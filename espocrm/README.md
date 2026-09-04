# EspoCRM

Live at **https://crm.graylining.com** — EspoCRM 10.0.7 behind Traefik.

## Containers

| Container | Role |
|---|---|
| `espocrm` | Web app (Apache), routed by Traefik on port 80 |
| `espocrm_daemon` | Background jobs — scheduled tasks, workflows, email checking |
| `espocrm_websocket` | Real-time updates, reached via the `/wss` path on port 8080 |
| `espocrm_db` | MariaDB 11. EspoCRM does not support PostgreSQL, so it cannot use the shared `postgres` service |

## Two gotchas that will bite on a rebuild

**1. Never mount `/var/www/html`.** EspoCRM 10 changed its volume model. Mounting the
whole tree (as the older docs and `volumes_from` examples do) triggers
`LEGACY INSTALLATION METHOD DETECTED`, silently skips the installer, and leaves the app
redirecting to a `/install/` directory that does not exist. Mount only these three:

    ./data           -> /var/www/html/data
    ./custom         -> /var/www/html/custom
    ./client-custom  -> /var/www/html/client/custom

**2. `ESPOCRM_ADMIN_USERNAME` must be exactly `admin` on a fresh install.**
The image entrypoint runs `create-admin-user "$ESPOCRM_ADMIN_USERNAME"` and then
`set-password admin` — with the username hardcoded. Any other value makes
`set-password` fail with `User 'admin' not found`; because the script runs under
`set -euo pipefail` with output sent to `/dev/null`, the installer aborts with no error
message before setting `isInstalled`, and the container restart-loops forever.

The live admin account here is **`hammad`** — it was created by the installer, then had
its password set and `isInstalled` flipped manually to finish the job.

## First-time install order

Starting everything at once is fine now, but on a fresh volume bring the app up alone
first so nothing else touches its directories mid-install:

    docker compose up -d espocrm-db     # wait until healthy
    docker compose up -d espocrm        # wait for data/config.php to appear
    docker compose up -d                # daemon + websocket

## Outgoing email

Sends through Stalwart as `contact@graylining.com`. `SMTP_PASSWORD` in `.env` is
deliberately blank — set that mailbox's password and run `docker compose up -d`.
Untested until then; verify the container can reach `mail.graylining.com:587`.

## What is not in git

`.env`, `db/`, `data/`, `custom/`, `client-custom/`. Back up `db/` and `data/` — that is
all the state.
