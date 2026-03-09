---
name: setup-project
description: Use to generate HOTL adapter files for the current project — creates AGENTS.md, .clinerules, cursor rules, or copilot instructions depending on tools the team uses.
---

# Setup Project for HOTL

## Overview

Generate the right config files so every code assistant on your team follows HOTL principles.

**Announce:** "Running HOTL project setup. Let me check what tools your team uses."

## Process

1. Ask: "Which code assistants does your team use?" (select all that apply)
   - Claude Code
   - Codex (OpenAI)
   - Cline (VS Code extension)
   - Cursor
   - GitHub Copilot

2. For each selected tool, generate the appropriate file:

| Tool | File Generated | Location |
|---|---|---|
| Claude Code | `CLAUDE.md` | Project root |
| Codex | `AGENTS.md` | Project root |
| Cline | `.clinerules` | Project root |
| Cursor | `.cursor/rules/hotl.md` | Project root |
| GitHub Copilot | `.github/copilot-instructions.md` | Project root |

3. Each generated file contains:
   - HOTL operating principles (intent/verification/governance contracts)
   - Link to `hotl-workflow-<slug>.md` format
   - Risk level guidelines
   - What always requires human review

4. Commit all generated files:

```bash
git add AGENTS.md .clinerules .cursor/ .github/ CLAUDE.md
git commit -m "chore: add HOTL adapter files for [tool list]"
```

## AGENTS.md Template Content

```markdown
# AGENTS.md — HOTL Operating Model

This project follows the Human-on-the-Loop (HOTL) development model.

## How to Work

1. Before feature work: brainstorm with intent/verification/governance contracts
2. Create a `hotl-workflow-<slug>.md` with steps, loop conditions, and gates
3. Execute steps autonomously within guardrails
4. Pause at `gate: human` for high-risk steps

## Risk Levels

- **low/medium + auto_approve: true:** Execute autonomously, auto-approve gates
- **high:** Always pause for human review at gates

## Always Requires Human Review

- Auth/authz changes
- Encryption or key management
- Privacy-critical logic (PII, consent, deletion)
- Billing or financial logic
- Broad access control changes

## Workflow Format

See `hotl-workflow-*.md` in project root or `workflows/` in the plugin for templates.
```
