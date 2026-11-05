# Sync .cursor, .ai, cli, zfoo, AGENTS.md, and opencode.json from godot-fun/godot-framework into this project.
# Usage (from project root):
#   .\sync-godot-framework.ps1

param(
	[string]$RepoUrl = "https://github.com/godot-fun/godot-framework.git"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path $PSScriptRoot
$TempRoot = Join-Path $env:TEMP ("godot-framework-sync-{0}" -f [guid]::NewGuid().ToString("N"))
$CloneDir = $TempRoot

New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

function Remove-TempRoot {
	if (Test-Path $TempRoot) {
		Write-Host "Cleaning up temporary directory: $TempRoot"
		Remove-Item -Path $TempRoot -Recurse -Force
	}
}

function Copy-DirReplace {
	param(
		[string]$Source,
		[string]$Destination
	)

	if (-not (Test-Path $Source)) {
		throw "Directory not found: $Source"
	}

	Write-Host "Replacing $Destination"
	if (Test-Path $Destination) {
		Remove-Item -Path $Destination -Recurse -Force
	}
	Copy-Item -Path $Source -Destination $Destination -Recurse -Force
}

function Copy-DirOverlay {
	param(
		[string]$Source,
		[string]$Destination
	)

	if (-not (Test-Path $Source)) {
		throw "Directory not found: $Source"
	}

	Write-Host "Overlaying $Destination"
	if (-not (Test-Path $Destination)) {
		New-Item -ItemType Directory -Path $Destination -Force | Out-Null
	}
	Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Copy-FileReplace {
	param(
		[string]$Source,
		[string]$Destination
	)

	if (-not (Test-Path $Source)) {
		throw "File not found: $Source"
	}

	Write-Host "Replacing $Destination"
	Copy-Item -Path $Source -Destination $Destination -Force
}

function Copy-FrameworkDirs {
	param(
		[string]$SourceRoot
	)

	Copy-DirOverlay -Source (Join-Path $SourceRoot ".cursor") -Destination (Join-Path $ProjectRoot ".cursor")
	Copy-DirOverlay -Source (Join-Path $SourceRoot ".ai") -Destination (Join-Path $ProjectRoot ".ai")
	Copy-DirOverlay -Source (Join-Path $SourceRoot "cli") -Destination (Join-Path $ProjectRoot "cli")
	Copy-DirReplace -Source (Join-Path $SourceRoot "zfoo") -Destination (Join-Path $ProjectRoot "zfoo")
	Copy-FileReplace -Source (Join-Path $SourceRoot "AGENTS.md") -Destination (Join-Path $ProjectRoot "AGENTS.md")
	Copy-FileReplace -Source (Join-Path $SourceRoot "opencode.json") -Destination (Join-Path $ProjectRoot "opencode.json")
}

try {
	Write-Host "Cloning $RepoUrl ..."
	git clone --depth 1 $RepoUrl $CloneDir
	if ($LASTEXITCODE -ne 0) {
		throw "git clone failed with exit code $LASTEXITCODE"
	}

	Copy-FrameworkDirs -SourceRoot $CloneDir

	Write-Host "Sync completed."
} catch {
	Write-Error $_
	exit 1
} finally {
	Remove-TempRoot
}
