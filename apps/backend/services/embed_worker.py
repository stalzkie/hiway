# apps/backend/workers/embed_worker.py
from __future__ import annotations
import os, time, hashlib, json
from typing import List, Dict, Any

from supabase import create_client, Client
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
import numpy as np

# ---------------------- Config ----------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
PINECONE_INDEX = os.getenv("PINECONE_INDEX", "hiway-jobseekers")
EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "intfloat/e5-base-v2")

NAMESPACE = "job_seekers"
BATCH = 10
SLEEP = 5  # seconds between polls

assert SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY and PINECONE_API_KEY, \
    "Missing required environment variables"

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


def build_section_texts(row: Dict[str, Any]) -> Dict[str, str]:
    def j2s(j): return json.dumps(j, ensure_ascii=False)
    return {
        "full": row.get("search_document") or "",
        "skills": j2s(row.get("skills") or []),
        "experience": j2s(row.get("experience") or []),
        "education": j2s(row.get("education") or []),
        "licenses": j2s(row.get("licenses_certifications") or []),
    }


def upsert_job_seeker_vectors(js: Dict[str, Any]):
    jsid = js["job_seeker_id"]
    sections = build_section_texts(js)

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

    index.upsert(vectors=vectors, namespace=NAMESPACE)

    sb.table("job_seeker").update({
        "pinecone_id": str(jsid),
        "embedding_checksum": checksum(sections["full"])
    }).eq("job_seeker_id", jsid).execute()


def process_batch() -> int:
    q = sb.table("embedding_queue") \
        .select("*") \
        .is_("processed_at", "null") \
        .order("enqueued_at", desc=False) \
        .limit(BATCH) \
        .execute()

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


def main():
    print("🔄 Embed worker running…")
    while True:
        count = process_batch()
        if count == 0:
            print("⏳ No pending rows. Sleeping...")
            time.sleep(SLEEP)


if __name__ == "__main__":
    main()
