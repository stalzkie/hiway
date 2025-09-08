from __future__ import annotations
from fastapi import Header, HTTPException, status
from typing import Optional

async def get_bearer_token(authorization: Optional[str] = Header(None)) -> str:
    """
    Returns the raw JWT sent as "Authorization: Bearer <token>".
    Raise 401 if missing or malformed.
    """
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Authorization header")
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1]:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Authorization header")
    return parts[1]
