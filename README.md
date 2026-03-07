# work-server-setup



## Services

### Traefik Setup

This folder contains a **Traefik v3.6 Docker setup** configured for use on a server without a domain. It exposes the dashboard behind **Basic Authentication** and handles IP-based routing.

### Features

* Traefik v3.6 as reverse proxy
* Dashboard available at `/dashboard/`
* Protected with **BasicAuth**
* IP-based routing (no domain required)
* Docker provider enabled, with containers requiring explicit labels
* Automatic dashboard access via IP only

### Usage

1. **Install prerequisites** (if not already installed):

```bash
sudo apt update
sudo apt install docker docker-compose apache2-utils -y
```

2. **Set your dashboard password**:

```bash
htpasswd -nbB admin YOUR_PASSWORD
```

> Example output:
> `admin:$2y$05$FanjsGc5VI45wycthT/Aqef8Q3QRc.Kzu6JH8t58N1NRCJ3UmPrim`

3. **Update the Docker Compose file**:

* Copy the hash from the previous step into the label `traefik.http.middlewares.traefik-auth.basicauth.users`.
* Make sure the hash is **single-quoted** and every `$` in the hash is doubled (`$$`) to prevent Compose variable substitution:

```yaml
- 'traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$2y$$05$$FanjsGc5VI45wycthT/Aqef8Q3QRc.Kzu6JH8t58N1NRCJ3UmPrim'
```

4. **Start Traefik**:

```bash
docker compose up -d
```

5. **Access the dashboard**:

```
http://YOUR_SERVER_IP/dashboard/
```

* Username: `admin`
* Password: the plaintext password you used when generating the hash

> ⚠️ Always include the trailing slash `/` in the URL. Without it, the dashboard may show a 404.

6. **Optional: Redirect `/dashboard` to `/dashboard/`**

To allow access without a trailing slash, a redirect middleware can be added:

```yaml
- "traefik.http.middlewares.dashboard-redirect.redirectregex.regex=^/dashboard$"
- "traefik.http.middlewares.dashboard-redirect.redirectregex.replacement=/dashboard/"
- "traefik.http.routers.traefik.middlewares=traefik-auth,dashboard-redirect"
```

### Labels & Routing

* Only Docker containers with `traefik.enable=true` and appropriate routing labels are exposed.
* Dashboard router rule: `PathPrefix(`/dashboard`) || PathPrefix(`/api`)`
* Middleware: `traefik-auth` (BasicAuth)

### Security Notes

* **Do not use `--api.insecure=true`** in production.
* Dashboard is password-protected, but consider restricting access by IP for additional security.
* If you add more services (Uptime Kuma, Portainer, etc.), reuse the same BasicAuth middleware.

### Networks

* External Docker network: `proxy`
* Traefik connects only to containers in the `proxy` network.
