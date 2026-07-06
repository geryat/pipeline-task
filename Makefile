# Read version from VERSION file (single source of truth)
VERSION := $(shell cat VERSION | tr -d '[:space:]')

.PHONY: build up down logs test clean

build:
	IMAGE_TAG=$(VERSION) docker compose build

up:
	IMAGE_TAG=$(VERSION) docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

test:
	@echo "→ /health"
	@curl -s http://localhost:8080/health | python3 -m json.tool
	@echo "\n→ /version"
	@curl -s http://localhost:8080/version | python3 -m json.tool
	@echo "\n→ /info"
	@curl -s http://localhost:8080/info | python3 -m json.tool

rebuild: down build up test

clean:
	docker compose down --rmi all -v
