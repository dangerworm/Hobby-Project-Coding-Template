#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

DOTNET_TFM="net9.0"

fail() {
  printf "\nERROR: %s\n" "$1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

trim() {
  local s="$1"
  # shellcheck disable=SC2001
  s="$(echo "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "$s"
}

to_pascal_case() {
  # Convert arbitrary input into a safe .NET-ish PascalCase base name.
  # - Splits on non-alphanumeric
  # - Capitalizes words
  # - Removes all separators
  local input="$1"
  input="$(echo "$input" | tr '_' ' ')"
  echo "$input" \
    | tr -cs '[:alnum:]' ' ' \
    | awk '{
      for (i = 1; i <= NF; i++) {
        w = $i
        first = substr(w, 1, 1)
        rest = substr(w, 2)
        printf toupper(first) rest
      }
      printf "\n"
    }'
}

to_kebab_case() {
  # Convert arbitrary input into a safe npm package-ish name.
  local input="$1"
  input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
  # Replace any run of non-alphanumerics with '-'
  # shellcheck disable=SC2001
  input="$(echo "$input" | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+//; s/-+$//')"
  echo "$input"
}

contains_alnum() {
  local input="$1"
  [[ "$input" =~ [[:alnum:]] ]]
}

ensure_dotnet_base_name() {
  # Ensure a reasonable .NET identifier-like base name.
  # If the computed name doesn't start with a letter, prefix with "App".
  local name="$1"
  [[ -n "$name" ]] || return 1
  if [[ ! "$name" =~ ^[A-Za-z] ]]; then
    name="App${name}"
  fi
  echo "$name"
}

ensure_vite_package_name() {
  # Ensure a reasonable npm package-ish name.
  # If the computed name doesn't start with a letter, prefix with "app-".
  local name="$1"
  [[ -n "$name" ]] || return 1
  if [[ ! "$name" =~ ^[a-z] ]]; then
    name="app-${name}"
  fi
  echo "$name"
}

confirm() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N]: " reply || true
  reply="$(echo "${reply:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$reply" == "y" || "$reply" == "yes" ]]
}

dir_is_effectively_empty() {
  # Treat a directory as "empty" if it contains no files
  # besides an optional .env.example.
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  local count
  count=$(find "$dir" -mindepth 1 -maxdepth 1 -not -name '.env.example' | wc -l | tr -d '[:space:]')
  [[ "$count" == "0" ]]
}

main() {
  need_cmd dotnet
  need_cmd npm
  need_cmd node
  need_cmd awk
  need_cmd sed
  need_cmd find

  printf "\nBootstrap: .NET (Core/Application/Web) + Vite React/TS\n"
  printf "Location: %s\n\n" "$SCRIPT_DIR"

  local raw_name
  read -r -p "Project name (e.g. 'My Cool App'): " raw_name
  raw_name="$(trim "${raw_name:-}")"
  [[ -n "$raw_name" ]] || fail "Project name is required."
  contains_alnum "$raw_name" || fail "Project name must contain at least one letter (A-Z) or digit (0-9)."

  local dotnet_base
  local vite_name
  local dotnet_candidate
  local vite_candidate
  dotnet_candidate="$(to_pascal_case "$raw_name")"
  vite_candidate="$(to_kebab_case "$raw_name")"
  [[ -n "$dotnet_candidate" ]] || fail "Could not derive a usable .NET name from '$raw_name'."
  [[ -n "$vite_candidate" ]] || fail "Could not derive a usable Vite name from '$raw_name'."
  dotnet_base="$(ensure_dotnet_base_name "$dotnet_candidate")" || fail "Could not derive a usable .NET name from '$raw_name'."
  vite_name="$(ensure_vite_package_name "$vite_candidate")" || fail "Could not derive a usable Vite name from '$raw_name'."

  [[ -n "$dotnet_base" ]] || fail "Project name resulted in an empty .NET name; try a different name."
  [[ -n "$vite_name" ]] || fail "Project name resulted in an empty Vite name; try a different name."

  printf "\nDerived names:\n"
  printf -- "- .NET base: %s\n" "$dotnet_base"
  printf -- "- Vite name: %s\n\n" "$vite_name"

  if ! confirm "Proceed and scaffold into app/backend and app/frontend?"; then
    printf "Aborted.\n"
    exit 0
  fi

  mkdir -p "$BACKEND_DIR"
  if ! dir_is_effectively_empty "$BACKEND_DIR"; then
    fail "Backend directory is not empty: $BACKEND_DIR (refusing to overwrite)."
  fi

  if [[ -e "$BACKEND_DIR/${dotnet_base}.sln" ]]; then
    fail "Backend solution already exists: $BACKEND_DIR/${dotnet_base}.sln"
  fi

  if [[ -e "$FRONTEND_DIR" ]]; then
    if ! dir_is_effectively_empty "$FRONTEND_DIR"; then
      fail "Frontend directory is not empty: $FRONTEND_DIR (refusing to overwrite)."
    fi
  fi

  printf "\n==> Scaffolding backend (.NET)\n"
  (
    cd "$BACKEND_DIR"
    dotnet new sln -n "$dotnet_base"
    mkdir -p src
    cd src

    dotnet new classlib -n "${dotnet_base}.Core" -o "${dotnet_base}.Core" -f "$DOTNET_TFM"
    dotnet new classlib -n "${dotnet_base}.Application" -o "${dotnet_base}.Application" -f "$DOTNET_TFM"
    dotnet new webapi -n "${dotnet_base}.Web" -o "${dotnet_base}.Web" -f "$DOTNET_TFM"

    dotnet sln "../${dotnet_base}.sln" add \
      "${dotnet_base}.Core/${dotnet_base}.Core.csproj" \
      "${dotnet_base}.Application/${dotnet_base}.Application.csproj" \
      "${dotnet_base}.Web/${dotnet_base}.Web.csproj"

    dotnet add "${dotnet_base}.Application/${dotnet_base}.Application.csproj" reference \
      "${dotnet_base}.Core/${dotnet_base}.Core.csproj"
    dotnet add "${dotnet_base}.Web/${dotnet_base}.Web.csproj" reference \
      "${dotnet_base}.Application/${dotnet_base}.Application.csproj" \
      "${dotnet_base}.Core/${dotnet_base}.Core.csproj"
  )

  # Stabilize ports so Vite proxy doesn't need guesswork.
  local launch_settings="$BACKEND_DIR/src/${dotnet_base}.Web/Properties/launchSettings.json"
  if [[ -f "$launch_settings" ]]; then
    cat >"$launch_settings" <<'JSON'
{
  "$schema": "http://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "swagger",
      "applicationUrl": "http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "swagger",
      "applicationUrl": "https://localhost:5001;http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
JSON
  fi

  # Provide a stable API prefix (/api) and a simple health endpoint.
  local program_cs="$BACKEND_DIR/src/${dotnet_base}.Web/Program.cs"
  if [[ -f "$program_cs" ]]; then
    cat >"$program_cs" <<'CS'
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }))
    .WithName("Health")
    .WithOpenApi();

app.Run();
CS
  fi

  printf "\n==> Scaffolding frontend (Vite React/TS)\n"
  local moved_env_example=""
  if [[ -f "$FRONTEND_DIR/.env.example" ]]; then
    moved_env_example="$SCRIPT_DIR/.env.example.frontend.bak"
    mv "$FRONTEND_DIR/.env.example" "$moved_env_example"
  fi

	# If the frontend directory exists (even empty), remove it so create-vite can create it.
	if [[ -d "$FRONTEND_DIR" ]]; then
		rmdir "$FRONTEND_DIR" 2>/dev/null || true
	fi

  (
    cd "$SCRIPT_DIR"
    CI=true npm create vite@latest frontend -- --template react-ts --rolldown --no-interactive
    cd "$FRONTEND_DIR"
  )

  if [[ -n "$moved_env_example" && -f "$moved_env_example" ]]; then
    mv "$moved_env_example" "$FRONTEND_DIR/.env.example"
  fi

  # Ensure package.json has a reasonable "name".
  if [[ -f "$FRONTEND_DIR/package.json" ]]; then
    (
      cd "$FRONTEND_DIR"
      VITE_APP_NAME="$vite_name" node - <<'NODE'
const fs = require('fs');
const path = require('path');

const packageJsonPath = path.join(process.cwd(), 'package.json');
const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
pkg.name = process.env.VITE_APP_NAME || pkg.name;
fs.writeFileSync(packageJsonPath, JSON.stringify(pkg, null, 2) + '\n');
NODE
    )
  fi

  # Set up a Vite proxy for /api -> backend.
  if [[ -f "$FRONTEND_DIR/vite.config.ts" ]]; then
    cat >"$FRONTEND_DIR/vite.config.ts" <<'TS'
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiTarget = env.VITE_API_PROXY_TARGET ?? 'https://localhost:5001'

  return {
    plugins: [react()],
    server: {
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
          secure: false
        }
      }
    }
  }
})
TS
  fi

  # Ensure a frontend .env.example exists and document the proxy target.
  if [[ ! -f "$FRONTEND_DIR/.env.example" ]]; then
    cat >"$FRONTEND_DIR/.env.example" <<'ENV'
# Copy this file to .env and fill in values.

# Vite dev proxy target for /api
VITE_API_PROXY_TARGET=https://localhost:5001
ENV
  else
    if ! grep -q "VITE_API_PROXY_TARGET" "$FRONTEND_DIR/.env.example"; then
      printf "\n# Vite dev proxy target for /api\nVITE_API_PROXY_TARGET=https://localhost:5001\n" >>"$FRONTEND_DIR/.env.example"
    fi
  fi

  # Install dependencies last, so any Ctrl+C during install still leaves
  # the proxy and package name configured.
  (
    printf "\nRunning npm install. Please wait...\n"

    cd "$FRONTEND_DIR"
    CI=true npm install
  )

  printf "\nDone. Next steps:\n"
  printf -- "- Backend:  cd app/backend && dotnet watch run --project src/%s.Web\n" "$dotnet_base"
  printf -- "- Frontend: cd app/frontend && npm run dev\n"
  printf "\nFrontend calls should use relative URLs like /api/health (proxied to the backend).\n"
}

main "$@"
