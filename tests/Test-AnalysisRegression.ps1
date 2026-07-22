<#
.SYNOPSIS
    Tests analysis report export functionality.

.DESCRIPTION
    This regression test validates dependency analysis workflow behavior for
    Export-OrphanedObjectsReport without storing environment-specific details
    in the test script.

    The test reads export.yaml from the supplied OutputFolder.

.PARAMETER OutputFolder
    The external export folder that contains export.yaml.

.EXAMPLE
    .\tests\Test-AnalysisRegression.ps1 -OutputFolder 'C:\Source\FolderName'
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
Write-Host 'Test-AnalysisRegression'
Write-Host ("Started: {0}" -f (Get-Date))
Write-Host '========================================================='

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0
$script:Config = $null
$script:Connection = $null
$script:Dependencies = @()
$script:OrphanedReportResult = $null
$script:ProfilePath = $null
$script:ResolvedOutputFolder = $null
$script:AnalysisFolder = $null
$script:OrphanedReportPath = $null
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

Write-TestStatus -Status INFO -Message 'Starting analysis regression test.'

Invoke-TestStep -Name 'Setup Analysis Test Context' -ScriptBlock {
    $script:ResolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ResolvedOutputFolder -PathType Container) `
        -Message "Output folder does not exist: $script:ResolvedOutputFolder"

    $script:ProfilePath = Join-Path $script:ResolvedOutputFolder 'export.yaml'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ProfilePath -PathType Leaf) `
        -Message "export.yaml does not exist: $script:ProfilePath"

    $script:AnalysisFolder = Join-Path $script:ResolvedOutputFolder 'Analysis'
    $script:OrphanedReportPath = Join-Path $script:AnalysisFolder 'OrphanedObjects.md'
}

Invoke-TestStep -Name 'Export-OrphanedObjectsReport Function Exists' -ScriptBlock {
    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Export-OrphanedObjectsReport -ErrorAction SilentlyContinue)) `
        -Message 'Export-OrphanedObjectsReport function was not found.'
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
        -Condition ($script:Config.Contains('connection')) `
        -Message 'Configuration does not contain a connection section.'
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

Invoke-TestStep -Name 'Get-DatabaseDependencies' -ScriptBlock {
    if ($null -eq $script:Connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    if ($script:Connection.Connected -ne $true) {
        Skip-TestStep -Message 'Connection is not in a connected state.'
    }

    $script:Dependencies = @(
        Get-DatabaseDependencies -Connection $script:Connection
    )

    Assert-Condition `
        -Condition ($script:Dependencies -is [System.Array]) `
        -Message 'Get-DatabaseDependencies did not return an array.'

    Write-TestStatus `
        -Status INFO `
        -Message ("Dependency rows returned: {0}" -f $script:Dependencies.Count)
}

Invoke-TestStep -Name 'Export-OrphanedObjectsReport' -ScriptBlock {
    if ($null -eq $script:Connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    if ($null -eq $script:Dependencies) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not produce dependency data.'
    }

    $script:OrphanedReportResult = Export-OrphanedObjectsReport `
        -Connection $script:Connection `
        -Dependencies $script:Dependencies `
        -OutputFolder $script:ResolvedOutputFolder `
        -Config $script:Config

    Assert-Condition `
        -Condition ($null -ne $script:OrphanedReportResult) `
        -Message 'Export-OrphanedObjectsReport returned null.'

    foreach ($propertyName in @('DependencyCandidateCount', 'SecurityCandidateCount', 'ReferenceDataCandidateCount', 'ReportPath')) {
        Assert-Condition `
            -Condition ($null -ne $script:OrphanedReportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-OrphanedObjectsReport result is missing {0}." -f $propertyName)
    }

    $resultReportPath = [string]$script:OrphanedReportResult.ReportPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($resultReportPath)) `
        -Message 'Export-OrphanedObjectsReport returned an empty ReportPath.'

    $script:OrphanedReportPath = $resultReportPath
}

Invoke-TestStep -Name 'Validate OrphanedObjects Report Output' -ScriptBlock {
    if ($null -eq $script:OrphanedReportResult) {
        Skip-TestStep -Message 'Export-OrphanedObjectsReport did not complete successfully.'
    }

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($script:AnalysisFolder)) `
        -Message 'Analysis folder path is unavailable.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:AnalysisFolder -PathType Container) `
        -Message "Analysis folder does not exist: $script:AnalysisFolder"

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($script:OrphanedReportPath)) `
        -Message 'Orphaned report path is unavailable.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:OrphanedReportPath -PathType Leaf) `
        -Message "OrphanedObjects.md does not exist: $script:OrphanedReportPath"

    $reportContent = Get-Content -LiteralPath $script:OrphanedReportPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($reportContent)) `
        -Message "OrphanedObjects.md is empty: $script:OrphanedReportPath"

    Assert-Condition `
        -Condition ($reportContent -match [regex]::Escape('# Orphaned Object Analysis')) `
        -Message 'Report is missing # Orphaned Object Analysis heading.'

    Assert-Condition `
        -Condition ($reportContent -match [regex]::Escape('## Summary')) `
        -Message 'Report is missing ## Summary heading.'

    Assert-Condition `
        -Condition ($reportContent -match [regex]::Escape('## Dependency-Based Candidates')) `
        -Message 'Report is missing ## Dependency-Based Candidates heading.'

    Assert-Condition `
        -Condition ($reportContent -match [regex]::Escape('## Security Candidates')) `
        -Message 'Report is missing ## Security Candidates heading.'

    Assert-Condition `
        -Condition ($reportContent -match [regex]::Escape('## Reference Data Candidates')) `
        -Message 'Report is missing ## Reference Data Candidates heading.'

    Assert-Condition `
        -Condition ($reportContent -match '(?i)candidate|review') `
        -Message 'Report does not include conservative review language.'

    $containsSafeToDelete = $reportContent -match '(?i)\bsafe to delete\b'
    if ($containsSafeToDelete) {
        $containsWarningContext = $reportContent -match '(?is)cannot determine.*safe to delete|safe to delete.*cannot determine|manual validation required|does not prove that an object is unused'

        Assert-Condition `
            -Condition $containsWarningContext `
            -Message 'Report contains "safe to delete" wording without warning context.'
    }

    $dependencyCandidateCount = [int]$script:OrphanedReportResult.DependencyCandidateCount
    $securityCandidateCount = [int]$script:OrphanedReportResult.SecurityCandidateCount
    $referenceDataCandidateCount = [int]$script:OrphanedReportResult.ReferenceDataCandidateCount

    if (($dependencyCandidateCount + $securityCandidateCount + $referenceDataCandidateCount) -eq 0) {
        Write-TestStatus -Status INFO -Message 'All candidate counts are zero. This is allowed and the test remains valid.'
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
