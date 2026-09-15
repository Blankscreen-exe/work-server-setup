# MinIO - shared S3-compatible storage

Served at **https://koecast-storage.graylining.com** (S3 API only). First user: KoeCast.

## ⚠️ This is an archived, unmaintained image

MinIO's community edition was archived in April 2026, and its Docker Hub images
were removed on 2026-09-11. `docker-compose.yml` pins the last build still
published on quay.io, `RELEASE.2025-09-07T16-13-09Z.hotfix.7aa24e772`.

**It will never receive another security fix**, and it is the service strangers'
uploads go straight into. This was a deliberate choice over maintained
alternatives (Garage, SeaweedFS). Revisit it before relying on this for anything
sensitive, and never float the tag to `latest`.

## Setup

Container and service are `shared-minio`, and Traefik routers are `storage` / `storage-http`.
The job tracker runs its own MinIO on the same `proxy` network, so a generic
`minio` name would share its DNS alias: a request could land on the wrong server.


```bash
docker compose up -d
docker run --rm --network proxy --env-file .env \
  -v "$PWD/init.sh:/init.sh:ro" --entrypoint sh \
  quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z /init.sh
```

`init.sh` is safe to re-run. It creates the buckets, a least-privilege user per
app, and the public-read rule.

## Access model

| Who | Can |
|---|---|
| `minio-admin` (root) | everything - used only by `init.sh` |
| `koecast-app` | read/write `koecast-audio` and `koecast-backups`, nothing else |
| anyone (anonymous) | `GetObject` on `koecast-audio/audio/*` only |

🔴 **Anonymous access is read-one-file, never list.** `mc anonymous set download`
would also grant `ListBucket`, letting anyone enumerate every note's slug - and
the slug is the secret part of a share link. `init.sh` sets the policy by hand
for exactly this reason. `raw/` uploads and the backups bucket stay private.

**CORS** is limited to the origins in `CORS_ALLOW_ORIGIN`. The default would be
`*`. Browsers upload straight to this service, so every app that does so has to
be added there.

**The web console (port 9001) is not routed through Traefik.** To browse files,
tunnel to it over SSH instead of exposing it.

## Backups

KoeCast's nightly database dump lands in `koecast-backups` **on this same
server**. That protects against a bad migration or an accidental deletion. It
does **not** protect against losing this disk. Nothing backs up `data/` off the
server yet.

## Health check

`mc ready local`, verified to exist and exit 0 in this exact image in an
isolated container before it was added. If the image tag ever changes,
re-verify it first. Traefik drops unhealthy containers from its configuration
entirely, so a health check whose command is missing takes storage offline, and
the symptom points nowhere near the cause.
