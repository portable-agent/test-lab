$ErrorActionPreference = "Stop"
foreach ($file in @(".env.example", "compose.yaml", "tests/smoke.js", "chaos/pod-delay.yaml", "README.md", "AGENTS.md", "SERVICE.md")) {
    if (-not (Test-Path $file)) { throw "Нет обязательного файла: $file" }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker не найден." }
& docker compose --env-file .env.example config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config содержит ошибку." }
$script = Get-Content tests/smoke.js -Raw
foreach ($required in @("TARGET_URL", "thresholds", "http_req_failed", "http_req_duration")) {
    if ($script -notmatch $required) { throw "В k6-тесте нет $required." }
}
Write-Host "Быстрые проверки test-lab прошли."

