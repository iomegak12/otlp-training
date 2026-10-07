# Put the whole lab back in the starting ("problem") state for all nine scenarios.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
function Copy-Tree([string]$Source) {
    # Copies every file under $Source (including .env) to the same relative path in the lab folder.
    $root = (Resolve-Path $Source).Path
    Get-ChildItem -Path $root -Recurse -File -Force | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length + 1)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path (Get-Location) $relative)) | Out-Null
        Copy-Item -Path $_.FullName -Destination (Join-Path (Get-Location) $relative) -Force
        Write-Host "  $relative"
    }
}

Copy-Tree 'scenarios\00-start'
try { docker compose unpause tempo 2>$null } catch { }
docker compose up -d
docker compose restart otel-agent tempo
Invoke-WebRequest -Method Post -Uri http://localhost:9090/-/reload -UseBasicParsing | Out-Null
Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/admin/chaos?latencyMs=0&errorRate=0' -UseBasicParsing | Out-Null
docker compose run --rm fleet scale 3
Write-Host "Lab reset to the starting state."
