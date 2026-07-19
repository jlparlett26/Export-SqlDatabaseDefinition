<#
.SYNOPSIS
    Synchronize project folders to OneDrive.

.DESCRIPTION
    Copies:

      <databaseCodeRoot>\*
        EXCEPT folders listed in sync.excludeFolders

    TO

      <OneDrive>\<projectsFolder>\

    AND copies:

      <exporterProjectRoot>

    TO

      <OneDrive>\<projectsFolder>\Export-SqlDatabaseDefinition

    Configuration is loaded from:

      ..\local-config.yaml

    relative to this script.

.NOTES
    Requires:
      Install-Module powershell-yaml -Scope CurrentUser
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------
# Load Configuration
# ---------------------------------------------------------------------

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path

$configPath = Join-Path $scriptFolder '..\local-config.yaml'
$configPath = [System.IO.Path]::GetFullPath($configPath)

if (-not (Test-Path $configPath)) {
    throw "Configuration file not found: $configPath"
}

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    throw @"
Required module not found: powershell-yaml

Install using:

Install-Module powershell-yaml -Scope CurrentUser
"@
}

Import-Module powershell-yaml -ErrorAction Stop

$config = ConvertFrom-Yaml (
    Get-Content -Path $configPath -Raw
)

# ---------------------------------------------------------------------
# Validate Configuration
# ---------------------------------------------------------------------

$databaseCodeRoot   = $config.paths.databaseCodeRoot
$exporterProjectRoot = $config.paths.exporterProjectRoot

$projectsFolderName = $config.onedrive.projectsFolder

$excludeFolders = @($config.sync.excludeFolders)
$excludeDirs    = @($config.sync.excludeDirectories)

$retries     = $config.sync.robocopy.retries
$waitSeconds = $config.sync.robocopy.waitSeconds
$mirror      = [bool]$config.sync.robocopy.mirror

if (-not (Test-Path $databaseCodeRoot)) {
    throw "databaseCodeRoot not found: $databaseCodeRoot"
}

if (-not (Test-Path $exporterProjectRoot)) {
    throw "exporterProjectRoot not found: $exporterProjectRoot"
}

# ---------------------------------------------------------------------
# Discover OneDrive
# ---------------------------------------------------------------------

$oneDriveRoot = $env:OneDrive

if ([string]::IsNullOrEmpty($oneDriveRoot)) {
    throw "Unable to determine OneDrive location from environment variable OneDrive."
}

if (-not (Test-Path $oneDriveRoot)) {
    throw "OneDrive path does not exist: $oneDriveRoot"
}

$projectsRoot = Join-Path $oneDriveRoot $projectsFolderName

if (-not (Test-Path $projectsRoot)) {
    New-Item `
        -Path $projectsRoot `
        -ItemType Directory `
        -Force | Out-Null
}

Write-Host ""
Write-Host "Configuration:"
Write-Host "  Config File : $configPath"
Write-Host "  OneDrive    : $oneDriveRoot"
Write-Host "  Projects    : $projectsRoot"
Write-Host ""

# ---------------------------------------------------------------------
# Build Robocopy Arguments
# ---------------------------------------------------------------------

$robocopyArgs = @()

if ($mirror) {
    $robocopyArgs += '/MIR'
}

$robocopyArgs += "/R:$retries"
$robocopyArgs += "/W:$waitSeconds"

if ($excludeDirs.Count -gt 0) {
    $robocopyArgs += '/XD'
    $robocopyArgs += $excludeDirs
}

# ---------------------------------------------------------------------
# Sync Database Code Projects
# ---------------------------------------------------------------------

Write-Host "========================================"
Write-Host "Sync Database Code Projects"
Write-Host "========================================"
Write-Host ""

Get-ChildItem -Path $databaseCodeRoot -Directory |
    Where-Object {
        $_.Name -notin $excludeFolders
    } |
    Sort-Object Name |
    ForEach-Object {

        $source      = $_.FullName
        $destination = Join-Path $projectsRoot $_.Name

        Write-Host "Syncing:"
        Write-Host "  $source"
        Write-Host "  ->"
        Write-Host "  $destination"
        Write-Host ""

        & robocopy `
            $source `
            $destination `
            @robocopyArgs | Out-Null

        $exitCode = $LASTEXITCODE

        if ($exitCode -ge 8) {
            throw "Robocopy failed for $source (ExitCode=$exitCode)"
        }
    }

# ---------------------------------------------------------------------
# Sync Export-SqlDatabaseDefinition
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Sync Export-SqlDatabaseDefinition"
Write-Host "========================================"
Write-Host ""

$exporterDestination = Join-Path `
    $projectsRoot `
    'Export-SqlDatabaseDefinition'

Write-Host "Syncing:"
Write-Host "  $exporterProjectRoot"
Write-Host "  ->"
Write-Host "  $exporterDestination"
Write-Host ""

& robocopy `
    $exporterProjectRoot `
    $exporterDestination `
    @robocopyArgs | Out-Null

$exitCode = $LASTEXITCODE

if ($exitCode -ge 8) {
    throw "Robocopy failed for Export-SqlDatabaseDefinition (ExitCode=$exitCode)"
}

# ---------------------------------------------------------------------
# Complete
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Sync Complete"
Write-Host "========================================"
Write-Host ""
