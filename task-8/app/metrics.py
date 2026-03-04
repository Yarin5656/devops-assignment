"""
metrics.py – Prometheus metric definitions.

Kept in its own module so they are created exactly once at import time,
and can be imported by both main.py and tests without re-registration.
"""

from prometheus_client import Counter, Histogram

# ------------------------------------------------------------------
# Counters
# ------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "endpoint", "status_code"],
)

SHORTEN_COUNT = Counter(
    "url_shorten_total",
    "Total number of URLs shortened",
)

RESOLVE_COUNT = Counter(
    "url_resolve_total",
    "Total number of resolve attempts",
    ["result"],  # 'hit' or 'miss'
)

# ------------------------------------------------------------------
# Histograms
# ------------------------------------------------------------------
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)
