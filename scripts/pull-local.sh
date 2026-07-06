#!/usr/bin/env bash
#
# pull-local.sh
# -------------
# Finds the newest published image tag and runs it locally with docker compose.
#
# How it works:
#   - The CI pipeline tags every push as <version>-<short-sha> (immutable, unique)
#     and also moves `:latest` to point to the newest successful build.
#   - This script resolves which unique tag `:latest` currently points to
#     (via the registry API, by matching image digests) and pins .env to it.
#   - Then runs `docker compose pull && docker compose up -d`.
#
# Why not just run :latest directly?
#   - :latest is mutable. If you pull it mid-deploy you can grab a broken half-uploaded
#     image. Pinning to the resolved unique tag is stable and reproducible.
#
# Usage:
#   ./scripts/pull-local.sh                 # uses Docker Hub (default)
#   REGISTRY=ghcr ./scripts/pull-local.sh   # uses GHCR
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
IMAGE_NAME="pipeline-task"

# --- load .env ---
if [ ! -f "$ENV_FILE" ]; then
  echo "✗ .env not found. Run:  cp .env.example .env   (then fill in your username)"
  exit 1
fi
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

REGISTRY="${REGISTRY:-dockerhub}" # dockerhub | ghcr

case "$REGISTRY" in
ghcr)
  OWNER="${GHCR_OWNER:?GHCR_OWNER not set in .env}"
  REPO="${OWNER}/${IMAGE_NAME}"
  REGISTRY_HOST="ghcr.io"
  AUTH_URL="https://ghcr.io/token?scope=repository:${REPO}:pull"
  ;;
dockerhub)
  OWNER="${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME not set in .env}"
  REPO="${OWNER}/${IMAGE_NAME}"
  REGISTRY_HOST="registry-1.docker.io"
  AUTH_URL="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${REPO}:pull"
  ;;
*)
  echo "✗ Unknown REGISTRY '$REGISTRY' (use: ghcr | dockerhub)"
  exit 1
  ;;
esac

echo "→ Registry: ${REGISTRY_HOST}/${REPO}"

# --- get an anonymous pull token (works for PUBLIC packages) ---
TOKEN=$(curl -fsS "$AUTH_URL" | jq -r '.token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "✗ Could not get registry token. Is the package published and public?"
  exit 1
fi

AUTH="Authorization: Bearer ${TOKEN}"
# Accept both Docker v2 and OCI manifest types so digest comparison works.
ACCEPT="Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json"

manifest_digest() { # $1 = tag → prints sha256:...
  curl -fsSI -H "$AUTH" -H "$ACCEPT" \
    "https://${REGISTRY_HOST}/v2/${REPO}/manifests/$1" |
    tr -d '\r' | grep -i '^docker-content-digest:' | cut -d' ' -f2
}

# --- resolve :latest to its digest ---
LATEST_DIGEST=$(manifest_digest latest)
if [ -z "$LATEST_DIGEST" ]; then
  echo "✗ Could not resolve :latest. Has the pipeline published a build yet?"
  exit 1
fi
echo "→ :latest digest = ${LATEST_DIGEST}"

# --- list all tags, find the unique one whose digest matches :latest ---
TAGS=$(curl -fsS -H "$AUTH" "https://${REGISTRY_HOST}/v2/${REPO}/tags/list" | jq -r '.tags[]?')
if [ -z "$TAGS" ]; then
  echo "✗ No tags found in registry."
  exit 1
fi

RESOLVED_TAG=""
for TAG in $TAGS; do
  [ "$TAG" = "latest" ] && continue
  DIG=$(manifest_digest "$TAG")
  if [ "$DIG" = "$LATEST_DIGEST" ]; then
    RESOLVED_TAG="$TAG"
    break
  fi
done

if [ -z "$RESOLVED_TAG" ]; then
  echo "✗ No unique tag matches :latest. (Tags: $(echo "$TAGS" | tr '\n' ' '))"
  exit 1
fi
echo "→ Resolved published tag: ${RESOLVED_TAG}"

# --- update IMAGE_TAG in .env ---
CURRENT_TAG="${IMAGE_TAG:-}"
if [ "$CURRENT_TAG" = "$RESOLVED_TAG" ]; then
  echo "→ Already pinned to ${RESOLVED_TAG}."
else
  echo "→ Updating .env: IMAGE_TAG  ${CURRENT_TAG:-<none>}  →  ${RESOLVED_TAG}"
  if grep -q '^IMAGE_TAG=' "$ENV_FILE"; then
    sed -i.bak "s|^IMAGE_TAG=.*|IMAGE_TAG=${RESOLVED_TAG}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    printf 'IMAGE_TAG=%s\n' "$RESOLVED_TAG" >>"$ENV_FILE"
  fi
  export IMAGE_TAG="$RESOLVED_TAG"
fi

# --- pull & run ---
cd "$PROJECT_DIR"
echo "→ docker compose pull"
docker compose pull
echo "→ docker compose up -d"
docker compose up -d

cat <<EOF

✓ Running tag:   ${RESOLVED_TAG}
  Registry:      ${REGISTRY_HOST}/${REPO}
  Port:          ${APP_PORT:-8080}
  Check it:      curl http://localhost:${APP_PORT:-8080}/health
  Version:       curl http://localhost:${APP_PORT:-8080}/version
  Logs:          docker compose logs -f
  Stop:          docker compose down
EOF
