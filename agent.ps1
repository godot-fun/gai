# Launch the agent desktop app. Usage: .\agent.ps1  |  .\agent.ps1 -Wait  |  .\agent.ps1 --data-dir .gai3
# The data folder defaults to <workspace>\.gai2; pass --data-dir <workspace-relative path> to change it.
# Every launch first syncs the import cache (~4 s), then starts the app.

param(
	[switch]$Wait,

	# Extra arguments are forwarded to Godot as user args (after `--`), e.g. --data-dir <path>.
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$Rest
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
# Refresh import cache
# ---------------------------------------------------------------------------
# Game mode never scans res://, so it only sees what .godot already contains:
# replaced images / audio / fonts stay stale, and new assets or new class_name
# scripts fail to load. Always run `--import` first: it starts the editor
# headless, syncs imports (plus global_script_class_cache.cfg and uid_cache.bin),
# then quits.
#
# Godot ships a GUI-subsystem exe, so `& $Editor ...` returns at once and leaves
# $LASTEXITCODE empty — the app would start while the import is still running.
# Start-Process -Wait blocks until the import process really exits.

Push-Location $Root
try {
	$ImportProcess = Start-Process -FilePath $Editor -ArgumentList @("--headless", "--path", $Root, "--import") `
		-WorkingDirectory $Root -NoNewWindow -Wait -PassThru
	$ImportExit = $ImportProcess.ExitCode
} finally {
	Pop-Location
}

if ($ImportExit -gt 0) {
	Write-Host "Asset import failed (exit $ImportExit)"
	exit $ImportExit
}

# ---------------------------------------------------------------------------
# Start agent main scene
# ---------------------------------------------------------------------------
# Default: new process (same as agent.bat). -Wait: run in this console + exit code.
# Everything after `--` reaches the app through OS.get_cmdline_user_args():
#   --data-dir <path>   agent data folder, workspace-relative (default here: .gai2)

$UserArgs = @($Rest | Where-Object { $null -ne $_ })
if (-not ($UserArgs -match '^--data-dir(=.*)?$')) {
	$UserArgs = @("--data-dir", ".gai2") + $UserArgs
}

$ArgumentList = @("--path", $Root, "res://agent/Agent.tscn", "--") + $UserArgs

if ($Wait) {
	Push-Location $Root
	try {
		# Same GUI-subsystem caveat as the import step: wait for the real process.
		$AppProcess = Start-Process -FilePath $Editor -ArgumentList $ArgumentList `
			-WorkingDirectory $Root -NoNewWindow -Wait -PassThru
		exit $AppProcess.ExitCode
	} finally {
		Pop-Location
	}
}

Start-Process -FilePath $Editor -ArgumentList $ArgumentList -WorkingDirectory $Root
exit 0
