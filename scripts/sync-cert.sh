#!/bin/bash
# ---------------------------------------------------------------------------
# Hand Traefik's Let's Encrypt certificate to Stalwart.
#
# Traefik already obtains and renews a certificate for the mail hostname (it
# serves it on 443). Stalwart's mail ports otherwise present its built-in
# self-signed placeholder, which no client trusts. This copies Traefik's copy
# across and restarts Stalwart if anything actually changed.
#
# Safe to run on a schedule: it exits without touching anything when the
# certificate is unchanged, so it will only ever restart Stalwart after a
# genuine renewal (roughly every 60 days).
#
# Usage: sync-cert.sh [domain]
# ---------------------------------------------------------------------------
set -euo pipefail

DOMAIN="${1:-mail.graylining.com}"
CONFIG_DIR=/home/ubuntu/stalwart_mail_server/config
LIVE_CRT="$CONFIG_DIR/certs/$DOMAIN.crt"

log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%SZ')] $*"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- pull the cert out of Traefik's store -----------------------------------
docker exec traefik cat /letsencrypt/acme.json > "$tmp/acme.json"

python3 - "$tmp/acme.json" "$DOMAIN" "$tmp/cert.pem" "$tmp/key.pem" <<'PY'
import base64, json, sys

acme_path, domain, cert_out, key_out = sys.argv[1:5]

with open(acme_path) as fh:
    data = json.load(fh)

found = None
for resolver in data.values():
    if not isinstance(resolver, dict):
        continue
    for entry in resolver.get("Certificates") or []:
        if (entry.get("domain") or {}).get("main") == domain:
            found = entry

if found is None:
    sys.exit("error: no certificate for %s in acme.json" % domain)

with open(cert_out, "wb") as fh:
    fh.write(base64.b64decode(found["certificate"]))
with open(key_out, "wb") as fh:
    fh.write(base64.b64decode(found["key"]))
PY

# --- sanity: the key must actually match the certificate --------------------
# Compare public keys rather than RSA moduli, so this works for ECDSA too
# (Let's Encrypt issues ECDSA certs, where -modulus fails outright).
c_pub=$(openssl x509 -in "$tmp/cert.pem" -noout -pubkey 2>/dev/null | openssl md5)
k_pub=$(openssl pkey -in "$tmp/key.pem"  -pubout        2>/dev/null | openssl md5)
if [ -z "$c_pub" ] || [ "$c_pub" != "$k_pub" ]; then
    log "error: extracted key does not match certificate - aborting"
    exit 1
fi

# --- skip if nothing changed ------------------------------------------------
if cmp -s "$tmp/cert.pem" "$LIVE_CRT" 2>/dev/null; then
    log "certificate for $DOMAIN unchanged - nothing to do"
    exit 0
fi

# --- install into Stalwart's config dir -------------------------------------
# That directory is owned by uid 2000 (Stalwart) and is not writable by this
# user, so a throwaway root container does the copy and sets ownership.
docker run --rm \
    -v "$CONFIG_DIR":/dest \
    -v "$tmp":/src:ro \
    alpine sh -c '
        set -e
        mkdir -p /dest/certs
        cp /src/cert.pem /dest/certs/'"$DOMAIN"'.crt
        cp /src/key.pem  /dest/certs/'"$DOMAIN"'.key
        chown -R 2000:2000 /dest/certs
        chmod 755 /dest/certs
        chmod 644 /dest/certs/'"$DOMAIN"'.crt
        chmod 600 /dest/certs/'"$DOMAIN"'.key
    '

log "installed new certificate for $DOMAIN"
openssl x509 -in "$tmp/cert.pem" -noout -subject -issuer -enddate | sed 's/^/    /'

if [ "${NO_RESTART:-0}" = "1" ]; then
    log "NO_RESTART=1 - files installed, Stalwart not restarted"
    exit 0
fi

docker restart stalwart >/dev/null
log "stalwart restarted to load the new certificate"
