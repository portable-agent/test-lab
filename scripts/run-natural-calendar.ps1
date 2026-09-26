param(
    [ValidateRange(30, 600)]
    [int]$MaxSeconds = 120
)

$ErrorActionPreference = "Stop"
$oldMaxSeconds = [Environment]::GetEnvironmentVariable("MODEL_TEST_MAX_SECONDS", "Process")

try {
    [Environment]::SetEnvironmentVariable("MODEL_TEST_MAX_SECONDS", $MaxSeconds, "Process")
    & "$PSScriptRoot/run-calendar.ps1" -TestFile "natural-calendar.js"
    if ($LASTEXITCODE -ne 0) { throw "Natural-language calendar scenario failed." }
}
finally {
    [Environment]::SetEnvironmentVariable("MODEL_TEST_MAX_SECONDS", $oldMaxSeconds, "Process")
}
