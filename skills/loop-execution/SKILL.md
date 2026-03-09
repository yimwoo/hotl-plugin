---
name: loop-execution
description: Use when executing a hotl-workflow-*.md — reads steps, loops until success criteria met, auto-approves low-risk gates, pauses at high-risk gates.
---

# HOTL Loop Execution

## Overview

Execute a `hotl-workflow-<slug>.md` file autonomously. Loop on steps with success criteria. Auto-approve low-risk gates. Always pause for high-risk gates.

**Announce:** "Starting HOTL loop execution. Looking for workflow file..."

## Workflow File Resolution

Resolve which workflow file to execute:

1. If the user specified a filename (e.g., `/hotl:loop hotl-workflow-add-auth.md`) → use that file
2. Else, glob for `hotl-workflow*.md` in project root:
   - **One match** → use it automatically
   - **Multiple matches** → list them and ask the user to pick
   - **No matches** → see "What to Do If No Workflow Found" below

## Execution Algorithm

```
1. Resolve workflow file (see above)
2. Parse frontmatter: intent, risk_level, auto_approve
3. For each step in order:

   a. Announce: "→ Step N: [name]"

   b. Execute the action

   c. If loop: false
      → run verify command if present
      → if verify fails: STOP, report to human
      → continue to next step

   d. If loop: until [condition]
      → run verify command
      → if pass: log "✓ [condition] met", continue to next step
      → if fail AND iterations < max_iterations: log "↻ Retrying ([n]/[max])...", retry
      → if fail AND iterations = max_iterations: STOP
          Report: "Step N reached max iterations ([max]). [condition] not met."
          Show last verify output. Wait for human guidance.

   e. If gate: human
      → if auto_approve: true AND risk_level != high:
          log "⚡ Auto-approved: Step N gate (risk: [risk_level])"
          continue
      → else:
          PAUSE. Show summary of what was done in this step.
          Ask: "Gate reached at Step N. Continue? (yes/no/show-details)"
          Wait for human response before proceeding.

   f. If gate: auto
      → always continue, log "⚡ Auto-approved: Step N gate"

4. All steps complete:
   → Print summary table (step name | status | iterations used)
   → Invoke hotl:verification-before-completion skill
```

## Safety Rules

- `risk_level: high` in frontmatter **always** forces human approval at `gate: human` steps, even if `auto_approve: true`
- Never skip a `gate: human` on steps with security-sensitive keywords (auth, encrypt, secret, key, password, token, permission, role, billing)
- On STOP: always show the failing verify output so human can diagnose

## Reporting

After each step, log one line:
```
✓ Step 1: Write failing tests (1 iteration)
✓ Step 2: Implement auth logic (3 iterations, tests now pass)
⚡ Step 3: Security review gate (auto-approved, risk: low)
✓ Step 4: Update docs (1 iteration)
```

## What to Do If No Workflow Found

If no `hotl-workflow*.md` found in project root:
"No workflow file found. Would you like to:
1. Create one from a template (`/hotl:write-plan`)
2. Use a workflow template from the plugin (`workflows/feature.md`, `workflows/bugfix.md`, `workflows/refactor.md`)"
