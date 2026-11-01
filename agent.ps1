# Launch the agent desktop app. Usage: .\agent.ps1  |  .\agent.ps1 -Wait

param(
	[switch]$Wait
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Portable user:// under .godot
# ---------------------------------------------------------------------------
# Godot has no CLI flag for user://. Set APPDATA before start so user data stays
# in the repo: .godot\Godot\app_userdata\<config/name>\ (see project.godot).
# Opening Godot without this script uses the real OS %APPDATA% instead.

$Root = $PSScriptRoot
$env:APPDATA = Join-Path $Root ".godot"

# ---------------------------------------------------------------------------
# Resolve Godot editor from dependency manifest
# ---------------------------------------------------------------------------
# Binary path: .dependency/manifest.json -> godot.bin (setup: agent/Dependency.md).

$ManifestPath = Join-Path $Root ".dependency\manifest.json"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
	Write-Host "Missing .dependency/manifest.json. See agent/Dependency.md"
	exit 1
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$GodotEntry = $Manifest.godot
if ($null -eq $GodotEntry -or -not $GodotEntry.populated) {
	Write-Host "godot is not populated in .dependency/manifest.json. See agent/Dependency.md"
	exit 1
}

$Editor = Join-Path $Root ($GodotEntry.bin -replace "/", "\")
if (-not (Test-Path -LiteralPath $Editor)) {
	Write-Host "Godot editor not found: $Editor"
	exit 1
}

# ---------------------------------------------------------------------------
# Start agent main scene
# ---------------------------------------------------------------------------
# Default: new process (same as agent.bat). -Wait: run in this console + exit code.

$ArgumentList = @("--path", $Root, "res://agent/Agent.tscn")

if ($Wait) {
	Push-Location $Root
	try {
		& $Editor @ArgumentList
		exit $LASTEXITCODE
	} finally {
		Pop-Location
	}
}

Start-Process -FilePath $Editor -ArgumentList $ArgumentList -WorkingDirectory $Root
exit 0
