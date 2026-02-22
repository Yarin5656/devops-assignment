.PHONY: lint test docker-build docker-run

lint:
	flake8 app

test:
	pytest -q

docker-build:
	docker build -t devops-fastapi:local .

docker-run:
	docker run --rm -p 8000:8000 devops-fastapi:local
