# Bring your lab folder to the finished state of a lab, then rebuild and restart the stack.
#
#   .\scripts\catch-up.ps1 -Lab b     # state after Lab B (also c, d or e)
#
# Your own edits to the copied files are overwritten. Files not in the snapshot are left alone.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('b', 'c', 'd', 'e')]
    [string]$Lab
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$source = "solutions/after-lab-$Lab"
Write-Host "Copying $source into the lab folder:"
Get-ChildItem -Path $source -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring((Resolve-Path $source).Path.Length + 1)
    $target = Join-Path (Get-Location) $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -Path $_.FullName -Destination $target -Force
    Write-Host "  $relative"
}

Write-Host "Rebuilding and restarting (the load generator is included) ..."
docker compose --profile load up -d --build
