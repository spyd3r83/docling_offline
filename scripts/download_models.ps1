[CmdletBinding()]
param(
  [string]$BundleRoot = "",
  [string]$VenvDir = ".venv",
  [string]$OutputDir = "models",
  [string[]]$Models = @(),
  [switch]$All,
  [switch]$Force,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if (-not $BundleRoot) {
  $BundleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
  $BundleRoot = Resolve-Path $BundleRoot
}

$venvPath = Join-Path $BundleRoot $VenvDir
$doclingTools = Join-Path $venvPath "Scripts\\docling-tools.exe"
if (-not (Test-Path $doclingTools)) {
  throw "docling-tools not found: $doclingTools"
}

$modelsPath = Join-Path $BundleRoot $OutputDir
if (-not (Test-Path $modelsPath)) {
  $null = New-Item -ItemType Directory -Path $modelsPath
}

$args = @("models", "download", "-o", $modelsPath)
if ($All) { $args += "--all" }
if ($Force) { $args += "--force" }
if ($Quiet) { $args += "--quiet" }
if ($Models.Count -gt 0) { $args += $Models }

& $doclingTools @args
