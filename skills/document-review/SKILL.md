---
name: document-review
description: Review design specs and workflow plans before execution — runs deterministic lint first, then AI-driven qualitative review. Use after brainstorming produces a design doc or after writing-plans produces a workflow file.
---

# HOTL Document Review

## Overview

Two-phase review of HOTL documents before execution. Phase 1 is a hard structural gate (lint). Phase 2 is an AI-driven qualitative review. Execution is blocked unless both phases pass or the human explicitly overrides.

**Announce:** "Running document review. Phase 1: structural lint..."

## Document Scope

- Design specs: `docs/plans/*-design.md`
- Workflow plans: `hotl-workflow-*.md`

## Phase 1: Structural Lint (Hard Gate)

Run the deterministic lint script:

```bash
bash scripts/document-lint.sh <file>
```

If the script is not found at `scripts/document-lint.sh`, check `~/.cline/hotl/scripts/document-lint.sh` or `~/.claude/plugins/hotl/scripts/document-lint.sh`.

**If lint FAILS:** STOP. Show all errors. The author MUST fix structural issues before AI review runs. Do not proceed.

**If lint PASSES:** Continue to Phase 2.

### What Lint Checks

**Design docs (*-design.md):**
- Intent Contract with intent, constraints, success_criteria, risk_level
- Verification Contract with at least one verify step
- Governance Contract with approval_gates and rollback
- risk_level is low, medium, or high

**Workflow files (hotl-workflow-*.md):**
- YAML frontmatter with intent, success_criteria, risk_level
- Every step has action and loop fields
- Every looped step (loop: until) has verify and max_iterations
- High-risk steps with security keywords have gate: human

## Phase 2: AI-Driven Review (Soft Gate)

Read the full document and evaluate these judgment questions:

### For Design Docs

1. **Internal consistency** — Do the three contracts align with each other? Does the verification contract actually test the intent?
2. **YAGNI** — Is anything speculative, overbuilt, or solving problems that don't exist yet?
3. **Risk assessment** — Is the risk_level appropriate? Are high-risk areas (auth, encryption, billing) correctly identified?
4. **Success criteria** — Are they concrete and testable, or vague?
5. **Scope** — Does this cross too many subsystems? Should it be decomposed?

### For Workflow Files

1. **Step sizing** — Are steps atomic (2-5 minutes each)? Flag steps that are too large or vague.
2. **Verify coverage** — Do verify commands actually test what the step claims to do?
3. **Gate placement** — Are human gates placed at the right points? Any risky steps missing gates?
4. **Loop safety** — Are max_iterations reasonable? Any infinite-loop risks?
5. **Ordering** — Do steps build on each other logically? Any missing dependencies?

## Review Outcomes

After completing both phases, output exactly one of:

### PASS
All structural and qualitative checks satisfied. Document is ready for execution.

```
REVIEW: PASS
Document: <filename>
Lint: PASSED
AI Review: No issues found.
Ready for execution.
```

### REVISE
Issues found that should be fixed before execution. List each issue with a specific suggestion.

```
REVIEW: REVISE
Document: <filename>
Lint: PASSED
AI Review: <N> issue(s) found.

Issues:
1. [ISSUE]: <description>
   Suggestion: <how to fix>
2. [ISSUE]: <description>
   Suggestion: <how to fix>

Fix these issues and re-run document review.
```

### HUMAN_OVERRIDE_REQUIRED
Serious concerns that the AI cannot resolve. Human must decide whether to proceed.

```
REVIEW: HUMAN_OVERRIDE_REQUIRED
Document: <filename>
Lint: PASSED
AI Review: Serious concern(s) requiring human judgment.

Concerns:
1. [CONCERN]: <description>
   Risk: <what could go wrong>