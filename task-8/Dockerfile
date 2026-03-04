# =============================================================================
# Multi-stage production Dockerfile – URL Shortener (FastAPI / Python 3.12)
#
# Stages
# ------
#   builder  – installs Python deps into user-local prefix (no system pollution)
#   runtime  – minimal image: only runtime packages + source, non-root user
#
# Image tagging strategy (see README § Containerization):
#   ghcr.io/<org>/url-shortener:<semver>           e.g. 1.2.3
#   ghcr.io/<org>/url-shortener:<semver>-<sha7>    e.g. 1.2.3-a1b2c3d
#   ghcr.io/<org>/url-shortener:latest             (main branch only)
#   localhost:5001/url-shortener:<tag>             (kind local registry)
# =============================================================================

# ---- Stage 1: builder -------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

COPY app/requirements.txt ./

# Install only runtime deps (dev/test packages excluded)
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir --user \
      "fastapi==0.111.1" \
      "uvicorn[standard]==0.30.3" \
      "pydantic==2.7.4" \
      "prometheus-client==0.20.0"

# ---- Stage 2: runtime -------------------------------------------------------
FROM python:3.12-slim AS runtime

LABEL org.opencontainers.image.title="URL Shortener" \
      org.opencontainers.image.description="FastAPI-based URL shortener" \
      org.opencontainers.image.source="https://github.com/<org>/<repo>"

# Non-root system user for container security
RUN groupadd --system app \
 && useradd --system --gid app --no-create-home --shell /sbin/nologin app

WORKDIR /app

# Bring pre-built packages from builder stage
COPY --from=builder /root/.local /home/app/.local

# Copy only the application source (no tests, no dev tooling)
COPY --chown=app:app app/main.py    ./main.py
COPY --chown=app:app app/models.py  ./models.py
COPY --chown=app:app app/storage.py ./storage.py
COPY --chown=app:app app/metrics.py ./metrics.py

USER app

ENV PATH="/home/app/.local/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION="unknown" \
    BASE_URL="http://localhost:8000" \
    LOG_LEVEL="INFO"

EXPOSE 8000

# Built-in Docker healthcheck (also used by compose)
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c \
      "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" \
      || exit 1

CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--no-access-log"]
