# apps/backend/services/data_storer.py
from __future__ import annotations

import os
import json
import hashlib
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from supabase import create_client, Client


# ---------------------------
# Supabase client (eager)
# ---------------------------
_SUPABASE_URL = os.getenv("SUPABASE_URL")
_SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")  # Service role (backend only)

if not _SUPABASE_URL or not _SUPABASE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

_sb: Client = create_client(_SUPABASE_URL, _SUPABASE_KEY)


# ---------------------------
# Small utils
# ---------------------------
def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json_stable(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def _sha256_blob(blob: str) -> str:
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _sha256_json(obj: Any) -> str:
    return _sha256_blob(_json_stable(obj))


def _ensure_list(v: Optional[List[Any]]) -> List[Any]:
    return v if isinstance(v, list) else []


def _ensure_dict(v: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    return v if isinstance(v, dict) else {}


# =========================================================
#                 MATCH SCORE SNAPSHOTS
# =========================================================
def store_match_score(
    *,
    job_seeker_id: str,
    job_post_id: str,
    auth_user_id: Optional[str],
    confidence: float,
    section_scores: Dict[str, float],
    weights: Dict[str, float],
    rerank_enabled: bool = False,
    method: Optional[str] = "pinecone",
    model_version: Optional[str] = None,
    matched_skills: Optional[List[str]] = None,
    missing_skills: Optional[List[str]] = None,
    matched_explanations: Optional[Dict[str, str]] = None,
    overall_summary: Optional[str] = None,
    calculated_at_iso: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Inserts ONE snapshot into job_match_scores.
    Your DB trigger should update job_match_scores_cache automatically (newest wins).
    Returns the inserted row (or the row payload if PostgREST returns empty).
    """
    row = {
        "job_seeker_id": job_seeker_id,
        "job_post_id": job_post_id,
        "auth_user_id": auth_user_id,
        "confidence": round(float(confidence), 2),
        "section_scores": _ensure_dict(section_scores),
        "weights": _ensure_dict(weights),
        "rerank_enabled": bool(rerank_enabled),
        "method": method,
        "model_version": model_version,
        "calculated_at": calculated_at_iso or _now_iso(),
        "matched_skills": _ensure_list(matched_skills),
        "missing_skills": _ensure_list(missing_skills),
        "matched_explanations": _ensure_dict(matched_explanations),
        "overall_summary": overall_summary,
    }
    res = _sb.table("job_match_scores").insert(row).execute()
    return (res.data or [row])[0]


def store_match_scores_bulk(
    *,
    auth_user_id: Optional[str],
    job_seeker_id: str,
    items: List[Dict[str, Any]],
    default_weights: Optional[Dict[str, float]] = None,
    method: Optional[str] = "pinecone",
    model_version: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Bulk helper: items = list of results from matcher (one per job_post).
    Each item may contain: job_post_id, confidence, section_scores, analysis{...}
    """
    rows: List[Dict[str, Any]] = []
    for it in items or []:
        analysis = _ensure_dict(it.get("analysis"))
        rows.append(
            {
                "job_seeker_id": job_seeker_id,
                "job_post_id": it["job_post_id"],
                "auth_user_id": auth_user_id,
                "confidence": round(float(it["confidence"]), 2),
                "section_scores": _ensure_dict(it.get("section_scores")),
                "weights": _ensure_dict(it.get("weights") or default_weights or {}),
                "rerank_enabled": bool(it.get("rerank_enabled", False)),
                "method": method,
                "model_version": model_version,
                "calculated_at": _now_iso(),
                "matched_skills": _ensure_list(analysis.get("matched_skills")),
                "missing_skills": _ensure_list(analysis.get("missing_skills")),
                "matched_explanations": _ensure_dict(analysis.get("matched_explanations")),
                "overall_summary": analysis.get("overall_summary"),
            }
        )
    if not rows:
        return []
    res = _sb.table("job_match_scores").insert(rows).execute()
    return res.data or rows


# =========================================================
#                    ROLE ROADMAP (MASTER)
# =========================================================
def _roadmap_prompt_hash(
    *,
    job_seeker_id: str,
    role: str,
    provider: str,
    model: str,
    prompt_template: Optional[str],
    cert_allowlist: List[str],
) -> str:
    """
    Deterministic hash for a roadmap definition. Including job_seeker_id makes
    the cache distinct per seeker (since roadmaps are seeker-scoped for you).
    """
    payload = {
        "job_seeker_id": (job_seeker_id or "").strip().lower(),
        "role": (role or "").strip().lower(),
        "provider": (provider or "").strip().lower(),
        "model": (model or "").strip().lower(),
        "prompt_template": (prompt_template or "").strip(),
        "cert_allowlist": sorted([str(c).strip().lower() for c in (cert_allowlist or [])]),
    }
    return _sha256_json(payload)


def get_or_create_role_roadmap(
    *,
    job_seeker_id: str,
    role: str,
    provider: str,
    model: str,
    milestones: List[Dict[str, Any]],
    prompt_template: Optional[str],
    cert_allowlist: Optional[List[str]],
    expires_at_iso: Optional[str] = None,
) -> Tuple[str, Dict[str, Any]]:
    """
    Upsert a seeker-scoped roadmap keyed by (job_seeker_id, role, prompt_hash).
    Returns (roadmap_id, row).
    """
    allowlist = _ensure_list(cert_allowlist)
    phash = _roadmap_prompt_hash(
        job_seeker_id=job_seeker_id,
        role=role,
        provider=provider,
        model=model,
        prompt_template=prompt_template,
        cert_allowlist=allowlist,
    )
    ahash = _sha256_json(allowlist)

    payload = {
        "job_seeker_id": job_seeker_id,
        "role": role,
        "provider": provider,
        "model": model,
        "milestones": _ensure_list(milestones),
        "prompt_template": prompt_template,
        "cert_allowlist": allowlist,
        "prompt_hash": phash,         # <<< REQUIRED (NOT NULL)
        "allowlist_hash": ahash,      # optional but useful
        "expires_at": expires_at_iso,
    }

    # Upsert based on unique combo; supabase-py v2 returns rows directly
    res = (
        _sb.table("role_roadmaps")
        .upsert(payload, on_conflict=["job_seeker_id", "role", "prompt_hash"])
        .execute()
    )
    row = (res.data or [payload])[0]

    roadmap_id = row.get("roadmap_id")
    if not roadmap_id:
        # Safety fetch (shouldn't normally happen if DB returns inserted row)
        res2 = (
            _sb.table("role_roadmaps")
            .select("roadmap_id")
            .eq("job_seeker_id", job_seeker_id)
            .eq("role", role)
            .eq("prompt_hash", phash)
            .limit(1)
            .execute()
        )
        roadmap_id = (res2.data or [{}])[0].get("roadmap_id")
        row["roadmap_id"] = roadmap_id
    return roadmap_id, row


# =========================================================
#                 ROADMAP RESOURCES (PER MILESTONE)
# =========================================================
def upsert_roadmap_resources(
    *,
    roadmap_id: str,
    job_seeker_id: str,
    milestone_index: int,
    resources: Optional[List[Dict[str, Any]]] = None,
    certifications: Optional[List[Dict[str, Any]]] = None,
    network_groups: Optional[List[Dict[str, Any]]] = None,
    fetched_at_iso: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Caches heavy SerpAPI results per milestone (unique on (roadmap_id, milestone_index)).
    Tracks job_seeker_id for convenience/partitioning.
    """
    row = {
        "roadmap_id": roadmap_id,
        "job_seeker_id": job_seeker_id,
        "milestone_index": int(milestone_index),
        "resources": _ensure_list(resources),
        "certifications": _ensure_list(certifications),
        "network_groups": _ensure_list(network_groups),
        "fetched_at": fetched_at_iso or _now_iso(),
    }
    res = (
        _sb.table("roadmap_resources")
        .upsert(row, on_conflict=["roadmap_id", "milestone_index"])
        .execute()
    )
    return (res.data or [row])[0]


# =========================================================
#            SEEKER MILESTONE STATUS SNAPSHOTS
# =========================================================
def store_seeker_milestone_status(
    *,
    job_seeker_id: str,
    role: str,
    roadmap_id: Optional[str],
    auth_user_id: Optional[str],
    current_milestone: Optional[str],
    current_level: Optional[str],
    current_score_pct: Optional[float],
    next_milestone: Optional[str],
    next_level: Optional[str],
    gaps: Optional[List[Any]],
    milestones_scored: List[Dict[str, Any]],
    weights: Dict[str, Any],
    model_version: Optional[str] = None,
    low_confidence: bool = False,
    calculated_at_iso: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Inserts ONE snapshot row describing where the seeker currently is in the roadmap.

    Notes:
    - `milestones_scored` may include ETA fields per milestone:
        eta_hours (float), eta_text (str), eta_confidence (float 0..1)
    - `weights` may include an `eta_summary` array for unfinished milestones.
    """
    row = {
        "job_seeker_id": job_seeker_id,
        "role": role,
        "roadmap_id": roadmap_id,
        "auth_user_id": auth_user_id,
        "current_milestone": current_milestone,
        "current_level": current_level,
        "current_score_pct": None if current_score_pct is None else round(float(current_score_pct), 2),
        "low_confidence": bool(low_confidence),
        "next_milestone": next_milestone,
        "next_level": next_level,
        "gaps": _ensure_list(gaps),
        "milestones_scored": _ensure_list(milestones_scored),
        "weights": _ensure_dict(weights),
        "model_version": model_version,
        "calculated_at": calculated_at_iso or _now_iso(),
    }
    res = _sb.table("seeker_milestone_status").insert(row).execute()
    return (res.data or [row])[0]


# =========================================================
#         Convenience: end-to-end helpers for pipelines
# =========================================================
def persist_matcher_results(
    *,
    auth_user_id: Optional[str],
    job_seeker_id: str,
    matcher_results: List[Dict[str, Any]],
    default_weights: Optional[Dict[str, float]] = None,
    method: str = "pinecone",
    model_version: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Drop-in for matcher.py outputs (e.g., from match_and_enrich or
    rank_posts_for_seeker + your analysis):
    Each result must include: job_post_id, confidence, section_scores,
    analysis{matched_skills, missing_skills, ...}
    """
    return store_match_scores_bulk(
        auth_user_id=auth_user_id,
        job_seeker_id=job_seeker_id,
        items=matcher_results,
        default_weights=default_weights,
        method=method,
        model_version=model_version,
    )


def persist_scraper_roadmap_with_resources(
    *,
    job_seeker_id: str,
    role: str,
    provider: str,
    model: str,
    milestones: List[Dict[str, Any]],
    prompt_template_or_hashable: Any,
    cert_allowlist_or_hashable: Any,
    milestone_resources: List[
        Tuple[
            List[Dict[str, Any]],  # resources
            List[Dict[str, Any]],  # certifications
            List[Dict[str, Any]],  # network_groups
        ]
    ],
) -> str:
    """
    Store a roadmap + resources in Supabase, linked to a job_seeker_id and a role.
    Returns the generated roadmap_id (UUID provided by DB default or returned by upsert).
    """
    # Normalize inputs
    prompt_template = (
        prompt_template_or_hashable
        if isinstance(prompt_template_or_hashable, str)
        else _json_stable(prompt_template_or_hashable)
    )
    cert_allowlist = (
        list(cert_allowlist_or_hashable)
        if isinstance(cert_allowlist_or_hashable, (list, tuple, set))
        else [str(cert_allowlist_or_hashable)]
        if cert_allowlist_or_hashable is not None
        else []
    )

    # Compute hashes (REQUIRED: prompt_hash must be non-null)
    phash = _roadmap_prompt_hash(
        job_seeker_id=job_seeker_id,
        role=role,
        provider=provider,
        model=model,
        prompt_template=prompt_template,
        cert_allowlist=cert_allowlist,
    )
    ahash = _sha256_json(cert_allowlist)

    # Insert master row (let DB generate roadmap_id)
    try:
        master = (
            _sb.table("role_roadmaps")
            .insert(
                {
                    "job_seeker_id": job_seeker_id,
                    "role": role,
                    "provider": provider,
                    "model": model,
                    "milestones": _ensure_list(milestones),
                    "prompt_template": prompt_template,
                    "cert_allowlist": cert_allowlist,
                    "prompt_hash": phash,     # <<< satisfies NOT NULL
                    "allowlist_hash": ahash,
                }
            )
            .execute()
        )
        if getattr(master, "error", None):
            raise RuntimeError(master.error)
        roadmap_id = (master.data or [{}])[0].get("roadmap_id")
        if not roadmap_id:
            # Fallback fetch by unique key
            fetched = (
                _sb.table("role_roadmaps")
                .select("roadmap_id")
                .eq("job_seeker_id", job_seeker_id)
                .eq("role", role)
                .eq("prompt_hash", phash)
                .limit(1)
                .execute()
            )
            roadmap_id = (fetched.data or [{}])[0].get("roadmap_id")
        if not roadmap_id:
            raise RuntimeError("Failed to obtain roadmap_id after insert")
    except Exception as e:
        # Surface clear error for API layer
        raise RuntimeError(f"Failed to insert into role_roadmaps: {e}")

    # Insert per-milestone resources
    try:
        rows = []
        for idx, (res, certs, groups) in enumerate(milestone_resources):
            rows.append(
                {
                    "roadmap_id": roadmap_id,
                    "job_seeker_id": job_seeker_id,  # track seeker here too
                    "milestone_index": idx,
                    "resources": res or [],
                    "certifications": certs or [],
                    "network_groups": groups or [],
                    "fetched_at": _now_iso(),
                }
            )
        if rows:
            resp2 = _sb.table("roadmap_resources").insert(rows).execute()
            if getattr(resp2, "error", None):
                raise RuntimeError(resp2.error)
    except Exception as e:
        raise RuntimeError(f"Failed to insert into roadmap_resources: {e}")

    return roadmap_id
