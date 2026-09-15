param(
    [Parameter(Mandatory)][string]$Namespace,
    [switch]$AllowChaos
)
$ErrorActionPreference = "Stop"
if (-not $AllowChaos) { throw "Explicit -AllowChaos flag is required." }
if ($Namespace -match '(?i)prod|production') { throw "Chaos in production is forbidden by this repository." }
$label = & kubectl get namespace $Namespace -o 'jsonpath={.metadata.labels.portable-agent\.io/chaos-ready}'
if ($LASTEXITCODE -ne 0 -or $label -ne "true") { throw "Namespace must have portable-agent.io/chaos-ready=true label." }
$yaml = (Get-Content chaos/pod-delay.yaml -Raw).Replace("change-me", $Namespace)
$yaml | & kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw "Chaos manifest was not applied." }

