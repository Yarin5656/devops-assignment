import logging
import time
from typing import List

import httpx

from app.models import CharacterOut

logger = logging.getLogger(__name__)

RICK_AND_MORTY_CHARACTERS_URL = "https://rickandmortyapi.com/api/character"
REQUEST_TIMEOUT_SECONDS = 10.0
MAX_RETRIES = 3
BACKOFF_SECONDS = 1.5


class RickMortyServiceError(Exception):
    """Raised when character fetch fails."""


def is_target_character(item: dict) -> bool:
    return (
        item.get("species") == "Human"
        and item.get("status") == "Alive"
        and item.get("origin", {}).get("name") == "Earth"
    )


def fetch_alive_human_from_earth() -> List[CharacterOut]:
    """Fetch all pages and return filtered character list.

    Filters:
    - species == Human
    - status == Alive
    - origin.name == Earth (exact match)
    """
    results: List[CharacterOut] = []
    next_url = RICK_AND_MORTY_CHARACTERS_URL

    headers = {"User-Agent": "rickmorty-assignment-ci/1.0"}

    with httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS, headers=headers) as client:
        while next_url:
            last_error: Exception | None = None
            response = None

            for attempt in range(1, MAX_RETRIES + 1):
                try:
                    response = client.get(next_url)
                    if response.status_code == 429 and attempt < MAX_RETRIES:
                        time.sleep(BACKOFF_SECONDS * attempt)
                        continue
                    response.raise_for_status()
                    last_error = None
                    break
                except httpx.TimeoutException as exc:
                    last_error = exc
                    if attempt < MAX_RETRIES:
                        time.sleep(BACKOFF_SECONDS * attempt)
                        continue
                except httpx.HTTPStatusError as exc:
                    last_error = exc
                    if exc.response.status_code in (429, 500, 502, 503, 504) and attempt < MAX_RETRIES:
                        time.sleep(BACKOFF_SECONDS * attempt)
                        continue
                except httpx.HTTPError as exc:
                    last_error = exc
                    if attempt < MAX_RETRIES:
                        time.sleep(BACKOFF_SECONDS * attempt)
                        continue

            if response is None or response.status_code >= 400:
                if isinstance(last_error, httpx.TimeoutException):
                    raise RickMortyServiceError("Request timed out while fetching characters") from last_error
                if isinstance(last_error, httpx.HTTPStatusError):
                    raise RickMortyServiceError(
                        f"Rick and Morty API returned status {last_error.response.status_code}"
                    ) from last_error
                if last_error is not None:
                    raise RickMortyServiceError("Network error while fetching characters") from last_error
                raise RickMortyServiceError("Unknown error while fetching characters")

            payload = response.json()
            page_results = payload.get("results", [])
            next_url = payload.get("info", {}).get("next")

            for item in page_results:
                if is_target_character(item):
                    try:
                        results.append(
                            CharacterOut(
                                name=item.get("name", ""),
                                location=item.get("location", {}).get("name", ""),
                                image=item.get("image", ""),
                            )
                        )
                    except Exception:
                        logger.exception("Skipping invalid character payload: %s", item)

    return results
