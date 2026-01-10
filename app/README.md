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
./bootstrap.sh
```

The script sets up a default Vite dev proxy so frontend calls to `/api/*` are
proxied to `https://localhost:5001`.

After bootstrapping, run both in tandem:

```bash
cd app/backend
dotnet watch run --project src/<YourName>.Web
```

```bash
cd app/frontend
npm run dev
```

In the frontend, prefer calling the backend via relative URLs like
`/api/health`.

If you use Docker Compose locally, start with app/docker-compose.yml.

For environment variables, prefer `.env.example` files and keep `.env` local.
