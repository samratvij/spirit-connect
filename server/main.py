"""
Spirit Connect — FastAPI backend entrypoint.
"""

import logging

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db
from middleware.auth import BearerTokenMiddleware
from routes.chat import router as chat_router
from routes.memory import router as memory_router
from routes.conversations import router as conversations_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Spirit Connect server...")
    await init_db()
    logger.info("Database initialized.")
    yield
    logger.info("Spirit Connect server shutting down.")


app = FastAPI(
    title="Spirit Connect",
    description="Personal AI assistant backend — private, memory-enabled.",
    version="1.0.0",
    lifespan=lifespan,
)

# Auth middleware (applied to all routes except PUBLIC_PATHS)
app.add_middleware(BearerTokenMiddleware)

# CORS — allow mobile app origin (Tailscale IPs are internal, but Flutter needs this)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Locked down by Tailscale VPN + API key at network level
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(chat_router)
app.include_router(memory_router)
app.include_router(conversations_router)


@app.get("/health", tags=["system"])
async def health():
    return {"status": "ok", "service": "spirit-connect"}
