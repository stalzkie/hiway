#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scraper.py — Role → Knowledge Milestones & Roadmap (LLM + SerpAPI, PH-first)

Usage:
  python scraper.py "social media manager" --max 10 --outdir /tmp

Env:
  SERPAPI_API_KEY=<your_serpapi_key>
  LLM_PROVIDER=auto|gemini|openai   (optional; default: auto)
  GEMINI_API_KEY=<your_gemini_key>  (if using Gemini)
  OPENAI_API_KEY=<your_openai_key>  (if using OpenAI)
  OPENAI_MODEL=gpt-4o-mini          (optional; default shown)
  GEMINI_MODEL=gemini-1.5-pro       (optional; default shown)
"""

import os
import re
import sys
import json
import time
import argparse
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Optional, Tuple
import urllib.parse

import requests

# ---------------- Env / Config ----------------
SERPAPI_KEY = os.getenv("SERPAPI_API_KEY")
SERPAPI_ENDPOINT = "https://serpapi.com/search.json"

LLM_PROVIDER = (os.getenv("LLM_PROVIDER") or "auto").lower()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

MAX_MILESTONES_HARD = 10

# ---------- Data Models ----------
@dataclass
class ResourceItem:
    title: str
    url: str
    source: Optional[str] = None

@dataclass
class MilestoneBundle:
    milestone: str                 # e.g., "Basic SEO", "Advanced Social Media Analytics"
    level: str                     # "Basic" | "Intermediate" | "Advanced"
    resources: List[ResourceItem]  # learning resources, free-first (PH-first)
    certifications: List[ResourceItem]  # certifications OR licenses (combined), max 3
    network_groups: List[ResourceItem]  # FB groups, forums, communities (PH-first)


# ---------- SerpAPI Client ----------
class SerpApiClient:
    def __init__(self, api_key: str, rate_delay: float = 1.0):
        if not api_key:
            raise RuntimeError(
                "SERPAPI_API_KEY is not set. Export SERPAPI_API_KEY and try again."
            )
        self.api_key = api_key
        self.rate_delay = rate_delay

    def search(self, query: str, num: int = 10, engine: str = "google", **kwargs) -> Dict[str, Any]:
        # Prioritize PH accessibility
        params = {
            "api_key": self.api_key,
            "engine": engine,
            "q": query,
            "num": max(10, min(100, num)),  # Google 'num' supports up to 100
            "gl": "ph",                     # country
            "hl": "en",                     # language
            "location": "Philippines",
            "google_domain": "google.com",  # serpapi will respect gl/location
        }
        params.update(kwargs)
        resp = requests.get(SERPAPI_ENDPOINT, params=params, timeout=30)
        if resp.status_code != 200:
            raise RuntimeError(f"SerpAPI error {resp.status_code}: {resp.text}")
        data = resp.json()
        time.sleep(self.rate_delay)
        return data


# ---------- LLM: Provider Selection ----------
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


# ---------- LLM: Prompt + Call ----------
def _compose_milestones_prompt(role: str, max_milestones: int) -> str:
    """
    Ask the LLM to output a JSON array of milestone dicts ordered from basic to advanced.
    """
    return (
        "You are designing an upskilling roadmap for a job seeker.\n"
        "TASK: Given the target role, propose leveled knowledge milestones that cover the journey from basic to advanced.\n"
        "CONSTRAINTS:\n"
        "• Use clear, general milestone titles that include a level (e.g., 'Basic SEO', 'Intermediate Content Strategy', 'Advanced Social Media Analytics').\n"
        "• Start from the fundamentals and progress to the most advanced topics needed for the role.\n"
        "• Order matters: milestones must be sorted from easiest (index 1) to hardest.\n"
        "• Limit the number of milestones to the provided max.\n"
        "• OUTPUT ONLY JSON: an array of objects, each with keys: milestone (string), level (Basic|Intermediate|Advanced).\n\n"
        f"role: {role}\n"
        f"max_milestones: {max_milestones}\n"
        "JSON EXAMPLE:\n"
        '[\n'
        '  {"milestone": "Basic SEO", "level": "Basic"},\n'
        '  {"milestone": "Intermediate On-Page Optimization", "level": "Intermediate"},\n'
        '  {"milestone": "Advanced Social Media Analytics", "level": "Advanced"}\n'
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
        # Try to extract the first JSON array
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
            arr = _safe_parse_json_array(text)
            return arr[:max_milestones] if arr else []
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
            arr = _safe_parse_json_array(text)
            return arr[:max_milestones] if arr else []
        except Exception:
            return []
    else:
        return []


# ---------- Resource Discovery (PH-first, free-first) ----------
def _score_domain_for_free_ph(domain: str, title: str) -> float:
    d = (domain or "").lower()
    t = (title or "").lower()
    score = 0.0
    # PH-first
    if d.endswith(".ph"):
        score += 2.0
    if "philippines" in t:
        score += 1.0
    # Free-first signals
    if "free" in t or "scholarship" in t or "open course" in t or "open-source" in t:
        score += 1.5
    # Helpful platforms
    if any(x in d for x in ("gov.ph",".edu",".org","youtube.com","google.com","facebook.com","reddit.com","medium.com","coursera.org","udemy.com","semrush.com","hubspot.com")):
        score += 0.8
    return score

def pick_top_resources_scored(organic: List[Dict[str, Any]], k: int = 3) -> List[ResourceItem]:
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

def search_resources_for_milestone(api: SerpApiClient, milestone_title: str) -> Tuple[List[ResourceItem], List[ResourceItem], List[ResourceItem]]:
    """
    Returns (resources, certifications_plus_licenses, network_groups) — each up to 3 items.
    Uses the LLM-provided milestone title directly in the queries:
      - "<Milestone> learning resources (articles, youtube videos, and other learning resources)"
      - "<Milestone> certifications (certifications from udemy, semrush, coursera, etc) [also licenses]"
      - "<Milestone> network groups (facebook groups, linkedin groups, reddit forums)"
    All queries prioritize Philippines accessibility and free content where applicable.
    """
    # Learning resources
    q_resources = (
        f'{milestone_title} learning resources (articles OR "youtube" OR video OR tutorial OR course) '
        f'("free" OR open) (Philippines OR site:.ph)'
    )
    data_res = api.search(q_resources, num=10)
    resources = pick_top_resources_scored(data_res.get("organic_results", []), k=3)

    # Certifications & Licenses (combined)
    q_cert = (
        f'{milestone_title} certifications OR certificate OR license OR licensing '
        f'(Udemy OR Coursera OR SEMrush OR HubSpot OR Google OR Meta) '
        f'(Philippines OR site:.ph)'
    )
    data_cert = api.search(q_cert, num=10)
    certs = pick_top_resources_scored(data_cert.get("organic_results", []), k=3)

    # Network groups — FB/LinkedIn/Reddit/forums/communities (PH-first)
    q_group = (
        f'{milestone_title} network groups ("Facebook group" OR "FB group" OR "LinkedIn group" OR reddit OR forum OR community OR meetup) '
        f'(Philippines OR site:.ph)'
    )
    data_grp = api.search(q_group, num=10)
    prioritized: List[Tuple[float, ResourceItem]] = []
    for item in data_grp.get("organic_results", []) or []:
        link = item.get("link") or item.get("url")
        title = (item.get("title") or "").strip()
        if not link or not title:
            continue
        domain = urllib.parse.urlparse(link).netloc.lower()
        base_score = _score_domain_for_free_ph(domain, title)
        if "facebook.com" in domain:
            base_score += 2.0
        if "linkedin.com" in domain:
            base_score += 1.2
        if "reddit.com" in domain or "discord" in domain or "telegram" in domain:
            base_score += 1.0
        if any(w in title.lower() for w in ("group","forum","community","meetup","chapter","society","association")):
            base_score += 0.5
        prioritized.append((base_score, ResourceItem(title=title, url=link, source=domain)))
    prioritized.sort(key=lambda x: x[0], reverse=True)
    groups = [ri for _, ri in prioritized[:3]]

    return (resources, certs, groups)


# ---------- Orchestrator ----------
def build_bundles(role: str, api: SerpApiClient, max_milestones: int = 10) -> List[MilestoneBundle]:
    """
    1) Use LLM to propose leveled, ordered milestone titles (Basic → Advanced).
    2) For each milestone, scrape resources/certs/groups (PH-first, free-first).
    3) Return ordered bundles for rendering.
    """
    max_milestones = min(MAX_MILESTONES_HARD, max(1, int(max_milestones)))
    milestones_llm = _llm_generate_milestones(role, max_milestones)

    # Hard fallback: if LLM unavailable, create a minimal two-step path
    if not milestones_llm:
        milestones_llm = [
            {"milestone": f"Basic {role.title()} Fundamentals", "level": "Basic"},
            {"milestone": f"Advanced {role.title()} Practice", "level": "Advanced"},
        ]

    bundles: List[MilestoneBundle] = []
    for m in milestones_llm:
        title = (m.get("milestone") or "").strip()
        level = (m.get("level") or "Basic").strip().title()
        res, cert, grp = search_resources_for_milestone(api, title)
        bundles.append(
            MilestoneBundle(
                milestone=title,
                level=level if level in {"Basic","Intermediate","Advanced"} else "Basic",
                resources=res,
                certifications=cert,
                network_groups=grp,
            )
        )
    return bundles


# ---------- Rendering ----------
def to_markdown(role: str, bundles: List[MilestoneBundle]) -> str:
    lines = []
    lines.append(f"# Upskilling Roadmap for **{role}** (Philippines)\n")
    lines.append("> Goal: ensure the learner progresses from fundamentals to the most advanced aspects of the role.\n")
    for i, b in enumerate(bundles, start=1):
        lines.append(f"## Milestone {i}: {b.milestone}  _(Level: {b.level})_")
        # Resources
        lines.append("**Resources (free-first)**")
        if b.resources:
            for it in b.resources:
                lines.append(f"- [{it.title}]({it.url})  · _{it.source}_")
        else:
            lines.append("- (none found)")
        # Certifications & Licenses (combined)
        lines.append("\n**Certifications & Licenses**")
        if b.certifications:
            for it in b.certifications:
                lines.append(f"- [{it.title}]({it.url})  · _{it.source}_")
        else:
            lines.append("- (none found)")
        # Network Groups
        lines.append("\n**Network Groups (FB groups, forums, communities)**")
        if b.network_groups:
            for it in b.network_groups:
                lines.append(f"- [{it.title}]({it.url})  · _{it.source}_")
        else:
            lines.append("- (none found)")
        lines.append("")  # spacer
    return "\n".join(lines).strip() + "\n"

def to_json(role: str, bundles: List[MilestoneBundle]) -> Dict[str, Any]:
    return {
        "role": role,
        "count": len(bundles),
        "milestones": [
            {
                "milestone": b.milestone,
                "level": b.level,
                "resources": [asdict(x) for x in b.resources],
                "certifications": [asdict(x) for x in b.certifications],
                "network_groups": [asdict(x) for x in b.network_groups],
            }
            for b in bundles
        ],
    }


# ---------- CLI ----------
def slugify(s: str) -> str:
    s = (s or "").strip().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or "role"

def main(argv=None):
    parser = argparse.ArgumentParser(description="LLM-generated milestones + SerpAPI resources (PH-first).")
    parser.add_argument("keyword", help='Target role, e.g. "social media manager"')
    parser.add_argument("--max", type=int, default=10, help="Max milestones (hard limit 10)")
    parser.add_argument("--outdir", type=str, default="/tmp", help="Directory to write JSON/MD outputs")
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds between SerpAPI calls (rate limit)")
    args = parser.parse_args(argv)

    if args.max > MAX_MILESTONES_HARD:
        print("[info] Hard limiting milestones to 10.", file=sys.stderr)
        args.max = MAX_MILESTONES_HARD

    # Prepare clients
    api = SerpApiClient(SERPAPI_KEY, rate_delay=args.delay)
    role = args.keyword.strip()

    # Build roadmap
    bundles = build_bundles(role, api, max_milestones=args.max)

    # Print JSON to stdout
    out_json = to_json(role, bundles)
    print(json.dumps(out_json, ensure_ascii=False, indent=2))

    # Write files
    os.makedirs(args.outdir, exist_ok=True)
    base = os.path.join(args.outdir, f"{slugify(role)}_milestones")
    with open(base + ".json", "w", encoding="utf-8") as f:
        json.dump(out_json, f, ensure_ascii=False, indent=2)
    with open(base + ".md", "w", encoding="utf-8") as f:
        f.write(to_markdown(role, bundles))

    print(f"\n[written] {base}.json", file=sys.stderr)
    print(f"[written] {base}.md", file=sys.stderr)


if __name__ == "__main__":
    main()
