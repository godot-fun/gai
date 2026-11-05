# Launch the standalone code editor. Usage: .\shell\editor.ps1  |  .\shell\editor.ps1 --data-dir .gai
# The data folder defaults to <workspace>\.gai2; pass --data-dir <workspace-relative path> to change it.
# Starts the editor main scene in a new Godot window.

param(
	# Extra arguments are forwarded to Godot as user args (after `--`), e.g. --data-dir <path>.
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$Rest
)

$ErrorActionPreference = "Stop"

$DefaultDataDir = ".gai2"
$PortableAppDataDir = ".godot/app/editor"

. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "console-steps.ps1")
Initialize-LaunchSteps -StepTotal 1

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$env:APPDATA = Join-Path $Root $PortableAppDataDir

$Editor = Resolve-GodotEditorPath -ProjectRoot $Root

$UserArgs = @($Rest | Where-Object { $null -ne $_ })
if (-not ($UserArgs -match '^--data-dir(=.*)?$')) {
	$UserArgs = @("--data-dir", $DefaultDataDir) + $UserArgs
}

$MainScene = "res://agent/app/editor/Editor.tscn"
$ArgumentList = @("--path", $Root, $MainScene, "--") + $UserArgs

Write-Step ("Start editor ({0} {1})" -f $MainScene, ($UserArgs -join " "))
Write-StepDone "started" "new window"

Release-LaunchConsole
Start-Process -FilePath $Editor -ArgumentList $ArgumentList -WorkingDirectory $Root
exit 0
