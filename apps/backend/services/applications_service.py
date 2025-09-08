from __future__ import annotations
from typing import Any, Dict, List, Optional, Tuple
from supabase import Client
from apps.backend.lib.supabase import get_sb, as_user

ACTIVE_STATUSES = ["draft","submitted","shortlisted","interviewed","offered"]

class ApplicationsService:
    def __init__(self, sb: Optional[Client] = None):
        self.sb = sb or get_sb()

    # --- Core RPC wrapper ---
    def apply_for_job(
        self,
        user_jwt: str,
        job_post_id: str,
        match_confidence: Optional[float] = None,     # 0..1
        match_snapshot: Optional[Dict[str, Any]] = None,
        cover_letter: Optional[str] = None,
        resume_url: Optional[str] = None,
    ) -> str:
        c = as_user(self.sb, user_jwt)
        params = {
            "p_job_post_id": job_post_id,
            "p_match_confidence": match_confidence,
            "p_match_snapshot": match_snapshot or {},
            "p_cover_letter": cover_letter,
            "p_resume_url": resume_url,
        }
        res = c.rpc("apply_for_job", params=params).execute()
        if res.error:
            raise RuntimeError(res.error.message)
        return str(res.data)

    # --- Seeker: list own applications (RLS limits rows) ---
    def list_my_applications(
        self,
        user_jwt: str,
        limit: int = 20,
        offset: int = 0,
        status: Optional[str] = None,
        job_post_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        c = as_user(self.sb, user_jwt)
        q = c.from_("job_application").select(
            "application_id, job_post_id, employer_id, status, match_confidence, created_at, updated_at, match_snapshot"
        )
        if status:
            q = q.eq("status", status)
        if job_post_id:
            q = q.eq("job_post_id", job_post_id)
        q = q.order("created_at", desc=True).range(offset, offset + limit - 1)
        res = q.execute()
        if res.error:
            raise RuntimeError(res.error.message)
        return list(res.data or [])

    # --- Employer: list applications to employer’s posts (RLS enforces scope) ---
    def employer_list_applications(
        self,
        user_jwt: str,
        limit: int = 20,
        offset: int = 0,
        job_post_id: Optional[str] = None,
        status: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        c = as_user(self.sb, user_jwt)
        # You can enrich with joins via PostgREST embedded selects if exposed,
        # or keep it simple and let the UI fetch seeker profile separately.
        q = c.from_("job_application").select(
            "application_id, job_post_id, job_seeker_id, status, match_confidence, created_at, updated_at, match_snapshot"
        )
        if job_post_id:
            q = q.eq("job_post_id", job_post_id)
        if status:
            q = q.eq("status", status)
        q = q.order("created_at", desc=True).range(offset, offset + limit - 1)
        res = q.execute()
        if res.error:
            raise RuntimeError(res.error.message)
        return list(res.data or [])

    # --- Employer: update status on an application they own (RLS enforces) ---
    def employer_update_status(
        self,
        user_jwt: str,
        application_id: str,
        new_status: str,
    ) -> Dict[str, Any]:
        c = as_user(self.sb, user_jwt)
        res = (
            c.from_("job_application")
            .update({"status": new_status})
            .eq("application_id", application_id)
            .select("*")
            .single()
            .execute()
        )
        if res.error:
            raise RuntimeError(res.error.message)
        return dict(res.data or {})

    # --- Seeker: withdraw their own application ---
    def seeker_withdraw(
        self,
        user_jwt: str,
        application_id: str,
    ) -> Dict[str, Any]:
        c = as_user(self.sb, user_jwt)
        res = (
            c.from_("job_application")
            .update({"status": "withdrawn"})
            .eq("application_id", application_id)
            .select("*")
            .single()
            .execute()
        )
        if res.error:
            raise RuntimeError(res.error.message)
        return dict(res.data or {})
