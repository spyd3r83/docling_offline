[CmdletBinding()]
param(
  [string]$BundleRoot = "",
  [string]$VenvDir = ".venv",
  [string]$PythonExe = "python",
  [string]$Extras = ""
)

$ErrorActionPreference = "Stop"

$isWindowsOs = $false
$isMacOs = $false
$isLinuxOs = $false
if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
  $isWindowsOs = $IsWindows
  $isMacOs = $IsMacOS
  $isLinuxOs = $IsLinux
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

$wheelhouse = Join-Path $BundleRoot "wheelhouse"
if (-not (Test-Path $wheelhouse)) {
  throw "Wheelhouse not found: $wheelhouse"
}

$venvPath = Join-Path $BundleRoot $VenvDir
if (-not (Test-Path $venvPath)) {
  & $PythonExe -m venv $venvPath
}

$venvPython = Get-VenvPythonPath -VenvPath $venvPath
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
if ($isWindowsOs) {
  Write-Host "Activate with: $venvPath\\Scripts\\Activate.ps1"
} else {
  Write-Host "Activate with: $venvPath/bin/Activate.ps1"
}
