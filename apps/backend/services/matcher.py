# apps/backend/services/matcher.py
from __future__ import annotations

import os
import sys
import json
import math
from typing import Dict, List, Any, Iterable, Optional, Tuple

# Best-effort: load .env (harmless if already loaded by app.py)
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

# ============================== CONFIG ==============================

# Pinecone namespaces / scopes
SEEKER_NS = os.getenv("PINECONE_NS_JOB_SEEKERS", "job_seekers")
POST_NS   = os.getenv("PINECONE_NS_JOB_POSTS", "job_posts")
VALID_SCOPES: Tuple[str, ...] = ("skills", "experience", "education", "licenses")

# Default section weights for hybrid cosine aggregation
DEFAULT_WEIGHTS: Dict[str, float] = {
    "skills":     0.40,
    "experience": 0.30,
    "education":  0.15,
    "licenses":   0.15,
}

# Cross-encoder reranker (enabled by default)
RERANK_ENABLE = True
RERANK_MODEL  = "cross-encoder/ms-marco-MiniLM-L-6-v2"
RERANK_ALPHA  = 0.65     # 0..1 — higher = trust Pinecone more
RERANK_TOP_K  = 50       # rerank up to this many from the hybrid list

# LLM judge (strict, context-aware) to refine top results
LLM_ENABLE       = True            # on by default
LLM_JUDGE_TOP_K  = 15              # how many hybrid+reranked to send to LLM
LLM_WEIGHT       = 0.55            # blend: final = (1-LLM_WEIGHT)*hybrid + LLM_WEIGHT*llm_overall
OPENAI_MODEL     = "gpt-4o-mini"
GEMINI_MODEL     = "gemini-2.5-flash"

# Per-section blending: mix vector section scores with LLM section scores
BLEND_SECTION_SCORES = True
LLM_SECTION_ALPHA    = 0.35   # 0..1 (0 = trust vectors only, 1 = trust LLM only)

# Retrieval sizes
DEFAULT_TOP_K_PER_SECTION = 30

# Stricter calibration of raw cosine -> 0..100 (smooth, not hard caps)
# Example: s=0.45 → ~8.3%, s=0.65 → ~50%, s=0.85 → ~95%
CAL_K = 12.0
CAL_M = 0.65

# =========================== ENV CHECKS =============================

def _require_env() -> None:
    missing = []
    for k in ("PINECONE_API_KEY", "PINECONE_INDEX", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"):
        if not os.getenv(k):
            missing.append(k)

    if LLM_ENABLE:
        if not (os.getenv("OPENAI_API_KEY") or os.getenv("GEMINI_API_KEY")):
            missing.append("OPENAI_API_KEY or GEMINI_API_KEY")

    if missing:
        raise RuntimeError("Missing required environment variables: " + ", ".join(missing))

_require_env()

# ======================= LAZY CLIENT FACTORY =======================

_PC = None
_INDEX = None
_SB = None
_CE = None  # cross encoder (lazy)

def _get_clients():
    """Create and cache Pinecone index + Supabase client lazily."""
    global _PC, _INDEX, _SB
    if _INDEX is not None and _SB is not None:
        return _INDEX, _SB

    from pinecone import Pinecone
    from supabase import create_client

    _PC = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
    _INDEX = _PC.Index(os.getenv("PINECONE_INDEX"))
    _SB = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_SERVICE_ROLE_KEY"))
    return _INDEX, _SB

class _SBProxy:
    def __getattr__(self, name: str):
        _, sb = _get_clients()
        return getattr(sb, name)
SB = _SBProxy()

# ========================= RETRIEVAL LAYER =========================

def get_seeker_vectors(job_seeker_id: str, scopes: Iterable[str] = VALID_SCOPES) -> Dict[str, List[float]]:
    """Fetch the seeker's per-section vectors from Pinecone."""
    INDEX, _ = _get_clients()
    ids = [f"{job_seeker_id}:{s}" for s in scopes]
    fetch_res = INDEX.fetch(ids=ids, namespace=SEEKER_NS)

    out: Dict[str, List[float]] = {}

    def _add(vid: Optional[str], vobj: Any):
        if not vid:
            vid = (vobj.get("id") if isinstance(vobj, dict) else getattr(vobj, "id", None))
        if not vid or ":" not in vid:
            return
        scope = vid.split(":", 1)[1]
        if scope not in VALID_SCOPES:
            return
        vals = (vobj.get("values") if isinstance(vobj, dict) else getattr(vobj, "values", None)) or []
        if vals:
            out[scope] = list(vals)

    vectors_obj = getattr(fetch_res, "vectors", None)
    if isinstance(vectors_obj, dict):
        for vid, v in vectors_obj.items():
            _add(vid, v)
    elif isinstance(vectors_obj, list):
        for v in vectors_obj:
            _add(None, v)
    elif isinstance(fetch_res, dict):
        v = fetch_res.get("vectors", {})
        if isinstance(v, dict):
            for vid, vv in v.items():
                _add(vid, vv)
        elif isinstance(v, list):
            for vv in v:
                _add(None, vv)
    return out

def _query_section(scope: str, vector: List[float], top_k: int) -> List[Dict[str, Any]]:
    """Query job_posts for one section vector."""
    if not vector:
        return []
    INDEX, _ = _get_clients()
    res = INDEX.query(
        vector=vector,
        top_k=top_k,
        namespace=POST_NS,
        filter={"scope": {"$eq": scope}},
        include_metadata=True,
    )
    return res.get("matches", []) if isinstance(res, dict) else (getattr(res, "matches", None) or [])

# ==================== CALIBRATION & AGGREGATION ====================

def _calibrate_cosine_to_100(s: float) -> float:
    """Map raw cosine similarity (0..1) to stricter 0..100 via logistic."""
    s = max(0.0, min(1.0, float(s)))
    p = 1.0 / (1.0 + math.exp(-CAL_K * (s - CAL_M)))
    return float(round(p * 100.0, 2))

def _effective_weights(weights: Optional[Dict[str, float]]) -> Dict[str, float]:
    """Validate and return usable weights for all scopes."""
    if not weights:
        return DEFAULT_WEIGHTS.copy()
    out: Dict[str, float] = {}
    for s in VALID_SCOPES:
        out[s] = float(weights.get(s, DEFAULT_WEIGHTS[s]))
    return out

def _aggregate_scores(
    section_results: Dict[str, List[Dict[str, Any]]],
    weights: Dict[str, float],
    min_sections: int = 1,
) -> List[Dict[str, Any]]:
    """
    Weighted average of the *calibrated* best score per section per job_post.
    Returns: [{"job_post_id", "confidence", "section_scores"}], sorted desc.
    """
    per_post: Dict[str, Dict[str, float]] = {}  # pid -> {scope: best_calibrated_score_0..100}

    for scope, matches in section_results.items():
        for m in matches or []:
            mid = m.get("id", "")
            if ":" not in mid:
                continue
            pid, _ = mid.split(":", 1)
            raw = float(m.get("score", 0.0))
            cal = _calibrate_cosine_to_100(raw)
            bucket = per_post.setdefault(pid, {})
            bucket[scope] = max(bucket.get(scope, 0.0), cal)

    ranked: List[Dict[str, Any]] = []
    min_sections = max(1, int(min_sections))

    for pid, section_best in per_post.items():
        if len(section_best) < min_sections:
            continue

        weight_sum = sum(float(weights.get(s, 0.0)) for s in VALID_SCOPES)
        if weight_sum <= 0:
            continue

        weighted = 0.0
        for scope in VALID_SCOPES:
            w = float(weights.get(scope, 0.0))
            score_cal = float(section_best.get(scope, 0.0))  # 0 if section missing
            weighted += w * score_cal

        confidence = weighted / weight_sum  # already 0..100 (calibrated per-section)
        ranked.append({
            "job_post_id": pid,
            "confidence": round(confidence, 2),
            "section_scores": {k: round(v, 2) for k, v in section_best.items()},
        })

    ranked.sort(key=lambda d: d["confidence"], reverse=True)
    return ranked

# =========================== RERANKER ==============================

def _get_cross_encoder():
    global _CE
    if _CE is not None:
        return _CE
    if not RERANK_ENABLE:
        return None
    try:
        from sentence_transformers import CrossEncoder
        _CE = CrossEncoder(RERANK_MODEL)  # downloads on first use
        return _CE
    except Exception:
        return None

def _minmax_to_0_100(vals: List[float]) -> List[float]:
    if not vals:
        return []
    vmin = min(vals)
    vmax = max(vals)
    if vmax <= vmin:
        return [50.0 for _ in vals]
    return [ (v - vmin) / (vmax - vmin) * 100.0 for v in vals ]

def _get_seeker_text(job_seeker_id: str) -> str:
    _, SB_real = _get_clients()
    cols = "full_name, email, skills, experience, education, licenses_certifications"
    try:
        resp = (
            SB_real.table("job_seeker")
            .select(cols)
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
    except Exception:
        return ""
    if not resp.data:
        return ""
    row = resp.data[0] or {}

    def _coerce_list(x) -> List[str]:
        if x is None: return []
        if isinstance(x, list): return [str(t).strip() for t in x if str(t).strip()]
        if isinstance(x, str): return [t.strip() for t in x.split(",") if t.strip()]
        if isinstance(x, dict): return [str(k).strip() for k in x.keys()]
        return []

    def _str(x: Any) -> str:
        if x is None: return ""
        if isinstance(x, str): return x
        try:
            return json.dumps(x, ensure_ascii=False)
        except Exception:
            return str(x)

    parts: List[str] = []
    if row.get("full_name"):
        parts.append(f"Name: {row.get('full_name')}")
    if row.get("skills"):
        parts.append("Skills: " + ", ".join(_coerce_list(row.get("skills"))))
    if row.get("experience"):
        parts.append("Experience: " + _str(row.get("experience")))
    if row.get("education"):
        parts.append("Education: " + _str(row.get("education")))
    if row.get("licenses_certifications"):
        parts.append("Licenses/Certs: " + ", ".join(_coerce_list(row.get("licenses_certifications"))))
    return " | ".join(parts)

def _get_post_text(post_row: Dict[str, Any]) -> str:
    def _coerce_list(x) -> List[str]:
        if x is None: return []
        if isinstance(x, list): return [str(t).strip() for t in x if str(t).strip()]
        if isinstance(x, str): return [t.strip() for t in x.split(",") if t.strip()]
        if isinstance(x, dict): return [str(k).strip() for k in x.keys()]
        return []
    def _str(x: Any) -> str:
        if x is None: return ""
        if isinstance(x, str): return x
        try:
            return json.dumps(x, ensure_ascii=False)
        except Exception:
            return str(x)

    parts: List[str] = []
    title = post_row.get("job_title") or post_row.get("title") or ""
    company = post_row.get("company") or post_row.get("employer") or ""
    if title or company:
        parts.append(f"{title} at {company}".strip())
    if post_row.get("job_overview"):
        parts.append(_str(post_row.get("job_overview")))
    if post_row.get("job_skills"):
        parts.append("Required skills: " + ", ".join(_coerce_list(post_row.get("job_skills"))))
    if post_row.get("job_experience"):
        parts.append("Experience req: " + _str(post_row.get("job_experience")))
    if post_row.get("job_education"):
        parts.append("Education req: " + _str(post_row.get("job_education")))
    if post_row.get("job_licenses_certifications"):
        parts.append("Licenses/Certs: " + _str(post_row.get("job_licenses_certifications")))
    return " | ".join(parts)

def _apply_reranker(job_seeker_id: str, ranked: List[Dict[str, Any]], posts_map: Dict[str, Any]) -> List[Dict[str, Any]]:
    if not RERANK_ENABLE or not ranked:
        return ranked
    ce = _get_cross_encoder()
    if ce is None:
        return ranked

    seeker_text = _get_seeker_text(job_seeker_id)
    if not seeker_text:
        return ranked

    top = ranked[: max(1, min(RERANK_TOP_K, len(ranked)))]
    pairs: List[Tuple[str, str]] = []
    for r in top:
        post_row = posts_map.get(r["job_post_id"]) or {}
        post_text = _get_post_text(post_row) or str(post_row or "")
        pairs.append((seeker_text, post_text))

    try:
        scores = ce.predict(pairs).tolist()  # type: ignore[attr-defined]
    except Exception:
        return ranked

    scores_norm = _minmax_to_0_100(scores)
    for r, rr in zip(top, scores_norm):
        pine = float(r.get("confidence", 0.0))
        blended = RERANK_ALPHA * pine + (1.0 - RERANK_ALPHA) * rr
        r["confidence"] = round(float(blended), 2)

    ranked.sort(key=lambda d: d["confidence"], reverse=True)
    return ranked

# =========================== SUPABASE IO ===========================

def _coerce_to_list(field) -> List[str]:
    if field is None:
        return []
    if isinstance(field, list):
        return [str(x).strip() for x in field if str(x).strip()]
    if isinstance(field, str):
        return [x.strip() for x in field.split(",") if x.strip()]
    if isinstance(field, dict):
        return [str(k).strip() for k, v in field.items() if str(k).strip()]
    return []

def _stringify(x: Any) -> str:
    if x is None:
        return ""
    if isinstance(x, str):
        return x
    try:
        return json.dumps(x, ensure_ascii=False)
    except Exception:
        return str(x)

def _fetch_posts_map(pids: List[str]) -> Dict[str, Dict[str, Any]]:
    if not pids:
        return {}
    _, SB_real = _get_clients()
    details_map: Dict[str, Any] = {}
    CHUNK = 200
    for i in range(0, len(pids), CHUNK):
        chunk = pids[i:i+CHUNK]
        resp = SB_real.table("job_post").select("*").in_("job_post_id", chunk).execute()
        for row in (resp.data or []):
            details_map[str(row.get("job_post_id"))] = row
    return details_map

def _build_job_context(post: Dict[str, Any]) -> Dict[str, Any]:
    if not post:
        return {}
    education_required = bool(post.get("job_education"))
    license_required   = bool(post.get("job_licenses_certifications"))
    return {
        "job_post_id": str(post.get("job_post_id")),
        "job_title":   post.get("job_title") or post.get("title") or "",
        "company":     post.get("company") or post.get("employer") or "",
        "job_overview": _stringify(post.get("job_overview")),
        "job_skills":  _coerce_to_list(post.get("job_skills")),
        "experience_req": _stringify(post.get("job_experience")),
        "education_req":  _stringify(post.get("job_education")),
        "licenses_req":   _stringify(post.get("job_licenses_certifications")),
        "location":    post.get("location") or "",
        "seniority":   post.get("seniority") or "",
        "education_required": education_required,
        "license_required":   license_required,
    }

def _fetch_seeker_context(job_seeker_id: str) -> Dict[str, Any]:
    _, SB_real = _get_clients()
    projection = "full_name,email,skills,experience,education,licenses_certifications,search_document"
    resp = SB_real.table("job_seeker").select(projection).eq("job_seeker_id", job_seeker_id).limit(1).execute()
    if not resp.data:
        return {}
    row = resp.data[0] or {}
    return {
        "full_name": row.get("full_name") or "",
        "email": row.get("email") or "",
        "skills": _coerce_to_list(row.get("skills")),
        "experience_text": _stringify(row.get("experience")),
        "education_text": _stringify(row.get("education")),
        "licenses_certifications": _coerce_to_list(row.get("licenses_certifications")),
        "search_document": row.get("search_document") or "",
    }

# ============================= LLM ================================

def _select_provider() -> str:
    if os.getenv("OPENAI_API_KEY"):
        return "openai"
    if os.getenv("GEMINI_API_KEY"):
        return "gemini"
    raise RuntimeError("No LLM key configured")

def _llm_score_candidates(seeker_ctx: Dict[str, Any], jobs_ctx: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Strict, context-aware LLM scoring for top candidates.
    Output array items include: job_post_id, section_scores{skills,experience,education,licenses}, overall,
    matched_skills, missing_skills, matched_explanations, notes.
    """
    provider = _select_provider()

    SYSTEM = (
        "You are an expert technical recruiter and hiring manager acting as a STRICT job-matching judge. "
        "Score realistically on a 0–100 scale for each section (skills, experience, education, licenses) and an overall score. "
        "Reason with context, not just keywords. Make sure to triple check and recalculate before sending in the final scores. "
        "OUTPUT ONLY valid JSON and match the provided response_schema_hint exactly—no prose, no markdown, no extra keys.\n\n"
        "Scoring principles (be conservative and evidence-based):\n"
        "Add a deduction of appropriate points if the entire list of skills, licenses, experiences, and certificates of the job seeker are nowhere related to the job post requirements. For example, the skills of a carpenter must not reach 10% to the confidence score of tech jobs. Use this for other test cases.\n"
        "• Prioritize hard/technical requirements (tools, frameworks, languages, platforms, certifications, years, seniority).\n"
        "• Use deep context alignment: responsibilities, scope/impact, seniority (IC vs lead/manager), domain/industry, and outcomes.\n"
        "• Synonyms/near-equivalents may count (React ↔ frontend React; Google Cloud ↔ GCP), but generic terms do not.\n"
        "• Recency matters: recent, hands-on evidence outweighs old or superficial exposure.\n"
        "• Penalize stack/domain/seniority mismatches and vague or unsubstantiated claims.\n"
        "• If the job does not require them (flags provided), do not penalize overall; you may keep those section scores low but EXCLUDE them from the overall calculation.\n"
        "• When evidence is thin or ambiguous, keep scores low and do not guess.\n\n"
        "Explanations: Provide concise, specific reasons tied to concrete evidence. 1–2 sentences per matched skill, low-jargon."
    )

    schema_hint = {
        "type": "array",
        "items": {
            "type": "object",
            "required": ["job_post_id", "section_scores", "overall", "matched_skills", "missing_skills", "domain_mismatch"],
            "properties": {
                "job_post_id": {"type": "string"},
                "section_scores": {
                    "type": "object",
                    "properties": {
                        "skills": {"type": "integer", "minimum": 0, "maximum": 100},
                        "experience": {"type": "integer", "minimum": 0, "maximum": 100},
                        "education": {"type": "integer", "minimum": 0, "maximum": 100},
                        "licenses": {"type": "integer", "minimum": 0, "maximum": 100},
                    }
                },
                "overall": {"type": "integer", "minimum": 0, "maximum": 100},
                "matched_skills": {"type": "array", "items": {"type": "string"}},
                "missing_skills": {"type": "array", "items": {"type": "string"}},
                "matched_explanations": {"type": "object", "additionalProperties": {"type": "string"}},
                "domain_mismatch": {"type": "boolean", "description": "True if candidate's domain is completely unrelated to the job"},
                "notes": {"type": "string"},
            }
        }
    }

    user_payload = {
        "seeker": seeker_ctx,
        "jobs": jobs_ctx,
        "instructions": {
            "explanation_style": "1–2 sentences per matched skill; simple, specific, low-jargon",
            "overall_weighting": "Compute overall as ~40% skills, 30% experience, 15% education/licenses; "
                                 "IF education_required=false or license_required=false for a job, exclude that section from the overall weighting.",
            "strictness": "Be EXTREMELY conservative. Unrelated domains must not exceed 5%. Similar but different domains must not exceed 15%.",
            "domain_rules": "Set domain_mismatch=true if backgrounds are completely unrelated (e.g., construction worker applying to software dev).",
        },
        "response_schema_hint": schema_hint,
    }

    text = json.dumps(user_payload, ensure_ascii=False)

    try:
        if provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            model = genai.GenerativeModel(
                GEMINI_MODEL,
                generation_config={"temperature": 0.2, "response_mime_type": "application/json"},
                system_instruction=SYSTEM,
            )
            resp = model.generate_content(text)
            out = (resp.text or "").strip()
        else:
            from openai import OpenAI
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            resp = client.chat.completions.create(
                model=OPENAI_MODEL,
                temperature=0.2,
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": SYSTEM},
                    {"role": "user", "content": text},
                ],
            )
            out = (resp.choices[0].message.content or "").strip()
    except Exception as e:
        raise RuntimeError(f"LLM scoring failed: {e}")

    try:
        data = json.loads(out)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            if "items" in data and isinstance(data["items"], list):
                return data["items"]
            if "results" in data and isinstance(data["results"], list):
                return data["results"]
    except Exception as e:
        raise RuntimeError(f"LLM JSON parse failed: {e}\nRaw: {out[:500]}")

    raise RuntimeError("LLM returned unexpected JSON shape")

# ======================== CORE RANKING API ========================

def _collect_candidates(seeker_vecs: Dict[str, List[float]], top_k_per_section: int) -> Dict[str, Dict[str, Any]]:
    """
    Per-section queries -> calibration -> weighted aggregation -> ranked list.
    Returns a dict pid -> row {"job_post_id","confidence","section_scores"} ordered later.
    """
    weights_eff = _effective_weights(None)
    section_results: Dict[str, List[Dict[str, Any]]] = {}
    for scope, vec in seeker_vecs.items():
        section_results[scope] = _query_section(scope, vec, top_k=top_k_per_section)

    aggregated = _aggregate_scores(section_results, weights_eff, min_sections=1)
    return {r["job_post_id"]: r for r in aggregated}

def rank_posts_for_seeker(
    job_seeker_id: str,
    top_k_per_section: int = DEFAULT_TOP_K_PER_SECTION,
    include_job_details: bool = False,
    min_sections: int = 1,  # used in aggregation (stricter coverage)
    weights: Optional[Dict[str, float]] = None,
) -> List[Dict[str, Any]]:
    """
    Hybrid pipeline:
      1) Per-section Pinecone queries
      2) Strict calibrated weighted aggregation
      3) Optional cross-encoder reranker (blends with aggregation)
      4) Optional LLM judge on top-K (blends with hybrid for final confidence)
    """
    # Ensure seeker vectors exist; else enqueue best-effort and return []
    seeker_vecs = get_seeker_vectors(job_seeker_id)
    if not seeker_vecs:
        try:
            _, sb = _get_clients()
            sb.table("embedding_queue").insert({"job_seeker_id": job_seeker_id, "reason": "insert"}).execute()
        except Exception:
            pass
    # 1–2) Aggregate with stricter calibration
    weights_eff = _effective_weights(weights)
    section_results: Dict[str, List[Dict[str, Any]]] = {}
    for scope, vec in seeker_vecs.items():
        section_results[scope] = _query_section(scope, vec, top_k=top_k_per_section)
    ranked = _aggregate_scores(section_results, weights_eff, min_sections=min_sections)

    if not ranked:
        return []

    # 3) Fetch job details (for reranker + LLM context)
    pids = [r["job_post_id"] for r in ranked]
    posts_map = _fetch_posts_map(pids)

    # Cross-encoder reranker
    ranked = _apply_reranker(job_seeker_id, ranked, posts_map)

    # Filter out job posts that do not exist in the job_post table
    valid_post_ids = set(posts_map.keys())
    ranked = [r for r in ranked if r["job_post_id"] in valid_post_ids]

    # 4) LLM judge on the top subset, then blend with hybrid
    if LLM_ENABLE and ranked:
        top = ranked[: min(LLM_JUDGE_TOP_K, len(ranked))]
        jobs_ctx = [_build_job_context(posts_map.get(r["job_post_id"], {})) for r in top]
        seeker_ctx = _fetch_seeker_context(job_seeker_id)

        try:
            judged = _llm_score_candidates(seeker_ctx, jobs_ctx)
            judged_by_pid = {str(it.get("job_post_id")): it for it in judged if it.get("job_post_id")}
        except Exception as e:
            judged_by_pid = {}
            # non-fatal; keep hybrid if LLM fails
            print(f"[WARN] LLM judge failed: {e}")

        for r in top:
            pid = r["job_post_id"]
            j = judged_by_pid.get(pid)
            if not j:
                continue

            # -------- overall blending (kept) --------
            try:
                llm_overall = float(j.get("overall", 0.0))
                is_domain_mismatch = j.get("domain_mismatch", False)

                # Force very low scores for domain mismatches
                if is_domain_mismatch:
                    llm_overall = min(5.0, llm_overall)  # Hard cap at 5% for complete mismatches
                    r["confidence"] = min(5.0, r["confidence"])  # Cap hybrid score too

                # Regular blending for non-mismatches
                blended = (1.0 - LLM_WEIGHT) * float(r["confidence"]) + LLM_WEIGHT * llm_overall
                r["confidence"] = round(min(blended, 15.0 if is_domain_mismatch else 100.0), 2)
            except Exception:
                # Conservative cap if LLM fails
                r["confidence"] = round(min(r["confidence"], 15.0), 2)

            # -------- per-section blending (APPLIED TO section_scores) --------
            # Use current (vector-based) section scores as base
            base_sections = dict(r.get("section_scores", {}))
            js_sections = j.get("section_scores") or {}

            if BLEND_SECTION_SCORES and js_sections:
                blended_sections: Dict[str, float] = {}
                for k in ("skills", "experience", "education", "licenses"):
                    v_vec = float(base_sections.get(k, 0.0))
                    v_llm = float(js_sections.get(k, v_vec))  # fallback to vector if LLM missing key
                    blended_sections[k] = round((1.0 - LLM_SECTION_ALPHA) * v_vec + LLM_SECTION_ALPHA * v_llm, 2)
                # Replace displayed per-section scores with the blended values
                r["section_scores"] = blended_sections
            else:
                # No LLM sections; keep vector-derived sections
                r["section_scores"] = base_sections

            # -------- attach analysis fields (unchanged) --------
            r.setdefault("analysis", {})
            required_skills = j.get("required_skills")
            if required_skills is None:
                required_skills = _coerce_to_list(posts_map.get(pid, {}).get("job_skills"))
            r["analysis"].update({
                "matched_skills": j.get("matched_skills") or [],
                "missing_skills": j.get("missing_skills") or [],
                "matched_explanations": j.get("matched_explanations") or {},
                "overall_summary": j.get("notes") or "",
                "required_skills": required_skills,
            })
            req = required_skills or []
            matched = r["analysis"]["matched_skills"] or []
            try:
                smr = j.get("skills_match_rate")
                if smr is None:
                    smr = len(matched) / max(1, len(_coerce_to_list(req)))
                smr = float(smr)
                if smr <= 1.0:
                    smr *= 100.0
            except Exception:
                smr = (len(matched) / max(1, len(_coerce_to_list(req)))) * 100.0
            r["analysis"]["skills_match_rate"] = round(float(smr), 2)

    # -------------------- FIX ADDED: Post-pass to ALWAYS fill analysis defaults --------------------
    # Ensures every item (not just LLM-judged) has analysis fields + skills_match_rate
    for r in ranked:
        a = r.setdefault("analysis", {})
        # required_skills fallback from job_post
        if "required_skills" not in a:
            post = posts_map.get(r["job_post_id"], {}) or {}
            a["required_skills"] = _coerce_to_list(post.get("job_skills"))
        a.setdefault("matched_skills", [])
        a.setdefault("missing_skills", [])
        a.setdefault("matched_explanations", {})
        a.setdefault("overall_summary", "")
        a.setdefault("domain_mismatch", False)

        req = a["required_skills"] or []
        matched = a["matched_skills"] or []
        try:
            smr = a.get("skills_match_rate")
            if smr is None:
                smr = len(matched) / max(1, len(req))
            smr = float(smr)
            if smr <= 1.0:
                smr *= 100.0
        except Exception:
            smr = (len(matched) / max(1, len(req))) * 100.0
        a["skills_match_rate"] = round(float(smr), 2)
    # -----------------------------------------------------------------------------------------------

    # Add details if requested
    if include_job_details:
        for r in ranked:
            r["job_post"] = posts_map.get(r["job_post_id"])

    ranked.sort(key=lambda d: d.get("confidence", 0.0), reverse=True)
    return ranked

def get_seeker_id_by_email(email: str) -> Optional[str]:
    _, SB_real = _get_clients()
    resp = SB_real.table("job_seeker").select("job_seeker_id").eq("email", email).limit(1).execute()
    if not resp.data:
        return None
    return resp.data[0]["job_seeker_id"]

def rank_posts_for_seeker_by_email(
    email: str,
    top_k_per_section: int = DEFAULT_TOP_K_PER_SECTION,
    include_job_details: bool = False,
    min_sections: int = 1,
    weights: Optional[Dict[str, float]] = None,
) -> List[Dict[str, Any]]:
    js_id = get_seeker_id_by_email(email)
    if not js_id:
        return []
    results = rank_posts_for_seeker(
        job_seeker_id=js_id,
        top_k_per_section=top_k_per_section,
        include_job_details=include_job_details,
        min_sections=min_sections,
        weights=weights,
    )
    # Ensure required analysis fields for all results (not just LLM-judged)
    for r in results:
        r.setdefault("analysis", {})
        if "required_skills" not in r["analysis"]:
            r["analysis"]["required_skills"] = []
        r["analysis"].setdefault("matched_skills", [])
        r["analysis"].setdefault("missing_skills", [])
        req = r["analysis"]["required_skills"] or []
        matched = r["analysis"]["matched_skills"] or []
        try:
            smr = r["analysis"].get("skills_match_rate")
            if smr is None:
                smr = len(matched) / max(1, len(req))
            smr = float(smr)
            if smr <= 1.0:
                smr *= 100.0
        except Exception:
            smr = (len(matched) / max(1, len(req))) * 100.0
        r["analysis"]["skills_match_rate"] = round(float(smr), 2)
    return results

# ==================== HIGH-LEVEL ORCHESTRATION ====================

def match_and_enrich(
    *,
    job_seeker_id: str,
    top_k_per_section: int = DEFAULT_TOP_K_PER_SECTION,
    include_details: bool = False,
    min_sections: int = 1,
    include_explanations: bool = True,    # kept for API compat (LLM adds explanations already)
    weights: Optional[Dict[str, float]] = None,
) -> List[Dict[str, Any]]:
    """
    Final service for the endpoint:
      - Retrieve & aggregate
      - Rerank (cross-encoder)
      - LLM judge blend (strict, context-aware)
      - Persist to Supabase (best-effort)
    """
    results = rank_posts_for_seeker(
        job_seeker_id=job_seeker_id,
        top_k_per_section=top_k_per_section,
        include_job_details=True,  # required for contexts above
        min_sections=min_sections,
        weights=weights,
    )
    if not results:
        return []

    # Optionally strip details before returning
    out: List[Dict[str, Any]] = []
    for r in results:
        if include_details:
            x = dict(r)
        else:
            x = dict(r)
            x.pop("job_post", None)
        # Always remove 'analysis' key before persisting to DB
        if "analysis" in x:
            del x["analysis"]
        out.append(x)

    # Persist (best-effort)
    try:
        from .data_storer import persist_matcher_results
        provider = "openai" if os.getenv("OPENAI_API_KEY") else ("gemini" if os.getenv("GEMINI_API_KEY") else "none")
        model_name = OPENAI_MODEL if provider == "openai" else (GEMINI_MODEL if provider == "gemini" else "hybrid-only")
        method = "hybrid+rerank" + ("+llm" if LLM_ENABLE else "")
        persist_matcher_results(
            auth_user_id=None,
            job_seeker_id=job_seeker_id,
            matcher_results=out,
            default_weights=weights,
            method=method,
            model_version=model_name,
        )
    except Exception as e:
        print(f"[WARN] Failed to persist matcher results: {e}")

    return out

__all__ = [
    "SB", "VALID_SCOPES", "SEEKER_NS", "POST_NS",
    "rank_posts_for_seeker", "rank_posts_for_seeker_by_email", "get_seeker_id_by_email",
    "match_and_enrich",
]

# ============================== CLI ===============================

def _parse_argv(argv: List[str]) -> Dict[str, Any]:
    if not argv:
        raise SystemExit(
            "Usage: python matcher.py <job_seeker_id> [top_k_per_section=30] [include_details=0|1] [min_sections=1]"
        )
    out: Dict[str, Any] = {"job_seeker_id": argv[0]}
    out["top_k"] = int(argv[1]) if len(argv) > 1 else DEFAULT_TOP_K_PER_SECTION
    out["include_details"] = bool(int(argv[2])) if len(argv) > 2 else False
    out["min_sections"] = int(argv[3]) if len(argv) > 3 else 1
    return out

if __name__ == "__main__":
    args = _parse_argv(sys.argv[1:])
    results = rank_posts_for_seeker(
        job_seeker_id=args["job_seeker_id"],
        top_k_per_section=args["top_k"],
        include_job_details=args["include_details"],
        min_sections=args["min_sections"],
    )
    for r in results[:10]:
        pid = r["job_post_id"]
        conf = r["confidence"]
        sections = ", ".join(f"{k}:{v}" for k, v in sorted(r["section_scores"].items()))
        print(f"{pid}  confidence={conf}  sections=({sections})")
