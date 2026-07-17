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
D:\DatabaseExports\BannerProd
```

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
- Profile name
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

# Profiles

Potential future profiles:

- Standard
- SchemaOnly
- SecurityAudit
- DependencyMapOnly
- ReferenceDataOnly
- MigrationReview

Default:

```yaml
profile: Standard
```

---

# Development Roadmap

## Sprint 1 - Foundation

- Project skeleton
- Create export.yaml
- Load YAML
- Create exportinfo.json
- Create export.log

## Sprint 2 - Core Export

- Connect to SQL Server
- Export schemas
- Export tables
- Export views
- Export procedures
- Export functions

## Sprint 3 - Dependency Data

- Query dependencies
- Export CSV
- Export JSON
- Dependency warnings

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