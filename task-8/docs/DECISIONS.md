# DECISIONS.md

Short, high-signal record of implementation decisions.

## 1) FastAPI + Python 3.11
- Chosen for readable API code, strong typing support, and interview familiarity.

## 2) Modular service structure
- `app/services/rickmorty.py` for data fetch/filter logic.
- `app/utils/csv_writer.py` for reusable CSV output.
- `app/main.py` remains thin controller layer.

## 3) Exact Earth match
- Filter uses strict `origin.name == "Earth"` (not partial match).
- This aligns with assignment requirement and avoids ambiguous interpretations.

## 4) Pagination support
- Upstream API is traversed through `info.next` until exhausted.
- Ensures correctness across all pages.

## 5) CI determinism via offline fixture mode
- Added `RM_OFFLINE=1` to avoid flaky CI from upstream 429/rate limits.
- Fixture mode uses local `data/fixtures_characters.json` with same filtering logic.

## 6) Error semantics
- Upstream 429 maps to `503 Service Unavailable` (temporary dependency issue).
- Other upstream/network failures map to `502`.

## 7) Deployment artifacts
- Plain k8s manifests in `yamls/` for transparency.
- Helm chart for values-driven deployments and interview discussion.

## 8) CI strategy
- Docker smoke test validates runtime behavior quickly.
- kind smoke test validates Kubernetes deployment path.
