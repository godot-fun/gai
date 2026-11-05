# Launch the agent desktop app. Usage: .\agent.ps1  |  .\agent.ps1 --data-dir .gai3
# The data folder defaults to <workspace>\.gai2; pass --data-dir <workspace-relative path> to change it.
# Every launch first pulls the latest code, then syncs the import cache (~4 s), then starts the app.

param(
	# Extra arguments are forwarded to Godot as user args (after `--`), e.g. --data-dir <path>.
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$Rest
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Console step output
# ---------------------------------------------------------------------------
# Three visible steps: update code -> refresh import cache -> start the app.
# Each step prints "[n/3] title" up front and "[n/3] done in 4.1s" when it ends,
# so the walls of subprocess output (git, the Godot import) still have clear
# boundaries. Plain ASCII only: this launcher runs on Windows PowerShell 5.1,
# which has no $PSStyle, and the default console code page turns box-drawing
# characters into mojibake.

$StepTotal = 3
$StepIndex = 0

function Write-Step([string]$Title) {
	$script:StepIndex++
	$script:StepStarted = Get-Date
	Write-Host ""
	Write-Host ("[{0}/{1}] {2}" -f $script:StepIndex, $script:StepTotal, $Title) -ForegroundColor Cyan
}

function Write-StepNote([string]$Message) {
	Write-Host ("       {0}" -f $Message) -ForegroundColor Yellow
}

function Write-StepDone([string]$Status = "done", [string]$Detail = "") {
	$Seconds = ((Get-Date) - $script:StepStarted).TotalSeconds
	$Suffix = ""
	if ($Detail -ne "") {
		$Suffix = " ({0})" -f $Detail
	}
	$Color = switch ($Status) {
		"done" { "Green" }
		"started" { "Green" }
		"skipped" { "Yellow" }
		default { "Red" }
	}
	Write-Host ("[{0}/{1}] {2} in {3:0.0}s{4}" -f $script:StepIndex, $script:StepTotal, $Status, $Seconds, $Suffix) -ForegroundColor $Color
}

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
	Write-Host "Missing .dependency/manifest.json. See agent/Dependency.md" -ForegroundColor Red
	exit 1
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$GodotEntry = $Manifest.godot
if ($null -eq $GodotEntry -or -not $GodotEntry.populated) {
	Write-Host "godot is not populated in .dependency/manifest.json. See agent/Dependency.md" -ForegroundColor Red
	exit 1
}

$Editor = Join-Path $Root ($GodotEntry.bin -replace "/", "\")
if (-not (Test-Path -LiteralPath $Editor)) {
	Write-Host "Godot editor not found: $Editor" -ForegroundColor Red
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

Write-Step "Update code (git pull --ff-only)"

# Only a successful fast-forward counts as "done"; every other outcome starts the
# app from the local checkout and reports itself as "skipped" with a note above.
$PullStatus = "skipped"

$Git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $Git) {
	Write-StepNote "git not found, starting from local code"
} else {
	# GIT_TERMINAL_PROMPT=0 keeps a private remote from blocking on a credential
	# prompt: it fails fast and the app starts from the local checkout.
	# No dirty-tree check: --ff-only already aborts (leaving files untouched)
	# when incoming commits would overwrite local edits. Not a repo, detached
	# HEAD, offline, or a diverged branch fail the same way.
	$PreviousPrompt = $env:GIT_TERMINAL_PROMPT
	$env:GIT_TERMINAL_PROMPT = "0"
	try {
		& $Git.Source -C $Root pull --ff-only
		if ($LASTEXITCODE -eq 0) {
			$PullStatus = "done"
		} else {
			Write-StepNote "git pull failed, starting from local code"
		}
	} finally {
		$env:GIT_TERMINAL_PROMPT = $PreviousPrompt
	}
}

Write-StepDone $PullStatus

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

Write-Step "Refresh import cache (godot --headless --import)"

$ImportProcess = Start-Process -FilePath $Editor -ArgumentList @("--headless", "--path", $Root, "--import") -WorkingDirectory $Root -NoNewWindow -Wait -PassThru
$ImportExit = $ImportProcess.ExitCode

if ($ImportExit -gt 0) {
	Write-StepDone "failed" "exit $ImportExit"
	exit $ImportExit
}

Write-StepDone "done" "exit 0"

# ---------------------------------------------------------------------------
# Start agent main scene
# ---------------------------------------------------------------------------
# Godot calls AttachConsole on its parent at startup and would keep this window
# open. Release the console first, then start the app.
# Everything after `--` reaches the app through OS.get_cmdline_user_args():
#   --data-dir <path>   agent data folder, workspace-relative (default here: .gai2)

$UserArgs = @($Rest | Where-Object { $null -ne $_ })
if (-not ($UserArgs -match '^--data-dir(=.*)?$')) {
	$UserArgs = @("--data-dir", ".gai2") + $UserArgs
}

$ArgumentList = @("--path", $Root, "res://agent/Agent.tscn", "--") + $UserArgs

Write-Step ("Start agent (res://agent/Agent.tscn {0})" -f ($UserArgs -join " "))
Write-StepDone "started" "new window"

try {
	Add-Type -Namespace Win32 -Name Kernel32Console -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern bool FreeConsole();'
	[Win32.Kernel32Console]::FreeConsole() | Out-Null
} catch {
}
Start-Process -FilePath $Editor -ArgumentList $ArgumentList -WorkingDirectory $Root
exit 0
