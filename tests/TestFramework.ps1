function Write-TestStatus {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet('PASS', 'FAIL', 'INFO', 'WARN', 'SKIP')]
		[string]$Status,

		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	Write-Host ("[{0}] {1}" -f $Status, $Message)
}

function Assert-Condition {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[bool]$Condition,

		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	if (-not $Condition) {
		throw $Message
	}
}

function Skip-TestStep {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	throw [System.OperationCanceledException]::new($Message)
}

function Add-TestCounter {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Passed', 'Failed', 'Skipped')]
		[string]$Counter
	)

	$counterNames = switch ($Counter) {
		'Passed' { @('TestsPassed', 'testsPassed') }
		'Failed' { @('TestsFailed', 'testsFailed') }
		'Skipped' { @('TestsSkipped', 'testsSkipped') }
		default { @() }
	}

	foreach ($counterName in $counterNames) {
		$counterVariable = Get-Variable -Scope Script -Name $counterName -ErrorAction SilentlyContinue
		if ($null -ne $counterVariable) {
			Set-Variable -Scope Script -Name $counterName -Value ([int]$counterVariable.Value + 1)
			return
		}
	}

	throw [System.InvalidOperationException]::new(("Required script counter is not initialized for '{0}'." -f $Counter))
}

function Invoke-TestStep {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,

		[Parameter(Mandatory = $true)]
		[scriptblock]$ScriptBlock
	)

	Write-TestStatus -Status INFO -Message ("Running: {0}" -f $Name)

	try {
		& $ScriptBlock
		Add-TestCounter -Counter Passed
		Write-TestStatus -Status PASS -Message $Name
	}
	catch [System.OperationCanceledException] {
		Add-TestCounter -Counter Skipped
		Write-TestStatus -Status SKIP -Message $Name
		Write-TestStatus -Status SKIP -Message $_.Exception.Message
	}
	catch {
		Add-TestCounter -Counter Failed
		Write-TestStatus -Status FAIL -Message $Name
		Write-TestStatus -Status FAIL -Message $_.Exception.Message
	}
}
