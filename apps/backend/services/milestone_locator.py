# apps/backend/services/milestone_locator_vector.py
from __future__ import annotations

import os
import time
from typing import Any, Dict, List, Optional, Tuple, Iterable

from supabase import create_client, Client
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
import numpy as np

from apps.backend.services.data_storer import (
    _now_iso,
    _json_stable,  # optional; helpful for deterministic ids
    store_seeker_milestone_status,
)

# ---------------------- Config ----------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

_sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
PINECONE_INDEX  = os.getenv("PINECONE_INDEX", "hiway-milestones")  # dedicated index for milestones
PINECONE_REGION = os.getenv("PINECONE_REGION")  # optional; depends on your Pinecone setup

EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "sentence-transformers/all-MiniLM-L6-v2")
MODEL = SentenceTransformer(EMBED_MODEL_NAME)

# weights / gates (align to your previous logic; tweak via env if needed)
PASS_GATE = float(os.getenv("MILESTONE_PASS_GATE", 0.60))          # 0..1
SKILL_WEIGHT = float(os.getenv("MILESTONE_SKILL_WEIGHT", 0.70))    # part of overall score
OUTCOME_WEIGHT = float(os.getenv("MILESTONE_OUTCOME_WEIGHT", 0.30))
GAP_THRESHOLD = float(os.getenv("MILESTONE_GAP_THRESHOLD", 0.50))  # 0..1
TOPK = int(os.getenv("MILESTONE_TOPK", "5"))                       # neighbors to consider per item

# level bands
LEVEL_BANDS = [
    ("Beginner", 0.0, 0.40),
    ("Intermediate", 0.40, 0.70),
    ("Advanced", 0.70, 1.01),
]

# ---------------------- Pinecone helpers ----------------------
def _pc_client() -> Pinecone:
    if not PINECONE_API_KEY:
        raise RuntimeError("PINECONE_API_KEY must be set")
    return Pinecone(api_key=PINECONE_API_KEY)

def _pc_index(pc: Pinecone):
    # assumes index already exists with correct dimension
    return pc.Index(PINECONE_INDEX)

def _namespace_for_roadmap(roadmap_id: str) -> str:
    # isolate vectors per roadmap
    return f"roadmap:{roadmap_id}"

def _ensure_index_ready(expected_dim: int):
    """
    You should create the Pinecone index out-of-band once:
    dimension must match the embedding model (e.g., 384 for MiniLM-L6-v2).
    Example CLI/SDK creation:
      pc.create_index(name=PINECONE_INDEX, dimension=384, metric="cosine")
    """
    pc = _pc_client()
    desc = pc.describe_index(PINECONE_INDEX)
    if int(desc.dimension) != expected_dim:
        raise RuntimeError(
            f"Pinecone index dim={desc.dimension} != expected model dim={expected_dim}"
        )

# ---------------------- Embeddings ----------------------
def _embed(texts: List[str]) -> np.ndarray:
    if not texts:
        return np.zeros((0, MODEL.get_sentence_embedding_dimension()), dtype=np.float32)
    vecs = MODEL.encode(texts, normalize_embeddings=True)
    return np.asarray(vecs, dtype=np.float32)

def _cos(a: np.ndarray, b: np.ndarray) -> float:
    # both are L2-normalized → dot == cosine
    return float(np.dot(a, b))

def _band_for(score01: float) -> str:
    for name, lo, hi in LEVEL_BANDS:
        if lo <= score01 < hi:
            return name
    return "Beginner"

# ---------------------- Data I/O ----------------------
def _fetch_roadmap(roadmap_id: Optional[str], job_seeker_id: str, role: str) -> Dict[str, Any]:
    if roadmap_id:
        r = (
            _sb.table("role_roadmaps")
            .select("roadmap_id, milestones")
            .eq("roadmap_id", roadmap_id)
            .limit(1)
            .execute()
        )
    else:
        r = (
            _sb.table("role_roadmaps")
            .select("roadmap_id, milestones")
            .eq("job_seeker_id", job_seeker_id)
            .eq("role", role)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
    road = (r.data or [None])[0]
    if not road:
        raise RuntimeError("No roadmap found for seeker+role")
    return road

def _fetch_seeker_profile(job_seeker_id: str) -> Tuple[Dict[str, Any], Optional[str]]:
    sres = (
        _sb.table("job_seeker")
        .select("skills, experience, education, licenses_certifications, updated_at")
        .eq("job_seeker_id", job_seeker_id)
        .limit(1)
        .execute()
    )
    seeker = (sres.data or [{}])[0]
    updated_at = seeker.get("updated_at")
    return seeker, updated_at

def _fetch_latest_snapshot_time(job_seeker_id: str, role: str, roadmap_id: str) -> Optional[str]:
    res = (
        _sb.table("seeker_milestone_status")
        .select("calculated_at")
        .eq("job_seeker_id", job_seeker_id)
        .eq("role", role)
        .eq("roadmap_id", roadmap_id)
        .order("calculated_at", desc=True)
        .limit(1)
        .execute()
    )
    row = (res.data or [None])[0]
    return row["calculated_at"] if row else None

# ---------------------- Indexing milestones ----------------------
def _milestone_items(m: Dict[str, Any]) -> Tuple[List[str], List[str]]:
    # normalize skills/outcomes to strings
    req_skills = [str(x) for x in (m.get("skills") or []) if str(x).strip()]
    outcomes   = [str(x) for x in (m.get("outcomes") or []) if str(x).strip()]
    return req_skills, outcomes

def _ensure_milestones_indexed(roadmap_id: str, milestones: List[Dict[str, Any]]):
    """
    Upserts milestone requirement vectors into Pinecone (namespace per roadmap).
    Vector schema:
      id: f"{milestone_index}:{kind}:{i}"  (kind in {"skill","outcome"})
      metadata: { "milestone_index": int, "kind": "skill|outcome", "text": str }
    """
    _ensure_index_ready(MODEL.get_sentence_embedding_dimension())
    pc = _pc_client()
    index = _pc_index(pc)
    namespace = _namespace_for_roadmap(roadmap_id)

    # Build payloads
    vecs: List[Tuple[str, List[float], Dict[str, Any]]] = []
    for mi, m in enumerate(milestones):
        s, o = _milestone_items(m)
        if s:
            s_emb = _embed(s)
            for i in range(len(s)):
                vecs.append((
                    f"{mi}:skill:{i}",
                    s_emb[i].tolist(),
                    {"milestone_index": mi, "kind": "skill", "text": s[i]},
                ))
        if o:
            o_emb = _embed(o)
            for i in range(len(o)):
                vecs.append((
                    f"{mi}:outcome:{i}",
                    o_emb[i].tolist(),
                    {"milestone_index": mi, "kind": "outcome", "text": o[i]},
                ))

    # Upsert in chunks
    BATCH = 200
    for k in range(0, len(vecs), BATCH):
        batch = vecs[k:k+BATCH]
        index.upsert(vectors=[{"id": vid, "values": vals, "metadata": meta} for vid, vals, meta in batch],
                     namespace=namespace)

# ---------------------- Scoring with Pinecone ----------------------
def _score_milestones_with_pinecone(
    roadmap_id: str,
    milestones: List[Dict[str, Any]],
    seeker_strings: List[str],
) -> Tuple[List[Dict[str, Any]], int]:
    """
    For each required item per milestone, we query nearest neighbors from Pinecone
    and compute similarity coverage based on matches mapped back to the same milestone.
    Returns (milestones_scored, current_idx).
    """
    if not milestones:
        return [], 0

    # Embed seeker profile items
    seeker_items = [s for s in seeker_strings if s.strip()]
    if not seeker_items:
        # no data; everything scores zero
        scored = []
        for i, m in enumerate(milestones):
            scored.append({
                "index": i,
                "title": m.get("title"),
                "target_level": m.get("target_level"),
                "score_pct": 0.0,
                "skills_scored": [],
                "outcomes_scored": [],
                "gaps": (m.get("skills") or []) + (m.get("outcomes") or []),
            })
        return scored, 0

    seeker_emb = _embed(seeker_items)

    # Query Pinecone for each seeker item, accumulate best matches by milestone
    pc = _pc_client()
    index = _pc_index(pc)
    namespace = _namespace_for_roadmap(roadmap_id)

    # Keep best similarity per (milestone, required_text)
    # We will invert: for each required item, find best similarity among seeker items using topK of seeker->index.
    # Build a map: required_text -> (milestone_index, kind)
    required_map: Dict[str, Tuple[int, str]] = {}
    for mi, m in enumerate(milestones):
        skills, outcomes = _milestone_items(m)
        for t in skills:
            required_map[t] = (mi, "skill")
        for t in outcomes:
            required_map[t] = (mi, "outcome")

    # Accumulator for per-required item best sim
    best_sim: Dict[Tuple[int, str, str], float] = {}  # key=(mi, kind, text)

    for vec in seeker_emb:
        q = index.query(
            vector=vec.tolist(),
            top_k=TOPK,
            include_metadata=True,
            namespace=namespace
        )
        for match in (q.matches or []):
            meta = match.metadata or {}
            mi = int(meta.get("milestone_index", 0))
            kind = meta.get("kind", "skill")
            text = str(meta.get("text", ""))
            sim = float(match.score)  # cosine since normalized

            key = (mi, kind, text)
            if key not in best_sim or sim > best_sim[key]:
                best_sim[key] = sim

    # Aggregate per milestone
    milestones_scored: List[Dict[str, Any]] = []
    best_gate_idx: Optional[int] = None

    for mi, m in enumerate(milestones):
        skills, outcomes = _milestone_items(m)

        skills_pairs = [(t, round(best_sim.get((mi, "skill", t), 0.0), 4)) for t in skills]
        outs_pairs   = [(t, round(best_sim.get((mi, "outcome", t), 0.0), 4)) for t in outcomes]

        skills_avg = sum(s for _, s in skills_pairs) / max(1, len(skills_pairs))
        outs_avg   = sum(s for _, s in outs_pairs) / max(1, len(outs_pairs))
        score01    = (SKILL_WEIGHT * skills_avg) + (OUTCOME_WEIGHT * outs_avg)
        score_pct  = round(score01 * 100.0, 2)

        gaps = [t for t, s in (skills_pairs + outs_pairs) if s < GAP_THRESHOLD]

        milestones_scored.append({
            "index": mi,
            "title": m.get("title"),
            "target_level": m.get("target_level"),
            "score_pct": score_pct,
            "skills_scored": [{"item": t, "sim": round(s, 2)} for t, s in skills_pairs],
            "outcomes_scored": [{"item": t, "sim": round(s, 2)} for t, s in outs_pairs],
            "gaps": gaps,
        })

        if score01 >= PASS_GATE:
            best_gate_idx = mi

    current_idx = best_gate_idx if best_gate_idx is not None else 0
    return milestones_scored, current_idx

# ---------------------- Public entrypoint ----------------------
def locate_milestone_with_vectors(
    *,
    job_seeker_id: str,
    role: str,
    roadmap_id: Optional[str] = None,
    force: bool = False,
    model_version: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Determines current/next milestone for a seeker using Pinecone+SBERT.
    Writes a snapshot to seeker_milestone_status, but only if:
      - force=True, or
      - no existing snapshot, or
      - seeker.updated_at > last_snapshot.calculated_at
    Returns the snapshot row that was written (or the latest existing snapshot if no changes).
    """
    road = _fetch_roadmap(roadmap_id, job_seeker_id, role)
    roadmap_id = road["roadmap_id"]
    milestones: List[Dict[str, Any]] = road.get("milestones") or []

    seeker, seeker_updated_at = _fetch_seeker_profile(job_seeker_id)
    latest_calc = _fetch_latest_snapshot_time(job_seeker_id, role, roadmap_id)

    # decide if we should recompute
    should_compute = force or (latest_calc is None) or (
        seeker_updated_at and latest_calc and str(seeker_updated_at) > str(latest_calc)
    )

    if not should_compute:
        # return the latest existing snapshot
        res = (
            _sb.table("seeker_milestone_status")
            .select("*")
            .eq("job_seeker_id", job_seeker_id)
            .eq("role", role)
            .eq("roadmap_id", roadmap_id)
            .order("calculated_at", desc=True)
            .limit(1)
            .execute()
        )
        return (res.data or [None])[0]

    # ensure milestone vectors are in Pinecone
    _ensure_milestones_indexed(roadmap_id, milestones)

    # flatten seeker strings (skills + experience + education + certs)
    seeker_items: List[str] = []
    for key in ("skills", "experience", "education", "licenses_certifications"):
        arr = seeker.get(key) or []
        seeker_items.extend([str(x).strip() for x in arr if str(x).strip()])

    milestones_scored, current_idx = _score_milestones_with_pinecone(
        roadmap_id=roadmap_id,
        milestones=milestones,
        seeker_strings=seeker_items,
    )

    current = milestones_scored[current_idx] if milestones_scored else None
    next_idx = min(current_idx + 1, max(0, len(milestones_scored) - 1))
    next_m  = milestones_scored[next_idx] if milestones_scored else None

    current_score01 = (current["score_pct"] / 100.0) if current else 0.0
    current_level = _band_for(current_score01)
    next_level = _band_for((next_m["score_pct"] / 100.0) if next_m else 0.0)

    snapshot = store_seeker_milestone_status(
        job_seeker_id=job_seeker_id,
        role=role,
        roadmap_id=roadmap_id,
        auth_user_id=None,
        current_milestone=current.get("title") if current else None,
        current_level=current_level,
        current_score_pct=current.get("score_pct") if current else None,
        next_milestone=next_m.get("title") if next_m else None,
        next_level=next_level,
        gaps=current.get("gaps") if current else [],
        milestones_scored=milestones_scored,
        weights={
            "skills": SKILL_WEIGHT,
            "outcomes": OUTCOME_WEIGHT,
            "pass_gate": PASS_GATE,
            "gap_threshold": GAP_THRESHOLD,
            "topk": TOPK,
            "engine": "sbert+pcone",
            "embed_model": EMBED_MODEL_NAME,
        },
        model_version=model_version,
        low_confidence=(current_score01 < PASS_GATE),
        calculated_at_iso=_now_iso(),
    )
    return snapshot
