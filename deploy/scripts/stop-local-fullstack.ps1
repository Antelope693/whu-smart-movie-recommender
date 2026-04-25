$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stateDir = Join-Path $repoRoot ".local-run"
$algorithmPidFile = Join-Path $stateDir "algorithm.pid"
$backendPidFile = Join-Path $stateDir "backend.pid"

function Stop-ByPidFile {
    param(
        [string]$Name,
        [string]$PidFile
    )
    if (!(Test-Path $PidFile)) {
        Write-Host "[SKIP] $Name pid file not found."
        return
    }

    $processId = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($processId)) {
        Write-Host "[SKIP] $Name pid file is empty."
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        return
    }

    try {
        Stop-Process -Id ([int]$processId) -Force -ErrorAction Stop
        Write-Host "[OK] Stopped $Name process (PID=$processId)."
    } catch {
        Write-Host "[WARN] Failed to stop $Name process (PID=$processId), it may already be exited."
    }

    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

Stop-ByPidFile -Name "Algorithm service" -PidFile $algorithmPidFile
Stop-ByPidFile -Name "Backend service" -PidFile $backendPidFile

function Stop-ByPort {
    param(
        [string]$Name,
        [int]$Port
    )
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    } catch {
        Write-Host "[SKIP] $Name no listener on port $Port."
        return
    }

    if ($null -eq $connections) {
        Write-Host "[SKIP] $Name no listener on port $Port."
        return
    }

    $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $pids) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-Host "[OK] Stopped $Name by port $Port (PID=$procId)."
        } catch {
            Write-Host "[WARN] Failed to stop $Name on port $Port (PID=$procId)."
        }
    }
}

# Fallback: stop orphan processes even when pid files are missing.
Stop-ByPort -Name "Algorithm service" -Port 8000
Stop-ByPort -Name "Backend service" -Port 8080
