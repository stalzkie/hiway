# apps/backend/api/endpoints/matcher.py
from typing import Optional, Dict, List
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field, EmailStr

from apps.backend.services.matcher import (
    rank_posts_for_seeker,
    rank_posts_for_seeker_by_email,
    get_seeker_id_by_email,
)

# ---------- Schemas (for clean Swagger/OpenAPI) ----------
class SectionScores(BaseModel):
    skills: Optional[float] = Field(None, description="Per-section score (0..100)")
    experience: Optional[float] = Field(None, description="Per-section score (0..100)")
    education: Optional[float] = Field(None, description="Per-section score (0..100)")
    licenses: Optional[float] = Field(None, description="Per-section score (0..100)")

class MatchItem(BaseModel):
    job_post_id: str = Field(..., description="UUID of the job post")
    confidence: float = Field(..., ge=0, le=100, description="Weighted confidence (0..100)")
    section_scores: SectionScores = Field(..., description="Best match per section")
    job_post: Optional[dict] = Field(
        None,
        description="Job post row (included when include_details=true)"
    )

class MatchResponse(BaseModel):
    job_seeker_id: str = Field(..., description="Resolved seeker UUID")
    count: int = Field(..., description="Number of posts returned")
    matches: List[MatchItem]

router = APIRouter()

@router.get(
    "/match",
    response_model=MatchResponse,
    summary="Match Seeker To Jobs",
    description=(
        "Returns job posts ranked for the given job seeker via Pinecone cosine similarities. "
        "Provide either `job_seeker_id` or `email` (email will be resolved to a seeker UUID)."
    ),
)
def match_seeker_to_jobs(
    job_seeker_id: Optional[str] = Query(
        None,
        description="UUID of the job seeker (leave empty if using `email`)"
    ),
    email: Optional[EmailStr] = Query(
        None,
        description="Look up seeker by email (alternative to `job_seeker_id`)",
        example="dstalingrad@gmail.com",
    ),
    top_k: int = Query(
        20, ge=1, le=200,
        description="Top K per section to retrieve from Pinecone",
        example=20
    ),
    include_details: bool = Query(
        False,
        description="If true, attach `job_post` rows to each match",
        example=False
    ),
    min_sections: int = Query(
        1, ge=1, le=4,
        description="Require at least N sections to contribute to a post’s score",
        example=2
    ),
):
    # 1) Resolve seeker id via email when provided
    if email and not job_seeker_id:
        job_seeker_id = get_seeker_id_by_email(str(email))
        if not job_seeker_id:
            raise HTTPException(status_code=404, detail=f"No job_seeker found for email {email}")

    # 2) Ensure we have an identifier
    if not job_seeker_id:
        raise HTTPException(status_code=400, detail="Provide job_seeker_id or email")

    # 3) Run matching
    if email:
        matches = rank_posts_for_seeker_by_email(
            email=str(email),
            top_k_per_section=top_k,
            include_job_details=include_details,
            min_sections=min_sections,
        )
    else:
        matches = rank_posts_for_seeker(
            job_seeker_id=job_seeker_id,
            top_k_per_section=top_k,
            include_job_details=include_details,
            min_sections=min_sections,
        )

    return MatchResponse(
        job_seeker_id=job_seeker_id,
        count=len(matches),
        matches=matches,  # shape matches MatchItem thanks to your service structure
    )
