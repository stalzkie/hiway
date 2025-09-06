# apps/backend/api/endpoints/milestone_locator.py
from __future__ import annotations

from typing import Optional, Literal

from fastapi import APIRouter, HTTPException, Query

# Both are imported; engine selection is done at the endpoint layer.
from apps.backend.services.milestone_locator import (
    locate_milestone_with_llm,
)

router = APIRouter()

@router.post("/seekers/{seeker_id}/roles/{role}/milestones/locate")
def api_locate(
    seeker_id: str,
    role: str,
    roadmap_id: Optional[str] = Query(default=None, description="Specific roadmap_id; latest for seeker+role if omitted"),
    force: bool = Query(default=False, description="Recompute even if nothing changed"),
    engine: Literal["llm", "vectors"] = Query(default="llm", description="Scoring engine"),
    model_version: Optional[str] = Query(default=None, description="Optional tag to store alongside the snapshot"),
):
    """
    Locate the user's current milestone for a given role.

    Defaults to the LLM engine for simpler, schema-tolerant scoring.
    Set engine=vectors to use the legacy SBERT+Pinecone path (if configured).
    """
    try:
        if engine == "llm":
            snap = locate_milestone_with_llm(
                job_seeker_id=seeker_id,
                role=role,
                roadmap_id=roadmap_id,
                force=force,
                model_version=model_version,
            )
            return {"engine": engine, "milestone_status": snap}
        elif engine == "vectors":
            # If you have a vector-based implementation, add it here
            raise HTTPException(status_code=501, detail="Vector engine not implemented")
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported engine: {engine}")
            
    except RuntimeError as e:
        # Handle business logic errors (e.g., no roadmap found)
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        # Handle unexpected errors
        raise HTTPException(status_code=500, detail=str(e))