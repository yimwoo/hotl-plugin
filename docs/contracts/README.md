# HOTL Output Contracts

This directory contains canonical output schemas for HOTL artifacts. Each contract defines what the output contains and means. Platform-specific rendering (how it surfaces) lives in platform docs or skill files.

## Vocabularies

HOTL uses three distinct vocabularies across its contracts. Do not conflate them.

**Severity** (for findings in reviews):
`BLOCK | WARN | NOTE` — the only finding-severity system in user-facing text. No other severity labels (P1/P2, priority numbers) may appear in prose.

**Verdict** (for task-specific outcomes — defined per contract):
- Review verdicts: `READY | READY WITH WARNINGS | NOT READY`, `PROCEED | PROCEED WITH WARNINGS | HOLD`, `APPROVE | REQUEST_CHANGES | COMMENT`
- Each contract specifies which verdict set applies to its context.

**Execution status** (for step and run states):
`done | failed | blocked | auto-approved | approved | running | pending | retrying | paused | completed` — these are status labels indicating step/run state, not severity levels.

## Conventions

These rules apply to all contracts in this directory.

1. **Semantics vs rendering.** Contracts define output semantics. Platform-specific rendering lives in platform docs (`docs/README.codex.md`, `cline/rules/`, etc.). Exception: final-artifact rendering tables belong in contracts because they define how the same durable artifact appears per platform.

2. **Severity vocabulary.** `BLOCK | WARN | NOTE` is the only finding-severity system. Consistent across all review contracts.

3. **Section ordering.** Contracts define a fixed section order. All sections are always present, even when empty or clean.

4. **Clean-report requirement.** When a section has no findings or issues, state what was checked and what was not covered. No silent omissions.

## Contracts

| Contract | Sections | Purpose |
|----------|----------|---------|
| [pr-review-output.md](pr-review-output.md) | 9 | PR review schema — metadata, dimension verdicts, consolidated findings |
| [code-review-output.md](code-review-output.md) | 6 | Code review schema — scope, dimensions, findings, coverage gaps, verdict |
| [execution-report-output.md](execution-report-output.md) | 5 | Execution report — metadata, summary table, event log, final summary, verification |
