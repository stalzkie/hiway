# apps/backend/services/milestone_locator.py
from __future__ import annotations

import os
import json
import math
from typing import Any, Dict, List, Optional, Tuple

from supabase import create_client, Client
from apps.backend.services.data_storer import (
    store_seeker_milestone_status,
    _now_iso,
)

# --------------------------- Supabase client ---------------------------
_SUPABASE_URL = os.getenv("SUPABASE_URL")
_SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
if not _SUPABASE_URL or not _SUPABASE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

_sb: Client = create_client(_SUPABASE_URL, _SUPABASE_KEY)

# --------------------------- Scoring params ---------------------------
PASS_GATE = float(os.getenv("MILESTONE_PASS_GATE", 0.60))
GAP_MIN = int(os.getenv("MILESTONE_GAP_MIN", 3))  # min gaps when score < 60%

LEVEL_BANDS: List[Tuple[str, float, float]] = [
    ("Beginner", 0.0, 0.40),
    ("Intermediate", 0.40, 0.70),
    ("Advanced", 0.70, 1.01),
]

# --------------------------- Helpers ---------------------------
def _band_for(score01: float) -> str:
    for name, lo, hi in LEVEL_BANDS:
        if lo <= score01 < hi:
            return name
    return "Beginner"

def _fetch_roadmap(roadmap_id: Optional[str], job_seeker_id: str, role: str) -> Dict[str, Any]:
    if roadmap_id:
        r = (
            _sb.table("role_roadmaps")
            .select("roadmap_id, job_seeker_id, role, milestones, created_at")
            .eq("roadmap_id", roadmap_id)
            .limit(1)
            .execute()
        )
    else:
        r = (
            _sb.table("role_roadmaps")
            .select("roadmap_id, job_seeker_id, role, milestones, created_at")
            .eq("job_seeker_id", job_seeker_id)
            .eq("role", role)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
    road = (r.data or [None])[0]
    if not road:
        raise RuntimeError("No roadmap found for seeker+role")
    return road

def _fetch_seeker_profile(job_seeker_id: str) -> Tuple[Dict[str, Any], Optional[str]]:
    sres = (
        _sb.table("job_seeker")
        .select("skills, experience, education, licenses_certifications, updated_at")
        .eq("job_seeker_id", job_seeker_id)
        .limit(1)
        .execute()
    )
    seeker = (sres.data or [{}])[0]
    updated_at = seeker.get("updated_at")
    # Ensure arrays exist
    for k in ("skills", "experience", "education", "licenses_certifications"):
        seeker[k] = seeker.get(k) or []
    return seeker, updated_at

def _fetch_latest_snapshot_time(job_seeker_id: str, role: str, roadmap_id: str) -> Optional[str]:
    res = (
        _sb.table("seeker_milestone_status")
        .select("calculated_at")
        .eq("job_seeker_id", job_seeker_id)
        .eq("role", role)
        .eq("roadmap_id", roadmap_id)
        .order("calculated_at", desc=True)
        .limit(1)
        .execute()
    )
    row = (res.data or [None])[0]
    return row["calculated_at"] if row else None

# --------------------------- String/Vector utils ---------------------------
def _to_text(x: Any) -> str:
    if isinstance(x, str):
        return x
    if isinstance(x, dict):
        try:
            return " ".join(str(v) for v in x.values() if v is not None)
        except Exception:
            return str(x)
    if isinstance(x, (list, tuple, set)):
        try:
            return " ".join(_to_text(v) for v in x)
        except Exception:
            return str(x)
    return str(x)

def _norm(s: Any) -> str:
    t = _to_text(s)
    return t.strip().lower()

def _flatten_user_knowledge(seeker: Dict[str, Any]) -> List[str]:
    """
    Flatten *only* these sources into canonical tokens:
    - skills
    - experience
    - education
    - licenses_certifications
    """
    parts: List[str] = []
    for k in ("skills", "experience", "education", "licenses_certifications"):
        parts.extend([_to_text(x) for x in (seeker.get(k) or [])])

    # split comma-separated strings
    split_parts: List[str] = []
    for p in parts:
        if "," in p:
            split_parts.extend([_to_text(x) for x in p.split(",")])
        else:
            split_parts.append(p)

    # dedupe + clean
    seen = set()
    out: List[str] = []
    for s in split_parts:
        ns = _norm(s)
        if ns and ns not in seen:
            seen.add(ns)
            out.append(ns)
    return out

def _cosine_from_sets(a_items: List[str], b_items: List[str]) -> float:
    """
    Binary cosine similarity between two lists of canonical strings.
    """
    a_set = set([_norm(x) for x in a_items if x])
    b_set = set([_norm(x) for x in b_items if x])
    if not a_set or not b_set:
        return 0.0
    inter = len(a_set & b_set)
    denom = math.sqrt(len(a_set)) * math.sqrt(len(b_set))
    return float(inter) / float(denom) if denom else 0.0

def _clamp01(x: float) -> float:
    try:
        xf = float(x)
    except Exception:
        return 0.0
    return 0.0 if xf < 0 else (1.0 if xf > 1.0 else xf)

def _avg(vals: List[float]) -> float:
    return sum(vals) / len(vals) if vals else 0.0

# --------------------------- Milestone knowledge extraction ---------------------------
def _milestone_knowledge_text(ms: Dict[str, Any]) -> str:
    """
    Prefer explicit knowledge/content fields if present; otherwise
    build a knowledge blob from skills/outcomes/certs/title.
    """
    blobs: List[str] = []
    for k in ("knowledge", "content", "body", "description"):
        if ms.get(k):
            blobs.append(_to_text(ms.get(k)))

    # fallbacks / enrichers
    for k in ("skills", "outcomes", "cert_names"):
        if ms.get(k):
            blobs.append(_to_text(ms.get(k)))

    if ms.get("title") or ms.get("milestone"):
        blobs.append(str(ms.get("title") or ms.get("milestone")))

    return _to_text(blobs)

def _milestone_keywords(ms: Dict[str, Any]) -> List[str]:
    """
    Keywords used for cosine backstop. Use any structured lists if present.
    """
    keys: List[str] = []
    for k in ("knowledge_keywords", "skills", "outcomes", "cert_names"):
        if ms.get(k):
            vals = ms.get(k)
            if isinstance(vals, list):
                keys.extend([_to_text(x) for x in vals])
            else:
                keys.append(_to_text(vals))
    # de-dupe normalized
    seen = set()
    out: List[str] = []
    for s in keys:
        ns = _norm(s)
        if ns and ns not in seen:
            seen.add(ns)
            out.append(ns)
    return out

# --------------------------- LLM prompt & call ---------------------------
def _mk_prompt(seeker: Dict[str, Any], milestones: List[Dict[str, Any]]) -> str:
    """
    Constrained JSON-only prompt. Compares ONLY these job_seeker fields:
      - skills
      - licenses_certifications
      - experience
      - education
    Against the *knowledge content* of each milestone.

    Critical rule:
    • When scoring milestone at index i, ASSUME milestones [0..i-1] are already achieved by the seeker.
      Evaluate only the incremental knowledge expected at milestone i, not what earlier milestones cover.
    """
    flat = _flatten_user_knowledge(seeker)

    payload = {
        "user_profile": {
            "skills": seeker.get("skills") or [],
            "experience": seeker.get("experience") or [],
            "education": seeker.get("education") or [],
            "licenses_certifications": seeker.get("licenses_certifications") or [],
            "flat_user_knowledge": flat,
        },
        "milestones": [
            {
                "index": i,
                "title": m.get("title") or m.get("milestone"),
                "knowledge_text": _milestone_knowledge_text(m),
                "prior_titles": [
                    (milestones[j].get("title") or milestones[j].get("milestone"))
                    for j in range(0, i)
                ],
            }
            for i, m in enumerate(milestones or [])
        ],
        "rubric": {
            "gap_threshold": 0.5,
            "gap_min_when_score_below": {"threshold_pct": 60, "min_gaps": GAP_MIN},
        },
    }

    return (
        "You are an expert career assessor. OUTPUT STRICT JSON ONLY (no markdown, no commentary).\n"
        "Compare ONLY the job seeker's: skills, licenses & certifications, experience, education\n"
        "to each milestone's KNOWLEDGE TEXT.\n"
        "Assume that for milestone i, ALL prior milestones [0..i-1] are already achieved by the seeker.\n"
        "Evaluate only the additional/next knowledge expected at milestone i.\n"
        "For each milestone, produce:\n"
        "  - score_pct (0..100)\n"
        "  - matched_evidence: array of {\"item\",\"source\"} where source in {\"skills\",\"experience\",\"education\",\"licenses\"}\n"
        "  - gaps: array of \"items\" representing missing knowledge for that milestone (post-assumption)\n"
        "  - rationale: 1–2 sentences explaining the score in light of the assumption\n"
        f"IMPORTANT: If score_pct < 60, include at least {GAP_MIN} gap items.\n"
        "Return JSON with exactly these top-level keys: milestones_scored.\n\n"
        f"{json.dumps(payload, ensure_ascii=False)}"
    )

def _select_provider() -> str:
    provider = (os.getenv("LLM_PROVIDER") or "auto").lower()
    if provider == "auto":
        if os.getenv("GEMINI_API_KEY"):
            return "gemini"
        elif os.getenv("OPENAI_API_KEY"):
            return "openai"
        else:
            raise RuntimeError("No LLM API key found. Set GEMINI_API_KEY or OPENAI_API_KEY.")
    return provider

def _call_llm(prompt: str) -> Dict[str, Any]:
    provider = _select_provider()
    if provider == "openai":
        from openai import OpenAI
        client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        resp = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content or "{}"
        return json.loads(content)
    elif provider == "gemini":
        import google.generativeai as genai
        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
        model = genai.GenerativeModel(os.getenv("GEMINI_MODEL", "gemini-1.5-pro"))
        resp = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.1,
                "response_mime_type": "application/json",
            },
        )
        text = resp.text or "{}"
        try:
            return json.loads(text)
        except Exception:
            first = text.find("{")
            last = text.rfind("}")
            if first >= 0 and last >= 0 and last > first:
                return json.loads(text[first:last+1])
            raise
    else:
        raise RuntimeError(f"Unsupported LLM_PROVIDER: {provider}")

# --------------------------- Normalization helpers ---------------------------
def _to_list(val: Any) -> List[Any]:
    if val is None:
        return []
    if isinstance(val, list):
        return val
    if isinstance(val, dict):
        return [val]
    return [val]

def _coerce_item(obj: Any) -> Optional[Dict[str, Any]]:
    if isinstance(obj, dict):
        item = obj.get("item")
        source = obj.get("source")
        if item is None:
            return None
        return {"item": str(item), "source": str(source) if source else None}
    if isinstance(obj, str):
        return {"item": obj, "source": None}
    return None

def _normalize_matched(val: Any) -> List[Dict[str, Any]]:
    items = _to_list(val)
    out: List[Dict[str, Any]] = []
    for elem in items:
        coerced = _coerce_item(elem)
        if coerced:
            out.append(coerced)
    return out

def _normalize_gaps(val: Any) -> List[Dict[str, Any]]:
    items = _to_list(val)
    out: List[Dict[str, Any]] = []
    for elem in items:
        if isinstance(elem, dict):
            it = elem.get("item") or elem.get("name") or elem.get("topic")
            if it:
                out.append({"item": str(it)})
        elif isinstance(elem, str):
            out.append({"item": elem})
    return out

def _ensure_gap_min(row: Dict[str, Any], ms_keywords: List[str]) -> None:
    try:
        score = float(row.get("score_pct", 0.0))
    except Exception:
        score = 0.0
    gaps = _normalize_gaps(row.get("gaps"))

    if score < 60.0 and len(gaps) < GAP_MIN:
        # backfill from milestone keywords not already listed
        already = set(_norm(g.get("item")) for g in gaps)
        for kw in ms_keywords:
            if _norm(kw) not in already:
                gaps.append({"item": kw})
                already.add(_norm(kw))
                if len(gaps) >= GAP_MIN:
                    break

    row["gaps"] = gaps

# --------------------------- Finalization & selection ---------------------------
def _finalize_scored(scored: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out = []
    for idx, row in enumerate(scored or []):
        try:
            sp = float(row.get("score_pct", 0.0))
        except Exception:
            sp = 0.0
        row["score_pct"] = round(sp, 2)
        row["index"] = int(row.get("index", idx))
        row["title"] = row.get("title") or ""
        row["rationale"] = row.get("rationale") or ""
        row["matched_evidence"] = _normalize_matched(row.get("matched_evidence"))
        row["gaps"] = _normalize_gaps(row.get("gaps"))
        out.append(row)
    out.sort(key=lambda r: r.get("index", 0))
    return out

def _pick_current_next(scored: List[Dict[str, Any]]) -> Tuple[int, int]:
    current_idx = 0
    for r in scored:
        if (r.get("score_pct", 0.0) / 100.0) >= PASS_GATE:
            current_idx = r["index"]
    next_idx = min(current_idx + 1, max(0, len(scored) - 1))
    return current_idx, next_idx

# --------------------------- Public entrypoint ---------------------------
def locate_milestone_with_llm(
    *,
    job_seeker_id: str,
    role: str,
    roadmap_id: Optional[str] = None,
    force: bool = False,
    model_version: Optional[str] = None,
) -> Dict[str, Any]:
    """
    LLM-based evaluation:
      • Compares ONLY seeker skills/experience/education/licenses to the milestone's knowledge content.
      • For milestone i, LLM ASSUMES milestones [0..i-1] are already achieved (cumulative progression).
    """
    road = _fetch_roadmap(roadmap_id, job_seeker_id, role)
    roadmap_id = road["roadmap_id"]
    milestones: List[Dict[str, Any]] = list(road.get("milestones") or [])

    seeker, seeker_updated_at = _fetch_seeker_profile(job_seeker_id)
    latest_calc = _fetch_latest_snapshot_time(job_seeker_id, role, roadmap_id)

    should_compute = force or (latest_calc is None) or (
        seeker_updated_at and latest_calc and str(seeker_updated_at) > str(latest_calc)
    )

    if not should_compute:
        res = (
            _sb.table("seeker_milestone_status")
            .select("*")
            .eq("job_seeker_id", job_seeker_id)
            .eq("role", role)
            .eq("roadmap_id", roadmap_id)
            .order("calculated_at", desc=True)
            .limit(1)
            .execute()
        )
        return (res.data or [None])[0]

    # -------- LLM call (assume prior milestones achieved for each row) --------
    prompt = _mk_prompt(seeker, milestones)
    raw = _call_llm(prompt)

    # Normalize & finalize
    milestones_scored = _finalize_scored(raw.get("milestones_scored") or [])

    # Hybrid backstop: light cosine against milestone keywords (defensive)
    flat_user = _flatten_user_knowledge(seeker)
    for row in milestones_scored:
        idx = row.get("index", 0)
        ms = milestones[idx] if 0 <= idx < len(milestones) else {}
        ms_title = ms.get("title") or ms.get("milestone") or f"Milestone {idx}"
        ms_keys = _milestone_keywords(ms)

        # cosine backstop (0..1) -> pct
        cos_sim = _cosine_from_sets(flat_user, ms_keys) if ms_keys else 0.0
        cos_pct = 100.0 * cos_sim

        # take the protective maximum of LLM score and cosine backstop
        try:
            llm_pct = float(row.get("score_pct", 0.0))
        except Exception:
            llm_pct = 0.0

        row["score_pct"] = round(max(llm_pct, cos_pct), 2)
        row["title"] = ms_title

        # enforce min gaps when score low
        _ensure_gap_min(row, ms_keys)

    # Decide current/next
    current_idx, next_idx = _pick_current_next(milestones_scored)
    current = milestones_scored[current_idx] if milestones_scored else None
    next_m = milestones_scored[next_idx] if milestones_scored else None

    current01 = (current["score_pct"] / 100.0) if current else 0.0
    next01 = (next_m["score_pct"] / 100.0) if next_m else 0.0

    current_level = _band_for(current01)
    next_level = _band_for(next01)

    weights_meta = {
        "engine": "llm(assume-prior-achieved)+cosine-backstop",
        "pass_gate": PASS_GATE,
        "gap_min": GAP_MIN,
    }

    snapshot = store_seeker_milestone_status(
        job_seeker_id=job_seeker_id,
        role=role,
        roadmap_id=roadmap_id,
        auth_user_id=None,
        current_milestone=current.get("title") if current else None,
        current_level=current_level,
        current_score_pct=current.get("score_pct") if current else 0.0,
        next_milestone=next_m.get("title") if next_m else None,
        next_level=next_level,
        gaps=current.get("gaps") if current else [],
        milestones_scored=milestones_scored,
        weights=weights_meta,
        model_version=model_version or "llm-assume-prior-achieved-v1",
        low_confidence=(current01 < PASS_GATE),
        calculated_at_iso=_now_iso(),
    )
    return snapshot
