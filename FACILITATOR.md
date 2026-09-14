# Facilitating this demo

Notes for presenting the Flask → Chainguard migration live. For what the demo *is*, see
the [README](README.md); this file is about running it in front of people.

The single most important thing on this page: **the credential token lives for 8 hours.**
Run `./scripts/setup.sh` the same day you present, ideally within a couple of hours of going on.

## Pre-flight

Do all of this before the audience is in the room.

- [ ] `chainctl auth login` — confirm you're authenticated, and know which organization has
      Chainguard Libraries for Python enabled.
- [ ] **`./scripts/setup.sh`** (same day — 8-hour token). Mints the token, writes `.netrc`, and
      pre-builds all three stage images plus the Compose topology, so nothing builds cold
      on stage.
- [ ] Ports **8000** and **80** free. `lsof -i :8000 -i :80` — a stray container from a
      previous run is the usual culprit; `./scripts/teardown.sh` clears it (then re-run `setup.sh`).
- [ ] `pv` installed (`brew install pv`) if you want the typing effect. If not, present
      with `-d`.
- [ ] Rehearse once end to end. `./scripts/demo.sh --skip-comments` gives you the floor on timing;
      the real run is longer because you're talking.
- [ ] Note the actual image sizes from your rehearsal. You'll quote them in stage 2, and
      they shift with upstream image versions — don't rely on a number from a previous talk.
- [ ] Terminal set up: large font, wide window. The section banners draw a box around the
      title and the narration lines are written to fit a wide terminal; a narrow window
      wraps both badly.

## How the script drives

Advancing is **two ENTER presses per command**, and that rhythm is the point:

1. First press — the command types itself out, but does **not** run.
2. Second press — it runs.

That gap is where you talk. The command is on screen, the audience can read it, and
nothing has happened yet. Use it, especially for the `docker build` lines.

The rest of the mechanics:

- **Section banners** pause before drawing, so you can land your last point before a new
  heading appears.
- **Narration lines** (grey) print instantly, no keypress. They're written to be said out
  loud in your own words, not read verbatim.
- **Plumbing runs automatically** — `docker rm -f`, `docker run -d`, and the readiness
  waits fire without pausing, so you're not pressing ENTER through housekeeping.

About **41 ENTER presses** from start to finish.

Flags worth knowing on stage:

| Flag | Use |
|---|---|
| `-d` | No simulated typing. Use it if `pv` is missing, or if typing feels slow in the room. |
| `--skip-comments` | Narration off. Rehearsal and timing, not live. |
| `-w5` | Auto-advance every 5s. Unattended loops, not live. |
| `-n` | No pauses at all — runs the whole thing top to bottom. Good for a smoke test right before you go on. **Never present with this.** |

## The arc

Six sections. The through-line to keep returning to: *the app never changes.*

**1. The app.** `requirements.txt` (Flask, gunicorn) and `app.py`. Establish that these
two files are frozen from here on — say it explicitly, because it's what makes the rest
land. Everything after this is base image and dependency source.

**2. Stage 1 — plain Python.** `FROM python`, `pip install`, `CMD gunicorn`. Deliberately
ordinary; this is the "before" everyone recognises from their own repos. Don't editorialise
yet. Get it running, `curl` it, and name the response as the baseline.

**3. Stage 2 — Chainguard Containers.** Shown as a **diff against stage 1**, not a new
file. Two things changed: the base image, and the build became multi-stage — dependencies
install in `-dev`, only the venv crosses into a runtime image with no shell and no package
manager. Then the same `curl` against the same URL returns the same response, followed by
the size comparison.

This is the biggest structural change in the demo and the best place to slow down. If you
only have time for part of the story, make it this part.

**4. Stage 3 — Chainguard Libraries.** Again a diff, this time against stage 2. One
`pip install` gained an `--index-url`. No code change, no `requirements.txt` change — only
where packages are resolved from. The build mounts `.netrc` as a BuildKit secret; worth a
sentence, since "how do credentials get in there" is a question you'll otherwise get in
Q&A.

**5. Stage 4 — behind nginx.** `compose.yml` builds `flask-app` from
`Dockerfile.libraries` — the stage just landed on. Then `nginx/Dockerfile` goes up, and
it's two lines: `FROM cgr.dev/chainguard/nginx:latest` and the config copied in. Worth
pausing on, because it widens the story — the migration wasn't a Python trick, it's the
same one-line base image swap for the proxy. Then the same app on port 80 through
nginx, and the closing point that every container in the topology is now a Chainguard
image.

If someone asks how the proxy compares to `docker.io/nginx`, you can pull it and
diff the sizes — but do that in Q&A, not inline. It's a cold Docker Hub pull in the
middle of your last beat.

**6. Demo complete.** Land the through-line: the app was never touched. What changed was
where the bits came from.

A note on what `curl` shows: the app returns raw HTML (a heading and a row of octopuses).
That reads fine in a terminal, but if your audience would rather see a page, have
`http://localhost:8000` open in a browser to refresh between stages — same response, more
obviously "a working web app."

## When something goes wrong

**A `curl` prints nothing.** Just run it again — `curl -s http://localhost:8000/`. The
readiness check waits for a non-empty body specifically to prevent this, but if the
container is slow to bind you can land ahead of it. Not fatal, don't restart the demo.

**`!! <url> never came up after 30s`** on stderr means the readiness wait gave up and the
next command will likely show nothing. Check the container in a second terminal:
`docker ps` and `docker logs pymigrate`.

**The Libraries build fails with a 401/403.** The token has expired — this is the 8-hour
TTL biting. You don't need the full `setup.sh`; just re-mint the credentials file:

```bash
CREDS=$(chainctl auth pull-token --repository=python --parent="$CGR_ORG" --ttl=8h -o json)
printf 'machine libraries.cgr.dev\nlogin %s\npassword %s\n' \
  "$(jq -r .identity_id <<<"$CREDS")" "$(jq -r .token <<<"$CREDS")" > .netrc
chmod 0600 .netrc
```

Then re-run the build. Keep that snippet somewhere you can paste it from.

**A warm build cache hides an expired token.** This is the subtle one. The
`pip install` layer is cached like any other, so the Libraries build will happily
succeed off an expired token and never contact `libraries.cgr.dev` at all — a clean
rehearsal does *not* prove your credentials are live. Anything that invalidates that
layer mid-demo (an edited `requirements.txt`, a pruned cache, a different machine) is
where it surfaces. Re-running `setup.sh` is what actually proves the token, because it
mints a fresh one.

**`port is already allocated`.** Something from an earlier run survived:
`docker rm -f pymigrate` and `docker compose down`, then retry.

**A build is unexpectedly slow.** It's not hitting the cache `setup.sh` warmed — usually
because `setup.sh` ran before a change to `app/` or a Dockerfile. Talk over it; it will
finish. This is the reason for the pre-build step.

**`demo.sh` exits immediately saying `Missing .netrc`.** `setup.sh` hasn't run, or
`teardown.sh` ran after it and deleted the file.

## Afterwards

```bash
./scripts/teardown.sh
```

Stops the containers, removes the three `pymigrate` images, and **deletes `.netrc`**.
Everything is local — nothing was pushed to a registry — so there's no remote state to
clean up.

If you're presenting again later, remember teardown removed both the images and the
credentials: run `./scripts/setup.sh` again, and mind the 8-hour window.
