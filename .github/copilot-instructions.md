# Export-SqlDatabaseDefinition Copilot Instructions

Before generating code:

1. Read:
   docs/ProjectPlan.md

2. Treat ProjectPlan.md as the authoritative project specification.

3. Follow all architectural rules defined in ProjectPlan.md.


4. If a code generation request conflicts with ProjectPlan.md:

   - Identify the conflict.
   - Explain the tradeoffs.
   - Recommend a solution.
   - Ask for confirmation before modifying the architecture or violating ProjectPlan.md

5. Do not introduce functionality that violates project requirements.

## Project Standards

- PowerShell 7.6+
- One object per file
- Deterministic output
- No timestamps in generated SQL files
- No machine-specific information in generated SQL files
- Git-friendly output
- YAML configuration
- Verb-Noun naming
- Comment-based help
- CmdletBinding
- Strict mode enabled

## Repository Rules

- Never write exported database artifacts into this repository.
- All exports must occur outside the project folder.
- export.yaml resides in the export folder, not the project folder.

## Development Philosophy

- Prefer simple implementations.
- Build small incremental features.
- Complete one phase before starting the next.
- Do not implement future phases unless explicitly requested.

## Project Plan Evolution

ProjectPlan.md is expected to evolve over time.

If a requested change appears to improve the architecture:

- Describe the proposed change.
- Explain benefits and drawbacks.
- Recommend whether ProjectPlan.md should be updated.
- Do not automatically modify architectural assumptions without confirmation.
