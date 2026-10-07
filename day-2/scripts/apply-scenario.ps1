# Jump to the finished state of a scenario (use it if a live demo goes wrong).
#   .\scripts\apply-scenario.ps1 -Scenario 4      # state after scenario 4 (1-9)
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 9)]
    [int]$Scenario
)
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

$dir = Get-ChildItem -Directory "scenarios" | Where-Object { $_.Name -like "0$Scenario-*" } | Select-Object -First 1
Write-Host "Applying $($dir.Name)\after"
Copy-Tree (Join-Path $dir.FullName 'after')
docker compose up -d eod-reconciliation otel-agent
docker compose restart otel-agent tempo
Invoke-WebRequest -Method Post -Uri http://localhost:9090/-/reload -UseBasicParsing | Out-Null
Write-Host "Prometheus configuration reloaded. Now at the end of scenario $Scenario."
