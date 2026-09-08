# Migrating a Flask Application to Chainguard -- demo

A scripted, live-presentable version of this repo's migration story: one Flask app,
one `requirements.txt`, walked through three base images -- plain Python, Chainguard
Containers, Chainguard Containers + Chainguard Libraries -- then wired up behind
nginx with Compose. Scripted with [demo-magic](https://github.com/paxtonhare/demo-magic).

- BEFORE the talk: run `./setup.sh` (builds all three stage images ahead of time)
- ON stage: run `./demo.sh` (press ENTER to advance; `-d` disables the typing effect;
  `--skip-comments` drops the narration lines and runs only the actual commands)
- AFTER: run `./teardown.sh`

Every command shown is the real command being run -- no hidden wrappers.

Requires: `docker` (with `buildx` and `compose`), `curl`, `pv` (for the typing effect).

## Layout

```
app/
  app.py             one Flask app, shared by every stage
  requirements.txt   one requirements.txt, shared by every stage
docker/
  Dockerfile.v0          plain python, straight from PyPI
  Dockerfile.containers  Chainguard Containers
  Dockerfile.libraries   Chainguard Containers + Chainguard Libraries
nginx/                nginx in front of the fully-migrated build
compose.yml           Flask (Dockerfile.libraries) + nginx topology
```

## Resources

- [Migrating to Python Chainguard Images](https://edu.chainguard.dev/chainguard/migration/migrating-python/)
- [Blog Post: Securely Containerize a Python Application with Chainguard Images](https://dev.to/chainguard/securely-containerize-a-python-application-with-chainguard-images-bn8)
- [Video: How to containerize a Python application with a multi-stage build using Chainguard Images](https://www.youtube.com/watch?v=2D0JULd4E5A)
