"""
main.py – FastAPI URL Shortener

Endpoints
---------
POST /shorten  body: {"url": "https://..."} → {"code": "abc123", "short_url": "..."}
POST /resolve  body: {"code": "abc123"}      → {"url": "https://..."}
GET  /healthz                                → {"status": "ok", "version": "..."}
GET  /metrics                               → Prometheus text exposition
"""

import json
import logging
import os
import random
import string
import time
from typing import Callable

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from metrics import REQUEST_COUNT, REQUEST_LATENCY, RESOLVE_COUNT, SHORTEN_COUNT
from models import (
    HealthResponse,
    ResolveRequest,
    ResolveResponse,
    ShortenRequest,
    ShortenResponse,
)
from storage import InMemoryStorage, URLStorage

# ---------------------------------------------------------------------------
# Structured JSON logging
# ---------------------------------------------------------------------------

APP_VERSION = os.getenv("APP_VERSION", "dev")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()


class _JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "line": record.lineno,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload)


def _configure_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(_JSONFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))


_configure_logging()
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application & DI
# ---------------------------------------------------------------------------

app = FastAPI(
    title="URL Shortener",
    version=APP_VERSION,
    description="Simple URL shortener with pluggable storage.",
)

# Singleton storage – swap InMemoryStorage for RedisStorage here (or via env)
_storage: URLStorage = InMemoryStorage()


def get_storage() -> URLStorage:
    """FastAPI dependency that yields the current storage backend."""
    return _storage


# ---------------------------------------------------------------------------
# Middleware – metrics & structured access log
# ---------------------------------------------------------------------------


@app.middleware("http")
async def _metrics_and_logging(request: Request, call_next: Callable) -> Response:
    start = time.perf_counter()
    response: Response = await call_next(request)
    duration = time.perf_counter() - start

    endpoint = request.url.path
    method = request.method
    status = str(response.status_code)

    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status_code=status).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)

    logger.info(
        "request",
        extra={},  # structured fields are in the message for simplicity
    )
    logger.info(
        json.dumps(
            {
                "event": "request",
                "method": method,
                "path": endpoint,
                "status": response.status_code,
                "duration_ms": round(duration * 1000, 2),
            }
        )
    )
    return response


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_CODE_CHARS = string.ascii_letters + string.digits
_CODE_LENGTH = int(os.getenv("CODE_LENGTH", "6"))
_BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")


def _generate_code(storage: URLStorage, length: int = _CODE_LENGTH) -> str:
    """Generate a unique random alphanumeric code."""
    for _ in range(10):  # retry on collision (astronomically unlikely)
        code = "".join(random.choices(_CODE_CHARS, k=length))
        if not storage.exists(code):
            return code
    raise RuntimeError("Could not generate a unique code after 10 attempts")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.get("/healthz", response_model=HealthResponse, tags=["ops"])
def healthz() -> HealthResponse:
    """Liveness / readiness probe endpoint."""
    return HealthResponse(status="ok", version=APP_VERSION)


@app.post("/shorten", response_model=ShortenResponse, tags=["api"])
def shorten(
    req: ShortenRequest,
    storage: URLStorage = Depends(get_storage),
) -> ShortenResponse:
    """Create a short code for the given URL."""
    code = _generate_code(storage)
    url_str = str(req.url)
    storage.save(code, url_str)
    short_url = f"{_BASE_URL.rstrip('/')}/{code}"
    logger.info(json.dumps({"event": "shorten", "code": code, "url": url_str}))
    SHORTEN_COUNT.inc()
    return ShortenResponse(code=code, short_url=short_url)


@app.post("/resolve", response_model=ResolveResponse, tags=["api"])
def resolve(
    req: ResolveRequest,
    storage: URLStorage = Depends(get_storage),
) -> ResolveResponse:
    """Resolve a short code back to the original URL."""
    url = storage.get(req.code)
    if url is None:
        RESOLVE_COUNT.labels(result="miss").inc()
        logger.warning(json.dumps({"event": "resolve_miss", "code": req.code}))
        raise HTTPException(status_code=404, detail=f"Code '{req.code}' not found")
    RESOLVE_COUNT.labels(result="hit").inc()
    logger.info(json.dumps({"event": "resolve_hit", "code": req.code, "url": url}))
    return ResolveResponse(url=url)


@app.get("/metrics", tags=["ops"], include_in_schema=False)
def metrics() -> Response:
    """Prometheus metrics endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
