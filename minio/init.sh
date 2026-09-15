#!/bin/sh
# One-time (and safely re-runnable) setup for the shared MinIO service.
# Run from ~/work-server-setup/minio:
#   docker run --rm --network proxy --env-file .env \
#     -v "$PWD/init.sh:/init.sh:ro" --entrypoint sh \
#     quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z /init.sh
set -eu

mc alias set local http://shared-minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null

mc mb --ignore-existing local/koecast-audio
mc mb --ignore-existing local/koecast-backups

# KoeCast's app user: read/write its two buckets and nothing else on this server.
cat > /tmp/koecast-app.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": ["arn:aws:s3:::koecast-audio", "arn:aws:s3:::koecast-backups"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject",
                 "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
      "Resource": ["arn:aws:s3:::koecast-audio/*", "arn:aws:s3:::koecast-backups/*"]
    }
  ]
}
JSON
mc admin policy create local koecast-app /tmp/koecast-app.json
mc admin user add local "$KOECAST_S3_ACCESS_KEY" "$KOECAST_S3_SECRET_KEY"
# The mc image has no grep, so match with the shell. Match the policyName
# field, not the bare word: the user is also called koecast-app, so a plain
# match would always succeed and never attach.
INFO=$(mc admin user info local "$KOECAST_S3_ACCESS_KEY" --json)
case "$INFO" in
  *'"policyName":"koecast-app"'*) echo "policy koecast-app already attached" ;;
  *) mc admin policy attach local koecast-app --user "$KOECAST_S3_ACCESS_KEY" ;;
esac

# 🔴 Anonymous READ of finished audio only - the share pages play it from here.
# Deliberately NOT `mc anonymous set download`: that also grants anonymous
# ListBucket, which would let anyone enumerate every note's slug - and the slug
# is the secret part of a share link. raw/ uploads and the backups bucket stay
# private.
cat > /tmp/koecast-public.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::koecast-audio/audio/*"]
    }
  ]
}
JSON
mc anonymous set-json /tmp/koecast-public.json local/koecast-audio
mc anonymous get-json local/koecast-audio
echo "init complete"
