# apps/backend/app.py
from pathlib import Path
from dotenv import load_dotenv
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ---- Load environment variables early (local only) ----
def _load_local_env_if_present() -> None:
    """
    In production (Railway), env vars come from the platform, no .env file exists.
    Silently load a local .env only if present. Never override platform env.
    """
    if os.getenv("RUNTIME_ENV", "").lower() == "production":
        return

    candidates = [
        Path(__file__).resolve().parents[2] / ".env",  # repo root
        Path(__file__).resolve().parents[1] / ".env",  # apps/backend/.env
    ]
    for p in candidates:
        if p.exists():
            load_dotenv(p, override=False)
            print(f"[DIAG] loaded .env: {p}")  # optional for local dev
            return

_load_local_env_if_present()

# ---- Import routers AFTER env is loaded ----
from apps.backend.api.endpoints import (  # noqa: E402
    matcher,
    scraper,
    orchestrator,
    applications,  # applications API (prefix="/applications")
)

# ---- App config ----
app = FastAPI(
    title="HiWay Backend",
    version="1.0.0",
    description="API for job seeker/job post matching and related services",
)

# ---- CORS (adjust origins for your frontend domain) ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: tighten for prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Routers ----
# Expose matcher at /match (so GET /match works)
app.include_router(matcher.router, prefix="", tags=["matcher"])
# Keep the others as-is
app.include_router(scraper.router, prefix="/scraper", tags=["scraper"])
app.include_router(orchestrator.router, prefix="/api", tags=["Orchestrator"])
# Applications API (router already uses prefix="/applications")
app.include_router(applications.router)

# ---- Root & Health ----
@app.get("/")
def root():
    return {"status": "ok"}

@app.get("/healthz")
def healthz():
    return {"status": "ok"}
