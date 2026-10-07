#!/bin/bash
# Runs once on first boot (when the data volume is empty).
# One database and one login per app - an app can never read another's data.
#
# No app uses this server yet. IceHrm was removed on 2026-10-07; its block is
# kept below, commented, as the shape to copy.
#
# ⚠️ This only runs on an EMPTY data volume. Adding an app to a server that is
# already running means executing the same statements by hand:
#   docker exec -it mysql mysql -u root -p
set -e

# mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
#     CREATE DATABASE IF NOT EXISTS myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
#     CREATE USER IF NOT EXISTS 'myapp'@'%' IDENTIFIED BY '${MYAPP_DB_PASSWORD}';
#     GRANT ALL PRIVILEGES ON myapp.* TO 'myapp'@'%';
#     FLUSH PRIVILEGES;
# EOSQL
