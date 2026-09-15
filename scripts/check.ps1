$ErrorActionPreference = "Stop"
foreach ($file in @(".env.example", "compose.yaml", "Taskfile.yml", "tests/smoke.js", "tests/calendar-event.js", "scripts/run-calendar.ps1", "chaos/pod-delay.yaml", "README.md", "AGENTS.md", "SERVICE.md")) {
    if (-not (Test-Path $file)) { throw "Required file is missing: $file" }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker is not installed." }
& docker compose --env-file .env.example config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config is invalid." }
$script = Get-Content tests/smoke.js -Raw
foreach ($required in @("TARGET_URL", "thresholds", "http_req_failed", "http_req_duration")) {
    if ($script -notmatch $required) { throw "k6 test does not contain $required." }
}
$calendarScript = Get-Content tests/calendar-event.js -Raw
foreach ($required in @("AWAITING_APPROVAL", "SUCCEEDED", "payloadHash", "requestKey", "result?.eventId", "http_req_failed", "CALENDAR_TEST_API_KEY", "X-Test-Key", "CHANNEL_URL", "/api/v1/messages", "requiresApproval", "Authorization")) {
    if ($calendarScript -notmatch [regex]::Escape($required)) { throw "Calendar acceptance test does not contain $required." }
}
foreach ($oldName in @("utterance", "tenant_id", "actor_id", "available_connectors", "requires_approval")) {
    if ($calendarScript -match [regex]::Escape($oldName)) { throw "Calendar acceptance test still contains old field $oldName." }
}
if ($calendarScript -match "/api/v1/proposals") { throw "Acceptance-test must start through Channel Gateway." }

$runner = Get-Content scripts/run-calendar.ps1 -Raw
foreach ($required in @("ACTION_TOKEN", "KEYCLOAK_URL", "OIDC_REALM", "OIDC_CLIENT_ID", "TEST_USERNAME", "TEST_PASSWORD", "protocol/openid-connect/token", "--add-host", "host.docker.internal:host-gateway", "DOCKER_NETWORK", "--network")) {
    if ($runner -notmatch [regex]::Escape($required)) { throw "Calendar runner does not support $required." }
}

$taskfile = Get-Content Taskfile.yml -Raw
foreach ($required in @("verify:", "test:smoke:", "test:e2e:", "test:load:")) {
    if ($taskfile -notmatch [regex]::Escape($required)) { throw "Taskfile does not contain $required." }
}

$ci = Get-Content .github/workflows/ci.yml -Raw
foreach ($required in @("go-task/setup-task", "task verify", "task test:smoke")) {
    if ($ci -notmatch [regex]::Escape($required)) { throw "CI does not use $required." }
}
Write-Host "Test Lab checks passed."

