# /app

Put application code here.

Suggested conventions (optional):

- app/backend: API, workers, jobs
- app/frontend: web UI
- app/infrastructure: scripts/manifests specific to this app
- app/terraform: IaC (if you keep it colocated with the app)

To scaffold a .NET solution (Core/Application/Web) plus a Vite React/TS
frontend, run:

```bash
./bootstrap-script.sh
```

The script sets up a default Vite dev proxy so frontend calls to `/api/*` are
proxied to `https://localhost:5001`.

If you use Docker Compose locally, start with app/docker-compose.yml.

For environment variables, prefer `.env.example` files and keep `.env` local.
