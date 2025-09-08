#!/usr/bin/env python3
"""
Cleanup script: Remove Pinecone vectors for job posts that no longer exist in the main job_post table.

Usage:
  python cleanup_pinecone_orphans.py

Requirements:
- pinecone-client
- supabase-py
- python-dotenv (if using .env)

Set your environment variables or .env for:
- PINECONE_API_KEY
- PINECONE_INDEX
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

"""
import os
from dotenv import load_dotenv
from pinecone import Pinecone
from supabase import create_client

# Load environment variables
load_dotenv()

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
PINECONE_INDEX = os.getenv("PINECONE_INDEX")
PINECONE_NAMESPACE = os.getenv("PINECONE_NS_JOB_POSTS", "job_posts")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

assert PINECONE_API_KEY and PINECONE_INDEX and SUPABASE_URL and SUPABASE_KEY, "Missing required env vars."

# Connect to Pinecone
pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(PINECONE_INDEX)

# Connect to Supabase
sb = create_client(SUPABASE_URL, SUPABASE_KEY)

# 1. Get all job_post_ids from Supabase
def get_valid_job_post_ids():
    ids = set()
    page = 0
    page_size = 1000
    while True:
        resp = sb.table("job_post").select("job_post_id").range(page * page_size, (page + 1) * page_size - 1).execute()
        rows = resp.data or []
        if not rows:
            break
        ids.update(str(row["job_post_id"]) for row in rows if row.get("job_post_id"))
        if len(rows) < page_size:
            break
        page += 1
    return ids

# 2. Get all vector IDs from Pinecone (for the job_posts namespace)
def get_pinecone_post_ids():
    # Pinecone's fetch API is paginated; use index.describe_index_stats for all IDs
    stats = index.describe_index_stats(namespace=PINECONE_NAMESPACE)
    return set(stats.get("namespaces", {}).get(PINECONE_NAMESPACE, {}).get("vector_count", 0))

# 3. Find orphaned IDs and delete them
def main():
    print("Fetching valid job_post_ids from Supabase...")
    valid_ids = get_valid_job_post_ids()
    print(f"Found {len(valid_ids)} valid job_post_ids.")

    print("Fetching vector IDs from Pinecone...")
    stats = index.describe_index_stats(namespace=PINECONE_NAMESPACE)
    all_ids = set(stats.get("namespaces", {}).get(PINECONE_NAMESPACE, {}).get("vector_ids", []))
    print(f"Found {len(all_ids)} vectors in Pinecone namespace '{PINECONE_NAMESPACE}'.")

    # If your Pinecone IDs are like 'job_post_id:section', split and compare only the job_post_id part
    orphan_ids = [vid for vid in all_ids if vid.split(":")[0] not in valid_ids]
    print(f"Found {len(orphan_ids)} orphaned vectors to delete.")

    # Delete in batches (Pinecone allows up to 1000 per call)
    BATCH = 1000
    for i in range(0, len(orphan_ids), BATCH):
        batch = orphan_ids[i:i+BATCH]
        print(f"Deleting batch {i//BATCH+1}: {len(batch)} vectors...")
        index.delete(ids=batch, namespace=PINECONE_NAMESPACE)
    print("Cleanup complete.")

if __name__ == "__main__":
    main()
