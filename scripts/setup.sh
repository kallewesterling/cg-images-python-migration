#!/usr/bin/env bash
#
# BUILD-UP for the "Migrating a Flask Application to Chainguard" demo. Two things
# happen here:
#   1. A repo-root .netrc is written so the Chainguard Libraries build stage can
#      authenticate to libraries.cgr.dev -- passed to `docker build`/`docker compose
#      build` as a BuildKit secret, never baked into the image.
#   2. All three stage images (plus the Compose topology) are built ahead of time,
#      so nothing builds live on stage.
#
# Run this BEFORE the demo. Re-runnable.
#
# Usage:
#   ORG_NAME=<your-cg-org> ./scripts/setup.sh
#   ./scripts/setup.sh            # prompts for ORG_NAME
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Build from the repo root: the build contexts and -f paths below, and the
# .netrc that compose.yml mounts as a secret, are all root-relative.
cd "$HERE/.."

. "$HERE/lib/org.sh"

echo "==> Writing .netrc for libraries.cgr.dev (build-time secret only, never in the image)"
CREDS_OUTPUT=$(chainctl auth pull-token --repository=python --parent="$ORG_NAME" --ttl=8h -o json)
CGR_USER=$(echo "$CREDS_OUTPUT" | jq -r '.identity_id')
CGR_TOKEN=$(echo "$CREDS_OUTPUT" | jq -r '.token')
printf 'machine libraries.cgr.dev\nlogin %s\npassword %s\n' "$CGR_USER" "$CGR_TOKEN" > .netrc
chmod 0600 .netrc

echo "==> Building v0 (plain python, straight from PyPI)"
docker build -f docker/Dockerfile.v0 -t pymigrate:v0 app

echo "==> Building containers (Chainguard Containers)"
docker build -f docker/Dockerfile.containers -t pymigrate:containers app

echo "==> Building libraries (Chainguard Containers + Chainguard Libraries)"
docker build --secret id=netrc,src=.netrc -f docker/Dockerfile.libraries -t pymigrate:libraries app

echo "==> Pre-building the nginx + Compose topology"
docker compose build

echo
echo "==> Done. ./scripts/demo.sh is ready to run. ./scripts/teardown.sh to clean up afterward."
