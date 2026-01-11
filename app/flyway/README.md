# Flyway

This folder contains a tiny, reusable Flyway runner (via Docker) plus a place
for SQL migrations.

## Quick start

1. Copy the example env file and set your DB connection:

- `app/flyway/.env.example` → `app/flyway/.env`

2. Run Flyway commands:

### Bash

```bash
./app/flyway/flyway.sh info
./app/flyway/flyway.sh migrate
```

### PowerShell

```powershell
./app/flyway/flyway.ps1 info
./app/flyway/flyway.ps1 migrate
```

## Migrations layout

- `sql/Versioned` for versioned migrations (e.g. `V1__init.sql`)
- `sql/Repeatable` for repeatable migrations (e.g. `R__views.sql`)

## Notes

- The runner mounts `sql/` into the container at `/flyway/sql`.
- Secrets should live in `app/flyway/.env` (do not commit it).

If your database runs in Docker/Compose, set `FLYWAY_DOCKER_NETWORK` to the
network name so Flyway can reach it.

## Compose runner (optional)

If you prefer Docker Compose, use `app/docker-compose.flyway.yml`:

```bash
cd app
docker compose -f docker-compose.flyway.yml run --rm flyway info
docker compose -f docker-compose.flyway.yml run --rm flyway migrate
```
