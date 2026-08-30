param(
    [Parameter(Mandatory)][string]$Namespace,
    [switch]$AllowChaos
)
$ErrorActionPreference = "Stop"
if (-not $AllowChaos) { throw "Нужен явный флаг -AllowChaos." }
if ($Namespace -match '(?i)prod|production') { throw "Chaos в production запрещён этим репозиторием." }
$label = & kubectl get namespace $Namespace -o 'jsonpath={.metadata.labels.portable-agent\.io/chaos-ready}'
if ($LASTEXITCODE -ne 0 -or $label -ne "true") { throw "У namespace нет метки portable-agent.io/chaos-ready=true." }
$yaml = (Get-Content chaos/pod-delay.yaml -Raw).Replace("change-me", $Namespace)
$yaml | & kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw "Chaos manifest не применился." }

