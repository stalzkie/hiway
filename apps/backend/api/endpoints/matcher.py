# apps/backend/api/endpoints/matcher.py
from __future__ import annotations

from typing import Optional, Dict, List, Any
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field, EmailStr

from apps.backend.services.matcher import (
    match_and_enrich,
    get_seeker_id_by_email,
)
from apps.backend.services.data_storer import persist_matcher_results

router = APIRouter()


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
        description="2–4 sentence summary explaining the score via semantic/vector similarity across sections",
    )


class MatchItem(BaseModel):
    job_post_id: str = Field(..., description="UUID of the job post")
    confidence: float = Field(..., ge=0, le=100, description="Weighted confidence (0..100)")
    section_scores: SectionScores = Field(..., description="Best match per section")
    job_post: Optional[dict] = Field(
        None, description="Job post row (included when include_details=true)"
    )
    analysis: Optional[SkillAnalysis] = Field(
        None, description="Required vs seeker skill breakdown and explanations"
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
        "Returns job posts ranked for the given job seeker via Pinecone cosine similarities, "
        "optionally reranked with a cross-encoder and enriched with LLM explanations. "
        "Provide either job_seeker_id or email (email will be resolved to a seeker UUID). "
        "Results are also persisted to Supabase in job_match_scores/job_match_scores_cache."
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
        1, ge=1, le=4, description="Require at least N sections to contribute to a post’s score", example=2
    ),
    include_explanations: bool = Query(
        False,
        description="If true, generate per-skill explanations and an overall semantic summary",
        example=True,
    ),
):
    """
    Endpoint flow:
      1) Resolve job_seeker_id (from email if provided).
      2) Call services.matcher.match_and_enrich to compute scores + explanations.
      3) Persist results to Supabase (job_match_scores, with cache maintained by trigger).
      4) Return structured response to client.
    """
    # Resolve seeker id via email when provided
    if email and not job_seeker_id:
        job_seeker_id = get_seeker_id_by_email(str(email))
        if not job_seeker_id:
            raise HTTPException(status_code=404, detail=f"No job_seeker found for email {email}")

    if not job_seeker_id:
        raise HTTPException(status_code=400, detail="Provide job_seeker_id or email")

    try:
        results: List[Dict[str, Any]] = match_and_enrich(
            job_seeker_id=job_seeker_id,
            top_k_per_section=top_k,
            include_details=include_details,
            min_sections=min_sections,
            include_explanations=include_explanations,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Persist results to Supabase
    try:
        persist_matcher_results(
            auth_user_id=None,  # If you want, pass through request.user.id
            job_seeker_id=job_seeker_id,
            matcher_results=results,
            default_weights=None,
            method="pinecone+rerank",
            model_version="api-endpoint",
        )
    except Exception as e:
        print(f"[WARN] Failed to persist matcher results: {e}")

    # Pydantic validation & response shaping
    return MatchResponse(
        job_seeker_id=job_seeker_id,
        count=len(results),
        matches=[MatchItem.model_validate(r) for r in results],
    )
