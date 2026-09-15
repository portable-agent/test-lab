param([string]$TargetUrl = "")
$ErrorActionPreference = "Stop"
$envFiles = @("--env-file", ".env.example")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
if ($TargetUrl) {
    if ($TargetUrl -match '(?i)prod|production') { throw "Running against production is forbidden." }
    $env:TARGET_URL = $TargetUrl
}
try {
    & docker compose @envFiles up -d --wait fake-service
    if ($LASTEXITCODE -ne 0) { throw "Fake service did not start." }
    & docker compose @envFiles --profile test run --rm k6
    if ($LASTEXITCODE -ne 0) { throw "k6 thresholds were not met." }
}
finally {
    & docker compose @envFiles --profile test down | Out-Null
    if ($TargetUrl) { Remove-Item Env:TARGET_URL -ErrorAction SilentlyContinue }
}

