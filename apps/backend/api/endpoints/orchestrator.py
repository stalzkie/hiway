# apps/backend/api/endpoints/orchestrator.py
from __future__ import annotations

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator
from typing import Optional, Dict, Any, List, Union

from apps.backend.services.orchestrator import orchestrate_user_update

router = APIRouter()

# ---------------- Normalizers (endpoint-level) ----------------
def _to_list(val: Any) -> List[Any]:
    if val is None:
        return []
    if isinstance(val, list):
        return val
    if isinstance(val, dict):
        return [val]
    return [val]

def _coerce_matched_item(obj: Any) -> Optional[Dict[str, Any]]:
    """
    Normalize to {"item": str, "source": Optional[str]}.
    Accept strings and dicts; ignore anything else.
    """
    if isinstance(obj, dict):
        item = obj.get("item") or obj.get("name") or obj.get("topic")
        if item is None:
            return None
        src = obj.get("source")
        return {"item": str(item), "source": (str(src) if src is not None else None)}
    if isinstance(obj, str):
        return {"item": obj, "source": None}
    return None

def _normalize_matched_field(val: Any) -> List[Dict[str, Any]]:
    items = _to_list(val)
    out: List[Dict[str, Any]] = []
    for elem in items:
        c = _coerce_matched_item(elem)
        if c:
            out.append(c)
    return out

def _coerce_gap_item(obj: Any) -> Optional[Dict[str, Any]]:
    """
    Normalize gaps to {"item": str}.
    """
    if isinstance(obj, dict):
        item = obj.get("item") or obj.get("name") or obj.get("topic")
        if item is None:
            return None
        return {"item": str(item)}
    if isinstance(obj, str):
        return {"item": obj}
    return None

def _normalize_gaps_field(val: Any) -> List[Dict[str, Any]]:
    items = _to_list(val)
    out: List[Dict[str, Any]] = []
    for elem in items:
        c = _coerce_gap_item(elem)
        if c:
            out.append(c)
    return out

def _coerce_float(val: Any) -> Optional[float]:
    if val is None:
        return None
    if isinstance(val, (int, float)):
        return float(val)
    try:
        # tolerate strings like "12.5" or "~12.5 hours"
        s = str(val).strip()
        num = ""
        dot_seen = False
        for ch in s:
            if ch.isdigit():
                num += ch
            elif ch == "." and not dot_seen:
                num += ch
                dot_seen = True
            elif num:
                break
        return float(num) if num else None
    except Exception:
        return None

def _coerce_str(val: Any) -> Optional[str]:
    if val is None:
        return None
    try:
        s = str(val).strip()
        return s if s else None
    except Exception:
        return None

def _clamp01(x: Optional[float]) -> Optional[float]:
    if x is None:
        return None
    try:
        xf = float(x)
    except Exception:
        return None
    if xf < 0:
        return 0.0
    if xf > 1:
        return 1.0
    return xf

# ---------------- Nested Schemas ----------------
class MilestoneMatchedEvidence(BaseModel):
    model_config = ConfigDict(extra="ignore")
    item: str
    source: Optional[str] = Field(
        default=None,
        description='One of {"skills","experience","education","licenses"} when available.'
    )

class MilestoneGap(BaseModel):
    model_config = ConfigDict(extra="ignore")
    item: str

class MilestoneScore(BaseModel):
    model_config = ConfigDict(extra="ignore")

    index: int
    title: Optional[str] = None
    score_pct: float
    matched_evidence: Optional[List[MilestoneMatchedEvidence]] = None
    gaps: Optional[List[MilestoneGap]] = None
    rationale: Optional[str] = None  # 1–2 sentences

    # NEW: ETA fields from milestone_locator
    eta_hours: Optional[float] = Field(
        default=None,
        description="Estimated focused hours to reach pass_gate for this milestone"
    )
    eta_text: Optional[str] = Field(
        default=None,
        description="Human-friendly ETA (e.g., '~12 hours' or '~1.5 weeks @ 10h/week')"
    )
    eta_confidence: Optional[float] = Field(
        default=None, ge=0, le=1,
        description="LLM/heuristic confidence 0..1"
    )

    # ---- Defensive coercions (accept legacy shapes gracefully) ----
    @field_validator("matched_evidence", mode="before")
    @classmethod
    def _coerce_matched(cls, v: Any):
        # Accept legacy fields too: skills_scored / outcomes_scored -> map to matched_evidence (item only)
        return _normalize_matched_field(v)

    @field_validator("gaps", mode="before")
    @classmethod
    def _coerce_gaps(cls, v: Any):
        return _normalize_gaps_field(v)

    @field_validator("eta_hours", mode="before")
    @classmethod
    def _coerce_eta_hours(cls, v: Any):
        return _coerce_float(v)

    @field_validator("eta_text", mode="before")
    @classmethod
    def _coerce_eta_text(cls, v: Any):
        return _coerce_str(v)

    @field_validator("eta_confidence", mode="before")
    @classmethod
    def _coerce_eta_conf(cls, v: Any):
        return _clamp01(_coerce_float(v))

class MilestoneStatus(BaseModel):
    model_config = ConfigDict(extra="ignore")

    roadmap_id: Optional[str] = None
    current_milestone: Optional[str] = None
    current_level: Optional[str] = None
    current_score_pct: Optional[float] = None
    next_milestone: Optional[str] = None
    next_level: Optional[str] = None
    gaps: Optional[List[MilestoneGap]] = None
    milestones_scored: Optional[List[MilestoneScore]] = None
    weights: Optional[Dict[str, Any]] = Field(
        default=None,
        description='May include {"pass_gate","gap_min","engine","eta_summary":[{"index","title","eta_hours","eta_text","eta_confidence"}]}'
    )
    model_version: Optional[str] = None
    low_confidence: Optional[bool] = None
    calculated_at: Optional[str] = None  # we’ll map calculated_at_iso -> calculated_at

    @field_validator("gaps", mode="before")
    @classmethod
    def _coerce_status_gaps(cls, v: Any):
        return _normalize_gaps_field(v)

class RoadmapDoc(BaseModel):
    model_config = ConfigDict(extra="ignore")

    roadmap_id: Optional[str] = None
    job_seeker_id: Optional[str] = None
    role: Optional[str] = None
    milestones: Optional[List[Dict[str, Any]]] = None  # passed through as-is
    prompt_template: Optional[str] = None
    created_at: Optional[str] = None
    expires_at: Optional[str] = None

# ---------------- Response Schema ----------------
class OrchestratorResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    status: str = Field(..., description='"updated" if recomputation ran; otherwise "cached"')
    job_seeker_id: Optional[str] = None
    role: Optional[str] = None

    matches_written: int = 0
    roadmap: Optional[RoadmapDoc] = None
    milestone_status: Optional[MilestoneStatus] = None

    message: Optional[str] = None

# ---------------- Endpoint ----------------
@router.post(
    "/orchestrate",
    response_model=OrchestratorResponse,
    summary="Run orchestrator and locate current milestone (knowledge-match; prior milestones assumed achieved; includes ETA)",
    description=(
        "Resolves the seeker by email, updates job-match snapshots if the profile changed (or force=true), "
        "ensures a role-specific roadmap exists (creates if missing), and locates the seeker's current milestone.\n\n"
        "Scoring compares ONLY the job seeker's skills, experience, education, and licenses/certifications "
        "against the KNOWLEDGE content of each milestone. When evaluating milestone i, the evaluator ASSUMES all "
        "prior milestones [0..i-1] are already achieved and focuses on incremental knowledge.\n\n"
        "Each milestone may include ETA fields: eta_hours, eta_text, and eta_confidence. "
        "The weights object may include an eta_summary array for unfinished milestones."
    ),
)
def run_orchestrator(
    email: EmailStr = Query(..., description="Job seeker’s email"),
    role: Optional[str] = Query(None, description="Target role/job title (defaults to seeker.target_role if not provided)"),
    force: bool = Query(False, description="Force refresh regardless of profile/cache state"),
) -> OrchestratorResponse:
    try:
        result = orchestrate_user_update(email=email, role=role, force=force) or {}

        # Map calculated_at_iso -> calculated_at for schema stability
        ms = result.get("milestone_status") or {}
        if "calculated_at" not in ms and "calculated_at_iso" in ms:
            ms["calculated_at"] = ms.get("calculated_at_iso")
            result["milestone_status"] = ms

        return OrchestratorResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
