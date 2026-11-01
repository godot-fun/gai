# Launch agent scene; Godot editor path from .dependency/manifest.json (godot.bin).
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location -LiteralPath $root

$manifestPath = Join-Path $root ".dependency\manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Error "Missing .dependency/manifest.json. See agent/Dependency.md"
    exit 1
}

$godot = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).godot
if ($null -eq $godot -or -not $godot.populated) {
    Write-Error "godot is not populated in .dependency/manifest.json. See agent/Dependency.md"
    exit 1
}

$rel = [string]$godot.bin -replace "/", "\"
$editor = Join-Path $root $rel
if (-not (Test-Path -LiteralPath $editor)) {
    Write-Error "Godot editor not found: $editor"
    exit 1
}

Start-Process -LiteralPath $editor -ArgumentList @("--path", $root, "res://agent/Agent.tscn")
