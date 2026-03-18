## HOTL Document Review

**When to use:** Optional — for ad hoc review of existing docs, external specs, hand-authored plans, or non-HOTL documents. Not required in the standard HOTL plan-then-execute flow (writing-plans has a built-in self-check, and execution preflight runs structural lint automatically).

**Full skill:** Read `~/.cline/hotl/skills/document-review/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY — TWO PHASES, BOTH REQUIRED

You MUST run both phases in order. Do NOT skip Phase 1. Do NOT start execution until review completes.

### Phase 1: Structural Lint (Hard Gate)

Run the lint script:

```bash
bash ~/Documents/Cline/Scripts/document-lint.sh <file>
```

**If lint FAILS:** STOP. Show all errors. Author MUST fix structural issues. Do NOT proceed to Phase 2.

**If lint PASSES:** Continue to Phase 2.

**What lint checks for design docs (*-design.md):**
- Intent Contract with intent, constraints, success_criteria, risk_level
- Verification Contract with at least one verify step
- Governance Contract with approval_gates and rollback
- risk_level is low, medium, or high

**What lint checks for workflow files (hotl-workflow-*.md):**
- YAML frontmatter with intent, success_criteria, risk_level
- Every step has action and loop fields
- Every looped step has verify and max_iterations
- High-risk steps with security keywords have gate: human

### Phase 2: AI-Driven Review (Soft Gate)

Evaluate these judgment questions:

**For design docs:**
- Internal consistency — do contracts align with each other?
- YAGNI — anything overbuilt or speculative?
- Risk assessment — is risk_level appropriate?
- Success criteria — concrete and testable?
- Scope — crosses too many subsystems?

**For workflow files:**
- Step sizing — atomic (2-5 min) or too large?
- Verify coverage — do verify commands test what steps claim?
- Gate placement — risky steps missing gates?
- Loop safety — max_iterations reasonable?
- Ordering — logical dependencies?

### Review Outcomes

Output exactly one:

- **PASS** — ready for execution
- **REVISE** — list specific issues with suggestions, author fixes and re-submits
- **HUMAN_OVERRIDE_REQUIRED** — serious concerns, human must decide whether to proceed

### What You MUST NOT Do

- NEVER skip Phase 1 (lint) — structural validation is a hard gate
- NEVER proceed to execution if lint fails
- NEVER output PASS if you found real issues — be honest
- NEVER hide concerns — report everything, let the human decide
