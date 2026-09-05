param(
    [string]$AgentUrl = "http://host.docker.internal:18080",
    [string]$ActionUrl = "http://host.docker.internal:18081",
    [string]$CalendarTestUrl = "http://host.docker.internal:18082"
)

$ErrorActionPreference = "Stop"

foreach ($url in @($AgentUrl, $ActionUrl, $CalendarTestUrl)) {
    $uri = [Uri]$url
    if ($uri.Scheme -ne "http" -or $uri.Host -notin @("localhost", "127.0.0.1", "host.docker.internal")) {
        throw "Calendar acceptance-тест разрешён только для локальных HTTP-адресов."
    }
}
if (-not $env:ACTION_TOKEN) { throw "Укажи ACTION_TOKEN с JWT тестового пользователя." }
$parts = $env:ACTION_TOKEN.Split('.')
if ($parts.Count -ne 3) { throw "ACTION_TOKEN не похож на JWT." }
$payload = $parts[1].Replace('-', '+').Replace('_', '/')
while ($payload.Length % 4) { $payload += '=' }
try {
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
}
catch {
    throw "Не удалось прочитать claims из ACTION_TOKEN."
}
if (-not $claims.sub -or -not $claims.tenant_id) {
    throw "В ACTION_TOKEN нужны claims sub и tenant_id."
}

& docker run --rm `
    --volume "${PWD}/tests:/tests:ro" `
    --env "AGENT_URL=$AgentUrl" `
    --env "ACTION_URL=$ActionUrl" `
    --env "CALENDAR_TEST_URL=$CalendarTestUrl" `
    --env "ACTION_TOKEN=$env:ACTION_TOKEN" `
    --env "TEST_TENANT_ID=$($claims.tenant_id)" `
    --env "TEST_ACTOR_ID=$($claims.sub)" `
    "grafana/k6:2.2.0" run /tests/calendar-event.js

if ($LASTEXITCODE -ne 0) { throw "Сценарий создания встречи не прошёл." }
