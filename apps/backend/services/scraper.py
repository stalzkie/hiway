from __future__ import annotations

import os
import re
import json
from typing import List, Dict, Any, Optional, Tuple, Set
from .data_storer import persist_scraper_roadmap_with_resources

import requests
import urllib.parse

# -------- Optional BeautifulSoup (graceful fallback; no hard lxml dep) --------
try:
    from bs4 import BeautifulSoup, FeatureNotFound  # type: ignore
except Exception:  # bs4 missing or partial
    BeautifulSoup = None  # type: ignore

    class FeatureNotFound(Exception):  # type: ignore
        ...

def _best_soup(html: str):
    if not BeautifulSoup:
        return None
    for parser in ("lxml", "html.parser", "html5lib"):
        try:
            return BeautifulSoup(html, parser)  # type: ignore
        except FeatureNotFound:
            continue
        except Exception:
            continue
    return None

# -------- Certificate domain guards (EXPANDED + issuers) --------
CERT_ALLOWED_DOMAINS: List[str] = [
    "grow.google",
    "skillshop.withgoogle.com",
    "skillshop.exceedlms.com",
    "cloud.google.com",
    "cloudskillsboost.google",
    "developers.google.com",
    "coursera.org",
    "edx.org",
    "udacity.com",
    "deeplearning.ai",
    "academy.hubspot.com",
    "semrush.com",
    "moz.com",
    "academy.moz.com",
    "yoast.com",
    "academy.intuit.com",
    "quickbooks.intuit.com",
    "xero.com",
    "ibm.com",
    "learn.microsoft.com",
    "microsoft.com",
    "aws.amazon.com",
    "aws.training",
    "tableau.com",
    "tensorflow.org",
    "pythoninstitute.org",
    "oracle.com",
    "cisco.com",
    "cloudera.com",
    "sas.com",
    "datacamp.com",
    "alison.com",
    "salesforce.com",
    "trailhead.salesforce.com",
    "ads.google.com",
    "support.google.com",
    "academy.adobe.com",
    "certification.adobe.com",
    "credly.com",
    "comptia.org",
    "ec-council.org",
    "isaca.org",
    "offensive-security.com",
    "giac.org",
    "redhat.com",
    "vmware.com",
    "fortinet.com",
    "splunk.com",
    "pmi.org",
    "scrum.org",
    "scrumalliance.org",
    "cfainstitute.org",
    "accaglobal.com",
    "hbr.org",
    "autodesk.com",
    "unity.com",
    "unrealengine.com",
    "adobe.com",
    "medscape.org",
    "who.int",
    "ama-assn.org",
    "nursingworld.org",
    "osha.gov",
    "nccer.org",
    "hvacexcellence.org",
    "nsc.org",
    "linkedin.com/learning",
    "ahrefs.com/academy",
    "mailchimp.com/resources/certification",
    "hootsuite.com/education",
    "meta.com/blueprint",
    "twitterflightschool.com",
    "tiktokacademy.com",
    "google.com/partners",
    "upwork.com/academy",
    "fiverr.com/learn",
    "gohighlevel.com",
    "canva.com/designschool/certifications",
    "blender.org/certification",
    "gcfglobal.org",
    "ic3digitalliteracy.org",
    "typing.com",
]

# Explicitly NOT treating these as cert issuers for direct cert URLs
# (we might still use them as NETWORK GROUPS or RESOURCES elsewhere)
CERT_DENY_DOMAINS: Set[str] = {
    "quizlet.com",
    "reddit.com",
    "community.hubspot.com",
    "coursemon.net",
    "krcmic.com",
    "medium.com",
    "facebook.com",           # communities ok elsewhere, not cert detail
    "business.facebook.com",  # communities ok elsewhere, not cert detail
    "linkedin.com",           # learning pages are courses, not official certs
    "learning.linkedin.com",
    "udemy.com",              # courses, not official vendor certs
}

# RELAXED PATH RESTRICTIONS (still block obvious non-cert areas)
CERT_DENY_PATHS: Tuple[str, ...] = (
    "/blog", "/blogs", "/post", "/posts", "/answers", "/community", "/forum", "/discussions",
    "/q-a", "/help", "/support/faq", "/news", "/press", "/careers", "/about", "/articles",
)

# -------- Issuer hints: prefer official domains when the name implies them --------
ISSUER_HINTS: List[Tuple[str, str]] = [
    (r"\baws certified\b|\baws\b",                                   "aws.amazon.com"),
    (r"\bmicrosoft certified\b|\bazure\b",                           "learn.microsoft.com"),
    (r"\bgoogle cloud certified\b|\bgcp\b|\bmachine learning engineer\b", "cloud.google.com"),
    (r"\btensorflow developer certificate\b|\btensorflow\b",         "tensorflow.org"),
    (r"\bpcep\b|\bpcap\b|\bpython institute\b",                      "pythoninstitute.org"),
    (r"\btableau\b",                                                 "tableau.com"),
    (r"\bhubspot\b",                                                 "academy.hubspot.com"),
    (r"\bsemrush\b",                                                 "semrush.com"),
    (r"\bdeeplearning\.ai\b|\bdeep learning specialization\b",       "deeplearning.ai"),
    (r"\budacity\b|\bnanodegree\b",                                  "udacity.com"),
    (r"\bcoursera\b|\bspecialization\b|\bprofessional certificate\b","coursera.org"),
]

def _preferred_domain_for_name(name: str) -> Optional[str]:
    import re
    n = (name or "").lower()
    for pat, dom in ISSUER_HINTS:
        if re.search(pat, n):
            return dom
    return None

# -------- Shared helpers (URL, tokens, checks) --------
def _normalize_url(u: str) -> str:
    if not u:
        return ""
    try:
        p = urllib.parse.urlparse(u)
        host = (p.netloc or "").lower()
        path = urllib.parse.unquote(p.path or "")
        if path.endswith("/") and path != "/":
            path = path[:-1]
        tracking = {"gclid", "fbclid"}
        q_pairs = urllib.parse.parse_qsl(p.query, keep_blank_values=True)
        q_pairs = [(k, v) for (k, v) in q_pairs if not (k.startswith("utm_") or k in tracking)]
        query = urllib.parse.urlencode(q_pairs, doseq=True)
        norm = urllib.parse.urlunparse(("", host, path, "", query, ""))
        return norm or host
    except Exception:
        return u.strip()

def _not_used(norm_url: str, used: Set[str]) -> bool:
    return bool(norm_url) and (norm_url not in used)

def _domain(u: str) -> str:
    try:
        return (urllib.parse.urlparse(u).netloc or "").lower()
    except Exception:
        return ""

_STOPWORDS = {
    "the", "and", "for", "of", "to", "in", "on", "with", "online", "free", "course", "courses",
    "program", "programs", "professional", "certificate", "certificates", "certification",
    "certifications", "exam", "assessment", "credential", "credentials", "individual", "qualification",
}
def _tokens(s: str) -> List[str]:
    s = (s or "").lower()
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return [w for w in s.split() if w and w not in _STOPWORDS]

_CERT_TITLE_POS = ("certificate", "certification", "exam", "qualification", "credential", "specialization", "nanodegree")
_CERT_TITLE_NEG = ("degree", "degrees", "catalog", "pricing", "plans", "for business", "overview", "what is", "about", "article", "blog")
def _title_looks_like_cert(title: str) -> bool:
    if not title:
        return False
    t = title.strip().lower()
    if not any(k in t for k in _CERT_TITLE_POS):
        return False
    if any(k in t for k in _CERT_TITLE_NEG):
        return False
    return True

def _path_validation_relaxed(link: str) -> bool:
    """Lenient path validation but block obvious non-cert areas."""
    try:
        path = urllib.parse.urlparse(link).path.lower()
        if any(path.startswith(p) or p in path for p in CERT_DENY_PATHS):
            return False
        # Likely credential paths
        if any(seg in path for seg in ("/certificate", "/certification", "/professional-certificates", "/specializations",
                                       "/certificates", "/training", "/academy", "/learn", "/education")):
            return True
        # Accept depth >= 1
        segments = [seg for seg in path.strip("/").split("/") if seg]
        return len(segments) >= 1
    except Exception:
        return True  # allow on parse failure

def _url_covers_name_tokens(link: str, name: str, min_frac: float = 0.6) -> bool:
    """Require ~60% of name tokens to appear in host+path (vs ALL)."""
    try:
        p = urllib.parse.urlparse(link)
        haystack = (p.netloc + p.path).lower()
    except Exception:
        return False
    toks = _tokens(name)
    if len(toks) < 2:
        return True
    hits = sum(1 for t in toks if t in haystack)
    return (hits / len(toks)) >= min_frac

def _title_similarity(a: str, b: str) -> float:
    A, B = set(_tokens(a)), set(_tokens(b))
    if not A:
        return 0.0
    return len(A & B) / float(len(A))

def _is_likely_cert_domain(domain: str, title: str) -> bool:
    """Flexible domain validation: allow official issuers and credential-y domains."""
    d = (domain or "").lower()
    t = (title or "").lower()
    if any(d == allowed or d.endswith("." + allowed) for allowed in CERT_ALLOWED_DOMAINS):
        return True
    # As a fallback: sites that look like academies + cert-like title
    if any(ind in d for ind in ("academy", "certification", "train", "learn", "education", "skill", "campus")):
        if any(w in t for w in ("certificate", "certification", "exam", "credential")):
            return True
    return False

# -------- SerpAPI helper --------
SERPAPI_ENDPOINT = "https://serpapi.com/search.json"

def serpapi_search(query: str, serpapi_key: str, num: int = 10) -> Dict[str, Any]:
    if not serpapi_key:
        raise RuntimeError("SERPAPI_API_KEY not set in environment")
    params = {
        "api_key": serpapi_key,
        "engine": "google",
        "q": query,
        "num": max(10, min(100, num)),
        "gl": "ph",
        "hl": "en",
        "location": "Philippines",
        "google_domain": "google.com",
    }
    resp = requests.get(SERPAPI_ENDPOINT, params=params, timeout=30)
    if resp.status_code != 200:
        raise RuntimeError(f"SerpAPI error {resp.status_code}: {resp.text}")
    return resp.json()

# -------- Scoring for resources/groups (PH-first, free-first) --------
def _score_domain_for_free_ph(domain: str, title: str) -> float:
    d = (domain or "").lower()
    t = (title or "").lower()
    score = 0.0
    if d.endswith(".ph"):
        score += 2.0
    if "philippines" in t:
        score += 1.0
    if any(w in t for w in ("free", "scholarship", "open course", "open-source", "open education")):
        score += 1.5
    if any(x in d for x in ("gov.ph", ".edu", ".org", "youtube.com", "facebook.com", "google.com",
                            "reddit.com", "medium.com", "coursera.org", "udemy.com", "semrush.com", "hubspot.com")):
        score += 0.8
    return score

def _pick_top_scored(
    organic: List[Dict[str, Any]],
    used_urls: Set[str],
    k: int = 3,
    exclude_domains: Optional[Set[str]] = None,
) -> List[Dict[str, Optional[str]]]:
    ex = exclude_domains or set()
    scored: List[Tuple[float, Dict[str, Optional[str]], str]] = []
    for item in organic or []:
        link = item.get("link") or item.get("url")
        title = (item.get("title") or item.get("name") or "").strip()
        if not link or not title:
            continue
        norm = _normalize_url(link)
        if not _not_used(norm, used_urls):
            continue
        domain = urllib.parse.urlparse(link).netloc.lower()
        if any(domain == d or domain.endswith("." + d) for d in ex):
            continue  # keep cert issuers out of Resources
        s = _score_domain_for_free_ph(domain, title)
        scored.append((s, {"title": title, "url": link, "source": domain}, norm))
    scored.sort(key=lambda x: x[0], reverse=True)
    out: List[Dict[str, Optional[str]]] = []
    for _, ri, norm in scored:
        if len(out) >= k:
            break
        out.append(ri)
        used_urls.add(norm)
    return out

# -------- LLM helpers (one-shot: milestones + 3 cert names) --------
def _select_provider(provider: str, gemini_api_key: str, openai_api_key: str) -> str:
    if provider == "gemini" and gemini_api_key:
        return "gemini"
    if provider == "openai" and openai_api_key:
        return "openai"
    if gemini_api_key:
        return "gemini"
    if openai_api_key:
        return "openai"
    return "none"

def _compose_roadmap_prompt(role: str, max_milestones: int) -> str:
    return (
        "You are designing an upskilling roadmap for a job seeker focused on the Philippines.\n"
        "TASK: Given the target ROLE, propose leveled knowledge milestones (Basic → Advanced) AND, for each milestone, make sure this roadmap is centered around the job economy of the Philippines\n"
        "You can create only a MAX of 10 knowledge milestones and a standard of 5-8 milestones. The more complicated the jobs, the more milestones.\n"
        "list EXACTLY 3 specific certificates/licenses that validate skills for that milestone.\n"
        "STRICT RULES:\n"
        "• Certificates must be SPECIFIC credential names with EXACT titles as they appear on official sites.\n"
        "• PREFER certificates from: Google, Google Cloud, HubSpot, Microsoft, AWS, IBM, Tableau, Coursera/DeepLearning.AI, edX, Udacity.\n"
        "• Each item MUST include 'Certificate', 'Certification', 'Exam', 'Credential', 'Specialization', or 'Nanodegree' in the name.\n"
        "• Use EXACT official names (e.g., 'Google Data Analytics Professional Certificate').\n"
        "• DO NOT output homepages, catalogs, degree programs, or vague items.\n"
        "• OUTPUT ONLY JSON: an array of objects, each with keys:\n"
        "  - milestone (string),\n"
        "  - level (Basic|Intermediate|Advanced),\n"
        "  - cert_names (array of EXACT credential names, length 3).\n\n"
        f"ROLE: {role}\n"
        f"MAX_MILESTONES: {max_milestones}\n"
        "JSON EXAMPLE:\n"
        "[\n"
        "  {\n"
        "    \"milestone\": \"Basic Accounting Principles\",\n"
        "    \"level\": \"Basic\",\n"
        "    \"cert_names\": [\n"
        "      \"Intuit Bookkeeping Professional Certificate\",\n"
        "      \"Google Data Analytics Professional Certificate\",\n"
        "      \"HubSpot Inbound Marketing Certification\"\n"
        "    ]\n"
        "  }\n"
        "]\n"
        "Return ONLY valid JSON (no commentary)."
    )

def _safe_parse_roadmap_json(text: str) -> List[Dict[str, Any]]:
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return data
    except Exception:
        pass
    left = text.find("[")
    right = text.rfind("]")
    if left != -1 and right != -1 and right > left:
        try:
            data = json.loads(text[left:right + 1])
            if isinstance(data, list):
                return data
        except Exception:
            pass
    return []

def _llm_generate_roadmap(
    role: str,
    max_milestones: int,
    provider: str,
    gemini_api_key: str,
    openai_api_key: str,
    openai_model: str,
    gemini_model: str,
) -> List[Dict[str, Any]]:
    selected = _select_provider(provider, gemini_api_key, openai_api_key)
    prompt = _compose_roadmap_prompt(role, max_milestones)

    if selected == "gemini":
        try:
            import google.generativeai as genai
            genai.configure(api_key=gemini_api_key)
            model = genai.GenerativeModel(gemini_model)
            resp = model.generate_content(prompt)
            text = (getattr(resp, "text", None) or "").strip()
            return _safe_parse_roadmap_json(text)[:max_milestones]
        except Exception as e:
            print(f"Gemini API Error: {e}")
            return []
    elif selected == "openai":
        try:
            from openai import OpenAI
            client = OpenAI(api_key=openai_api_key)
            resp = client.chat.completions.create(
                model=openai_model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
            )
            text = (resp.choices[0].message.content or "").strip()
            return _safe_parse_roadmap_json(text)[:max_milestones]
        except Exception as e:
            print(f"OpenAI API Error: {e}")
            return []
    else:
        return []

# -------- Page verification (best-effort; never hard-fails) --------
_VERIFICATION_KEYWORDS = (
    "enroll", "register", "start course", "get started", "take exam",
    "start learning", "begin", "apply now", "earn certificate", "get certified",
)

def _scrape_and_verify_page(url: str) -> bool:
    """Best-effort verification; never raises. Returns True on weak positive too."""
    try:
        r = requests.get(url, timeout=8)
        if r.status_code != 200:
            return False
        soup = _best_soup(r.text)
        text = r.text.lower()
        if any(k in text for k in _VERIFICATION_KEYWORDS):
            return True
        if soup:
            for a in soup.find_all(["a", "button"]):
                t = (a.get_text() or "").strip().lower()
                if t in _VERIFICATION_KEYWORDS or any(k in t for k in _VERIFICATION_KEYWORDS):
                    return True
        # If we've already passed issuer + token checks, allow
        return True
    except Exception:
        return True

# -------- IMPROVED Cert name → URL resolution --------
def _build_cert_query_flexible(name: str) -> Tuple[str, str]:
    """Create both restricted and flexible queries."""
    top_domains = CERT_ALLOWED_DOMAINS[:15]  # avoid overlong queries
    sites = " OR ".join([f"site:{d}" for d in top_domains])
    restricted = f'"{name}" ({sites})'
    flexible = f'"{name}" (certification OR certificate OR exam OR credential OR training)'
    return restricted, flexible

def _search_cert_name_flexible(name: str, serpapi_key: str, num: int = 20) -> List[Dict[str, Any]]:
    """Search with restricted first, then flexible fallback."""
    restricted_query, flexible_query = _build_cert_query_flexible(name)
    results: List[Dict[str, Any]] = []

    try:
        print(f"[cert-search] Restricted query: {restricted_query[:100]}...")
        data = serpapi_search(restricted_query, serpapi_key=serpapi_key, num=max(10, num // 2))
        results = data.get("organic_results", []) or []
        print(f"[cert-search] Restricted results: {len(results)}")
        if len(results) >= 3:
            return results
    except Exception as e:
        print(f"[cert-search] Restricted search failed: {e}")
        results = []

    try:
        print(f"[cert-search] Flexible query: {flexible_query[:100]}...")
        data_flex = serpapi_search(flexible_query, serpapi_key=serpapi_key, num=num)
        flex_results = data_flex.get("organic_results", []) or []
        results.extend(flex_results)
        print(f"[cert-search] Flexible results: {len(flex_results)}")
    except Exception as e:
        print(f"[cert-search] Flexible search failed: {e}")

    return results

def _create_manual_cert_entry(name: str) -> Dict[str, Optional[str]]:
    """Create manual entry when auto-resolution fails (non-blocking)."""
    manual_mappings = {
        "microsoft ": ("learn.microsoft.com", "/en-us/certifications/"),
        "google ads": ("ads.google.com", "/certifications/"),
        "meta ": ("business.facebook.com", "/learn/certification/"),
        "hubspot": ("academy.hubspot.com", "/"),
        "google ": ("grow.google", "/certificates/"),
        "aws ": ("aws.amazon.com", "/certification/"),
        "tableau": ("tableau.com", "/learn/certification"),
    }
    n = (name or "").lower()
    for key, (domain, path) in manual_mappings.items():
        if key in n:
            search_url = f"https://{domain}{path}?search={urllib.parse.quote(name)}"
            return {"title": name, "url": search_url, "source": f"manual-{domain}"}
    return {"title": name, "url": None, "source": "manual-fallback"}

def _resolve_one_cert_improved(
    name: str,
    used_urls: Set[str],
    used_cert_names: Set[str],
    serpapi_key: str,
) -> Dict[str, Optional[str]]:
    """Improved certificate resolution with relaxed filtering + issuer hints."""
    name_key = " ".join(_tokens(name))
    if name_key in used_cert_names:
        print(f'[cert-resolve] SKIP duplicate cert name: "{name}"')
        return {"title": name, "url": None, "source": "duplicate-cert-name"}

    candidates = _search_cert_name_flexible(name, serpapi_key=serpapi_key, num=30)
    print(f'[cert-resolve] Found {len(candidates)} candidates for "{name}"')

    chosen: Optional[Tuple[float, Dict[str, Optional[str]], str]] = None
    debug_filters = {
        "no_link_title": 0,
        "domain_filtered": 0,
        "deny_domain": 0,
        "path_filtered": 0,
        "title_filtered": 0,
        "url_used": 0,
        "token_filtered": 0,
        "issuer_mismatch": 0,
        "considered": 0,
    }

    issuer_pref = _preferred_domain_for_name(name)

    for it in candidates:
        link = it.get("link") or it.get("url")
        title = (it.get("title") or it.get("name") or "").strip()
        if not link or not title:
            debug_filters["no_link_title"] += 1
            continue

        dom = _domain(link)

        # Skip explicit deny domains (aggregators, articles, non-official courses)
        if dom in CERT_DENY_DOMAINS:
            debug_filters["deny_domain"] += 1
            continue

        # If issuer is strongly implied by name, enforce that domain
        if issuer_pref and (dom != issuer_pref and not dom.endswith("." + issuer_pref)):
            debug_filters["issuer_mismatch"] += 1
            continue

        # General domain sanity
        if not _is_likely_cert_domain(dom, title):
            debug_filters["domain_filtered"] += 1
            continue

        # Path and title sanity
        if not _path_validation_relaxed(link):
            debug_filters["path_filtered"] += 1
            continue
        if not _title_looks_like_cert(title):
            debug_filters["title_filtered"] += 1
            continue

        # Token coverage (host+path, ~60%)
        if not _url_covers_name_tokens(link, name, min_frac=0.6):
            debug_filters["token_filtered"] += 1
            continue

        norm = _normalize_url(link)
        if not _not_used(norm, used_urls):
            debug_filters["url_used"] += 1
            continue

        debug_filters["considered"] += 1

        # Optional: soft verification for enroll/exam cues (non-blocking)
        _ = _scrape_and_verify_page(link)

        sim = _title_similarity(name, title)
        item = {"title": title, "url": link, "source": dom}
        if (chosen is None) or (sim > chosen[0]):
            chosen = (sim, item, norm)

        # Early accept if the title is a very close match
        if sim >= 0.80:
            break

    print(f'[cert-resolve-debug] "{name}" filters: {debug_filters}')

    if chosen:
        sim, item, norm = chosen
        used_urls.add(norm)
        used_cert_names.add(name_key)
        print(f'[cert-resolve] "{name}" → {item["url"]}  (sim={sim:.2f})')
        return item

    # Manual fallback (non-blocking, returns a search page)
    manual_entry = _create_manual_cert_entry(name)
    if manual_entry.get("url"):
        used_cert_names.add(name_key)
        print(f'[cert-resolve] "{name}" → {manual_entry["url"]} (manual)')
        return manual_entry

    print(f'[cert-resolve] "{name}" → NO URL FOUND')
    used_cert_names.add(name_key)
    return None  # Return None instead of a dict with null URL

def resolve_cert_names_to_urls(
    names: List[str],
    used_urls: Set[str],
    used_cert_names: Set[str],
    serpapi_key: str,
    k: int = 3,
) -> List[Dict[str, Optional[str]]]:
    """Resolve up to k cert names into official URLs (dicts for Pydantic/FastAPI)."""
    out: List[Dict[str, Optional[str]]] = []
    for name in names:
        if len(out) >= k:
            break
        cert = _resolve_one_cert_improved(name, used_urls, used_cert_names, serpapi_key=serpapi_key)
        if cert is not None and cert.get("url"):  # Only add certificates that have a URL
            out.append(cert)
    return out

# -------- Section search using milestone title + provided cert names --------
def search_sections_for_milestone(
    milestone_title: str,
    cert_names: List[str],
    used_urls: Set[str],
    used_cert_names: Set[str],
    serpapi_key: str,
) -> Tuple[List[Dict[str, Optional[str]]], List[Dict[str, Optional[str]]], List[Dict[str, Optional[str]]]]:
    # Resources (exclude issuer domains so we don't "steal" cert pages)
    q_resources = (
        f'{milestone_title} learning resources (articles OR "youtube" OR video OR tutorial OR course) '
        f'("free" OR open) (Philippines OR site:.ph)'
    )
    res_data = serpapi_search(q_resources, serpapi_key=serpapi_key, num=12)
    resources = _pick_top_scored(
        res_data.get("organic_results", []),
        used_urls=used_urls,
        k=3,
        exclude_domains=set(CERT_ALLOWED_DOMAINS),
    )

    # Certifications (using improved resolution)
    certs = resolve_cert_names_to_urls(
        cert_names or [],
        used_urls=used_urls,
        used_cert_names=used_cert_names,
        serpapi_key=serpapi_key,
        k=3,
    )

    # Network groups (PH-first)
    q_group = (
        f'{milestone_title} network groups ("Facebook group" OR "FB group" OR "LinkedIn group" OR reddit OR forum OR community OR meetup) '
        f'(Philippines OR site:.ph)'
    )
    grp_data = serpapi_search(q_group, serpapi_key=serpapi_key, num=12)

    prioritized: List[Tuple[float, Dict[str, Optional[str]], str]] = []
    for item in grp_data.get("organic_results", []) or []:
        link = item.get("link") or item.get("url")
        title = (item.get("title") or "").strip()
        if not link or not title:
            continue
        norm = _normalize_url(link)
        if not _not_used(norm, used_urls):
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
        prioritized.append((base, {"title": title, "url": link, "source": domain}, norm))
    prioritized.sort(key=lambda x: x[0], reverse=True)

    network_groups: List[Dict[str, Optional[str]]] = []
    for _, ri, norm in prioritized:
        if len(network_groups) >= 3:
            break
        network_groups.append(ri)
        used_urls.add(norm)

    return resources, certs, network_groups

def generate_and_store_roadmap(
    job_seeker_id: str,
    role: str,
    max_milestones: int = 10,
    provider: str = "auto",
    gemini_api_key: Optional[str] = os.getenv("GEMINI_API_KEY"),
    openai_api_key: Optional[str] = os.getenv("OPENAI_API_KEY"),
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
    serpapi_key: Optional[str] = os.getenv("SERPAPI_API_KEY"),
) -> str:
    """
    High-level orchestration for roadmap creation:
      1) Generate milestones + cert names (LLM).
      2) Resolve resources, certifications, and network groups.
      3) Persist roadmap + resources into Supabase, linked to job_seeker_id.
    Returns roadmap_id.
    """
    # 1) Generate roadmap
    milestones = _llm_generate_roadmap(
        role, max_milestones, provider, gemini_api_key, openai_api_key, openai_model, gemini_model
    )
    if not milestones:
        return ""

    # Ensure every milestone has a non-null 'title' (fallback to 'milestone')
    for ms in milestones:
        if not ms.get("title"):
            ms["title"] = ms.get("milestone", "")

    # 2) Collect resources per milestone
    used_urls: Set[str] = set()
    used_cert_names: Set[str] = set()
    milestone_resources = []
    for ms in milestones:
        res, certs, groups = search_sections_for_milestone(
            ms.get("milestone", ""), ms.get("cert_names", []), used_urls, used_cert_names, serpapi_key
        )
        milestone_resources.append((res, certs, groups))

    # 3) Persist to Supabase (now linked to job_seeker_id)
    roadmap_id = persist_scraper_roadmap_with_resources(
        job_seeker_id=job_seeker_id,
        role=role,
        provider=provider,
        model=(gemini_model if provider == "gemini" else openai_model),
        milestones=milestones,
        prompt_template_or_hashable="default-roadmap-prompt",
        cert_allowlist_or_hashable=CERT_ALLOWED_DOMAINS,
        milestone_resources=milestone_resources,
    )

    return roadmap_id
# -------- Re-export for endpoints --------
__all__ = [
    "_llm_generate_roadmap",
    "search_sections_for_milestone",
    "generate_and_store_roadmap",
]

