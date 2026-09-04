# Stalwart Mail TLS Certificates

## Symptom: mail clients warn about an untrusted certificate

Mail apps show a certificate warning when connecting over IMAP/SMTP, and applications
that verify certificates strictly fail outright. EspoCRM, for example, reports only a
generic `Email sending error` with no detail — the connection dies during the TLS
handshake, before any mail is attempted.

Check what Stalwart is actually presenting:

```bash
openssl s_client -starttls smtp -connect mail.graylining.com:587 </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer
```

If you see this, Stalwart is serving its built-in placeholder:

```
subject=CN = rcgen self signed cert
issuer=CN = rcgen self signed cert
```

A healthy result names the domain and Let's Encrypt as issuer.

## Why it happens

**Stalwart does not share Traefik's certificates.** Traefik terminates HTTPS on port 443
and holds a valid Let's Encrypt certificate for `mail.graylining.com` — but that only
covers the web admin UI. Stalwart's mail ports (25, 465, 587, 993) do their own TLS and
fall back to a self-signed placeholder until explicitly given a certificate.

Stalwart can't obtain one itself the easy way either: the usual Let's Encrypt validation
methods need port 80 (HTTP-01) or port 443 (TLS-ALPN-01), and Traefik owns both. DNS
validation would work but means giving Stalwart API access to the DNS provider.

So instead we reuse the certificate Traefik already maintains.

## How it works here

```
Let's Encrypt
    |
    v
Traefik  (obtains + auto-renews, stores in /letsencrypt/acme.json)
    |
    |  sync-cert.sh  (nightly cron, no-op unless the cert actually changed)
    v
/home/ubuntu/stalwart_mail_server/config/certs/     <- on the host
    = /etc/stalwart/certs/                          <- inside the container
    |
    v
Stalwart  (Certificate object referencing those files)
```

| Location | Path |
|---|---|
| Host | `/home/ubuntu/stalwart_mail_server/config/certs/mail.graylining.com.{crt,key}` |
| Inside container | `/etc/stalwart/certs/mail.graylining.com.{crt,key}` |
| Sync script | `/home/ubuntu/stalwart_mail_server/sync-cert.sh` (copy in this repo: `scripts/sync-cert.sh`) |
| Cron log | `/home/ubuntu/stalwart_mail_server/sync-cert.log` |

Cron entry (user `ubuntu`):

```
17 3 * * * /home/ubuntu/stalwart_mail_server/sync-cert.sh mail.graylining.com >> /home/ubuntu/stalwart_mail_server/sync-cert.log 2>&1
```

The script compares against the live certificate and exits doing nothing when unchanged,
so it only copies files and restarts Stalwart after a real renewal — roughly every 60 days.

## One-time Stalwart configuration

This must be done in the **admin web UI**. Stalwart v0.16 removed its REST API entirely —
all management is now JMAP against a single `/jmap` endpoint, so there is no simple
scripted equivalent.

1. Log into `https://mail.graylining.com/` as an admin
2. **Settings → TLS → Certificates**, create a certificate
3. Set both fields to type **File**, pointing at the **container** paths:
   - Certificate: `/etc/stalwart/certs/mail.graylining.com.crt`
   - Private key: `/etc/stalwart/certs/mail.graylining.com.key`
4. Save. Stalwart parses the file and displays the expiry — if it shows the right date,
   it genuinely read the file rather than just storing a string.
5. Set it as the **default certificate**
6. `docker restart stalwart`

## Verifying

```bash
# all three should name mail.graylining.com, issued by Let's Encrypt
for p in 587 465 993; do
  if [ "$p" = "587" ]; then
    timeout 20 openssl s_client -starttls smtp -connect mail.graylining.com:$p </dev/null 2>/dev/null
  else
    timeout 20 openssl s_client -connect mail.graylining.com:$p </dev/null 2>/dev/null
  fi | openssl x509 -noout -subject -issuer -enddate
done

# the chain must actually validate - this is what strict clients require
openssl s_client -starttls smtp -connect mail.graylining.com:587 </dev/null 2>&1 \
  | grep 'Verify return code'
# want: Verify return code: 0 (ok)
```

## Important dependency

**Stalwart's certificate now depends on Traefik continuing to renew it.** Traefik keeps
that certificate alive because it routes `mail.graylining.com` on port 443. If that
router were ever removed, renewals would stop and Stalwart's certificate would quietly
expire about 90 days later, with the only warning being the nightly log.

If you ever retire the mail web route from Traefik, either keep a dummy router for the
hostname or move Stalwart to its own DNS-validated certificate.

## Gotchas

- **Container paths, not host paths.** Stalwart cannot see `/home/ubuntu/...`. Using the
  host path in the UI silently gives you no certificate.
- **The config directory is owned by uid 2000**, not `ubuntu`, so the user cannot write
  into it directly. The sync script uses a throwaway root container to place the files
  and set ownership. This also means `sudo` is not required for the cron job.
- **Let's Encrypt issues ECDSA certificates.** Verifying that a key matches its
  certificate with `openssl x509 -modulus` fails on these — it is RSA-only. Compare
  public keys instead (`openssl x509 -pubkey` against `openssl pkey -pubout`), which the
  script does.
- Fixing this benefits **every** mail client, not just the application that surfaced it.
