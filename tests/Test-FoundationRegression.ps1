<#
.SYNOPSIS
    Runs the current regression workflow for Export-SqlDatabaseDefinition.

.DESCRIPTION
    This script tests the current development workflow without storing server,
    database, or environment-specific details in the test file.

    The test reads export.yaml from the supplied OutputFolder.

.PARAMETER OutputFolder
    The external export folder that contains export.yaml.

.EXAMPLE
    .\tests\Test-FoundationRegression.ps1 -OutputFolder 'C:\Source\FolderName'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-TestStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PASS', 'FAIL', 'INFO', 'WARN', 'SKIP')]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $prefix = "[{0}]" -f $Status
    Write-Host "$prefix $Message"
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

$script:testsPassed = 0
$script:testsFailed = 0
$script:testsSkipped = 0

$script:resolvedOutputFolder = $null
$script:profilePath = $null
$script:config = $null
$script:connection = $null
$script:projectRoot = $null
$script:scriptPath = $null

function Skip-TestStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    throw [System.OperationCanceledException]::new($Message)
}

function Invoke-TestStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock
    )

    Write-TestStatus -Status INFO -Message ("Running: {0}" -f $Name)

    try {
        & $ScriptBlock
        $script:testsPassed++
        Write-TestStatus -Status PASS -Message $Name
    }
    catch [System.OperationCanceledException] {
        $script:testsSkipped++
        Write-TestStatus -Status SKIP -Message $Name
        Write-TestStatus -Status SKIP -Message $_.Exception.Message
    }
    catch {
        $script:testsFailed++
        Write-TestStatus -Status FAIL -Message $Name
        Write-TestStatus -Status FAIL -Message $_.Exception.Message
    }
}

Clear-Host
Write-TestStatus -Status INFO -Message 'Starting current workflow regression test.'

Invoke-TestStep -Name 'Setup Regression Context' -ScriptBlock {
    $script:projectRoot = Split-Path -Parent $PSScriptRoot
    $script:scriptPath = Join-Path $script:projectRoot 'Export-SqlDatabaseDefinition.ps1'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:scriptPath -PathType Leaf) `
        -Message "Could not find Export-SqlDatabaseDefinition.ps1 at: $script:scriptPath"

    . $script:scriptPath

    $script:resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:resolvedOutputFolder -PathType Container) `
        -Message "Output folder does not exist: $script:resolvedOutputFolder"

    $script:profilePath = Join-Path $script:resolvedOutputFolder 'export.yaml'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:profilePath -PathType Leaf) `
        -Message "export.yaml does not exist: $script:profilePath"
}

Invoke-TestStep -Name 'Test-ExportDependencies' -ScriptBlock {
    if (-not (Get-Command -Name Test-ExportDependencies -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Test-ExportDependencies function was not found.'
    }

    $dependencyResult = Test-ExportDependencies

    Assert-Condition `
        -Condition ($null -ne $dependencyResult) `
        -Message 'Test-ExportDependencies returned null.'

    Assert-Condition `
        -Condition ($dependencyResult.IsValid -eq $true) `
        -Message 'Required export dependencies are not valid.'
}

Invoke-TestStep -Name 'Read-ExportProfile' -ScriptBlock {
    if (-not (Get-Command -Name Read-ExportProfile -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Read-ExportProfile function was not found.'
    }

    if ([string]::IsNullOrWhiteSpace($script:profilePath)) {
        Skip-TestStep -Message 'Setup did not provide a profile path.'
    }

    $script:config = Read-ExportProfile -Path $script:profilePath

    Assert-Condition `
        -Condition ($null -ne $script:config) `
        -Message 'Read-ExportProfile returned null.'

    Assert-Condition `
        -Condition ($script:config.Contains('connection')) `
        -Message 'Configuration does not contain a connection section.'

    Assert-Condition `
        -Condition (-not [string]::IsNullOrEmpty($script:config['connection']['server'])) `
        -Message 'connection.server is empty.'

    Assert-Condition `
        -Condition (-not [string]::IsNullOrEmpty($script:config['connection']['database'])) `
        -Message 'connection.database is empty.'

    Assert-Condition `
        -Condition (-not [string]::IsNullOrEmpty($script:config['connection']['authentication'])) `
        -Message 'connection.authentication is empty.'
}

Invoke-TestStep -Name 'Connect-SqlDatabase' -ScriptBlock {
    if (-not (Get-Command -Name Connect-SqlDatabase -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Connect-SqlDatabase function was not found.'
    }

    if ($null -eq $script:config) {
        Skip-TestStep -Message 'Read-ExportProfile did not produce a valid config object.'
    }

    $script:connection = Connect-SqlDatabase -Config $script:config

    Assert-Condition `
        -Condition ($null -ne $script:connection) `
        -Message 'Connect-SqlDatabase returned null.'

    Assert-Condition `
        -Condition ($script:connection.Connected -eq $true) `
        -Message 'Connect-SqlDatabase did not return Connected = True.'

    Assert-Condition `
        -Condition ($null -ne $script:connection.DatabaseObject) `
        -Message 'Connection did not include a DatabaseObject.'
}

Invoke-TestStep -Name 'export.log' -ScriptBlock {
    if (-not (Get-Command -Name Initialize-ExportLog -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Initialize-ExportLog function was not found.'
    }

    if ([string]::IsNullOrWhiteSpace($script:resolvedOutputFolder)) {
        Skip-TestStep -Message 'Setup did not provide an output folder.'
    }

    $logPath = Initialize-ExportLog -OutputFolder $script:resolvedOutputFolder

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $logPath -PathType Leaf) `
        -Message "export.log was not created: $logPath"

    Write-Log -Level Information -Message 'Regression test log entry.'
}

Invoke-TestStep -Name 'exportinfo.json' -ScriptBlock {
    if (-not (Get-Command -Name Write-ExportInfo -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Write-ExportInfo function was not found.'
    }

    if ($null -eq $script:config) {
        Skip-TestStep -Message 'Read-ExportProfile did not produce a valid config object.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    Write-ExportInfo `
        -Config $script:config `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder | Out-Null

    $exportInfoPath = Join-Path $script:resolvedOutputFolder 'exportinfo.json'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $exportInfoPath -PathType Leaf) `
        -Message "exportinfo.json was not created: $exportInfoPath"

    $exportInfo = Get-Content -LiteralPath $exportInfoPath -Raw | ConvertFrom-Json

    Assert-Condition `
        -Condition ($exportInfo.databaseName -eq $script:connection.DatabaseName) `
        -Message 'exportinfo.json databaseName does not match the connection database.'
}

Invoke-TestStep -Name 'Export-DatabaseProperties' -ScriptBlock {
    if (-not (Get-Command -Name Export-DatabaseProperties -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-DatabaseProperties function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    Export-DatabaseProperties `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder | Out-Null

    $databaseFolderPath = Join-Path $script:resolvedOutputFolder 'Database'
    $databasePropertiesPath = Join-Path $databaseFolderPath 'Database.sql'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $databaseFolderPath -PathType Container) `
        -Message "Database folder was not created: $databaseFolderPath"

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $databasePropertiesPath -PathType Leaf) `
        -Message "Database.sql was not created: $databasePropertiesPath"

    $databaseContent = Get-Content -LiteralPath $databasePropertiesPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($databaseContent)) `
        -Message 'Database.sql is empty.'
}

Write-Host ''
Write-Host '----------------------------------------'
Write-Host 'Regression Test Summary'
Write-Host '----------------------------------------'
Write-Host ''
Write-Host ('Passed:   {0}' -f $script:testsPassed)
Write-Host ('Failed:   {0}' -f $script:testsFailed)
Write-Host ('Skipped:  {0}' -f $script:testsSkipped)

if ($script:testsFailed -gt 0) {
    exit 1
}

exit 0
