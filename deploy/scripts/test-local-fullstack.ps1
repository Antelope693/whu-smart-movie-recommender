param(
    [int]$UserId = 1,
    [int]$MovieId = 1,
    [double]$Score = 4.5,
    [string]$LlmQuery = "推荐一部烧脑科幻片",
    [switch]$AutoStart,
    [switch]$SkipMysqlCheck,
    [switch]$SkipLlmCheck
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mysqlCheckScript = Join-Path $repoRoot "deploy\scripts\check-mysql-local.ps1"
$startScript = Join-Path $repoRoot "deploy\scripts\start-local-fullstack.ps1"

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $results.Add([PSCustomObject]@{
            Name   = $Name
            Passed = $Passed
            Detail = $Detail
        }) | Out-Null
}

function Invoke-Test {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    try {
        & $Action
        Add-Result -Name $Name -Passed $true -Detail "OK"
        Write-Host "[PASS] $Name"
    } catch {
        Add-Result -Name $Name -Passed $false -Detail $_.Exception.Message
        Write-Host "[FAIL] $Name -> $($_.Exception.Message)"
    }
}

function Test-Endpoint {
    param([string]$Url)
    try {
        $null = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 3
        return $true
    } catch {
        return $false
    }
}

Write-Host "== Local Fullstack Test =="
Write-Host "target userId=$UserId movieId=$MovieId score=$Score"

if ($AutoStart) {
    Write-Host "[INFO] AutoStart enabled. Ensuring services are running..."
    $algorithmUp = Test-Endpoint -Url "http://127.0.0.1:8000/api/python/health"
    $backendUp = Test-Endpoint -Url "http://127.0.0.1:8080/api/recommend/movie?userId=$UserId&topN=1"
    if (-not ($algorithmUp -and $backendUp)) {
        if (!(Test-Path $startScript)) {
            throw "Missing startup script: $startScript"
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $startScript
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to auto start local fullstack, exit code: $LASTEXITCODE"
        }
    } else {
        Write-Host "[INFO] Services already healthy, skip autostart."
    }
}

if (-not $SkipMysqlCheck) {
    Invoke-Test -Name "MySQL connectivity script" -Action {
        if (!(Test-Path $mysqlCheckScript)) {
            throw "Missing script: $mysqlCheckScript"
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $mysqlCheckScript
        if ($LASTEXITCODE -ne 0) {
            throw "check-mysql-local.ps1 exit code: $LASTEXITCODE"
        }
    }
}

Invoke-Test -Name "Algorithm health endpoint" -Action {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/python/health" -Method Get -TimeoutSec 5
    if ($resp.status -ne "ok") {
        throw "Unexpected status: $($resp.status)"
    }
}

Invoke-Test -Name "Recommend API returns data" -Action {
    $url = "http://127.0.0.1:8080/api/recommend/movie?userId=$UserId&topN=3"
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10
    if ($resp.code -ne 0) { throw "code != 0" }
    if ($null -eq $resp.data) { throw "data is null" }
}

Invoke-Test -Name "Rating submit API" -Action {
    $body = @{
        userId  = $UserId
        movieId = $MovieId
        score   = $Score
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/rating/submit" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 10
    if ($resp.code -ne 0) { throw "code != 0" }
}

Invoke-Test -Name "Recommend API after rating submit" -Action {
    $url = "http://127.0.0.1:8080/api/recommend/movie?userId=$UserId&topN=5"
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10
    if ($resp.code -ne 0) { throw "code != 0" }
    if ($null -eq $resp.data) { throw "data is null" }
}

if (-not $SkipLlmCheck) {
    Invoke-Test -Name "LLM query API" -Action {
        $body = @{
            userId    = $UserId
            queryText = $LlmQuery
        } | ConvertTo-Json
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/llm/query" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
        if ($resp.code -ne 0) { throw "code != 0" }
        if ([string]::IsNullOrWhiteSpace($resp.responseText)) { throw "responseText empty" }
    }
}

$passCount = @($results | Where-Object { $_.Passed }).Count
$failCount = @($results | Where-Object { -not $_.Passed }).Count

Write-Host ""
Write-Host "== Test Summary =="
$results | ForEach-Object {
    $flag = if ($_.Passed) { "PASS" } else { "FAIL" }
    Write-Host "[$flag] $($_.Name) - $($_.Detail)"
}
Write-Host "Total: $($results.Count), Passed: $passCount, Failed: $failCount"

if ($failCount -gt 0) {
    exit 1
}
exit 0
