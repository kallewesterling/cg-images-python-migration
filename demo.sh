#!/usr/bin/env bash
#
# Migrating a Flask Application to Chainguard -- theater demo (live, scripted with demo-magic).
# One Flask app, one requirements.txt, never touched again. This demo walks the same app
# through three base images -- plain Python, Chainguard Containers, Chainguard Containers +
# Chainguard Libraries -- then wires the fully-migrated build up behind nginx with Compose.
#
# ON stage: run ./demo.sh    (press ENTER to advance; -d disables typing)
#           --skip-comments drops the "# ..." narration lines, showing/running
#           only the actual commands
# BEFORE:   run ./setup.sh   (builds all three images ahead of time)
# AFTER:    run ./teardown.sh
#
# Every command shown is the real command being run -- no hidden wrappers.
# Requires: docker (buildx), docker compose, curl.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SKIP_COMMENTS=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --skip-comments) SKIP_COMMENTS=true ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]}"

. "$HERE/lib/base.sh"

TYPE_SPEED=60
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

clear
echo -e "
Migrating a Flask Application to Chainguard

A default Python image, a Dockerfile, and a handful of pip installs -- that's how most
Flask apps ship. This demo migrates one such app to Chainguard Containers, then to
Chainguard Libraries, in stages -- same app, same requirements.txt, the whole way through.
"
wait

# ---------------------------------------------------------------------------
banner "The app: a simple Flask microservice"
# ---------------------------------------------------------------------------
say "One Flask app, one requirements.txt -- neither changes for the rest of this demo.\nWhat changes is the base image and where dependencies come from:"
pe "cat app/requirements.txt"
pe "cat app/app.py"

# ---------------------------------------------------------------------------
banner "Stage 1: plain Python base image"
# ---------------------------------------------------------------------------
say "Start simple: build straight off the public 'python' image, straight from Docker Hub:"
pe "cat docker/Dockerfile.v0"
pe "docker build -f docker/Dockerfile.v0 -t pymigrate:v0 app"
pei "docker rm -f pymigrate >/dev/null 2>&1"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:v0"
pei "wait_for_http http://localhost:8000"
pe "curl -s http://localhost:8000/"

# ---------------------------------------------------------------------------
banner "Migrate to Chainguard Containers"
# ---------------------------------------------------------------------------
say "Same app, same requirements.txt -- only the base image and build shape change:"
pe "git --no-pager diff --no-index --color=always docker/Dockerfile.v0 docker/Dockerfile.containers"
pe "docker build -f docker/Dockerfile.containers -t pymigrate:containers app"
pei "docker rm -f pymigrate"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:containers"
pei "wait_for_http http://localhost:8000"
pe "curl -s http://localhost:8000/"
p  "# Same response. Minimal, distroless-based image underneath -- and a smaller footprint:"
pe "docker images --filter reference=pymigrate:v0 --filter reference=pymigrate:containers --format 'table {{.Tag}}\t{{.Size}}'"

# ---------------------------------------------------------------------------
banner "Add Chainguard Libraries"
# ---------------------------------------------------------------------------
say "One more line: point pip at the Chainguard Libraries index instead of PyPI:"
pe "git --no-pager diff --no-index --color=always docker/Dockerfile.containers docker/Dockerfile.libraries"
pe "docker build -f docker/Dockerfile.libraries -t pymigrate:libraries app"
pei "docker rm -f pymigrate"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:libraries"
pei "wait_for_http http://localhost:8000"
pe "curl -s http://localhost:8000/"
pei "docker rm -f pymigrate"

# ---------------------------------------------------------------------------
banner "Production topology: Flask behind nginx"
# ---------------------------------------------------------------------------
say "Wire the fully-migrated build up behind nginx with Compose:"
pe "cat compose.yml"
pe "docker compose up -d --build"
pei "wait_for_http http://localhost:80"
pe "curl -s http://localhost:80/"
pei "docker compose down"

banner "Demo complete"
