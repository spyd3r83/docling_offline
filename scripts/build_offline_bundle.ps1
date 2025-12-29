[CmdletBinding()]
param(
  [string]$OutputDir = "",
  [string]$PythonVersion = "3.13.9",
  [string]$PythonInstallerUrl = "",
  [switch]$SkipPythonDownload,
  [string]$DoclingVersion = "",
  [string]$Extras = "",
  [bool]$IncludeModels = $true,
  [switch]$AllowSdists
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

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$versionParts = $PythonVersion.Split(".")
$pyMajor = $versionParts[0]
$pyMinor = $versionParts[1]
$pyShort = "$pyMajor.$pyMinor"
$currentPy = (& python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" ).Trim()

$ResolvedDoclingVersion = $DoclingVersion
if (-not $ResolvedDoclingVersion) {
  Write-Host "Resolving docling version from PyPI..."
  $resolveDir = Join-Path $Root "dist\\_resolve_docling"
  if (Test-Path $resolveDir) {
    Remove-Item -Recurse -Force $resolveDir
  }
  $null = New-Item -ItemType Directory -Path $resolveDir
  & python -m pip download --no-deps --dest $resolveDir docling
  if ($LASTEXITCODE -ne 0) {
    throw "pip download failed while resolving docling version (exit code $LASTEXITCODE)"
  }
  $doclingWheel = Get-ChildItem -Path $resolveDir -Filter "docling-*.whl" | Sort-Object Name -Descending | Select-Object -First 1
  if (-not $doclingWheel) {
    throw "Could not resolve docling wheel in $resolveDir"
  }
  $ResolvedDoclingVersion = ($doclingWheel.BaseName -split "-")[1]
  Remove-Item -Recurse -Force $resolveDir
}

if (-not $OutputDir) {
  $OutputDir = Join-Path $Root ("dist\\docling-offline-$ResolvedDoclingVersion")
}

if (Test-Path $OutputDir) {
  throw "OutputDir already exists: $OutputDir"
}

$null = New-Item -ItemType Directory -Path $OutputDir
$null = New-Item -ItemType Directory -Path (Join-Path $OutputDir "wheelhouse")
$null = New-Item -ItemType Directory -Path (Join-Path $OutputDir "python")
$null = New-Item -ItemType Directory -Path (Join-Path $OutputDir "scripts")
$null = New-Item -ItemType Directory -Path (Join-Path $OutputDir "models")

$pythonInstallerName = ""
if (-not $SkipPythonDownload) {
  if ($PythonInstallerUrl) {
    $pythonUrl = $PythonInstallerUrl
    $pythonInstallerName = [System.IO.Path]::GetFileName(([System.Uri]$pythonUrl).AbsolutePath)
  } elseif ($isWindowsOs) {
    $pythonInstallerName = "python-$PythonVersion-amd64.exe"
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/$pythonInstallerName"
  } elseif ($isMacOs) {
    $pythonInstallerName = "python-$PythonVersion-macos11.pkg"
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/$pythonInstallerName"
  } else {
    $SkipPythonDownload = $true
    Write-Host "Skipping Python download on Linux by default. Use -PythonInstallerUrl to include an installer."
  }
}

if (-not $SkipPythonDownload) {
  Write-Host "Downloading Python $PythonVersion..."
  $pythonOut = Join-Path $OutputDir ("python\\" + $pythonInstallerName)
  Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonOut
}

Write-Host "Downloading wheels..."
$wheelhouse = Join-Path $OutputDir "wheelhouse"
$pkg = "docling==$ResolvedDoclingVersion"
if ($Extras) { $pkg = "docling[$Extras]==$ResolvedDoclingVersion" }
$downloadArgs = @("download", "--dest", $wheelhouse, $pkg)
if ($pyShort -ne $currentPy) {
  if (-not $isWindowsOs) {
    throw "Run this script with Python $pyShort on this platform to build a compatible wheelhouse."
  }
  if ($AllowSdists) {
    throw "AllowSdists requires running with Python $pyShort. Install that Python and rerun."
  }
  $pyAbi = "cp$pyMajor$pyMinor"
  $downloadArgs += @(
    "--platform", "win_amd64",
    "--python-version", $pyShort,
    "--implementation", "cp",
    "--abi", $pyAbi
  )
}
if (-not $AllowSdists) {
  $downloadArgs += "--only-binary"
  $downloadArgs += ":all:"
}
& python -m pip @downloadArgs
if ($LASTEXITCODE -ne 0) {
  throw "pip download failed with exit code $LASTEXITCODE"
}
if ($AllowSdists) {
  & python -m pip download --dest $wheelhouse wheel setuptools
  if ($LASTEXITCODE -ne 0) {
    throw "pip download of build tools failed with exit code $LASTEXITCODE"
  }
}

Write-Host "Copying helper scripts..."
Copy-Item -Path (Join-Path $Root "scripts\\install_offline.ps1") -Destination (Join-Path $OutputDir "scripts") -Force
Copy-Item -Path (Join-Path $Root "scripts\\download_models.ps1") -Destination (Join-Path $OutputDir "scripts") -Force

if ($IncludeModels) {
  Write-Host "Downloading model artifacts (this can be large)..."
  $venvPath = Join-Path $OutputDir "_build_venv"
  & python -m venv $venvPath
  $venvPython = Get-VenvPythonPath -VenvPath $venvPath
  & $venvPython -m pip install --no-index --find-links $wheelhouse $pkg
  $modelsDir = Join-Path $OutputDir "models"
  & $venvPython -m docling.cli.tools models download -o $modelsDir
  Remove-Item -Recurse -Force $venvPath
}

$platformName = "linux"
if ($isWindowsOs) {
  $platformName = "windows"
} elseif ($isMacOs) {
  $platformName = "macos"
}

$manifestPath = Join-Path $OutputDir "MANIFEST.txt"
$manifest = @"
Docling version: $ResolvedDoclingVersion
Python version: $PythonVersion
Platform: $platformName
Python installer: $pythonInstallerName
Wheelhouse built: $(Get-Date -Format o)
Extras: $Extras
Models included: $IncludeModels
"@
Set-Content -Path $manifestPath -Value $manifest -NoNewline

$readmePath = Join-Path $OutputDir "README.md"
$pythonInstallerLine = "Python $PythonVersion installer: not included"
$pythonInstallSteps = @"
1) Install Python $PythonVersion using your system package manager or a local installer.
"@
if (-not $SkipPythonDownload -and $pythonInstallerName) {
  $pythonInstallerLine = "Python $PythonVersion installer: $pythonInstallerName"
  if ($isWindowsOs) {
    $pythonInstallSteps = @"
1) Run the Python installer in python\:
   ~~~powershell
   .\python\$pythonInstallerName
   ~~~
"@
  } elseif ($isMacOs) {
    $pythonInstallSteps = @"
1) Install Python $PythonVersion from the included pkg:
   ~~~powershell
   sudo installer -pkg ./python/$pythonInstallerName -target /
   ~~~
"@
  }
}

$readme = @"
# Docling Offline Bundle

This bundle contains:
- $pythonInstallerLine
- Docling wheelhouse for version $ResolvedDoclingVersion
- Wheelhouse of Python dependencies for $platformName / Python $PythonVersion
- Model artifacts in `models\` downloaded by docling-tools

## Install (offline machine)

$pythonInstallSteps
2) From this bundle root (PowerShell 7+ on macOS/Linux):
   ~~~powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\install_offline.ps1
   ~~~

Manual install:
~~~powershell
python -m venv .venv
# Windows: .\.venv\Scripts\Activate.ps1
# macOS/Linux: ./.venv/bin/Activate.ps1
python -m pip install --no-index --find-links .\wheelhouse docling
~~~

Verify:
~~~powershell
docling --version
~~~

## Models for offline PDF pipelines

Docling can run fully offline if the model artifacts are present locally.
This bundle includes the default model artifacts in models\.
Use:
~~~powershell
docling --artifacts-path .\models <FILE>
~~~

To refresh or add models on a connected machine:
~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download_models.ps1 -OutputDir .\models
~~~

## Notes

- PDF processing requires the model artifacts; other formats like DOCX/PPTX do not.
- This wheelhouse targets $platformName + Python $PythonVersion. Rebuild if your target differs.
- The wheelhouse includes a couple of source dists (pylatexenc, antlr4-python3-runtime); pip builds them locally.
"@
Set-Content -Path $readmePath -Value $readme -NoNewline

Write-Host ""
Write-Host "Bundle created at: $OutputDir"
