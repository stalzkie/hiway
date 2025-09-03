# apps/backend/services/matcher.py
from __future__ import annotations

import os
import sys
from typing import Dict, List, Any, Iterable, Optional, Tuple

from pinecone import Pinecone
from supabase import create_client, Client

# ---------------------- Config / Clients ----------------------
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
PINECONE_INDEX = os.getenv("PINECONE_INDEX")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not (PINECONE_API_KEY and PINECONE_INDEX and SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY):
    missing = [k for k, v in {
        "PINECONE_API_KEY": PINECONE_API_KEY,
        "PINECONE_INDEX": PINECONE_INDEX,
        "SUPABASE_URL": SUPABASE_URL,
        "SUPABASE_SERVICE_ROLE_KEY": SUPABASE_SERVICE_ROLE_KEY
    }.items() if not v]
    raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")

PC = Pinecone(api_key=PINECONE_API_KEY)
INDEX = PC.Index(PINECONE_INDEX)

SB: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

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

# ---------------------- Helpers ----------------------
def _effective_weights(weights: Optional[Dict[str, float]]) -> Dict[str, float]:
    """Validate and return usable weights for all scopes."""
    if not weights:
        return DEFAULT_WEIGHTS.copy()
    out = {}
    for s in VALID_SCOPES:
        out[s] = float(weights.get(s, DEFAULT_WEIGHTS[s]))
    return out

def get_seeker_vectors(job_seeker_id: str, scopes: Iterable[str] = VALID_SCOPES) -> Dict[str, List[float]]:
    """
    Fetch the seeker's section vectors from Pinecone.
    Returns only sections found and non-empty.
    """
    ids = [f"{job_seeker_id}:{s}" for s in scopes]
    fetch_res = INDEX.fetch(ids=ids, namespace=SEEKER_NS)
    vectors: Dict[str, List[float]] = {}
    for vid, payload in (getattr(fetch_res, "vectors", None) or {}).items():
        try:
            scope = vid.split(":")[1]
        except Exception:
            continue
        if scope in VALID_SCOPES:
            vals = payload.get("values") or []
            if vals:
                vectors[scope] = vals
    return vectors

def _query_section(scope: str, vector: List[float], top_k: int = 20) -> List[Dict[str, Any]]:
    """
    Query job_posts for a single section vector and return Pinecone matches.
    Each returned id is expected to be 'job_post_id:scope'.
    """
    if not vector:
        return []
    res = INDEX.query(
        vector=vector,
        top_k=top_k,
        namespace=POST_NS,
        filter={"scope": {"$eq": scope}},
        include_metadata=True
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
            "section_scores": section_scores_out
        })

    ranked.sort(key=lambda d: d["confidence"], reverse=True)
    return ranked

# ---------------------- Public service functions ----------------------
def rank_posts_for_seeker(
    job_seeker_id: str,
    top_k_per_section: int = 20,
    weights: Optional[Dict[str, float]] = None,
    include_job_details: bool = False,
    min_sections: int = 1,
) -> List[Dict[str, Any]]:
    """Rank job posts for a seeker by aggregating cosine similarities across sections."""
    weights_eff = _effective_weights(weights)

    # 1) Seeker vectors
    seeker_vecs = get_seeker_vectors(job_seeker_id)
    if not seeker_vecs:
        return []

    # 2) Query posts per section
    section_results: Dict[str, List[Dict[str, Any]]] = {}
    for scope, vec in seeker_vecs.items():
        section_results[scope] = _query_section(scope, vec, top_k=top_k_per_section)

    # 3) Aggregate to weighted confidence
    ranked = _aggregate_scores(section_results, weights_eff, min_sections=min_sections)

    # 4) Optionally include job_post rows
    if include_job_details and ranked:
        pids = [r["job_post_id"] for r in ranked]
        details_map: Dict[str, Any] = {}
        CHUNK = 200
        for i in range(0, len(pids), CHUNK):
            chunk = pids[i:i+CHUNK]
            resp = SB.table("job_post").select("*").in_("job_post_id", chunk).execute()
            for row in (resp.data or []):
                details_map[str(row.get("job_post_id"))] = row
        for r in ranked:
            r["job_post"] = details_map.get(r["job_post_id"])

    return ranked

def get_seeker_id_by_email(email: str) -> Optional[str]:
    """Resolve a job_seeker_id from a seeker email. Returns None if not found."""
    resp = SB.table("job_seeker").select("job_seeker_id").eq("email", email).limit(1).execute()
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
    """Convenience wrapper: look up the seeker by email, then rank posts."""
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

__all__ = [
    "SB",
    "rank_posts_for_seeker",
    "rank_posts_for_seeker_by_email",
    "get_seeker_id_by_email",
    "VALID_SCOPES",
    "DEFAULT_WEIGHTS",
    "SEEKER_NS",
    "POST_NS",
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
