# Shared helpers for shell launchers. Dot-source: . (Join-Path $PSScriptRoot "common.ps1")

function Resolve-GodotEditorPath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ProjectRoot
	)

	$ManifestPath = Join-Path $ProjectRoot ".dependency\manifest.json"

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

	$EditorPath = Join-Path $ProjectRoot ($GodotEntry.bin -replace "/", "\")
	if (-not (Test-Path -LiteralPath $EditorPath)) {
		Write-Host "Godot editor not found: $EditorPath" -ForegroundColor Red
		exit 1
	}

	return $EditorPath
}

function Release-LaunchConsole {
	# Godot calls AttachConsole on its parent at startup and would keep the launcher window open.
	try {
		Add-Type -Namespace Win32 -Name Kernel32Console -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern bool FreeConsole();'
		[Win32.Kernel32Console]::FreeConsole() | Out-Null
	} catch {
	}
}
