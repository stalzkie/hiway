# apps/backend/services/embed_worker.py
from __future__ import annotations

import os
import time
import hashlib
import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from importlib import import_module
from pathlib import Path

import numpy as np
from supabase import create_client, Client
from sentence_transformers import SentenceTransformer

# ---------------------- .env loading (robust) ----------------------
def _load_env() -> None:
    """
    Load .env from common locations. Prints which file was used.
    Works whether you run as a module (-m) or a script from any CWD.
    """
    try:
        from dotenv import load_dotenv, find_dotenv
    except Exception:
        print("[DIAG] python-dotenv not installed; relying on OS env only.")
        return

    # User override: ENV_FILE=/absolute/path/to/.env
    env_file = os.getenv("ENV_FILE")
    tried: List[str] = []

    def _try(path: Path) -> bool:
        try:
            if path.exists():
                load_dotenv(path.as_posix(), override=False)
                print(f"[DIAG] loaded .env: {path.as_posix()}")
                return True
        except Exception as e:
            print(f"[DIAG] failed to load {path}: {e}")
        tried.append(path.as_posix())
        return False

    if env_file:
        if _try(Path(env_file).expanduser().resolve()):
            return

    # Search typical places relative to this file and the repo
    here = Path(__file__).resolve()
    candidates = [
        here.parent.parent.parent / ".env",  # project root: <repo>/.env
        here.parent.parent / ".env",         # apps/.env  (you have this)
        here.parent / ".env",                # services/.env
        Path.cwd() / ".env",                 # CWD
    ]

    for p in candidates:
        if _try(p):
            return

    # Last resort: python-dotenv discovery
    found = find_dotenv(filename=".env", usecwd=True)
    if found:
        load_dotenv(found, override=False)
        print(f"[DIAG] loaded .env via find_dotenv: {found}")
    else:
        print(f"[DIAG] no .env found (tried={tried})")

_load_env()

# ---------------------- Config ----------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")

# One index for both; override as needed
PINECONE_INDEX = os.getenv("PINECONE_INDEX", "hiway-jobseekers")
EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "intfloat/e5-base-v2")

# Namespaces (keep in sync with matcher.py)
JOB_SEEKERS_NAMESPACE = os.getenv("PINECONE_NS_JOB_SEEKERS", "job_seekers")
JOB_POSTS_NAMESPACE   = os.getenv("PINECONE_NS_JOB_POSTS", "job_posts")

# Queue table names & reason
EMBED_QUEUE_TABLE_SEEKER = os.getenv("EMBED_QUEUE_TABLE_SEEKER", "embedding_queue")
EMBED_QUEUE_TABLE_POST   = os.getenv("EMBED_QUEUE_TABLE_POST", "embedding_queue_post")
EMBED_QUEUE_REASON_DEFAULT = os.getenv("EMBED_QUEUE_REASON_DEFAULT", "insert")

# Worker loop tuning
BATCH = int(os.getenv("EMBED_BATCH", "10"))
SLEEP = int(os.getenv("EMBED_SLEEP", "5"))  # seconds between polls

# e5 models expect "query: ..." vs "passage: ...".
E5_USE_PREFIX = os.getenv("E5_USE_PREFIX", "1") == "1"
E5_PASSAGE_PREFIX = os.getenv("E5_PASSAGE_PREFIX", "passage: ")

# Optional: toggle attaching sparse vectors (defaults to on)
ENABLE_SPARSE = os.getenv("ENABLE_SPARSE", "1") == "1"

# ---------------------- Env validation (nice errors) ----------------------
def _require_env() -> None:
    missing = [k for k in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "PINECONE_API_KEY") if not os.getenv(k)]
    if missing:
        print("[FATAL] Missing required environment variables:")
        for k in missing:
            print(f"  - {k}=<not set>")
        print("Hint: ensure your .env contains them and that it was loaded (see [DIAG] logs above).")
        raise SystemExit(1)

_require_env()

# ---------------------- Clients ----------------------
sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# Pinecone: support new 3.x and legacy client, with diagnostics
def _init_pinecone():
    try:
        _pcm = import_module("pinecone")
        _pcm_file = getattr(_pcm, "__file__", None)
        _pcm_ver = getattr(_pcm, "__version__", None)
        print(f"[DIAG] imported pinecone module file={_pcm_file} version={_pcm_ver}")

        if hasattr(_pcm, "Pinecone"):  # New SDK (3.x+)
            from pinecone import Pinecone  # type: ignore
            pc = Pinecone(api_key=PINECONE_API_KEY)
            index = pc.Index(PINECONE_INDEX)
            print("[DIAG] using Pinecone 3.x style client")
            return index
        else:
            # Legacy SDK fallback
            print("[DIAG] Pinecone.Pinecone not found; falling back to legacy init() flow")
            PINECONE_ENV = os.getenv("PINECONE_ENV") or "us-east-1"
            _pcm.init(api_key=PINECONE_API_KEY, environment=PINECONE_ENV)
            idx = _pcm.Index(PINECONE_INDEX)
            print(f"[DIAG] using legacy pinecone-client with environment={PINECONE_ENV}")
            return idx
    except Exception as e:
        print(f"[FATAL] Could not initialize Pinecone client: {e}")
        import traceback; traceback.print_exc()
        raise

index = _init_pinecone()
model = SentenceTransformer(EMBED_MODEL_NAME)

# ---------------------- Hybrid (BM25) encoder for sparse vectors ----------------------
try:
    from pinecone_text.sparse import BM25Encoder
except Exception:
    BM25Encoder = None  # type: ignore

_BM25: Optional["BM25Encoder"] = None

def _fit_bm25_from_db() -> None:
    """
    Fit a BM25 encoder on your current job_post corpus (search_document).
    Called at startup. If pinecone-text isn't installed or ENABLE_SPARSE=0,
    this is a no-op and the worker runs dense-only.
    """
    global _BM25
    if not ENABLE_SPARSE:
        print("[DIAG] ENABLE_SPARSE=0; skipping BM25 fit (dense-only upserts)")
        _BM25 = None
        return

    if BM25Encoder is None:
        print("[DIAG] pinecone-text not installed; skipping BM25 fit (dense-only upserts)")
        _BM25 = None
        return

    try:
        res = sb.table("job_post").select("search_document").limit(100000).execute()
        corpus = [(r.get("search_document") or "") for r in (res.data or [])]
        enc = BM25Encoder()
        enc.fit(corpus)
        _BM25 = enc
        print(f"[DIAG] BM25 fitted on {len(corpus)} job_post documents")
    except Exception as e:
        print(f"[WARN] BM25 fit failed: {e}")
        _BM25 = None

def _bm25_encode_doc(text: str):
    """Return Pinecone sparse values for a document text (BM25)."""
    if _BM25 is None:
        return None
    sv = _BM25.encode_documents([text or ""])[0]
    return {"indices": sv["indices"], "values": sv["values"]}

# ---------------------- Small utils ----------------------
def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def normalize(vec: List[float]) -> List[float]:
    v = np.array(vec, dtype=np.float32)
    n = np.linalg.norm(v)
    return (v / (n + 1e-12)).astype(np.float32).tolist()

def embed_passage(text: str) -> List[float]:
    text = (text or "").strip()
    if E5_USE_PREFIX:
        text = f"{E5_PASSAGE_PREFIX}{text}"
    emb = model.encode(text, convert_to_numpy=True)
    return normalize(emb.tolist())

def checksum(text: str) -> str:
    return hashlib.sha256((text or "").encode("utf-8")).hexdigest()

def j2s(j: Any) -> str:
    if isinstance(j, str):
        return j
    return json.dumps(j or [], ensure_ascii=False)

def _safe_update(table: str, row_id_col: str, row_id_val: Any, data: Dict[str, Any]) -> None:
    try:
        sb.table(table).update(data).eq(row_id_col, row_id_val).execute()
    except Exception as e:
        print(f"[WARN] update {table} id={row_id_val} failed: {e}")

def _mark_processed(table: str, row_id_val: Any) -> None:
    _safe_update(table, "id", row_id_val, {"processed_at": _now_iso()})

def _mark_started(table: str, row_id_val: Any) -> None:
    # if your table doesn't have started_at, remove this and its calls
    try:
        _safe_update(table, "id", row_id_val, {"enqueued_at": _now_iso()})
    except Exception:
        pass

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

    # Upsert to Pinecone (seekers are dense-only; sparse not needed for queries)
    try:
        index.upsert(vectors=vectors, namespace=JOB_SEEKERS_NAMESPACE)
    except Exception as e:
        print(f"[ERROR] pinecone upsert (seeker {jsid}) failed: {e}")
        raise

    # Persist marker back to Supabase
    _safe_update(
        table="job_seeker",
        row_id_col="job_seeker_id",
        row_id_val=jsid,
        data={
            "pinecone_id": str(jsid),
            "embedding_checksum": checksum(sections["full"]),
        },
    )

def process_job_seeker_batch() -> int:
    try:
        q = (
            sb.table(EMBED_QUEUE_TABLE_SEEKER)
            .select("*")
            .is_("processed_at", "null")
            .order("enqueued_at", desc=False)
            .limit(BATCH)
            .execute()
        )
    except Exception as e:
        print(f"[ERROR] selecting from {EMBED_QUEUE_TABLE_SEEKER}: {e}")
        return 0

    rows = q.data or []
    if not rows:
        return 0

    ids = [r["job_seeker_id"] for r in rows if r.get("job_seeker_id")]
    if not ids:
        for r in rows:
            _mark_processed(EMBED_QUEUE_TABLE_SEEKER, r.get("id"))
        return len(rows)

    for r in rows:
        _mark_started(EMBED_QUEUE_TABLE_SEEKER, r.get("id"))

    js_resp = sb.table("job_seeker").select("*").in_("job_seeker_id", ids).execute()
    by_id = {r["job_seeker_id"]: r for r in (js_resp.data or [])}

    processed = 0
    for r in rows:
        rid = r.get("id")
        jsid = r.get("job_seeker_id")
        js = by_id.get(jsid)

        if not js:
            _mark_processed(EMBED_QUEUE_TABLE_SEEKER, rid)
            continue

        full_text = js.get("search_document") or ""
        chksum = checksum(full_text)
        if chksum == (js.get("embedding_checksum") or ""):
            _mark_processed(EMBED_QUEUE_TABLE_SEEKER, rid)
            processed += 1
            continue

        try:
            upsert_job_seeker_vectors(js)
            _mark_processed(EMBED_QUEUE_TABLE_SEEKER, rid)
            processed += 1
        except Exception as e:
            print(f"[ERROR] seeker upsert failed for {jsid}: {e}")

    return processed

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
    """
    Upsert job post per-section vectors. Includes dense 'values' and, if available,
    BM25 'sparse_values' so Pinecone Hybrid queries can leverage lexical rarity.
    """
    pid = post["job_post_id"]
    sections = build_job_post_section_texts(post)

    vectors = []
    for scope, text in sections.items():
        vec = embed_passage(text)

        item: Dict[str, Any] = {
            "id": f"{pid}:{scope}",
            "values": vec,
            "metadata": {
                "job_post_id": str(pid),
                "scope": scope,
                "posted_by": (post.get("posted_by") or ""),
                "updated_at": post.get("updated_at"),
            }
        }

        # Attach sparse BM25 ONLY for job posts (targets)
        if ENABLE_SPARSE and _BM25 is not None:
            sparse = _bm25_encode_doc(text)
            if sparse and sparse.get("values"):
                item["sparse_values"] = sparse  # Pinecone 3.x snake_case

        vectors.append(item)

    try:
        index.upsert(vectors=vectors, namespace=JOB_POSTS_NAMESPACE)
    except Exception as e:
        print(f"[ERROR] pinecone upsert (post {pid}) failed: {e}")
        raise

    _safe_update(
        table="job_post",
        row_id_col="job_post_id",
        row_id_val=pid,
        data={
            "pinecone_id": str(pid),
            "embedding_checksum": checksum(sections["full"]),
        },
    )

def process_job_post_batch() -> int:
    try:
        q = (
            sb.table(EMBED_QUEUE_TABLE_POST)
            .select("*")
            .is_("processed_at", "null")
            .order("enqueued_at", desc=False)
            .limit(BATCH)
            .execute()
        )
    except Exception as e:
        print(f"[ERROR] selecting from {EMBED_QUEUE_TABLE_POST}: {e}")
        return 0

    rows = q.data or []
    if not rows:
        return 0

    ids = [r["job_post_id"] for r in rows if r.get("job_post_id")]
    if not ids:
        for r in rows:
            _mark_processed(EMBED_QUEUE_TABLE_POST, r.get("id"))
        return len(rows)

    for r in rows:
        _mark_started(EMBED_QUEUE_TABLE_POST, r.get("id"))

    resp = sb.table("job_post").select("*").in_("job_post_id", ids).execute()
    by_id = {r["job_post_id"]: r for r in (resp.data or [])}

    processed = 0
    for r in rows:
        rid = r.get("id")
        pid = r.get("job_post_id")
        post = by_id.get(pid)

        if not post:
            _mark_processed(EMBED_QUEUE_TABLE_POST, rid)
            continue

        full_text = post.get("search_document") or ""
        chksum = checksum(full_text)
        if chksum == (post.get("embedding_checksum") or ""):
            _mark_processed(EMBED_QUEUE_TABLE_POST, rid)
            processed += 1
            continue

        try:
            upsert_job_post_vectors(post)
            _mark_processed(EMBED_QUEUE_TABLE_POST, rid)
            processed += 1
        except Exception as e:
            print(f"[ERROR] post upsert failed for {pid}: {e}")

    return processed

# ---------------------- Main ----------------------
def main():
    print(
        f"Embed worker running… index={PINECONE_INDEX} "
        f"ns_seekers={JOB_SEEKERS_NAMESPACE} ns_posts={JOB_POSTS_NAMESPACE} "
        f"model={EMBED_MODEL_NAME}"
    )
    # Fit BM25 on job_post corpus once (no-op if disabled/missing)
    _fit_bm25_from_db()

    while True:
        c_seekers = process_job_seeker_batch()
        c_posts = process_job_post_batch()

        if c_seekers or c_posts:
            print(f"Processed: job_seekers={c_seekers}, job_posts={c_posts}")
        else:
            print("No pending rows. Sleeping...")
        time.sleep(SLEEP)

if __name__ == "__main__":
    main()
