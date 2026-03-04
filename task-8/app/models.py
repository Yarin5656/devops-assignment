"""Pydantic request/response models for the URL shortener API."""

from pydantic import BaseModel, HttpUrl, field_validator


class ShortenRequest(BaseModel):
    url: HttpUrl

    @field_validator("url")
    @classmethod
    def url_must_have_scheme(cls, v: HttpUrl) -> HttpUrl:
        if str(v).startswith(("http://", "https://")):
            return v
        raise ValueError("URL must start with http:// or https://")


class ShortenResponse(BaseModel):
    code: str
    short_url: str


class ResolveRequest(BaseModel):
    code: str


class ResolveResponse(BaseModel):
    url: str


class HealthResponse(BaseModel):
    status: str
    version: str
