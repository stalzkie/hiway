# apps/backend/services/orchestrator.py
from __future__ import annotations

import os
from typing import Dict, Any, Optional

from supabase import create_client

from .matcher import match_and_enrich, get_seeker_id_by_email
from .scraper import generate_and_store_roadmap
from .data_storer import persist_matcher_results
from .milestone_locator import locate_milestone_with_vectors  # <-- NEW

# ---------------- Supabase client ----------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
sb = create_client(SUPABASE_URL, SUPABASE_KEY)


# ---------------- Helpers ----------------
def _fetch_job_seeker(job_seeker_id: str) -> Optional[Dict[str, Any]]:
    """
    Fetch seeker; tolerate singular/plural table naming.
    """
    for tbl in ("job_seeker", "job_seeker"):
        resp = (
            sb.table(tbl)
            .select("*")
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
        if resp.data:
            return resp.data[0]
    return None


def _fetch_latest_match(job_seeker_id: str) -> Optional[Dict[str, Any]]:
    resp = (
        sb.table("job_match_scores_cache")
        .select("*")
        .eq("job_seeker_id", job_seeker_id)
        .order("calculated_at", desc=True)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _fetch_latest_status_for_role(job_seeker_id: str, role: str) -> Optional[Dict[str, Any]]:
    """
    Latest row from seeker_milestone_status (contains roadmap_id & computed fields).
    """
    resp = (
        sb.table("seeker_milestone_status")
        .select("*")
        .eq("job_seeker_id", job_seeker_id)
        .eq("role", role)
        .order("calculated_at", desc=True)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _fetch_roadmap_doc_by_id(roadmap_id: str) -> Optional[Dict[str, Any]]:
    resp = (
        sb.table("role_roadmaps")
        .select("roadmap_id, job_seeker_id, role, milestones, prompt_template, cert_allowlist, created_at, expires_at")
        .eq("roadmap_id", roadmap_id)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _fetch_latest_roadmap_doc_for_role(job_seeker_id: str, role: str) -> Optional[Dict[str, Any]]:
    resp = (
        sb.table("role_roadmaps")
        .select("roadmap_id, job_seeker_id, role, milestones, prompt_template, cert_allowlist, created_at, expires_at")
        .eq("job_seeker_id", job_seeker_id)
        .eq("role", role)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _profile_changed(seeker_row: Dict[str, Any], last_entry: Optional[Dict[str, Any]]) -> bool:
    """
    Naive check: if seeker's updated_at is newer than the last computed record, we recompute.
    Works for both job_match_scores_cache (calculated_at) and seeker_milestone_status (calculated_at).
    """
    if not seeker_row or not last_entry:
        return True
    seeker_time = seeker_row.get("updated_at")
    last_time = last_entry.get("calculated_at")
    if not seeker_time or not last_time:
        return True
    return seeker_time > last_time  # profile updated after last record


# ---------------- Orchestrator ----------------
def orchestrate_user_update(email: str, role: Optional[str] = None, force: bool = False) -> Dict[str, Any]:
    """
    Main orchestrator:
      1) Resolve job_seeker by email.
      2) Update matches if needed.
      3) Ensure a roadmap exists for the role (create if needed).
      4) Run vector-based milestone locator (idempotent: recomputes only if needed).
      5) Return the roadmap document + current milestone status (always).
    """
    job_seeker_id = get_seeker_id_by_email(email)
    if not job_seeker_id:
        return {"status": "error", "message": f"No job_seeker found for {email}"}

    seeker_row = _fetch_job_seeker(job_seeker_id)
    if not seeker_row:
        return {"status": "error", "message": f"Job seeker record missing for {email}"}

    # Use seeker’s target role unless caller specified a role explicitly
    target_role = role or seeker_row.get("target_role", "Generalist")

    # Latest cached artifacts
    last_match = _fetch_latest_match(job_seeker_id)
    last_status = _fetch_latest_status_for_role(job_seeker_id, target_role)

    needs_match_update = force or _profile_changed(seeker_row, last_match)
    # If no status exists, or profile changed since last status, or force: we need roadmap &/or relayout
    needs_roadmap_or_locate = force or (last_status is None) or _profile_changed(seeker_row, last_status)

    # -------- 2) Matcher update (job posts confidence snapshots) --------
    if needs_match_update:
        results = match_and_enrich(
            job_seeker_id=job_seeker_id,
            top_k_per_section=20,
            include_details=True,
            min_sections=1,
            include_explanations=True,
        )
        persist_matcher_results(
            auth_user_id=seeker_row.get("auth_user_id"),
            job_seeker_id=job_seeker_id,
            matcher_results=results,
            default_weights=None,
            method="pinecone+rerank",
            model_version="orchestrator",
        )
    else:
        results = []

    # -------- 3) Ensure roadmap exists (create if needed) --------
    # Prefer roadmap_id from last_status if present; otherwise fetch latest roadmap doc; otherwise create.
    roadmap_id: Optional[str] = (last_status or {}).get("roadmap_id")
    roadmap_doc: Optional[Dict[str, Any]] = None

    if not roadmap_id:
        roadmap_doc = _fetch_latest_roadmap_doc_for_role(job_seeker_id, target_role)
        roadmap_id = (roadmap_doc or {}).get("roadmap_id")

    if not roadmap_id:
        # No roadmap yet (or role changed) -> create one
        roadmap_id = generate_and_store_roadmap(
            job_seeker_id=job_seeker_id,
            role=target_role,
        )
        # We just created it; fetch the doc to return
        roadmap_doc = _fetch_roadmap_doc_by_id(roadmap_id)
        needs_roadmap_or_locate = True  # definitely locate after creation

    # Ensure we have the roadmap document to return
    if roadmap_doc is None and roadmap_id:
        roadmap_doc = _fetch_roadmap_doc_by_id(roadmap_id)

    # -------- 4) Locate current milestone (vector service; idempotent) --------
    # Even on cached runs, calling this is cheap: it will re-use the latest snapshot unless needed.
    milestone_status = locate_milestone_with_vectors(
        job_seeker_id=job_seeker_id,
        role=target_role,
        roadmap_id=roadmap_id,
        force=force or needs_roadmap_or_locate,
        model_version="orchestrator",
    )

    # -------- 5) Assemble response --------
    # Status label: "updated" if we changed anything; else "cached"
    did_update = bool(results) or (force or needs_roadmap_or_locate)
    return {
        "status": "updated" if did_update else "cached",
        "job_seeker_id": job_seeker_id,
        "role": target_role,
        "matches_written": len(results),
        "roadmap": roadmap_doc or {},
        "milestone_status": milestone_status or {},
    }
