# backend/test/test_pinecone.py
"""
Quick Pinecone sanity check + query script.

Usage (from apps/backend/):
  python test/test_pinecone.py
  python test/test_pinecone.py --q "Python developer with BI experience"
  python test/test_pinecone.py --q "data analytics and dashboards" --ns job_seekers --topk 5

Env vars required:
  PINECONE_API_KEY   (your Pinecone API key)
  PINECONE_INDEX     (e.g., hiway-jobseekers)
Optional:
  EMBED_MODEL_NAME   (default: intfloat/e5-base-v2)
"""

import os
import sys
import json
import argparse
import numpy as np

try:
    from pinecone import Pinecone
except Exception as e:
    print("❌ pinecone-client not installed. Run: pip install pinecone-client")
    raise

try:
    from sentence_transformers import SentenceTransformer
except Exception as e:
    print("❌ sentence-transformers not installed. Run: pip install sentence-transformers")
    raise


def normalize(vec: np.ndarray) -> list[float]:
    v = vec.astype("float32")
    n = float(np.linalg.norm(v))
    if n == 0.0:
        return v.tolist()
    return (v / (n + 1e-12)).tolist()


def embed_query(model: SentenceTransformer, text: str) -> list[float]:
    # E5 models expect the "query: " prefix for queries
    emb = model.encode("query: " + (text or ""), convert_to_numpy=True)
    return normalize(emb)


def pretty(obj) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description="Test Pinecone connectivity and query.")
    parser.add_argument("--q", "--query", dest="query", type=str,
                        default="Business intelligence and data dashboards",
                        help="Query text to search for.")
    parser.add_argument("--ns", "--namespace", dest="namespace", type=str,
                        default="job_seekers", help="Pinecone namespace.")
    parser.add_argument("--topk", dest="top_k", type=int, default=5, help="Top K results.")
    args = parser.parse_args()

    api_key = os.getenv("PINECONE_API_KEY")
    index_name = os.getenv("PINECONE_INDEX")
    model_name = os.getenv("EMBED_MODEL_NAME", "intfloat/e5-base-v2")

    if not api_key or not index_name:
        print("❌ Missing env vars. Please set:")
        print("   export PINECONE_API_KEY=... ")
        print("   export PINECONE_INDEX=hiway-jobseekers")
        print("Optional:")
        print("   export EMBED_MODEL_NAME=intfloat/e5-base-v2")
        sys.exit(1)

    print("🔗 Connecting to Pinecone…")
    pc = Pinecone(api_key=api_key)
    idx = pc.Index(index_name)

    stats = idx.describe_index_stats()
    print("📊 Index stats:")
    print(pretty(stats))

    print(f"\n🧠 Loading embedding model: {model_name}")
    model = SentenceTransformer(model_name)

    print(f"\n🔎 Querying namespace '{args.namespace}' with: “{args.query}”")
    qvec = embed_query(model, args.query)

    res = idx.query(
        vector=qvec,
        top_k=args.top_k,
        namespace=args.namespace,
        include_metadata=True,
    )

    # Print concise results
    matches = res.get("matches", [])
    if not matches:
        print("⚠️ No results returned.")
        return

    print("\n✅ Matches:")
    for i, m in enumerate(matches, 1):
        meta = m.get("metadata", {}) or {}
        print(
            f"{i:>2}. id={m.get('id')}  score={m.get('score'):.4f}  "
            f"name={meta.get('full_name')}  scope={meta.get('scope')}  email={meta.get('email')}"
        )

    # Full JSON (uncomment if you want the raw response)
    # print("\nRaw response:")
    # print(pretty(res))


if __name__ == "__main__":
    main()
