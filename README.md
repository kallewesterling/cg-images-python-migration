# Migrating a Flask Application to Chainguard

A default Python image, a Dockerfile, and a handful of `pip install`s — that's how most
Flask apps ship. This repo takes one such app and migrates it, in stages, to
[Chainguard Containers](https://www.chainguard.dev/containers) and then
[Chainguard Libraries](https://www.chainguard.dev/libraries).

The point of the exercise: **the application never changes.** One `app.py`, one
`requirements.txt`, untouched from the first stage to the last. What changes is the base
image and where dependencies are resolved from — and at every stage the app still
returns the same response.

You can work through this yourself (below), or
[present it to an audience](FACILITATOR.md).

## The stages

| Stage | Dockerfile | What changes |
|---|---|---|
| 1 | [`docker/Dockerfile.baseline`](docker/Dockerfile.baseline) | The starting point: `FROM python`, `pip install` from PyPI, single stage. |
| 2 | [`docker/Dockerfile.containers`](docker/Dockerfile.containers) | `FROM cgr.dev/chainguard/python`. Becomes multi-stage: dependencies install into a venv in a `-dev` image, only the venv carries into a minimal runtime image with no shell or package manager. |
| 3 | [`docker/Dockerfile.libraries`](docker/Dockerfile.libraries) | Same image, one changed `pip install`: resolve packages from Chainguard Libraries instead of PyPI. |
| 4 | [`compose.yml`](compose.yml) | The migrated build behind nginx (also a Chainguard image), as a production-shaped topology. |

The diff between consecutive Dockerfiles *is* the migration. Reading them side by side is
the fastest way to see how little has to change:

```bash
git diff --no-index docker/Dockerfile.baseline docker/Dockerfile.containers
git diff --no-index docker/Dockerfile.containers docker/Dockerfile.libraries
```

## Prerequisites

For **stages 1 and 2** — no credentials, no account:

- `docker` with `buildx` and `compose`
- `curl` and `git`

For **stages 3 and 4** you additionally need access to Chainguard Libraries for Python,
which is a paid Chainguard feature tied to an organization:

- A Chainguard organization with Chainguard Libraries for Python enabled
- [`chainctl`](https://edu.chainguard.dev/chainguard/chainctl/), authenticated
  (`chainctl auth login`)
- `jq`

If you don't have Libraries access, stages 1 and 2 still stand on their own — they're
the Chainguard Containers migration, which is the bigger structural change anyway.

## Self-guided: run the scripted walkthrough

The scripted path replays the whole migration one command at a time, so you can read each
command before it runs. It needs Libraries access, because it builds every stage
including stage 3.

```bash
./scripts/setup.sh      # authenticates, writes .netrc, pre-builds all stage images
./scripts/demo.sh       # press ENTER to advance through the migration
./scripts/teardown.sh   # removes containers, images, and the credentials file
```

`./scripts/setup.sh` prompts for your Chainguard organization, or takes it from the environment:

```bash
ORG_NAME=my-org.example ./scripts/setup.sh
```

Useful `./scripts/demo.sh` flags:

| Flag | Effect |
|---|---|
| `-d` | Turn off the simulated typing. Also removes the dependency on `pv`. |
| `--skip-comments` | Drop the narration and run only the commands. |
| `-w5` | Auto-advance after 5 seconds instead of waiting for ENTER. |
| `-n` | Never wait. Runs the entire demo start to finish without pausing. |

The simulated typing needs [`pv`](https://www.ivarch.com/programs/pv.shtml)
(`brew install pv` on macOS). If you'd rather not install it, use `-d`.

Every command the script displays is the real command being run — there are no hidden
wrappers. If you'd rather drive it yourself, the section below is the same sequence by
hand.

## Self-guided: by hand

**Stage 1 — the starting point.** No credentials needed.

```bash
docker build -f docker/Dockerfile.baseline -t pymigrate:baseline app
docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:baseline
curl -s http://localhost:8000/
docker rm -f pymigrate
```

**Stage 2 — Chainguard Containers.** Still no credentials needed.

```bash
docker build -f docker/Dockerfile.containers -t pymigrate:containers app
docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:containers
curl -s http://localhost:8000/
docker rm -f pymigrate
```

Same response from a much smaller image with far less in it. Compare them:

```bash
docker images pymigrate:baseline   --format 'table {{.Tag}}\t{{.Size}}'
docker images pymigrate:containers --format 'table {{.Tag}}\t{{.Size}}'
```

**Stage 3 — Chainguard Libraries.** Needs Libraries access. The build authenticates to
`libraries.cgr.dev` with a short-lived token, passed in as a BuildKit secret:

```bash
CREDS=$(chainctl auth pull-token --repository=python --parent=my-org.example --ttl=8h -o json)
printf 'machine libraries.cgr.dev\nlogin %s\npassword %s\n' \
  "$(jq -r .identity_id <<<"$CREDS")" "$(jq -r .token <<<"$CREDS")" > .netrc
chmod 0600 .netrc

docker build --secret id=netrc,src=.netrc \
  -f docker/Dockerfile.libraries -t pymigrate:libraries app
docker run -d --rm -p 8000:8000 --name pymigrate pymigrate:libraries
curl -s http://localhost:8000/
docker rm -f pymigrate
```

(`./scripts/setup.sh` does exactly this — the expanded version is here so you can see what it does.)

**Stage 4 — behind nginx.**

```bash
docker compose up -d --build
curl -s http://localhost:80/
docker compose down
```

## How credentials are handled

The Libraries stage needs to authenticate to `libraries.cgr.dev`. This repo does that with
a **build-time secret, never a baked-in layer**:

- `chainctl auth pull-token --ttl=8h` mints a short-lived token.
- It's written to a repo-root `.netrc`, mode `0600`, which is **gitignored and never
  committed**.
- The build mounts it with `RUN --mount=type=secret,id=netrc`, so it exists only for the
  duration of that `RUN` and never lands in the image or its history.
- `./scripts/teardown.sh` deletes it.

If you copy this pattern, keep that shape: a secret mount, not a `COPY` and not a
build `ARG`.

## Layout

```
app/
  app.py                   one Flask app, shared by every stage
  requirements.txt         one requirements.txt, shared by every stage
docker/
  Dockerfile.baseline      stage 1: plain python, from PyPI
  Dockerfile.containers    stage 2: Chainguard Containers, multi-stage
  Dockerfile.libraries     stage 3: + Chainguard Libraries
nginx/                     nginx (Chainguard image) fronting the migrated build
compose.yml                stage 4: flask-app + nginx topology
FACILITATOR.md             notes for presenting this live
scripts/                   the demo harness, not part of the migration itself
  demo.sh                  the scripted walkthrough
  setup.sh                 build-up: credentials + pre-built images
  teardown.sh              clean-up
  lib/                     demo-magic plus local helpers
```

Everything above `scripts/` is the migration. `scripts/` is the machinery that presents
it — you never need to read it to follow the story.

## Presenting this

If you're running this in front of an audience, [FACILITATOR.md](FACILITATOR.md) has the
pre-flight checklist, the beats of each stage, and what to do when a build misbehaves
on stage.

## Resources

- [Migrating to Python Chainguard Images](https://edu.chainguard.dev/chainguard/migration/migrating-python/)
- [Chainguard Libraries for Python](https://edu.chainguard.dev/chainguard/libraries/python/)
- [Blog: Securely Containerize a Python Application with Chainguard Images](https://dev.to/chainguard/securely-containerize-a-python-application-with-chainguard-images-bn8)
- [Video: How to containerize a Python application with a multi-stage build](https://www.youtube.com/watch?v=2D0JULd4E5A)
- Scripted with [demo-magic](https://github.com/paxtonhare/demo-magic)
