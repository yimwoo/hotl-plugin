## HOTL Operating Model

The Human-on-the-Loop (HOTL) model applies to **implementation tasks** — new features, refactors, and significant changes. Not every task needs the full workflow. Route tasks by type.

### Task-Type Routing

**Determine the task type FIRST, before doing anything else.**

| Task type | Examples | What to do |
|---|---|---|
| **Code understanding** | "where does this error come from?", "how does this function work?", "walk me through this flow", "what does this error mean?" | Just answer. Read the code, trace the logic, explain. No HOTL workflow needed. |
| **Quick fix** | Typo, config value, import path, one-line correction — the fix is obvious and low-risk | Just fix it, verify the change works, report back. No brainstorm or plan. |
| **Debugging** | "debug this", "investigate", "why is this failing?", error message pasted | Use systematic debugging (`hotl-debugging.md`). No brainstorm or plan needed. |
| **Implementation** | "build", "add", "implement", "design", "refactor", new feature, significant change | Full HOTL workflow: Brainstorm → Plan → Execute → Verify |

**Quick fix boundary:** A quick fix is an obvious low-risk edit where the change is self-evident. If the cause is ambiguous or the fix could have side effects, route to debugging instead.

### The HOTL Workflow (implementation tasks only)

1. **Brainstorm** — explore intent, ask questions, propose approaches, define contracts
2. **Plan** — create `docs/plans/YYYY-MM-DD-<slug>-workflow.md` with atomic steps
3. **Execute** — run the plan step by step with verification
4. **Review** — a first-class lifecycle stage embedded in execution:
   - Executors invoke `requesting-code-review` at defined checkpoints (batch boundaries, pre-completion)
   - Findings are handled via `receiving-code-review` — verify claims, evaluate against contracts, then implement
   - Review happens after step verification, before completion, before finalize

**Do NOT skip steps for implementation tasks.** Do NOT jump from brainstorming to coding. Do NOT mark tasks complete without verification.

### Three Contracts (for implementation tasks)

Every implementation workflow MUST define all three:

1. **Intent contract** — objective, constraints, success criteria, risk level (low/medium/high)
2. **Verification contract** — how to confirm each step worked (test commands, checks, success signals)
3. **Governance contract** — approval gates, rollback strategy, ownership

### Risk Levels

- **low:** UI changes, new endpoints, non-critical features — auto-approve OK
- **medium:** Schema changes, refactors, performance work — caution
- **high:** Auth/authz, encryption, privacy, billing — ALWAYS pause for human approval. NEVER auto-approve.

### Skill Routing

When the user triggers a workflow, read the full skill file from disk for detailed instructions:

| Trigger phrase | Read this file |
|---|---|
| "explain", "where is", "how does", "walk me through", "what does this error mean" | No skill needed — just answer the question directly |
| "fix this typo", "update the config", obvious one-line correction | No skill needed — fix, verify, report back |
| "debug", "investigate", "why is this failing" | `__HOTL_HOME__/skills/systematic-debugging/SKILL.md` |
| "brainstorm", "design this", "let's think about" | `__HOTL_HOME__/skills/brainstorming/SKILL.md` |
| "plan", "write a plan", "create workflow" | `__HOTL_HOME__/skills/writing-plans/SKILL.md` |
| "execute", "run the plan", "implement" | `__HOTL_HOME__/skills/governed-execution/SKILL.md` (preferred) or `__HOTL_HOME__/skills/executing-plans/SKILL.md` |
| "loop", "run autonomously" | `__HOTL_HOME__/skills/loop-execution/SKILL.md` |
| "tdd", "test first", "red green refactor" | `__HOTL_HOME__/skills/tdd/SKILL.md` |
| "review", "code review" | `__HOTL_HOME__/skills/code-review/SKILL.md` |

### Workflow Files

Workflow files are saved as `docs/plans/YYYY-MM-DD-<slug>-workflow.md`. Legacy root files such as `hotl-workflow-<slug>.md` remain readable during migration, but new writes should use `docs/plans/`. Each step includes:
- `action` — what to do
- `loop` — false or "until [condition]"
- `verify` — command or typed verification block to confirm success
- `gate` — human or auto approval

### Task Completion Rules

**NEVER mark a task as "Task Completed" unless:**
- All planned steps have been executed
- All verify commands have been run and passed
- All success criteria from the intent contract are met
- Evidence of completion is shown (test output, command output, etc.)
