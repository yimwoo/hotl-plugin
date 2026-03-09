---
name: executing-plans
description: Use when executing an implementation plan linearly with explicit human checkpoints between batches of tasks.
---

# Executing Plans (Linear with Checkpoints)

Execute the plan task by task. Pause after every 3 tasks for human review.

## Workflow File Resolution

Resolve which workflow file to execute:

1. If the user specified a filename → use that file
2. Else, glob for `hotl-workflow*.md` in project root:
   - **One match** → use it automatically
   - **Multiple matches** → list them and ask the user to pick
   - **No matches** → check `docs/plans/*.md` as fallback

## Process

1. Resolve and read the plan (see above)
2. Execute tasks in order, 3 at a time
3. After each batch: show what was done, ask "Continue to next batch?"
4. On failure: stop and report — never silently skip a failed step
5. When complete: invoke `hotl:verification-before-completion`

Use this over `loop-execution` when you want explicit human checkpoints at every stage rather than auto-approve.
