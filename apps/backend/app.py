# apps/backend/app.py
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ---- Load environment variables early ----
# Try repo root and backend folder
def _load_local_env_if_present() -> None:
    """
    In production (Railway), env vars come from the platform, no .env file exists.
    Silently load a local .env only if present. Never override platform env.
    """
    # If you set RUNTIME_ENV=production on Railway, skip loading files
    if os.getenv("RUNTIME_ENV", "").lower() == "production":
        return

    candidates = [
        Path(__file__).resolve().parents[2] / ".env",      # repo root
        Path(__file__).resolve().parents[1] / ".env",      # apps/backend/.env
    ]
    for p in candidates:
        if p.exists():
            load_dotenv(p, override=False)
            print(f"[DIAG] loaded .env: {p}")  # optional
            return
    # No print in prod; keep quiet if not found
    # print(f"[DIAG] no .env found (tried={[str(c) for c in candidates]})")

_load_local_env_if_present()

# ---- Import routers AFTER env is loaded ----
from apps.backend.api.endpoints import (
    matcher,
    scraper,
    orchestrator,
    applications,  # <-- NEW
)  # noqa: E402

# ---- App config ----
app = FastAPI(
    title="HiWay Backend",
    version="1.0.0",
    description="API for job seeker/job post matching and related services",
)

# ---- CORS (adjust origins for your frontend domain) ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: in prod replace with your frontend domain(s)
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

# ---- Healthcheck ----
@app.get("/healthz")
def healthz():
    return {"status": "ok"}
