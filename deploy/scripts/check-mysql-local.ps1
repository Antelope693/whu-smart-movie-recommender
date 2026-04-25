param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"

function Get-JdbcUrlParts {
    param([string]$JdbcUrl)
    $result = @{
        Host = "127.0.0.1"
        Port = 3306
        Database = "movie_recommender"
    }
    if ([string]::IsNullOrWhiteSpace($JdbcUrl)) {
        return $result
    }
    if ($JdbcUrl -match '^jdbc:mysql://([^:/\?]+)(?::(\d+))?/([^?\s]+)') {
        $result.Host = $matches[1]
        if ($matches[2]) { $result.Port = [int]$matches[2] }
        $result.Database = $matches[3]
    }
    return $result
}

function Get-EnvMap {
    param([string]$Path)
    $map = @{}
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $parts = $line.Split("=", 2)
        if ($parts.Length -eq 2) {
            $map[$parts[0]] = $parts[1]
        }
    }
    return $map
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $repoRoot "backend\.env"
}
if (!(Test-Path $EnvFile)) {
    throw "Missing env file: $EnvFile"
}

$envMap = Get-EnvMap -Path $EnvFile
$jdbcUrl = $envMap["MYSQL_URL"]
$mysqlUser = $envMap["MYSQL_USER"]
$mysqlPassword = $envMap["MYSQL_PASSWORD"]
$jdbc = Get-JdbcUrlParts -JdbcUrl $jdbcUrl

Write-Host "== MySQL Local Check =="
Write-Host "env file: $EnvFile"
Write-Host "target  : $($jdbc.Host):$($jdbc.Port)/$($jdbc.Database)"

$tcpOk = $false
try {
    $tcp = Test-NetConnection -ComputerName $jdbc.Host -Port $jdbc.Port -WarningAction SilentlyContinue
    $tcpOk = [bool]$tcp.TcpTestSucceeded
} catch {
    $tcpOk = $false
}
if ($tcpOk) {
    Write-Host "[OK] TCP reachable."
} else {
    Write-Host "[ERR] TCP unreachable. Check MySQL service/port/firewall."
}

$mysqlCmd = Get-Command mysql -ErrorAction SilentlyContinue
if ($null -eq $mysqlCmd) {
    Write-Host "[WARN] mysql client not found in PATH; skipping auth/database checks."
    exit 0
}

$myIni = Join-Path $env:TEMP "mysql-check.cnf"
@"
[client]
host=$($jdbc.Host)
port=$($jdbc.Port)
user=$mysqlUser
password=$mysqlPassword
"@ | Set-Content $myIni -Encoding ascii

$authOk = $true
try {
    & $mysqlCmd.Source --defaults-extra-file="$myIni" -e "SELECT 1;" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mysql command exit code: $LASTEXITCODE" }
    Write-Host "[OK] MySQL auth check passed."
} catch {
    $authOk = $false
    Write-Host "[ERR] MySQL auth check failed. Verify MYSQL_USER / MYSQL_PASSWORD."
}

if ($authOk) {
    try {
        $dbExists = & $mysqlCmd.Source --defaults-extra-file="$myIni" -N -s -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$($jdbc.Database)';"
        if ($LASTEXITCODE -ne 0) { throw "mysql command exit code: $LASTEXITCODE" }
        if ($dbExists -eq $jdbc.Database) {
            Write-Host "[OK] Database exists: $($jdbc.Database)"
        } else {
            Write-Host "[ERR] Database missing: $($jdbc.Database)"
            Write-Host "      Fix: CREATE DATABASE $($jdbc.Database) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        }
    } catch {
        Write-Host "[WARN] Could not verify database existence."
    }
}

Remove-Item $myIni -Force -ErrorAction SilentlyContinue
Write-Host "== Check complete =="
