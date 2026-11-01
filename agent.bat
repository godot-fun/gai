@echo off
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$root = (Get-Location).Path;" ^
  "$manifestPath = Join-Path $root '.dependency\manifest.json';" ^
  "if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Host 'Missing .dependency/manifest.json. See agent/Dependency.md'; exit 1 };" ^
  "$godot = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).godot;" ^
  "if ($null -eq $godot -or -not $godot.populated) { Write-Host 'godot is not populated in .dependency/manifest.json. See agent/Dependency.md'; exit 1 };" ^
  "$editor = Join-Path $root ($godot.bin -replace '/', '\');" ^
  "if (-not (Test-Path -LiteralPath $editor)) { Write-Host \"Godot editor not found: $editor\"; exit 1 };" ^
  "Start-Process -FilePath $editor -ArgumentList @('--path', $root, 'res://agent/Agent.tscn')"

if errorlevel 1 pause
exit /b %ERRORLEVEL%
