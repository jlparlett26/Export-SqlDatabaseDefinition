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
        Read-ExportProfile -Path 'C:\Exports\BannerProd\export.yaml'

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
#endregion

#region Dependency Functions
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
            Notes = 'Get-Command dot -ErrorAction SilentlyContinue'
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
                $graphvizCommand = Get-Command -Name 'dot' -ErrorAction SilentlyContinue
                if ($null -ne $graphvizCommand) {
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

        $dependencyRecords = [System.Collections.Generic.List[object]]::new()

        foreach ($row in $rows) {
            $referencingId = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencingId')
            $referencedId = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencedId')
            $referencingClass = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencingClass')
            $referencedClass = & $toNullableInt -Value (& $getRowValue -Row $row -ColumnName 'ReferencedClass')

            $referencingSchema = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencingSchema'))
            $referencingObject = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencingObject'))
            $referencingObjectType = (& $normalizeObjectType -TypeValue (& $getRowValue -Row $row -ColumnName 'ReferencingObjectTypeRaw'))

            $referencedServerRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedServer'))
            $referencedDatabaseRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedDatabase'))
            $referencedSchemaRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedSchema'))
            $referencedObjectRaw = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedObject'))

            $referencedLocalSchema = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedLocalSchema'))
            $referencedLocalObject = (& $toStringOrEmpty -Value (& $getRowValue -Row $row -ColumnName 'ReferencedLocalObject'))

            $resolvedReferencedSchema = $referencedSchemaRaw
            if ([string]::IsNullOrWhiteSpace($resolvedReferencedSchema)) {
                $resolvedReferencedSchema = $referencedLocalSchema
            }

            $resolvedReferencedObject = $referencedObjectRaw
            if ([string]::IsNullOrWhiteSpace($resolvedReferencedObject)) {
                $resolvedReferencedObject = $referencedLocalObject
            }

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
                ReferencingObjectType = $referencingObjectType

                ReferencedServer = $referencedServerRaw
                ReferencedDatabase = $referencedDatabaseRaw
                ReferencedSchema = $resolvedReferencedSchema
                ReferencedObject = $resolvedReferencedObject
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

        Write-ExporterLog -Level Information -Message ("Number of dependencies found: {0}" -f $sortedDependencies.Count)
        Write-ExporterLog -Level Information -Message 'Dependency query completed'

        return @($sortedDependencies)
    }
    catch {
        throw [System.InvalidOperationException]::new(("Failed to query dependency metadata. {0}" -f $_.Exception.Message))
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

