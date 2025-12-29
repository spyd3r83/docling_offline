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

$isWindowsOs = $false
if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
  $isWindowsOs = $IsWindows
} else {
  $isWindowsOs = $env:OS -eq "Windows_NT"
}

function Get-VenvPythonPath {
  param([string]$VenvPath)
  if ($isWindowsOs) {
    return (Join-Path $VenvPath "Scripts\\python.exe")
  }
  return (Join-Path $VenvPath "bin/python")
}

if (-not $BundleRoot) {
  $BundleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
  $BundleRoot = Resolve-Path $BundleRoot
}

$venvPath = Join-Path $BundleRoot $VenvDir
$venvPython = Get-VenvPythonPath -VenvPath $venvPath
if (-not (Test-Path $venvPython)) {
  throw "Virtual env python not found: $venvPython"
}

$modelsPath = Join-Path $BundleRoot $OutputDir
if (-not (Test-Path $modelsPath)) {
  $null = New-Item -ItemType Directory -Path $modelsPath
}

$args = @("-m", "docling.cli.tools", "models", "download", "-o", $modelsPath)
if ($All) { $args += "--all" }
if ($Force) { $args += "--force" }
if ($Quiet) { $args += "--quiet" }
if ($Models.Count -gt 0) { $args += $Models }

& $venvPython @args
