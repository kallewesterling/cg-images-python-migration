#!/usr/bin/env bash
#
# TEAR-DOWN for the "Migrating a Flask Application to Chainguard" demo.
# Everything here is local (no registry push in this demo), so there's no
# remote state to clean up -- just containers and images.
#
set -uo pipefail
cd "$(dirname "$0")"

echo "==> Stopping demo containers"
docker compose down >/dev/null 2>&1 || true
docker rm -f pymigrate >/dev/null 2>&1 || true

echo "==> Removing local images"
docker image rm pymigrate:v0 pymigrate:containers pymigrate:libraries >/dev/null 2>&1 || true

echo "==> Removing credentials file"
rm -f .netrc

echo "==> Done. Local state cleaned."
