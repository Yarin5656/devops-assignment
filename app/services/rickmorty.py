import logging
from typing import List

import httpx

from app.models import CharacterOut

logger = logging.getLogger(__name__)

RICK_AND_MORTY_CHARACTERS_URL = "https://rickandmortyapi.com/api/character"
REQUEST_TIMEOUT_SECONDS = 10.0


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

    with httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS) as client:
        while next_url:
            try:
                response = client.get(next_url)
                response.raise_for_status()
            except httpx.TimeoutException as exc:
                raise RickMortyServiceError("Request timed out while fetching characters") from exc
            except httpx.HTTPStatusError as exc:
                raise RickMortyServiceError(
                    f"Rick and Morty API returned status {exc.response.status_code}"
                ) from exc
            except httpx.HTTPError as exc:
                raise RickMortyServiceError("Network error while fetching characters") from exc

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
