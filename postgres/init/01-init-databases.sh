#!/bin/bash
# Runs once on first boot (when the data volume is empty).
# Add a new SELECT line for each app database you need.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE keycloak' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
    SELECT 'CREATE DATABASE svix'     WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'svix')\gexec
    SELECT 'CREATE DATABASE focalboard' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'focalboard')\gexec
EOSQL
