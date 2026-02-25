# Phase 1 scaffold: build context is repo root, app source in ./app
FROM python:3.12-slim

WORKDIR /app
COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY app/app.py ./app.py

EXPOSE 8080
CMD ["python", "app.py"]
