# apps/backend/services/orchestrator.py
from __future__ import annotations

import os
from typing import Dict, Any, Optional

from supabase import create_client

from .matcher import match_and_enrich, get_seeker_id_by_email
from .scraper import generate_and_store_roadmap
from .data_storer import persist_matcher_results

# ---------------- Supabase client ----------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
sb = create_client(SUPABASE_URL, SUPABASE_KEY)


# ---------------- Helpers ----------------
def _fetch_job_seeker(job_seeker_id: str) -> Optional[Dict[str, Any]]:
    resp = (
        sb.table("job_seeker")
        .select("*")
        .eq("job_seeker_id", job_seeker_id)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


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


def _fetch_latest_roadmap_for_role(job_seeker_id: str, role: str) -> Optional[Dict[str, Any]]:
    resp = (
        sb.table("seeker_milestone_status")
        .select("*")
        .eq("job_seeker_id", job_seeker_id)
        .eq("role", role)  # roadmaps are role-specific
        .order("calculated_at", desc=True)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _profile_changed(seeker_row: Dict[str, Any], last_entry: Optional[Dict[str, Any]]) -> bool:
    """
    Naive check: if profile JSON differs since last calculated_at, consider changed.
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
      1. Look up job_seeker by email.
      2. If no match/roadmap or profile changed → run matcher + scraper.
      3. Else return cached results.
    """
    job_seeker_id = get_seeker_id_by_email(email)
    if not job_seeker_id:
        return {"status": "error", "message": f"No job_seeker found for {email}"}

    seeker_row = _fetch_job_seeker(job_seeker_id)
    if not seeker_row:
        return {"status": "error", "message": f"Job seeker record missing for {email}"}

    # Use seeker’s target role unless caller specified a role explicitly
    target_role = role or seeker_row.get("target_role", "Generalist")

    last_match = _fetch_latest_match(job_seeker_id)
    last_roadmap = _fetch_latest_roadmap_for_role(job_seeker_id, target_role)

    needs_match_update = force or _profile_changed(seeker_row, last_match)
    needs_roadmap_update = force or (not last_roadmap) or _profile_changed(seeker_row, last_roadmap)

    if needs_match_update or needs_roadmap_update:
        print(f"[orchestrator] Updating data for seeker {email} (role={target_role})")

        # --- Matcher update ---
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

        # --- Scraper update (per role) ---
        if needs_roadmap_update:
            roadmap_id = generate_and_store_roadmap(
                job_seeker_id=job_seeker_id,
                role=target_role,
            )
        else:
            roadmap_id = last_roadmap.get("roadmap_id") if last_roadmap else None

        return {
            "status": "updated",
            "job_seeker_id": job_seeker_id,
            "role": target_role,
            "matches": len(results),
            "roadmap_id": roadmap_id,
        }

    else:
        print(f"[orchestrator] No update needed for seeker {email} (role={target_role})")
        return {
            "status": "cached",
            "job_seeker_id": job_seeker_id,
            "role": target_role,
            "last_match": last_match,
            "last_roadmap": last_roadmap,
        }
