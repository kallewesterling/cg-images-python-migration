#!/usr/bin/env bash
#
# BUILD-UP for the "Migrating a Flask Application to Chainguard" demo. Four things
# happen here:
#   1. A repo-root .netrc is written so the Chainguard Libraries build stage can
#      authenticate to libraries.cgr.dev -- passed to `docker build`/`docker compose
#      build` as a BuildKit secret, never baked into the image.
#   2. All three stage images (plus the Compose topology) are built ahead of time,
#      so nothing builds live on stage.
#   3. The grype vulnerability database is refreshed. grype rejects a database more
#      than 5 days old outright, so this is not optional housekeeping -- a stale one
#      means the scan beats fail on stage rather than printing a smaller number.
#   4. SBOMs are generated for the two images the demo scans. Scanning the 1.6GB
#      baseline image directly takes ~50s; scanning its SBOM takes ~10s. Since that
#      scan happens in front of an audience, the cataloguing moves in here.
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

for tool in chainctl jq docker grype syft; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool" >&2
    echo "See the README prerequisites; on macOS most of these are 'brew install $tool'." >&2
    exit 1
  }
done

. "$HERE/lib/org.sh"

echo "==> Writing .netrc for libraries.cgr.dev (build-time secret only, never in the image)"
CREDS_OUTPUT=$(chainctl auth pull-token --repository=python --parent="$ORG_NAME" --ttl=8h -o json)
CGR_USER=$(echo "$CREDS_OUTPUT" | jq -r '.identity_id')
CGR_TOKEN=$(echo "$CREDS_OUTPUT" | jq -r '.token')
printf 'machine libraries.cgr.dev\nlogin %s\npassword %s\n' "$CGR_USER" "$CGR_TOKEN" > .netrc
chmod 0600 .netrc

echo "==> Building baseline (plain python, straight from PyPI)"
docker build \
  -f docker/Dockerfile.baseline \
  -t pymigrate:baseline \
  app

echo "==> Building containers (Chainguard Containers)"
docker build \
  -f docker/Dockerfile.containers \
  -t pymigrate:containers \
  app

echo "==> Building libraries (Chainguard Containers + Chainguard Libraries)"
docker build \
  --secret id=netrc,src=.netrc \
  -f docker/Dockerfile.libraries \
  -t pymigrate:libraries \
  app

echo "==> Pre-building the nginx + Compose topology"
docker compose build

echo "==> Refreshing the grype vulnerability database"
# grype refuses a database older than 5 days. Left to chance this fails live.
grype db update

echo "==> Cataloguing the two scanned images into SBOMs"
# The demo scans SBOMs rather than images so the baseline scan is ~10s on stage
# instead of ~50s. Only the two images the demo actually compares are catalogued;
# libraries scans identically to containers, so the demo doesn't scan it.
mkdir -p sboms
syft pymigrate:baseline   -o syft-json=sboms/baseline.json   -q
syft pymigrate:containers -o syft-json=sboms/containers.json -q

echo
echo "==> Done. ./scripts/demo.sh is ready to run. ./scripts/teardown.sh to clean up afterward."
