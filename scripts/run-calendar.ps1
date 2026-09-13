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
if (-not $env:CALENDAR_TEST_API_KEY) { throw "Укажи CALENDAR_TEST_API_KEY локального Calendar MCP." }
$parts = $env:ACTION_TOKEN.Split('.')
if ($parts.Count -ne 3) { throw "ACTION_TOKEN не похож на JWT." }

& docker run --rm `
    --volume "${PWD}/tests:/tests:ro" `
    --env "AGENT_URL=$AgentUrl" `
    --env "ACTION_URL=$ActionUrl" `
    --env "CALENDAR_TEST_URL=$CalendarTestUrl" `
    --env "CALENDAR_TEST_API_KEY=$env:CALENDAR_TEST_API_KEY" `
    --env "ACTION_TOKEN=$env:ACTION_TOKEN" `
    "grafana/k6:2.2.0" run /tests/calendar-event.js

if ($LASTEXITCODE -ne 0) { throw "Сценарий создания встречи не прошёл." }
