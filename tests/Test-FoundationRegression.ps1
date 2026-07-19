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

$script:projectRoot = Split-Path -Parent $PSScriptRoot
$script:scriptPath = Join-Path $script:projectRoot 'Export-SqlDatabaseDefinition.ps1'

Assert-Condition `
    -Condition (Test-Path -LiteralPath $script:scriptPath -PathType Leaf) `
    -Message "Could not find Export-SqlDatabaseDefinition.ps1 at: $script:scriptPath"

Write-TestStatus -Status INFO -Message "Loading exporter script from: $script:scriptPath"

. $script:scriptPath

Invoke-TestStep -Name 'Setup Regression Context' -ScriptBlock {
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

Invoke-TestStep -Name 'Export-Schemas' -ScriptBlock {
    if (-not (Get-Command -Name Export-Schemas -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Schemas function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    Export-Schemas `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder | Out-Null

    $schemasFolderPath = Join-Path $script:resolvedOutputFolder 'Schemas'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $schemasFolderPath -PathType Container) `
        -Message "Schemas folder was not created: $schemasFolderPath"

    $schemaFiles = @(Get-ChildItem -LiteralPath $schemasFolderPath -Filter '*.sql' -File)

    Assert-Condition `
        -Condition ($schemaFiles.Count -gt 0) `
        -Message "No schema files were exported to: $schemasFolderPath"

    $containsCreateSchema = $false

    foreach ($schemaFile in $schemaFiles) {
        Assert-Condition `
            -Condition (Test-Path -LiteralPath $schemaFile.FullName -PathType Leaf) `
            -Message "Schema file does not exist: $($schemaFile.FullName)"

        $schemaFileContent = Get-Content -LiteralPath $schemaFile.FullName -Raw

        Assert-Condition `
            -Condition (-not [string]::IsNullOrWhiteSpace($schemaFileContent)) `
            -Message "Schema file is empty: $($schemaFile.FullName)"

        if ($schemaFileContent -match 'CREATE\s+SCHEMA') {
            $containsCreateSchema = $true
        }
    }

    Assert-Condition `
        -Condition ($containsCreateSchema) `
        -Message 'No exported schema file contains CREATE SCHEMA.'
}

Invoke-TestStep -Name 'Export-Tables' -ScriptBlock {
    if (-not (Get-Command -Name Export-Tables -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Tables function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $tableExportResult = Export-Tables `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $tablesFolderPath = Join-Path $script:resolvedOutputFolder 'Tables'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $tablesFolderPath -PathType Container) `
        -Message "Tables folder was not created: $tablesFolderPath"

    Assert-Condition `
        -Condition ($null -ne $tableExportResult) `
        -Message 'Export-Tables returned null.'

    Assert-Condition `
        -Condition ($null -ne $tableExportResult.PSObject.Properties['TableCount']) `
        -Message 'Export-Tables result does not include TableCount.'

    Assert-Condition `
        -Condition ($null -ne $tableExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Tables result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $tableExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Tables result does not include ExportedFiles.'

    if ([int]$tableExportResult.TableCount -gt 0) {
        $tableFiles = @(Get-ChildItem -LiteralPath $tablesFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($tableFiles.Count -gt 0) `
            -Message "No table files were exported to: $tablesFolderPath"

        $containsCreateTable = $false

        foreach ($tableFilePath in @($tableExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$tableFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $tableFilePath -PathType Leaf) `
                -Message "Exported table file does not exist: $tableFilePath"

            $tableFileContent = Get-Content -LiteralPath $tableFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($tableFileContent)) `
                -Message "Exported table file is empty: $tableFilePath"

            if ($tableFileContent -match 'CREATE\s+TABLE') {
                $containsCreateTable = $true
            }
        }

        Assert-Condition `
            -Condition ($containsCreateTable) `
            -Message 'No exported table file contains CREATE TABLE.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Tables found no user tables to export.'
    }
}

Invoke-TestStep -Name 'Export-Views' -ScriptBlock {
    if (-not (Get-Command -Name Export-Views -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Views function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $viewExportResult = Export-Views `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $viewsFolderPath = Join-Path $script:resolvedOutputFolder 'Views'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $viewsFolderPath -PathType Container) `
        -Message "Views folder was not created: $viewsFolderPath"

    Assert-Condition `
        -Condition ($null -ne $viewExportResult) `
        -Message 'Export-Views returned null.'

    Assert-Condition `
        -Condition ($null -ne $viewExportResult.PSObject.Properties['ViewCount']) `
        -Message 'Export-Views result does not include ViewCount.'

    Assert-Condition `
        -Condition ($null -ne $viewExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Views result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $viewExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Views result does not include ExportedFiles.'

    if ([int]$viewExportResult.ViewCount -gt 0) {
        $viewFiles = @(Get-ChildItem -LiteralPath $viewsFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($viewFiles.Count -gt 0) `
            -Message "No view files were exported to: $viewsFolderPath"

        $containsViewDefinition = $false

        foreach ($viewFilePath in @($viewExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$viewFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $viewFilePath -PathType Leaf) `
                -Message "Exported view file does not exist: $viewFilePath"

            $viewFileContent = Get-Content -LiteralPath $viewFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($viewFileContent)) `
                -Message "Exported view file is empty: $viewFilePath"

            if ($viewFileContent -match 'CREATE\s+VIEW|ALTER\s+VIEW') {
                $containsViewDefinition = $true
            }
        }

        Assert-Condition `
            -Condition ($containsViewDefinition) `
            -Message 'No exported view file contains CREATE VIEW or ALTER VIEW.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Views found no user views to export.'
    }
}

Invoke-TestStep -Name 'Export-StoredProcedures' -ScriptBlock {
    if (-not (Get-Command -Name Export-StoredProcedures -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-StoredProcedures function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $procedureExportResult = Export-StoredProcedures `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $proceduresFolderPath = Join-Path $script:resolvedOutputFolder 'StoredProcedures'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $proceduresFolderPath -PathType Container) `
        -Message "StoredProcedures folder was not created: $proceduresFolderPath"

    Assert-Condition `
        -Condition ($null -ne $procedureExportResult) `
        -Message 'Export-StoredProcedures returned null.'

    Assert-Condition `
        -Condition ($null -ne $procedureExportResult.PSObject.Properties['ProcedureCount']) `
        -Message 'Export-StoredProcedures result does not include ProcedureCount.'

    Assert-Condition `
        -Condition ($null -ne $procedureExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-StoredProcedures result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $procedureExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-StoredProcedures result does not include ExportedFiles.'

    if ([int]$procedureExportResult.ProcedureCount -gt 0) {
        $procedureFiles = @(Get-ChildItem -LiteralPath $proceduresFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($procedureFiles.Count -gt 0) `
            -Message "No stored procedure files were exported to: $proceduresFolderPath"

        $containsProcedureDefinition = $false

        foreach ($procedureFilePath in @($procedureExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$procedureFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $procedureFilePath -PathType Leaf) `
                -Message "Exported stored procedure file does not exist: $procedureFilePath"

            $procedureFileContent = Get-Content -LiteralPath $procedureFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($procedureFileContent)) `
                -Message "Exported stored procedure file is empty: $procedureFilePath"

            if ($procedureFileContent -match 'CREATE\s+PROCEDURE|ALTER\s+PROCEDURE') {
                $containsProcedureDefinition = $true
            }
        }

        Assert-Condition `
            -Condition ($containsProcedureDefinition) `
            -Message 'No exported stored procedure file contains CREATE PROCEDURE or ALTER PROCEDURE.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-StoredProcedures found no user stored procedures to export.'
    }
}

Invoke-TestStep -Name 'Export-Functions' -ScriptBlock {
    if (-not (Get-Command -Name Export-Functions -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Functions function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $functionExportResult = Export-Functions `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $functionsFolderPath = Join-Path $script:resolvedOutputFolder 'Functions'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $functionsFolderPath -PathType Container) `
        -Message "Functions folder was not created: $functionsFolderPath"

    Assert-Condition `
        -Condition ($null -ne $functionExportResult) `
        -Message 'Export-Functions returned null.'

    Assert-Condition `
        -Condition ($null -ne $functionExportResult.PSObject.Properties['FunctionCount']) `
        -Message 'Export-Functions result does not include FunctionCount.'

    Assert-Condition `
        -Condition ($null -ne $functionExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Functions result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $functionExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Functions result does not include ExportedFiles.'

    if ([int]$functionExportResult.FunctionCount -gt 0) {
        $functionFiles = @(Get-ChildItem -LiteralPath $functionsFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($functionFiles.Count -gt 0) `
            -Message "No function files were exported to: $functionsFolderPath"

        $containsFunctionDefinition = $false

        foreach ($functionFilePath in @($functionExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$functionFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $functionFilePath -PathType Leaf) `
                -Message "Exported function file does not exist: $functionFilePath"

            $functionFileContent = Get-Content -LiteralPath $functionFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($functionFileContent)) `
                -Message "Exported function file is empty: $functionFilePath"

            if ($functionFileContent -match 'CREATE\s+FUNCTION|ALTER\s+FUNCTION') {
                $containsFunctionDefinition = $true
            }
        }

        Assert-Condition `
            -Condition ($containsFunctionDefinition) `
            -Message 'No exported function file contains CREATE FUNCTION or ALTER FUNCTION.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Functions found no user functions to export.'
    }
}

Invoke-TestStep -Name 'Export-Triggers' -ScriptBlock {
    if (-not (Get-Command -Name Export-Triggers -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Triggers function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $triggerExportResult = Export-Triggers `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $triggersFolderPath = Join-Path $script:resolvedOutputFolder 'Triggers'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $triggersFolderPath -PathType Container) `
        -Message "Triggers folder was not created: $triggersFolderPath"

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult) `
        -Message 'Export-Triggers returned null.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['TriggerCount']) `
        -Message 'Export-Triggers result does not include TriggerCount.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['DatabaseTriggers']) `
        -Message 'Export-Triggers result does not include DatabaseTriggers.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['DdlTriggers']) `
        -Message 'Export-Triggers result does not include DdlTriggers.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['DmlTriggers']) `
        -Message 'Export-Triggers result does not include DmlTriggers.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Triggers result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $triggerExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Triggers result does not include ExportedFiles.'

    $triggerCount = [int]$triggerExportResult.TriggerCount
    $databaseTriggerCount = [int]$triggerExportResult.DatabaseTriggers
    $ddlTriggerCount = [int]$triggerExportResult.DdlTriggers
    $dmlTriggerCount = [int]$triggerExportResult.DmlTriggers

    Assert-Condition `
        -Condition ($triggerCount -eq ($databaseTriggerCount + $ddlTriggerCount + $dmlTriggerCount)) `
        -Message 'Export-Triggers count mismatch: TriggerCount does not equal DatabaseTriggers + DdlTriggers + DmlTriggers.'

    if ($triggerCount -gt 0) {
        $triggerFiles = @(Get-ChildItem -LiteralPath $triggersFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($triggerFiles.Count -gt 0) `
            -Message "No trigger files were exported to: $triggersFolderPath"

        $containsTriggerDefinition = $false
        $containsTriggerTypeHeader = $false

        foreach ($triggerFilePath in @($triggerExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$triggerFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $triggerFilePath -PathType Leaf) `
                -Message "Exported trigger file does not exist: $triggerFilePath"

            $triggerFileContent = Get-Content -LiteralPath $triggerFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($triggerFileContent)) `
                -Message "Exported trigger file is empty: $triggerFilePath"

            Assert-Condition `
                -Condition ($triggerFileContent -match '(?m)^--\s*Trigger\s+Type:\s*.+$') `
                -Message "Exported trigger file does not include -- Trigger Type: header: $triggerFilePath"

            if ($triggerFileContent -match '(?m)^--\s*Trigger\s+Type:\s*.+$') {
                $containsTriggerTypeHeader = $true
            }

            $isDmlTableTrigger = $triggerFileContent -match '(?m)^--\s*Trigger\s+Type:\s*DML/Table\s*$'
            $hasParentObjectHeader = $triggerFileContent -match '(?m)^--\s*Parent\s+Object:\s*.+$'

            if ($isDmlTableTrigger -and -not $hasParentObjectHeader) {
                Assert-Condition `
                    -Condition $false `
                    -Message "DML/Table trigger file does not include -- Parent Object: header: $triggerFilePath"
            }

            if ($triggerFileContent -match 'CREATE\s+TRIGGER|ALTER\s+TRIGGER') {
                $containsTriggerDefinition = $true
            }
        }

        Assert-Condition `
            -Condition ($containsTriggerTypeHeader) `
            -Message 'No exported trigger file contains -- Trigger Type: metadata header.'

        Assert-Condition `
            -Condition ($containsTriggerDefinition) `
            -Message 'No exported trigger file contains CREATE TRIGGER or ALTER TRIGGER.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Triggers found no user triggers to export.'
    }
}

Invoke-TestStep -Name 'Export-Synonyms' -ScriptBlock {
    if (-not (Get-Command -Name Export-Synonyms -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Synonyms function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $synonymExportResult = Export-Synonyms `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $synonymsFolderPath = Join-Path $script:resolvedOutputFolder 'Synonyms'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $synonymsFolderPath -PathType Container) `
        -Message "Synonyms folder was not created: $synonymsFolderPath"

    Assert-Condition `
        -Condition ($null -ne $synonymExportResult) `
        -Message 'Export-Synonyms returned null.'

    Assert-Condition `
        -Condition ($null -ne $synonymExportResult.PSObject.Properties['SynonymCount']) `
        -Message 'Export-Synonyms result does not include SynonymCount.'

    Assert-Condition `
        -Condition ($null -ne $synonymExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Synonyms result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $synonymExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Synonyms result does not include ExportedFiles.'

    $synonymCount = [int]$synonymExportResult.SynonymCount

    if ($synonymCount -gt 0) {
        $synonymFiles = @(Get-ChildItem -LiteralPath $synonymsFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($synonymFiles.Count -gt 0) `
            -Message "No synonym files were exported to: $synonymsFolderPath"

        $containsCreateSynonym = $false
        $containsSynonymNameHeader = $false
        $containsBaseObjectHeader = $false

        foreach ($synonymFilePath in @($synonymExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$synonymFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $synonymFilePath -PathType Leaf) `
                -Message "Exported synonym file does not exist: $synonymFilePath"

            $synonymFileContent = Get-Content -LiteralPath $synonymFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($synonymFileContent)) `
                -Message "Exported synonym file is empty: $synonymFilePath"

            if ($synonymFileContent -match 'CREATE\s+SYNONYM') {
                $containsCreateSynonym = $true
            }

            if ($synonymFileContent -match '(?m)^--\s*Synonym\s+Name:\s*.+$') {
                $containsSynonymNameHeader = $true
            }

            if ($synonymFileContent -match '(?m)^--\s*Base\s+Object:\s*.+$') {
                $containsBaseObjectHeader = $true
            }
        }

        Assert-Condition `
            -Condition ($containsCreateSynonym) `
            -Message 'No exported synonym file contains CREATE SYNONYM.'

        Assert-Condition `
            -Condition ($containsSynonymNameHeader) `
            -Message 'No exported synonym file contains -- Synonym Name: metadata header.'

        Assert-Condition `
            -Condition ($containsBaseObjectHeader) `
            -Message 'No exported synonym file contains -- Base Object: metadata header.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Synonyms found no user synonyms to export.'
    }
}

Invoke-TestStep -Name 'Export-Sequences' -ScriptBlock {
    if (-not (Get-Command -Name Export-Sequences -ErrorAction SilentlyContinue)) {
        Skip-TestStep -Message 'Export-Sequences function was not found.'
    }

    if ($null -eq $script:connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    $sequenceExportResult = Export-Sequences `
        -Connection $script:connection `
        -OutputFolder $script:resolvedOutputFolder

    $sequencesFolderPath = Join-Path $script:resolvedOutputFolder 'Sequences'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $sequencesFolderPath -PathType Container) `
        -Message "Sequences folder was not created: $sequencesFolderPath"

    Assert-Condition `
        -Condition ($null -ne $sequenceExportResult) `
        -Message 'Export-Sequences returned null.'

    Assert-Condition `
        -Condition ($null -ne $sequenceExportResult.PSObject.Properties['SequenceCount']) `
        -Message 'Export-Sequences result does not include SequenceCount.'

    Assert-Condition `
        -Condition ($null -ne $sequenceExportResult.PSObject.Properties['OutputFolder']) `
        -Message 'Export-Sequences result does not include OutputFolder.'

    Assert-Condition `
        -Condition ($null -ne $sequenceExportResult.PSObject.Properties['ExportedFiles']) `
        -Message 'Export-Sequences result does not include ExportedFiles.'

    $sequenceCount = [int]$sequenceExportResult.SequenceCount

    if ($sequenceCount -gt 0) {
        $sequenceFiles = @(Get-ChildItem -LiteralPath $sequencesFolderPath -Filter '*.sql' -File)

        Assert-Condition `
            -Condition ($sequenceFiles.Count -gt 0) `
            -Message "No sequence files were exported to: $sequencesFolderPath"

        $containsCreateSequence = $false
        $containsSequenceNameHeader = $false

        foreach ($sequenceFilePath in @($sequenceExportResult.ExportedFiles)) {
            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace([string]$sequenceFilePath)) `
                -Message 'ExportedFiles contains an empty path value.'

            Assert-Condition `
                -Condition (Test-Path -LiteralPath $sequenceFilePath -PathType Leaf) `
                -Message "Exported sequence file does not exist: $sequenceFilePath"

            $sequenceFileContent = Get-Content -LiteralPath $sequenceFilePath -Raw

            Assert-Condition `
                -Condition (-not [string]::IsNullOrWhiteSpace($sequenceFileContent)) `
                -Message "Exported sequence file is empty: $sequenceFilePath"

            if ($sequenceFileContent -match 'CREATE\s+SEQUENCE') {
                $containsCreateSequence = $true
            }

            if ($sequenceFileContent -match '(?m)^--\s*Sequence\s+Name:\s*.+$') {
                $containsSequenceNameHeader = $true
            }
        }

        Assert-Condition `
            -Condition ($containsCreateSequence) `
            -Message 'No exported sequence file contains CREATE SEQUENCE.'

        Assert-Condition `
            -Condition ($containsSequenceNameHeader) `
            -Message 'No exported sequence file contains -- Sequence Name: metadata header.'
    }
    else {
        Write-TestStatus -Status WARN -Message 'Export-Sequences found no user sequences to export.'
    }
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
