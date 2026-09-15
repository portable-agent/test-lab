param(
    [string]$ChannelUrl = "",
    [string]$ActionUrl = "",
    [string]$CalendarTestUrl = "",
    [string]$KeycloakUrl = ""
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
    $uri = [Uri]$url
    if ($uri.Scheme -ne "http" -or $uri.Host -notin @("localhost", "127.0.0.1", "host.docker.internal")) {
        throw "Calendar acceptance test allows local HTTP URLs only."
    }
}

$ChannelUrl = if ($ChannelUrl) { $ChannelUrl } else { Get-Setting "CHANNEL_URL" }
$ActionUrl = if ($ActionUrl) { $ActionUrl } else { Get-Setting "ACTION_URL" }
$CalendarTestUrl = if ($CalendarTestUrl) { $CalendarTestUrl } else { Get-Setting "CALENDAR_TEST_URL" }
$KeycloakUrl = if ($KeycloakUrl) { $KeycloakUrl } else { Get-Setting "KEYCLOAK_URL" }

foreach ($url in @($ChannelUrl, $ActionUrl, $CalendarTestUrl, $KeycloakUrl)) {
    Assert-LocalUrl $url
}

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

$parts = $token.Split('.')
if ($parts.Count -ne 3) { throw "ACTION_TOKEN is not a JWT." }
$calendarTestKey = Get-Setting "CALENDAR_TEST_API_KEY" -Secret
$k6Image = Get-Setting "K6_IMAGE"

& docker run --rm `
    --add-host "host.docker.internal:host-gateway" `
    --volume "${PWD}/tests:/tests:ro" `
    --env "CHANNEL_URL=$ChannelUrl" `
    --env "ACTION_URL=$ActionUrl" `
    --env "CALENDAR_TEST_URL=$CalendarTestUrl" `
    --env "CALENDAR_TEST_API_KEY=$calendarTestKey" `
    --env "ACTION_TOKEN=$token" `
    $k6Image run /tests/calendar-event.js

if ($LASTEXITCODE -ne 0) { throw "Calendar acceptance scenario failed." }
