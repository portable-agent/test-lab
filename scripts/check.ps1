$ErrorActionPreference = "Stop"
foreach ($file in @(".env.example", "compose.yaml", "tests/smoke.js", "tests/calendar-event.js", "scripts/run-calendar.ps1", "chaos/pod-delay.yaml", "README.md", "AGENTS.md", "SERVICE.md")) {
    if (-not (Test-Path $file)) { throw "Нет обязательного файла: $file" }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker не найден." }
& docker compose --env-file .env.example config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config содержит ошибку." }
$script = Get-Content tests/smoke.js -Raw
foreach ($required in @("TARGET_URL", "thresholds", "http_req_failed", "http_req_duration")) {
    if ($script -notmatch $required) { throw "В k6-тесте нет $required." }
}
$calendarScript = Get-Content tests/calendar-event.js -Raw
foreach ($required in @("AWAITING_APPROVAL", "SUCCEEDED", "payloadHash", "requestKey", "result?.eventId", "http_req_failed", "CALENDAR_TEST_API_KEY", "X-Test-Key")) {
    if ($calendarScript -notmatch [regex]::Escape($required)) { throw "В calendar acceptance-тесте нет $required." }
}
Write-Host "Быстрые проверки test-lab прошли."

