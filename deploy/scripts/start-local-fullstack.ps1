param(
    [switch]$InstallDeps,
    [int]$HealthTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendStartScript = Join-Path $repoRoot "deploy\scripts\start-backend-local.ps1"
$algorithmDir = Join-Path $repoRoot "algorithm-service"
$stateDir = Join-Path $repoRoot ".local-run"
$logDir = Join-Path $stateDir "logs"
$algorithmLog = Join-Path $logDir "algorithm.log"
$backendLog = Join-Path $logDir "backend.log"
$algorithmPidFile = Join-Path $stateDir "algorithm.pid"
$backendPidFile = Join-Path $stateDir "backend.pid"

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Test-PortListening {
    param([int]$Port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
        return $null -ne $conn
    } catch {
        return $false
    }
}

function Test-HttpHealthy {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 2
    )
    try {
        $null = Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSeconds
        return $true
    } catch {
        return $false
    }
}

function Wait-ForHealth {
    param(
        [string]$Name,
        [string]$Url,
        [int]$MaxSeconds
    )
    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-HttpHealthy -Url $Url) {
            Write-Host "[OK] $Name healthy: $Url"
            return
        }
        Start-Sleep -Seconds 2
    }
    throw "$Name health check timeout: $Url"
}

function Stop-IfRunning {
    param([int]$ProcId)
    try {
        Stop-Process -Id $ProcId -Force -ErrorAction Stop
    } catch {
        # ignore cleanup errors
    }
}

if (!(Test-Path $backendStartScript)) {
    throw "Missing backend startup script: $backendStartScript"
}
if (!(Test-Path $algorithmDir)) {
    throw "Missing algorithm service directory: $algorithmDir"
}
if (Test-PortListening -Port 8000) {
    throw "Port 8000 is already in use. Run .\deploy\scripts\stop-local-fullstack.ps1 or stop existing process first."
}
if (Test-PortListening -Port 8080) {
    throw "Port 8080 is already in use. Run .\deploy\scripts\stop-local-fullstack.ps1 or stop existing process first."
}

Write-Host "[1/5] Preparing Python runtime..."
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
$pythonExe = $null
if ($pythonCmd) {
    $pythonExe = $pythonCmd.Source
}
if (-not $pythonExe) {
    throw "Python not found in PATH."
}

$venvDir = Join-Path $algorithmDir ".venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvUvicorn = Join-Path $venvDir "Scripts\uvicorn.exe"

if (!(Test-Path $venvPython)) {
    & $pythonExe -m venv $venvDir
}

if ($InstallDeps -or !(Test-Path $venvUvicorn)) {
    & $venvPython -m pip install --upgrade pip | Out-Null
    & $venvPython -m pip install -r (Join-Path $algorithmDir "requirements.txt") | Out-Null
}

Write-Host "[2/5] Starting algorithm service..."
$algorithmCommand = "Set-Location '$algorithmDir'; & '$venvPython' -m uvicorn app.main:app --host 0.0.0.0 --port 8000 *>> '$algorithmLog'"
$algorithmProc = Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $algorithmCommand -PassThru
$algorithmProc.Id | Set-Content $algorithmPidFile

Write-Host "[3/5] Starting backend service..."
$backendCommand = "& '$backendStartScript' *>> '$backendLog'"
$backendProc = Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $backendCommand -PassThru
$backendProc.Id | Set-Content $backendPidFile

Write-Host "[4/5] Waiting for health checks..."
try {
    Wait-ForHealth -Name "Algorithm service" -Url "http://127.0.0.1:8000/api/python/health" -MaxSeconds $HealthTimeoutSeconds
    Wait-ForHealth -Name "Backend service" -Url "http://127.0.0.1:8080/api/recommend/movie?userId=1&topN=1" -MaxSeconds $HealthTimeoutSeconds
} catch {
    Write-Host "[ERR] Health check failed, cleaning up started processes..."
    Stop-IfRunning -ProcId $algorithmProc.Id
    Stop-IfRunning -ProcId $backendProc.Id
    Remove-Item $algorithmPidFile -Force -ErrorAction SilentlyContinue
    Remove-Item $backendPidFile -Force -ErrorAction SilentlyContinue
    throw
}

Write-Host "[5/5] Full stack started."
Write-Host ""
Write-Host "Algorithm health: http://127.0.0.1:8000/api/python/health"
Write-Host "Backend API:      http://127.0.0.1:8080/api/recommend/movie?userId=1&topN=3"
Write-Host "Algorithm log:    $algorithmLog"
Write-Host "Backend log:      $backendLog"
Write-Host "Stop command:     .\deploy\scripts\stop-local-fullstack.ps1"
