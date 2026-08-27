# Smoke test: export_lab_data.ps1 must exist
$script = Join-Path $PSScriptRoot "..\export_lab_data.ps1"
if (-not (Test-Path $script)) { throw "export_lab_data.ps1 missing" }
Write-Host "OK: export_lab_data.ps1 found"