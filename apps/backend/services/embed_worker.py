# apps/backend/workers/embed_worker.py
from __future__ import annotations

import os
import time
import hashlib
import json
from typing import List, Dict, Any

from supabase import create_client, Client
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
import numpy as np

# ---------------------- Config ----------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")

# One index for both; override as needed
PINECONE_INDEX = os.getenv("PINECONE_INDEX", "hiway-jobseekers")
EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "intfloat/e5-base-v2")

# Namespaces
JOB_SEEKERS_NAMESPACE = "job_seekers"
JOB_POSTS_NAMESPACE = "job_posts"

# Worker loop tuning
BATCH = int(os.getenv("EMBED_BATCH", "10"))
SLEEP = int(os.getenv("EMBED_SLEEP", "5"))  # seconds between polls

assert SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY and PINECONE_API_KEY, \
    "Missing required environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PINECONE_API_KEY"

# ---------------------- Clients ----------------------
sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(PINECONE_INDEX)
model = SentenceTransformer(EMBED_MODEL_NAME)

# ---------------------- Helpers ----------------------
def normalize(vec: List[float]) -> List[float]:
    v = np.array(vec, dtype=np.float32)
    n = np.linalg.norm(v)
    return (v / (n + 1e-12)).astype(np.float32).tolist()

def embed_passage(text: str) -> List[float]:
    if not text:
        text = ""
    emb = model.encode("passage: " + text, convert_to_numpy=True)
    return normalize(emb.tolist())

def checksum(text: str) -> str:
    return hashlib.sha256((text or "").encode("utf-8")).hexdigest()

def j2s(j: Any) -> str:
    return json.dumps(j or [], ensure_ascii=False)

# ---------------------- Job Seekers ----------------------
def build_job_seeker_section_texts(row: Dict[str, Any]) -> Dict[str, str]:
    return {
        "full": row.get("search_document") or "",
        "skills": j2s(row.get("skills")),
        "experience": j2s(row.get("experience")),
        "education": j2s(row.get("education")),
        "licenses": j2s(row.get("licenses_certifications")),
    }

def upsert_job_seeker_vectors(js: Dict[str, Any]) -> None:
    jsid = js["job_seeker_id"]
    sections = build_job_seeker_section_texts(js)

    vectors = []
    for scope, text in sections.items():
        vec = embed_passage(text)
        vectors.append({
            "id": f"{jsid}:{scope}",
            "values": vec,
            "metadata": {
                "job_seeker_id": str(jsid),
                "scope": scope,
                "full_name": js.get("full_name"),
                "email": js.get("email"),
                "updated_at": js.get("updated_at"),
            }
        })

    index.upsert(vectors=vectors, namespace=JOB_SEEKERS_NAMESPACE)

    sb.table("job_seeker").update({
        "pinecone_id": str(jsid),
        "embedding_checksum": checksum(sections["full"])
    }).eq("job_seeker_id", jsid).execute()

def process_job_seeker_batch() -> int:
    q = (sb.table("embedding_queue")
           .select("*")
           .is_("processed_at", "null")
           .order("enqueued_at", desc=False)
           .limit(BATCH)
           .execute())
    rows = q.data or []
    if not rows:
        return 0

    ids = [r["job_seeker_id"] for r in rows]
    js_resp = sb.table("job_seeker").select("*").in_("job_seeker_id", ids).execute()
    by_id = {r["job_seeker_id"]: r for r in (js_resp.data or [])}

    for r in rows:
        js = by_id.get(r["job_seeker_id"])
        if not js:
            sb.table("embedding_queue").update({"processed_at": "now()"}).eq("id", r["id"]).execute()
            continue

        full_text = js.get("search_document") or ""
        chksum = checksum(full_text)
        if chksum == (js.get("embedding_checksum") or ""):
            sb.table("embedding_queue").update({"processed_at": "now()"}).eq("id", r["id"]).execute()
            continue

        upsert_job_seeker_vectors(js)
        sb.table("embedding_queue").update({"processed_at": "now()"}).eq("id", r["id"]).execute()

    return len(rows)

# ---------------------- Job Posts ----------------------
def build_job_post_section_texts(row: Dict[str, Any]) -> Dict[str, str]:
    return {
        "full": row.get("search_document") or "",
        "skills": j2s(row.get("job_skills")),
        "experience": j2s(row.get("job_experience")),
        "education": j2s(row.get("job_education")),
        "licenses": j2s(row.get("job_licenses_certifications")),
    }

def upsert_job_post_vectors(post: Dict[str, Any]) -> None:
    pid = post["job_post_id"]
    sections = build_job_post_section_texts(post)

    vectors = []
    for scope, text in sections.items():
        vec = embed_passage(text)
        vectors.append({
            "id": f"{pid}:{scope}",
            "values": vec,
            "metadata": {
                "job_post_id": str(pid),
                "scope": scope,
                "posted_by": str(post.get("posted_by")),
                "updated_at": post.get("updated_at"),
            }
        })

    index.upsert(vectors=vectors, namespace=JOB_POSTS_NAMESPACE)

    sb.table("job_post").update({
        "pinecone_id": str(pid),
        "embedding_checksum": checksum(sections["full"])
    }).eq("job_post_id", pid).execute()

def process_job_post_batch() -> int:
    q = (sb.table("embedding_queue_post")
           .select("*")
           .is_("processed_at", "null")
           .order("enqueued_at", desc=False)
           .limit(BATCH)
           .execute())
    rows = q.data or []
    if not rows:
        return 0

    ids = [r["job_post_id"] for r in rows]
    resp = sb.table("job_post").select("*").in_("job_post_id", ids).execute()
    by_id = {r["job_post_id"]: r for r in (resp.data or [])}

    for r in rows:
        post = by_id.get(r["job_post_id"])
        if not post:
            sb.table("embedding_queue_post").update({"processed_at": "now()"}).eq("id", r["id"]).execute()
            continue

        full_text = post.get("search_document") or ""
        chksum = checksum(full_text)
        if chksum == (post.get("embedding_checksum") or ""):
            sb.table("embedding_queue_post").update({"processed_at": "now()"}).eq("id", r["id"]).execute()
            continue

        upsert_job_post_vectors(post)
        sb.table("embedding_queue_post").update({"processed_at": "now()"}).eq("id", r["id"]).execute()

    return len(rows)

# ---------------------- Main ----------------------
def main():
    print("🔄 Embed worker running…")
    while True:
        c_seekers = process_job_seeker_batch()
        c_posts = process_job_post_batch()

        if c_seekers or c_posts:
            print(f"✅ Processed: job_seekers={c_seekers}, job_posts={c_posts}")
        else:
            print("⏳ No pending rows. Sleeping...")
            time.sleep(SLEEP)

if __name__ == "__main__":
    main()
