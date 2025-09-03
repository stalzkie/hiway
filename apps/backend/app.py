# apps/backend/app.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# import your endpoint routers
from apps.backend.api.endpoints import matcher

app = FastAPI(
    title="HiWay Backend",
    version="1.0.0",
    description="API for job seeker/job post matching and related services"
)

# ---- CORS (adjust origins for your frontend domain) ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # in prod: replace with ["https://your-frontend.com"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Routers ----
app.include_router(matcher.router, prefix="/matcher", tags=["matcher"])

# ---- Healthcheck ----
@app.get("/healthz")
def healthz():
    return {"status": "ok"}
