# apps/backend/api/endpoints/matcher.py
from __future__ import annotations

import os
import time
from typing import Optional, Dict, List, Any

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field, EmailStr
from supabase import create_client, Client

from apps.backend.services.matcher import (
    rank_posts_for_seeker,
    get_seeker_id_by_email,
)
from apps.backend.services.data_storer import persist_matcher_results

# ✅ Import the actual functions your embed_worker.py exposes
try:
    from apps.backend.services.embed_worker import (
        process_job_seeker_batch,
        process_job_post_batch,
    )
except Exception as e:
    process_job_seeker_batch = None  # type: ignore
    process_job_post_batch = None    # type: ignore
    print(f"[WARN] embed_worker imports failed (non-fatal): {e}")

router = APIRouter()

# --------------------------------------------------------------------
# Supabase (service role) for enqueue/checks
# --------------------------------------------------------------------
_SUPABASE_URL = os.getenv("SUPABASE_URL")
_SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")  # service role key
if not _SUPABASE_URL or not _SUPABASE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

_sb: Client = create_client(_SUPABASE_URL, _SUPABASE_KEY)

# --------------------------------------------------------------------
# Enqueue helpers — ALWAYS include a valid 'reason'
# Your DB CHECK allows only: 'insert', 'update', 'manual'
# --------------------------------------------------------------------
_ALLOWED_REASONS = {"insert", "update", "manual"}  # Fixed: removed 'backfill'

def _fetch_seeker_row(job_seeker_id: str) -> Optional[dict]:
    try:
        resp = (
            _sb.table("job_seeker")
            .select("pinecone_id, embedding_checksum, search_document")
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
        rows = resp.data or []
        return rows[0] if rows else None
    except Exception as e:
        print(f"[WARN] _fetch_seeker_row failed: {e}")
        return None

def _pick_reason_for_seeker(row: dict) -> str:
    """If pinecone_id or embedding_checksum is missing => 'insert', else 'update'."""
    reason = "insert" if (not row.get("pinecone_id") or not row.get("embedding_checksum")) else "update"
    return reason if reason in _ALLOWED_REASONS else "insert"

def _has_embeddings_for_seeker(job_seeker_id: str) -> bool:
    row = _fetch_seeker_row(job_seeker_id)
    if not row:
        return False
    return bool(row.get("pinecone_id")) and bool(row.get("embedding_checksum"))

def _ensure_seeker_enqueued(job_seeker_id: str) -> str:
    """Enqueue seeker if needed; returns the 'reason' used for enqueue."""
    try:
        row = _fetch_seeker_row(job_seeker_id)
        if not row:
            reason = "insert"
        else:
            reason = _pick_reason_for_seeker(row)
        _sb.table("embedding_queue").insert({
            "job_seeker_id": job_seeker_id,
            "reason": reason,   # 👈 required by NOT NULL + CHECK
        }).execute()
        return reason
    except Exception as e:
        print(f"[WARN] _ensure_seeker_enqueued failed: {e}")
        return "insert"

def _enqueue_stale_posts_if_any(limit: int = 200) -> int:
    """
    Opportunistically enqueue any job posts that are missing embeddings.
    Returns count enqueued (best-effort).
    """
    count = 0
    try:
        missing_posts = (
            _sb.table("job_post")
            .select("job_post_id")
            .or_("pinecone_id.is.null,embedding_checksum.is.null")
            .limit(limit)
            .execute()
        )
        for r in (missing_posts.data or []):
            jp_id = r.get("job_post_id")
            if not jp_id:
                continue
            try:
                _sb.table("embedding_queue_post").insert({
                    "job_post_id": jp_id,
                    "reason": "insert",  # 👈 required by NOT NULL + CHECK
                }).execute()
                count += 1
            except Exception as inner:
                print(f"[WARN] enqueue post {jp_id} failed: {inner}")
    except Exception as e:
        print(f"[WARN] _enqueue_stale_posts_if_any failed: {e}")
    return count

def _run_worker_passes(eager_passes: int = 2) -> None:
    """
    Run the worker loops once or twice synchronously to process the just-enqueued rows.
    Uses your embed_worker.process_* functions directly.
    Best-effort and non-fatal if imports are missing.
    """
    if not process_job_seeker_batch or not process_job_post_batch:
        return
    try:
        for _ in range(max(1, eager_passes)):
            try:
                cs = process_job_seeker_batch()  # type: ignore
            except Exception as e:
                cs = 0
                print(f"[WARN] process_job_seeker_batch failed: {e}")
            try:
                cp = process_job_post_batch()    # type: ignore
            except Exception as e:
                cp = 0
                print(f"[WARN] process_job_post_batch failed: {e}")
            if cs == 0 and cp == 0:
                break
    except Exception as e:
        print(f"[WARN] _run_worker_passes failed: {e}")

def _poll_until_seeker_embedded(job_seeker_id: str, timeout_s: int = 8, interval_s: float = 0.8) -> bool:
    """
    Poll briefly for the just-enqueued seeker to be embedded.
    Returns True if embedded appears; False on timeout.
    """
    deadline = time.time() + max(1, timeout_s)
    while time.time() < deadline:
        if _has_embeddings_for_seeker(job_seeker_id):
            return True
        time.sleep(interval_s)
    return False

# ---------------------- Response Schemas ----------------------
class SectionScores(BaseModel):
    skills: Optional[float] = Field(None, description="Per-section score (0..100)")
    experience: Optional[float] = Field(None, description="Per-section score (0..100)")
    education: Optional[float] = Field(None, description="Per-section score (0..100)")
    licenses: Optional[float] = Field(None, description="Per-section score (0..100)")

class SkillAnalysis(BaseModel):
    required_skills: List[str]
    matched_skills: List[str]
    missing_skills: List[str]
    skills_match_rate: float
    matched_explanations: Optional[Dict[str, str]] = Field(
        default=None,
        description="Map of matched_skill -> 1–2 sentence explanation providing contextual reasoning",
    )
    overall_summary: Optional[str] = Field(
        default=None,
        description="2–4 sentence summary explaining the score using LLM + vector retrieval",
    )

class MatchItem(BaseModel):
    job_post_id: str = Field(..., description="UUID of the job post")
    confidence: float = Field(..., ge=0, le=100, description="Final strict score (0..100)")
    section_scores: SectionScores = Field(..., description="Per-section scores (0..100)")
    job_post: Optional[dict] = Field(
        None, description="Job post row (included when include_details=true)"
    )
    analysis: Optional[SkillAnalysis] = Field(
        None, description="Required vs seeker skill breakdown and LLM explanations"
    )

class MatchResponse(BaseModel):
    job_seeker_id: str = Field(..., description="Resolved seeker UUID")
    count: int = Field(..., description="Number of posts returned")
    matches: List[MatchItem]

# ---------------------- Endpoint ----------------------
@router.get(
    "/match",
    response_model=MatchResponse,
    summary="Match Seeker To Jobs",
    description=(
        "Retrieves candidate job posts from Pinecone (per-section vectors) and scores them "
        "with an LLM using retrieved context (RAG). The final score is a strict, section-driven "
        "weighted mean with harsh penalties for experience and required-skill gaps."
    ),
)
def match_seeker_to_jobs(
    job_seeker_id: Optional[str] = Query(
        None, description="UUID of the job seeker (leave empty if using email)"
    ),
    email: Optional[EmailStr] = Query(
        None,
        description="Look up seeker by email (alternative to job_seeker_id)",
        example="seeker@example.com",
    ),
    top_k: int = Query(
        20, ge=1, le=200, description="Top K per section to retrieve from Pinecone", example=20
    ),
    include_details: bool = Query(
        False, description="If true, attach job_post rows to each match", example=False
    ),
    min_sections: int = Query(
        2,  # stricter default; was 1
        ge=1, le=4,
        description="Require at least N sections to contribute to a post’s score",
        example=2
    ),
    include_explanations: bool = Query(
        True,
        description="LLM explanations and overall summary are always used when available.",
        example=True,
        deprecated=True,
    ),
    eager_embed: bool = Query(
        True,
        description="If true, run a few quick embed-worker passes after enqueueing (best-effort).",
        example=True,
    ),
):
    """
    Flow:
      1) Resolve job_seeker_id (or from email).
      2) Enqueue seeker + any stale posts (with a valid NOT-NULL 'reason').
      3) (Optional) Run 1–2 quick worker passes and briefly poll for the seeker's embeddings.
      4) Run strict matcher (vectors + LLM sections), then apply harsh penalties with uniform rescale.
    """
    # 1) Resolve seeker id
    if email and not job_seeker_id:
        job_seeker_id = get_seeker_id_by_email(str(email))
        if not job_seeker_id:
            raise HTTPException(status_code=404, detail=f"No job_seeker found for email {email}")

    if not job_seeker_id:
        raise HTTPException(status_code=400, detail="Provide job_seeker_id or email")

    # 2) Enqueue
    reason = _ensure_seeker_enqueued(job_seeker_id)
    _enqueue_stale_posts_if_any()

    # 3) Eager embed (best-effort)
    if eager_embed:
        try:
            _run_worker_passes(eager_passes=2)
            _ = _poll_until_seeker_embedded(job_seeker_id, timeout_s=8, interval_s=0.8)
        except Exception as e:
            print(f"[WARN] eager embed pipeline failed (non-fatal): {e}")

    # 4) Run matcher
    try:
        results: List[Dict[str, Any]] = rank_posts_for_seeker(
            job_seeker_id=job_seeker_id,
            top_k_per_section=top_k,
            include_job_details=include_details,
            min_sections=min_sections,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Persist results to Supabase (optional; matcher also persists)
    try:
        persist_matcher_results(
            auth_user_id=None,
            job_seeker_id=job_seeker_id,
            matcher_results=results,
            default_weights=None,
            method=f"rag-llm strict (reason={reason})",
            model_version="api-endpoint",
        )
    except Exception as e:
        print(f"[WARN] Failed to persist matcher results: {e}")

    return MatchResponse(
        job_seeker_id=job_seeker_id,
        count=len(results),
        matches=[MatchItem.model_validate(r) for r in results],
    )
