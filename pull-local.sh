#!/bin/bash
set -e

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-geryat}"
VERSION="${VERSION:-latest}"
IMAGE="$DOCKERHUB_USERNAME/pipeline-task:$VERSION"

echo "Pulling $IMAGE from Docker Hub..."
docker pull "$IMAGE"

echo "Restarting container..."
DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME VERSION=$VERSION \
  docker compose -f docker-compose.yml -f docker-compose.remote.yml down
DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME VERSION=$VERSION \
  docker compose -f docker-compose.yml -f docker-compose.remote.yml up -d

echo "Done. Running: $IMAGE"
echo "Health check: curl http://localhost:5000/health"
