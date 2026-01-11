Param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlywayArgs
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
@'
Flyway runner (Docker)

Usage:
  ./app/flyway/flyway.ps1 <command> [args...]

Examples:
  ./app/flyway/flyway.ps1 info
  ./app/flyway/flyway.ps1 migrate
  ./app/flyway/flyway.ps1 validate
  ./app/flyway/flyway.ps1 repair

Configuration:
  - Create ./app/flyway/.env from ./app/flyway/.env.example
  - Or set env vars: FLYWAY_URL, FLYWAY_USER, FLYWAY_PASSWORD, ...
'@
}

if (-not $FlywayArgs -or $FlywayArgs.Count -eq 0 -or $FlywayArgs[0] -in @('-h', '--help', '/?')) {
  Show-Usage
  exit 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Missing required command: docker'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir '.env'

if (-not (Test-Path $envFile)) {
  Write-Warning "NOTE: $envFile not found. Copy .env.example to .env and set DB credentials, or set FLYWAY_* env vars."
}

$flywayImage = if ($env:FLYWAY_IMAGE) { $env:FLYWAY_IMAGE } else { 'flyway/flyway:10' }
$flywayNetwork = $env:FLYWAY_DOCKER_NETWORK

$args = @('run', '--rm')

# Mount migrations read-only
$args += @('-v', "${scriptDir}/sql:/flyway/sql:ro")

if ($flywayNetwork) {
  $args += @('--network', $flywayNetwork)
}

if (Test-Path $envFile) {
  $args += @('--env-file', $envFile)
}

$args += $flywayImage
$args += $FlywayArgs

& docker @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
