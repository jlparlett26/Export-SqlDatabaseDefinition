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

---
# Coding Standards

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

---

# Current Development State

Current Sprint:
Sprint 3 - Dependency Data

Current Milestone:
Dependency Export Framework

Current Feature:
Export-DependenciesCsv

Completed Milestones:

✅ Foundation
✅ Regression Framework
✅ Core Object Export

Regression Status:

✅ Test-FoundationRegression
✅ All object exports validated

Known Deferred Issues:

- Read-ExportProfile validation report formatting
- Review need for Test-ExportProfile

Future functionality is intentionally out of scope until this feature is completed.

---

# Core Goals

The tool shall:

- Export SQL Server objects into a deterministic folder structure
- Use a YAML configuration file
- Produce Git-friendly output
- Export security information
- Generate dependency documentation
- Create a visual dependency map from `sys.sql_expression_dependencies`
- Support repeatable exports for long-term change tracking

---

# Architectural Rules

## Configuration Management

The export.yaml schema is a versioned contract.

Changes to the schema must:

1. Be documented in ProjectPlan.md
2. Increment configVersion when appropriate
3. Remain backward compatible whenever practical

# Runtime Dependency Validation

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


## Development Dependencies

PSScriptAnalyzer

Install:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Purpose:
Static analysis and code quality validation.

## Quality Gates

Before closing a sprint:

- Regression tests must pass.
- New warnings must be reviewed.
- High-confidence warnings should be corrected.
- Any intentionally deferred warnings should be documented. 

- Invoke-ScriptAnalyzer must be executed.
    PSScriptAnalyzer Exceptions
        PSUseSingularNouns
        Export-* functions intentionally use plural nouns because they export collections of objects rather than a single object.
        This warning is accepted by design.

PSScriptAnalyzer Exceptions
Known Accepted Warnings
``
PSUseSingularNouns

Accepted by design.

Export-* functions intentionally use plural nouns because they
export collections of database objects rather than a single object.

Examples:

- Export-Tables
- Export-Views
- Export-Functions
- Export-Triggers

This warning will not be remediated.
``

## Repository Separation

1. The exporter project repository shall never contain exported database artifacts.

2. All export output must be written outside the project folder.

3. `export.yaml` shall reside in the export folder.

### Example

Exporter Code:

```text
C:\Work\Code\Export-SqlDatabaseDefinition
```

Database Export:

```text
D:\DatabaseExports\SomeDatabaseName
```

## Export Folder Ownership

The export folder is considered application data.

The exporter owns:

- export.yaml
- exportinfo.json
- export.log

The exporter must never modify files outside the export folder unless explicitly requested.

---

## Deterministic Output

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

---

## Object Organization

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

---

# Standard Export Structure

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

---

# YAML Configuration

## Automatic Configuration Creation

If `export.yaml` does not exist:

1. Create a default configuration
2. Inform the user
3. Exit successfully

The user reviews the configuration and reruns the exporter.

## Configuration Schema Version 

configVersion: 1

# SQL Database Exporter Configuration

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

---

## Dependency Settings

The YAML configuration should control:

- Dependency export enabled/disabled
- Include cross-database references
- Include cross-server references
- CSV output
- JSON output
- DOT output
- SVG output
- HTML output

---

# Metadata and Logging

## exportinfo.json

Store:

- Server
- Database
- Tool version
- Export timestamp

## export.log

Log:

- Startup
- Configuration loading
- Export steps
- Warnings
- Errors
- Completion status

---

# Core Object Export

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

---

# Security Export

Export:

```text
Security\
    Roles.sql

Security\
    Users.sql

Security\
    Permissions.sql
```

Primary use case:

- Migration review
- Security auditing

---

# Dependency Analysis

## Source

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

---

## Structured Outputs

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

---
# Dependency Analysis Enhancements

- Preserve synonym base-object metadata in exported files.
- Use synonym metadata when identifying cross-database and cross-server dependencies.
- Use synonym metadata during migration analysis and dependency reporting.

# Dependency Visualization

## DOT Output

```text
Dependencies\
    dependencies.dot
```

DOT is the canonical visualization source.

## SVG Output

```text
Dependencies\
    dependencies.svg
```

Benefits:

- Browser-friendly
- Git-friendly
- Scalable

## HTML Report

```text
Dependencies\
    dependencies.html
```

Include:

- Dependency graph
- Cross-database references
- Cross-server references
- Ambiguous references
- Caller-dependent references
- Orphaned objects

---

# Dependency Visualization Rules

## Initial Version

Keep visualization simple.

Example:

```text
dbo.vStudentSummary -> dbo.Student

dbo.usp_LoadSecurity -> dbo.SecurityRole
```

### Future Enhancement

Color coding:

- Tables = Blue
- Views = Green
- Procedures = Orange
- Functions = Purple
- External References = Red

---

## Dependency Warnings

Generate:

```text
Dependencies\
    dependency-warnings.md
```

Include:

- Ambiguous references
- Caller-dependent references
- Cross-database references
- Cross-server references
- Unresolved objects

---

# Reference Data

Reference data export is optional.

Examples:

- StateCodes
- Campuses
- Security roles
- Lookup tables

Controlled entirely through YAML.

---

# Development Roadmap

# Sprint 3 Dependency Analysis Design Decisions

## Canonical Dependency Source

Version 1 shall use:

    sys.sql_expression_dependencies

as the authoritative dependency source.

Known limitations:

- Dynamic SQL may not be detected.
- Some synonym scenarios may not fully resolve.
- SQL Server dependency metadata is accepted as authoritative for Version 1.

## Canonical Dependency Object Model

All dependency exports shall be generated from a single in-memory dependency model.

Minimum fields:

- ReferencingObject
- ReferencingSchema
- ReferencingType

- ReferencedServer
- ReferencedDatabase
- ReferencedSchema
- ReferencedObject

- IsSchemaBound
- IsCallerDependent
- IsAmbiguous

Future dependency outputs:

- dependencies.csv
- dependencies.json
- dependencies.dot
- dependencies.svg
- dependencies.html

must be generated from this model.

## Cross-Database References

Cross-database references shall be recorded.

Version 1 shall not attempt to connect to or resolve external databases.

Example:

    ViewA -> OtherDatabase.dbo.TableB

is recorded but not resolved.

## Cross-Server References

Cross-server references shall be recorded.

Version 1 shall not attempt to connect to linked servers.

Example:

    ViewA -> LinkedServer.Database.Schema.Table

is recorded but not resolved.

## Dependency Object Types

Version 1 shall standardize object types as:

- TABLE
- VIEW
- PROCEDURE
- FUNCTION
- TRIGGER
- SYNONYM
- SEQUENCE
- UNKNOWN

## Dependency Warning Rules

dependency-warnings.md shall report:

### Cross Database

ReferencedDatabase populated.

### Cross Server

ReferencedServer populated.

### Ambiguous References

is_ambiguous = 1

### Caller Dependent References

is_caller_dependent = 1

## Synonym Integration

Exported synonym metadata may be used to improve:

- Dependency reporting
- Migration analysis
- Cross-database reference identification
- Cross-server reference identification

Version 1 dependency extraction remains based on:

    sys.sql_expression_dependencies

Synonym metadata is supplemental information.

## Sprint 1 - Foundation

Completed:
✅ Project skeleton
✅ Logging
✅ Export profile schema
✅ Get-DefaultExportProfileContent
✅ Initialize-ExportProfile
✅ Read-ExportProfile
✅ Test-ExportDependencies
✅ Connect-SqlDatabase
✅ exportinfo.json
✅ export.log
✅ Export-DatabaseProperties
✅ Export-Schemas
✅ Export-Tables
✅ Test-FoundationRegression

## Sprint 2 - Core Export

✅ Connect-SqlDatabase
✅ Export-Schemas
✅ Export-Tables
✅ Export-Views
✅ Export-StoredProcedures
✅ Export-Functions
✅ Export-Triggers
✅ Export-Synonyms
✅ Export-Sequences

Regression Coverage:
✅ Full object export validation

Known Technical Debt:
✅ Read-ExportProfile formatting
✅ Test-ExportProfile decision pending

Lessons Learned:
✅ Regression framework became essential
✅ Object-per-file approach works well
✅ Metadata headers are valuable

Completed Milestones:

✅ Foundation
✅ Core Objec

## Sprint 3 - Dependency Data

- Query dependencies
- Export CSV
- Export JSON
- Dependency warnings

### Sprint 3 Build Order

- Create Get-DatabaseDependencies
- Query sys.sql_expression_dependencies
- Return standardized dependency objects

## Sprint 4 - Dependency Visualization

- Generate DOT
- Generate SVG
- Generate HTML report

## Sprint 5 - Security

- Export roles
- Export users
- Export permissions

## Sprint 6 - Reference Data

- Export lookup tables
- YAML controlled configuration

## Sprint 7 - Profiles

- Named profiles
- Configuration upgrades

## Sprint 8 - Polish

- Dependency filtering
- Large graph handling
- Git integration
- Detect dot-sourcing and avoid automatic execution.
- Allow developers to load functions without running the exporter.
- Generate dependency report from Test-ExportDependencies
- Export dependency status to exportinfo.json
- Known cosmetic defect: Read-ExportProfile validation report formatting
- Test-ExportProfile: decide if necessary

# Future Analysis Features Wishlist

These features are intentionally outside the MVP scope.
They may require additional SQL queries, performance data, or analysis beyond object export.

These items should not influence current architecture unless
they can be implemented cleanly after the core exporter is complete.

## Naming Convention Analysis

Report:

- Tables without primary keys
- Non-standard constraint names
- Generic index names
- Objects using reserved words
- Objects with spaces
- Mixed naming standards

Output:

Analysis\
    NamingStandards.md

# Known Issues

Read-ExportProfile currently reports validation failures correctly but does not
properly render the detailed validation list.

The validation logic is correct.

Only the formatting of the error report needs improvement.

Deferred to Sprint 8.

---

# Future Enhancements

## SSMS Integration

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

---

# MVP Definition

The first release is complete when it can:

- Create export.yaml automatically
- Load configuration
- Export database objects
- Export security
- Generate export metadata
- Generate export log
- Export dependency data
- Generate dependency visualizations

---

# Example Export

```text
BannerProd
│
├── export.yaml
├── exportinfo.json
├── export.log
│
├── Tables
├── Views
├── StoredProcedures
├── Functions
└── Dependencies
    ├── dependencies.csv
    ├── dependencies.json
    ├── dependencies.dot
    ├── dependencies.svg
    └── dependencies.html

```

---

# Future Analysis Features Wishlist

## Script Updates

- Evaluate adding:

    USE [<DatabaseName>]
    GO

  to exported SQL files to reduce accidental deployment
  into the wrong database.

- Consider making this configurable through export.yaml.

- Review impact on deployment tools and Git diffs before implementation.

## Performance

- Missing Index Recommendations
- Index Health Analysis
- View Optimization Analysis

## Upgrade Readiness

- Deprecated Feature Analysis
- Upgrade Readiness Report

## Security

- Security Risk Analysis

## Data Integrity

- Foreign Key Trust Analysis
- Constraint Health Analysis

## Dependency Analysis

- Change Impact Analysis
- Orphaned Object Analysis

