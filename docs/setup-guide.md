# Work Server Setup Guide

Self-hosted services stack running on Ubuntu with Docker Compose, using Traefik as the reverse proxy with automatic HTTPS via Let's Encrypt.

**Server IP:** `84.46.244.158`
**Base Domain:** `dev-in-trenches.com`

## Prerequisites

- Ubuntu server with Docker and Docker Compose installed
- A domain with DNS access to create A records
- Ports 80 and 443 open on the server firewall

## Architecture Overview

```
Internet
  │
  ├── :80  (HTTP → HTTPS redirect)
  ├── :443 (HTTPS)
  │
  └── Traefik (reverse proxy)
        │
        ├── bookstack.dev-in-trenches.com  → BookStack
        ├── n8n-internal.dev-in-trenches.com → N8N
        ├── taiga.dev-in-trenches.com      → Taiga
        ├── svix.dev-in-trenches.com       → Svix
        ├── /auth                          → Keycloak
        ├── /uptime                        → Uptime Kuma
        └── /health                        → Server Home
```

All services connect to a shared `proxy` Docker network for Traefik routing. Services with databases use an additional internal network for DB communication.

---

## 1. Initial Setup

### Create the shared Docker network

```bash
docker network create proxy
```

### Clone the repository

```bash
cd ~ && git clone <repo-url> work-server-setup
```

---

## 2. Traefik (Reverse Proxy)

Handles HTTPS termination, automatic Let's Encrypt certificates, and routes traffic to all services.

### DNS

No subdomain needed — Traefik listens directly on ports 80/443.

### Configuration

```bash
cd ~/work-server-setup/traefik
```

Edit `.env`:

| Variable | Description | How to generate |
|---|---|---|
| `ACME_EMAIL` | Email for Let's Encrypt notifications | Use your real email |
| `TRAEFIK_AUTH_HASH` | Dashboard login hash | `htpasswd -nbB admin YOUR_PASSWORD` (escape `$` as `$$`) |

### Deploy

```bash
docker compose up -d
```

### Verify

- Dashboard: `http://<server-ip>/dashboard/` (requires basic auth)
- Logs: `docker logs traefik --tail 20`

---

## 3. BookStack (Wiki / Documentation)

Self-hosted wiki platform for team documentation.

### DNS

Create an A record: `bookstack` → `<server-ip>`

### Configuration

```bash
cd ~/work-server-setup/bookstack
cp .env.example .env  # if starting fresh, otherwise edit existing .env
```

Edit `.env`:

| Variable | Description | How to generate |
|---|---|---|
| `BOOKSTACK_DOMAIN` | Subdomain for BookStack | e.g. `bookstack.dev-in-trenches.com` |
| `APP_URL` | Full application URL | `https://bookstack.dev-in-trenches.com` |
| `APP_KEY` | Laravel encryption key | `docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey` |
| `DB_PASSWORD` | Database password | Choose a strong password |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password | Choose a strong password |
| `MYSQL_PASSWORD` | Must match `DB_PASSWORD` | Same as `DB_PASSWORD` |

### Deploy

```bash
docker compose up -d
```

### Verify

- URL: `https://bookstack.dev-in-trenches.com`
- Default login: `admin@admin.com` / `password`
- **Change the default password immediately after first login**

---

## 4. N8N (Workflow Automation)

Low-code workflow automation platform with webhook and integration support.

### DNS

Create an A record: `n8n-internal` → `<server-ip>`

### Configuration

```bash
cd ~/work-server-setup/n8n
```

Edit `.env`:

| Variable | Description |
|---|---|
| `N8N_DOMAIN` | Subdomain for N8N (e.g. `n8n-internal.dev-in-trenches.com`) |
| `N8N_HOST` | Same as `N8N_DOMAIN` |
| `WEBHOOK_URL` | `https://<N8N_DOMAIN>/` |
| `GENERIC_TIMEZONE` | Server timezone (e.g. `UTC`) |

### Deploy

```bash
docker compose up -d
```

### Verify

- URL: `https://n8n-internal.dev-in-trenches.com`
- First visit will prompt you to create an admin account

---

## 5. Taiga (Project Management)

Agile project management platform with sprints, user stories, and kanban boards.

### DNS

Create an A record: `taiga` → `<server-ip>`

### Configuration

```bash
cd ~/work-server-setup/taiga
cp .env.example .env
```

Edit `.env`:

| Variable | Description | How to generate |
|---|---|---|
| `TAIGA_DOMAIN` | Subdomain for Taiga | e.g. `taiga.dev-in-trenches.com` |
| `TAIGA_SCHEME` | `https` | |
| `WEBSOCKETS_SCHEME` | `wss` | |
| `SECRET_KEY` | Django secret key | `openssl rand -hex 32` |
| `POSTGRES_PASSWORD` | Database password | Choose a strong password |
| `RABBITMQ_PASS` | RabbitMQ password | Choose a strong password |
| `RABBITMQ_ERLANG_COOKIE` | RabbitMQ cookie | `openssl rand -hex 20` |

Email settings (optional — set `EMAIL_BACKEND=console` to disable):

| Variable | Description |
|---|---|
| `EMAIL_BACKEND` | `smtp` for real email, `console` for logging only |
| `EMAIL_HOST` | SMTP server hostname |
| `EMAIL_PORT` | SMTP port (typically `587`) |
| `EMAIL_HOST_USER` | SMTP username |
| `EMAIL_HOST_PASSWORD` | SMTP password |
| `EMAIL_DEFAULT_FROM` | From address |

### Deploy

```bash
docker compose up -d
```

### Verify

- URL: `https://taiga.dev-in-trenches.com`
- Default login: `admin` / `123123`
- **Change the default password immediately after first login**

---

## 6. Svix (Webhook Infrastructure)

Central webhook gateway with automatic retries, logging, and delivery monitoring.

### DNS

Create an A record for your chosen subdomain → `<server-ip>`

### Configuration

```bash
cd ~/work-server-setup/svix
cp .env.example .env
```

Edit `.env`:

| Variable | Description | How to generate |
|---|---|---|
| `SVIX_DOMAIN` | Subdomain for Svix | e.g. `svix.dev-in-trenches.com` |
| `SVIX_JWT_SECRET` | API authentication secret | `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | Database password | Choose a strong password |

### Deploy

```bash
docker compose up -d
```

### Verify

- Health check: `curl https://<SVIX_DOMAIN>/api/v1/health/`
- API docs: `https://<SVIX_DOMAIN>/docs`

---

## 7. Keycloak (Identity & Access Management)

OAuth2/OIDC identity provider for centralized authentication and SSO.

### Configuration

```bash
cd ~/work-server-setup/key-cloak
```

Edit `.env`:

| Variable | Description |
|---|---|
| `KEYCLOAK_ADMIN` | Admin console username |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin console password |
| `KC_DB_PASSWORD` | PostgreSQL password |
| `POSTGRES_PASSWORD` | Must match `KC_DB_PASSWORD` |

### Deploy

```bash
docker compose up -d
```

### Verify

- URL: `http://<server-ip>/auth`
- Login with the admin credentials from your `.env`

---

## 8. Uptime Kuma (Status Monitoring)

Lightweight uptime monitoring with status pages and notifications.

### Configuration

```bash
cd ~/work-server-setup/uptime-kuma
```

Edit `.env`:

| Variable | Description |
|---|---|
| `UPTIME_KUMA_BASE_PATH` | Base path (default: `/uptime`) |

### Deploy

```bash
docker compose up -d
```

### Verify

- URL: `http://<server-ip>/uptime`
- First visit will prompt you to create an admin account

---

## Generating Secrets Reference

| Secret | Command |
|---|---|
| General hex secret | `openssl rand -hex 32` |
| Base64 secret | `openssl rand -base64 32` |
| BookStack APP_KEY | `docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey` |
| Traefik auth hash | `htpasswd -nbB admin YOUR_PASSWORD` |
| Strong password | `openssl rand -base64 16` |

---

## DNS Records Summary

| Type | Host | Value |
|---|---|---|
| A | `@` | `<server-ip>` |
| A | `bookstack` | `<server-ip>` |
| A | `n8n-internal` | `<server-ip>` |
| A | `taiga` | `<server-ip>` |
| A | `svix` (or your choice) | `<server-ip>` |

---

## Deployment Order

For a fresh setup, deploy in this order:

1. **Traefik** — must be first (other services depend on the `proxy` network and HTTPS)
2. **Keycloak** — identity provider (other services can integrate with it)
3. **BookStack** — documentation
4. **Taiga** — project management
5. **N8N** — workflow automation
6. **Svix** — webhook infrastructure
7. **Uptime Kuma** — monitoring (set up last so you can add monitors for all other services)

---

## Updating Services

To update any service to the latest image:

```bash
cd ~/work-server-setup/<service>
docker compose pull
docker compose up -d
```

## Stopping Services

```bash
cd ~/work-server-setup/<service>
docker compose down
```

To also remove volumes (destroys data):

```bash
docker compose down -v
```
