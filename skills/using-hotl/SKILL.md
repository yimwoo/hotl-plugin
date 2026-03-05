---
name: using-hotl
description: Use when starting any conversation - establishes how to find and use HOTL skills, requiring Skill tool invocation before ANY response
---

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a HOTL skill might apply, you MUST invoke the skill.
This is not negotiable. This is not optional.
</EXTREMELY-IMPORTANT>

## Available HOTL Skills

Use the `Skill` tool to invoke any of these before responding:

| Skill | When to Use |
|---|---|
| `hotl:brainstorming` | Before any feature work — design with HOTL contracts |
| `hotl:writing-plans` | After design approval — produces `hotl-workflow.md` |
| `hotl:executing-plans` | Linear execution with human checkpoints |
| `hotl:loop-execution` | Execute a `hotl-workflow.md` with loops + auto-approve |
| `hotl:dispatch-agents` | 2+ independent tasks that can run in parallel |
| `hotl:tdd` | Before writing any implementation code |
| `hotl:systematic-debugging` | When encountering any bug or unexpected behavior |
| `hotl:code-review` | After completing implementation, before merging |
| `hotl:verification-before-completion` | Before claiming work is done |
| `hotl:setup-project` | To generate adapter files for Codex, Cline, Cursor, Copilot |

## Red Flags (You Are Rationalizing)

- "This is a simple task" → Check for skills anyway
- "I need context first" → Skill check comes BEFORE anything
- "I remember this skill" → Skills evolve. Invoke it fresh.

## HOTL Operating Principles

**Human-on-the-Loop:** Set intent + constraints upfront. AI executes autonomously within guardrails. Human reviews final output.

**Three contracts every workflow should define:**
1. **Intent contract:** objective, constraints, success criteria
2. **Verification contract:** how to confirm each step worked
3. **Governance contract:** approval gates, risk level, rollback strategy
