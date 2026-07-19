<#
.SYNOPSIS
    Tests the dependency object model returned by Get-DatabaseDependencies.

.DESCRIPTION
    This regression test validates the shape and usability of dependency data
    without storing server names, database names, or environment-specific values
    in the test script.

    The test reads export.yaml from the supplied OutputFolder.

.PARAMETER OutputFolder
    The external export folder that contains export.yaml.

.PARAMETER SampleCount
    Number of dependency rows to display as a sample.

.EXAMPLE
    .\tests\Test-DependencyModel.ps1 -OutputFolder 'C:\Source\FolderName'

.EXAMPLE
    .\tests\Test-DependencyModel.ps1 -OutputFolder 'C:\Source\FolderName' -SampleCount 25
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$SampleCount = 10
)


Clear-Host

Write-Host ''
Write-Host '========================================================='
Write-Host 'Test-DependencyModel'
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
$script:ProfilePath = $null
$script:ResolvedOutputFolder = $null
$script:DependenciesLoaded = $false

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
        $script:TestsPassed++
        Write-TestStatus -Status PASS -Message $Name
    }
    catch [System.OperationCanceledException] {
        $script:TestsSkipped++
        Write-TestStatus -Status SKIP -Message $Name
        Write-TestStatus -Status SKIP -Message $_.Exception.Message
    }
    catch {
        $script:TestsFailed++
        Write-TestStatus -Status FAIL -Message $Name
        Write-TestStatus -Status FAIL -Message $_.Exception.Message
    }
}

Write-TestStatus -Status INFO -Message 'Starting dependency model regression test.'

Invoke-TestStep -Name 'Setup Dependency Test Context' -ScriptBlock {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ExporterScriptPath = Join-Path $script:ProjectRoot 'Export-SqlDatabaseDefinition.ps1'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ExporterScriptPath -PathType Leaf) `
        -Message "Exporter script was not found: $script:ExporterScriptPath"

    . $script:ExporterScriptPath

    $script:ResolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ResolvedOutputFolder -PathType Container) `
        -Message "Output folder does not exist: $script:ResolvedOutputFolder"

    $script:ProfilePath = Join-Path $script:ResolvedOutputFolder 'export.yaml'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:ProfilePath -PathType Leaf) `
        -Message "export.yaml does not exist: $script:ProfilePath"

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Read-ExportProfile -ErrorAction SilentlyContinue)) `
        -Message 'Read-ExportProfile function was not loaded.'

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Connect-SqlDatabase -ErrorAction SilentlyContinue)) `
        -Message 'Connect-SqlDatabase function was not loaded.'

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Get-DatabaseDependencies -ErrorAction SilentlyContinue)) `
        -Message 'Get-DatabaseDependencies function was not loaded.'

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Export-DependenciesCsv -ErrorAction SilentlyContinue)) `
        -Message 'Export-DependenciesCsv function was not loaded.'
}

Invoke-TestStep -Name 'Read-ExportProfile' -ScriptBlock {
    if ([string]::IsNullOrWhiteSpace($script:ProfilePath)) {
        Skip-TestStep -Message 'Setup Dependency Test Context did not provide ProfilePath.'
    }

    if (-not (Test-Path -LiteralPath $script:ProfilePath -PathType Leaf)) {
        Skip-TestStep -Message ("Setup Dependency Test Context did not produce a valid export.yaml path: {0}" -f $script:ProfilePath)
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

    $script:DependenciesLoaded = $true

    Assert-Condition `
        -Condition ($null -ne $script:Dependencies) `
        -Message 'Get-DatabaseDependencies returned null.'

    Write-TestStatus `
        -Status INFO `
        -Message ("Dependency rows returned: {0}" -f $script:Dependencies.Count)
}

Invoke-TestStep -Name 'Export-DependenciesCsv' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    $csvExportResult = Export-DependenciesCsv `
        -Dependencies $script:Dependencies `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $csvExportResult) `
        -Message 'Export-DependenciesCsv returned null.'

    Assert-Condition `
        -Condition ($null -ne $csvExportResult.PSObject.Properties['DependencyCount']) `
        -Message 'Export-DependenciesCsv result is missing DependencyCount.'

    Assert-Condition `
        -Condition ($null -ne $csvExportResult.PSObject.Properties['CsvPath']) `
        -Message 'Export-DependenciesCsv result is missing CsvPath.'

    $csvPath = [string]$csvExportResult.CsvPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($csvPath)) `
        -Message 'Export-DependenciesCsv returned an empty CsvPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $csvPath -PathType Leaf) `
        -Message "CSV file does not exist: $csvPath"

    $csvRawContent = Get-Content -LiteralPath $csvPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($csvRawContent)) `
        -Message "CSV file is empty: $csvPath"

    $csvHeader = (Get-Content -LiteralPath $csvPath -TotalCount 1)

    Assert-Condition `
        -Condition ($csvHeader -match 'ReferencingFullName') `
        -Message 'CSV header does not contain ReferencingFullName.'

    Assert-Condition `
        -Condition ($csvHeader -match 'ReferencedFullName') `
        -Message 'CSV header does not contain ReferencedFullName.'

    $importedRows = @(Import-Csv -LiteralPath $csvPath)

    if ($script:Dependencies.Count -gt 0) {
        Assert-Condition `
            -Condition ($importedRows.Count -gt 0) `
            -Message 'CSV data row count is zero while dependencies exist.'

        $firstCsvRow = $importedRows[0]

        foreach ($propertyName in @('ReferencingFullName', 'ReferencedFullName', 'ReferencingObjectType', 'ReferencedObjectType')) {
            Assert-Condition `
                -Condition ($firstCsvRow.PSObject.Properties.Name -contains $propertyName) `
                -Message ("CSV row is missing expected property: {0}" -f $propertyName)
        }
    }
    else {
        Write-TestStatus -Status WARN -Message 'No dependencies were returned. CSV export created header-only output.'
    }
}

Invoke-TestStep -Name 'Dependency Object Shape' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    if ($script:Dependencies.Count -eq 0) {
        Write-TestStatus -Status WARN -Message 'No dependencies were returned. Object-shape validation skipped.'
        return
    }

    $firstDependency = $script:Dependencies[0]

    $requiredProperties = @(
        'ReferencingDatabase',
        'ReferencingSchema',
        'ReferencingObject',
        'ReferencingFullName',
        'ReferencingObjectType',
        'ReferencedServer',
        'ReferencedDatabase',
        'ReferencedSchema',
        'ReferencedObject',
        'ReferencedFullName',
        'ReferencedObjectType',
        'IsSchemaBound',
        'IsCallerDependent',
        'IsAmbiguous',
        'IsCrossDatabase',
        'IsCrossServer',
        'IsExternalReference',
        'ReferencingId',
        'ReferencedId',
        'ReferencingClass',
        'ReferencedClass'
    )

    foreach ($propertyName in $requiredProperties) {
        Assert-Condition `
            -Condition ($firstDependency.PSObject.Properties.Name -contains $propertyName) `
            -Message "Dependency object is missing property: $propertyName"
    }
}

Invoke-TestStep -Name 'Dependency Full Name Validation' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    if ($script:Dependencies.Count -eq 0) {
        Write-TestStatus -Status WARN -Message 'No dependencies were returned. Full-name validation skipped.'
        return
    }

    foreach ($dependency in $script:Dependencies) {
        if (-not [string]::IsNullOrWhiteSpace($dependency.ReferencingSchema) -and
            -not [string]::IsNullOrWhiteSpace($dependency.ReferencingObject)) {

            $expectedReferencingFullName = "{0}.{1}" -f $dependency.ReferencingSchema, $dependency.ReferencingObject

            Assert-Condition `
                -Condition ($dependency.ReferencingFullName -eq $expectedReferencingFullName) `
                -Message ("ReferencingFullName mismatch. Expected '{0}', found '{1}'." -f $expectedReferencingFullName, $dependency.ReferencingFullName)
        }

        if (-not [string]::IsNullOrWhiteSpace($dependency.ReferencedDatabase)) {
            if (-not [string]::IsNullOrWhiteSpace($dependency.ReferencedSchema)) {
                $expectedReferencedFullName = "{0}.{1}" -f $dependency.ReferencedSchema, $dependency.ReferencedObject
            }
            else {
                $expectedReferencedFullName = $dependency.ReferencedObject
            }

            Assert-Condition `
                -Condition ($dependency.ReferencedFullName -eq $expectedReferencedFullName) `
                -Message ("ReferencedFullName mismatch. Expected '{0}', found '{1}'." -f $expectedReferencedFullName, $dependency.ReferencedFullName)
        }

        Assert-Condition `
            -Condition (-not ($dependency.ReferencingFullName -like '.*')) `
            -Message ("ReferencingFullName has a leading period: {0}" -f $dependency.ReferencingFullName)

        Assert-Condition `
            -Condition (-not ($dependency.ReferencedFullName -like '.*')) `
            -Message ("ReferencedFullName has a leading period: {0}" -f $dependency.ReferencedFullName)
    }
}

Invoke-TestStep -Name 'Dependency Type Summary' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    if ($script:Dependencies.Count -eq 0) {
        Write-TestStatus -Status WARN -Message 'No dependencies were returned. Type summary skipped.'
        return
    }

    Write-TestStatus -Status INFO -Message 'Referencing object type summary:'

    $script:Dependencies |
        Group-Object ReferencingObjectType |
        Sort-Object Count -Descending |
        ForEach-Object {
            Write-TestStatus -Status INFO -Message ("  {0}: {1}" -f $_.Name, $_.Count)
        }

    Write-TestStatus -Status INFO -Message 'Referenced object type summary:'

    $script:Dependencies |
        Group-Object ReferencedObjectType |
        Sort-Object Count -Descending |
        ForEach-Object {
            Write-TestStatus -Status INFO -Message ("  {0}: {1}" -f $_.Name, $_.Count)
        }
}

Invoke-TestStep -Name 'Dependency Sample Output' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    if ($script:Dependencies.Count -eq 0) {
        Write-TestStatus -Status WARN -Message 'No dependencies were returned. Sample output skipped.'
        return
    }

    Write-TestStatus -Status INFO -Message ("Showing first {0} dependency row(s):" -f $SampleCount)

    $script:Dependencies |
        Select-Object -First $SampleCount `
            ReferencingFullName,
            ReferencedFullName,
            ReferencingObjectType,
            ReferencedObjectType,
            IsCrossDatabase,
            IsCrossServer,
            IsAmbiguous,
            IsCallerDependent |
        Format-Table -AutoSize
}

Write-Host ''
Write-Host '----------------------------------------'
Write-Host 'Dependency Model Test Summary'
Write-Host '----------------------------------------'
Write-Host ''
Write-Host ("Passed:   {0}" -f $script:TestsPassed)
Write-Host ("Failed:   {0}" -f $script:TestsFailed)
Write-Host ("Skipped:  {0}" -f $script:TestsSkipped)

if ($script:TestsFailed -gt 0) {
    exit 1
}

exit 0
