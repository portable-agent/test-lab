param([string]$TargetUrl = "")
$ErrorActionPreference = "Stop"
$envFiles = @("--env-file", ".env.example")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
if ($TargetUrl) {
    if ($TargetUrl -match '(?i)prod|production') { throw "Запуск против production запрещён." }
    $env:TARGET_URL = $TargetUrl
}
try {
    & docker compose @envFiles up -d --wait fake-service
    if ($LASTEXITCODE -ne 0) { throw "Fake service не запустился." }
    & docker compose @envFiles --profile test run --rm k6
    if ($LASTEXITCODE -ne 0) { throw "k6-пороги не выполнены." }
}
finally {
    & docker compose @envFiles --profile test down | Out-Null
    if ($TargetUrl) { Remove-Item Env:TARGET_URL -ErrorAction SilentlyContinue }
}

