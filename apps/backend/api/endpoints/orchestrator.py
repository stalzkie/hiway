# apps/backend/api/endpoints/orchestrator.py
from __future__ import annotations

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict, Any, List

from apps.backend.services.orchestrator import orchestrate_user_update

router = APIRouter()


# ---------------- Nested Schemas (for clarity) ----------------
class MilestoneItemScore(BaseModel):
    item: str
    sim: float

class MilestoneScore(BaseModel):
    index: int
    title: Optional[str] = None
    target_level: Optional[str] = None
    score_pct: float
    skills_scored: Optional[List[MilestoneItemScore]] = None
    outcomes_scored: Optional[List[MilestoneItemScore]] = None
    gaps: Optional[List[str]] = None

class MilestoneStatus(BaseModel):
    roadmap_id: Optional[str] = None
    current_milestone: Optional[str] = None
    current_level: Optional[str] = None
    current_score_pct: Optional[float] = None
    next_milestone: Optional[str] = None
    next_level: Optional[str] = None
    gaps: Optional[List[str]] = None
    milestones_scored: Optional[List[MilestoneScore]] = None
    weights: Optional[Dict[str, Any]] = None
    model_version: Optional[str] = None
    low_confidence: Optional[bool] = None
    calculated_at: Optional[str] = None

class RoadmapDoc(BaseModel):
    roadmap_id: Optional[str] = None
    job_seeker_id: Optional[str] = None
    role: Optional[str] = None
    milestones: Optional[List[Dict[str, Any]]] = None
    prompt_template: Optional[str] = None
    cert_allowlist: Optional[List[Any]] = None
    created_at: Optional[str] = None
    expires_at: Optional[str] = None


# ---------------- Response Schema ----------------
class OrchestratorResponse(BaseModel):
    status: str = Field(..., description='"updated" if any recomputation ran; otherwise "cached"')
    job_seeker_id: Optional[str] = None
    role: Optional[str] = None

    # From updated orchestrator service
    matches_written: int = 0
    roadmap: Optional[RoadmapDoc] = None
    milestone_status: Optional[MilestoneStatus] = None

    # Optional message for error/info cases
    message: Optional[str] = None


# ---------------- Endpoint ----------------
@router.post(
    "/orchestrate",
    response_model=OrchestratorResponse,
    summary="Run orchestrator: ensure roadmap exists and return current milestone",
    description=(
        "Resolves the seeker by email, updates matches if the profile changed (or force=true), "
        "ensures a role-specific roadmap exists (creates if missing), and locates the seeker's "
        "current milestone using the Pinecone+SBERT milestone locator. "
        "Always returns the roadmap document and the latest milestone status."
    ),
)
def run_orchestrator(
    email: EmailStr = Query(..., description="Job seeker’s email"),
    role: Optional[str] = Query(
        None,
        description="Target role/job title (defaults to seeker.target_role if not provided)",
    ),
    force: bool = Query(
        False,
        description="Force refresh regardless of profile/cache state",
    ),
) -> OrchestratorResponse:
    try:
        result = orchestrate_user_update(email=email, role=role, force=force)
        # The service returns keys compatible with OrchestratorResponse
        return OrchestratorResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
