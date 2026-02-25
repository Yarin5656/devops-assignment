import csv
from pathlib import Path
from typing import Iterable

from app.models import CharacterOut

DEFAULT_OUTPUT_PATH = Path("data/output.csv")


def write_characters_to_csv(
    characters: Iterable[CharacterOut], output_path: Path = DEFAULT_OUTPUT_PATH
) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=["name", "location", "image"])
        writer.writeheader()
        for character in characters:
            writer.writerow(
                {
                    "name": character.name,
                    "location": character.location,
                    "image": str(character.image),
                }
            )

    return output_path
