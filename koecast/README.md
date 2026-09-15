# KoeCast - server notes

Live at **https://koecast.graylining.com**. The application lives in its own
repository (`graylining/KoeCast-nextjs`, branch `develop`), cloned at
`~/koecast`. **This folder is not the app** - it records what the server needs
that the app's repository does not contain.

## What lives only on the server

| File | Why it is not in the app repo |
|---|---|
| `~/koecast/.env` | Secrets. Every variable is explained in the repo's `.env.example`. |
| `~/koecast/compose.override.yml` | Adds the http->https redirect the repo's `compose.yml` lacks. A copy is here; it is hidden from the clone's git via `.git/info/exclude`. |

If `compose.override.yml` is ever lost, `http://koecast.graylining.com` returns
Traefik's 404 again instead of redirecting. Restore it from this folder.

## Depends on

- **`~/work-server-setup/minio`** (`shared-minio`, https://koecast-storage.graylining.com) -
  audio storage and the nightly database backups. It must be running first.
- **Resend**, sending as `noreply@koecastmail.graylining.com`.

## Build notes

The images are built on this server. The satellite's Dockerfile needs BuildKit,
so the `buildx` plugin is installed for the `ubuntu` user at
`~/.docker/cli-plugins/docker-buildx` (checksum-verified). Without it,
`docker compose build` fails with "the --mount option requires BuildKit".

## Deploying an update

```bash
cd ~/koecast && git pull
docker compose build
docker compose up -d      # runs migrate first, then satellite, then worker and web
```

🔴 Deploy the satellite **before** the worker, and roll back in the reverse order -
see `docs/deployment.md` in the app repo.

## Fixed at creation - never change

`DATA_VOLUME_PREFIX=koecast`, `POSTGRES_USER=koecast`, `POSTGRES_DB=koecast`.
A new prefix silently starts the app on a new, empty database.
