<#
.SYNOPSIS
    Tests reference data export functionality.

.DESCRIPTION
    This regression test validates the reference data export workflow without storing
    server names, database names, table names, or environment-specific paths in the test script.

    The test reads export.yaml from the supplied OutputFolder.

.PARAMETER OutputFolder
    The external export folder that contains export.yaml.

.EXAMPLE
    .\tests\Test-ReferenceDataRegression.ps1 -OutputFolder 'C:\Source\FolderName'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder
)

Clear-Host

Write-Host ''
Write-Host '========================================================='
Write-Host 'Test-ReferenceDataRegression'
Write-Host ("Started: {0}" -f (Get-Date))
Write-Host '========================================================='

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0
$script:Config = $null
$script:Connection = $null
$script:ReferenceDataExportResult = $null
$script:ProfilePath = $null
$script:ResolvedOutputFolder = $null
$script:ReferenceDataEnabled = $false
$script:ConfiguredTables = @()
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:ExporterScriptPath = Join-Path $script:ProjectRoot 'Export-SqlDatabaseDefinition.ps1'
$testFrameworkPath = Join-Path $PSScriptRoot 'TestFramework.ps1'

if (-not (Test-Path -LiteralPath $testFrameworkPath -PathType Leaf)) {
    throw "Test framework was not found: $testFrameworkPath"
}

. $testFrameworkPath

if (-not (Test-Path -LiteralPath $script:ExporterScriptPath -PathType Leaf)) {
    throw "Exporter script was not found: $script:ExporterScriptPath"
}

. $script:ExporterScriptPath

Write-TestStatus -Status INFO -Message 'Starting reference data regression test.'

Invoke-TestStep -Name 'Setup Reference Data Test Context' -ScriptBlock {
    $script:ResolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ResolvedOutputFolder -PathType Container) `
        -Message "Output folder does not exist: $script:ResolvedOutputFolder"

    $script:ProfilePath = Join-Path $script:ResolvedOutputFolder 'export.yaml'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ProfilePath -PathType Leaf) `
        -Message "export.yaml does not exist: $script:ProfilePath"
}

Invoke-TestStep -Name 'Export-ReferenceData Function Exists' -ScriptBlock {
    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Export-ReferenceData -ErrorAction SilentlyContinue)) `
        -Message 'Export-ReferenceData function was not found.'
}

Invoke-TestStep -Name 'Read-ExportProfile' -ScriptBlock {
    if ([string]::IsNullOrWhiteSpace($script:ProfilePath)) {
        Skip-TestStep -Message 'Setup did not provide a profile path.'
    }

    $script:Config = Read-ExportProfile -Path $script:ProfilePath

    Assert-Condition `
        -Condition ($null -ne $script:Config) `
        -Message 'Read-ExportProfile returned null.'

    Assert-Condition `
        -Condition ($script:Config.Contains('referenceData')) `
        -Message 'Configuration does not contain a referenceData section.'

    $referenceDataSection = $script:Config['referenceData']
    Assert-Condition `
        -Condition ($referenceDataSection -is [System.Collections.IDictionary]) `
        -Message 'referenceData section is not a mapping object.'

    if ($referenceDataSection.Contains('enabled') -and $null -ne $referenceDataSection['enabled']) {
        $script:ReferenceDataEnabled = [bool]$referenceDataSection['enabled']
    }

    if ($referenceDataSection.Contains('tables') -and $null -ne $referenceDataSection['tables'] -and $referenceDataSection['tables'] -is [System.Collections.IEnumerable] -and $referenceDataSection['tables'] -isnot [string]) {
        $script:ConfiguredTables = @($referenceDataSection['tables'])
    }
    else {
        $script:ConfiguredTables = @()
    }
}

Invoke-TestStep -Name 'Connect-SqlDatabase' -ScriptBlock {
    if ($null -eq $script:Config) {
        Skip-TestStep -Message 'Read-ExportProfile did not produce a valid config object.'
    }

    $script:Connection = Connect-SqlDatabase -Config $script:Config

    Assert-Condition `
        -Condition ($null -ne $script:Connection) `
        -Message 'Connect-SqlDatabase returned null.'

    Assert-Condition `
        -Condition ($script:Connection.Connected -eq $true) `
        -Message 'Connect-SqlDatabase did not return Connected = True.'

    Assert-Condition `
        -Condition ($null -ne $script:Connection.DatabaseObject) `
        -Message 'Connection does not contain a DatabaseObject.'
}

Invoke-TestStep -Name 'Export-ReferenceData' -ScriptBlock {
    if ($null -eq $script:Config) {
        Skip-TestStep -Message 'Read-ExportProfile did not produce a valid config object.'
    }

    if ($null -eq $script:Connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $script:ReferenceDataExportResult = Export-ReferenceData `
        -Config $script:Config `
        -Connection $script:Connection `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $script:ReferenceDataExportResult) `
        -Message 'Export-ReferenceData returned null.'

    foreach ($propertyName in @('Enabled', 'TableCount', 'ExportedFiles')) {
        Assert-Condition `
            -Condition ($null -ne $script:ReferenceDataExportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-ReferenceData result is missing {0}." -f $propertyName)
    }
}

Invoke-TestStep -Name 'Validate Reference Data Export' -ScriptBlock {
    if ($null -eq $script:ReferenceDataExportResult) {
        Skip-TestStep -Message 'Export-ReferenceData did not complete successfully.'
    }

    $resultEnabled = [bool]$script:ReferenceDataExportResult.Enabled
    $tableCount = [int]$script:ReferenceDataExportResult.TableCount
    $exportedFiles = @($script:ReferenceDataExportResult.ExportedFiles)

    if (-not $resultEnabled) {
        Assert-Condition `
            -Condition ($tableCount -eq 0) `
            -Message 'When reference data export is disabled, TableCount must be 0.'

        Assert-Condition `
            -Condition ($exportedFiles.Count -eq 0) `
            -Message 'When reference data export is disabled, ExportedFiles must be empty.'

        Write-TestStatus -Status INFO -Message 'Reference data export is disabled by configuration. Validation passed.'
        return
    }

    if ($script:ConfiguredTables.Count -gt 0) {
        Assert-Condition `
            -Condition ($tableCount -eq $script:ConfiguredTables.Count) `
            -Message ("TableCount mismatch. Expected {0}, found {1}." -f $script:ConfiguredTables.Count, $tableCount)
    }

    if ($script:ConfiguredTables.Count -gt 0) {
        $referenceDataFolder = Join-Path $script:ResolvedOutputFolder 'ReferenceData'

        Assert-Condition `
            -Condition (Test-Path -LiteralPath $referenceDataFolder -PathType Container) `
            -Message "ReferenceData folder was not created: $referenceDataFolder"
    }

    if ($exportedFiles.Count -eq 0) {
        Write-TestStatus -Status WARN -Message 'No reference data files were exported. This may be expected when no tables are configured.'
        return
    }

    $fileContents = [System.Collections.Generic.List[string]]::new()

    foreach ($filePath in $exportedFiles) {
        Assert-Condition `
            -Condition (-not [string]::IsNullOrWhiteSpace([string]$filePath)) `
            -Message 'ExportedFiles contains an empty path value.'

        Assert-Condition `
            -Condition (Test-Path -LiteralPath $filePath -PathType Leaf) `
            -Message "Exported file does not exist: $filePath"

        $rawContent = Get-Content -LiteralPath $filePath -Raw

        Assert-Condition `
            -Condition (-not [string]::IsNullOrWhiteSpace($rawContent)) `
            -Message "Exported file is empty: $filePath"

        [void]$fileContents.Add($rawContent)
    }

    $containsInsertInto = $false
    $containsNoRowsMessage = $false
    $allFilesIndicateNoRows = $true

    foreach ($rawContent in $fileContents) {
        if ($rawContent -match 'INSERT\s+INTO') {
            $containsInsertInto = $true
        }

        if ($rawContent -match [regex]::Escape('No rows exported.')) {
            $containsNoRowsMessage = $true
        }
        else {
            $allFilesIndicateNoRows = $false
        }
    }

    if (-not $allFilesIndicateNoRows) {
        Assert-Condition `
            -Condition ($containsInsertInto) `
            -Message 'At least one exported file should contain INSERT INTO when rows are exported.'
    }

    if ($containsNoRowsMessage) {
        Write-TestStatus -Status INFO -Message 'Detected one or more tables with zero rows (No rows exported.).'
    }
}

Write-Host ''
Write-Host '========================================================='
Write-Host 'Summary'
Write-Host '========================================================='
Write-Host ("Passed:  {0}" -f $script:TestsPassed)
Write-Host ("Failed:  {0}" -f $script:TestsFailed)
Write-Host ("Skipped: {0}" -f $script:TestsSkipped)

if ($script:TestsFailed -gt 0) {
    exit 1
}

exit 0
