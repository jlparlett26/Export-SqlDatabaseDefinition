
# Export-SqlDatabaseDefinition

## Project Vision

Build an opinionated PowerShell tool named:

```text
Export-SqlDatabaseDefinition
```

that exports a SQL Server database into a standardized folder structure suitable for:

- Source control
- Documentation
- Migration planning
- Dependency analysis
- Security review
- Change tracking

This is **not** intended to be a clone of the SSMS Generate Scripts wizard.

This is a **Database-to-Folder Exporter with Dependency Documentation**.

## Coding Standards

All PowerShell code should:

- Target PowerShell 7.6+
- Use Set-StrictMode
- Use CmdletBinding
- Use comment-based help
- Use Verb-Noun naming
- Use UTF-8 encoding
- Prefer deterministic output
- Avoid hard-coded paths
- Avoid writing exported artifacts into the project repository
- Separate configuration generation from configuration usage

## Development Process 

### Development Dependencies

PSScriptAnalyzer

Install:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Purpose:

Static analysis and code quality validation.

### Quality Gates

Before closing a sprint:

- Regression tests must pass.
- New warnings must be reviewed.
- High-confidence warnings should be corrected.
- Any intentionally deferred warnings should be documented.

- Invoke-ScriptAnalyzer must be executed.

### Accepted PSScriptAnalyzer Exceptions

PSScriptAnalyzer exceptions are accepted by design:

- PSUseSingularNouns
- Export-* functions intentionally use plural nouns because they export collections of objects rather than a single object.

## Current Development State

Current Sprint:

Sprint 8 - Database Code Analysis

Sprint 8 Status:

Active

Current Milestone:

Current Feature:

Completed Milestones:

- Foundation
- Core Object Export
- Dependency Data Export
- Dependency Visualization
- Security Export
- Reference Data Export

Regression Status:

- Test-FoundationRegression PASS
- Test-DependencyModel PASS
- Test-SecurityRegression PASS
- Test-ReferenceDataRegression PASS

Current Status:

✅ Sprint 6 complete
✅ Reference Data export complete
✅ Sprint 7 Configuration Evolution paused
✅ Named Profiles not currently necessary
✅ Next active work is Database Code Analysis

Current Test Status:

All regression suites passing.

## Architectural Rules

### Configuration Management

The export.yaml schema is a versioned contract.

Changes to the schema must:

1. Be documented in ProjectPlan.md
2. Increment configVersion when appropriate
3. Remain backward compatible whenever practical

### Runtime Dependency Validation

The exporter validates runtime dependencies before beginning work.

Required Dependencies

- PowerShell 7.6+
- powershell-yaml

Optional Dependencies

- SqlServer
- Graphviz

Dependency validation should provide:

- Dependency name
- Required or optional status
- Installation command
- Validation status

The exporter must never automatically install dependencies.

The exporter should fail fast before beginning export processing.

Future Enhancement:

Dependency validation should report installation commands for both required and optional dependencies.

Example:

SqlServer
    Install-Module SqlServer -Scope CurrentUser

Graphviz
    winget install Graphviz.Graphviz

### Deterministic Output

The exporter shall generate deterministic output.

Generated files must not contain:

- Timestamps
- Machine names
- User names
- Environment-specific values

The same database should generate:

- The same file names
- The same folder structure
- The same object ordering

Goal:

```text
git diff
```

should show only meaningful changes.

### Repository Separation

1. The exporter project repository shall never contain exported database artifacts.

2. All export output must be written outside the project folder.

3. `export.yaml` shall reside in the export folder.

### Export Folder Ownership

The export folder is considered application data.

The exporter owns:

- export.yaml
- exportinfo.json
- export.log

The exporter must never modify files outside the export folder unless explicitly requested.

### Object Organization

- One object per file
- Predictable folder structure
- Consistent naming conventions

Examples:

```text
Tables\
    dbo.Customer.sql

Views\
    dbo.vActiveStudents.sql

StoredProcedures\
    dbo.usp_LoadSecurity.sql
```

## Standard Export Structure

```text
DatabaseName
│
├── export.yaml
├── exportinfo.json
├── export.log
│
├── Database
├── Schemas
├── Tables
├── Views
├── StoredProcedures
├── Functions
├── Triggers
├── Synonyms
├── Sequences
├── Security
├── ReferenceData
└── Dependencies
```

## Configuration

### Automatic Configuration Creation

If `export.yaml` does not exist:

1. Create a default configuration
2. Inform the user
3. Exit successfully

The user reviews the configuration and reruns the exporter.

### Configuration Schema Version

`configVersion: 1`

### SQL Database Exporter Configuration

```yaml
configVersion: 1

# SQL Server connection settings
connection:

  # SQL Server instance name
  server: CHANGE_ME

  # Database name
  database: CHANGE_ME

  # Windows | SQL
  authentication: Windows

export:

  schemas: true
  tables: true
  views: true
  storedProcedures: true
  functions: true
  triggers: true
  synonyms: true
  sequences: true

security:

  # Export security information
  enabled: true

  roles: true
  users: true
  permissions: true

dependencies:

  # Export dependency information from
  # sys.sql_expression_dependencies
  enabled: true

  csv: true
  json: true
  dot: true
  svg: true
  html: true

referenceData:

  enabled: false

  # Tables whose data should be exported
  tables: []
```

### Dependency Settings

The YAML configuration should control:

- Dependency export enabled/disabled
- Include cross-database references
- Include cross-server references
- CSV output
- JSON output
- DOT output
- SVG output
- HTML output

## Logging and Metadata

### exportinfo.json

Store:

- Server
- Database
- Tool version
- Export timestamp

### export.log

Log:

- Startup
- Configuration loading
- Export steps
- Warnings
- Errors
- Completion status

## Core Export Features

### Database and Object Export

The exporter will support:

- Database settings
- Schemas
- Tables
- Views
- Stored Procedures
- Functions
- Triggers
- Synonyms
- Sequences

### Security Export

Export:

```text
Security\
    Roles.sql

Security\
    Users.sql

Security\
    Permissions.sql
```

Status:

- Roles.sql: implemented
- Users.sql: implemented
- Permissions.sql: implemented

Primary use case:

- Migration review
- Security auditing

### Reference Data Export

Reference data export is optional.

Reference data export is controlled entirely through export.yaml.

Tables must be explicitly listed.

Wildcard table selection is not supported.

Automatic discovery of reference tables is not supported.

Preferred YAML format:

```yaml
referenceData:
    enabled: true
    tables:
        - "[dbo].[tblUSDBannerSecurityArchive_TEMP]"
```

Table names may be stored in bracketed schema-qualified format:

```text
[schema].[table]
```

Output format is one file per table.

Example output:

```text
ReferenceData\
        dbo.tblUSDBannerSecurityArchive_TEMP.sql
```

Version 1 generates INSERT statements only.

Version 1 does not generate MERGE statements.

Version 1 does not generate TRUNCATE statements.

If a configured table contains zero rows, the exporter still creates the file.

Example:

```text
-- Table: [dbo].[SomeLookupTable]
-- No rows exported.
```

Row ordering must be deterministic.

Preferred ordering:

Primary key order when available.

Fallback ordering:

All columns ascending when no primary key exists.

Examples:

- StateCodes
- Campuses
- Security roles
- Lookup tables

Controlled entirely through YAML.

## Dependency Analysis

### Source

Dependencies will be collected from:

```sql
sys.sql_expression_dependencies
```

Capture:

- Referencing object
- Referencing schema
- Referencing type
- Referenced server
- Referenced database
- Referenced schema
- Referenced object
- Schema-bound flag
- Caller-dependent flag
- Ambiguous flag

### Canonical Dependency Model

All dependency exports shall be generated from a single in-memory dependency model.

Minimum fields:

- ReferencingDatabase
- ReferencingSchema
- ReferencingObject
- ReferencingFullName
- ReferencingObjectType

- ReferencedServer
- ReferencedDatabase
- ReferencedSchema
- ReferencedObject
- ReferencedFullName
- ReferencedObjectType

- IsSchemaBound
- IsCallerDependent
- IsAmbiguous
- IsCrossDatabase
- IsCrossServer
- IsExternalReference

- ReferencingId
- ReferencedId
- ReferencingClass
- ReferencedClass

Dependency outputs:

Completed:

- dependencies.csv
- dependencies.json
- dependency-warnings.md

Completed visualization outputs:

- dependencies.dot
- dependencies.svg
- dependencies.html

Purpose:

- Migration review
- Operational risk review
- Dependency validation
- Pre-upgrade assessment

must be generated from this model.

### Cross-Database References

Cross-database references shall be recorded.

Version 1 shall not attempt to connect to or resolve external databases.

Example:

    ViewA -> OtherDatabase.dbo.TableB

is recorded but not resolved.

### Cross-Server References

Cross-server references shall be recorded.

Version 1 shall not attempt to connect to linked servers.

Example:

    ViewA -> LinkedServer.Database.Schema.Table

is recorded but not resolved.

### Dependency Object Types

Version 1 shall standardize object types as:

- TABLE
- VIEW
- PROCEDURE
- FUNCTION
- TRIGGER
- SYNONYM
- SEQUENCE
- UNKNOWN

### Dependency Warning Rules

dependency-warnings.md shall report:

- Cross Database References
- Cross Server References
- Ambiguous References
- Caller Dependent References

### Structured Outputs

```text
Dependencies\
    dependencies.csv
```

Purpose:

- Excel analysis
- Filtering
- Troubleshooting

```text
Dependencies\
    dependencies.json
```

Purpose:

- Automation
- Comparisons
- Reporting

```text
Dependencies\
    dependency-warnings.md
```

Purpose:

- Migration review
- Operational risk review
- Dependency validation
- Pre-upgrade assessment

### Dependency Analysis Enhancements

- Preserve synonym base-object metadata in exported files.
- Use synonym metadata when identifying cross-database and cross-server dependencies.
- Use synonym metadata during migration analysis and dependency reporting.

### Synonym Integration

Exported synonym metadata may be used to improve:

- Dependency reporting
- Migration analysis
- Cross-database reference identification
- Cross-server reference identification

Version 1 dependency extraction remains based on:

```text
sys.sql_expression_dependencies
```

Synonym metadata is supplemental information.

## Dependency Visualization

### DOT Output

```text
Dependencies\
    dependencies.dot
```

Status: implemented

DOT is the canonical visualization source.

### SVG Output

```text
Dependencies\
    dependencies.svg
```

Status: implemented

Benefits:

- Browser-friendly
- Git-friendly
- Scalable

### HTML Report

```text
Dependencies\
    dependencies.html
```

Status: implemented

Include:

- Dependency graph
- Cross-database references
- Cross-server references
- Ambiguous references
- Caller-dependent references
- Orphaned objects

### Dependency Visualization Rules

Keep visualization simple.

Example:

```text
dbo.vStudentSummary -> dbo.Student

dbo.usp_LoadSecurity -> dbo.SecurityRole
```

Future Enhancement:

Color coding:

- Tables = Blue
- Views = Green
- Procedures = Orange
- Functions = Purple
- External References = Red

## Development Roadmap

### Sprint 1 - Foundation

Completed:

- Project skeleton
- Logging
- Export profile schema
- Get-DefaultExportProfileContent
- Initialize-ExportProfile
- Read-ExportProfile
- Test-ExportDependencies
- Connect-SqlDatabase
- exportinfo.json
- export.log
- Test-FoundationRegression

### Sprint 2 - Core Export

Completed:

- Connect-SqlDatabase
- Export-DatabaseProperties
- Export-Schemas
- Export-Tables
- Export-Views
- Export-StoredProcedures
- Export-Functions
- Export-Triggers
- Export-Synonyms
- Export-Sequences

Regression Coverage:

- Full object export validation

Known Technical Debt:

- Read-ExportProfile formatting
- Test-ExportProfile decision pending

Lessons Learned:

- Regression framework became essential
- Object-per-file approach works well
- Metadata headers are valuable

### Sprint 3 - Dependency Data

Completed Deliverables:

- Get-DatabaseDependencies
- ReferencingFullName
- ReferencedFullName
- Export-DependenciesCsv
- Export-DependenciesJson
- Export-DependencyWarnings
- Test-DependencyModel

Validated By:

- Test-FoundationRegression
- Test-DependencyModel

Sprint 3 review complete.

### Sprint 4 - Dependency Visualization

Completed:

- Export-DependenciesDot
- Export-DependenciesSvg
- Export-DependenciesHtml
- Graphviz detection improvements

Validated By:

- Test-DependencyModel

Retrospective:

The visualization framework is functional and validated.
The generated outputs satisfy current requirements but
are considered an initial implementation.

Future visualization improvements remain deferred to
later roadmap phases.

### Sprint 5 - Security

Sprint 5 Goal:

Export SQL Server security artifacts.

Planned Outputs:

```text
Security\
    Roles.sql

Security\
    Users.sql

Security\
    Permissions.sql
```

Recommended Build Order:

1. Export-Roles
2. Export-Users
3. Export-Permissions

Completed:

- Export-Roles
- Export-Users
- Export-Permissions

Validated By:

- Test-SecurityRegression

In Progress:

- None

Planned:

- Security permission analysis (future if applicable)

Status:

Sprint 5 complete.

Validation Strategy:

Extend existing regression testing.

Each security export should produce deterministic output.

Lessons Learned:

The security export subsystem follows the same
deterministic export patterns used throughout the project.

Dedicated security regression testing simplified
implementation and validation.

### Sprint 6 - Reference Data

Sprint 6 Goal:

Export selected reference data from configured tables.

Planned Outputs:

```text
ReferenceData\
    dbo.tblUSDBannerSecurityArchive_TEMP.sql
```

Reference Data Design Principles:

- YAML-controlled
- Explicit table selection
- Deterministic output
- One file per table
- No wildcard table selection
- No automatic table discovery
- Bracketed [schema].[table] entries supported
- INSERT statements only in Version 1
- No MERGE statements in Version 1
- No TRUNCATE statements in Version 1
- Empty configured tables still produce output files
- Primary key ordering preferred; otherwise all columns ascending

Recommended Build Order:

1. Reference Data Design Review
2. Define YAML schema
3. Export-ReferenceData
4. Reference Data Regression Testing

Completed:

- Reference Data Design Review
- Export-ReferenceData
- Test-ReferenceDataRegression

In Progress:

- None

Planned:

- None

Validated By:

- Test-ReferenceDataRegression

Status:

Sprint 6 complete.

Known Design Principles:

- Remain YAML-based
- Remain deterministic
- Avoid breaking existing export.yaml files
- Preserve backward compatibility whenever practical

### Sprint 7 - Configuration Evolution

Status:

Paused / Deferred

Folder-based environment management may provide a simpler and more maintainable solution than an explicit profile framework.


Sprint 7 Goal:

Evolve configuration safely when real schema evolution needs exist.

Planned Features:

- Configuration Versioning
- Configuration Upgrades
- Backward Compatibility

Design Review Notes:

- Named Profiles are currently not necessary.
- The current export-folder model already supports DEV, TEST, and PROD through separate folders.

Example:

    D:\Exports\DEV\BannerSecurity\
    D:\Exports\TEST\BannerSecurity\
    D:\Exports\PROD\BannerSecurity\

Each folder contains its own:

    export.yaml
    exportinfo.json
    export.log
    exported artifacts

Design Question:

Do profiles solve a real problem that export folders do not?

Current Conclusion:

Not currently.

Profile implementation should remain paused unless a future requirement is identified that cannot be solved through folder-based environment management.

Configuration Evolution should resume only when a real configVersion change or backward-compatibility issue exists.

Sprint 7 remains deferred until a real configuration schema change requires versioning, upgrades, or backward-compatibility handling.

Named Profiles are not currently planned because separate export folders already solve the DEV/TEST/PROD environment separation problem.


### Sprint 8 - Database Health Analysis

- Missing Index Recommendations
- Index Health Analysis
- View Optimization Analysis
- Deprecated Feature Analysis
- Upgrade Readiness Report
- Foreign Key Trust Analysis
- Constraint Health Analysis
- Security Risk Analysis

- Tables without primary keys
- Non-standard constraint names
- Generic index names
- Objects using reserved words
- Objects with spaces
- Mixed naming standards
- MS SQL Coding standards
- Joins, Right outer, Left outer used
- Joins producing a cartesian result
- empty tables
- empty views
- views that return an error
- objects that have a space in the name

#### Naming Convention Analysis
needed: NamingStandards.md
Output:

```text
Analysis\
    NamingStandards.md
```

### Sprint 9 - Database Code Analysis

Sprint 8 Purpose:

Add reports that make exported database code more useful during DBA review.

Planned Analysis Scope:

####  Orphaned Object Analysis - Analysis Framework

- Complete

Dependency-Based Objects - Dependency-Based Candidates
- Views
- Procedures
- Functions
- Triggers
- Synonyms

Unused Views
Unused Procedures
Unused Functions
Unused Synonyms

Security Objects - Security Candidates
- Roles
- Users
- Permissions

Roles Without Members
Users Without Roles
Permissions Assigned To Unused Principals

Reference Data - Data Candidates
- Reference Data

Empty Reference Tables
Reference Tables Not Configured For Export

Invoke-OrphanedObjectAnalysis

    Analyze-DependencyObjects

    Analyze-SecurityObjects

    Analyze-ReferenceData

Analysis\
    OrphanedObjects.md

Analysis\
    SecurityAnalysis.md

Analysis\
    ReferenceDataHealth.md


- Naming Convention Analysis
- Tables without primary keys
- Non-standard constraint names
- Generic index names
- Objects using reserved words
- Objects with spaces
- Mixed naming standards
- MS SQL Coding standards
- Joins, Right outer, Left outer used
- Joins producing a cartesian result
- empty tables
- empty views
- views that return an error
- objects that have a space in the name

- Change Impact Analysis


### Sprint 10 - Dependency Visualization Improvements

Sprint 9 Purpose:

Improve the usefulness of the existing DOT/SVG/HTML outputs for actual DBA code review.

Planned Improvements:

- Dependency filtering
- Large graph handling
- Color coding
- Tables = Blue
- Views = Green
- Procedures = Orange
- Functions = Purple
- External References = Red
- Graph usability improvements

Current State Note:

The current visualization outputs are functional and validated but are considered initial implementations. Future work should make them more actionable for database code review.



### Sprint 11 - Exporter Reliability and Developer Experience

- Detect dot-sourcing and avoid automatic execution.
- Allow developers to load functions without running the exporter.
- Read-ExportProfile validation report formatting.
- Test-ExportProfile: decide if necessary.
- TestFramework.ps1 consolidation if not already fully complete.

### Sprint 12 - Export Metadata and Reporting

- Generate dependency report from Test-ExportDependencies.
- Export dependency status to exportinfo.json.
- Git integration.

Lessons Learned:

The project should continue favoring simple, deterministic, file-based solutions unless a more complex abstraction provides clear value.

## Known Issues

- Read-ExportProfile currently reports validation failures correctly but does not properly render the detailed validation list.
- The validation logic is correct.
- Only the formatting of the error report needs improvement.
- Deferred to Sprint 11.

## Future Enhancements

### SSMS Integration

Preferred workflow:

```text
Open SSMS
Connect to Server
Select Database
Run Exporter
```

Avoid requiring:

```text
-Server
-Database
```

for normal usage.

Support explicit parameters for automation.

## Future Analysis Features Wishlist

These features are intentionally outside the MVP scope unless promoted into planned roadmap sprints.

They may require additional SQL queries, performance data, or analysis beyond object export.

These items should not influence current architecture unless they can be implemented cleanly after the core exporter is complete.

### Script Updates

- Evaluate adding:

    USE [<DatabaseName>]
    GO

  to exported SQL files to reduce accidental deployment into the wrong database.

- Consider making this configurable through export.yaml.

- Review impact on deployment tools and Git diffs before implementation.

### Performance

- Missing Index Recommendations
- Index Health Analysis
- View Optimization Analysis

### Upgrade Readiness

- Deprecated Feature Analysis
- Upgrade Readiness Report

### Security

- Security Risk Analysis

### Data Integrity

- Foreign Key Trust Analysis
- Constraint Health Analysis

### Dependency Analysis

- Change Impact Analysis
- Orphaned Object Analysis

## MVP Definition

The first release is complete when it can:

- Create export.yaml automatically
- Load configuration
- Export database objects
- Export security
- Generate export metadata
- Generate export log
- Export dependency data
- Generate dependency visualizations

Status:
MVP Complete

## Example Export

```text

DatabaseName
│
├── export.yaml
├── exportinfo.json
├── export.log
│
├── Database
├── Schemas
├── Tables
├── Views
├── StoredProcedures
├── Functions
├── Triggers
├── Synonyms
├── Sequences
├── Security
├── ReferenceData
└── Dependencies
    ├── dependencies.csv
    ├── dependencies.json
    ├── dependency-warnings.md
    ├── dependencies.dot
    ├── dependencies.svg
    └── dependencies.html

```
