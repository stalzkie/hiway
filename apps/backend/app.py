# apps/backend/app.py
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ---- Load environment variables early ----
# Try repo root and backend folder
ROOT = Path(__file__).resolve().parents[2]   # hiway_app/
BACKEND = Path(__file__).resolve().parents[1]

for p in [ROOT / ".env", BACKEND / ".env"]:
    if p.exists():
        load_dotenv(p, override=False)

# ---- Import routers AFTER env is loaded ----
from apps.backend.api.endpoints import matcher, scraper

# ---- App config ----
app = FastAPI(
    title="HiWay Backend",
    version="1.0.0",
    description="API for job seeker/job post matching and related services"
)

# ---- CORS (adjust origins for your frontend domain) ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: in prod replace with your frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Routers ----
app.include_router(matcher.router, prefix="/matcher", tags=["matcher"])
app.include_router(scraper.router, prefix="/scraper", tags=["scraper"])

# ---- Healthcheck ----
@app.get("/healthz")
def healthz():
    return {"status": "ok"}
