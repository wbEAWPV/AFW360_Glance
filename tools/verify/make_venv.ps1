# Create tools/verify/.venv with Python 3.11 and install requirements.txt.
# Usage (PowerShell): powershell -ExecutionPolicy Bypass -File tools/verify/make_venv.ps1
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Root = (Resolve-Path (Join-Path $Here '..\..')).Path
$Venv = Join-Path $Here '.venv'

function Test-Py311([string]$exe) {
    if (-not $exe -or -not (Test-Path $exe)) { return $false }
    & $exe -c 'import sys; sys.exit(0 if sys.version_info[:2]==(3,11) else 1)' 2>$null
    return ($LASTEXITCODE -eq 0)
}

$Py = $null
# 1. base interpreter of the project venv
$ProjPy = Join-Path $Root '.venv\Scripts\python.exe'
if (Test-Path $ProjPy) {
    $base = (& $ProjPy -c 'import sys; print(sys.base_prefix)').Trim()
    $cand = Join-Path $base 'python.exe'
    if (Test-Py311 $cand) { $Py = $cand }
}
# 2. Windows py launcher
if (-not $Py -and (Get-Command py -ErrorAction SilentlyContinue)) {
    $cand = (& py -3.11 -c 'import sys; print(sys.executable)' 2>$null)
    if ($LASTEXITCODE -eq 0 -and $cand) { $cand = $cand.Trim(); if (Test-Py311 $cand) { $Py = $cand } }
}
if (-not $Py) { Write-Error 'make_venv.ps1: no Python 3.11 found'; exit 1 }
Write-Host "Using Python 3.11: $Py"

if (-not (Test-Path $Venv)) { & $Py -m venv $Venv; if ($LASTEXITCODE -ne 0) { exit 1 } }
$VPy = Join-Path $Venv 'Scripts\python.exe'
& $VPy -m pip install --upgrade pip | Out-Null
& $VPy -m pip install -r (Join-Path $Here 'requirements.txt')
if ($LASTEXITCODE -ne 0) { exit 1 }
& $VPy -c "import pysdmx, lxml; print('pysdmx', pysdmx.__version__)"
exit $LASTEXITCODE
