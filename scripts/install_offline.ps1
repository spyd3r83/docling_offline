[CmdletBinding()]
param(
  [string]$BundleRoot = "",
  [string]$VenvDir = ".venv",
  [string]$PythonExe = "python",
  [string]$Extras = ""
)

$ErrorActionPreference = "Stop"

if (-not $BundleRoot) {
  $BundleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
  $BundleRoot = Resolve-Path $BundleRoot
}

$wheelhouse = Join-Path $BundleRoot "wheelhouse"
if (-not (Test-Path $wheelhouse)) {
  throw "Wheelhouse not found: $wheelhouse"
}

$venvPath = Join-Path $BundleRoot $VenvDir
if (-not (Test-Path $venvPath)) {
  & $PythonExe -m venv $venvPath
}

$venvPython = Join-Path $venvPath "Scripts\\python.exe"
if (-not (Test-Path $venvPython)) {
  throw "Virtual env python not found: $venvPython"
}

$pkg = "docling"
if ($Extras) {
  $pkg = "docling[$Extras]"
}

& $venvPython -m pip install --no-index --find-links $wheelhouse $pkg

Write-Host ""
Write-Host "Docling installed into: $venvPath"
Write-Host "Activate with: $venvPath\\Scripts\\Activate.ps1"
