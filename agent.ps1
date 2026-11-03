# Launch the agent desktop app. Usage: .\agent.ps1  |  .\agent.ps1 -Wait  |  .\agent.ps1 --data-dir .gai3
# The data folder defaults to <workspace>\.gai2; pass --data-dir <workspace-relative path> to change it.
# Every launch first pulls the latest code, then syncs the import cache (~4 s), then starts the app.

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
# Update code from git
# ---------------------------------------------------------------------------
# Runs before the import step so assets and scripts pulled in this launch are
# imported by the same run. Never blocks startup: a missing git, a dirty tree,
# a detached HEAD, or an unreachable remote only prints a warning and the app
# starts from the local checkout. Fast-forward only — a diverged branch is left
# alone instead of creating a merge commit or overwriting local work.

$Git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $Git) {
	Write-Host "git not found, starting from local code"
} else {
	# Git writes expected states ("not a git repository", diverged pull) to stderr.
	# $ErrorActionPreference = "Stop" turns that into a terminating error, so relax
	# it around the git calls and merge stderr into captured text instead.
	# GIT_TERMINAL_PROMPT=0 keeps a private remote from blocking on a credential
	# prompt: it fails fast and the app starts from the local checkout.
	$PreviousPreference = $ErrorActionPreference
	$PreviousPrompt = $env:GIT_TERMINAL_PROMPT
	$ErrorActionPreference = "Continue"
	$env:GIT_TERMINAL_PROMPT = "0"
	Push-Location $Root
	try {
		$Branch = (& $Git.Source rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
		$IsRepo = $LASTEXITCODE -eq 0
		if (-not $IsRepo) {
			Write-Host "Not a git checkout, starting from local code"
		} elseif ($Branch -eq "HEAD") {
			Write-Host "Detached HEAD, skipping git update"
		} else {
			# No dirty-tree check: --ff-only already aborts (leaving files untouched)
			# when incoming commits would overwrite local edits.
			Write-Host "Updating code: git pull --ff-only"
			& $Git.Source pull --ff-only
			if ($LASTEXITCODE -ne 0) {
				Write-Host "git pull failed (offline, dirty tree, or diverged branch), starting from local code"
			}
		}
	} finally {
		Pop-Location
		$env:GIT_TERMINAL_PROMPT = $PreviousPrompt
		$ErrorActionPreference = $PreviousPreference
	}
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

# Small safety margin so the OS finishes flushing .godot before the app maps it.
Start-Sleep -Seconds 1

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
		& $Editor @ArgumentList
		exit $LASTEXITCODE
	} finally {
		Pop-Location
	}
}

Start-Process -FilePath $Editor -ArgumentList $ArgumentList -WorkingDirectory $Root
exit 0
