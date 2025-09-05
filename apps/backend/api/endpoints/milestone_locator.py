# apps/backend/api/endpoints/milestone_locator.py
from fastapi import APIRouter, HTTPException, Query
from apps.backend.services.milestone_locator import locate_milestone_with_vectors

router = APIRouter()

@router.post("/seekers/{seeker_id}/roles/{role}/milestones/locate")
def api_locate(seeker_id: str, role: str, roadmap_id: str | None = None, force: bool = False):
    try:
        snap = locate_milestone_with_vectors(
            job_seeker_id=seeker_id,
            role=role,
            roadmap_id=roadmap_id,
            force=force,
        )
        return {"snapshot": snap}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
