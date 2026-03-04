"""
storage.py – pluggable URL storage abstraction.

The interface (URLStorage) separates the contract from the implementation.
To swap to Redis or PostgreSQL, implement URLStorage and inject it via
the FastAPI dependency, no other code changes needed.
"""

from abc import ABC, abstractmethod
from typing import Optional
import threading


class URLStorage(ABC):
    """Abstract interface for URL code ↔ URL mapping."""

    @abstractmethod
    def save(self, code: str, url: str) -> None:
        """Persist a code→url mapping."""

    @abstractmethod
    def get(self, code: str) -> Optional[str]:
        """Return the URL for *code*, or None if not found."""

    @abstractmethod
    def exists(self, code: str) -> bool:
        """Return True if *code* is already taken."""


class InMemoryStorage(URLStorage):
    """
    Thread-safe in-memory implementation (for local dev / testing).

    Future improvement: replace with RedisStorage(URLStorage) that talks
    to a Redis cluster, giving persistence, TTLs, and horizontal scale.
    The swap is zero-code-change in main.py – only the DI binding changes.
    """

    def __init__(self) -> None:
        self._store: dict[str, str] = {}
        self._lock = threading.Lock()

    def save(self, code: str, url: str) -> None:
        with self._lock:
            self._store[code] = url

    def get(self, code: str) -> Optional[str]:
        with self._lock:
            return self._store.get(code)

    def exists(self, code: str) -> bool:
        with self._lock:
            return code in self._store
