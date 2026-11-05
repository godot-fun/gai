# Numbered console steps for shell launchers: "[n/N] title" then "[n/N] done in 4.1s".
# Plain ASCII only — Windows PowerShell 5.1 has no $PSStyle; box-drawing chars mojibake in the default code page.
# Dot-source: . (Join-Path $PSScriptRoot "console-steps.ps1"); Initialize-LaunchSteps -StepTotal 3

function Initialize-LaunchSteps {
	param(
		[Parameter(Mandatory = $true)]
		[int]$StepTotal
	)

	$script:StepTotal = $StepTotal
	$script:StepIndex = 0
}

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
