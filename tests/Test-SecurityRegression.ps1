<#
.SYNOPSIS
    Tests security export functionality.

.DESCRIPTION
    This regression test validates the security export workflow without storing
    server names, database names, role names, user names, or environment-specific
    paths in the test script.

    The test reads export.yaml from the supplied OutputFolder.

.PARAMETER OutputFolder
    The external export folder that contains export.yaml.

.EXAMPLE
    .\tests\Test-SecurityRegression.ps1 -OutputFolder 'C:\Source\FolderName'
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
Write-Host 'Test-SecurityRegression'
Write-Host ("Started: {0}" -f (Get-Date))
Write-Host '========================================================='

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0
$script:Config = $null
$script:Connection = $null
$script:ProfilePath = $null
$script:ResolvedOutputFolder = $null
$script:SecurityExportResult = $null
$script:RolesPath = $null
$script:UsersExportResult = $null
$script:UsersPath = $null
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
    'Export-Roles',
    'Export-Users'
)

$missingExporterFunctions = @(
    $requiredExporterFunctions | Where-Object {
        $null -eq (Get-Command -Name $_ -ErrorAction SilentlyContinue)
    }
)

if ($missingExporterFunctions.Count -gt 0) {
    throw ("Required exporter functions were not loaded: {0}" -f ($missingExporterFunctions -join ', '))
}

Write-TestStatus -Status INFO -Message 'Starting security regression test.'

Invoke-TestStep -Name 'Setup Security Test Context' -ScriptBlock {
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
        -Condition ($null -ne (Get-Command -Name Export-Roles -ErrorAction SilentlyContinue)) `
        -Message 'Export-Roles function was not loaded.'

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Export-Users -ErrorAction SilentlyContinue)) `
        -Message 'Export-Users function was not loaded.'
}

Invoke-TestStep -Name 'Read-ExportProfile' -ScriptBlock {
    if ([string]::IsNullOrWhiteSpace($script:ProfilePath)) {
        Skip-TestStep -Message 'Setup Security Test Context did not provide ProfilePath.'
    }

    if (-not (Test-Path -LiteralPath $script:ProfilePath -PathType Leaf)) {
        Skip-TestStep -Message ("Setup Security Test Context did not produce a valid export.yaml path: {0}" -f $script:ProfilePath)
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

Invoke-TestStep -Name 'Export-Roles' -ScriptBlock {
    if ($null -eq $script:Connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    if ($script:Connection.Connected -ne $true) {
        Skip-TestStep -Message 'Connection is not in a connected state.'
    }

    $script:SecurityExportResult = Export-Roles `
        -Connection $script:Connection `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $script:SecurityExportResult) `
        -Message 'Export-Roles returned null.'

    foreach ($propertyName in @('RoleCount', 'RolesPath')) {
        Assert-Condition `
            -Condition ($null -ne $script:SecurityExportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-Roles result is missing {0}." -f $propertyName)
    }

    $script:RolesPath = [string]$script:SecurityExportResult.RolesPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($script:RolesPath)) `
        -Message 'Export-Roles returned an empty RolesPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:RolesPath -PathType Leaf) `
        -Message "Roles.sql does not exist: $script:RolesPath"
}

Invoke-TestStep -Name 'Validate Roles Export' -ScriptBlock {
    if ($null -eq $script:SecurityExportResult) {
        Skip-TestStep -Message 'Export-Roles did not complete successfully.'
    }

    $securityFolder = Split-Path -Parent $script:RolesPath

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $securityFolder -PathType Container) `
        -Message "Security folder does not exist: $securityFolder"

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:RolesPath -PathType Leaf) `
        -Message "Roles.sql does not exist: $script:RolesPath"

    $rolesRawContent = Get-Content -LiteralPath $script:RolesPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($rolesRawContent)) `
        -Message "Roles.sql is empty: $script:RolesPath"

    $roleCount = [int]$script:SecurityExportResult.RoleCount

    if ($roleCount -gt 0) {
        Assert-Condition `
            -Condition ($rolesRawContent -match 'CREATE ROLE') `
            -Message 'Roles.sql does not contain CREATE ROLE while roles were exported.'
    }
    else {
        Assert-Condition `
            -Condition ($rolesRawContent -match [regex]::Escape('No user-defined database roles found.')) `
            -Message 'Roles.sql does not contain the empty-role message.'
    }
}

Invoke-TestStep -Name 'Export-Users' -ScriptBlock {
    if ($null -eq $script:Connection) {
        Skip-TestStep -Message 'Connect-SqlDatabase did not produce a valid connection object.'
    }

    if ($script:Connection.Connected -ne $true) {
        Skip-TestStep -Message 'Connection is not in a connected state.'
    }

    Assert-Condition `
        -Condition ($null -ne (Get-Command -Name Export-Users -ErrorAction SilentlyContinue)) `
        -Message 'Export-Users function was not loaded.'

    $script:UsersExportResult = Export-Users `
        -Connection $script:Connection `
        -OutputFolder $script:ResolvedOutputFolder

    Assert-Condition `
        -Condition ($null -ne $script:UsersExportResult) `
        -Message 'Export-Users returned null.'

    foreach ($propertyName in @('UserCount', 'UsersPath')) {
        Assert-Condition `
            -Condition ($null -ne $script:UsersExportResult.PSObject.Properties[$propertyName]) `
            -Message ("Export-Users result is missing {0}." -f $propertyName)
    }

    $script:UsersPath = [string]$script:UsersExportResult.UsersPath

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($script:UsersPath)) `
        -Message 'Export-Users returned an empty UsersPath.'

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:UsersPath -PathType Leaf) `
        -Message "Users.sql does not exist: $script:UsersPath"
}

Invoke-TestStep -Name 'Validate Users Export' -ScriptBlock {
    if ($null -eq $script:UsersExportResult) {
        Skip-TestStep -Message 'Export-Users did not complete successfully.'
    }

    $securityFolder = Split-Path -Parent $script:UsersPath

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $securityFolder -PathType Container) `
        -Message "Security folder does not exist: $securityFolder"

    Assert-Condition `
        -Condition (Test-Path -LiteralPath $script:UsersPath -PathType Leaf) `
        -Message "Users.sql does not exist: $script:UsersPath"

    $usersRawContent = Get-Content -LiteralPath $script:UsersPath -Raw

    Assert-Condition `
        -Condition (-not [string]::IsNullOrWhiteSpace($usersRawContent)) `
        -Message "Users.sql is empty: $script:UsersPath"

    $userCount = [int]$script:UsersExportResult.UserCount

    if ($userCount -gt 0) {
        Assert-Condition `
            -Condition ($usersRawContent -match 'CREATE USER') `
            -Message 'Users.sql does not contain CREATE USER while users were exported.'
    }
    else {
        Assert-Condition `
            -Condition ($usersRawContent -match [regex]::Escape('No user-defined database users found.')) `
            -Message 'Users.sql does not contain the empty-user message.'
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
