# apps/backend/api/endpoints/orchestrator.py
from __future__ import annotations

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any

from apps.backend.services.orchestrator import orchestrate_user_update

router = APIRouter()


# ---------------- Response Schema ----------------
class OrchestratorResponse(BaseModel):
    status: str
    job_seeker_id: Optional[str] = None
    role: Optional[str] = None
    matches: Optional[int] = None
    roadmap_id: Optional[str] = None
    last_match: Optional[Dict[str, Any]] = None
    last_roadmap: Optional[Dict[str, Any]] = None
    message: Optional[str] = None


# ---------------- Endpoint ----------------
@router.post(
    "/orchestrate",
    response_model=OrchestratorResponse,
    summary="Run orchestrator pipeline for a seeker",
    description=(
        "Checks if a seeker’s profile has changed or if no cached data exists. "
        "If yes, runs matcher + scraper + data_storer. "
        "If not, returns cached match scores and roadmap. "
        "You can force refresh with `force=true`."
    ),
)
def run_orchestrator(
    email: EmailStr = Query(..., description="Job seeker’s email"),
    role: Optional[str] = Query(
        None,
        description="Target role/job title (defaults to seeker.target_role if not given)",
    ),
    force: bool = Query(
        False,
        description="Force refresh regardless of profile/cache state",
    ),
) -> OrchestratorResponse:
    try:
        result = orchestrate_user_update(email=email, role=role, force=force)
        return OrchestratorResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
