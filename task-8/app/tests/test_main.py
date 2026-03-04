"""
test_main.py – pytest test suite for the URL Shortener API.

Run from the app/ directory:
    pytest tests/ -v --cov=.. --cov-report=term-missing

Coverage gate is enforced in CI via --cov-fail-under=80.
"""

import sys
import os

# Ensure the app package is on sys.path when tests run from repo root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from fastapi.testclient import TestClient

# Isolate prometheus registry so repeated test runs don't error on duplicate metric names
from prometheus_client import CollectorRegistry

# We patch the global registry before importing main so metrics are fresh
import prometheus_client as _pc

_test_registry = CollectorRegistry()
_pc.REGISTRY = _test_registry  # type: ignore[attr-defined]

from main import app, _storage  # noqa: E402  (import after registry patch)
from storage import InMemoryStorage  # noqa: E402

client = TestClient(app)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def clear_storage():
    """Reset the in-memory store between tests to ensure isolation."""
    # Access internal dict directly (test-only privilege)
    _storage._store.clear()  # type: ignore[attr-defined]
    yield
    _storage._store.clear()  # type: ignore[attr-defined]


# ---------------------------------------------------------------------------
# /healthz
# ---------------------------------------------------------------------------


def test_healthz_returns_200():
    resp = client.get("/healthz")
    assert resp.status_code == 200


def test_healthz_body():
    resp = client.get("/healthz")
    body = resp.json()
    assert body["status"] == "ok"
    assert "version" in body


# ---------------------------------------------------------------------------
# /shorten
# ---------------------------------------------------------------------------


def test_shorten_returns_200():
    resp = client.post("/shorten", json={"url": "https://example.com"})
    assert resp.status_code == 200


def test_shorten_response_has_code_and_short_url():
    resp = client.post("/shorten", json={"url": "https://example.com"})
    body = resp.json()
    assert "code" in body
    assert "short_url" in body
    assert len(body["code"]) == 6


def test_shorten_code_is_alphanumeric():
    resp = client.post("/shorten", json={"url": "https://example.com"})
    code = resp.json()["code"]
    assert code.isalnum()


def test_shorten_invalid_url_returns_422():
    resp = client.post("/shorten", json={"url": "not-a-url"})
    assert resp.status_code == 422


def test_shorten_missing_body_returns_422():
    resp = client.post("/shorten", json={})
    assert resp.status_code == 422


def test_shorten_multiple_calls_produce_different_codes():
    codes = set()
    for _ in range(5):
        resp = client.post("/shorten", json={"url": "https://example.com"})
        codes.add(resp.json()["code"])
    # With 62^6 ~= 56 billion possibilities, collisions in 5 calls are impossible
    assert len(codes) == 5


# ---------------------------------------------------------------------------
# /resolve
# ---------------------------------------------------------------------------


def test_resolve_returns_original_url():
    shorten_resp = client.post("/shorten", json={"url": "https://example.com"})
    code = shorten_resp.json()["code"]

    resolve_resp = client.post("/resolve", json={"code": code})
    assert resolve_resp.status_code == 200
    assert resolve_resp.json()["url"] == "https://example.com/"


def test_resolve_unknown_code_returns_404():
    resp = client.post("/resolve", json={"code": "zzzzzz"})
    assert resp.status_code == 404


def test_resolve_missing_body_returns_422():
    resp = client.post("/resolve", json={})
    assert resp.status_code == 422


def test_full_roundtrip():
    """End-to-end: shorten → resolve must give back the original URL."""
    original = "https://docs.python.org/3/"
    shorten = client.post("/shorten", json={"url": original})
    assert shorten.status_code == 200
    code = shorten.json()["code"]

    resolve = client.post("/resolve", json={"code": code})
    assert resolve.status_code == 200
    assert resolve.json()["url"] == original


# ---------------------------------------------------------------------------
# /metrics
# ---------------------------------------------------------------------------


def test_metrics_endpoint_available():
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "text/plain" in resp.headers["content-type"]


# ---------------------------------------------------------------------------
# Storage unit tests
# ---------------------------------------------------------------------------


def test_inmemory_storage_save_and_get():
    s = InMemoryStorage()
    s.save("abc", "https://example.com")
    assert s.get("abc") == "https://example.com"


def test_inmemory_storage_get_missing():
    s = InMemoryStorage()
    assert s.get("missing") is None


def test_inmemory_storage_exists():
    s = InMemoryStorage()
    assert not s.exists("x")
    s.save("x", "https://x.com")
    assert s.exists("x")
