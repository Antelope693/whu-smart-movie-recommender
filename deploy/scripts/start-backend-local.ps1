$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendDir = Join-Path $repoRoot "backend"
$envFile = Join-Path $backendDir ".env"

if (!(Test-Path $envFile)) {
    Write-Error "Missing $envFile. Copy .env.example to .env first."
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line.Split("=", 2)
    if ($parts.Length -eq 2) {
        [System.Environment]::SetEnvironmentVariable($parts[0], $parts[1], "Process")
    }
}

Set-Location $backendDir
mvn -DskipTests package
java -jar ".\target\movie-backend-0.0.1-SNAPSHOT.jar"
