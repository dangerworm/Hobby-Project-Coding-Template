# /app

Put application code here.

Suggested conventions (optional):

- app/api: API, workers, jobs
- app/client: web UI
- app/flyway: database migrations (Flyway runner + SQL)
- app/infrastructure: scripts/manifests specific to this app
- app/terraform: IaC (if you keep it colocated with the app)

To scaffold a .NET solution (Core/Application/Web) plus a Vite React/TS client,
run:

```bash
./bootstrap.sh
```

The script sets up a default Vite dev proxy so client calls to `/api/*` are
proxied to `https://localhost:5001`.

After bootstrapping, run both in tandem:

```bash
cd app/api
dotnet watch run --project src/<YourName>.Web
```

```bash
cd app/client
npm run dev
```

In the client, prefer calling the api via relative URLs like `/api/health`.

If you use Docker Compose locally, start with app/docker-compose.yml.

Flyway migrations live in `app/flyway/sql`. Run them via Docker:

```bash
./app/flyway/flyway.sh info
./app/flyway/flyway.sh migrate
```

Or via compose:

```bash
cd app
docker compose -f docker-compose.flyway.yml run --rm flyway migrate
```

For environment variables, prefer `.env.example` files and keep `.env` local.
