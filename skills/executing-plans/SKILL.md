---
name: executing-plans
description: Use when executing an implementation plan linearly with explicit human checkpoints between batches of tasks.
---

# Executing Plans (Linear with Checkpoints)

Execute the plan in `hotl-workflow.md` or `docs/plans/*.md` task by task. Pause after every 3 tasks for human review.

## Process

1. Read the plan
2. Execute tasks in order, 3 at a time
3. After each batch: show what was done, ask "Continue to next batch?"
4. On failure: stop and report — never silently skip a failed step
5. When complete: invoke `hotl:verification-before-completion`

Use this over `loop-execution` when you want explicit human checkpoints at every stage rather than auto-approve.
