#!/bin/bash
# Runs once on first boot (when the data volume is empty).
# Add a new SELECT line for each app database you need.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE keycloak' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
    SELECT 'CREATE DATABASE svix'     WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'svix')\gexec
    SELECT 'CREATE DATABASE focalboard' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'focalboard')\gexec
EOSQL

# ⚠️ The attendance tool (../attendance) owns its database through its own
# login, so one app cannot read another's rows. That cannot be created here,
# because this script has no access to its password - it lives in
# ../attendance/.env. On a fresh data volume, run these by hand afterwards and
# use the DATABASE_URL password from that file:
#
#   docker exec -it postgres psql -U "$POSTGRES_USER" -d postgres
#     CREATE ROLE attendance LOGIN PASSWORD '<from ../attendance/.env>';
#     CREATE DATABASE attendance OWNER attendance;
