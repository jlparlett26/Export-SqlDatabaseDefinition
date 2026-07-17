# Export-SqlDatabaseDefinition Standards

- PowerShell 7.6+
- No exported database artifacts inside repository
- All exports must occur outside project folder
- YAML configuration lives in export folder
- Deterministic output only
- No timestamps in generated SQL files
- One object per file
- Use Verb-Noun naming
- Use comment-based help
``