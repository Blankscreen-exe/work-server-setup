# flatnotes-enhanced

Live at **https://notes.graylining.com** - a self-hosted markdown note app.
Pinned to v1.14.2.

This is [BobWs/flatnotes-enhanced](https://github.com/BobWs/flatnotes-enhanced),
a third-party fork of the original flatnotes, published to Docker Hub as
`dockerbobw/flatnotes-enhanced`. Worth knowing: that is an individual's image
rather than an upstream-official one, and it holds notes and a mounted data
volume. Pin the version and read release notes before bumping it.

## Notes are plain files

Notes live as ordinary markdown in `data/`, which is the main reason to use
this app - no database to export from, no lock-in. **Back up `data/`** and you
have backed up everything. It also holds `data/.flatnotes/` with the search
index and a small SQLite database, which the app rebuilds if lost.

## Login

Password auth (`FLATNOTES_AUTH_TYPE=password`), credentials in `.env`.
The fork also supports `totp`, `oidc`, `read_only` and `none` - switch by
changing `FLATNOTES_AUTH_TYPE` and restarting.

`FLATNOTES_SECRET_KEY` signs session tokens. Changing it logs everyone out.
It does not encrypt anything, so losing it costs nothing but a re-login.

## Health checks

Do not add a `healthcheck:` block without first checking the command exists
inside the image. Traefik removes unhealthy containers from its configuration
entirely, so a health check that cannot run takes the service off the internet
while the symptom (Traefik's default certificate, no router) points nowhere
near the cause. The image already provides a working one.

## What is not in git

`.env` and `data/`.
