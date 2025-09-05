# apps/backend/api/endpoints/scraper.py
from __future__ import annotations

import os
import json
from typing import List, Dict, Any, Set

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field

# Local imports from the services module
from ...services.scraper import (
    _llm_generate_roadmap,
    search_sections_for_milestone,
    CERT_ALLOWED_DOMAINS,
)
from ...services.data_storer import persist_scraper_roadmap_with_resources

router = APIRouter()

# -------- Config (env) --------
SERPAPI_KEY = os.getenv("SERPAPI_API_KEY")
LLM_PROVIDER = (os.getenv("LLM_PROVIDER") or "auto").lower()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

# -------- Models --------
class ResourceItem(BaseModel):
    title: str
    url: str | None = None
    source: str | None = None

class MilestoneBundle(BaseModel):
    milestone: str
    level: str
    resources: list[ResourceItem]
    certifications: list[ResourceItem]
    network_groups: list[ResourceItem]

class ScraperResponse(BaseModel):
    role: str = Field(..., description="The role keyword you searched")
    roadmap_id: str | None = Field(None, description="Supabase roadmap_id for this role")
    count: int = Field(..., description="Number of milestones returned")
    milestones: list[MilestoneBundle]

def _coerce_items(items: list[Any]) -> list[ResourceItem]:
    """Coerce dicts or arbitrary objects into endpoint's Pydantic ResourceItem."""
    out: list[ResourceItem] = []
    for it in items or []:
        if isinstance(it, dict):
            out.append(ResourceItem(**{k: it.get(k) for k in ("title", "url", "source")}))
        else:
            out.append(
                ResourceItem(
                    title=getattr(it, "title", None),
                    url=getattr(it, "url", None),
                    source=getattr(it, "source", None),
                )
            )
    return out

# -------- Endpoint --------
@router.get(
    "/scrape",
    response_model=ScraperResponse,
    summary="Roadmap: LLM milestones + SerpAPI resources (PH-first)",
    description=(
        "Generates leveled, ordered knowledge milestones via a single LLM call for the target role, "
        "including 3 specific certificate names per milestone. "
        "Then fills each milestone with 3 Resources (free-first, PH-first), "
        "resolves the 3 specific certifications to exact URLs with strict checks, "
        "and finds 3 Network Groups (FB/forums/communities; PH-first). "
        "Global URL dedup ensures no link repeats across milestones or sections. "
        "The roadmap and milestone resources are also persisted into Supabase."
    ),
)
def scrape(
    keyword: str = Query(..., description="Target role, e.g. 'software engineer'"),
    max_milestones: int = Query(10, le=10, description="Maximum milestones (hard limit 10)"),
) -> ScraperResponse:
    try:
        # 1) Ask LLM for milestones + 3 cert names per milestone
        roadmap = _llm_generate_roadmap(
            role=keyword,
            max_milestones=max_milestones,
            provider=LLM_PROVIDER,
            gemini_api_key=GEMINI_API_KEY,
            openai_api_key=OPENAI_API_KEY,
            openai_model=OPENAI_MODEL,
            gemini_model=GEMINI_MODEL,
        )

        print("\n[llm→roadmap] Proposed milestones & certifications:")
        if roadmap:
            print(json.dumps(roadmap, indent=2))
        else:
            print("  (No roadmap produced by LLM; using fallback.)")
            roadmap = [
                {"milestone": f"Basic {keyword.title()} Fundamentals", "level": "Basic", "cert_names": [
                    "Google Data Analytics Professional Certificate",
                    "Intuit Bookkeeping Professional Certificate",
                    "HubSpot Inbound Marketing Certification",
                ]},
                {"milestone": f"Advanced {keyword.title()} Practice", "level": "Advanced", "cert_names": [
                    "SEMrush SEO Toolkit Exam",
                    "Xero Advisor Certification",
                    "QuickBooks Online Certification Exam",
                ]},
            ]

        # 2) For each milestone, fetch sections (dedup globally)
        bundles: list[MilestoneBundle] = []
        used_urls: Set[str] = set()
        used_cert_names: Set[str] = set()
        milestone_resources: list[tuple] = []

        for m in roadmap[:max_milestones]:
            title = (m.get("milestone") or "").strip()
            level = (m.get("level") or "Basic").strip().title()
            cert_names = [str(x).strip() for x in (m.get("cert_names") or [])][:3]

            print(f'\n[milestone] {title}  (Level: {level})')
            resources, certs, groups = search_sections_for_milestone(
                milestone_title=title,
                cert_names=cert_names,
                used_urls=used_urls,
                used_cert_names=used_cert_names,
                serpapi_key=SERPAPI_KEY,
            )

            milestone_resources.append((resources, certs, groups))

            bundles.append(
                MilestoneBundle(
                    milestone=title,
                    level=level if level in {"Basic", "Intermediate", "Advanced"} else "Basic",
                    resources=_coerce_items(resources),
                    certifications=_coerce_items(certs),
                    network_groups=_coerce_items(groups),
                )
            )

        # 3) Persist roadmap + resources into Supabase
        roadmap_id = persist_scraper_roadmap_with_resources(
            role=keyword,
            provider=LLM_PROVIDER,
            model=(GEMINI_MODEL if LLM_PROVIDER == "gemini" else OPENAI_MODEL),
            milestones=roadmap,
            prompt_template_or_hashable="default-roadmap-prompt",
            cert_allowlist_or_hashable=CERT_ALLOWED_DOMAINS,
            milestone_resources=milestone_resources,
        )

        return ScraperResponse(role=keyword, roadmap_id=roadmap_id, count=len(bundles), milestones=bundles)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
