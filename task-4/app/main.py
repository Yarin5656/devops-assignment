from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse

app = FastAPI()


@app.get("/", response_class=PlainTextResponse)
async def read_root() -> str:
    return "Hello, DevOps!"


@app.post("/echo")
async def echo(payload: Request) -> dict:
    return await payload.json()
