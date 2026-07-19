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

$requiredExporterFunctions = @(
    'Read-ExportProfile',
    'Connect-SqlDatabase',
    'Get-DatabaseDependencies',
    'Export-DependenciesCsv',
    'Export-DependenciesJson',
    'Export-DependencyWarnings',
    'Export-DependenciesDot'
)

$missingExporterFunctions = @(
    $requiredExporterFunctions | Where-Object {
        $null -eq (Get-Command -Name $_ -ErrorAction SilentlyContinue)
    }
)

if ($missingExporterFunctions.Count -gt 0) {
    throw ("Required exporter functions were not loaded: {0}" -f ($missingExporterFunctions -join ', '))
}

Write-TestStatus -Status INFO -Message 'Starting dependency model regression test.'

Invoke-TestStep -Name 'Setup Dependency Test Context' -ScriptBlock {
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

Invoke-TestStep -Name 'Export-DependenciesJson' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    $jsonExportResult = Export-DependenciesJson `
        -Dependencies $script:Dependencies `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $jsonExportResult) `
        -Message 'Export-DependenciesJson returned null.'

    Assert-Condition `
        -Condition ($null -ne $jsonExportResult.PSObject.Properties['DependencyCount']) `
        -Message 'Export-DependenciesJson result is missing DependencyCount.'

    Assert-Condition `
        -Condition ($null -ne $jsonExportResult.PSObject.Properties['JsonPath']) `
        -Message 'Export-DependenciesJson result is missing JsonPath.'

    $jsonPath = [string]$jsonExportResult.JsonPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($jsonPath)) `
        -Message 'Export-DependenciesJson returned an empty JsonPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $jsonPath -PathType Leaf) `
        -Message "JSON file does not exist: $jsonPath"

    $jsonRawContent = Get-Content -LiteralPath $jsonPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($jsonRawContent)) `
        -Message "JSON file is empty: $jsonPath"

    $parsedJson = $null
    try {
        $parsedJson = ConvertFrom-Json -InputObject $jsonRawContent
    }
    catch {
        throw ("JSON parse failed for file '{0}'. {1}" -f $jsonPath, $_.Exception.Message)
    }

    Assert-Condition `
        -Condition ($null -ne $parsedJson) `
        -Message 'Parsed JSON result is null.'

    if ($script:Dependencies.Count -gt 0) {
        $parsedJsonArray = @($parsedJson)

        Assert-Condition `
            -Condition ($parsedJsonArray.Count -gt 0) `
            -Message 'Parsed JSON contains zero dependency records while dependencies exist.'

        $firstJsonRecord = $parsedJsonArray[0]

        foreach ($propertyName in @('ReferencingFullName', 'ReferencedFullName', 'ReferencingObjectType', 'ReferencedObjectType')) {
            Assert-Condition `
                -Condition ($firstJsonRecord.PSObject.Properties.Name -contains $propertyName) `
                -Message ("JSON dependency record is missing expected property: {0}" -f $propertyName)
        }
    }
    else {
        Assert-Condition `
            -Condition ($jsonRawContent.Trim() -eq '[]') `
            -Message 'JSON output must be an empty array [] when dependencies are zero.'

        Write-TestStatus -Status WARN -Message 'No dependencies were returned. JSON export created empty-array output.'
    }
}

Invoke-TestStep -Name 'Export-DependencyWarnings' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    $warningExportResult = Export-DependencyWarnings `
        -Dependencies $script:Dependencies `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $warningExportResult) `
        -Message 'Export-DependencyWarnings returned null.'

    foreach ($propertyName in @('WarningPath', 'CrossDatabaseCount', 'CrossServerCount', 'CallerDependentCount', 'AmbiguousCount')) {
        Assert-Condition `
            -Condition ($null -ne $warningExportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-DependencyWarnings result is missing {0}." -f $propertyName)
    }

    $warningPath = [string]$warningExportResult.WarningPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($warningPath)) `
        -Message 'Export-DependencyWarnings returned an empty WarningPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $warningPath -PathType Leaf) `
        -Message "Warning report file does not exist: $warningPath"

    $warningRawContent = Get-Content -LiteralPath $warningPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($warningRawContent)) `
        -Message "Warning report file is empty: $warningPath"

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('# Dependency Warning Report')) `
        -Message 'Warning report is missing # Dependency Warning Report.'

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('## Summary')) `
        -Message 'Warning report is missing ## Summary.'

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('Cross Database References')) `
        -Message 'Warning report is missing Cross Database References section.'

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('Cross Server References')) `
        -Message 'Warning report is missing Cross Server References section.'

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('Caller Dependent References')) `
        -Message 'Warning report is missing Caller Dependent References section.'

    Assert-Condition `
        -Condition ($warningRawContent -match [regex]::Escape('Ambiguous References')) `
        -Message 'Warning report is missing Ambiguous References section.'

    $hasCrossDatabase = $script:Dependencies | Where-Object { $_.IsCrossDatabase -eq $true } | Select-Object -First 1
    $hasCrossServer = $script:Dependencies | Where-Object { $_.IsCrossServer -eq $true } | Select-Object -First 1
    $hasCallerDependent = $script:Dependencies | Where-Object { $_.IsCallerDependent -eq $true } | Select-Object -First 1
    $hasAmbiguous = $script:Dependencies | Where-Object { $_.IsAmbiguous -eq $true } | Select-Object -First 1

    if ($null -eq $hasCrossDatabase -and
        $null -eq $hasCrossServer -and
        $null -eq $hasCallerDependent -and
        $null -eq $hasAmbiguous) {

        Assert-Condition `
            -Condition ($warningRawContent -match [regex]::Escape('None found')) `
            -Message 'Warning report should include None found when no warnings exist.'

        Write-TestStatus -Status WARN -Message 'No warning dependencies were found. Warning report contains None found.'
    }
}

Invoke-TestStep -Name 'Export-DependenciesDot' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    $dotExportResult = Export-DependenciesDot `
        -Dependencies $script:Dependencies `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $dotExportResult) `
        -Message 'Export-DependenciesDot returned null.'

    Assert-Condition `
        -Condition ($null -ne $dotExportResult.PSObject.Properties['DependencyCount']) `
        -Message 'Export-DependenciesDot result is missing DependencyCount.'

    Assert-Condition `
        -Condition ($null -ne $dotExportResult.PSObject.Properties['DotPath']) `
        -Message 'Export-DependenciesDot result is missing DotPath.'

    $dotPath = [string]$dotExportResult.DotPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($dotPath)) `
        -Message 'Export-DependenciesDot returned an empty DotPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $dotPath -PathType Leaf) `
        -Message "DOT file does not exist: $dotPath"

    $dotRawContent = Get-Content -LiteralPath $dotPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($dotRawContent)) `
        -Message "DOT file is empty: $dotPath"

    Assert-Condition `
        -Condition ($dotRawContent -match [regex]::Escape('digraph Dependencies')) `
        -Message 'DOT file is missing digraph Dependencies header.'

    if ($script:Dependencies.Count -gt 0) {
        Assert-Condition `
            -Condition ($dotRawContent -match [regex]::Escape('->')) `
            -Message 'DOT file is missing dependency edges while dependencies exist.'
    }
    else {
        Assert-Condition `
            -Condition ($dotRawContent -match 'digraph\s+Dependencies\s*\{\s*\}') `
            -Message 'DOT output must contain an empty graph block when dependencies are zero.'

        Write-TestStatus -Status WARN -Message 'No dependencies were returned. DOT export created an empty graph.'
    }
}

Invoke-TestStep -Name 'Export-DependenciesSvg' -ScriptBlock {
    if (-not $script:DependenciesLoaded) {
        Skip-TestStep -Message 'Get-DatabaseDependencies did not complete successfully.'
    }

    if (-not (Get-Command -Name Export-DependenciesSvg -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-DependenciesSvg function was not found.'
    }

    $dotCommand = Get-Command -Name 'dot' -ErrorAction SilentlyContinue
    if ($null -eq $dotCommand) {
        Write-TestStatus -Status WARN -Message 'Graphviz is not installed. Skipping SVG generation test.'
        Skip-TestStep -Message 'Graphviz is not installed. Skipping SVG generation test.'
    }

    $svgExportResult = $null
    try {
        $svgExportResult = Export-DependenciesSvg `
            -OutputFolder $script:ResolvedOutputFolder
    }
    catch {
        $errorMessage = [string]$_.Exception.Message
        if ($errorMessage -match 'Graphviz dot command was not found|winget install Graphviz\.Graphviz|\bdot\b') {
            Write-TestStatus -Status WARN -Message 'Graphviz is not installed. Skipping SVG generation test.'
            Skip-TestStep -Message 'Graphviz is not installed. Skipping SVG generation test.'
        }

        throw
    }

    Assert-Condition `
        -Condition ($null -ne $svgExportResult) `
        -Message 'Export-DependenciesSvg returned null.'

    foreach ($propertyName in @('DotPath', 'SvgPath', 'Generated')) {
        Assert-Condition `
            -Condition ($null -ne $svgExportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-DependenciesSvg result is missing {0}." -f $propertyName)
    }

    $dotPath = [string]$svgExportResult.DotPath
    $svgPath = [string]$svgExportResult.SvgPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($dotPath)) `
        -Message 'Export-DependenciesSvg returned an empty DotPath.'

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($svgPath)) `
        -Message 'Export-DependenciesSvg returned an empty SvgPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $dotPath -PathType Leaf) `
        -Message "DOT file does not exist: $dotPath"

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $svgPath -PathType Leaf) `
        -Message "SVG file does not exist: $svgPath"

    $svgRawContent = Get-Content -LiteralPath $svgPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($svgRawContent)) `
        -Message "SVG file is empty: $svgPath"

    Assert-Condition `
        -Condition ($svgRawContent -match '<svg') `
        -Message 'SVG file does not contain <svg.'
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
