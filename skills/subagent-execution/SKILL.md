---
name: subagent-execution
description: Execute a reviewed hotl-workflow-*.md in the current session by delegating implementation-friendly steps to fresh subagents while the controller keeps governance, verification, and stop conditions.
---

# HOTL Subagent Execution

## Overview

Use this when you have a reviewed `hotl-workflow-*.md` and want same-session execution with fresh subagents per delegated step. This is a governed execution mode, not generic parallel dispatch.

**Core principle:** delegation is allowed; governance is not delegated.

## When to Use

- The workflow file already exists
- `hotl:document-review` has passed, or the human has explicitly overridden review concerns
- Steps are independent enough to hand to one worker at a time
- You want the controller to stay in this session and keep ownership of gates and verification

## Do Not Use When

- The plan has not been reviewed
- The workflow is structurally broken
- The work requires parallel edits to shared files
- The risky parts need direct controller execution throughout

## Required Preflight

1. Resolve the workflow file:
   - If the user specified a filename, use it
   - Else glob for `hotl-workflow-*.md` in the project root
   - If multiple exist, ask the user which one to execute
2. Read the full workflow
3. Run `hotl:document-review` on the workflow file before executing anything
4. Interpret the outcome:
   - `PASS` → continue
   - `REVISE` → stop; the workflow must be fixed first
   - `HUMAN_OVERRIDE_REQUIRED` → stop until the human explicitly says to proceed

## Execution Model

For each workflow step in order:

1. Announce the step
2. Decide whether the controller or a subagent should execute it
3. If delegated:
   - dispatch a fresh subagent with the full step text, the relevant files, and the success condition
   - do not make the subagent infer the plan from scratch if you can provide the step directly
   - answer clarifying questions before letting the subagent continue
4. Run the step's `verify` command in the controller session
5. Apply loop rules:
   - `loop: false` and verify fails → stop and report
   - `loop: until ...` and verify fails → retry up to `max_iterations`
6. Apply gate rules:
   - `gate: human` → controller pauses for human approval
   - `gate: auto` → continue
7. Mark the workflow checkbox complete only after verify passes

## Delegation Rules

Delegate by default:

- test-writing steps
- implementation steps
- localized documentation changes
- contained refactors

Keep controller-owned by default:

- human-gated steps
- security-sensitive decisions
- final verification and summaries
- any step whose failure would require architectural judgment

## Safety Rules

- Never skip document review
- Never run multiple implementation subagents in parallel against the same workflow
- Never let a subagent decide to bypass a human gate
- Never mark a step complete before the controller verifies it
- Never continue after repeated verify failure without surfacing the output

## Completion

After all steps pass:

1. Summarize completed steps and any retries
2. Invoke `hotl:verification-before-completion`
3. Only then claim the workflow is complete

## Related Skills

- `hotl:document-review` — required before subagent execution
- `hotl:verification-before-completion` — required before claiming done
- `hotl:dispatch-agents` — use for generic parallel independent tasks, not governed workflow execution
