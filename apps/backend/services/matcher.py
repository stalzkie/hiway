# apps/backend/services/matcher.py
from __future__ import annotations

import os
import sys
from typing import Dict, List, Any, Iterable, Optional, Tuple

# Best-effort: load .env if available (harmless if already loaded elsewhere)
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

# ---------------------- Namespaces / Weights ----------------------
SEEKER_NS = os.getenv("PINECONE_NS_JOB_SEEKERS", "job_seekers")
POST_NS   = os.getenv("PINECONE_NS_JOB_POSTS", "job_posts")

VALID_SCOPES: Tuple[str, ...] = ("skills", "experience", "education", "licenses")

DEFAULT_WEIGHTS: Dict[str, float] = {
    "skills": 0.40,
    "experience": 0.30,
    "education": 0.15,
    "licenses": 0.15,
}

# ---------------------- Reranker Config (BERT/Cross-Encoder) ----------------------
RERANK_ENABLE = os.getenv("RERANK_ENABLE", "0") == "1"
RERANK_MODEL = os.getenv("RERANK_MODEL", "cross-encoder/ms-marco-MiniLM-L-6-v2")
RERANK_ALPHA = float(os.getenv("RERANK_ALPHA", "0.7"))  # 0..1 (higher = trust Pinecone more)
RERANK_TOP_K = int(os.getenv("RERANK_TOP_K", "50"))

# ---------------------- LLM Provider Config ----------------------
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "auto").lower()   # "gemini" | "openai" | "auto"
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL   = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
GEMINI_MODEL   = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

# ---------------------- Queue Config ----------------------
EMBED_QUEUE_TABLE_SEEKER = os.getenv("EMBED_QUEUE_TABLE_SEEKER", "embedding_queue")
EMBED_QUEUE_TABLE_POST   = os.getenv("EMBED_QUEUE_TABLE_POST", "embedding_queue_post")
# MUST be one of your DB CHECK values: insert | update | manual | backfill
EMBED_QUEUE_REASON_DEFAULT = os.getenv("EMBED_QUEUE_REASON_DEFAULT", "insert")
AUTO_ENQUEUE_STALE_POSTS = os.getenv("AUTO_ENQUEUE_STALE_POSTS", "1") == "1"

_ALLOWED_REASONS = {"insert", "update", "manual", "backfill"}

# ---------------------- Lazy client creation ----------------------
_PC = None
_INDEX = None
_SB = None
_CE = None  # cross-encoder model (lazy)

def _require_env() -> None:
    missing = [
        k for k in ("PINECONE_API_KEY", "PINECONE_INDEX", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
        if not os.getenv(k)
    ]
    if missing:
        raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")

def _get_clients():
    """Create and cache Pinecone index + Supabase client lazily."""
    global _PC, _INDEX, _SB
    if _INDEX is not None and _SB is not None:
        return _INDEX, _SB

    _require_env()

    from pinecone import Pinecone
    from supabase import create_client

    _PC = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
    _INDEX = _PC.Index(os.getenv("PINECONE_INDEX"))
    _SB = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_SERVICE_ROLE_KEY"))
    return _INDEX, _SB

# Backwards-compatible SB symbol for callers that import SB directly.
# This proxy defers real client creation until first attribute access.
class _SBProxy:
    def __getattr__(self, name: str):
        _, sb = _get_clients()
        return getattr(sb, name)

SB = _SBProxy()

# ---------------------- Enqueue Helpers (VALID reasons) ----------------------
def _pick_reason_for_seeker(row: dict) -> str:
    """
    If pinecone_id or embedding_checksum is missing => 'insert', else 'update'.
    """
    reason = "insert" if (not row.get("pinecone_id") or not row.get("embedding_checksum")) else "update"
    return reason if reason in _ALLOWED_REASONS else EMBED_QUEUE_REASON_DEFAULT

def _ensure_seeker_enqueued(job_seeker_id: str) -> None:
    """
    If a seeker is missing pinecone_id or embedding_checksum, enqueue them for embedding.
    Always includes a valid non-null 'reason' that satisfies your DB CHECK constraint.
    """
    try:
        _, sb = _get_clients()
        resp = (
            sb.table("job_seeker")
            .select("pinecone_id, embedding_checksum, search_document")
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
        rows = resp.data or []
        if not rows:
            return
        reason = _pick_reason_for_seeker(rows[0])
        if reason not in _ALLOWED_REASONS:
            reason = "insert"
        sb.table(EMBED_QUEUE_TABLE_SEEKER).insert({
            "job_seeker_id": job_seeker_id,
            "reason": reason,  # 👈 valid & NOT NULL
        }).execute()
    except Exception as e:
        print(f"[WARN] _ensure_seeker_enqueued failed: {e}")

def _enqueue_stale_posts_if_any(limit: int = 200) -> None:
    """
    Opportunistically enqueue job_posts that are missing pinecone_id or embedding_checksum.
    Always includes a valid non-null 'reason' ('insert').
    """
    try:
        _, sb = _get_clients()
        missing_posts = (
            sb.table("job_post")
            .select("job_post_id")
            .or_("pinecone_id.is.null,embedding_checksum.is.null")
            .limit(limit)
            .execute()
        )
        for r in (missing_posts.data or []):
            try:
                sb.table(EMBED_QUEUE_TABLE_POST).insert({
                    "job_post_id": r["job_post_id"],
                    "reason": "insert",  # 👈 valid & NOT NULL
                }).execute()
            except Exception as inner:
                print(f"[WARN] enqueue post {r.get('job_post_id')} failed: {inner}")
    except Exception as e:
        print(f"[WARN] _enqueue_stale_posts_if_any failed: {e}")

# ---------------------- Helpers ----------------------
def _effective_weights(weights: Optional[Dict[str, float]]) -> Dict[str, float]:
    """Validate and return usable weights for all scopes."""
    if not weights:
        return DEFAULT_WEIGHTS.copy()
    out: Dict[str, float] = {}
    for s in VALID_SCOPES:
        out[s] = float(weights.get(s, DEFAULT_WEIGHTS[s]))
    return out

def get_seeker_vectors(job_seeker_id: str, scopes: Iterable[str] = VALID_SCOPES) -> Dict[str, List[float]]:
    """
    Fetch the seeker's section vectors from Pinecone.
    Handles SDK variations (dict/list/Vector objects).
    Returns only sections found and non-empty.
    """
    INDEX, _ = _get_clients()

    ids = [f"{job_seeker_id}:{s}" for s in scopes]
    fetch_res = INDEX.fetch(ids=ids, namespace=SEEKER_NS)

    out: Dict[str, List[float]] = {}

    def _add(vid: Optional[str], vobj: Any):
        if not vid:
            vid = (vobj.get("id") if isinstance(vobj, dict) else getattr(vobj, "id", None))
        if not vid or ":" not in vid:
            return
        try:
            scope = vid.split(":", 1)[1]
        except Exception:
            return
        if scope not in VALID_SCOPES:
            return
        vals = (
            vobj.get("values") if isinstance(vobj, dict)
            else getattr(vobj, "values", None)
        ) or []
        if vals:
            out[scope] = list(vals)

    # Normalize all possible shapes
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

def _query_section(scope: str, vector: List[float], top_k: int = 20) -> List[Dict[str, Any]]:
    """
    Query job_posts for a single section vector and return Pinecone matches.
    Each returned id is expected to be 'job_post_id:scope'.
    """
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
    # SDK may return a dict or an object; normalize
    return res.get("matches", []) if isinstance(res, dict) else (getattr(res, "matches", None) or [])

def _aggregate_scores(
    section_results: Dict[str, List[Dict[str, Any]]],
    weights: Dict[str, float],
    min_sections: int = 1
) -> List[Dict[str, Any]]:
    """
    Weighted average of the best similarity per section per job_post.
    Returns: [{"job_post_id", "confidence", "section_scores"}], sorted desc by confidence.
    """
    per_post: Dict[str, Dict[str, float]] = {}  # pid -> {scope: best_score}

    for scope, matches in section_results.items():
        for m in matches or []:
            mid = m.get("id", "")
            if ":" not in mid:
                continue
            pid, _ = mid.split(":", 1)
            score = float(m.get("score", 0.0))
            bucket = per_post.setdefault(pid, {})
            bucket[scope] = max(bucket.get(scope, 0.0), score)  # keep best per section

    ranked: List[Dict[str, Any]] = []
    min_sections = max(1, int(min_sections))

    for pid, section_best in per_post.items():
        if len(section_best) < min_sections:
            continue

        weight_sum = 0.0
        weighted = 0.0
        section_scores_out: Dict[str, float] = {}

        for scope, score in section_best.items():
            w = float(weights.get(scope, 0.0))
            if w <= 0:
                continue
            weighted += w * score
            weight_sum += w
            section_scores_out[scope] = round(score * 100.0, 2)  # per-section 0..100

        if weight_sum <= 0:
            continue

        confidence = (weighted / weight_sum) * 100.0
        ranked.append({
            "job_post_id": pid,
            "confidence": round(confidence, 2),
            "section_scores": section_scores_out,
        })

    ranked.sort(key=lambda d: d["confidence"], reverse=True)
    return ranked

# ---------------------- Text builders for cross-encoder ----------------------
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
        import json as _json
        return _json.dumps(x, ensure_ascii=False)
    except Exception:
        return str(x)

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
    parts: List[str] = []
    if row.get("full_name"):
        parts.append(f"Name: {row.get('full_name')}")
    if row.get("skills"):
        parts.append("Skills: " + ", ".join(_coerce_to_list(row.get("skills"))))
    if row.get("experience"):
        parts.append("Experience: " + _stringify(row.get("experience")))
    if row.get("education"):
        parts.append("Education: " + _stringify(row.get("education")))
    if row.get("licenses_certifications"):
        parts.append("Licenses/Certs: " + ", ".join(_coerce_to_list(row.get("licenses_certifications"))))
    return " | ".join(parts)

def _get_post_text(post_row: Dict[str, Any]) -> str:
    parts: List[str] = []
    title = post_row.get("job_title") or post_row.get("title") or ""
    company = post_row.get("company") or post_row.get("employer") or ""
    if title or company:
        parts.append(f"{title} at {company}".strip())
    if post_row.get("job_overview"):
        parts.append(_stringify(post_row.get("job_overview")))
    if post_row.get("job_skills"):
        parts.append("Required skills: " + ", ".join(_coerce_to_list(post_row.get("job_skills"))))
    if post_row.get("job_experience"):
        parts.append("Experience req: " + _stringify(post_row.get("job_experience")))
    if post_row.get("job_education"):
        parts.append("Education req: " + _stringify(post_row.get("job_education")))
    if post_row.get("job_licenses_certifications"):
        parts.append("Licenses/Certs: " + _stringify(post_row.get("job_licenses_certifications")))
    return " | ".join(parts)

# ---------------------- Cross-encoder (lazy) ----------------------
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
        return [50.0 for _ in vals]  # flat case
    return [ (v - vmin) / (vmax - vmin) * 100.0 for v in vals ]

def _apply_reranker(
    job_seeker_id: str,
    ranked: List[Dict[str, Any]],
    include_job_details: bool,
) -> List[Dict[str, Any]]:
    if not RERANK_ENABLE:
        return ranked

    ce = _get_cross_encoder()
    if ce is None:
        return ranked

    if not ranked:
        return ranked

    _, SB_real = _get_clients()
    if include_job_details:
        has_details_for_all = all("job_post" in r and r["job_post"] for r in ranked)
    else:
        has_details_for_all = False

    if not has_details_for_all:
        pids = [r["job_post_id"] for r in ranked]
        details_map: Dict[str, Any] = {}
        CHUNK = 200
        for i in range(0, len(pids), CHUNK):
            chunk = pids[i:i+CHUNK]
            resp = SB_real.table("job_post").select("*").in_("job_post_id", chunk).execute()
            for row in (resp.data or []):
                details_map[str(row.get("job_post_id"))] = row
        for r in ranked:
            r.setdefault("job_post", details_map.get(r["job_post_id"]))

    seeker_text = _get_seeker_text(job_seeker_id)
    if not seeker_text:
        return ranked

    top = ranked[: max(1, RERANK_TOP_K)]
    pairs: List[Tuple[str, str]] = []
    for r in top:
        post_row = r.get("job_post") or {}
        post_text = _get_post_text(post_row)
        if not post_text:
            post_text = str(post_row or "")
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

# ---------------------- Public service: ranking only ----------------------
def rank_posts_for_seeker(
    job_seeker_id: str,
    top_k_per_section: int = 20,
    weights: Optional[Dict[str, float]] = None,
    include_job_details: bool = False,
    min_sections: int = 1,
) -> List[Dict[str, Any]]:
    """Rank job posts for a seeker by aggregating cosine similarities across sections,
    then (optionally) refine with a BERT/miniLM cross-encoder reranker."""
    if AUTO_ENQUEUE_STALE_POSTS:
        _enqueue_stale_posts_if_any()

    weights_eff = _effective_weights(weights)

    # 1) Seeker vectors
    seeker_vecs = get_seeker_vectors(job_seeker_id)
    if not seeker_vecs:
        _ensure_seeker_enqueued(job_seeker_id)  # enqueue with valid reason
        return []

    # 2) Query posts per section
    section_results: Dict[str, List[Dict[str, Any]]] = {}
    for scope, vec in seeker_vecs.items():
        section_results[scope] = _query_section(scope, vec, top_k=top_k_per_section)

    # 3) Aggregate to weighted confidence
    ranked = _aggregate_scores(section_results, weights_eff, min_sections=min_sections)

    # 4) Optionally include job_post rows (for endpoints and/or reranker)
    if (include_job_details or RERANK_ENABLE) and ranked:
        _, SB_real = _get_clients()
        pids = [r["job_post_id"] for r in ranked]
        details_map: Dict[str, Any] = {}
        CHUNK = 200
        for i in range(0, len(pids), CHUNK):
            chunk = pids[i:i+CHUNK]
            resp = SB_real.table("job_post").select("*").in_("job_post_id", chunk).execute()
            for row in (resp.data or []):
                details_map[str(row.get("job_post_id"))] = row
        for r in ranked:
            if include_job_details:
                r["job_post"] = details_map.get(r["job_post_id"])
            else:
                r.setdefault("job_post", details_map.get(r["job_post_id"]))

    # 5) Optional cross-encoder rerank
    ranked = _apply_reranker(job_seeker_id, ranked, include_job_details)

    # 6) Strip job_post if not requested
    if not include_job_details:
        for r in ranked:
            r.pop("job_post", None)

    return ranked

def get_seeker_id_by_email(email: str) -> Optional[str]:
    _, SB_real = _get_clients()
    resp = SB_real.table("job_seeker").select("job_seeker_id").eq("email", email).limit(1).execute()
    if not resp.data:
        return None
    return resp.data[0]["job_seeker_id"]

def rank_posts_for_seeker_by_email(
    email: str,
    top_k_per_section: int = 20,
    weights: Optional[Dict[str, float]] = None,
    include_job_details: bool = False,
    min_sections: int = 1,
) -> List[Dict[str, Any]]:
    js_id = get_seeker_id_by_email(email)
    if not js_id:
        return []
    return rank_posts_for_seeker(
        job_seeker_id=js_id,
        top_k_per_section=top_k_per_section,
        weights=weights,
        include_job_details=include_job_details,
        min_sections=min_sections,
    )

# ======================================================================
#              ENRICHMENT (LLM explanations)
# ======================================================================

def _select_provider() -> str:
    if LLM_PROVIDER == "gemini" and GEMINI_API_KEY:
        return "gemini"
    if LLM_PROVIDER == "openai" and OPENAI_API_KEY:
        return "openai"
    if GEMINI_API_KEY:
        return "gemini"
    if OPENAI_API_KEY:
        return "openai"
    return "none"

def _safe_parse_json_map(text: str) -> Dict[str, str]:
    try:
        import json
        data = json.loads(text)
        if isinstance(data, dict):
            return {str(k): str(v) for k, v in data.items()}
    except Exception:
        left = text.find("{"); right = text.rfind("}")
        if left != -1 and right != -1 and right > left:
            try:
                import json
                data = json.loads(text[left:right+1])
                if isinstance(data, dict):
                    return {str(k): str(v) for k, v in data.items()}
            except Exception:
                pass
    return {}

def _trim_to_two_sentences(s: str) -> str:
    import re
    parts = re.split(r"(?<=[.!?])\s+", (s or "").strip())
    return " ".join(parts[:2]).strip() if len(parts) > 2 else (s or "").strip()

def _compose_skill_prompt(skills: List[str], job_ctx: Dict[str, Any], seeker_ctx: Dict[str, Any]) -> str:
    import json as _json
    return (
        "You are assisting a job-matching system. For EACH skill in the provided list, "
        "write a concise 1–2 sentence explanation showing how the job seeker's background "
        "matches the job post's context for that skill. Be specific and grounded in the "
        "given details. If evidence is weak, state it cautiously.\n\n"
        "CRITICAL RULES:\n"
        "• Output ONLY valid JSON (an object/dict), no commentary.\n"
        "• The JSON keys must be the exact skill strings provided.\n"
        "• Each value must be a single string of 1–2 sentences. Avoid using too much jargons and simplify your sentences.\n\n"
        f"skills: {_json.dumps(skills, ensure_ascii=False)}\n\n"
        f"job_context: {_json.dumps(job_ctx, ensure_ascii=False)}\n\n"
        f"seeker_context: {_json.dumps(seeker_ctx, ensure_ascii=False)}\n"
    )

def _compose_overall_prompt(
    confidence: float,
    section_scores: Dict[str, float],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
    matched: List[str],
    missing: List[str],
) -> str:
    import json as _json
    return (
        "You are summarizing a job-match result produced by vector (semantic) similarity across sections. "
        "Write a concise 2–4 sentence explanation that helps the user understand WHY this score happened, "
        "even if there were few or no exact keyword matches. Write in a simple manner where it can be understood by non-native English speakers and be straight to the point"
        "Ground the explanation in the per-section semantic similarities (skills/experience/education/licenses) "
        "and in the job vs seeker contexts. If there are no exact matches, clarify that the score still comes from "
        "semantic overlap in responsibilities, tools, or outcomes. Avoid using too much jargons and simplify your sentences.\n\n"
        "Output ONLY valid JSON with a single key 'overall_summary'.\n\n"
        f"confidence: {_json.dumps(confidence)}\n"
        f"section_scores_0to100: {_json.dumps(section_scores, ensure_ascii=False)}\n"
        f"matched_skills: {_json.dumps(matched, ensure_ascii=False)}\n"
        f"missing_skills: {_json.dumps(missing, ensure_ascii=False)}\n"
        f"job_context: {_json.dumps(job_ctx, ensure_ascii=False)}\n"
        f"seeker_context: {_json.dumps(seeker_ctx, ensure_ascii=False)}\n"
    )

def _fetch_seeker_skills(job_seeker_id: str) -> List[str]:
    _, SB_real = _get_clients()
    resp = (
        SB_real.table("job_seeker")
        .select("skills")
        .eq("job_seeker_id", job_seeker_id)
        .limit(1)
        .execute()
    )
    if not resp.data:
        return []
    raw = (resp.data[0] or {}).get("skills")
    return _coerce_to_list(raw)

def _fetch_seeker_context(job_seeker_id: str) -> Dict[str, Any]:
    _, SB_real = _get_clients()
    projection = "skills, experience, education, licenses_certifications, full_name, email"

    def _normalize(row: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "skills": _coerce_to_list(row.get("skills")),
            "experience_text": _stringify(row.get("experience")),
            "education_text": _stringify(row.get("education")),
            "licenses_certifications": _coerce_to_list(row.get("licenses_certifications")),
            "full_name": (row.get("full_name") or ""),
            "email": (row.get("email") or ""),
            # Prompt compatibility keys
            "summary": "",
            "projects": [],
            "achievements": [],
            "portfolio": "",
        }

    try:
        resp = (
            SB_real.table("job_seeker")
            .select(projection)
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
        if not resp.data:
            return {}
        return _normalize(resp.data[0] or {})
    except Exception:
        return {
            "skills": [],
            "experience_text": "",
            "education_text": "",
            "licenses_certifications": [],
            "full_name": "",
            "email": "",
            "summary": "",
            "projects": [],
            "achievements": [],
            "portfolio": "",
        }

def _build_job_context(job_post_row: Dict[str, Any]) -> Dict[str, Any]:
    if not job_post_row:
        return {}
    return {
        "job_title": job_post_row.get("job_title") or job_post_row.get("title") or "",
        "company": job_post_row.get("company") or job_post_row.get("employer") or "",
        "job_overview": _stringify(job_post_row.get("job_overview")),
        "job_skills": _coerce_to_list(job_post_row.get("job_skills")),
        "experience_req": _stringify(job_post_row.get("job_experience")),
        "education_req": _stringify(job_post_row.get("job_education")),
        "licenses_req": _stringify(job_post_row.get("job_licenses_certifications")),
        "location": job_post_row.get("location") or "",
        "seniority": job_post_row.get("seniority") or "",
    }

def _llm_batch_explain_skills(
    skills: List[str],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
) -> Dict[str, str]:
    skills = [s for s in skills if s]
    if not skills:
        return {}

    provider = _select_provider()

    # Fallback: deterministic, non-LLM
    if provider == "none":
        return {
            s: f"{s}: The job requires '{s}', which appears in the candidate’s profile. "
               f"This suggests relevant exposure the employer is seeking."
            for s in skills
        }

    prompt = _compose_skill_prompt(skills, job_ctx, seeker_ctx)

    try:
        if provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel(
                GEMINI_MODEL,
                generation_config={"temperature": 0.2, "response_mime_type": "application/json"},
            )
            resp = model.generate_content(prompt)
            text = (resp.text or "").strip()
        else:
            from openai import OpenAI
            client = OpenAI(api_key=OPENAI_API_KEY)
            resp = client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
            )
            text = (resp.choices[0].message.content or "").strip()

        parsed = _safe_parse_json_map(text)
        return {k: _trim_to_two_sentences(v) for k, v in parsed.items() if k in skills} or {
            s: _trim_to_two_sentences(f"{s}: The candidate shows context relevant to '{s}' based on profile vs job needs.")
            for s in skills
        }
    except Exception:
        return {
            s: f"{s}: The job requires '{s}', and the candidate lists or demonstrates it in prior work/education."
            for s in skills
        }

def _llm_overall_summary(
    confidence: float,
    section_scores: Dict[str, float],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
    matched: List[str],
    missing: List[str],
) -> str:
    provider = _select_provider()

    def _fallback() -> str:
        parts: List[str] = []
        strong = [k for k, v in (section_scores or {}).items() if isinstance(v, (int, float)) and v >= 80]
        if strong:
            parts.append(f"High semantic similarity in {', '.join(strong)} drove the score.")
        if matched:
            parts.append(f"Exact matches found for: {', '.join(matched[:5])}.")
        else:
            parts.append("No exact keyword matches were found; the score comes from semantic overlap between your background and the role’s requirements.")
        parts.append(f"Overall confidence is {round(confidence, 2)} based on weighted vector similarity across sections.")
        return " ".join(parts)

    if provider == "none":
        return _fallback()

    prompt = _compose_overall_prompt(confidence, section_scores, job_ctx, seeker_ctx, matched, missing)
    try:
        if provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel(
                GEMINI_MODEL,
                generation_config={"temperature": 0.2, "response_mime_type": "application/json"},
            )
            resp = model.generate_content(prompt)
            text = (resp.text or "").strip()
        else:
            from openai import OpenAI
            client = OpenAI(api_key=OPENAI_API_KEY)
            resp = client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
            )
            text = (resp.choices[0].message.content or "").strip()

        data = _safe_parse_json_map(text)
        summary = (data.get("overall_summary") or "").strip()
        return _trim_to_two_sentences(summary) if summary else _fallback()
    except Exception:
        return _fallback()

def match_and_enrich(
    *,
    job_seeker_id: str,
    top_k_per_section: int = 20,
    include_details: bool = False,
    min_sections: int = 1,
    include_explanations: bool = False,
    weights: Optional[Dict[str, float]] = None,
) -> List[Dict[str, Any]]:
    """
    High-level service used by the endpoint:
      1) rank posts (Pinecone + optional reranker)
      2) attach required-vs-seeker skill analysis
      3) (optional) LLM per-skill explanations + overall summary
    """
    ranked = rank_posts_for_seeker(
        job_seeker_id=job_seeker_id,
        top_k_per_section=top_k_per_section,
        weights=weights,
        include_job_details=True,
        min_sections=min_sections,
    )

    if not ranked:
        return []

    seeker_skills = _fetch_seeker_skills(job_seeker_id)
    seeker_ctx = _fetch_seeker_context(job_seeker_id) if include_explanations else {}

    # Pull analyzer here to avoid circular imports at module import time
    from .skill_utils import analyze_required_vs_seeker
    from .data_storer import persist_matcher_results

    out: List[Dict[str, Any]] = []
    for r in ranked:
        jp = r.get("job_post") or {}
        required = _coerce_to_list(jp.get("job_skills"))
        analysis = analyze_required_vs_seeker(required, seeker_skills)

        if include_explanations:
            job_ctx = _build_job_context(jp)
            matched = analysis.get("matched_skills", []) or []
            missing = analysis.get("missing_skills", []) or []

            if matched:
                explanations = _llm_batch_explain_skills(matched, job_ctx, seeker_ctx)
                explanations = {k: v for k, v in explanations.items() if k in matched}
                if explanations:
                    analysis["matched_explanations"] = explanations

            overall = _llm_overall_summary(
                confidence=float(r.get("confidence", 0.0)),
                section_scores=r.get("section_scores", {}) or {},
                job_ctx=job_ctx,
                seeker_ctx=seeker_ctx,
                matched=matched,
                missing=missing,
            )
            if overall:
                analysis["overall_summary"] = overall

        r["analysis"] = analysis

        if not include_details:
            r = dict(r)  # shallow copy before mutating
            r.pop("job_post", None)

        out.append(r)

    try:
        persist_matcher_results(
            auth_user_id=None,          # or pass through from API layer
            job_seeker_id=job_seeker_id,
            matcher_results=out,
            default_weights=weights,
            method="pinecone+rerank" if RERANK_ENABLE else "pinecone",
            model_version=f"{RERANK_MODEL if RERANK_ENABLE else 'pinecone-only'}|{OPENAI_MODEL or GEMINI_MODEL}"
        )
    except Exception as e:
        print(f"[WARN] Failed to persist matcher results: {e}")

    return out

__all__ = [
    # Proxies & constants
    "SB", "VALID_SCOPES", "DEFAULT_WEIGHTS", "SEEKER_NS", "POST_NS",
    # Ranking services
    "rank_posts_for_seeker", "rank_posts_for_seeker_by_email", "get_seeker_id_by_email",
    # High-level orchestration (endpoint should call this)
    "match_and_enrich",
]

# ---------------------- CLI (optional) ----------------------
def _parse_argv(argv: List[str]) -> Dict[str, Any]:
    """
    Minimal CLI:
      python matcher.py <job_seeker_id> [top_k] [include_details:0|1] [min_sections]
    """
    if not argv:
        raise SystemExit(
            "Usage: python matcher.py <job_seeker_id> [top_k_per_section=20] [include_details=0|1] [min_sections=1]"
        )
    out: Dict[str, Any] = {"job_seeker_id": argv[0]}
    out["top_k"] = int(argv[1]) if len(argv) > 1 else 20
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
