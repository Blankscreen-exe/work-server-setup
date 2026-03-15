# BookStack Troubleshooting

## Symptom: "The application key is missing, halting init!"

BookStack requires an `APP_KEY` environment variable to be set before it can start.

### Generate a new APP_KEY

```bash
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey
```

This outputs a key in the format `base64:xxxxxxxx`. Set it in your `.env` file:

```
APP_KEY=base64:<generated-key-here>
```

Then restart the container:

```bash
docker compose up -d --force-recreate
```

### Notes

- Do **not** change `APP_KEY` after initial setup — it is used to encrypt data in the database. Changing it will make existing encrypted data unreadable.
- The `openssl rand -base64 32` approach also works if you prefix the output with `base64:`.
