from pydantic import BaseModel, HttpUrl


class CharacterOut(BaseModel):
    name: str
    location: str
    image: HttpUrl
