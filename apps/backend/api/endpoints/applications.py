# apps/backend/api/endpoints/applications.py
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, UUID4

from apps.backend.api.deps.auth import get_bearer_token
from apps.backend.services.applications_service import ApplicationsService, ACTIVE_STATUSES

router = APIRouter(prefix="/applications", tags=["applications"])
svc = ApplicationsService()

# -------------------------------------------------
# OpenAPI Schemas
# -------------------------------------------------

class ApplicationItem(BaseModel):
    application_id: UUID4
    job_post_id: UUID4
    employer_id: UUID4
    # job_seeker_id is intentionally hidden for seekers’ own list; included where relevant
    job_seeker_id: Optional[UUID4] = Field(default=None, description="Present in employer views")
    status: str = Field(..., description="Application status")
    match_confidence: Optional[float] = Field(None, ge=0, le=1, description="0..1 scale")
    match_snapshot: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

class ListResponse(BaseModel):
    items: List[ApplicationItem]
    limit: int
    offset: int

class ApplyBody(BaseModel):
    job_post_id: UUID4 = Field(..., description="Target job post ID")
    match_confidence: Optional[float] = Field(
        default=None, ge=0, le=1, description="Model confidence 0..1 (convert from %/100)"
    )
    match_snapshot: Optional[Dict[str, Any]] = Field(
        default=None, description="Optional analytics/features snapshot saved with the application"
    )
    cover_letter: Optional[str] = Field(default=None, description="Optional cover letter text")
    resume_url: Optional[str] = Field(default=None, description="Public URL to resume (https)")

    class Config:
        json_schema_extra = {
            "example": {
                "job_post_id": "9b8e0ae3-76b7-4f5a-b7a1-b7e2b2a4bbf3",
                "match_confidence": 0.82,
                "match_snapshot": {"match_percentage": 82, "top_skills": ["python", "sql"]},
                "cover_letter": "Excited to apply—my last project ships similar features.",
                "resume_url": "https://example.com/resume.pdf",
            }
        }

class ApplyResponse(BaseModel):
    application_id: UUID4
    status: str = Field("submitted", description="Created/updated status")

class UpdateStatusBody(BaseModel):
    status: str = Field(
        ...,
        description="One of: draft/submitted/withdrawn/shortlisted/interviewed/offered/rejected/hired",
        examples=["shortlisted"],
    )

# -------------------------------------------------
# Routes
# -------------------------------------------------

@router.post(
    "/apply",
    summary="Apply for a job",
    description=(
        "Creates or updates an ACTIVE application for the current seeker to the given job post. "
        "If an active application already exists, it is updated (idempotent). "
        "Requires the caller to be a seeker (RLS uses auth.uid())."
    ),
    response_model=ApplyResponse,
    status_code=status.HTTP_200_OK,
    responses={
        400: {"description": "Validation or RLS error"},
        401: {"description": "Missing/invalid bearer token"},
    },
)
def apply_for_job(
    body: ApplyBody,
    user_jwt: str = Depends(get_bearer_token),
):
    try:
        app_id = svc.apply_for_job(
            user_jwt=user_jwt,
            job_post_id=str(body.job_post_id),
            match_confidence=body.match_confidence,
            match_snapshot=body.match_snapshot,
            cover_letter=body.cover_letter,
            resume_url=body.resume_url,
        )
        return ApplyResponse(application_id=UUID(str(app_id)), status="submitted")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/me",
    summary="List my applications (seeker)",
    description=(
        "Returns applications owned by the current seeker. "
        "RLS restricts results to the caller’s job_seeker record."
    ),
    response_model=ListResponse,
    responses={
        400: {"description": "Query error"},
        401: {"description": "Missing/invalid bearer token"},
    },
)
def list_my_applications(
    limit: int = Query(20, ge=1, le=200),
    offset: int = Query(0, ge=0),
    status: Optional[str] = Query(
        None, description=f"Filter by status. Allowed: {', '.join(ACTIVE_STATUSES + ['withdrawn','rejected','hired'])}"
    ),
    job_post_id: Optional[str] = Query(None, description="Filter by job_post_id"),
    user_jwt: str = Depends(get_bearer_token),
):
    try:
        rows = svc.list_my_applications(
            user_jwt=user_jwt,
            limit=limit,
            offset=offset,
            status=status,
            job_post_id=job_post_id,
        )
        # Normalize for schema
        items = [
            ApplicationItem(
                application_id=UUID(r["application_id"]),
                job_post_id=UUID(r["job_post_id"]),
                employer_id=UUID(r["employer_id"]),
                job_seeker_id=None,  # hidden in seeker list
                status=r["status"],
                match_confidence=r.get("match_confidence"),
                match_snapshot=r.get("match_snapshot"),
                created_at=r["created_at"],
                updated_at=r["updated_at"],
            )
            for r in rows
        ]
        return ListResponse(items=items, limit=limit, offset=offset)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/employer",
    summary="List applications to my job posts (employer)",
    description=(
        "Returns applications for job posts created by the current employer. "
        "RLS restricts results to posts where employer.auth_user_id == auth.uid()."
    ),
    response_model=ListResponse,
    responses={
        400: {"description": "Query error"},
        401: {"description": "Missing/invalid bearer token"},
    },
)
def employer_list_applications(
    limit: int = Query(20, ge=1, le=200),
    offset: int = Query(0, ge=0),
    job_post_id: Optional[str] = Query(None, description="Filter by job_post_id"),
    status: Optional[str] = Query(None, description="Filter by application status"),
    user_jwt: str = Depends(get_bearer_token),
):
    try:
        rows = svc.employer_list_applications(
            user_jwt=user_jwt,
            limit=limit,
            offset=offset,
            job_post_id=job_post_id,
            status=status,
        )
        items = [
            ApplicationItem(
                application_id=UUID(r["application_id"]),
                job_post_id=UUID(r["job_post_id"]),
                job_seeker_id=UUID(r["job_seeker_id"]),
                employer_id=UUID(r.get("employer_id") or "00000000-0000-0000-0000-000000000000"),
                status=r["status"],
                match_confidence=r.get("match_confidence"),
                match_snapshot=r.get("match_snapshot"),
                created_at=r["created_at"],
                updated_at=r["updated_at"],
            )
            for r in rows
        ]
        return ListResponse(items=items, limit=limit, offset=offset)
    except KeyError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Missing column in response: {e}")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch(
    "/{application_id}/status",
    summary="Employer: update application status",
    description=(
        "Updates the status of an application. RLS enforces that the caller must be the employer "
        "who owns the job post tied to this application."
    ),
    response_model=ApplicationItem,
    responses={
        400: {"description": "Invalid status or RLS denied"},
        401: {"description": "Missing/invalid bearer token"},
    },
)
def employer_update_status(
    application_id: str,
    body: UpdateStatusBody,
    user_jwt: str = Depends(get_bearer_token),
):
    try:
        updated = svc.employer_update_status(
            user_jwt=user_jwt,
            application_id=application_id,
            new_status=body.status,
        )
        return ApplicationItem(
            application_id=UUID(updated["application_id"]),
            job_post_id=UUID(updated["job_post_id"]),
            employer_id=UUID(updated["employer_id"]),
            job_seeker_id=UUID(updated["job_seeker_id"]),
            status=updated["status"],
            match_confidence=updated.get("match_confidence"),
            match_snapshot=updated.get("match_snapshot"),
            created_at=updated["created_at"],
            updated_at=updated["updated_at"],
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post(
    "/{application_id}/withdraw",
    summary="Seeker: withdraw application",
    description="Allows the seeker to mark their own application as withdrawn.",
    response_model=ApplicationItem,
    responses={
        400: {"description": "RLS denied or update failure"},
        401: {"description": "Missing/invalid bearer token"},
    },
)
def seeker_withdraw(
    application_id: str,
    user_jwt: str = Depends(get_bearer_token),
):
    try:
        updated = svc.seeker_withdraw(user_jwt=user_jwt, application_id=application_id)
        return ApplicationItem(
            application_id=UUID(updated["application_id"]),
            job_post_id=UUID(updated["job_post_id"]),
            employer_id=UUID(updated["employer_id"]),
            job_seeker_id=UUID(updated["job_seeker_id"]),
            status=updated["status"],
            match_confidence=updated.get("match_confidence"),
            match_snapshot=updated.get("match_snapshot"),
            created_at=updated["created_at"],
            updated_at=updated["updated_at"],
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
