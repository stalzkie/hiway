# apps/backend/api/endpoints/matcher.py
from __future__ import annotations

from typing import Optional, Dict, List, Any, Tuple
import os
import json

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field, EmailStr
from postgrest.exceptions import APIError as PostgrestAPIError

from apps.backend.services.matcher import (
    rank_posts_for_seeker,
    rank_posts_for_seeker_by_email,
    get_seeker_id_by_email,
    SB,  # Supabase client proxy
)
from apps.backend.services.skill_utils import analyze_required_vs_seeker

# ---------------------- LLM Provider Config ----------------------
# LLM_PROVIDER=gemini | openai | auto
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "auto").lower()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# ---------------------- Schemas ----------------------
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

router = APIRouter()

# ---------------------- Helpers ----------------------
def _coerce_to_list(field) -> List[str]:
    if field is None:
        return []
    if isinstance(field, list):
        return [str(x).strip() for x in field if str(x).strip()]
    if isinstance(field, str):
        return [x.strip() for x in field.split(",") if x.strip()]
    if isinstance(field, dict):
        # e.g., {"python": true, "sql": 1} -> ["python", "sql"]
        return [str(k).strip() for k, v in field.items() if str(k).strip()]
    return []

def _stringify(x: Any) -> str:
    if x is None:
        return ""
    if isinstance(x, str):
        return x
    try:
        return json.dumps(x, ensure_ascii=False)
    except Exception:
        return str(x)

def _fetch_seeker_skills(job_seeker_id: str) -> List[str]:
    resp = (
        SB.table("job_seeker")
        .select("skills")
        .eq("job_seeker_id", job_seeker_id)
        .limit(1)
        .execute()
    )
    if not resp.data:
        return []
    raw = resp.data[0].get("skills")
    return _coerce_to_list(raw)

def _fetch_seeker_context(job_seeker_id: str) -> Dict[str, Any]:
    """
    Schema-accurate for your `job_seeker` table:
      skills (jsonb), experience (jsonb), education (jsonb),
      licenses_certifications (jsonb), full_name, email
    """
    projection = "skills, experience, education, licenses_certifications, full_name, email"

    def _normalize(row: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "skills": _coerce_to_list(row.get("skills")),
            "experience_text": _stringify(row.get("experience")),
            "education_text": _stringify(row.get("education")),
            "licenses_certifications": _coerce_to_list(row.get("licenses_certifications")),
            "full_name": (row.get("full_name") or ""),
            "email": (row.get("email") or ""),
            # Keys kept for prompt compatibility (not in schema)
            "summary": "",
            "projects": [],
            "achievements": [],
            "portfolio": "",
        }

    try:
        resp = (
            SB.table("job_seeker")
            .select(projection)
            .eq("job_seeker_id", job_seeker_id)
            .limit(1)
            .execute()
        )
        if not resp.data:
            return {}
        return _normalize(resp.data[0] or {})
    except PostgrestAPIError as e:
        if e.code == "42703":
            # Minimal safe fallback
            resp = (
                SB.table("job_seeker")
                .select("skills")
                .eq("job_seeker_id", job_seeker_id)
                .limit(1)
                .execute()
            )
            if not resp.data:
                return {}
            row = resp.data[0] or {}
            return {
                "skills": _coerce_to_list(row.get("skills")),
                "experience_text": "",
                "education_text": "",
                "licenses_certifications": [],
                "full_name": "",
                "email": "",
                "summary": "",
                "projects": [],
                "achievements": [],
                "portfolio": "",
            }
        raise

def _build_job_context(job_post_row: Dict[str, Any]) -> Dict[str, Any]:
    """
    Schema-accurate for your `job_post` table.
    """
    if not job_post_row:
        return {}
    return {
        "job_title": job_post_row.get("job_title") or job_post_row.get("title") or "",
        "company": job_post_row.get("company") or job_post_row.get("employer") or "",
        "job_overview": _stringify(job_post_row.get("job_overview")),
        "job_skills": _coerce_to_list(job_post_row.get("job_skills")),
        "experience_req": _stringify(job_post_row.get("job_experience")),
        "education_req": _stringify(job_post_row.get("job_education")),
        "licenses_req": _stringify(job_post_row.get("job_licenses_certifications")),
        "location": job_post_row.get("location") or "",
        "seniority": job_post_row.get("seniority") or "",
    }

# ---------------------- LLM utilities ----------------------
def _select_provider() -> str:
    if LLM_PROVIDER == "gemini" and GEMINI_API_KEY:
        return "gemini"
    if LLM_PROVIDER == "openai" and OPENAI_API_KEY:
        return "openai"
    # auto
    if GEMINI_API_KEY:
        return "gemini"
    if OPENAI_API_KEY:
        return "openai"
    return "none"

def _safe_parse_json_map(text: str) -> Dict[str, str]:
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return {str(k): _stringify(v) for k, v in data.items()}
    except Exception:
        left = text.find("{")
        right = text.rfind("}")
        if left != -1 and right != -1 and right > left:
            try:
                data = json.loads(text[left:right + 1])
                if isinstance(data, dict):
                    return {str(k): _stringify(v) for k, v in data.items()}
            except Exception:
                pass
    return {}

def _trim_to_two_sentences(s: str) -> str:
    import re
    parts = re.split(r"(?<=[.!?])\s+", (s or "").strip())
    return " ".join(parts[:2]).strip() if len(parts) > 2 else (s or "").strip()

def _compose_skill_prompt(skills: List[str], job_ctx: Dict[str, Any], seeker_ctx: Dict[str, Any]) -> str:
    return (
        "You are assisting a job-matching system. For EACH skill in the provided list, "
        "write a concise 1–2 sentence explanation showing how the job seeker's background "
        "matches the job post's context for that skill. Be specific and grounded in the "
        "given details. If evidence is weak, state it cautiously.\n\n"
        "CRITICAL RULES:\n"
        "• Output ONLY valid JSON (an object/dict), no commentary.\n"
        "• The JSON keys must be the exact skill strings provided.\n"
        "• Each value must be a single string of 1–2 sentences. Avoid using too much jargons and simplify your sentences.\n\n"
        f"skills: {json.dumps(skills, ensure_ascii=False)}\n\n"
        f"job_context: {json.dumps(job_ctx, ensure_ascii=False)}\n\n"
        f"seeker_context: {json.dumps(seeker_ctx, ensure_ascii=False)}\n"
    )

def _compose_overall_prompt(
    confidence: float,
    section_scores: Dict[str, float],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
    matched: List[str],
    missing: List[str],
) -> str:
    return (
        "You are summarizing a job-match result produced by vector (semantic) similarity across sections. "
        "Write a concise 2–4 sentence explanation that helps the user understand WHY this score happened, "
        "even if there were few or no exact keyword matches. "
        "Ground the explanation in the per-section semantic similarities (skills/experience/education/licenses) "
        "and in the job vs seeker contexts. If there are no exact matches, clarify that the score still comes from "
        "semantic overlap in responsibilities, tools, or outcomes. Avoid using too much jargons and simplify your sentences.\n\n"
        "Output ONLY valid JSON with a single key 'overall_summary'.\n\n"
        f"confidence: {json.dumps(confidence)}\n"
        f"section_scores_0to100: {json.dumps(section_scores, ensure_ascii=False)}\n"
        f"matched_skills: {json.dumps(matched, ensure_ascii=False)}\n"
        f"missing_skills: {json.dumps(missing, ensure_ascii=False)}\n"
        f"job_context: {json.dumps(job_ctx, ensure_ascii=False)}\n"
        f"seeker_context: {json.dumps(seeker_ctx, ensure_ascii=False)}\n"
    )

def _llm_batch_explain_skills(
    skills: List[str],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
) -> Dict[str, str]:
    skills = [s for s in skills if s]
    if not skills:
        return {}
    provider = _select_provider()

    # Fallback: deterministic, non-LLM
    if provider == "none":
        return {
            s: f"{s}: The job requires '{s}', which appears in the candidate’s profile. "
               f"This suggests relevant exposure the employer is seeking."
            for s in skills
        }

    prompt = _compose_skill_prompt(skills, job_ctx, seeker_ctx)

    try:
        if provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel(
                os.getenv("GEMINI_MODEL", "gemini-1.5-pro"),
                generation_config={"temperature": 0.2, "response_mime_type": "application/json"},
            )
            resp = model.generate_content(prompt)
            text = (resp.text or "").strip()
        else:
            from openai import OpenAI
            client = OpenAI(api_key=OPENAI_API_KEY)
            resp = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
            )
            text = (resp.choices[0].message.content or "").strip()

        parsed = _safe_parse_json_map(text)
        return {k: _trim_to_two_sentences(v) for k, v in parsed.items() if k in skills} or {
            s: _trim_to_two_sentences(f"{s}: The candidate shows context relevant to '{s}' based on profile vs job needs.")
            for s in skills
        }
    except Exception:
        return {
            s: f"{s}: The job requires '{s}', and the candidate lists or demonstrates it in prior work/education."
            for s in skills
        }

def _llm_overall_summary(
    confidence: float,
    section_scores: Dict[str, float],
    job_ctx: Dict[str, Any],
    seeker_ctx: Dict[str, Any],
    matched: List[str],
    missing: List[str],
) -> str:
    provider = _select_provider()

    def _fallback() -> str:
        parts: List[str] = []
        strong = [k for k, v in (section_scores or {}).items() if isinstance(v, (int, float)) and v >= 80]
        if strong:
            parts.append(f"High semantic similarity in {', '.join(strong)} drove the score.")
        if matched:
            parts.append(f"Exact matches found for: {', '.join(matched[:5])}.")
        else:
            parts.append("No exact keyword matches were found; the score comes from semantic overlap between your background and the role’s requirements.")
        parts.append(f"Overall confidence is {round(confidence, 2)} based on weighted vector similarity across sections.")
        return " ".join(parts)

    if provider == "none":
        return _fallback()

    prompt = _compose_overall_prompt(confidence, section_scores, job_ctx, seeker_ctx, matched, missing)
    try:
        if provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel(
                os.getenv("GEMINI_MODEL", "gemini-1.5-pro"),
                generation_config={"temperature": 0.2, "response_mime_type": "application/json"},
            )
            resp = model.generate_content(prompt)
            text = (resp.text or "").strip()
        else:
            from openai import OpenAI
            client = OpenAI(api_key=OPENAI_API_KEY)
            resp = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
            )
            text = (resp.choices[0].message.content or "").strip()

        data = _safe_parse_json_map(text)
        summary = (data.get("overall_summary") or "").strip()
        return _trim_to_two_sentences(summary) if summary else _fallback()
    except Exception:
        return _fallback()

# ---------------------- Endpoint ----------------------
@router.get(
    "/match",
    response_model=MatchResponse,
    summary="Match Seeker To Jobs",
    description=(
        "Returns job posts ranked for the given job seeker via Pinecone cosine similarities. "
        "Provide either job_seeker_id or email (email will be resolved to a seeker UUID). "
        "Optionally include contextual LLM explanations (per skill + overall semantic summary)."
    ),
)
def match_seeker_to_jobs(
    job_seeker_id: Optional[str] = Query(
        None, description="UUID of the job seeker (leave empty if using email)"
    ),
    email: Optional[EmailStr] = Query(
        None,
        description="Look up seeker by email (alternative to job_seeker_id)",
        example="dstalingrad@gmail.com",
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
            include_job_details=True,  # force details for job_skills
            min_sections=min_sections,
        )
    else:
        matches = rank_posts_for_seeker(
            job_seeker_id=job_seeker_id,
            top_k_per_section=top_k,
            include_job_details=True,  # force details for job_skills
            min_sections=min_sections,
        )

    # 4) Fetch seeker skills & optional context once
    seeker_skills = _fetch_seeker_skills(job_seeker_id)
    seeker_ctx = _fetch_seeker_context(job_seeker_id) if include_explanations else {}

    # 5) Enrich with skill analysis (+ explanations and overall summary)
    enriched: List[Dict[str, Any]] = []
    for m in matches:
        item = dict(m)
        jp = item.get("job_post") or {}

        required_raw = _coerce_to_list(jp.get("job_skills"))

        analysis_dict: Dict[str, Any] = {
            "required_skills": [],
            "matched_skills": [],
            "missing_skills": [],
            "skills_match_rate": 0.0,
        }

        if required_raw or seeker_skills:
            analysis_dict = analyze_required_vs_seeker(required_raw, seeker_skills)

            # Per-skill explanations
            if include_explanations and analysis_dict.get("matched_skills"):
                job_ctx = _build_job_context(jp)
                matched = analysis_dict.get("matched_skills", [])
                if matched:
                    explanations = _llm_batch_explain_skills(matched, job_ctx, seeker_ctx)
                    explanations = {k: v for k, v in explanations.items() if k in matched}
                    if explanations:
                        analysis_dict["matched_explanations"] = explanations

        # Overall semantic summary (always when include_explanations=true)
        if include_explanations:
            job_ctx = _build_job_context(jp)
            matched = analysis_dict.get("matched_skills", []) or []
            missing = analysis_dict.get("missing_skills", []) or []
            section_scores_out = item.get("section_scores", {}) or {}
            overall = _llm_overall_summary(
                confidence=float(item.get("confidence", 0.0)),
                section_scores=section_scores_out,
                job_ctx=job_ctx,
                seeker_ctx=seeker_ctx,
                matched=matched,
                missing=missing,
            )
            if overall:
                analysis_dict["overall_summary"] = overall

        # Optional pretty print
        sec = item.get("section_scores", {}) or {}
        print(
            "\n=== MATCH (job_post_id={}) ===\n"
            "Overall: {}%\n"
            "Sections → skills:{} exp:{} edu:{} lic:{}\n"
            "Required: {}\n"
            "Matched: {}\n"
            "Missing: {}\n"
            "Skills match rate: {}%\n".format(
                item.get("job_post_id"),
                item.get("confidence"),
                sec.get("skills"),
                sec.get("experience"),
                sec.get("education"),
                sec.get("licenses"),
                ", ".join(analysis_dict.get("required_skills", [])) or "(none)",
                ", ".join(analysis_dict.get("matched_skills", [])) or "(none)",
                ", ".join(analysis_dict.get("missing_skills", [])) or "(none)",
                analysis_dict.get("skills_match_rate", 0.0),
            )
        )

        item["analysis"] = analysis_dict
        enriched.append(item)

    return MatchResponse(
        job_seeker_id=job_seeker_id,
        count=len(enriched),
        matches=[MatchItem.model_validate(i) for i in enriched],
    )
