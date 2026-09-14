#!/usr/bin/env bash
#
# Migrating a Flask Application to Chainguard -- theater demo (live, scripted with demo-magic).
# One Flask app, one requirements.txt, never touched again. This demo walks the same app
# through three base images -- plain Python, Chainguard Containers, Chainguard Containers +
# Chainguard Libraries -- then wires the fully-migrated build up behind nginx with Compose.
#
# ON stage: run ./scripts/demo.sh   (press ENTER to advance; -d disables typing)
#           --skip-comments drops the narration lines, showing/running only the
#           actual commands
# BEFORE:   run ./scripts/setup.sh   (builds all three images ahead of time)
# AFTER:    run ./scripts/teardown.sh
#
# Every command shown is the real command being run -- no hidden wrappers.
# Requires: docker (buildx), docker compose, curl.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the repo root, not from scripts/. Every command this demo displays is
# written relative to the root ("cat docker/Dockerfile.v0", "docker build ... app"),
# so the audience sees paths that match the repo layout rather than ../ hops.
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

SKIP_COMMENTS=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --skip-comments) SKIP_COMMENTS=true ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]}"

if [ ! -f "$ROOT/.netrc" ]; then
  echo "Missing .netrc -- the Chainguard Libraries build stage needs it as a build secret." >&2
  echo "Run ./scripts/setup.sh first." >&2
  exit 1
fi

. "$HERE/lib/base.sh"

# Typing speed is set in scripts/lib/base.sh, before demo-magic parses argv, so that -d
# can switch it off. Don't re-assign it here.
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
say "We can see that it's nothing unusual -- pip install, copy the app in, run gunicorn.\n\nLet's build it:"
pe "docker build -f docker/Dockerfile.v0 -t pymigrate:v0 app"
say "Let's run it:"
pei "docker rm -f pymigrate >/dev/null 2>&1"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:v0"
pei "wait_for_http http://localhost:8000"
say "And it's up. This is the baseline every later stage gets compared against:"
pe "curl -s http://localhost:8000/"
echo

# ---------------------------------------------------------------------------
banner "Migrate to Chainguard Containers"
# ---------------------------------------------------------------------------
say "Same app, same requirements.txt -- only the base image and build shape change:"
pe "git --no-pager diff --no-index --color=always docker/Dockerfile.v0 docker/Dockerfile.containers"
say "We can see that it's a multi-stage build now: dependencies install in a -dev image, then\nonly the venv carries over into the minimal runtime image.\n\nLet's rebuild:"
pe "docker build -f docker/Dockerfile.containers -t pymigrate:containers app"
say "Let's run it:"
pei "docker rm -f pymigrate"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:containers"
pei "wait_for_http http://localhost:8000"
say "Swap the container out from under it -- same URL, same request:"
pe "curl -s http://localhost:8000/"
echo
say "We can see that it's the same response -- minimal, distroless-based image underneath.\n\nLet's compare the footprint:"
pe "docker images pymigrate:v0 --format 'table {{.Tag}}\t{{.Size}}'"
pe "docker images pymigrate:containers --format 'table {{.Tag}}\t{{.Size}}' | tail -1"

# ---------------------------------------------------------------------------
banner "Add Chainguard Libraries"
# ---------------------------------------------------------------------------
say "One more line: point pip at the Chainguard Libraries index instead of PyPI:"
pe "git --no-pager diff --no-index --color=always docker/Dockerfile.containers docker/Dockerfile.libraries"
say "We can see that there are no code changes, no requirements.txt changes -- just where\npip resolves packages from.\n\nLet's rebuild:"
pe "docker build -f docker/Dockerfile.libraries -t pymigrate:libraries app"
say "Let's run it:"
pei "docker rm -f pymigrate"
pei "docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:libraries"
pei "wait_for_http http://localhost:8000"
say "One more time, same check:"
pe "curl -s http://localhost:8000/"
echo
say "We can see that it's still the exact same app. What changed is where the bits came\nfrom, not what they do."
pei "docker rm -f pymigrate"

# ---------------------------------------------------------------------------
banner "Production topology: Flask behind nginx"
# ---------------------------------------------------------------------------
say "Wire the fully-migrated build up behind nginx with Compose:"
pe "cat compose.yml"
say "We can see that flask-app builds from Dockerfile.libraries -- the stage we just landed on.\n\nLet's bring it up:"
pe "docker compose up -d --build"
pei "wait_for_http http://localhost:80"
say "Same app again, now reached through nginx on port 80 instead of talking to it directly:"
pe "curl -s http://localhost:80/"
echo
pei "docker compose down"

banner "Demo complete"
