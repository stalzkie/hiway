from __future__ import annotations

import os
import re
import json
from typing import List, Dict, Any, Optional, Tuple

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field

import requests
import urllib.parse

router = APIRouter()

# -------- Config (env) --------
SERPAPI_KEY = os.getenv("SERPAPI_API_KEY")
SERPAPI_ENDPOINT = "https://serpapi.com/search.json"

LLM_PROVIDER = (os.getenv("LLM_PROVIDER") or "auto").lower()  # auto | gemini | openai
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

# -------- Models --------
class ResourceItem(BaseModel):
    title: str
    url: str
    source: Optional[str] = None

class MilestoneBundle(BaseModel):
    milestone: str                   # e.g., "Basic SEO", "Advanced Social Media Analytics"
    level: str                       # "Basic" | "Intermediate" | "Advanced"
    resources: List[ResourceItem]    # free-first, PH-first learning materials
    certifications: List[ResourceItem]  # includes certifications OR licenses (combined)
    network_groups: List[ResourceItem]  # FB groups, forums, communities; PH-first

class ScraperResponse(BaseModel):
    role: str = Field(..., description="The role keyword you searched")
    count: int = Field(..., description="Number of milestones returned")
    milestones: List[MilestoneBundle]

# -------- SerpAPI helper --------
def serpapi_search(query: str, num: int = 10) -> Dict[str, Any]:
    if not SERPAPI_KEY:
        raise RuntimeError("SERPAPI_API_KEY not set in environment")
    params = {
        "api_key": SERPAPI_KEY,
        "engine": "google",
        "q": query,
        "num": max(10, min(100, num)),
        # PH-first bias
        "gl": "ph",
        "hl": "en",
        "location": "Philippines",
        "google_domain": "google.com",
    }
    resp = requests.get(SERPAPI_ENDPOINT, params=params, timeout=30)
    if resp.status_code != 200:
        raise RuntimeError(f"SerpAPI error {resp.status_code}: {resp.text}")
    return resp.json()

def _score_domain_for_free_ph(domain: str, title: str) -> float:
    d = (domain or "").lower()
    t = (title or "").lower()
    score = 0.0
    # PH-first
    if d.endswith(".ph"):
        score += 2.0
    if "philippines" in t:
        score += 1.0
    # Free-first
    if any(w in t for w in ("free", "scholarship", "open course", "open-source", "open education")):
        score += 1.5
    # Useful platforms
    if any(x in d for x in ("gov.ph", ".edu", ".org", "youtube.com", "facebook.com", "google.com",
                            "reddit.com", "medium.com", "coursera.org", "udemy.com", "semrush.com", "hubspot.com")):
        score += 0.8
    return score

def _pick_top_scored(organic: List[Dict[str, Any]], k: int = 3) -> List[ResourceItem]:
    scored: List[Tuple[float, ResourceItem]] = []
    for item in organic or []:
        link = item.get("link") or item.get("url")
        title = (item.get("title") or item.get("name") or "").strip()
        if not link or not title:
            continue
        domain = urllib.parse.urlparse(link).netloc
        s = _score_domain_for_free_ph(domain, title)
        scored.append((s, ResourceItem(title=title, url=link, source=domain)))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [ri for _, ri in scored[:k]]

# -------- LLM helpers --------
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

def _compose_milestones_prompt(role: str, max_milestones: int) -> str:
    return (
        "You are designing an upskilling roadmap for a job seeker.\n"
        "TASK: Given the target role, propose leveled knowledge milestones that cover the journey from basic to advanced.\n"
        "GOAL: Ensure the learner progresses from fundamentals to the most advanced aspects of the role.\n"
        "CONSTRAINTS:\n"
        "• Use clear, general milestone titles that include a level (e.g., 'Basic SEO', 'Intermediate Content Strategy', 'Advanced Social Media Analytics').\n"
        "• Order matters: milestones must be sorted from easiest (index 1) to hardest.\n"
        "• Limit the number of milestones to the provided max.\n"
        "• OUTPUT ONLY JSON: an array of objects, each with keys: milestone (string), level (Basic|Intermediate|Advanced).\n\n"
        f"role: {role}\n"
        f"max_milestones: {max_milestones}\n"
        "JSON EXAMPLE:\n"
        '[\n'
        '  {\"milestone\": \"Basic SEO\", \"level\": \"Basic\"},\n'
        '  {\"milestone\": \"Intermediate On-Page Optimization\", \"level\": \"Intermediate\"},\n'
        '  {\"milestone\": \"Advanced Social Media Analytics\", \"level\": \"Advanced\"}\n'
    )

def _safe_parse_json_array(text: str) -> List[Dict[str, Any]]:
    try:
        data = json.loads(text)
        if isinstance(data, list):
            out = []
            for it in data:
                if isinstance(it, dict) and "milestone" in it and "level" in it:
                    out.append({"milestone": str(it["milestone"]).strip(),
                                "level": str(it["level"]).strip()})
            return out
    except Exception:
        left = text.find("[")
        right = text.rfind("]")
        if left != -1 and right != -1 and right > left:
            try:
                data = json.loads(text[left:right+1])
                if isinstance(data, list):
                    out = []
                    for it in data:
                        if isinstance(it, dict) and "milestone" in it and "level" in it:
                            out.append({"milestone": str(it["milestone"]).strip(),
                                        "level": str(it["level"]).strip()})
                    return out
            except Exception:
                pass
    return []

def _llm_generate_milestones(role: str, max_milestones: int) -> List[Dict[str, str]]:
    provider = _select_provider()
    prompt = _compose_milestones_prompt(role, max_milestones)

    if provider == "gemini":
        try:
            import google.generativeai as genai
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel(GEMINI_MODEL)
            resp = model.generate_content(prompt)
            text = (getattr(resp, "text", None) or "").strip()
            return _safe_parse_json_array(text)[:max_milestones]
        except Exception:
            return []
    elif provider == "openai":
        try:
            from openai import OpenAI
            client = OpenAI(api_key=OPENAI_API_KEY)
            resp = client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
            )
            text = (resp.choices[0].message.content or "").strip()
            return _safe_parse_json_array(text)[:max_milestones]
        except Exception:
            return []
    else:
        return []

# -------- Resource search using LLM milestone titles --------
def search_sections_for_milestone(milestone_title: str) -> Tuple[List[ResourceItem], List[ResourceItem], List[ResourceItem]]:
    # Resources (free-first; PH-first)
    q_resources = (
        f'{milestone_title} learning resources (articles OR "youtube" OR video OR tutorial OR course) '
        f'("free" OR open) (Philippines OR site:.ph)'
    )
    res_data = serpapi_search(q_resources, num=10)
    resources = _pick_top_scored(res_data.get("organic_results", []), k=3)

    # Certifications & Licenses (combined; PH-first)
    q_cert = (
        f'{milestone_title} certifications OR certificate OR license OR licensing '
        f'(Udemy OR Coursera OR SEMrush OR HubSpot OR Google OR Meta) '
        f'(Philippines OR site:.ph)'
    )
    cert_data = serpapi_search(q_cert, num=10)
    certs = _pick_top_scored(cert_data.get("organic_results", []), k=3)

    # Network groups — FB/LinkedIn/Reddit/forums/communities (PH-first)
    q_group = (
        f'{milestone_title} network groups ("Facebook group" OR "FB group" OR "LinkedIn group" OR reddit OR forum OR community OR meetup) '
        f'(Philippines OR site:.ph)'
    )
    grp_data = serpapi_search(q_group, num=10)

    prioritized: List[Tuple[float, ResourceItem]] = []
    for item in grp_data.get("organic_results", []) or []:
        link = item.get("link") or item.get("url")
        title = (item.get("title") or "").strip()
        if not link or not title:
            continue
        domain = urllib.parse.urlparse(link).netloc.lower()
        base = _score_domain_for_free_ph(domain, title)
        if "facebook.com" in domain:
            base += 2.0
        if "linkedin.com" in domain:
            base += 1.2
        if "reddit.com" in domain or "discord" in domain or "telegram" in domain:
            base += 1.0
        if any(w in title.lower() for w in ("group", "forum", "community", "meetup", "chapter", "society", "association")):
            base += 0.5
        prioritized.append((base, ResourceItem(title=title, url=link, source=domain)))
    prioritized.sort(key=lambda x: x[0], reverse=True)
    groups = [ri for _, ri in prioritized[:3]]

    return resources, certs, groups

# -------- Endpoint --------
@router.get(
    "/scrape",
    response_model=ScraperResponse,
    summary="Roadmap: LLM milestones + SerpAPI resources (PH-first)",
    description=(
        "Generates leveled, ordered knowledge milestones via LLM (Gemini/OpenAI) for the target role, "
        "then fills each milestone with 3 Resources (free-first, PH-first), "
        "3 Certifications & Licenses (combined), and 3 Network Groups (FB/forums/communities; PH-first)."
    ),
)
def scrape(
    keyword: str = Query(..., description="Target role, e.g. 'software engineer'"),
    max_milestones: int = Query(10, le=10, description="Maximum milestones (hard limit 10)"),
) -> ScraperResponse:
    try:
        # 1) Ask LLM for leveled, ordered milestone titles (Basic → Advanced)
        milestones = _llm_generate_milestones(keyword, max_milestones)

        # Fallback to minimal plan if LLM not available
        if not milestones:
            milestones = [
                {"milestone": f"Basic {keyword.title()} Fundamentals", "level": "Basic"},
                {"milestone": f"Advanced {keyword.title()} Practice", "level": "Advanced"},
            ]

        # 2) For each milestone, fetch 3 items for each section
        bundles: List[MilestoneBundle] = []
        for m in milestones:
            title = (m.get("milestone") or "").strip()
            level = (m.get("level") or "Basic").strip().title()
            resources, certs, groups = search_sections_for_milestone(title)
            bundles.append(
                MilestoneBundle(
                    milestone=title,
                    level=level if level in {"Basic", "Intermediate", "Advanced"} else "Basic",
                    resources=resources,
                    certifications=certs,
                    network_groups=groups,
                )
            )

        return ScraperResponse(role=keyword, count=len(bundles), milestones=bundles)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
