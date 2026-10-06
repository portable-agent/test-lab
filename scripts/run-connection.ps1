param(
    [string]$ChannelUrl = "",
    [string]$KeycloakUrl = "",
    [string]$DockerNetwork = ""
)

$ErrorActionPreference = "Stop"

function Get-Setting([string]$Name, [switch]$Secret) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value -and (Test-Path -LiteralPath ".env")) {
        $line = Get-Content -LiteralPath ".env" | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
        if ($line) { $value = $line.Substring($line.IndexOf('=') + 1) }
    }
    if (-not $value -and -not $Secret -and (Test-Path -LiteralPath ".env.example")) {
        $line = Get-Content -LiteralPath ".env.example" | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
        if ($line) { $value = $line.Substring($line.IndexOf('=') + 1) }
    }
    if (-not $value) { throw "Set $Name in the environment or local .env file." }
    return $value
}

function Assert-LocalUrl([string]$Url) {
    $uri = [Uri]$Url
    $allowedHosts = @("localhost", "127.0.0.1", "host.docker.internal")
    if ($DockerNetwork) { $allowedHosts += "channel-gateway" }
    if ($uri.Scheme -ne "http" -or $uri.Host -notin $allowedHosts) {
        throw "Connection acceptance test allows local HTTP URLs only."
    }
}

$DockerNetwork = if ($DockerNetwork) { $DockerNetwork } else { [Environment]::GetEnvironmentVariable("DOCKER_NETWORK") }
if ($DockerNetwork -and $DockerNetwork -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]+$') {
    throw "DOCKER_NETWORK contains unsupported characters."
}
$ChannelUrl = if ($ChannelUrl) { $ChannelUrl } else { Get-Setting "CHANNEL_URL" }
$KeycloakUrl = if ($KeycloakUrl) { $KeycloakUrl } else { Get-Setting "KEYCLOAK_URL" }
Assert-LocalUrl $ChannelUrl
Assert-LocalUrl $KeycloakUrl

$token = [Environment]::GetEnvironmentVariable("ACTION_TOKEN")
if (-not $token) {
    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "$KeycloakUrl/realms/$(Get-Setting 'OIDC_REALM')/protocol/openid-connect/token" `
        -Body @{
            client_id = Get-Setting "OIDC_CLIENT_ID"
            username = Get-Setting "TEST_USERNAME" -Secret
            password = Get-Setting "TEST_PASSWORD" -Secret
            grant_type = "password"
        }
    $token = $tokenResponse.access_token
}
if ($token.Split('.').Count -ne 3) { throw "ACTION_TOKEN is not a JWT." }

$dockerArgs = @("run", "--rm", "--add-host", "host.docker.internal:host-gateway")
if ($DockerNetwork) { $dockerArgs += @("--network", $DockerNetwork) }
$dockerArgs += @(
    "--volume", "${PWD}/tests:/tests:ro",
    "--env", "CHANNEL_URL=$ChannelUrl",
    "--env", "ACTION_TOKEN=$token",
    (Get-Setting "K6_IMAGE"), "run", "/tests/connection-widget.js"
)

& docker @dockerArgs
if ($LASTEXITCODE -ne 0) { throw "Connection widget acceptance scenario failed." }
