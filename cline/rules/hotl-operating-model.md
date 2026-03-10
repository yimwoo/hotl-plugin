## HOTL Operating Model

Follow the Human-on-the-Loop (HOTL) operating model for ALL development work.

### CRITICAL RULE

**NEVER start coding without a design.** When the user asks to build something, your FIRST action is brainstorming — not coding. You MUST follow the brainstorming process in `hotl-brainstorming.md` before writing any implementation code.

### The HOTL Workflow (follow this order)

1. **Brainstorm** — explore intent, ask questions, propose approaches, define contracts
2. **Plan** — create a `hotl-workflow-<slug>.md` with atomic steps
3. **Execute** — run the plan step by step with verification
4. **Review** — verify all success criteria are met before claiming done

**Do NOT skip steps.** Do NOT jump from brainstorming to coding. Do NOT mark tasks complete without verification.

### Three Contracts (ALL REQUIRED)

Every workflow MUST define all three:

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
| "brainstorm", "design this", "let's think about" | `~/.cline/hotl/skills/brainstorming/SKILL.md` |
| "plan", "write a plan", "create workflow" | `~/.cline/hotl/skills/writing-plans/SKILL.md` |
| "execute", "run the plan", "implement" | `~/.cline/hotl/skills/executing-plans/SKILL.md` |
| "loop", "run autonomously" | `~/.cline/hotl/skills/loop-execution/SKILL.md` |
| "tdd", "test first", "red green refactor" | `~/.cline/hotl/skills/tdd/SKILL.md` |
| "debug", "investigate", "why is this failing" | `~/.cline/hotl/skills/systematic-debugging/SKILL.md` |
| "review", "code review" | `~/.cline/hotl/skills/code-review/SKILL.md` |

**How to use:** When a trigger phrase matches, read the referenced file and follow the process described in it. If the file is not found, follow the condensed version in the corresponding `.clinerules/hotl-*.md` rule file.

### Workflow Files

Plans are saved as `hotl-workflow-<slug>.md` in the project root. Each step includes:
- `action` — what to do
- `loop` — false or "until [condition]"
- `verify` — command to confirm success
- `gate` — human or auto approval

### Task Completion Rules

**NEVER mark a task as "Task Completed" unless:**
- All planned steps have been executed
- All verify commands have been run and passed
- All success criteria from the intent contract are met
- Evidence of completion is shown (test output, command output, etc.)
