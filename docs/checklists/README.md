# Review Checklists

Reusable review heuristics for HOTL code review skills. These checklists inform review depth — they are not governance rules and do not define verdicts or severity. Skills that load them remain responsible for verdict models, HOTL contracts, and governance behavior.

## Checklist Index

| File | Purpose | Used by |
|---|---|---|
| `architecture-and-design.md` | SOLID violations and architecture smells | `code-review` (inline fallback), `pr-reviewing` (Subagent B) |
| `security-and-reliability.md` | Security heuristics beyond OWASP basics | `code-review` (inline fallback), `pr-reviewing` (Subagent C) |
| `performance-and-boundary-conditions.md` | Performance, boundary conditions, error handling | `code-review` (inline fallback), `pr-reviewing` (Subagent D) |
| `removal-and-simplification.md` | Dead code, redundant abstractions, simplification | `code-review` (inline fallback), `pr-reviewing` (Subagent B) |
