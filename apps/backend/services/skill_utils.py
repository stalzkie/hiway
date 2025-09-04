from __future__ import annotations
import re
from typing import Iterable, List, Dict

_WORDS = re.compile(r"[A-Za-z0-9+#.\-_/]+")

def _norm_tokens(s: str) -> List[str]:
    return [m.group(0).lower().strip() for m in _WORDS.finditer(s or "")]

def normalize_list(raw: Iterable[str]) -> List[str]:
    out: List[str] = []
    for item in raw or []:
        out.extend(_norm_tokens(item))
    # dedupe in order
    seen, uniq = set(), []
    for t in out:
        if t not in seen:
            seen.add(t); uniq.append(t)
    return uniq

def analyze_required_vs_seeker(required_raw: Iterable[str], seeker_raw: Iterable[str]) -> Dict[str, List[str] | float]:
    required = normalize_list(required_raw)
    seeker   = set(normalize_list(seeker_raw))
    matched  = [r for r in required if r in seeker]
    missing  = [r for r in required if r not in seeker]
    rate = (len(matched) / len(required) * 100.0) if required else 100.0
    return {
        "required_skills": required,
        "matched_skills": matched,
        "missing_skills": missing,
        "skills_match_rate": round(rate, 2),
    }
