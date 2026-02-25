from fastapi import FastAPI, HTTPException

from app.services.rickmorty import RickMortyServiceError, fetch_alive_human_from_earth
from app.utils.csv_writer import write_characters_to_csv

app = FastAPI(title="Rick and Morty Assignment API", version="1.0.0")


@app.get("/healthcheck")
def healthcheck() -> dict:
    return {"status": "ok"}


@app.get("/characters")
def get_characters() -> list[dict]:
    try:
        characters = fetch_alive_human_from_earth()
    except RickMortyServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return [character.model_dump() for character in characters]


@app.get("/characters/export-csv")
def export_characters_csv() -> dict:
    try:
        characters = fetch_alive_human_from_earth()
        output_path = write_characters_to_csv(characters)
    except RickMortyServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return {
        "status": "success",
        "message": "CSV generated",
        "path": str(output_path),
        "count": len(characters),
    }
