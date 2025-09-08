from __future__ import annotations
import os
from typing import Optional
from supabase import Client, create_client

_SUPABASE_URL = os.environ["SUPABASE_URL"]
# Use SERVICE ROLE for server-side operations like admin tasks,
# but for RLS-protected tables we will set the user's JWT per request.
_SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

def get_sb() -> Client:
    return create_client(_SUPABASE_URL, _SUPABASE_SERVICE_KEY)

def as_user(client: Client, user_jwt: str) -> Client:
    # Mutates the client’s auth context to use the end-user token
    client.auth.set_auth(user_jwt)
    return client
