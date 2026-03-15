# Traefik SSL / Let's Encrypt Troubleshooting

## Symptom: Browser shows "Not Secure" or certificate is `TRAEFIK DEFAULT CERT`

This means Traefik is serving its self-signed default certificate instead of a valid Let's Encrypt certificate.

### Step 1: Check if the cert resolver exists

```bash
docker inspect traefik | grep -A2 certificatesresolvers
```

Look for `--certificatesresolvers.letsencrypt.acme.*` entries in the container args. If missing, the Traefik container needs to be recreated with the updated config:

```bash
cd ~/work-server-setup/traefik && docker compose up -d --force-recreate
```

### Step 2: Check if a certificate was issued

```bash
docker exec traefik cat /letsencrypt/acme.json
```

- If `"Certificates"` array contains an entry for your domain, the cert was issued successfully.
- If `"Certificates"` is empty or missing your domain, the ACME challenge may have failed.

### Step 3: Check Traefik logs for ACME errors

```bash
docker logs traefik 2>&1 | grep -i "acme\|letsencrypt\|challenge\|cert"
```

Common errors:
- `nonexistent certificate resolver` - Traefik was started before the cert resolver config was added. Recreate the container.
- `acme: error: 403` - Let's Encrypt rate limit hit. Wait and retry.
- Challenge failures - Port 80 must be reachable from the internet.

### Step 4: Verify the HTTP challenge can reach your server

The Let's Encrypt HTTP-01 challenge requires port 80 to be publicly accessible.

```bash
curl -v http://<subdomain>.dev-in-trenches.com/.well-known/acme-challenge/test
```

- `404` response from Traefik = port 80 is reachable (good, Traefik handles the real challenge automatically)
- Connection timeout = port 80 is blocked by a firewall

### Step 5: Verify the service labels

Check that the service has the correct Traefik labels:

```bash
docker inspect <container_name> --format '{{json .Config.Labels}}' | python3 -m json.tool
```

Required labels for HTTPS:
```yaml
- "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
- "traefik.http.routers.<name>.entrypoints=websecure"
```

---

## Symptom: `PassThrough` is `False` in Traefik dashboard

This is **normal and expected**. It means Traefik terminates TLS and forwards plain HTTP to the backend service. If `PassThrough` were `True`, the backend would need to handle SSL itself.

---

## Symptom: HTTP does not redirect to HTTPS

Ensure the service has both an HTTP router with a redirect middleware:

```yaml
- "traefik.http.routers.<name>-http.rule=Host(`<domain>`)"
- "traefik.http.routers.<name>-http.entrypoints=web"
- "traefik.http.middlewares.<name>-https-redirect.redirectscheme.scheme=https"
- "traefik.http.routers.<name>-http.middlewares=<name>-https-redirect"
```
