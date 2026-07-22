<#
.SYNOPSIS
    Exports a SQL Server database definition into a standardized folder structure for
    source control, documentation, migration planning, and dependency analysis.

.DESCRIPTION
    Export-SqlDatabaseDefinition is an opinionated PowerShell automation scaffold for
    future SQL Server database export workflows. The current implementation provides
    the project skeleton, including script metadata, logging, region placeholders,
    and entry-point stubs. No SQL Server, SMO, or export functionality is implemented.

.NOTES
    File Name: Export-SqlDatabaseDefinition.ps1
    Author:   GitHub Copilot
    Version:  0.1.0
    Requires: PowerShell 7.6+
    Purpose:  Project skeleton for future development.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration
$script:ScriptVersion = '0.1.0'
$script:ProjectRoot = $PSScriptRoot
$script:DefaultConfigFileName = 'export.yaml'
$script:LogFilePath = $null

function Get-ScriptVersion {
    <#
    .SYNOPSIS
        Returns the script version.

    .DESCRIPTION
        Placeholder function for future script version resolution.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:ScriptVersion
}
#endregion

#region Logging
function Initialize-ExportLog {
    <#
    .SYNOPSIS
        Initializes export.log for the current export session.

    .DESCRIPTION
        Validates the output folder, ensures export.log exists inside that folder,
        stores the resolved file path in script scope, and returns the log file path.

    .PARAMETER OutputFolder
        Target export folder that will contain export.log.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        throw [System.ArgumentException]::new('OutputFolder cannot be null, empty, or whitespace.')
    }

    $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

    if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new(("Output folder does not exist: {0}" -f $resolvedOutputFolder))
    }

    $resolvedLogFilePath = [System.IO.Path]::Combine($resolvedOutputFolder, 'export.log')

    if (Test-Path -LiteralPath $resolvedLogFilePath) {
        if (-not (Test-Path -LiteralPath $resolvedLogFilePath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new(("Log path exists but is not a file: {0}" -f $resolvedLogFilePath))
        }
    }
    else {
        [System.IO.File]::WriteAllText($resolvedLogFilePath, [string]::Empty, [System.Text.UTF8Encoding]::new($false))
    }

    $script:LogFilePath = $resolvedLogFilePath
    return $script:LogFilePath
}

function Write-ExporterLog {
    <#
    .SYNOPSIS
        Writes a timestamped log message to the console.

    .DESCRIPTION
        Writes a timestamped message with a severity prefix. The function is a placeholder
        for future logging integration and currently emits console output only.

    .PARAMETER Level
        The severity of the log message. Supported values are Information, Warning, and Error.

    .PARAMETER Message
        The message content to write to the log.

    .EXAMPLE
        Write-ExporterLog -Level Information -Message 'Starting export'

    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Information' { 'INFO' }
        'Warning' { 'WARN' }
        'Error' { 'ERROR' }
        default { 'INFO' }
    }

    $formattedMessage = "{0} [{1}] {2}" -f $timestamp, $prefix, $Message

    switch ($Level) {
        'Information' { Write-Information -MessageData $formattedMessage -InformationAction Continue }
        'Warning' { Write-Warning -Message $formattedMessage }
        'Error' { Write-Error -Message $formattedMessage }
        default { Write-Output $formattedMessage }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:LogFilePath) -and (Test-Path -LiteralPath $script:LogFilePath -PathType Leaf)) {
        try {
            [System.IO.File]::AppendAllText(
                $script:LogFilePath,
                $formattedMessage + [Environment]::NewLine,
                [System.Text.UTF8Encoding]::new($false)
            )
        }
        catch {
            Write-Warning -Message ("Failed to write to export.log: {0}" -f $_.Exception.Message)
        }
    }
}
#endregion

#region YAML Functions
function Get-DefaultExportProfileContent {
    <#
    .SYNOPSIS
        Returns the default export profile YAML content.

    .DESCRIPTION
        Returns the default YAML configuration that is written to export.yaml when
        the export profile file does not already exist.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @'
configVersion: 1

# SQL Server connection settings
connection:

  # SQL Server instance name
  server: CHANGE_ME

  # Database name
  database: CHANGE_ME

  # Windows | SQL
  authentication: Windows

# Object types to export
export:

  schemas: true
  tables: true
  views: true
  storedProcedures: true
  functions: true
  triggers: true
  synonyms: true
  sequences: true

# Security export settings
security:

  enabled: true

  roles: true
  users: true
  permissions: true

# Dependency analysis settings
dependencies:

  enabled: true

  csv: true
  json: true
  dot: true
  svg: true
  html: true

# Reference data export settings
referenceData:

  enabled: false
  # Tables whose reference data should be exported
  tables: []
'@
}
#endregion

#region Connection Functions
function Initialize-ExportProfile {
    <#
    .SYNOPSIS
        Initializes the export profile folder and configuration file.

    .DESCRIPTION
        Creates the specified output folder, ensures that export.yaml exists in that
        folder, and returns the full path to the profile file. If export.yaml already
        exists, the function leaves it unchanged and returns the existing path.

    .PARAMETER OutputFolder
        The folder that should contain export.yaml.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder
    )

    try {
        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.ArgumentException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())

        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $resolvedOutputFolder -Force | Out-Null
            Write-ExporterLog -Level Information -Message ("Folder created: {0}" -f $resolvedOutputFolder)
        }

        $exportFilePath = [System.IO.Path]::Combine($resolvedOutputFolder, 'export.yaml')
        $resolvedExportFilePath = [System.IO.Path]::GetFullPath($exportFilePath)

        if (Test-Path -LiteralPath $resolvedExportFilePath -PathType Leaf) {
            Write-ExporterLog -Level Information -Message ("export.yaml already exists: {0}" -f $resolvedExportFilePath)
            return $resolvedExportFilePath
        }

        if (Test-Path -LiteralPath $resolvedExportFilePath) {
            Write-ExporterLog -Level Error -Message ("Path exists but is not a file: {0}" -f $resolvedExportFilePath)
            throw [System.InvalidOperationException]::new("Path exists but is not a file: $resolvedExportFilePath")
        }

        $defaultYaml = Get-DefaultExportProfileContent

        [System.IO.File]::WriteAllText($resolvedExportFilePath, $defaultYaml, [System.Text.UTF8Encoding]::new($false))
        Write-ExporterLog -Level Information -Message ("export.yaml created: {0}" -f $resolvedExportFilePath)
        return $resolvedExportFilePath
    }
    catch {
        Write-ExporterLog -Level Error -Message $_.Exception.Message
        throw
    }
}

function Read-ExportProfile {
    <#
    .SYNOPSIS
        Reads and validates an export profile YAML file.

    .DESCRIPTION
        Reads the specified YAML file, converts it to a PowerShell object, and validates
        that it contains the required configuration sections and properties for the
        Export-SqlDatabaseDefinition tool. Any validation failure results in a descriptive
        exception and no partial object is returned.

    .PARAMETER Path
        The full or relative path to the export profile YAML file.

    .EXAMPLE
        Read-ExportProfile -Path 'C:\Exports\DatabaseName\export.yaml'

    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolvedPath = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw [System.ArgumentException]::new('Path cannot be null, empty, or whitespace.')
        }

        $resolvedPath = [System.IO.Path]::GetFullPath($Path.Trim())

        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            throw [System.IO.FileNotFoundException]::new(("Configuration file not found: {0}" -f $resolvedPath))
        }

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new(("Path is not a file: {0}" -f $resolvedPath))
        }

        $extension = [System.IO.Path]::GetExtension($resolvedPath)
        if ($extension -notin '.yaml', '.yml') {
            throw [System.ArgumentException]::new(("Unsupported file extension '{0}'. Expected .yaml or .yml: {1}" -f $extension, $resolvedPath))
        }

        $yamlCommand = Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue
        if ($null -eq $yamlCommand) {
            Import-Module powershell-yaml -ErrorAction SilentlyContinue
            $yamlCommand = Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue
        }

        if ($null -eq $yamlCommand) {
            throw [System.InvalidOperationException]::new('YAML parsing requires a command named ConvertFrom-Yaml. The expected provider is usually the powershell-yaml module. Install it manually with: Install-Module powershell-yaml -Scope CurrentUser')
        }

        $rawContent = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false))
        $config = ConvertFrom-Yaml -Yaml $rawContent

        if ($null -eq $config) {
            throw [System.InvalidOperationException]::new('The YAML document is empty.')
        }

        if (-not ($config -is [System.Collections.IDictionary])) {
            throw [System.InvalidOperationException]::new('The YAML content did not resolve to a dictionary object.')
        }

        $requiredScalarValues = @{
            'configVersion' = 1
        }

        $requiredSections = @{
            'connection' = @('server', 'database', 'authentication')
            'export' = @('schemas', 'tables', 'views', 'storedProcedures', 'functions', 'triggers', 'synonyms', 'sequences')
            'security' = @('enabled', 'roles', 'users', 'permissions')
            'dependencies' = @('enabled', 'csv', 'json', 'dot', 'svg', 'html')
            'referenceData' = @('enabled', 'tables')
        }

        $missingSections = [System.Collections.Generic.List[string]]::new()
        $missingProperties = [System.Collections.Generic.List[string]]::new()
        $invalidValues = [System.Collections.Generic.List[string]]::new()

        foreach ($scalarName in $requiredScalarValues.Keys) {
            if (-not $config.Contains($scalarName)) {
                $invalidValues.Add(("Missing required value: {0}" -f $scalarName))
                continue
            }

            $scalarValue = $config[$scalarName]
            if ($null -eq $scalarValue) {
                $invalidValues.Add(("Invalid value: {0} cannot be null." -f $scalarName))
                continue
            }

            if (($scalarName -eq 'configVersion') -and ($scalarValue -ne $requiredScalarValues[$scalarName])) {
                $invalidValues.Add(("Invalid value: configVersion must be {0}; found {1}." -f $requiredScalarValues[$scalarName], $scalarValue))
            }
        }

        foreach ($sectionName in $requiredSections.Keys) {
            if (-not $config.Contains($sectionName)) {
                $missingSections.Add($sectionName)
                continue
            }

            $sectionValue = $config[$sectionName]
            if ($null -eq $sectionValue) {
                $invalidValues.Add(("Invalid value: section '{0}' cannot be null." -f $sectionName))
                continue
            }

            if (-not ($sectionValue -is [System.Collections.IDictionary])) {
                $invalidValues.Add(("Invalid value: section '{0}' must be a mapping object." -f $sectionName))
                continue
            }

            foreach ($propertyName in $requiredSections[$sectionName]) {
                if (-not $sectionValue.Contains($propertyName)) {
                    $missingProperties.Add(("{0}.{1}" -f $sectionName, $propertyName))
                }
            }

            if ($sectionName -eq 'referenceData') {
                if ($sectionValue.Contains('tables')) {
                    $tablesValue = $sectionValue['tables']
                    if ($null -eq $tablesValue) {
                        $invalidValues.Add('Invalid value: referenceData.tables cannot be null. Expected a collection of table names.')
                    }
                    elseif ($tablesValue -is [string]) {
                        $invalidValues.Add('Invalid value: referenceData.tables must be a collection, not a scalar string.')
                    }
                    elseif ($tablesValue -is [System.Collections.IDictionary]) {
                        $invalidValues.Add('Invalid value: referenceData.tables must be a collection of strings. Found a mapping object.')
                    }
                    elseif ($tablesValue -is [System.Collections.IEnumerable]) {
                        $entryIndex = 0
                        foreach ($tableEntry in $tablesValue) {
                            if ($tableEntry -isnot [string]) {
                                $entryType = if ($null -eq $tableEntry) { 'null' } else { $tableEntry.GetType().FullName }
                                $invalidValues.Add(("Invalid value: referenceData.tables[{0}] must be a string. Found {1}." -f $entryIndex, $entryType))
                            }

                            if ($tableEntry -is [string] -and [string]::IsNullOrWhiteSpace($tableEntry)) {
                                $invalidValues.Add(("Invalid value: referenceData.tables[{0}] cannot be empty or whitespace." -f $entryIndex))
                            }

                            $entryIndex++
                        }
                    }
                    else {
                        $invalidValues.Add(("Invalid value: referenceData.tables must be a collection of strings. Found {0}." -f $tablesValue.GetType().FullName))
                    }
                }
            }
        }

        if (($missingSections.Count -gt 0) -or ($missingProperties.Count -gt 0) -or ($invalidValues.Count -gt 0)) {
            $problemLines = [System.Collections.Generic.List[string]]::new()

            foreach ($section in $missingSections) {
                $problemLines.Add(("  - Missing section: {0}" -f $section))
            }

            foreach ($property in $missingProperties) {
                $problemLines.Add(("  - Missing property: {0}" -f $property))
            }

            foreach ($invalid in $invalidValues) {
                $problemLines.Add(("  - {0}" -f $invalid))
            }

            $problemText = $problemLines -join [Environment]::NewLine

            $validationSummary = 'Validation failed: {0} missing section(s), {1} missing propertie(s), {2} invalid value(s).' -f $missingSections.Count, $missingProperties.Count, $invalidValues.Count

            $message = @(
                'Configuration validation failed.',
                '',
                'File:',
                ('    {0}' -f $resolvedPath),
                '',
                'Problems found:',
                $problemText,
                '',
                'Suggested actions:',
                '  Option 1:',
                '    Correct the configuration manually.',
                '  Option 2:',
                '    Delete export.yaml and rerun the exporter.',
                '    The exporter will generate a new default template.',
                '',
                'Validation aborted.'
            ) -join [Environment]::NewLine

            $logMessage = @(
                $validationSummary,
                '',
                $message
            ) -join [Environment]::NewLine

            Write-ExporterLog -Level Error -Message $logMessage -ErrorAction Continue
            throw [System.InvalidOperationException]::new($message)
        }

        Write-ExporterLog -Level Information -Message ("Configuration file loaded: {0}" -f $resolvedPath)
        Write-ExporterLog -Level Information -Message ("Validation successful: {0}" -f $resolvedPath)
        return $config
    }
    catch {
        if ($_.Exception.Message -and $_.Exception.Message -match 'Configuration validation failed') {
            throw
        }

        $displayPath = if ([string]::IsNullOrWhiteSpace($resolvedPath)) { $Path } else { $resolvedPath }

        $problemDescription = switch -Regex ($_.Exception.GetType().FullName) {
            'FileNotFoundException' { 'The configuration file does not exist at the specified path.'; break }
            'DirectoryNotFoundException' { 'The configuration file path is invalid or inaccessible.'; break }
            'UnauthorizedAccessException' { 'The configuration file cannot be accessed due to permissions.'; break }
            'ArgumentException' { 'The configuration path or file type is invalid. Use a .yaml or .yml file.'; break }
            default {
                if ($_.Exception.Message -match 'YAML parsing requires a command named ConvertFrom-Yaml') {
                    'YAML parsing support is unavailable. Install the required module: Install-Module powershell-yaml -Scope CurrentUser'
                }
                elseif ($_.Exception.Message -match 'did not resolve to a dictionary object|YAML document is empty') {
                    'The configuration file structure is invalid or empty.'
                }
                else {
                    'The configuration file could not be read or parsed. Verify YAML syntax and required sections.'
                }
            }
        }

        $friendlyMessage = @(
            'Configuration load failed.',
            '',
            'File:',
            ('    {0}' -f $displayPath),
            '',
            'Problem:',
            ("  - {0}" -f $problemDescription),
            '',
            'Suggested actions:',
            '  Option 1:',
            '    Verify that export.yaml exists, is readable, and contains valid YAML syntax.',
            '  Option 2:',
            '    Delete export.yaml and rerun the exporter.',
            '    The exporter will generate a new default template.',
            '',
            'Validation aborted.'
        ) -join [Environment]::NewLine

        Write-ExporterLog -Level Error -Message ('Configuration load failed: {0}' -f $displayPath) -ErrorAction Continue
        throw [System.InvalidOperationException]::new($friendlyMessage)
    }
}

function Connect-SqlDatabase {
    <#
    .SYNOPSIS
        Connects to a SQL Server database.

    .DESCRIPTION
        Validates SQL Server connection settings from the parsed export profile,
        establishes a Windows-authenticated connection to the target SQL Server
        instance, and confirms that the configured database exists.

    .PARAMETER Config
        Parsed export profile configuration dictionary.

    .EXAMPLE
        Connect-SqlDatabase -Config $config

    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    try {
        if ($null -eq $Config) {
            throw [System.InvalidOperationException]::new('Config cannot be null.')
        }

        if (-not $Config.Contains('connection')) {
            throw [System.InvalidOperationException]::new('Connection section is missing from export.yaml.')
        }

        $connection = $Config['connection']
        if ($null -eq $connection -or $connection -isnot [System.Collections.IDictionary]) {
            throw [System.InvalidOperationException]::new('Connection section is invalid in export.yaml.')
        }

        if (-not $connection.Contains('server')) {
            throw [System.InvalidOperationException]::new('Missing connection.server in export.yaml.')
        }

        if (-not $connection.Contains('database')) {
            throw [System.InvalidOperationException]::new('Missing connection.database in export.yaml.')
        }

        if (-not $connection.Contains('authentication')) {
            throw [System.InvalidOperationException]::new('Missing connection.authentication in export.yaml.')
        }

        $serverName = [string]$connection['server']
        $databaseName = [string]$connection['database']
        $authentication = [string]$connection['authentication']

        if ([string]::IsNullOrWhiteSpace($serverName)) {
            throw [System.InvalidOperationException]::new('Server name is missing from export.yaml.')
        }

        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            throw [System.InvalidOperationException]::new('Database name is missing from export.yaml.')
        }

        if ($serverName.Trim() -ieq 'CHANGE_ME') {
            throw [System.InvalidOperationException]::new('Server value is still CHANGE_ME.')
        }

        if ($databaseName.Trim() -ieq 'CHANGE_ME') {
            throw [System.InvalidOperationException]::new('Database value is still CHANGE_ME.')
        }

        if ([string]::IsNullOrWhiteSpace($authentication)) {
            throw [System.InvalidOperationException]::new('Authentication mode is missing from export.yaml.')
        }

        if ($authentication.Trim() -ine 'Windows') {
            throw [System.InvalidOperationException]::new('Only Windows authentication is currently supported.')
        }

        Write-ExporterLog -Level Information -Message 'Starting SQL connection'
        Write-ExporterLog -Level Information -Message ("Server name: {0}" -f $serverName)
        Write-ExporterLog -Level Information -Message ("Database name: {0}" -f $databaseName)
        Write-ExporterLog -Level Information -Message ("Authentication mode: {0}" -f $authentication)

        $sqlServerModule = Get-Module -ListAvailable -Name 'SqlServer' | Select-Object -First 1
        if ($null -eq $sqlServerModule) {
            Import-Module SqlServer -ErrorAction SilentlyContinue
            $sqlServerModule = Get-Module -ListAvailable -Name 'SqlServer' | Select-Object -First 1
        }

        if ($null -eq $sqlServerModule) {
            throw [System.InvalidOperationException]::new((
                'SQL Server connectivity requires the SqlServer PowerShell module.' + [Environment]::NewLine +
                'Install it with:' + [Environment]::NewLine +
                'Install-Module SqlServer -Scope CurrentUser'
            ))
        }

        if (-not ('Microsoft.SqlServer.Management.Smo.Server' -as [Type])) {
            Import-Module SqlServer -ErrorAction SilentlyContinue
        }

        if (-not ('Microsoft.SqlServer.Management.Smo.Server' -as [Type])) {
            throw [System.InvalidOperationException]::new((
                'SQL Server connectivity requires the SqlServer PowerShell module.' + [Environment]::NewLine +
                'Install it with:' + [Environment]::NewLine +
                'Install-Module SqlServer -Scope CurrentUser'
            ))
        }

        try {
            $server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
            $server.ConnectionContext.LoginSecure = $true
            $server.ConnectionContext.Connect()
        }
        catch {
            throw [System.InvalidOperationException]::new(("Could not connect to SQL Server: {0}" -f $serverName))
        }

        Write-ExporterLog -Level Information -Message 'Connection successful'

        $database = $server.Databases[$databaseName]
        if ($null -eq $database) {
            throw [System.InvalidOperationException]::new(("Database was not found on the server: {0}" -f $databaseName))
        }

        Write-ExporterLog -Level Information -Message 'Database found'

        return [PSCustomObject]@{
            ServerName = $serverName
            DatabaseName = $databaseName
            Authentication = $authentication
            Connected = $true
            ServerObject = $server
            DatabaseObject = $database
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Connection failure') -ErrorAction Continue
        throw
    }
}
#endregion

#region Database Export Functions
function Write-ExportInfo {
    <#
    .SYNOPSIS
        Writes export metadata to exportinfo.json.

    .DESCRIPTION
        Creates or overwrites exportinfo.json in the specified export folder using
        the active configuration and SQL connection result.

    .PARAMETER Config
        Parsed export profile configuration dictionary.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder that will contain exportinfo.json.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Config) {
            throw [System.InvalidOperationException]::new('Config cannot be null.')
        }

        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        $requiredConnectionProperties = @('ServerName', 'DatabaseName', 'Authentication', 'Connected', 'ServerObject', 'DatabaseObject')
        foreach ($propertyName in $requiredConnectionProperties) {
            $connectionProperty = $Connection.PSObject.Properties[$propertyName]
            if ($null -eq $connectionProperty) {
                throw [System.InvalidOperationException]::new(("Connection result is missing required property: {0}" -f $propertyName))
            }
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        Write-ExporterLog -Level Information -Message 'Starting exportinfo.json creation'

        $exportInfoPath = [System.IO.Path]::Combine($resolvedOutputFolder, 'exportinfo.json')
        Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $exportInfoPath)

        $databaseObject = $Connection.DatabaseObject

        $getDatabaseProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $createDateValue = & $getDatabaseProperty -Object $databaseObject -PropertyName 'CreateDate'
        if ($null -ne $createDateValue -and $createDateValue -is [datetime]) {
            $createDateValue = $createDateValue.ToString('o')
        }

        $compatibilityLevelValue = & $getDatabaseProperty -Object $databaseObject -PropertyName 'CompatibilityLevel'
        if ($null -ne $compatibilityLevelValue) {
            $compatibilityLevelValue = [string]$compatibilityLevelValue
        }

        $recoveryModelValue = & $getDatabaseProperty -Object $databaseObject -PropertyName 'RecoveryModel'
        if ($null -ne $recoveryModelValue) {
            $recoveryModelValue = [string]$recoveryModelValue
        }

        $exportInfo = [ordered]@{
            toolName = 'Export-SqlDatabaseDefinition'
            toolVersion = Get-ScriptVersion
            exportedAt = [DateTimeOffset]::UtcNow.ToString('o')
            serverName = [string]$Connection.ServerName
            databaseName = [string]$Connection.DatabaseName
            authentication = [string]$Connection.Authentication
            connected = [bool]$Connection.Connected
            databaseProperties = [ordered]@{
                name = (& $getDatabaseProperty -Object $databaseObject -PropertyName 'Name')
                id = (& $getDatabaseProperty -Object $databaseObject -PropertyName 'ID')
                createDate = $createDateValue
                compatibilityLevel = $compatibilityLevelValue
                collation = (& $getDatabaseProperty -Object $databaseObject -PropertyName 'Collation')
                recoveryModel = $recoveryModelValue
                owner = (& $getDatabaseProperty -Object $databaseObject -PropertyName 'Owner')
            }
        }

        $json = $exportInfo | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($exportInfoPath, $json, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'exportinfo.json written successfully'
        return $exportInfoPath
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Error creating exportinfo.json: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to create exportinfo.json. {0}' -f $_.Exception.Message))
    }
}

function Export-DatabaseProperties {
    <#
    .SYNOPSIS
        Exports database-level properties to Database\Database.sql.

    .DESCRIPTION
        Creates the Database folder in the export output path when needed and writes
        deterministic database metadata comments using the active SQL connection.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting Database Properties export'

        $databaseFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Database')
        if (-not (Test-Path -LiteralPath $databaseFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $databaseFolder -Force | Out-Null
        }

        $databaseSqlPath = [System.IO.Path]::Combine($databaseFolder, 'Database.sql')
        Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $databaseSqlPath)

        $database = $Connection.DatabaseObject

        $getDatabaseProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $nameValue = & $getDatabaseProperty -Object $database -PropertyName 'Name'
        $idValue = & $getDatabaseProperty -Object $database -PropertyName 'ID'
        $createDateValue = & $getDatabaseProperty -Object $database -PropertyName 'CreateDate'
        $compatibilityLevelValue = & $getDatabaseProperty -Object $database -PropertyName 'CompatibilityLevel'
        $collationValue = & $getDatabaseProperty -Object $database -PropertyName 'Collation'
        $recoveryModelValue = & $getDatabaseProperty -Object $database -PropertyName 'RecoveryModel'
        $ownerValue = & $getDatabaseProperty -Object $database -PropertyName 'Owner'

        if ($null -ne $createDateValue -and $createDateValue -is [datetime]) {
            $createDateValue = $createDateValue.ToString('o')
        }

        if ($null -ne $compatibilityLevelValue) {
            $compatibilityLevelValue = [string]$compatibilityLevelValue
        }

        if ($null -ne $recoveryModelValue) {
            $recoveryModelValue = [string]$recoveryModelValue
        }

        $content = @(
            ('-- Database Name: {0}' -f [string]$nameValue),
            ('-- Database Id: {0}' -f [string]$idValue),
            ('-- Create Date: {0}' -f [string]$createDateValue),
            ('-- Compatibility Level: {0}' -f [string]$compatibilityLevelValue),
            ('-- Collation: {0}' -f [string]$collationValue),
            ('-- Recovery Model: {0}' -f [string]$recoveryModelValue),
            ('-- Owner: {0}' -f [string]$ownerValue)
        ) -join [Environment]::NewLine

        [System.IO.File]::WriteAllText($databaseSqlPath, $content, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Database.sql created successfully'
        return $databaseSqlPath
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Database export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export database properties. {0}' -f $_.Exception.Message))
    }
}

function Export-Schemas {
    <#
    .SYNOPSIS
        Exports user-defined database schemas to one file per schema.

    .DESCRIPTION
        Creates the Schemas output folder when needed and writes one deterministic
        SQL file per user-defined schema from the connected database.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting schema export'

        $schemasFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Schemas')
        if (-not (Test-Path -LiteralPath $schemasFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $schemasFolder -Force | Out-Null
        }

        $rawSchemas = @($Connection.DatabaseObject.Schemas)
        $schemasToExport = @(
            $rawSchemas |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Name -ine 'sys') -and
                    ([string]$_.Name -ine 'INFORMATION_SCHEMA')
                } |
                Sort-Object -Property Name
        )

        Write-ExporterLog -Level Information -Message ("Number of schemas found: {0}" -f $schemasToExport.Count)

        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($schema in $schemasToExport) {
            $schemaName = [string]$schema.Name
            $schemaOwner = $null

            try {
                $schemaOwnerProperty = $schema.PSObject.Properties['Owner']
                if ($null -ne $schemaOwnerProperty -and -not [string]::IsNullOrWhiteSpace([string]$schemaOwnerProperty.Value)) {
                    $schemaOwner = [string]$schemaOwnerProperty.Value
                }
            }
            catch {
                $schemaOwner = $null
            }

            $schemaFilePath = [System.IO.Path]::Combine($schemasFolder, ('{0}.sql' -f $schemaName))
            $escapedSchemaName = $schemaName.Replace(']', ']]')

            if ([string]::IsNullOrWhiteSpace($schemaOwner)) {
                $schemaScript = @(
                    ('CREATE SCHEMA [{0}]' -f $escapedSchemaName),
                    'GO'
                ) -join [Environment]::NewLine
            }
            else {
                $escapedSchemaOwner = $schemaOwner.Replace(']', ']]')
                $schemaScript = @(
                    ('CREATE SCHEMA [{0}]' -f $escapedSchemaName),
                    ('AUTHORIZATION [{0}]' -f $escapedSchemaOwner),
                    'GO'
                ) -join [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($schemaFilePath, $schemaScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($schemaFilePath)
            Write-ExporterLog -Level Information -Message ("Schema file created: {0}" -f $schemaFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Schema export completed'

        return [PSCustomObject]@{
            SchemaCount = $schemasToExport.Count
            OutputFolder = $schemasFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Schema export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export schemas. {0}' -f $_.Exception.Message))
    }
}

function Export-Tables {
    <#
    .SYNOPSIS
        Exports user-defined table definitions to one file per table.

    .DESCRIPTION
        Creates the Tables output folder when needed and writes deterministic,
        schema-only table scripts for user-defined tables.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting table export'

        $tablesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Tables')
        Write-ExporterLog -Level Information -Message ("Output folder: {0}" -f $tablesFolder)

        if (-not (Test-Path -LiteralPath $tablesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $tablesFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject
        $rawTables = @($database.Tables)

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $userTables = @(
            $rawTables |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Number of user tables found: {0}" -f $userTables.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        foreach ($propertyName in @('Indexes', 'DriAll', 'Triggers', 'ScriptBatchTerminator')) {
            try {
                $optionProperty = $scriptingOptions.PSObject.Properties[$propertyName]
                if ($null -ne $optionProperty) {
                    switch ($propertyName) {
                        'Indexes' { $scriptingOptions.Indexes = $true }
                        'DriAll' { $scriptingOptions.DriAll = $true }
                        'Triggers' { $scriptingOptions.Triggers = $false }
                        'ScriptBatchTerminator' { $scriptingOptions.ScriptBatchTerminator = $true }
                    }
                }
            }
            catch {
                # Ignore unsupported scripting options on older/different SMO versions.
                $null = $_
            }
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($table in $userTables) {
            $schemaName = [string]$table.Schema
            $tableName = [string]$table.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeTableName = [Regex]::Replace($tableName, $invalidCharacterPattern, '_')
            $tableFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeTableName
            $tableFilePath = [System.IO.Path]::Combine($tablesFolder, $tableFileName)

            $scriptLines = @()
            try {
                $scriptLines = @($table.Script($scriptingOptions))
            }
            catch {
                throw [System.InvalidOperationException]::new(("Table scripting failed for [{0}].[{1}]." -f $schemaName, $tableName))
            }

            $tableScript = ($scriptLines -join [Environment]::NewLine)
            if ($tableScript.Length -gt 0 -and -not $tableScript.EndsWith([Environment]::NewLine)) {
                $tableScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($tableFilePath, $tableScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($tableFilePath)
            Write-ExporterLog -Level Information -Message ("Table file created: {0}" -f $tableFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Table export completed'

        return [PSCustomObject]@{
            TableCount = $userTables.Count
            OutputFolder = $tablesFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Table export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export tables. {0}' -f $_.Exception.Message))
    }
}

function Export-Views {
    <#
    .SYNOPSIS
        Exports user-defined view definitions to one file per view.

    .DESCRIPTION
        Creates the Views output folder when needed and writes deterministic,
        schema-only view scripts for user-defined views.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting view export'

        $viewsFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Views')
        if (-not (Test-Path -LiteralPath $viewsFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $viewsFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject
        $rawViews = @($database.Views)

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $userViews = @(
            $rawViews |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Number of views found: {0}" -f $userViews.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($view in $userViews) {
            $schemaName = [string]$view.Schema
            $viewName = [string]$view.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeViewName = [Regex]::Replace($viewName, $invalidCharacterPattern, '_')
            $viewFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeViewName
            $viewFilePath = [System.IO.Path]::Combine($viewsFolder, $viewFileName)

            $scriptLines = @()
            try {
                $scriptLines = @($view.Script($scriptingOptions))
            }
            catch {
                throw [System.InvalidOperationException]::new(("View scripting failed for [{0}].[{1}]." -f $schemaName, $viewName))
            }

            $viewScript = ($scriptLines -join [Environment]::NewLine)
            if ($viewScript.Length -gt 0 -and -not $viewScript.EndsWith([Environment]::NewLine)) {
                $viewScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($viewFilePath, $viewScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($viewFilePath)
            Write-ExporterLog -Level Information -Message ("View file created: {0}" -f $viewFilePath)
        }

        Write-ExporterLog -Level Information -Message 'View export complete'

        return [PSCustomObject]@{
            ViewCount = $userViews.Count
            OutputFolder = $viewsFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('View export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export views. {0}' -f $_.Exception.Message))
    }
}

function Export-StoredProcedures {
    <#
    .SYNOPSIS
        Exports user-defined stored procedure definitions to one file per procedure.

    .DESCRIPTION
        Creates the StoredProcedures output folder when needed and writes deterministic,
        schema-only stored procedure scripts for user-defined procedures.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting stored procedure export'

        $proceduresFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'StoredProcedures')
        if (-not (Test-Path -LiteralPath $proceduresFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $proceduresFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject
        $rawProcedures = @($database.StoredProcedures)

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $userProcedures = @(
            $rawProcedures |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject')) -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystem'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Procedure count: {0}" -f $userProcedures.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($procedure in $userProcedures) {
            $schemaName = [string]$procedure.Schema
            $procedureName = [string]$procedure.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeProcedureName = [Regex]::Replace($procedureName, $invalidCharacterPattern, '_')
            $procedureFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeProcedureName
            $procedureFilePath = [System.IO.Path]::Combine($proceduresFolder, $procedureFileName)

            $scriptLines = @()
            try {
                $scriptLines = @($procedure.Script($scriptingOptions))
            }
            catch {
                throw [System.InvalidOperationException]::new(("Stored procedure scripting failed for [{0}].[{1}]." -f $schemaName, $procedureName))
            }

            $procedureScript = ($scriptLines -join [Environment]::NewLine)
            if ($procedureScript.Length -gt 0 -and -not $procedureScript.EndsWith([Environment]::NewLine)) {
                $procedureScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($procedureFilePath, $procedureScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($procedureFilePath)
            Write-ExporterLog -Level Information -Message ("Stored procedure exported: {0}" -f $procedureFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Stored procedure export completed'

        return [PSCustomObject]@{
            ProcedureCount = $userProcedures.Count
            OutputFolder = $proceduresFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Stored procedure export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export stored procedures. {0}' -f $_.Exception.Message))
    }
}

function Export-Functions {
    <#
    .SYNOPSIS
        Exports user-defined function definitions to one file per function.

    .DESCRIPTION
        Creates the Functions output folder when needed and writes deterministic,
        schema-only function scripts for user-defined SQL functions.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting function export'

        $functionsFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Functions')
        if (-not (Test-Path -LiteralPath $functionsFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $functionsFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject
        $rawFunctions = @($database.UserDefinedFunctions)

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $userFunctions = @(
            $rawFunctions |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject')) -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystem'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Function count: {0}" -f $userFunctions.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($functionObject in $userFunctions) {
            $schemaName = [string]$functionObject.Schema
            $functionName = [string]$functionObject.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeFunctionName = [Regex]::Replace($functionName, $invalidCharacterPattern, '_')
            $functionFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeFunctionName
            $functionFilePath = [System.IO.Path]::Combine($functionsFolder, $functionFileName)

            $scriptLines = @()
            try {
                $scriptLines = @($functionObject.Script($scriptingOptions))
            }
            catch {
                throw [System.InvalidOperationException]::new(("Function scripting failed for [{0}].[{1}]." -f $schemaName, $functionName))
            }

            $functionScript = ($scriptLines -join [Environment]::NewLine)
            if ($functionScript.Length -gt 0 -and -not $functionScript.EndsWith([Environment]::NewLine)) {
                $functionScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($functionFilePath, $functionScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($functionFilePath)
            Write-ExporterLog -Level Information -Message ("Function exported: {0}" -f $functionFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Function export completed'

        return [PSCustomObject]@{
            FunctionCount = $userFunctions.Count
            OutputFolder = $functionsFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Function export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export functions. {0}' -f $_.Exception.Message))
    }
}

function Export-Triggers {
    <#
    .SYNOPSIS
        Exports user-defined trigger definitions to one file per trigger.

    .DESCRIPTION
        Creates the Triggers output folder when needed and writes deterministic,
        schema-only trigger scripts for user-defined database and table triggers.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting trigger export'

        $triggersFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Triggers')
        if (-not (Test-Path -LiteralPath $triggersFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $triggersFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $triggerEntries = [System.Collections.Generic.List[object]]::new()

        foreach ($databaseTrigger in @($database.Triggers)) {
            if ($null -eq $databaseTrigger) {
                continue
            }

            if (& $getBooleanProperty -Object $databaseTrigger -PropertyName 'IsSystemObject') {
                continue
            }

            if (& $getBooleanProperty -Object $databaseTrigger -PropertyName 'IsSystem') {
                continue
            }

            if ([string]::IsNullOrWhiteSpace([string]$databaseTrigger.Name)) {
                continue
            }

            $databaseTriggerType = 'Database'
            try {
                $databaseTriggerTypeName = $databaseTrigger.GetType().Name
                if (-not [string]::IsNullOrWhiteSpace($databaseTriggerTypeName) -and ($databaseTriggerTypeName -match 'Ddl')) {
                    $databaseTriggerType = 'DDL'
                }
            }
            catch {
                $databaseTriggerType = 'Database'
            }

            $triggerEntries.Add([PSCustomObject]@{
                Scope = 'Database'
                ScopeOrder = 1
                SchemaName = 'Database'
                TriggerName = [string]$databaseTrigger.Name
                TriggerType = $databaseTriggerType
                ParentObject = $null
                TriggerObject = $databaseTrigger
            })
        }

        $userTables = @(
            @($database.Tables) |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject'))
                }
        )

        foreach ($table in $userTables) {
            foreach ($tableTrigger in @($table.Triggers)) {
                if ($null -eq $tableTrigger) {
                    continue
                }

                if (& $getBooleanProperty -Object $tableTrigger -PropertyName 'IsSystemObject') {
                    continue
                }

                if (& $getBooleanProperty -Object $tableTrigger -PropertyName 'IsSystem') {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace([string]$tableTrigger.Name)) {
                    continue
                }

                $schemaName = if (-not [string]::IsNullOrWhiteSpace([string]$tableTrigger.Schema)) {
                    [string]$tableTrigger.Schema
                }
                else {
                    [string]$table.Schema
                }

                if ([string]::IsNullOrWhiteSpace($schemaName)) {
                    $schemaName = 'dbo'
                }

                $triggerEntries.Add([PSCustomObject]@{
                    Scope = 'Table'
                    ScopeOrder = 2
                    SchemaName = $schemaName
                    TriggerName = [string]$tableTrigger.Name
                    TriggerType = 'DML/Table'
                    ParentObject = ("{0}.{1}" -f [string]$table.Schema, [string]$table.Name)
                    TriggerObject = $tableTrigger
                })
            }
        }

        $orderedTriggers = @(
            $triggerEntries |
                Sort-Object -Property ScopeOrder, SchemaName, TriggerName
        )

        Write-ExporterLog -Level Information -Message ("Trigger count: {0}" -f $orderedTriggers.Count)

        $databaseTriggerCount = @($orderedTriggers | Where-Object { $_.TriggerType -eq 'Database' }).Count
        $ddlTriggerCount = @($orderedTriggers | Where-Object { $_.TriggerType -eq 'DDL' }).Count
        $dmlTriggerCount = @($orderedTriggers | Where-Object { $_.TriggerType -eq 'DML/Table' }).Count

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($triggerEntry in $orderedTriggers) {
            $schemaName = [string]$triggerEntry.SchemaName
            $triggerName = [string]$triggerEntry.TriggerName
            $triggerType = [string]$triggerEntry.TriggerType
            $parentObject = [string]$triggerEntry.ParentObject
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeTriggerName = [Regex]::Replace($triggerName, $invalidCharacterPattern, '_')
            $triggerFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeTriggerName
            $triggerFilePath = [System.IO.Path]::Combine($triggersFolder, $triggerFileName)

            $triggerLogLines = @(
                'Exporting trigger:',
                ("    Name: {0}" -f $triggerName),
                ("    Type: {0}" -f $triggerType)
            )

            if (-not [string]::IsNullOrWhiteSpace($parentObject)) {
                $triggerLogLines += ("    Parent: {0}" -f $parentObject)
            }

            Write-ExporterLog -Level Information -Message ($triggerLogLines -join [Environment]::NewLine)

            $scriptLines = @()
            try {
                $scriptLines = @($triggerEntry.TriggerObject.Script($scriptingOptions))
            }
            catch {
                throw [System.InvalidOperationException]::new(("Trigger scripting failed for [{0}].[{1}]." -f $schemaName, $triggerName))
            }

            $triggerScript = ($scriptLines -join [Environment]::NewLine)

            $metadataLines = @(
                ("-- Trigger Type: {0}" -f $triggerType)
            )

            if (-not [string]::IsNullOrWhiteSpace($parentObject)) {
                $metadataLines += ("-- Parent Object: {0}" -f $parentObject)
            }

            $metadataHeader = ($metadataLines -join [Environment]::NewLine)
            $triggerScript = "{0}{1}{1}{2}" -f $metadataHeader, [Environment]::NewLine, $triggerScript

            if ($triggerScript.Length -gt 0 -and -not $triggerScript.EndsWith([Environment]::NewLine)) {
                $triggerScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($triggerFilePath, $triggerScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($triggerFilePath)
            Write-ExporterLog -Level Information -Message ("Trigger exported: {0}" -f $triggerFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Trigger export completed'

        return [PSCustomObject]@{
            TriggerCount = $orderedTriggers.Count
            DatabaseTriggers = $databaseTriggerCount
            DdlTriggers = $ddlTriggerCount
            DmlTriggers = $dmlTriggerCount
            OutputFolder = $triggersFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Trigger export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export triggers. {0}' -f $_.Exception.Message))
    }
}

function Export-Synonyms {
    <#
    .SYNOPSIS
        Exports user-defined synonym definitions to one file per synonym.

    .DESCRIPTION
        Creates the Synonyms output folder when needed and writes deterministic,
        schema-only synonym scripts for user-defined synonyms.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting synonym export'

        $synonymsFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Synonyms')
        if (-not (Test-Path -LiteralPath $synonymsFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $synonymsFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $getStringProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return ''
                }

                return [string]$property.Value
            }
            catch {
                return ''
            }
        }

        $quoteIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $userSynonyms = @(
            @($database.Synonyms) |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject')) -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystem'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Synonym count: {0}" -f $userSynonyms.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($synonym in $userSynonyms) {
            $schemaName = [string]$synonym.Schema
            $synonymName = [string]$synonym.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeSynonymName = [Regex]::Replace($synonymName, $invalidCharacterPattern, '_')
            $synonymFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeSynonymName
            $synonymFilePath = [System.IO.Path]::Combine($synonymsFolder, $synonymFileName)

            $baseObject = [string]$synonym.BaseObject
            if ([string]::IsNullOrWhiteSpace($baseObject)) {
                $baseServer = (& $getStringProperty -Object $synonym -PropertyName 'BaseServer')
                $baseDatabase = (& $getStringProperty -Object $synonym -PropertyName 'BaseDatabase')
                $baseSchema = (& $getStringProperty -Object $synonym -PropertyName 'BaseSchema')
                $baseName = (& $getStringProperty -Object $synonym -PropertyName 'BaseObjectName')
                if ([string]::IsNullOrWhiteSpace($baseName)) {
                    $baseName = (& $getStringProperty -Object $synonym -PropertyName 'BaseObject')
                }

                $baseParts = [System.Collections.Generic.List[string]]::new()
                if (-not [string]::IsNullOrWhiteSpace($baseServer)) {
                    $baseParts.Add($baseServer)
                }

                if (-not [string]::IsNullOrWhiteSpace($baseDatabase)) {
                    $baseParts.Add($baseDatabase)
                }

                if (-not [string]::IsNullOrWhiteSpace($baseSchema)) {
                    $baseParts.Add($baseSchema)
                }

                if (-not [string]::IsNullOrWhiteSpace($baseName)) {
                    $baseParts.Add($baseName)
                }

                $baseObject = ($baseParts -join '.')
            }

            if ([string]::IsNullOrWhiteSpace($baseObject)) {
                throw [System.InvalidOperationException]::new(("Synonym base object is missing for [{0}].[{1}]." -f $schemaName, $synonymName))
            }

            Write-ExporterLog -Level Information -Message ((
                'Exporting synonym:{0}    Name: {1}.{2}{0}    Base Object: {3}' -f
                [Environment]::NewLine,
                $schemaName,
                $synonymName,
                $baseObject
            ))

            $scriptLines = @()
            $usedManualScripting = $false

            try {
                if ($null -ne $synonym -and $null -ne $synonym.PSObject.Methods['Script']) {
                    $scriptLines = @($synonym.Script($scriptingOptions))
                }
            }
            catch {
                $usedManualScripting = $true
            }

            if (@($scriptLines).Count -eq 0) {
                $usedManualScripting = $true
            }

            if ($usedManualScripting) {
                $scriptLines = @(
                    ('CREATE SYNONYM {0}.{1}' -f (& $quoteIdentifier -Value $schemaName), (& $quoteIdentifier -Value $synonymName)),
                    ('    FOR {0}' -f $baseObject),
                    'GO'
                )
            }

            $synonymScript = ($scriptLines -join [Environment]::NewLine)

            $metadataLines = @(
                ("-- Synonym Name: {0}.{1}" -f $schemaName, $synonymName),
                ("-- Base Object: {0}" -f $baseObject)
            )

            $metadataHeader = ($metadataLines -join [Environment]::NewLine)
            $synonymScript = "{0}{1}{1}{2}" -f $metadataHeader, [Environment]::NewLine, $synonymScript

            if ($synonymScript.Length -gt 0 -and -not $synonymScript.EndsWith([Environment]::NewLine)) {
                $synonymScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($synonymFilePath, $synonymScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($synonymFilePath)
            Write-ExporterLog -Level Information -Message ("Synonym exported: {0}" -f $synonymFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Synonym export completed'

        return [PSCustomObject]@{
            SynonymCount = $userSynonyms.Count
            OutputFolder = $synonymsFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Synonym export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export synonyms. {0}' -f $_.Exception.Message))
    }
}

function Export-Sequences {
    <#
    .SYNOPSIS
        Exports user-defined sequence definitions to one file per sequence.

    .DESCRIPTION
        Creates the Sequences output folder when needed and writes deterministic,
        schema-only sequence scripts for user-defined sequences.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting sequence export'

        $sequencesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Sequences')
        if (-not (Test-Path -LiteralPath $sequencesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $sequencesFolder -Force | Out-Null
        }

        $database = $Connection.DatabaseObject

        $getPropertyValue = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            $value = & $getPropertyValue -Object $Object -PropertyName $PropertyName
            if ($null -eq $value) {
                return $false
            }

            try {
                return [bool]$value
            }
            catch {
                return $false
            }
        }

        $getStringProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            $value = & $getPropertyValue -Object $Object -PropertyName $PropertyName
            if ($null -eq $value) {
                return ''
            }

            try {
                return [string]$value
            }
            catch {
                return ''
            }
        }

        $toInvariantString = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            if ($null -eq $Value) {
                return ''
            }

            try {
                return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            }
            catch {
                return [string]$Value
            }
        }

        $quoteIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $userSequences = @(
            @($database.Sequences) |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject')) -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystem'))
                } |
                Sort-Object -Property Schema, Name
        )

        Write-ExporterLog -Level Information -Message ("Sequence count: {0}" -f $userSequences.Count)

        $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
        $scriptingOptions.ScriptSchema = $true
        $scriptingOptions.ScriptData = $false
        $scriptingOptions.IncludeHeaders = $false
        $scriptingOptions.SchemaQualify = $true

        try {
            $batchTerminatorProperty = $scriptingOptions.PSObject.Properties['ScriptBatchTerminator']
            if ($null -ne $batchTerminatorProperty) {
                $scriptingOptions.ScriptBatchTerminator = $true
            }
        }
        catch {
            # Ignore unsupported scripting options on older/different SMO versions.
            $null = $_
        }

        $invalidFileNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidCharacterPattern = '[{0}]' -f [Regex]::Escape(($invalidFileNameCharacters -join ''))
        $exportedFiles = [System.Collections.Generic.List[string]]::new()

        foreach ($sequence in $userSequences) {
            $schemaName = [string]$sequence.Schema
            $sequenceName = [string]$sequence.Name
            $safeSchemaName = [Regex]::Replace($schemaName, $invalidCharacterPattern, '_')
            $safeSequenceName = [Regex]::Replace($sequenceName, $invalidCharacterPattern, '_')
            $sequenceFileName = '{0}.{1}.sql' -f $safeSchemaName, $safeSequenceName
            $sequenceFilePath = [System.IO.Path]::Combine($sequencesFolder, $sequenceFileName)

            $dataType = (& $getStringProperty -Object $sequence -PropertyName 'DataType')
            if ([string]::IsNullOrWhiteSpace($dataType)) {
                try {
                    $dataTypeObject = & $getPropertyValue -Object $sequence -PropertyName 'DataType'
                    if ($null -ne $dataTypeObject -and $null -ne $dataTypeObject.Name) {
                        $dataType = [string]$dataTypeObject.Name
                    }
                }
                catch {
                    $dataType = ''
                }
            }

            if ([string]::IsNullOrWhiteSpace($dataType)) {
                $dataType = 'bigint'
            }

            $startValue = (& $getPropertyValue -Object $sequence -PropertyName 'StartValue')
            $incrementValue = (& $getPropertyValue -Object $sequence -PropertyName 'IncrementValue')
            $minimumValue = (& $getPropertyValue -Object $sequence -PropertyName 'MinimumValue')
            $maximumValue = (& $getPropertyValue -Object $sequence -PropertyName 'MaximumValue')

            $isCycleEnabled = $false
            if ($null -ne (& $getPropertyValue -Object $sequence -PropertyName 'IsCycleEnabled')) {
                $isCycleEnabled = (& $getBooleanProperty -Object $sequence -PropertyName 'IsCycleEnabled')
            }
            elseif ($null -ne (& $getPropertyValue -Object $sequence -PropertyName 'Cycle')) {
                $isCycleEnabled = (& $getBooleanProperty -Object $sequence -PropertyName 'Cycle')
            }

            $isCached = $false
            if ($null -ne (& $getPropertyValue -Object $sequence -PropertyName 'IsCached')) {
                $isCached = (& $getBooleanProperty -Object $sequence -PropertyName 'IsCached')
            }

            $cacheSize = (& $getPropertyValue -Object $sequence -PropertyName 'CacheSize')

            $startValueText = (& $toInvariantString -Value $startValue)
            $incrementValueText = (& $toInvariantString -Value $incrementValue)
            $minimumValueText = (& $toInvariantString -Value $minimumValue)
            $maximumValueText = (& $toInvariantString -Value $maximumValue)
            $cacheSizeText = (& $toInvariantString -Value $cacheSize)

            Write-ExporterLog -Level Information -Message ("Exporting sequence: {0}.{1}" -f $schemaName, $sequenceName)

            $scriptLines = @()
            $usedManualScripting = $false

            try {
                if ($null -ne $sequence -and $null -ne $sequence.PSObject.Methods['Script']) {
                    $scriptLines = @($sequence.Script($scriptingOptions))
                }
            }
            catch {
                $usedManualScripting = $true
            }

            if (@($scriptLines).Count -eq 0) {
                $usedManualScripting = $true
            }

            if ($usedManualScripting) {
                $manualScriptLines = [System.Collections.Generic.List[string]]::new()
                $manualScriptLines.Add(('CREATE SEQUENCE {0}.{1}' -f (& $quoteIdentifier -Value $schemaName), (& $quoteIdentifier -Value $sequenceName)))
                $manualScriptLines.Add(('    AS {0}' -f $dataType))

                if (-not [string]::IsNullOrWhiteSpace($startValueText)) {
                    $manualScriptLines.Add(('    START WITH {0}' -f $startValueText))
                }

                if (-not [string]::IsNullOrWhiteSpace($incrementValueText)) {
                    $manualScriptLines.Add(('    INCREMENT BY {0}' -f $incrementValueText))
                }

                if (-not [string]::IsNullOrWhiteSpace($minimumValueText)) {
                    $manualScriptLines.Add(('    MINVALUE {0}' -f $minimumValueText))
                }

                if (-not [string]::IsNullOrWhiteSpace($maximumValueText)) {
                    $manualScriptLines.Add(('    MAXVALUE {0}' -f $maximumValueText))
                }

                if ($isCycleEnabled) {
                    $manualScriptLines.Add('    CYCLE')
                }
                else {
                    $manualScriptLines.Add('    NO CYCLE')
                }

                if ($isCached) {
                    if (-not [string]::IsNullOrWhiteSpace($cacheSizeText)) {
                        $manualScriptLines.Add(('    CACHE {0}' -f $cacheSizeText))
                    }
                    else {
                        $manualScriptLines.Add('    CACHE')
                    }
                }
                else {
                    $manualScriptLines.Add('    NO CACHE')
                }

                $manualScriptLines.Add('GO')
                $scriptLines = @($manualScriptLines)
            }

            $sequenceScript = ($scriptLines -join [Environment]::NewLine)

            $metadataLines = @(
                ("-- Sequence Name: {0}.{1}" -f $schemaName, $sequenceName),
                ("-- Data Type: {0}" -f $dataType),
                ("-- Start Value: {0}" -f $startValueText),
                ("-- Increment: {0}" -f $incrementValueText)
            )

            if (-not [string]::IsNullOrWhiteSpace($minimumValueText)) {
                $metadataLines += ("-- Minimum Value: {0}" -f $minimumValueText)
            }

            if (-not [string]::IsNullOrWhiteSpace($maximumValueText)) {
                $metadataLines += ("-- Maximum Value: {0}" -f $maximumValueText)
            }

            $metadataLines += ("-- Cycle Option: {0}" -f ($(if ($isCycleEnabled) { 'CYCLE' } else { 'NO CYCLE' })))

            if ($isCached) {
                if (-not [string]::IsNullOrWhiteSpace($cacheSizeText)) {
                    $metadataLines += ("-- Cache Option: CACHE {0}" -f $cacheSizeText)
                }
                else {
                    $metadataLines += '-- Cache Option: CACHE'
                }
            }
            else {
                $metadataLines += '-- Cache Option: NO CACHE'
            }

            $metadataHeader = ($metadataLines -join [Environment]::NewLine)
            $sequenceScript = "{0}{1}{1}{2}" -f $metadataHeader, [Environment]::NewLine, $sequenceScript

            if ($sequenceScript.Length -gt 0 -and -not $sequenceScript.EndsWith([Environment]::NewLine)) {
                $sequenceScript += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($sequenceFilePath, $sequenceScript, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($sequenceFilePath)
            Write-ExporterLog -Level Information -Message ("Sequence exported: {0}" -f $sequenceFilePath)
        }

        Write-ExporterLog -Level Information -Message 'Sequence export completed'

        return [PSCustomObject]@{
            SequenceCount = $userSequences.Count
            OutputFolder = $sequencesFolder
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Sequence export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export sequences. {0}' -f $_.Exception.Message))
    }
}

function Export-SqlDatabaseDefinition {
    <#
    .SYNOPSIS
        Exports a SQL Server database definition into a standardized structure.

    .DESCRIPTION
        This function is the current primary entry point for the script skeleton.
        It currently displays the script version, writes a startup log message,
        and exits successfully.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param()

    $version = Get-ScriptVersion
    Write-Information -MessageData ("Version: {0}" -f $version) -InformationAction Continue
    Write-ExporterLog -Level Information -Message 'Starting export'
    return $version
}
#endregion

#region Security Export Functions
function Export-Roles {
    <#
    .SYNOPSIS
        Exports user-defined database roles to Security\Roles.sql.

    .DESCRIPTION
        Creates the Security folder when needed and writes deterministic CREATE ROLE
        statements for user-defined database roles only. Fixed database roles and
        role memberships are excluded.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ($null -eq $Connection.PSObject.Properties['Connected'] -or -not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.PSObject.Properties['DatabaseObject'] -or $null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting role export'

        $securityFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Security')
        if (-not (Test-Path -LiteralPath $securityFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $securityFolder -Force | Out-Null
        }

        $rolesPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($securityFolder, 'Roles.sql'))

        $database = $Connection.DatabaseObject
        $rawRoles = @()
        if ($null -ne $database.PSObject.Properties['Roles']) {
            $rawRoles = @($database.Roles)
        }

        $fixedRoleNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($fixedRoleName in @(
            'db_owner',
            'db_datareader',
            'db_datawriter',
            'db_ddladmin',
            'db_securityadmin',
            'db_accessadmin',
            'db_backupoperator',
            'db_denydatareader',
            'db_denydatawriter',
            'public'
        )) {
            [void]$fixedRoleNames.Add($fixedRoleName)
        }

        $getRoleProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $userDefinedRoles = @(
            $rawRoles |
                Where-Object {
                    if ($null -eq $_) {
                        return $false
                    }

                    $roleName = [string](& $getRoleProperty -Object $_ -PropertyName 'Name')
                    if ([string]::IsNullOrWhiteSpace($roleName)) {
                        return $false
                    }

                    if ($fixedRoleNames.Contains($roleName)) {
                        return $false
                    }

                    $isFixedRoleProperty = $null
                    if ($null -ne $_.PSObject.Properties['IsFixedRole']) {
                        $isFixedRoleProperty = & $getRoleProperty -Object $_ -PropertyName 'IsFixedRole'
                    }

                    if ($null -ne $isFixedRoleProperty) {
                        try {
                            if ([bool]$isFixedRoleProperty) {
                                return $false
                            }
                        }
                        catch {
                        }
                    }

                    return $true
                } |
                Sort-Object -Property Name
        )

        Write-ExporterLog -Level Information -Message ("Role count: {0}" -f $userDefinedRoles.Count)
        Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $rolesPath)

        $lines = [System.Collections.Generic.List[string]]::new()

        if ($userDefinedRoles.Count -eq 0) {
            $lines.Add('-- No user-defined database roles found.')
        }
        else {
            for ($roleIndex = 0; $roleIndex -lt $userDefinedRoles.Count; $roleIndex++) {
                $role = $userDefinedRoles[$roleIndex]
                $roleName = [string](& $getRoleProperty -Object $role -PropertyName 'Name')
                $roleOwner = [string](& $getRoleProperty -Object $role -PropertyName 'Owner')

                if ([string]::IsNullOrWhiteSpace($roleOwner)) {
                    $roleOwner = ''
                }
                elseif ($null -ne $role.PSObject.Properties['Owner'] -and $null -ne $role.Owner -and $null -ne$role.Owner.PSObject.Properties['Name']) {
                    $roleOwner = [string]$role.Owner.Name
                }

                $lines.Add(('-- Role Name: {0}' -f $roleName))
                if (-not [string]::IsNullOrWhiteSpace($roleOwner)) {
                    $lines.Add(('-- Owner: {0}' -f $roleOwner))
                }

                $lines.Add('')

                $createRoleStatement = 'CREATE ROLE {0}' -f (& $escapeSqlIdentifier -Value $roleName)
                if (-not [string]::IsNullOrWhiteSpace($roleOwner)) {
                    $createRoleStatement += ' AUTHORIZATION {0}' -f (& $escapeSqlIdentifier -Value $roleOwner)
                }

                $lines.Add($createRoleStatement)
                $lines.Add('GO')

                if ($roleIndex -lt ($userDefinedRoles.Count - 1)) {
                    $lines.Add('')
                }
            }
        }

        $roleScript = [string]::Join([Environment]::NewLine, $lines)
        if (-not $roleScript.EndsWith([Environment]::NewLine)) {
            $roleScript += [Environment]::NewLine
        }

        [System.IO.File]::WriteAllText($rolesPath, $roleScript, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Role export completed'

        return [PSCustomObject]@{
            RoleCount = $userDefinedRoles.Count
            RolesPath = $rolesPath
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Role export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export roles. {0}' -f $_.Exception.Message))
    }
}

function Export-Users {
    <#
    .SYNOPSIS
        Exports database users to Security\Users.sql.

    .DESCRIPTION
        Creates the Security folder when needed and writes deterministic CREATE USER
        statements for user-defined database users only.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ($null -eq $Connection.PSObject.Properties['Connected'] -or -not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.PSObject.Properties['DatabaseObject'] -or $null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting user export'

        $securityFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Security')
        if (-not (Test-Path -LiteralPath $securityFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $securityFolder -Force | Out-Null
        }

        $usersPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($securityFolder, 'Users.sql'))

        $database = $Connection.DatabaseObject
        $rawUsers = @()
        if ($null -ne $database.PSObject.Properties['Users']) {
            $rawUsers = @($database.Users)
        }

        $excludedUserNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($excludedUserName in @('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')) {
            [void]$excludedUserNames.Add($excludedUserName)
        }

        $getUserProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $userDefinedUsers = @(
            $rawUsers |
                Where-Object {
                    if ($null -eq $_) {
                        return $false
                    }

                    $userName = [string](& $getUserProperty -Object $_ -PropertyName 'Name')
                    if ([string]::IsNullOrWhiteSpace($userName)) {
                        return $false
                    }

                    if ($excludedUserNames.Contains($userName)) {
                        return $false
                    }

                    return $true
                } |
                Sort-Object -Property Name
        )

        Write-ExporterLog -Level Information -Message ("User count: {0}" -f $userDefinedUsers.Count)
        Write-ExporterLog -Level Information -Message ("Output file: {0}" -f $usersPath)

        $lines = [System.Collections.Generic.List[string]]::new()

        if ($userDefinedUsers.Count -eq 0) {
            $lines.Add('-- No user-defined database users found.')
        }
        else {
            for ($userIndex = 0; $userIndex -lt $userDefinedUsers.Count; $userIndex++) {
                $databaseUser = $userDefinedUsers[$userIndex]

                $userName = [string](& $getUserProperty -Object $databaseUser -PropertyName 'Name')
                $loginName = [string](& $getUserProperty -Object $databaseUser -PropertyName 'Login')
                $defaultSchema = [string](& $getUserProperty -Object $databaseUser -PropertyName 'DefaultSchema')

                if ([string]::IsNullOrWhiteSpace($loginName)) {
                    $loginName = ''
                }

                if ([string]::IsNullOrWhiteSpace($defaultSchema)) {
                    $defaultSchema = ''
                }

                $lines.Add(('-- User Name: {0}' -f $userName))
                if (-not [string]::IsNullOrWhiteSpace($loginName)) {
                    $lines.Add(('-- Login: {0}' -f $loginName))
                }
                if (-not [string]::IsNullOrWhiteSpace($defaultSchema)) {
                    $lines.Add(('-- Default Schema: {0}' -f $defaultSchema))
                }

                $lines.Add('')

                $createUserStatement = 'CREATE USER {0}' -f (& $escapeSqlIdentifier -Value $userName)
                if (-not [string]::IsNullOrWhiteSpace($loginName)) {
                    $createUserStatement += ' FOR LOGIN {0}' -f (& $escapeSqlIdentifier -Value $loginName)
                }
                if (-not [string]::IsNullOrWhiteSpace($defaultSchema)) {
                    $createUserStatement += ' WITH DEFAULT_SCHEMA = {0}' -f (& $escapeSqlIdentifier -Value $defaultSchema)
                }

                $lines.Add($createUserStatement)
                $lines.Add('GO')

                if ($userIndex -lt ($userDefinedUsers.Count - 1)) {
                    $lines.Add('')
                }
            }
        }

        $userScript = [string]::Join([Environment]::NewLine, $lines)
        if (-not $userScript.EndsWith([Environment]::NewLine)) {
            $userScript += [Environment]::NewLine
        }

        [System.IO.File]::WriteAllText($usersPath, $userScript, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'User export completed'

        return [PSCustomObject]@{
            UserCount = $userDefinedUsers.Count
            UsersPath = $usersPath
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('User export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export users. {0}' -f $_.Exception.Message))
    }
}

function Export-Permissions {
    <#
    .SYNOPSIS
        Exports database permissions to Security\Permissions.sql.

    .DESCRIPTION
        Creates the Security folder when needed and writes deterministic SQL-style
        permission statements for database-level, schema-level, and object-level
        permissions from database metadata.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ($null -eq $Connection.PSObject.Properties['Connected'] -or -not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.PSObject.Properties['DatabaseObject'] -or $null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting permission export'

        $securityFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Security')
        if (-not (Test-Path -LiteralPath $securityFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $securityFolder -Force | Out-Null
        }

        $permissionsPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($securityFolder, 'Permissions.sql'))

        $databaseName = ''
        if ($null -ne $Connection.PSObject.Properties['DatabaseName'] -and -not [string]::IsNullOrWhiteSpace([string]$Connection.DatabaseName)) {
            $databaseName = [string]$Connection.DatabaseName
        }
        elseif ($null -ne $Connection.DatabaseObject.PSObject.Properties['Name'] -and -not [string]::IsNullOrWhiteSpace([string]$Connection.DatabaseObject.Name)) {
            $databaseName = [string]$Connection.DatabaseObject.Name
        }

        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            throw [System.InvalidOperationException]::new('Database name is unavailable from the connection object.')
        }

        $serverObject = $null
        if ($null -ne $Connection.PSObject.Properties['ServerObject'] -and $null -ne $Connection.ServerObject) {
            $serverObject = $Connection.ServerObject
        }
        elseif ($null -ne $Connection.DatabaseObject.PSObject.Properties['Parent']) {
            $serverObject = $Connection.DatabaseObject.Parent
        }

        if ($null -eq $serverObject) {
            throw [System.InvalidOperationException]::new('Connection does not contain a usable SQL Server object for permission queries.')
        }

        if ($null -eq $serverObject.PSObject.Properties['ConnectionContext'] -or $null -eq $serverObject.ConnectionContext) {
            throw [System.InvalidOperationException]::new('SQL Server connection context is unavailable for permission queries.')
        }

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $permissionQuery = @"
SELECT
    dp.state_desc AS PermissionState,
    dp.permission_name AS PermissionName,
    grantee.name AS GranteeName,
    dp.class_desc AS ClassDescription,
    OBJECT_SCHEMA_NAME(dp.major_id) AS ObjectSchemaName,
    OBJECT_NAME(dp.major_id) AS ObjectName,
    schemaTarget.name AS SchemaName
FROM sys.database_permissions AS dp
INNER JOIN sys.database_principals AS grantee
    ON dp.grantee_principal_id = grantee.principal_id
LEFT JOIN sys.schemas AS schemaTarget
    ON dp.class = 3
    AND dp.major_id = schemaTarget.schema_id
ORDER BY
    grantee.name,
    COALESCE(OBJECT_SCHEMA_NAME(dp.major_id), schemaTarget.name, ''),
    COALESCE(OBJECT_NAME(dp.major_id), ''),
    dp.permission_name,
    dp.state_desc;
"@

        $executeQuery = "USE {0};{1}{2}" -f (& $escapeSqlIdentifier -Value $databaseName), [Environment]::NewLine, $permissionQuery

        $queryResult = $null
        try {
            $queryResult = $serverObject.ConnectionContext.ExecuteWithResults($executeQuery)
        }
        catch {
            throw [System.InvalidOperationException]::new(("Permission query failed for database [{0}]." -f $databaseName))
        }

        $rows = @()
        if ($null -ne $queryResult -and $null -ne $queryResult.Tables -and $queryResult.Tables.Count -gt 0) {
            $rows = @($queryResult.Tables[0].Rows)
        }

        $getRowValue = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Row,

                [Parameter(Mandatory = $true)]
                [string]$ColumnName
            )

            if ($null -eq $Row -or $null -eq $Row.Table -or -not $Row.Table.Columns.Contains($ColumnName)) {
                return $null
            }

            $value = $Row[$ColumnName]
            if ($null -eq $value -or $value -is [System.DBNull]) {
                return $null
            }

            return $value
        }

        $permissionRecords = @(
            foreach ($row in $rows) {
                $permissionState = [string](& $getRowValue -Row $row -ColumnName 'PermissionState')
                $permissionName = [string](& $getRowValue -Row $row -ColumnName 'PermissionName')
                $granteeName = [string](& $getRowValue -Row $row -ColumnName 'GranteeName')
                $classDescription = [string](& $getRowValue -Row $row -ColumnName 'ClassDescription')
                $objectSchemaName = [string](& $getRowValue -Row $row -ColumnName 'ObjectSchemaName')
                $objectName = [string](& $getRowValue -Row $row -ColumnName 'ObjectName')
                $schemaName = [string](& $getRowValue -Row $row -ColumnName 'SchemaName')

                if ([string]::IsNullOrWhiteSpace($permissionName) -or [string]::IsNullOrWhiteSpace($granteeName)) {
                    continue
                }

                [PSCustomObject]@{
                    PermissionState = $permissionState
                    PermissionName = $permissionName
                    GranteeName = $granteeName
                    ClassDescription = $classDescription
                    ObjectSchemaName = $objectSchemaName
                    ObjectName = $objectName
                    SchemaName = $schemaName
                }
            }
        )

        $sortedPermissions = @(
            $permissionRecords |
                Sort-Object -Property GranteeName, ObjectSchemaName, ObjectName, PermissionName, PermissionState, ClassDescription, SchemaName
        )

        Write-ExporterLog -Level Information -Message ("Permission count: {0}" -f $sortedPermissions.Count)
        Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $permissionsPath)

        $lines = [System.Collections.Generic.List[string]]::new()

        if ($sortedPermissions.Count -eq 0) {
            $lines.Add('-- No database permissions found.')
        }
        else {
            for ($permissionIndex = 0; $permissionIndex -lt $sortedPermissions.Count; $permissionIndex++) {
                $permission = $sortedPermissions[$permissionIndex]

                $permissionStateUpper = ([string]$permission.PermissionState).Trim().ToUpperInvariant()
                $permissionName = ([string]$permission.PermissionName).Trim().ToUpperInvariant()
                $granteeName = ([string]$permission.GranteeName).Trim()
                $classDescription = ([string]$permission.ClassDescription).Trim().ToUpperInvariant()
                $objectSchemaName = ([string]$permission.ObjectSchemaName).Trim()
                $objectName = ([string]$permission.ObjectName).Trim()
                $schemaName = ([string]$permission.SchemaName).Trim()

                $permissionVerb = 'GRANT'
                $withGrantOption = $false

                switch ($permissionStateUpper) {
                    'DENY' {
                        $permissionVerb = 'DENY'
                    }
                    'GRANT_WITH_GRANT_OPTION' {
                        $permissionVerb = 'GRANT'
                        $withGrantOption = $true
                    }
                    default {
                        $permissionVerb = 'GRANT'
                    }
                }

                $objectDisplayName = ''
                if (-not [string]::IsNullOrWhiteSpace($objectSchemaName) -and -not [string]::IsNullOrWhiteSpace($objectName)) {
                    $objectDisplayName = ('{0}.{1}' -f $objectSchemaName, $objectName)
                }
                elseif (-not [string]::IsNullOrWhiteSpace($schemaName)) {
                    $objectDisplayName = $schemaName
                }
                else {
                    $objectDisplayName = 'DATABASE'
                }

                $lines.Add(('-- Permission: {0}' -f $permissionName))
                $lines.Add(('-- Grantee: {0}' -f $granteeName))
                $lines.Add(('-- Object: {0}' -f $objectDisplayName))
                $lines.Add('')

                $statementLines = [System.Collections.Generic.List[string]]::new()
                $statementLines.Add(('{0} {1}' -f $permissionVerb, $permissionName))

                if ($classDescription -eq 'OBJECT_OR_COLUMN' -and -not [string]::IsNullOrWhiteSpace($objectSchemaName) -and -not [string]::IsNullOrWhiteSpace($objectName)) {
                    $statementLines.Add(('    ON {0}.{1}' -f (& $escapeSqlIdentifier -Value $objectSchemaName), (& $escapeSqlIdentifier -Value $objectName)))
                }
                elseif ($classDescription -eq 'SCHEMA' -and -not [string]::IsNullOrWhiteSpace($schemaName)) {
                    $statementLines.Add(('    ON SCHEMA::{0}' -f (& $escapeSqlIdentifier -Value $schemaName)))
                }
                elseif ($classDescription -eq 'DATABASE') {
                    # Database-level permissions do not require an ON clause.
                }

                $statementLines.Add(('    TO {0}' -f (& $escapeSqlIdentifier -Value $granteeName)))

                if ($withGrantOption) {
                    $statementLines.Add('    WITH GRANT OPTION')
                }

                foreach ($statementLine in $statementLines) {
                    $lines.Add($statementLine)
                }

                $lines.Add('GO')

                if ($permissionIndex -lt ($sortedPermissions.Count - 1)) {
                    $lines.Add('')
                }
            }
        }

        $permissionScript = [string]::Join([Environment]::NewLine, $lines)
        if (-not $permissionScript.EndsWith([Environment]::NewLine)) {
            $permissionScript += [Environment]::NewLine
        }

        [System.IO.File]::WriteAllText($permissionsPath, $permissionScript, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Permission export completed'

        return [PSCustomObject]@{
            PermissionCount = $sortedPermissions.Count
            PermissionsPath = $permissionsPath
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Permission export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export permissions. {0}' -f $_.Exception.Message))
    }
}
#endregion

#region Reference Data Export Functions
function Export-ReferenceData {
    <#
    .SYNOPSIS
        Exports configured reference table data to one file per table.

    .DESCRIPTION
        Reads referenceData settings from the export configuration and writes
        deterministic INSERT statements for configured tables into ReferenceData.
        Export is optional and disabled by configuration.

    .PARAMETER Config
        Parsed export configuration dictionary.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER OutputFolder
        Target export folder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Config) {
            throw [System.InvalidOperationException]::new('Config cannot be null.')
        }

        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ($null -eq $Connection.PSObject.Properties['Connected'] -or -not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.PSObject.Properties['DatabaseObject'] -or $null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        if (-not $Config.Contains('referenceData')) {
            throw [System.InvalidOperationException]::new('Config is missing the referenceData section.')
        }

        $referenceDataConfig = $Config['referenceData']
        if ($null -eq $referenceDataConfig -or $referenceDataConfig -isnot [System.Collections.IDictionary]) {
            throw [System.InvalidOperationException]::new('Config referenceData section is invalid.')
        }

        Write-ExporterLog -Level Information -Message 'Starting reference data export'

        $enabled = $false
        if ($referenceDataConfig.Contains('enabled') -and $null -ne $referenceDataConfig['enabled']) {
            $enabled = [bool]$referenceDataConfig['enabled']
        }

        if (-not $enabled) {
            Write-ExporterLog -Level Information -Message 'Reference data export disabled by configuration'
            return [PSCustomObject]@{
                Enabled = $false
                TableCount = 0
                ExportedFiles = @()
            }
        }

        if (-not $referenceDataConfig.Contains('tables')) {
            throw [System.InvalidOperationException]::new('Config referenceData.tables is missing.')
        }

        $tablesValue = $referenceDataConfig['tables']
        if ($null -eq $tablesValue) {
            throw [System.InvalidOperationException]::new('Config referenceData.tables cannot be null.')
        }

        if ($tablesValue -is [string]) {
            throw [System.InvalidOperationException]::new('Config referenceData.tables must be a collection of table names.')
        }

        if ($tablesValue -is [System.Collections.IDictionary]) {
            throw [System.InvalidOperationException]::new('Config referenceData.tables must be a collection of table names, not a mapping.')
        }

        if ($tablesValue -isnot [System.Collections.IEnumerable]) {
            throw [System.InvalidOperationException]::new('Config referenceData.tables must be a collection of table names.')
        }

        $configuredTables = [System.Collections.Generic.List[string]]::new()
        $tableEntryIndex = 0
        foreach ($tableEntry in $tablesValue) {
            if ($tableEntry -isnot [string]) {
                $entryType = if ($null -eq $tableEntry) { 'null' } else { $tableEntry.GetType().FullName }
                throw [System.InvalidOperationException]::new(("Config referenceData.tables[{0}] must be a non-empty string. Found {1}." -f $tableEntryIndex, $entryType))
            }

            $tableName = $tableEntry.Trim()
            if ([string]::IsNullOrWhiteSpace($tableName)) {
                throw [System.InvalidOperationException]::new(("Config referenceData.tables[{0}] cannot be empty or whitespace." -f $tableEntryIndex))
            }

            if ($tableName.Contains('*') -or $tableName.Contains('?')) {
                throw [System.InvalidOperationException]::new(("Wildcard table selection is not supported: {0}" -f $tableName))
            }

            $configuredTables.Add($tableName)
            $tableEntryIndex++
        }

        Write-ExporterLog -Level Information -Message ("Table count requested: {0}" -f $configuredTables.Count)

        $referenceDataFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'ReferenceData')
        if (-not (Test-Path -LiteralPath $referenceDataFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $referenceDataFolder -Force | Out-Null
        }

        $databaseName = ''
        if ($null -ne $Connection.PSObject.Properties['DatabaseName'] -and -not [string]::IsNullOrWhiteSpace([string]$Connection.DatabaseName)) {
            $databaseName = [string]$Connection.DatabaseName
        }
        elseif ($null -ne $Connection.DatabaseObject.PSObject.Properties['Name'] -and -not [string]::IsNullOrWhiteSpace([string]$Connection.DatabaseObject.Name)) {
            $databaseName = [string]$Connection.DatabaseObject.Name
        }

        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            throw [System.InvalidOperationException]::new('Database name is unavailable from the connection object.')
        }

        $serverObject = $null
        if ($null -ne $Connection.PSObject.Properties['ServerObject'] -and $null -ne $Connection.ServerObject) {
            $serverObject = $Connection.ServerObject
        }
        elseif ($null -ne $Connection.DatabaseObject.PSObject.Properties['Parent']) {
            $serverObject = $Connection.DatabaseObject.Parent
        }

        if ($null -eq $serverObject) {
            throw [System.InvalidOperationException]::new('Connection does not contain a usable SQL Server object for reference data queries.')
        }

        if ($null -eq $serverObject.PSObject.Properties['ConnectionContext'] -or $null -eq $serverObject.ConnectionContext) {
            throw [System.InvalidOperationException]::new('SQL Server connection context is unavailable for reference data queries.')
        }

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $escapeSqlStringLiteral = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ("'{0}'" -f $Value.Replace("'", "''"))
        }

        $parseConfiguredTable = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            $inputText = $Value.Trim()
            if ([string]::IsNullOrWhiteSpace($inputText)) {
                throw [System.InvalidOperationException]::new('Configured table name cannot be empty.')
            }

            $schemaName = ''
            $tableName = ''

            if ($inputText -match '^\[(?<schema>(?:[^\]]|\]\])+)\]\.\[(?<table>(?:[^\]]|\]\])+)\]$') {
                $schemaName = $matches['schema'].Replace(']]', ']')
                $tableName = $matches['table'].Replace(']]', ']')
            }
            else {
                $parts = $inputText.Split('.', 2)
                if ($parts.Count -ne 2) {
                    throw [System.InvalidOperationException]::new(("Unsupported table format: {0}. Expected [schema].[table] or schema.table." -f $Value))
                }

                $schemaName = $parts[0].Trim()
                $tableName = $parts[1].Trim()

                if ($schemaName.StartsWith('[') -and $schemaName.EndsWith(']') -and $schemaName.Length -ge 2) {
                    $schemaName = $schemaName.Substring(1, $schemaName.Length - 2).Replace(']]', ']')
                }

                if ($tableName.StartsWith('[') -and $tableName.EndsWith(']') -and $tableName.Length -ge 2) {
                    $tableName = $tableName.Substring(1, $tableName.Length - 2).Replace(']]', ']')
                }
            }

            if ([string]::IsNullOrWhiteSpace($schemaName) -or [string]::IsNullOrWhiteSpace($tableName)) {
                throw [System.InvalidOperationException]::new(("Configured table must include schema and table names: {0}" -f $Value))
            }

            return [PSCustomObject]@{
                Schema = $schemaName
                Table = $tableName
                Normalized = ('{0}.{1}' -f $schemaName, $tableName)
                Bracketed = ('{0}.{1}' -f (& $escapeSqlIdentifier -Value $schemaName), (& $escapeSqlIdentifier -Value $tableName))
            }
        }

        $toSqlValue = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            if ($null -eq $Value -or $Value -is [System.DBNull]) {
                return 'NULL'
            }

            if ($Value -is [bool]) {
                return $(if ([bool]$Value) { '1' } else { '0' })
            }

            if ($Value -is [byte[]]) {
                if ($Value.Length -eq 0) {
                    return '0x'
                }

                $hex = [System.BitConverter]::ToString($Value).Replace('-', '')
                return ('0x{0}' -f $hex)
            }

            if ($Value -is [datetimeoffset]) {
                return (& $escapeSqlStringLiteral -Value $Value.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture))
            }

            if ($Value -is [datetime]) {
                return (& $escapeSqlStringLiteral -Value $Value.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', [System.Globalization.CultureInfo]::InvariantCulture))
            }

            if ($Value -is [timespan]) {
                return (& $escapeSqlStringLiteral -Value $Value.ToString())
            }

            if ($Value -is [guid]) {
                return (& $escapeSqlStringLiteral -Value $Value.ToString())
            }

            if (
                $Value -is [byte] -or
                $Value -is [sbyte] -or
                $Value -is [int16] -or
                $Value -is [uint16] -or
                $Value -is [int32] -or
                $Value -is [uint32] -or
                $Value -is [int64] -or
                $Value -is [uint64] -or
                $Value -is [single] -or
                $Value -is [double] -or
                $Value -is [decimal]
            ) {
                return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            }

            if ($Value -is [char]) {
                return (& $escapeSqlStringLiteral -Value ([string]$Value))
            }

            if ($Value -is [string]) {
                return (& $escapeSqlStringLiteral -Value $Value)
            }

            if ($Value -is [System.IFormattable]) {
                $formatted = $Value.ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
                return (& $escapeSqlStringLiteral -Value $formatted)
            }

            $fallback = [string]$Value
            return (& $escapeSqlStringLiteral -Value $fallback)
        }

        $getSafeFileName = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            $escapedInvalidChars = (($invalidChars | ForEach-Object { [Regex]::Escape([string]$_) }) -join '')
            if ([string]::IsNullOrEmpty($escapedInvalidChars)) {
                return $Value
            }

            return [Regex]::Replace($Value, ("[{0}]" -f $escapedInvalidChars), '_')
        }

        $exportedFiles = [System.Collections.Generic.List[string]]::new()
        $configuredTableCount = $configuredTables.Count

        foreach ($configuredTable in $configuredTables) {
            $parsedTable = & $parseConfiguredTable -Value $configuredTable

            Write-ExporterLog -Level Information -Message ("Exporting table: {0}" -f $parsedTable.Bracketed)

            $metadataQuery = @"
SELECT
    c.name AS ColumnName,
    c.column_id AS ColumnId,
    c.is_computed AS IsComputed,
    CASE WHEN pk.column_id IS NULL THEN 0 ELSE 1 END AS IsPrimaryKey,
    pk.key_ordinal AS PrimaryKeyOrdinal
FROM sys.columns AS c
LEFT JOIN (
    SELECT
        ic.object_id,
        ic.column_id,
        ic.key_ordinal
    FROM sys.indexes AS i
    INNER JOIN sys.index_columns AS ic
        ON i.object_id = ic.object_id
        AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) AS pk
    ON pk.object_id = c.object_id
    AND pk.column_id = c.column_id
WHERE c.object_id = OBJECT_ID(N'{0}')
ORDER BY c.column_id;
"@ -f $parsedTable.Bracketed

            $metadataExecuteQuery = "USE {0};{1}{2}" -f (& $escapeSqlIdentifier -Value $databaseName), [Environment]::NewLine, $metadataQuery
            $metadataResult = $serverObject.ConnectionContext.ExecuteWithResults($metadataExecuteQuery)

            $metadataRows = @()
            if ($null -ne $metadataResult -and $null -ne $metadataResult.Tables -and $metadataResult.Tables.Count -gt 0) {
                $metadataRows = @($metadataResult.Tables[0].Rows)
            }

            if ($metadataRows.Count -eq 0) {
                throw [System.InvalidOperationException]::new(("Configured reference table was not found: {0}" -f $parsedTable.Bracketed))
            }

            $insertableColumns = @(
                $metadataRows |
                    Where-Object { [int]$_.IsComputed -eq 0 } |
                    Sort-Object -Property ColumnId
            )

            $selectedColumnNames = @(
                $insertableColumns |
                    ForEach-Object { [string]$_.ColumnName }
            )

            $pkColumns = @(
                $insertableColumns |
                    Where-Object { [int]$_.IsPrimaryKey -eq 1 } |
                    Sort-Object -Property PrimaryKeyOrdinal, ColumnId |
                    ForEach-Object { [string]$_.ColumnName }
            )

            $orderByColumns = @()
            if ($pkColumns.Count -gt 0) {
                $orderByColumns = @($pkColumns)
            }
            elseif ($selectedColumnNames.Count -gt 0) {
                $orderByColumns = @($selectedColumnNames | Sort-Object)
            }

            $safeFileName = & $getSafeFileName -Value ('{0}.{1}.sql' -f $parsedTable.Schema, $parsedTable.Table)
            $tableOutputPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($referenceDataFolder, $safeFileName))

            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add(("-- Table: {0}" -f $parsedTable.Bracketed))

            $rowCount = 0

            if ($selectedColumnNames.Count -eq 0) {
                $lines.Add('-- No rows exported.')
                $lines.Add('-- No insertable columns found (all columns are computed).')
            }
            else {
                $selectColumnsSql = ($selectedColumnNames | ForEach-Object { & $escapeSqlIdentifier -Value $_ }) -join ', '
                $orderBySql = ''
                if ($orderByColumns.Count -gt 0) {
                    $orderBySql = (' ORDER BY {0}' -f (($orderByColumns | ForEach-Object { & $escapeSqlIdentifier -Value $_ }) -join ', '))
                }

                $dataQuery = "SELECT {0} FROM {1}{2};" -f $selectColumnsSql, $parsedTable.Bracketed, $orderBySql
                $dataExecuteQuery = "USE {0};{1}{2}" -f (& $escapeSqlIdentifier -Value $databaseName), [Environment]::NewLine, $dataQuery

                $dataResult = $serverObject.ConnectionContext.ExecuteWithResults($dataExecuteQuery)
                $dataRows = @()
                if ($null -ne $dataResult -and $null -ne $dataResult.Tables -and $dataResult.Tables.Count -gt 0) {
                    $dataRows = @($dataResult.Tables[0].Rows)
                }

                $rowCount = $dataRows.Count

                if ($rowCount -eq 0) {
                    $lines.Add('-- No rows exported.')
                }
                else {
                    $insertHeader = ("INSERT INTO {0}" -f $parsedTable.Bracketed)
                    $columnLines = $selectedColumnNames | ForEach-Object { "    {0}" -f (& $escapeSqlIdentifier -Value $_) }

                    foreach ($dataRow in $dataRows) {
                        $valueLines = @()
                        foreach ($columnName in $selectedColumnNames) {
                            $cellValue = $null
                            if ($null -ne $dataRow.Table -and $dataRow.Table.Columns.Contains($columnName)) {
                                $cellValue = $dataRow[$columnName]
                            }

                            $valueLines += ("    {0}" -f (& $toSqlValue -Value $cellValue))
                        }

                        $lines.Add($insertHeader)
                        $lines.Add('(')
                        for ($columnIndex = 0; $columnIndex -lt $columnLines.Count; $columnIndex++) {
                            if ($columnIndex -lt ($columnLines.Count - 1)) {
                                $lines.Add(($columnLines[$columnIndex] + ','))
                            }
                            else {
                                $lines.Add($columnLines[$columnIndex])
                            }
                        }
                        $lines.Add(')')
                        $lines.Add('VALUES')
                        $lines.Add('(')
                        for ($valueIndex = 0; $valueIndex -lt $valueLines.Count; $valueIndex++) {
                            if ($valueIndex -lt ($valueLines.Count - 1)) {
                                $lines.Add(($valueLines[$valueIndex] + ','))
                            }
                            else {
                                $lines.Add($valueLines[$valueIndex])
                            }
                        }
                        $lines.Add(');')
                        $lines.Add('GO')
                        $lines.Add('')
                    }

                    if ($lines.Count -gt 0 -and [string]::IsNullOrEmpty($lines[$lines.Count - 1])) {
                        [void]$lines.RemoveAt($lines.Count - 1)
                    }
                }
            }

            $fileContent = [string]::Join([Environment]::NewLine, $lines)
            if (-not $fileContent.EndsWith([Environment]::NewLine)) {
                $fileContent += [Environment]::NewLine
            }

            [System.IO.File]::WriteAllText($tableOutputPath, $fileContent, [System.Text.UTF8Encoding]::new($false))
            $exportedFiles.Add($tableOutputPath)

            Write-ExporterLog -Level Information -Message ("Row count for {0}: {1}" -f $parsedTable.Bracketed, $rowCount)
            Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $tableOutputPath)
            Write-ExporterLog -Level Information -Message ("Table exported: {0}" -f $parsedTable.Bracketed)
        }

        Write-ExporterLog -Level Information -Message 'Reference data export completed'

        return [PSCustomObject]@{
            Enabled = $true
            TableCount = $configuredTableCount
            ExportedFiles = @($exportedFiles)
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Reference data export failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export reference data. {0}' -f $_.Exception.Message))
    }
}
#endregion

#region Analysis Functions
function Export-OrphanedObjectsReport {
    <#
    .SYNOPSIS
        Exports an orphaned object analysis report to Analysis\OrphanedObjects.md.

    .DESCRIPTION
        Creates a conservative markdown report that highlights review candidates based on
        dependency metadata, security metadata, and optionally configured reference data tables.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .PARAMETER Dependencies
        Dependency records returned by Get-DatabaseDependencies.

    .PARAMETER OutputFolder
        Target export folder.

    .PARAMETER Config
        Parsed export configuration dictionary.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$Config
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        if ($null -eq $Connection.PSObject.Properties['Connected'] -or -not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.PSObject.Properties['DatabaseObject'] -or $null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting orphaned object analysis'

        $analysisFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Analysis')
        if (-not (Test-Path -LiteralPath $analysisFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $analysisFolder -Force | Out-Null
        }

        $reportPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($analysisFolder, 'OrphanedObjects.md'))
        $database = $Connection.DatabaseObject
        $dependencyArray = @($Dependencies)

        $getPropertyValue = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    return $null
                }

                return $property.Value
            }
            catch {
                return $null
            }
        }

        $getBooleanProperty = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                [string]$PropertyName
            )

            try {
                $property = $Object.PSObject.Properties[$PropertyName]
                if ($null -eq $property -or $null -eq $property.Value) {
                    return $false
                }

                return [bool]$property.Value
            }
            catch {
                return $false
            }
        }

        $buildFullName = {
            param(
                [Parameter(Mandatory = $false)]
                [string]$SchemaName,

                [Parameter(Mandatory = $false)]
                [string]$ObjectName
            )

            $schemaValue = ''
            if ($null -ne $SchemaName) {
                $schemaValue = $SchemaName.Trim()
            }

            $objectValue = ''
            if ($null -ne $ObjectName) {
                $objectValue = $ObjectName.Trim()
            }

            if (-not [string]::IsNullOrWhiteSpace($schemaValue) -and -not [string]::IsNullOrWhiteSpace($objectValue)) {
                return ('{0}.{1}' -f $schemaValue, $objectValue)
            }

            if (-not [string]::IsNullOrWhiteSpace($objectValue)) {
                return $objectValue
            }

            if (-not [string]::IsNullOrWhiteSpace($schemaValue)) {
                return $schemaValue
            }

            return ''
        }

        $getNormalizedFullName = {
            param(
                [Parameter(Mandatory = $false)]
                [string]$SchemaName,

                [Parameter(Mandatory = $false)]
                [string]$ObjectName
            )

            $fullName = & $buildFullName -SchemaName $SchemaName -ObjectName $ObjectName
            if ([string]::IsNullOrWhiteSpace($fullName)) {
                return ''
            }

            return $fullName.Trim()
        }

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $incomingDependencyNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($dependency in $dependencyArray) {
            if ($null -eq $dependency) {
                continue
            }

            $referencedSchema = [string](& $getPropertyValue -Object $dependency -PropertyName 'ReferencedSchema')
            $referencedObject = [string](& $getPropertyValue -Object $dependency -PropertyName 'ReferencedObject')
            $referencedFullName = [string](& $getPropertyValue -Object $dependency -PropertyName 'ReferencedFullName')

            if ([string]::IsNullOrWhiteSpace($referencedFullName)) {
                $referencedFullName = & $getNormalizedFullName -SchemaName $referencedSchema -ObjectName $referencedObject
            }
            else {
                $referencedFullName = $referencedFullName.Trim()
            }

            if (-not [string]::IsNullOrWhiteSpace($referencedFullName)) {
                [void]$incomingDependencyNames.Add($referencedFullName)
            }
        }

        $databaseCodeObjects = [System.Collections.Generic.List[object]]::new()

        $addDatabaseObjects = {
            param(
                [Parameter(Mandatory = $true)]
                [AllowEmptyCollection()]
                [object[]]$Objects,

                [Parameter(Mandatory = $true)]
                [string]$ObjectType,

                [Parameter(Mandatory = $true)]
                [string]$SectionName,

                [Parameter(Mandatory = $true)]
                [string]$CategoryOrder
            )

            $normalizedObjects = @($Objects)
            if ($normalizedObjects.Count -eq 0) {
                return
            }

            foreach ($object in $normalizedObjects) {
                if ($null -eq $object) {
                    continue
                }

                if (& $getBooleanProperty -Object $object -PropertyName 'IsSystemObject') {
                    continue
                }

                if (& $getBooleanProperty -Object $object -PropertyName 'IsSystem') {
                    continue
                }

                $schemaName = [string](& $getPropertyValue -Object $object -PropertyName 'Schema')
                $objectName = [string](& $getPropertyValue -Object $object -PropertyName 'Name')

                if ([string]::IsNullOrWhiteSpace($objectName)) {
                    continue
                }

                $normalizedFullName = & $getNormalizedFullName -SchemaName $schemaName -ObjectName $objectName
                if ([string]::IsNullOrWhiteSpace($normalizedFullName)) {
                    continue
                }

                $databaseCodeObjects.Add([PSCustomObject]@{
                    CategoryOrder = $CategoryOrder
                    SectionName = $SectionName
                    ObjectType = $ObjectType
                    ObjectName = $normalizedFullName
                    Reason = 'No incoming dependency references found.'
                    Note = $null
                    Scope = [string](& $getPropertyValue -Object $object -PropertyName 'Scope')
                })
            }
        }

        $triggerObjects = [System.Collections.Generic.List[object]]::new()
        foreach ($databaseTrigger in @($database.Triggers)) {
            if ($null -eq $databaseTrigger) {
                continue
            }

            $triggerObjects.Add($databaseTrigger)
        }

        $userTables = @(
            @($database.Tables) |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Schema) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                    ([string]$_.Schema -ine 'sys') -and
                    ([string]$_.Schema -ine 'INFORMATION_SCHEMA') -and
                    (-not (& $getBooleanProperty -Object $_ -PropertyName 'IsSystemObject'))
                }
        )

        foreach ($table in $userTables) {
            foreach ($tableTrigger in @($table.Triggers)) {
                if ($null -eq $tableTrigger) {
                    continue
                }

                if (& $getBooleanProperty -Object $tableTrigger -PropertyName 'IsSystemObject') {
                    continue
                }

                if (& $getBooleanProperty -Object $tableTrigger -PropertyName 'IsSystem') {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace([string]$tableTrigger.Name)) {
                    continue
                }

                $schemaName = [string](& $getPropertyValue -Object $tableTrigger -PropertyName 'Schema')
                if ([string]::IsNullOrWhiteSpace($schemaName)) {
                    $schemaName = [string]$table.Schema
                }

                $triggerObjects.Add([PSCustomObject]@{
                    Schema = $schemaName
                    Name = [string]$tableTrigger.Name
                    IsSystemObject = $false
                    IsSystem = $false
                })
            }
        }

        & $addDatabaseObjects -Objects @($database.Views) -ObjectType 'VIEW' -SectionName 'Potential Orphans' -CategoryOrder '1'
        & $addDatabaseObjects -Objects @($database.UserDefinedFunctions) -ObjectType 'FUNCTION' -SectionName 'Potential Orphans' -CategoryOrder '1'
        & $addDatabaseObjects -Objects @($database.Synonyms) -ObjectType 'SYNONYM' -SectionName 'Potential Orphans' -CategoryOrder '1'
        & $addDatabaseObjects -Objects @($triggerObjects) -ObjectType 'TRIGGER' -SectionName 'Potential Orphans' -CategoryOrder '1'
        & $addDatabaseObjects -Objects @($database.StoredProcedures) -ObjectType 'PROCEDURE' -SectionName 'External Usage Unknown' -CategoryOrder '2'

        foreach ($candidate in @($databaseCodeObjects)) {
            $candidate.ObjectName = [string]$candidate.ObjectName
            if ($candidate.ObjectType -eq 'PROCEDURE') {
                $candidate.Note = 'Stored procedures may be called by applications, SQL Agent jobs, reports, or scripts.'
            }
            elseif ($candidate.ObjectType -eq 'TRIGGER') {
                $candidate.Note = 'Trigger activity may still be driven by table events or database-level DDL.'
            }

            $candidate.Reason = [string]$candidate.Reason
        }

        $dependencyCandidates = [System.Collections.Generic.List[object]]::new()
        foreach ($candidate in @($databaseCodeObjects | Sort-Object -Property CategoryOrder, ObjectType, ObjectName)) {
            if ($null -eq $candidate) {
                continue
            }

            $incomingMatch = $incomingDependencyNames.Contains([string]$candidate.ObjectName)
            if ($incomingMatch) {
                continue
            }

            $dependencyCandidates.Add($candidate)
        }

        $dependencyPotentialOrphans = @(
            $dependencyCandidates |
                Where-Object { $_.SectionName -eq 'Potential Orphans' } |
                Sort-Object -Property ObjectType, ObjectName
        )

        $dependencyExternalUsageUnknown = @(
            $dependencyCandidates |
                Where-Object { $_.SectionName -eq 'External Usage Unknown' } |
                Sort-Object -Property ObjectType, ObjectName
        )

        $securityCandidates = [System.Collections.Generic.List[object]]::new()
        $securityAnalysisLimited = $false

        $databaseName = ''
        if ($null -ne $Connection.PSObject.Properties['DatabaseName'] -and -not [string]::IsNullOrWhiteSpace([string]$Connection.DatabaseName)) {
            $databaseName = [string]$Connection.DatabaseName
        }
        elseif ($null -ne $database.PSObject.Properties['Name'] -and -not [string]::IsNullOrWhiteSpace([string]$database.Name)) {
            $databaseName = [string]$database.Name
        }

        $serverObject = $null
        if ($null -ne $Connection.PSObject.Properties['ServerObject'] -and $null -ne $Connection.ServerObject) {
            $serverObject = $Connection.ServerObject
        }
        elseif ($null -ne $database.PSObject.Properties['Parent']) {
            $serverObject = $database.Parent
        }

        $connectionContext = $null
        if ($null -ne $serverObject -and $null -ne $serverObject.PSObject.Properties['ConnectionContext']) {
            $connectionContext = $serverObject.ConnectionContext
        }

        $getRowValue = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Row,

                [Parameter(Mandatory = $true)]
                [string]$ColumnName
            )

            if ($null -eq $Row -or $null -eq $Row.Table -or -not $Row.Table.Columns.Contains($ColumnName)) {
                return $null
            }

            $value = $Row[$ColumnName]
            if ($null -eq $value -or $value -is [System.DBNull]) {
                return $null
            }

            return $value
        }

        $executeQuery = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$QueryText
            )

            if ($null -eq $connectionContext -or [string]::IsNullOrWhiteSpace($databaseName)) {
                return $null
            }

            $sql = "USE {0};{1}{2}" -f (& $escapeSqlIdentifier -Value $databaseName), [Environment]::NewLine, $QueryText
            try {
                return $connectionContext.ExecuteWithResults($sql)
            }
            catch {
                return $null
            }
        }

        if ($null -ne $connectionContext -and -not [string]::IsNullOrWhiteSpace($databaseName)) {
            $securityRoleQuery = @"
SELECT
    rp.name AS PrincipalName,
    COALESCE(memberCounts.MemberCount, 0) AS MemberCount,
    COALESCE(permissionCounts.PermissionCount, 0) AS PermissionCount
FROM sys.database_principals AS rp
LEFT JOIN (
    SELECT role_principal_id, COUNT(1) AS MemberCount
    FROM sys.database_role_members
    GROUP BY role_principal_id
) AS memberCounts
    ON memberCounts.role_principal_id = rp.principal_id
LEFT JOIN (
    SELECT grantee_principal_id, COUNT(1) AS PermissionCount
    FROM sys.database_permissions
    GROUP BY grantee_principal_id
) AS permissionCounts
    ON permissionCounts.grantee_principal_id = rp.principal_id
WHERE rp.type = 'R'
    AND rp.is_fixed_role = 0
    AND rp.name <> 'public'
ORDER BY rp.name;
"@

            $securityUserQuery = @"
SELECT
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    COALESCE(roleMembershipCounts.RoleMembershipCount, 0) AS RoleMembershipCount,
    COALESCE(permissionCounts.PermissionCount, 0) AS PermissionCount
FROM sys.database_principals AS dp
LEFT JOIN (
    SELECT member_principal_id, COUNT(1) AS RoleMembershipCount
    FROM sys.database_role_members
    GROUP BY member_principal_id
) AS roleMembershipCounts
    ON roleMembershipCounts.member_principal_id = dp.principal_id
LEFT JOIN (
    SELECT grantee_principal_id, COUNT(1) AS PermissionCount
    FROM sys.database_permissions
    GROUP BY grantee_principal_id
) AS permissionCounts
    ON permissionCounts.grantee_principal_id = dp.principal_id
WHERE dp.principal_id > 4
    AND dp.type IN ('S', 'U', 'G', 'E', 'X', 'C')
    AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
ORDER BY dp.name;
"@

            $securityRoleResult = & $executeQuery -QueryText $securityRoleQuery
            $securityUserResult = & $executeQuery -QueryText $securityUserQuery

            if ($null -eq $securityRoleResult -or $null -eq $securityUserResult) {
                $securityAnalysisLimited = $true
            }

            if ($null -ne $securityRoleResult -and $null -ne $securityRoleResult.Tables -and $securityRoleResult.Tables.Count -gt 0) {
                foreach ($row in @($securityRoleResult.Tables[0].Rows)) {
                    $principalName = [string](& $getRowValue -Row $row -ColumnName 'PrincipalName')
                    if ([string]::IsNullOrWhiteSpace($principalName)) {
                        continue
                    }

                    $memberCount = 0
                    try {
                        $memberCount = [int](& $getRowValue -Row $row -ColumnName 'MemberCount')
                    }
                    catch {
                        $memberCount = 0
                    }

                    $permissionCount = 0
                    try {
                        $permissionCount = [int](& $getRowValue -Row $row -ColumnName 'PermissionCount')
                    }
                    catch {
                        $permissionCount = 0
                    }

                    if ($memberCount -eq 0 -and $permissionCount -eq 0) {
                        $securityCandidates.Add([PSCustomObject]@{
                            SectionName = 'Roles'
                            CategoryOrder = '1'
                            ObjectType = 'ROLE'
                            ObjectName = $principalName.Trim()
                            Reason = 'No members and no obvious permissions were found.'
                            Note = $null
                        })
                    }
                }
            }
            else {
                $securityAnalysisLimited = $true
            }

            if ($null -ne $securityUserResult -and $null -ne $securityUserResult.Tables -and $securityUserResult.Tables.Count -gt 0) {
                foreach ($row in @($securityUserResult.Tables[0].Rows)) {
                    $principalName = [string](& $getRowValue -Row $row -ColumnName 'PrincipalName')
                    if ([string]::IsNullOrWhiteSpace($principalName)) {
                        continue
                    }

                    $roleMembershipCount = 0
                    try {
                        $roleMembershipCount = [int](& $getRowValue -Row $row -ColumnName 'RoleMembershipCount')
                    }
                    catch {
                        $roleMembershipCount = 0
                    }

                    $permissionCount = 0
                    try {
                        $permissionCount = [int](& $getRowValue -Row $row -ColumnName 'PermissionCount')
                    }
                    catch {
                        $permissionCount = 0
                    }

                    if ($roleMembershipCount -eq 0 -and $permissionCount -eq 0) {
                        $securityCandidates.Add([PSCustomObject]@{
                            SectionName = 'Users'
                            CategoryOrder = '2'
                            ObjectType = 'USER'
                            ObjectName = $principalName.Trim()
                            Reason = 'No role memberships and no obvious direct permissions were found.'
                            Note = $null
                        })
                    }
                }
            }
            else {
                $securityAnalysisLimited = $true
            }
        }
        else {
            $securityAnalysisLimited = $true
        }

        $securityRoles = @(
            $securityCandidates |
                Where-Object { $_.SectionName -eq 'Roles' } |
                Sort-Object -Property ObjectType, ObjectName
        )

        $securityUsers = @(
            $securityCandidates |
                Where-Object { $_.SectionName -eq 'Users' } |
                Sort-Object -Property ObjectType, ObjectName
        )

        $referenceDataCandidates = [System.Collections.Generic.List[object]]::new()
        $referenceDataAnalysisPerformed = $false
        $referenceDataAnalysisLimited = $false

        if ($null -ne $Config -and $Config.Contains('referenceData')) {
            $referenceDataConfig = $Config['referenceData']
            if ($null -ne $referenceDataConfig -and $referenceDataConfig -is [System.Collections.IDictionary]) {
                $referenceDataEnabled = $false
                if ($referenceDataConfig.Contains('enabled') -and $null -ne $referenceDataConfig['enabled']) {
                    $referenceDataEnabled = [bool]$referenceDataConfig['enabled']
                }

                if ($referenceDataEnabled -and $referenceDataConfig.Contains('tables')) {
                    $referenceDataAnalysisPerformed = $true
                    $tablesValue = $referenceDataConfig['tables']
                    if ($null -ne $tablesValue -and $tablesValue -isnot [string] -and $tablesValue -isnot [System.Collections.IDictionary] -and $tablesValue -is [System.Collections.IEnumerable]) {
                        $configuredTables = [System.Collections.Generic.List[string]]::new()
                        foreach ($tableEntry in $tablesValue) {
                            if ($tableEntry -isnot [string]) {
                                $referenceDataAnalysisLimited = $true
                                continue
                            }

                            $tableName = $tableEntry.Trim()
                            if ([string]::IsNullOrWhiteSpace($tableName)) {
                                $referenceDataAnalysisLimited = $true
                                continue
                            }

                            if ($tableName.Contains('*') -or $tableName.Contains('?')) {
                                $referenceDataAnalysisLimited = $true
                                continue
                            }

                            $configuredTables.Add($tableName)
                        }
                        if ($configuredTables.Count -gt 0) {
                            $parseConfiguredTable = {
                                param(
                                    [Parameter(Mandatory = $true)]
                                    [string]$Value
                                )

                                $inputText = $Value.Trim()
                                if ([string]::IsNullOrWhiteSpace($inputText)) {
                                    throw [System.InvalidOperationException]::new('Configured table name cannot be empty.')
                                }

                                $schemaName = ''
                                $tableName = ''

                                if ($inputText -match '^\[(?<schema>(?:[^\]]|\]\])+)
\]\.\[(?<table>(?:[^\]]|\]\])+)
\]$') {
                                    $schemaName = $matches['schema'].Replace(']]', ']')
                                    $tableName = $matches['table'].Replace(']]', ']')
                                }
                                else {
                                    $parts = $inputText.Split('.', 2)
                                    if ($parts.Count -ne 2) {
                                        throw [System.InvalidOperationException]::new(("Unsupported table format: {0}. Expected [schema].[table] or schema.table." -f $Value))
                                    }

                                    $schemaName = $parts[0].Trim()
                                    $tableName = $parts[1].Trim()

                                    if ($schemaName.StartsWith('[') -and $schemaName.EndsWith(']') -and $schemaName.Length -ge 2) {
                                        $schemaName = $schemaName.Substring(1, $schemaName.Length - 2).Replace(']]', ']')
                                    }

                                    if ($tableName.StartsWith('[') -and $tableName.EndsWith(']') -and $tableName.Length -ge 2) {
                                        $tableName = $tableName.Substring(1, $tableName.Length - 2).Replace(']]', ']')
                                    }
                                }

                                if ([string]::IsNullOrWhiteSpace($schemaName) -or [string]::IsNullOrWhiteSpace($tableName)) {
                                    throw [System.InvalidOperationException]::new(("Configured table must include schema and table names: {0}" -f $Value))
                                }

                                return [PSCustomObject]@{
                                    Schema = $schemaName
                                    Table = $tableName
                                    Normalized = ('{0}.{1}' -f $schemaName, $tableName)
                                    Bracketed = ('{0}.{1}' -f (& $escapeSqlIdentifier -Value $schemaName), (& $escapeSqlIdentifier -Value $tableName))
                                }
                            }

                            foreach ($configuredTable in $configuredTables) {
                                try {
                                    $parsedTable = & $parseConfiguredTable -Value $configuredTable
                                }
                                catch {
                                    $referenceDataAnalysisLimited = $true
                                    continue
                                }

                                $rowCount = $null
                                if ($null -ne $connectionContext -and -not [string]::IsNullOrWhiteSpace($databaseName)) {
                                    $countQuery = @"
SELECT COUNT_BIG(1) AS RowCount
FROM {0};
"@ -f $parsedTable.Bracketed
                                    $countResult = & $executeQuery -QueryText $countQuery
                                    if ($null -ne $countResult -and $null -ne $countResult.Tables -and $countResult.Tables.Count -gt 0) {
                                        $countRow = $countResult.Tables[0].Rows | Select-Object -First 1
                                        if ($null -ne $countRow) {
                                            try {
                                                $rowCount = [long](& $getRowValue -Row $countRow -ColumnName 'RowCount')
                                            }
                                            catch {
                                                $rowCount = $null
                                            }
                                        }
                                    }
                                    else {
                                        $referenceDataAnalysisLimited = $true
                                    }
                                }
                                else {
                                    $referenceDataAnalysisLimited = $true
                                }

                                if ($null -eq $rowCount) {
                                    continue
                                }

                                if ($rowCount -eq 0) {
                                    $referenceDataCandidates.Add([PSCustomObject]@{
                                        SectionName = 'Configured Tables'
                                        CategoryOrder = '1'
                                        ObjectType = 'TABLE'
                                        ObjectName = $parsedTable.Normalized
                                        Reason = 'Configured table contains zero rows.'
                                        Note = $null
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }

        $referenceDataEmptyTables = @(
            $referenceDataCandidates |
                Sort-Object -Property ObjectType, ObjectName
        )

        $dependencyCandidateCount = @($dependencyCandidates).Count
        $securityCandidateCount = @($securityCandidates).Count
        $referenceDataCandidateCount = @($referenceDataEmptyTables).Count

        Write-ExporterLog -Level Information -Message (("Dependency candidate count: {0}" -f $dependencyCandidateCount))
        Write-ExporterLog -Level Information -Message (("Security candidate count: {0}" -f $securityCandidateCount))
        Write-ExporterLog -Level Information -Message (("Reference data candidate count: {0}" -f $referenceDataCandidateCount))
        Write-ExporterLog -Level Information -Message (("Output path: {0}" -f $reportPath))

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# Orphaned Object Analysis')
        $lines.Add('')
        $lines.Add('## Summary')
        $lines.Add('')
        $lines.Add(("- Dependency-Based Candidates: {0}" -f $dependencyCandidateCount))
        $lines.Add(("- Security Candidates: {0}" -f $securityCandidateCount))
        $lines.Add(("- Reference Data Candidates: {0}" -f $referenceDataCandidateCount))
        $lines.Add('')
        $lines.Add('## Important Review Note')
        $lines.Add('')
        $lines.Add('This report identifies review candidates only.')
        $lines.Add('This report does not prove that an object is unused.')
        $lines.Add('Objects may be referenced by applications, SQL Agent jobs, reports, scripts, SSIS packages, or other external systems.')
        $lines.Add('Manual validation required before removal.')
        $lines.Add('')

        $lines.Add('## Dependency-Based Candidates')
        $lines.Add('')
        $lines.Add('### Potential Orphans')
        $lines.Add('')
        if ($dependencyPotentialOrphans.Count -eq 0) {
            $lines.Add('None found.')
            $lines.Add('')
        }
        else {
            foreach ($candidate in $dependencyPotentialOrphans) {
                $lines.Add(("- {0}" -f $candidate.ObjectName))
                $lines.Add(("  - Type: {0}" -f $candidate.ObjectType))
                $lines.Add(("  - Reason: {0}" -f $candidate.Reason))
                if (-not [string]::IsNullOrWhiteSpace([string]$candidate.Note)) {
                    $lines.Add(("  - Note: {0}" -f $candidate.Note))
                }
                $lines.Add('')
            }
        }

        $lines.Add('### External Usage Unknown')
        $lines.Add('')
        if ($dependencyExternalUsageUnknown.Count -eq 0) {
            $lines.Add('None found.')
            $lines.Add('')
        }
        else {
            foreach ($candidate in $dependencyExternalUsageUnknown) {
                $lines.Add(("- {0}" -f $candidate.ObjectName))
                $lines.Add(("  - Type: {0}" -f $candidate.ObjectType))
                $lines.Add(("  - Reason: {0}" -f $candidate.Reason))
                $lines.Add(("  - Note: {0}" -f $candidate.Note))
                $lines.Add('')
            }
        }

        $lines.Add('## Security Candidates')
        $lines.Add('')
        $lines.Add('Security usage may require manual review.')
        if ($securityAnalysisLimited) {
            $lines.Add('Security analysis is limited to metadata available in the current database.')
        }
        $lines.Add('')

        $lines.Add('### Roles')
        $lines.Add('')
        if ($securityRoles.Count -eq 0) {
            $lines.Add('None found.')
            $lines.Add('')
        }
        else {
            foreach ($candidate in $securityRoles) {
                $lines.Add(("- {0}" -f $candidate.ObjectName))
                $lines.Add(("  - Type: {0}" -f $candidate.ObjectType))
                $lines.Add(("  - Reason: {0}" -f $candidate.Reason))
                $lines.Add('')
            }
        }

        $lines.Add('### Users')
        $lines.Add('')
        if ($securityUsers.Count -eq 0) {
            $lines.Add('None found.')
            $lines.Add('')
        }
        else {
            foreach ($candidate in $securityUsers) {
                $lines.Add(("- {0}" -f $candidate.ObjectName))
                $lines.Add(("  - Type: {0}" -f $candidate.ObjectType))
                $lines.Add(("  - Reason: {0}" -f $candidate.Reason))
                $lines.Add('')
            }
        }

        $lines.Add('## Reference Data Candidates')
        $lines.Add('')
        if ($referenceDataAnalysisPerformed) {
            if ($referenceDataAnalysisLimited) {
                $lines.Add('Reference data analysis is limited to configured tables available in the current database.')
                $lines.Add('')
            }

            if ($referenceDataEmptyTables.Count -eq 0) {
                $lines.Add('None found.')
                $lines.Add('')
            }
            else {
                foreach ($candidate in $referenceDataEmptyTables) {
                    $lines.Add(("- {0}" -f $candidate.ObjectName))
                    $lines.Add(("  - Type: {0}" -f $candidate.ObjectType))
                    $lines.Add(("  - Reason: {0}" -f $candidate.Reason))
                    $lines.Add('')
                }
            }
        }
        else {
            $lines.Add('Reference data analysis was not performed.')
            $lines.Add('')
        }

        $lines.Add('## Recommended Review Actions')
        $lines.Add('')
        $lines.Add('- Verify usage through application code.')
        $lines.Add('- Review SQL Agent jobs.')
        $lines.Add('- Review reporting tools.')
        $lines.Add('- Review deployment scripts.')
        $lines.Add('- Confirm with business or application owners before removal.')

        if ($dependencyCandidateCount -eq 0 -and $securityCandidateCount -eq 0 -and $referenceDataCandidateCount -eq 0) {
            $lines.Add('')
            $lines.Add('No candidates were found.')
        }

        $reportContent = [string]::Join([Environment]::NewLine, $lines)
        if (-not $reportContent.EndsWith([Environment]::NewLine)) {
            $reportContent += [Environment]::NewLine
        }

        [System.IO.File]::WriteAllText($reportPath, $reportContent, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Analysis completed'

        return [PSCustomObject]@{
            DependencyCandidateCount = $dependencyCandidateCount
            SecurityCandidateCount = $securityCandidateCount
            ReferenceDataCandidateCount = $referenceDataCandidateCount
            ReportPath = $reportPath
        }
    }
    catch {
        Write-ExporterLog -Level Error -Message ('Orphaned object analysis failed: {0}' -f $_.Exception.Message) -ErrorAction Continue
        throw [System.InvalidOperationException]::new(('Failed to export orphaned objects report. {0}' -f $_.Exception.Message))
    }
}
#endregion

#region Dependency Functions
function Get-GraphvizDotPath {
    <#
    .SYNOPSIS
        Resolves the Graphviz dot executable path.

    .DESCRIPTION
        Looks for dot on PATH first, then checks common Graphviz installation
        locations on Windows. Returns the full path when found; otherwise returns $null.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    param()

    $dotCommand = Get-Command -Name 'dot' -ErrorAction SilentlyContinue
    if ($null -ne $dotCommand) {
        $dotPath = $dotCommand.Source
        if ([string]::IsNullOrWhiteSpace($dotPath)) {
            $dotPath = $dotCommand.Path
        }

        if (-not [string]::IsNullOrWhiteSpace($dotPath)) {
            $resolvedDotPath = [System.IO.Path]::GetFullPath($dotPath)
            Write-ExporterLog -Level Information -Message ("Graphviz found via PATH: {0}" -f $resolvedDotPath)
            return $resolvedDotPath
        }
    }

    $commonDotPaths = @(
        'C:\Program Files\Graphviz\bin\dot.exe',
        'C:\Program Files (x86)\Graphviz\bin\dot.exe'
    )

    foreach ($commonDotPath in $commonDotPaths) {
        if (Test-Path -LiteralPath $commonDotPath -PathType Leaf) {
            $resolvedDotPath = [System.IO.Path]::GetFullPath($commonDotPath)
            Write-ExporterLog -Level Information -Message ("Graphviz found via fallback path: {0}" -f $resolvedDotPath)
            return $resolvedDotPath
        }
    }

    Write-ExporterLog -Level Information -Message 'Graphviz not found'
    return $null
}

function Test-ExportDependencies {
    <#
    .SYNOPSIS
        Validates runtime dependencies required by the exporter.

    .DESCRIPTION
        Checks the local PowerShell environment before any export processing begins.
        The function evaluates required and optional dependencies, logs the results,
        and returns a structured object describing what is installed and what is missing.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param()

    $dependencies = @(
        [PSCustomObject]@{
            Name = 'PowerShell'
            Required = $true
            InstallCommand = 'Upgrade PowerShell to version 7.6 or later'
            Notes = 'Validate PowerShell version 7.6+'
            Validation = 'PSVersionTable.PSVersion'
        },
        [PSCustomObject]@{
            Name = 'powershell-yaml'
            Required = $true
            InstallCommand = 'Install-Module powershell-yaml -Scope CurrentUser'
            Notes = 'ConvertFrom-Yaml available'
            Validation = 'ConvertFrom-Yaml'
        },
        [PSCustomObject]@{
            Name = 'SqlServer'
            Required = $false
            InstallCommand = 'Install-Module SqlServer -Scope CurrentUser'
            Notes = 'Optional for current milestone; required before Connect-SqlDatabase can succeed. Validate with: Get-Module SqlServer -ListAvailable'
            Validation = 'SqlServer module availability for future SQL connectivity'
        },
        [PSCustomObject]@{
            Name = 'Graphviz'
            Required = $false
            InstallCommand = 'winget install Graphviz.Graphviz'
            Notes = 'Get-GraphvizDotPath'
            Validation = 'dot.exe'
        }
    )

    $installedDependencies = [System.Collections.Generic.List[string]]::new()
    $missingDependencies = [System.Collections.Generic.List[string]]::new()
    $installCommands = [System.Collections.Generic.List[string]]::new()
    $dependencyDetails = [System.Collections.Generic.List[object]]::new()

    Write-ExporterLog -Level Information -Message 'Dependency Check Started'

    foreach ($dependency in $dependencies) {
        $isInstalled = $false
        $detail = [PSCustomObject]@{
            Name = $dependency.Name
            Required = $dependency.Required
            InstallCommand = $dependency.InstallCommand
            Notes = $dependency.Notes
            Validation = $dependency.Validation
            Installed = $false
            Message = ''
        }

        switch ($dependency.Name) {
            'PowerShell' {
                $minimumPowerShellVersion = [Version]'7.6'
                $currentPowerShellVersion = $PSVersionTable.PSVersion
                $isInstalled = $currentPowerShellVersion -ge $minimumPowerShellVersion
                if ($isInstalled) {
                    $detail.Installed = $true
                    $detail.Message = ("PASS: {0}" -f $dependency.Name)
                    $installedDependencies.Add(("PowerShell {0}" -f $currentPowerShellVersion.ToString()))
                    Write-ExporterLog -Level Information -Message ("PASS: {0}" -f $dependency.Name)
                }
                else {
                    $detail.Message = ("ERROR: {0} not installed. {1}" -f $dependency.Name, $dependency.InstallCommand)
                    $missingDependencies.Add($dependency.Name)
                    $installCommands.Add($dependency.InstallCommand)
                    Write-ExporterLog -Level Error -Message ("ERROR: {0} not installed. {1}" -f $dependency.Name, $dependency.InstallCommand)
                    Write-ExporterLog -Level Information -Message ("Install: {0}" -f $dependency.InstallCommand)
                }
            }
            'powershell-yaml' {
                $yamlCommand = Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue
                if ($null -eq $yamlCommand) {
                    Import-Module powershell-yaml -ErrorAction SilentlyContinue
                    $yamlCommand = Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue
                }

                if ($null -ne $yamlCommand) {
                    $isInstalled = $true
                    $detail.Installed = $true
                    $detail.Message = 'PASS: powershell-yaml'
                    $installedDependencies.Add('ConvertFrom-Yaml')
                    Write-ExporterLog -Level Information -Message 'PASS: powershell-yaml'
                }
                else {
                    $detail.Message = ("ERROR: powershell-yaml not installed. {0}" -f $dependency.InstallCommand)
                    $missingDependencies.Add($dependency.Name)
                    $installCommands.Add($dependency.InstallCommand)
                    Write-ExporterLog -Level Error -Message ("ERROR: powershell-yaml not installed. {0}" -f $dependency.InstallCommand)
                    Write-ExporterLog -Level Information -Message ("Install: {0}" -f $dependency.InstallCommand)
                }
            }
            'SqlServer' {
                $sqlServerModule = Get-Module -ListAvailable -Name 'SqlServer' | Select-Object -First 1
                if ($null -ne $sqlServerModule) {
                    $isInstalled = $true
                    $detail.Installed = $true
                    $detail.Message = 'PASS: SqlServer (ready for upcoming Connect-SqlDatabase milestone)'
                    $installedDependencies.Add('SqlServer')
                    Write-ExporterLog -Level Information -Message 'PASS: SqlServer (ready for upcoming Connect-SqlDatabase milestone)'
                }
                else {
                    $detail.Message = 'INFO: SqlServer not installed (optional today; required before Connect-SqlDatabase can succeed). Install-Module SqlServer -Scope CurrentUser'
                    $missingDependencies.Add($dependency.Name)
                    $installCommands.Add($dependency.InstallCommand)
                    Write-ExporterLog -Level Information -Message 'INFO: SqlServer not installed (optional today; required before Connect-SqlDatabase can succeed)'
                    Write-ExporterLog -Level Information -Message ("Install: {0}" -f $dependency.InstallCommand)
                }
            }
            'Graphviz' {
                $graphvizDotPath = Get-GraphvizDotPath
                if ($null -ne $graphvizDotPath) {
                    $isInstalled = $true
                    $detail.Installed = $true
                    $detail.Message = 'PASS: Graphviz'
                    $installedDependencies.Add('Graphviz')
                    Write-ExporterLog -Level Information -Message 'PASS: Graphviz'
                }
                else {
                    $detail.Message = 'INFO: Graphviz not installed (optional)'
                    $missingDependencies.Add($dependency.Name)
                    $installCommands.Add($dependency.InstallCommand)
                    Write-ExporterLog -Level Information -Message 'INFO: Graphviz not installed (optional)'
                    Write-ExporterLog -Level Information -Message ("Install: {0}" -f $dependency.InstallCommand)
                }
            }
        }

        if ($dependency.Required -and -not $isInstalled) {
            $missingDependencies.Add(("{0}" -f $dependency.Name))
        }

        $dependencyDetails.Add($detail)
    }

    Write-ExporterLog -Level Information -Message 'Dependency Check Complete'

    $missingRequiredDependencies = @(
        $dependencyDetails | Where-Object {
            $_.Required -eq $true -and $_.Installed -ne $true
        }
    )

    $isValid = ($missingRequiredDependencies.Count -eq 0)

    return [PSCustomObject]@{
        IsValid = $isValid
        InstalledDependencies = @($installedDependencies)
        MissingDependencies = @($missingDependencies)
        InstallCommands = @($installCommands)
        DependencyDetails = @($dependencyDetails)
    }
}

function Get-DatabaseDependencies {
    <#
    .SYNOPSIS
        Retrieves SQL object dependency metadata for the connected database.

    .DESCRIPTION
        Queries sys.sql_expression_dependencies and related catalog views to produce
        standardized dependency records for in-memory processing.

    .PARAMETER Connection
        Connection result returned by Connect-SqlDatabase.

    .OUTPUTS
        System.Object[]
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection
    )

    try {
        if ($null -eq $Connection) {
            throw [System.InvalidOperationException]::new('Connection cannot be null.')
        }

        $requiredConnectionProperties = @('Connected', 'DatabaseObject', 'DatabaseName', 'ServerName')
        foreach ($propertyName in $requiredConnectionProperties) {
            if ($null -eq $Connection.PSObject.Properties[$propertyName]) {
                throw [System.InvalidOperationException]::new(("Connection is missing required property: {0}" -f $propertyName))
            }
        }

        if (-not [bool]$Connection.Connected) {
            throw [System.InvalidOperationException]::new('Connection.Connected must be true.')
        }

        if ($null -eq $Connection.DatabaseObject) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseObject cannot be null.')
        }

        $databaseName = [string]$Connection.DatabaseName
        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            throw [System.InvalidOperationException]::new('Connection.DatabaseName cannot be null, empty, or whitespace.')
        }

        $serverName = [string]$Connection.ServerName
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            throw [System.InvalidOperationException]::new('Connection.ServerName cannot be null, empty, or whitespace.')
        }

        $serverObject = $null
        if ($null -ne $Connection.PSObject.Properties['ServerObject'] -and $null -ne $Connection.ServerObject) {
            $serverObject = $Connection.ServerObject
        }
        elseif ($null -ne $Connection.DatabaseObject.PSObject.Properties['Parent']) {
            $serverObject = $Connection.DatabaseObject.Parent
        }

        if ($null -eq $serverObject) {
            throw [System.InvalidOperationException]::new('Connection does not contain a usable SQL Server object for dependency queries.')
        }

        if ($null -eq $serverObject.PSObject.Properties['ConnectionContext'] -or $null -eq $serverObject.ConnectionContext) {
            throw [System.InvalidOperationException]::new('SQL Server connection context is unavailable for dependency queries.')
        }

        Write-ExporterLog -Level Information -Message 'Starting dependency query'
        Write-ExporterLog -Level Information -Message ("Database name: {0}" -f $databaseName)

        $dependencyQuery = @"
SELECT
    d.referencing_id AS ReferencingId,
    d.referenced_id AS ReferencedId,
    d.referencing_class AS ReferencingClass,
    d.referenced_class AS ReferencedClass,
    rs.name AS ReferencingSchema,
    ro.name AS ReferencingObject,
    ro.type_desc AS ReferencingObjectTypeRaw,
    d.referenced_server_name AS ReferencedServer,
    d.referenced_database_name AS ReferencedDatabase,
    d.referenced_schema_name AS ReferencedSchema,
    d.referenced_entity_name AS ReferencedObject,
    rso.type_desc AS ReferencedObjectTypeRaw,
    rss.name AS ReferencedLocalSchema,
    rso.name AS ReferencedLocalObject,
    d.is_schema_bound_reference AS IsSchemaBound,
    d.is_caller_dependent AS IsCallerDependent,
    d.is_ambiguous AS IsAmbiguous
FROM sys.sql_expression_dependencies AS d
INNER JOIN sys.objects AS ro
    ON d.referencing_id = ro.object_id
INNER JOIN sys.schemas AS rs
    ON ro.schema_id = rs.schema_id
LEFT JOIN sys.objects AS rso
    ON d.referenced_id = rso.object_id
LEFT JOIN sys.schemas AS rss
    ON rso.schema_id = rss.schema_id
ORDER BY
    rs.name,
    ro.name,
    d.referenced_database_name,
    d.referenced_schema_name,
    d.referenced_entity_name;
"@

        $escapeSqlIdentifier = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            return ('[{0}]' -f $Value.Replace(']', ']]'))
        }

        $executeQuery = "USE {0};{1}{2}" -f (& $escapeSqlIdentifier -Value $databaseName), [Environment]::NewLine, $dependencyQuery

        $queryResult = $null
        try {
            $queryResult = $serverObject.ConnectionContext.ExecuteWithResults($executeQuery)
        }
        catch {
            throw [System.InvalidOperationException]::new(("Dependency query failed for database [{0}] on server [{1}]." -f $databaseName, $serverName))
        }

        $rows = @()
        if ($null -ne $queryResult -and $null -ne $queryResult.Tables -and $queryResult.Tables.Count -gt 0) {
            $rows = @($queryResult.Tables[0].Rows)
        }

        $getRowValue = {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Row,

                [Parameter(Mandatory = $true)]
                [string]$ColumnName
            )

            if ($null -eq $Row -or $null -eq $Row.Table -or -not $Row.Table.Columns.Contains($ColumnName)) {
                return $null
            }

            $value = $Row[$ColumnName]
            if ($null -eq $value -or $value -is [System.DBNull]) {
                return $null
            }

            return $value
        }

        $toStringOrEmpty = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            if ($null -eq $Value) {
                return ''
            }

            return [string]$Value
        }

        $toNullableInt = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            if ($null -eq $Value) {
                return $null
            }

            try {
                return [int]$Value
            }
            catch {
                return $null
            }
        }

        $toBoolean = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            if ($null -eq $Value) {
                return $false
            }

            try {
                return [bool]$Value
            }
            catch {
                return $false
            }
        }

        $normalizeObjectType = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$TypeValue
            )

            $rawType = (& $toStringOrEmpty -Value $TypeValue)
            if ([string]::IsNullOrWhiteSpace($rawType)) {
                return 'UNKNOWN'
            }

            $rawTypeUpper = $rawType.ToUpperInvariant()

            if ($rawTypeUpper -match 'SEQUENCE') {
                return 'SEQUENCE'
            }

            if ($rawTypeUpper -match 'SYNONYM') {
                return 'SYNONYM'
            }

            if ($rawTypeUpper -match 'TRIGGER') {
                return 'TRIGGER'
            }

            if ($rawTypeUpper -match 'FUNCTION') {
                return 'FUNCTION'
            }

            if ($rawTypeUpper -match 'PROCEDURE') {
                return 'PROCEDURE'
            }

            if ($rawTypeUpper -match 'VIEW') {
                return 'VIEW'
            }

            if ($rawTypeUpper -match 'TABLE') {
                return 'TABLE'
            }

            return 'UNKNOWN'
        }

        $buildFullName = {
            param(
                [Parameter(Mandatory = $false)]
                [string]$SchemaName,

                [Parameter(Mandatory = $false)]
                [string]$ObjectName
            )

            $schemaValue = ''
            if ($null -ne $SchemaName) {
                $schemaValue = $SchemaName.Trim()
            }

            $objectValue = ''
            if ($null -ne $ObjectName) {
                $objectValue = $ObjectName.Trim()
            }

            if (-not [string]::IsNullOrWhiteSpace($schemaValue) -and -not [string]::IsNullOrWhiteSpace($objectValue)) {
                return ('{0}.{1}' -f $schemaValue, $objectValue)
            }

            if (-not [string]::IsNullOrWhiteSpace($objectValue)) {
                return $objectValue
            }

            if (-not [string]::IsNullOrWhiteSpace($schemaValue)) {
                return $schemaValue
            }

            return ''
        }

        $dependencyRecords = [System.Collections.Generic.List[object]]::new()

        foreach ($row in $rows) {
            $referencingId = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencingId')
            $referencedId = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencedId')
            $referencingClass = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencingClass')
            $referencedClass = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencedClass')

            $referencingSchema = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencingSchema')).Trim()
            $referencingObject = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencingObject')).Trim()
            $referencingFullName = (& $buildFullName -SchemaName $referencingSchema -ObjectName $referencingObject)
            $referencingObjectType = (& $normalizeObjectType -TypeValue (& $getRowValue -Row $row -ColumnName 'ReferencingObjectTypeRaw'))

            $referencedServerRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedServer')).Trim()
            $referencedDatabaseRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedDatabase')).Trim()
            $referencedSchemaRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedSchema')).Trim()
            $referencedObjectRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedObject')).Trim()

            $referencedLocalSchema = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedLocalSchema')).Trim()
            $referencedLocalObject = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedLocalObject')).Trim()

            $resolvedReferencedSchema = $referencedSchemaRaw
            if ([string]::IsNullOrWhiteSpace($resolvedReferencedSchema)) {
                $resolvedReferencedSchema = $referencedLocalSchema
            }

            $resolvedReferencedObject = $referencedObjectRaw
            if ([string]::IsNullOrWhiteSpace($resolvedReferencedObject)) {
                $resolvedReferencedObject = $referencedLocalObject
            }

            $referencedFullName = (& $buildFullName -SchemaName $resolvedReferencedSchema -ObjectName $resolvedReferencedObject)

            $referencedObjectTypeRaw = & $getRowValue -Row $row -ColumnName 'ReferencedObjectTypeRaw'
            $referencedObjectType = (& $normalizeObjectType -TypeValue $referencedObjectTypeRaw)

            $isSchemaBound = (& $toBoolean -Value (& $getRowValue -Row $row -ColumnName 'IsSchemaBound'))
            $isCallerDependent = (& $toBoolean -Value (& $getRowValue -Row $row -ColumnName 'IsCallerDependent'))
            $isAmbiguous = (& $toBoolean -Value (& $getRowValue -Row $row -ColumnName 'IsAmbiguous'))

            $isCrossServer = -not [string]::IsNullOrWhiteSpace($referencedServerRaw)
            $isCrossDatabase = (-not [string]::IsNullOrWhiteSpace($referencedDatabaseRaw)) -and ($referencedDatabaseRaw -ine $databaseName)
            $isExternalReference = $isCrossServer -or $isCrossDatabase

            $dependencyRecords.Add([PSCustomObject]@{
                ReferencingDatabase = $databaseName
                ReferencingSchema = $referencingSchema
                ReferencingObject = $referencingObject
                ReferencingFullName = $referencingFullName
                ReferencingObjectType = $referencingObjectType

                ReferencedServer = $referencedServerRaw
                ReferencedDatabase = $referencedDatabaseRaw
                ReferencedSchema = $resolvedReferencedSchema
                ReferencedObject = $resolvedReferencedObject
                ReferencedFullName = $referencedFullName
                ReferencedObjectType = $referencedObjectType

                IsSchemaBound = $isSchemaBound
                IsCallerDependent = $isCallerDependent
                IsAmbiguous = $isAmbiguous

                IsCrossDatabase = $isCrossDatabase
                IsCrossServer = $isCrossServer
                IsExternalReference = $isExternalReference

                ReferencingId = $referencingId
                ReferencedId = $referencedId
                ReferencingClass = $referencingClass
                ReferencedClass = $referencedClass
            })
        }

        $sortedDependencies = @(
            $dependencyRecords |
                Sort-Object -Property ReferencingSchema, ReferencingObject, ReferencedDatabase, ReferencedSchema, ReferencedObject
        )

        $finalDependencies = @(
            $sortedDependencies |
                ForEach-Object {
                    $referencingSchemaValue = (& $toStringOrEmpty -Value $_.ReferencingSchema).Trim()
                    $referencingObjectValue = (& $toStringOrEmpty -Value $_.ReferencingObject).Trim()
                    $referencingFullNameValue = (& $buildFullName -SchemaName $referencingSchemaValue -ObjectName $referencingObjectValue)

                    $referencedSchemaValue = (& $toStringOrEmpty -Value $_.ReferencedSchema).Trim()
                    $referencedObjectValue = (& $toStringOrEmpty -Value $_.ReferencedObject).Trim()
                    $referencedFullNameValue = (& $buildFullName -SchemaName $referencedSchemaValue -ObjectName $referencedObjectValue)

                    [PSCustomObject]@{
                        ReferencingDatabase = $_.ReferencingDatabase
                        ReferencingSchema = $referencingSchemaValue
                        ReferencingObject = $referencingObjectValue
                        ReferencingFullName = $referencingFullNameValue
                        ReferencingObjectType = $_.ReferencingObjectType

                        ReferencedServer = $_.ReferencedServer
                        ReferencedDatabase = $_.ReferencedDatabase
                        ReferencedSchema = $referencedSchemaValue
                        ReferencedObject = $referencedObjectValue
                        ReferencedFullName = $referencedFullNameValue
                        ReferencedObjectType = $_.ReferencedObjectType

                        IsSchemaBound = $_.IsSchemaBound
                        IsCallerDependent = $_.IsCallerDependent
                        IsAmbiguous = $_.IsAmbiguous

                        IsCrossDatabase = $_.IsCrossDatabase
                        IsCrossServer = $_.IsCrossServer
                        IsExternalReference = $_.IsExternalReference

                        ReferencingId = $_.ReferencingId
                        ReferencedId = $_.ReferencedId
                        ReferencingClass = $_.ReferencingClass
                        ReferencedClass = $_.ReferencedClass
                    }
                }
        )

        Write-ExporterLog -Level Information -Message ("Number of dependencies found: {0}" -f $finalDependencies.Count)
        Write-ExporterLog -Level Information -Message 'Dependency query completed'

        return @($finalDependencies)
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to query dependency metadata. {0}" -f $_.Exception.Message))
    }
}

function Export-DependenciesCsv {
    <#
    .SYNOPSIS
        Exports dependency records to Dependencies\dependencies.csv.

    .DESCRIPTION
        Writes dependency records returned by Get-DatabaseDependencies to a deterministic
        CSV file with fixed column order for downstream analysis and spreadsheet use.

    .PARAMETER Dependencies
        Dependency records to export.

    .PARAMETER OutputFolder
        Target export folder that will contain the Dependencies subfolder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting dependencies CSV export'

        $dependencyArray = @($Dependencies)
        Write-ExporterLog -Level Information -Message ("Dependency count: {0}" -f $dependencyArray.Count)

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $dependenciesFolder -Force | Out-Null
        }

        $csvPath = [System.IO.Path]::Combine($dependenciesFolder, 'dependencies.csv')
        Write-ExporterLog -Level Information -Message ("CSV path: {0}" -f $csvPath)

        $columnOrder = @(
            'ReferencingFullName',
            'ReferencingObjectType',
            'ReferencedFullName',
            'ReferencedObjectType',
            'ReferencingDatabase',
            'ReferencedServer',
            'ReferencedDatabase',
            'IsCrossDatabase',
            'IsCrossServer',
            'IsExternalReference',
            'IsSchemaBound',
            'IsCallerDependent',
            'IsAmbiguous',
            'ReferencingId',
            'ReferencedId'
        )

        $sortedDependencies = @(
            $dependencyArray |
                Sort-Object -Property ReferencingFullName, ReferencedFullName |
                Select-Object -Property $columnOrder
        )

        if ($sortedDependencies.Count -gt 0) {
            $sortedDependencies |
                Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
        }
        else {
            $emptyTemplate = [PSCustomObject]@{
                ReferencingFullName = ''
                ReferencingObjectType = ''
                ReferencedFullName = ''
                ReferencedObjectType = ''
                ReferencingDatabase = ''
                ReferencedServer = ''
                ReferencedDatabase = ''
                IsCrossDatabase = ''
                IsCrossServer = ''
                IsExternalReference = ''
                IsSchemaBound = ''
                IsCallerDependent = ''
                IsAmbiguous = ''
                ReferencingId = ''
                ReferencedId = ''
            }

            @($emptyTemplate) |
                Select-Object -Property $columnOrder |
                Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8

            $csvLines = Get-Content -LiteralPath $csvPath
            if ($csvLines.Count -gt 0) {
                Set-Content -LiteralPath $csvPath -Value $csvLines[0] -Encoding utf8
            }
        }

        Write-ExporterLog -Level Information -Message 'Dependencies CSV export completed'

        return [PSCustomObject]@{
            DependencyCount = $sortedDependencies.Count
            CsvPath = $csvPath
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependencies CSV. {0}" -f $_.Exception.Message))
    }
}

function Export-DependenciesJson {
    <#
    .SYNOPSIS
        Exports dependency records to Dependencies\dependencies.json.

    .DESCRIPTION
        Writes dependency records returned by Get-DatabaseDependencies to a deterministic
        JSON array for downstream dependency processing.

    .PARAMETER Dependencies
        Dependency records to export.

    .PARAMETER OutputFolder
        Target export folder that will contain the Dependencies subfolder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting dependencies JSON export'

        $dependencyArray = @($Dependencies)
        Write-ExporterLog -Level Information -Message ("Dependency count: {0}" -f $dependencyArray.Count)

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $dependenciesFolder -Force | Out-Null
        }

        $jsonPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.json'))
        Write-ExporterLog -Level Information -Message ("JSON path: {0}" -f $jsonPath)

        if ($dependencyArray.Count -eq 0) {
            [System.IO.File]::WriteAllText($jsonPath, '[]', [System.Text.UTF8Encoding]::new($false))
        }
        else {
            $sortedDependencies = @(
                $dependencyArray |
                    Sort-Object -Property ReferencingFullName, ReferencedFullName
            )

            $jsonContent = $sortedDependencies | ConvertTo-Json -Depth 10 -AsArray
            [System.IO.File]::WriteAllText($jsonPath, $jsonContent, [System.Text.UTF8Encoding]::new($false))
        }

        Write-ExporterLog -Level Information -Message 'Dependencies JSON export completed'

        return [PSCustomObject]@{
            DependencyCount = $dependencyArray.Count
            JsonPath = $jsonPath
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependencies JSON. {0}" -f $_.Exception.Message))
    }
}

function Export-DependenciesDot {
    <#
    .SYNOPSIS
        Exports dependency records to Dependencies\dependencies.dot.

    .DESCRIPTION
        Writes dependency records returned by Get-DatabaseDependencies to a deterministic
        DOT graph file for foundational dependency visualization.

    .PARAMETER Dependencies
        Dependency records to export.

    .PARAMETER OutputFolder
        Target export folder that will contain the Dependencies subfolder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting dependencies DOT export'

        $dependencyArray = @($Dependencies)
        Write-ExporterLog -Level Information -Message ("Dependency count: {0}" -f $dependencyArray.Count)

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $dependenciesFolder -Force | Out-Null
        }

        $dotPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.dot'))
        Write-ExporterLog -Level Information -Message ("DOT path: {0}" -f $dotPath)

        $sortedDependencies = @(
            $dependencyArray |
                Sort-Object -Property ReferencingFullName, ReferencedFullName
        )

        $escapeDotLabel = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            $label = ''
            if ($null -ne $Value) {
                $label = [string]$Value
            }

            $label = $label.Replace('\\', '\\\\')
            $label = $label.Replace('"', '\\"')
            return $label
        }

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('digraph Dependencies {')

        foreach ($dependency in $sortedDependencies) {
            $fromName = & $escapeDotLabel -Value $dependency.ReferencingFullName
            $toName = & $escapeDotLabel -Value $dependency.ReferencedFullName
            $lines.Add(('    "{0}" -> "{1}";' -f $fromName, $toName))
        }

        $lines.Add('}')

        $dotContent = [string]::Join([Environment]::NewLine, $lines)
        [System.IO.File]::WriteAllText($dotPath, $dotContent, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Dependencies DOT export completed'

        return [PSCustomObject]@{
            DependencyCount = $sortedDependencies.Count
            DotPath = $dotPath
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependencies DOT. {0}" -f $_.Exception.Message))
    }
}

function Export-DependenciesSvg {
    <#
    .SYNOPSIS
        Exports dependency graph SVG to Dependencies\dependencies.svg.

    .DESCRIPTION
        Generates an SVG file from an existing DOT dependency graph using the Graphviz
        dot command-line tool.

    .PARAMETER OutputFolder
        Target export folder that contains the Dependencies subfolder.

    .PARAMETER DotPath
        Optional full path to the DOT file. If omitted, uses
        <OutputFolder>\Dependencies\dependencies.dot.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [Parameter(Mandatory = $false)]
        [string]$DotPath
    )

    try {
        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting dependencies SVG export'

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("Dependencies folder does not exist: {0}" -f $dependenciesFolder))
        }

        $resolvedDotPath = $null
        if ([string]::IsNullOrWhiteSpace($DotPath)) {
            $resolvedDotPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.dot'))
        }
        else {
            $resolvedDotPath = [System.IO.Path]::GetFullPath($DotPath.Trim())
        }

        $svgPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.svg'))

        Write-ExporterLog -Level Information -Message ("DOT path: {0}" -f $resolvedDotPath)
        Write-ExporterLog -Level Information -Message ("SVG path: {0}" -f $svgPath)

        if (-not (Test-Path -LiteralPath $resolvedDotPath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new(("DOT file does not exist: {0}" -f $resolvedDotPath))
        }

        $dotContent = Get-Content -LiteralPath $resolvedDotPath -Raw
        if ([string]::IsNullOrWhiteSpace($dotContent)) {
            throw [System.InvalidOperationException]::new(("DOT file is empty: {0}" -f $resolvedDotPath))
        }

        $dotPath = Get-GraphvizDotPath
        if ($null -eq $dotPath) {
            $message = @(
                'Graphviz was not found.',
                'Searched:',
                '    PATH',
                '    C:\Program Files\Graphviz\bin\dot.exe',
                '    C:\Program Files (x86)\Graphviz\bin\dot.exe',
                '',
                'Install:',
                'winget install Graphviz.Graphviz'
            ) -join [Environment]::NewLine

            throw [System.InvalidOperationException]::new($message)
        }

        & $dotPath '-Tsvg' $resolvedDotPath '-o' $svgPath
        $dotExitCode = $LASTEXITCODE

        if ($dotExitCode -ne 0) {
            throw [System.InvalidOperationException]::new((
                'Graphviz SVG generation failed with exit code {0}.' + [Environment]::NewLine +
                'DOT path: {1}' + [Environment]::NewLine +
                'SVG path: {2}'
            ) -f $dotExitCode, $resolvedDotPath, $svgPath)
        }

        if (-not (Test-Path -LiteralPath $svgPath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new(("SVG file was not created: {0}" -f $svgPath))
        }

        Write-ExporterLog -Level Information -Message 'Dependencies SVG export completed'

        return [PSCustomObject]@{
            DotPath = $resolvedDotPath
            SvgPath = $svgPath
            Generated = $true
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependencies SVG. {0}" -f $_.Exception.Message))
    }
}

function Export-DependenciesHtml {
    <#
    .SYNOPSIS
        Exports dependency visualization HTML to Dependencies\dependencies.html.

    .DESCRIPTION
        Generates a static HTML report that summarizes dependency metadata and embeds
        the existing dependency SVG directly into the page body.

    .PARAMETER Dependencies
        Dependency records to include in the report summary.

    .PARAMETER OutputFolder
        Target export folder that contains the Dependencies subfolder.

    .PARAMETER SvgPath
        Optional full path to the SVG file. If omitted, uses
        <OutputFolder>\Dependencies\dependencies.svg.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [Parameter(Mandatory = $false)]
        [string]$SvgPath
    )

    try {
        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting HTML export'

        $dependencyArray = @($Dependencies)
        Write-ExporterLog -Level Information -Message ("Dependency count: {0}" -f $dependencyArray.Count)

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("Dependencies folder does not exist: {0}" -f $dependenciesFolder))
        }

        if ([string]::IsNullOrWhiteSpace($SvgPath)) {
            $resolvedSvgPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.svg'))
        }
        else {
            $resolvedSvgPath = [System.IO.Path]::GetFullPath($SvgPath.Trim())
        }

        $htmlPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependencies.html'))

        Write-ExporterLog -Level Information -Message ("SVG path: {0}" -f $resolvedSvgPath)
        Write-ExporterLog -Level Information -Message ("HTML path: {0}" -f $htmlPath)

        if (-not (Test-Path -LiteralPath $resolvedSvgPath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new((
                'dependencies.svg was not found.' + [Environment]::NewLine +
                'Run Export-DependenciesSvg before Export-DependenciesHtml.'
            ))
        }

        $svgContent = Get-Content -LiteralPath $resolvedSvgPath -Raw
        if ([string]::IsNullOrWhiteSpace($svgContent)) {
            throw [System.InvalidOperationException]::new(("SVG file is empty: {0}" -f $resolvedSvgPath))
        }

        $escapeHtml = {
            param(
                [Parameter(Mandatory = $false)]
                [object]$Value
            )

            $text = ''
            if ($null -ne $Value) {
                $text = [string]$Value
            }

            $encoded = [System.Net.WebUtility]::HtmlEncode($text)
            if ($null -eq $encoded) {
                return ''
            }

            return $encoded.Replace("'", '&#39;')
        }

        $sortedDependencies = @(
            $dependencyArray |
                Sort-Object -Property ReferencingFullName, ReferencedFullName
        )

        $totalDependencies = $sortedDependencies.Count
        $crossDatabaseReferences = @($sortedDependencies | Where-Object { $_.IsCrossDatabase -eq $true })
        $crossServerReferences = @($sortedDependencies | Where-Object { $_.IsCrossServer -eq $true })
        $externalReferences = @($sortedDependencies | Where-Object { $_.IsExternalReference -eq $true })
        $callerDependentReferences = @($sortedDependencies | Where-Object { $_.IsCallerDependent -eq $true })
        $ambiguousReferences = @($sortedDependencies | Where-Object { $_.IsAmbiguous -eq $true })

        $relatedFiles = @(
            'dependencies.csv',
            'dependencies.json',
            'dependency-warnings.md',
            'dependencies.dot',
            'dependencies.svg'
        )

        $relatedFilesMarkup = [System.Text.StringBuilder]::new()
        foreach ($relatedFile in $relatedFiles) {
            [void]$relatedFilesMarkup.AppendLine(('                <li>{0}</li>' -f (& $escapeHtml -Value $relatedFile)))
        }

        $summaryRows = @(
            @('Total Dependencies', $totalDependencies),
            @('Cross Database References', $crossDatabaseReferences.Count),
            @('Cross Server References', $crossServerReferences.Count),
            @('External References', $externalReferences.Count),
            @('Caller Dependent References', $callerDependentReferences.Count),
            @('Ambiguous References', $ambiguousReferences.Count)
        )

        $summaryRowsMarkup = [System.Text.StringBuilder]::new()
        foreach ($summaryRow in $summaryRows) {
            [void]$summaryRowsMarkup.AppendLine(('                    <tr><th>{0}</th><td>{1}</td></tr>' -f (& $escapeHtml -Value $summaryRow[0]), (& $escapeHtml -Value $summaryRow[1])))
        }

        $htmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SQL Dependency Visualization Report</title>
    <style>
        :root {
            color-scheme: light;
            --border: #d0d7de;
            --surface: #ffffff;
            --subtle: #f6f8fa;
            --text: #1f2328;
            --muted: #57606a;
        }
        body {
            margin: 0;
            padding: 2rem;
            font-family: Arial, Helvetica, sans-serif;
            color: var(--text);
            background: #fafbfc;
        }
        main {
            max-width: 1200px;
            margin: 0 auto;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(31, 35, 40, 0.08);
            overflow: hidden;
        }
        header, section {
            padding: 1.5rem 2rem;
        }
        header {
            background: linear-gradient(180deg, #f8fbff 0%, #ffffff 100%);
            border-bottom: 1px solid var(--border);
        }
        h1, h2 {
            margin: 0 0 1rem 0;
            line-height: 1.2;
        }
        h1 {
            font-size: 1.8rem;
        }
        h2 {
            font-size: 1.1rem;
        }
        .summary-table {
            width: 100%;
            border-collapse: collapse;
        }
        .summary-table th,
        .summary-table td {
            padding: 0.75rem 1rem;
            border-bottom: 1px solid var(--border);
            text-align: left;
        }
        .summary-table th {
            width: 60%;
            background: var(--subtle);
            font-weight: 600;
        }
        .svg-panel {
            padding: 1rem;
            border: 1px solid var(--border);
            border-radius: 10px;
            background: #fff;
            overflow-x: auto;
        }
        .related-files {
            margin: 0;
            padding-left: 1.25rem;
        }
        .notes {
            color: var(--muted);
        }
        .section-grid {
            display: grid;
            gap: 1rem;
        }
    </style>
</head>
<body>
    <main>
        <header>
            <h1>SQL Dependency Visualization Report</h1>
            <p>This report summarizes SQL Server dependency metadata and embeds the exported dependency graph.</p>
        </header>
        <section>
            <h2>Summary</h2>
            <table class="summary-table" aria-label="Dependency summary">
                <tbody>
__SUMMARY_ROWS__                </tbody>
            </table>
        </section>
        <section>
            <h2>Dependency Graph</h2>
            <div class="svg-panel">
__SVG_CONTENT__
            </div>
        </section>
        <section class="section-grid">
            <div>
                <h2>Related Files</h2>
                <ul class="related-files">
__RELATED_FILES__                </ul>
            </div>
            <div>
                <h2>Notes</h2>
                <p class="notes">The graph is generated from sys.sql_expression_dependencies and represents SQL Server dependency metadata captured by the exporter.</p>
            </div>
        </section>
    </main>
</body>
</html>
'@

        $htmlContent = $htmlContent.Replace('__SUMMARY_ROWS__', $summaryRowsMarkup.ToString())
        $htmlContent = $htmlContent.Replace('__SVG_CONTENT__', $svgContent)
        $htmlContent = $htmlContent.Replace('__RELATED_FILES__', $relatedFilesMarkup.ToString())

        [System.IO.File]::WriteAllText($htmlPath, $htmlContent, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'HTML export completed'

        return [PSCustomObject]@{
            DependencyCount = $totalDependencies
            HtmlPath        = $htmlPath
            SvgPath         = $svgPath
            Generated       = $true
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependencies HTML. {0}" -f $_.Exception.Message))
    }
}

function Export-DependencyWarnings {
    <#
    .SYNOPSIS
        Exports dependency warning details to Dependencies\dependency-warnings.md.

    .DESCRIPTION
        Creates a markdown warning report from dependency records returned by
        Get-DatabaseDependencies for migration and review workflows.

    .PARAMETER Dependencies
        Dependency records to analyze for warning conditions.

    .PARAMETER OutputFolder
        Target export folder that will contain the Dependencies subfolder.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    try {
        if ($null -eq $Dependencies) {
            throw [System.InvalidOperationException]::new('Dependencies cannot be null.')
        }

        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            throw [System.InvalidOperationException]::new('OutputFolder cannot be null, empty, or whitespace.')
        }

        $resolvedOutputFolder = [System.IO.Path]::GetFullPath($OutputFolder.Trim())
        if (-not (Test-Path -LiteralPath $resolvedOutputFolder -PathType Container)) {
            throw [System.InvalidOperationException]::new(("OutputFolder does not exist: {0}" -f $resolvedOutputFolder))
        }

        Write-ExporterLog -Level Information -Message 'Starting dependency warning report generation'

        $dependencyArray = @($Dependencies)

        $dependenciesFolder = [System.IO.Path]::Combine($resolvedOutputFolder, 'Dependencies')
        if (-not (Test-Path -LiteralPath $dependenciesFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $dependenciesFolder -Force | Out-Null
        }

        $warningPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dependenciesFolder, 'dependency-warnings.md'))

        $sortedDependencies = @(
            $dependencyArray |
                Sort-Object -Property ReferencingFullName, ReferencedFullName
        )

        $crossDatabaseReferences = @(
            $sortedDependencies | Where-Object { $_.IsCrossDatabase -eq $true }
        )
        $crossServerReferences = @(
            $sortedDependencies | Where-Object { $_.IsCrossServer -eq $true }
        )
        $callerDependentReferences = @(
            $sortedDependencies | Where-Object { $_.IsCallerDependent -eq $true }
        )
        $ambiguousReferences = @(
            $sortedDependencies | Where-Object { $_.IsAmbiguous -eq $true }
        )

        Write-ExporterLog -Level Information -Message (
            "Warning counts - CrossDatabase: {0}, CrossServer: {1}, CallerDependent: {2}, Ambiguous: {3}" -f
            $crossDatabaseReferences.Count,
            $crossServerReferences.Count,
            $callerDependentReferences.Count,
            $ambiguousReferences.Count
        )
        Write-ExporterLog -Level Information -Message ("Output path: {0}" -f $warningPath)

        $lines = [System.Collections.Generic.List[string]]::new()

        $addDependencySection = {
            param(
                [Parameter(Mandatory = $true)]
                [string]$SectionTitle,

                [Parameter(Mandatory = $true)]
                [AllowEmptyCollection()]
                [object[]]$SectionDependencies
            )

            $normalizedSectionTitle = @($SectionTitle)
            $normalizedSectionDependencies = @($SectionDependencies)

            $sectionDescription = @(
                switch ($normalizedSectionTitle[0]) {
                'Cross Database References' {
                    @(
                        'These dependencies reference objects located in a different database than the current database.',
                        'Cross-database references can complicate migrations, restores, environment refreshes, and deployments because the referenced database must also exist and remain compatible.'
                    )
                }
                'Cross Server References' {
                    @(
                        'These dependencies reference objects located on another SQL Server instance.',
                        'Cross-server references are often among the highest-risk migration items because they depend on infrastructure outside the current database environment.'
                    )
                }
                'Caller Dependent References' {
                    @(
                        'These dependencies are resolved at runtime based on the execution context of the caller.',
                        'SQL Server cannot fully determine the referenced object during dependency analysis, so additional validation may be required.'
                    )
                }
                'Ambiguous References' {
                    @(
                        'SQL Server could not resolve these dependencies with complete certainty.'
                        'Ambiguous references should be reviewed manually to verify that the expected objects are actually being referenced.'
                    )
                }
                default { @() }
                }
            )

            $lines.Add(("## {0}" -f $normalizedSectionTitle[0]))
            $lines.Add('')

            foreach ($descriptionLine in @($sectionDescription)) {
                $lines.Add($descriptionLine)
            }

            if (@($sectionDescription).Count -gt 0) {
                $lines.Add('')
            }

            if ($normalizedSectionDependencies.Count -eq 0) {
                $lines.Add('None found.')
                $lines.Add('')
                return
            }

            foreach ($dependency in $normalizedSectionDependencies) {
                $referencingFullName = [string]$dependency.ReferencingFullName
                if ([string]::IsNullOrWhiteSpace($referencingFullName)) {
                    $referencingFullName = '[Unknown Referencing Object]'
                }

                $referencedFullName = [string]$dependency.ReferencedFullName
                if ([string]::IsNullOrWhiteSpace($referencedFullName)) {
                    $referencedFullName = '[Unknown Referenced Object]'
                }

                $lines.Add($referencingFullName)
                $lines.Add('    ->')
                $lines.Add($referencedFullName)
                $lines.Add('')
            }
        }

        $lines.Add('# Dependency Warning Report')
        $lines.Add('')
    $lines.Add('This report highlights dependency patterns that may require additional review during migrations, upgrades, environment refreshes, restores, and code reviews.')
    $lines.Add('')
    $lines.Add('The absence of warnings does not guarantee that all dependencies are fully understood. It only indicates that no issues matching the analyzed categories were detected.')
    $lines.Add('')
        $lines.Add('## Summary')
        $lines.Add('')
        $lines.Add(("Total Dependencies: {0}" -f $sortedDependencies.Count))
        $lines.Add(("Cross Database References: {0}" -f $crossDatabaseReferences.Count))
        $lines.Add(("Cross Server References: {0}" -f $crossServerReferences.Count))
        $lines.Add(("Caller Dependent References: {0}" -f $callerDependentReferences.Count))
        $lines.Add(("Ambiguous References: {0}" -f $ambiguousReferences.Count))
        $lines.Add('')

        & $addDependencySection -SectionTitle 'Cross Database References' -SectionDependencies $crossDatabaseReferences
        & $addDependencySection -SectionTitle 'Cross Server References' -SectionDependencies $crossServerReferences
        & $addDependencySection -SectionTitle 'Caller Dependent References' -SectionDependencies $callerDependentReferences
        & $addDependencySection -SectionTitle 'Ambiguous References' -SectionDependencies $ambiguousReferences

        $warningContent = [string]::Join([Environment]::NewLine, $lines)
        [System.IO.File]::WriteAllText($warningPath, $warningContent, [System.Text.UTF8Encoding]::new($false))

        Write-ExporterLog -Level Information -Message 'Dependency warning report generation completed'

        return [PSCustomObject]@{
            WarningPath = $warningPath
            CrossDatabaseCount = $crossDatabaseReferences.Count
            CrossServerCount = $crossServerReferences.Count
            CallerDependentCount = $callerDependentReferences.Count
            AmbiguousCount = $ambiguousReferences.Count
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to export dependency warnings. {0}" -f $_.Exception.Message))
    }
}
#endregion

#region Main
# When dot-sourced (for tests/development), load functions only and skip script execution.
if ($MyInvocation.InvocationName -eq '.') {
    return
}

try {
    $null = Export-SqlDatabaseDefinition
    exit 0
}
catch {
    Write-ExporterLog -Level Error -Message $_.Exception.Message
    exit 1
}
#endregion

