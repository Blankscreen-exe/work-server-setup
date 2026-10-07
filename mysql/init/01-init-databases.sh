#!/bin/bash
# Runs once on first boot (when the data volume is empty).
# One database and one login per app - an app can never read another's data.
set -e

mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS icehrm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'icehrm'@'%' IDENTIFIED BY '${ICEHRM_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON icehrm.* TO 'icehrm'@'%';
    FLUSH PRIVILEGES;
EOSQL
