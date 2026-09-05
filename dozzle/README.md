# Dozzle

Live at **https://logs.graylining.com** — a web view of the logs of every container
on this server. Dozzle v10.9.2, pinned.

## Login

Dozzle's own login form (`DOZZLE_AUTH_PROVIDER=simple`), not Traefik BasicAuth.
It issues a session cookie lasting 48 hours, which avoids the browser
auth-prompt problems the Traefik dashboard suffers from.

Users live in `data/users.yml` as bcrypt hashes. To add or change one:

```bash
cd ~/work-server-setup/dozzle
docker run --rm amir20/dozzle:v10.9.2 generate <username> \
  --name "Display Name" --email you@example.com > data/users.yml
docker compose restart dozzle
```

Omit `--password` and it prompts, keeping the password out of shell history.
Note the command writes a whole file - to keep several users, edit `users.yml`
by hand and paste additional entries under `users:`.

## Security - read this before adding users

Dozzle shows the logs of **every container on the server**. Applications routinely
print sensitive material: connection strings, tokens, email addresses, and
occasionally credentials inside error traces. Anyone who can log in can read all
of it, so treat this login as equivalent to broad access to the machine.

The Docker socket is mounted **read-only**, which limits Dozzle to reading
container metadata and log streams rather than controlling Docker.

To narrow a user to specific containers, set the `filter` field in `users.yml`
(empty means full access).

## What is not in git

`data/` is gitignored, because it holds the user file. A rebuild from this repo
therefore needs the user regenerated with the command above - the container will
otherwise start with no accounts and nobody can log in.

## DNS

Needs an A record `logs.graylining.com` -> the server IP. Create it *before*
first start: Traefik requests a certificate as soon as the container appears, and
failed validations against a non-resolving hostname count towards Let's Encrypt
rate limits.
