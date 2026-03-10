# HOTL Plugin — Human-on-the-Loop AI Development for Claude Code, Cline, Cursor, Codex

Stop AI from blindly writing code. HOTL (Human-on-the-Loop) enforces structured workflows — brainstorm before coding, plan before implementing, verify before claiming done. Works with Claude Code, Cline (with Oracle Code Assist, OpenAI, Anthropic, or any provider), Cursor, Codex, and GitHub Copilot.

## Why HOTL

AI coding assistants jump straight to implementation. HOTL adds guardrails:

- **Brainstorm first** — define intent, constraints, and success criteria before any code
- **Plan before coding** — atomic steps with verification commands and approval gates
- **Loop execution** — AI retries steps until success criteria are met, not just once
- **Risk-aware** — low-risk gates auto-approve; high-risk gates (auth, encryption, billing) always pause for human review
- **Multi-tool** — same workflow across Claude Code, Cline, Cursor, Codex, and Copilot
- **Offline** — no external dependencies, works on corporate networks

## Quick Start

### Claude Code

```text
/plugin marketplace add yimwoo/hotl-plugin
/plugin install hotl@hotl-plugin
```

Then use `/hotl:brainstorm`, `/hotl:write-plan`, `/hotl:loop`, etc.

### Cline (VS Code)

Works with any API provider — Oracle Code Assist (OCA), OpenAI, Anthropic, Google, etc.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh)
```

This one command does everything:

1. Installs HOTL skills to `~/.cline/hotl/` (full skill files for on-demand reading)
2. Copies HOTL rules to `~/Documents/Cline/Rules/` (Cline's global rules directory)

**Rules apply to all projects automatically.** No per-project setup. No settings to paste.

After installing, just tell Cline what you need in natural language:

```text
"brainstorm this feature"       → design with HOTL contracts before coding
"plan the implementation"       → create a step-by-step workflow file
"execute the plan"              → run the workflow with checkpoints
"use TDD"                       → RED-GREEN-REFACTOR cycle
"debug this"                    → systematic 4-phase debugging
"review the code"               → checklist-based code review
```

Detailed docs: [docs/README.cline.md](docs/README.cline.md)

### Cursor

In Cursor Agent chat:

```text
/plugin-add hotl
```

### Codex

Tell Codex:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.codex/INSTALL.md
```

Detailed docs: [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.opencode/INSTALL.md
```

### Manual (git clone)

```bash
git clone https://github.com/yimwoo/hotl-plugin
cd hotl-plugin && bash install.sh
```

## Update

```bash
# Claude Code
cd ~/.claude/plugins/hotl && git pull

# Cline
cd ~/.cline/hotl && git pull && bash install-cline.sh
```

---

## How It Works

### The Workflow

```text
brainstorm  →  design doc with intent/verification/governance contracts
write-plan  →  hotl-workflow-<slug>.md with atomic steps and gates
loop/execute →  autonomous or checkpoint-based execution with verification
```

### Three Contracts

Every HOTL workflow defines:

1. **Intent contract** — objective, constraints, success criteria, risk level
2. **Verification contract** — test commands, checks, success signals for each step
3. **Governance contract** — approval gates, rollback strategy, ownership

### Risk Levels

| Level | Examples | Behavior |
| --- | --- | --- |
| **low** | UI changes, new endpoints, non-critical features | Auto-approve gates |
| **medium** | Schema changes, refactors, performance work | Proceed with caution |
| **high** | Auth, encryption, privacy, billing | Always pauses for human approval |

---

## Usage (Claude Code)

### Brainstorm a feature

Before writing any code, design with intent, verification, and governance contracts:

```text
/hotl:brainstorm
```

Scans `docs/plans/` for existing design docs. Asks about your objective, constraints, and success criteria. Produces a design doc with three HOTL contracts before any implementation begins.

### Write a plan

After design approval, convert the design doc into a step-by-step execution plan:

```text
/hotl:write-plan
```

Produces a `hotl-workflow-<slug>.md` with bite-sized tasks, verify commands, loop definitions, and approval gates.

### Loop execute (autonomous)

Execute the workflow file with loop execution and auto-approve for low-risk steps:

```text
/hotl:loop
```

Reads each step, executes it, verifies success criteria, and loops until done. High-risk gates always pause.

**Example output — real execution of adding a document review system:**

```text
→ Step 1: Create scripts directory
✓ Step 1: Create scripts directory (1 iteration)

→ Step 2: Write document-lint.sh
✓ Step 2: Write document-lint.sh (1 iteration)

→ Step 3: Test lint on valid design doc
✓ Step 3: Test lint on valid design doc (1 iteration)

→ Step 5: Add workflow validation
✗ Step 5: False positive — action text matched loop pattern
↻ Retrying (1/3)... fixed grep anchors
✓ Step 5: Add workflow validation (2 iterations)

→ Step 7: Test lint on broken workflow
✓ Step 7: Lint caught 6 errors — FAIL as expected (1 iteration)

→ Step 8: Write document-review skill
✓ Step 8: Write document-review skill (1 iteration)

→ Step 12: Run smoke tests
✓ Step 12: Run smoke tests (1 iteration)
```

**Execution summary table:**

| Step | Status | Iterations |
| --- | --- | --- |
| 1. Create scripts directory | done | 1 |
| 2. Write document-lint.sh | done | 1 |
| 3. Test lint on valid design doc | done | 1 |
| 4. Test lint on broken design doc | done | 1 |
| 5. Add workflow validation | done | 2 (fixed false positive) |
| 6. Test lint on valid workflow | done | 1 |
| 7. Test lint on broken workflow | done | 1 |
| 8. Write document-review skill | done | 1 |
| 9. Update skill index | done | 1 |
| 10. Write Cline rule file | done | 1 |
| 11. Checkbox progress tracking | done | 1 |
| 12. Run smoke tests | done | 1 |
| 13. End-to-end lint test | done | 1 |

Steps that fail verification are retried automatically (up to `max_iterations`). High-risk gates always pause for human approval regardless of `auto_approve` setting.

### Linear execute (with checkpoints)

```text
/hotl:execute-plan
```

Executes 3 steps at a time with an explicit human checkpoint between each batch.

### Parallel agents

```text
/hotl:dispatch
```

Dispatches 2+ independent tasks to sub-agents running in parallel.

### Setup for your team

```text
/hotl:setup
```

Generates adapter config files for Codex, Cline, Cursor, or GitHub Copilot.

---

## Commands Reference

| Command | Purpose |
| --- | --- |
| `/hotl:brainstorm` | Design a feature with HOTL contracts before writing code |
| `/hotl:write-plan` | Create a `hotl-workflow-<slug>.md` plan |
| `/hotl:loop` | Execute a workflow file with loop execution + auto-approve |
| `/hotl:execute-plan` | Linear execution with explicit checkpoints |
| `/hotl:dispatch` | Dispatch parallel sub-agents for independent tasks |
| `/hotl:setup` | Generate adapter files for your team's tools |

## Skills Reference

| Skill | Description |
| --- | --- |
| `hotl:brainstorming` | Design-first with HOTL contracts |
| `hotl:writing-plans` | Produces `hotl-workflow-<slug>.md` |
| `hotl:loop-execution` | Loop execution with auto-approve |
| `hotl:executing-plans` | Linear execution with checkpoints |
| `hotl:dispatch-agents` | Parallel sub-agent execution |
| `hotl:tdd` | RED-GREEN-REFACTOR cycle |
| `hotl:systematic-debugging` | 4-phase root cause process |
| `hotl:code-review` | BLOCK/WARN/NOTE review against plan |
| `hotl:verification-before-completion` | Evidence before claiming done |
| `hotl:setup-project` | Generate multi-tool adapter files |

## Multi-Tool Support

Run `/hotl:setup` to generate config files for your team's tools:

- **Claude Code:** Plugin with skills, commands, and hooks
- **Cline:** Global rules in `~/Documents/Cline/Rules/`
- **Codex:** `AGENTS.md`
- **Cursor:** `.cursor/rules/hotl.md`
- **GitHub Copilot:** `.github/copilot-instructions.md`

---

## Contributing

Contributions are welcome.

To contribute:

1. Fork the repo: [github.com/yimwoo/hotl-plugin](https://github.com/yimwoo/hotl-plugin)
2. Create a branch for your change
3. Run `bash scripts/dev-setup.sh` to install the pre-push smoke test hook
4. Submit a pull request with a clear description of what you changed and why
5. For new skills, follow the existing skill format and include a usage example

Workspace artifacts generated while developing the plugin (`hotl-workflow-*.md`, `docs/plans/`, `CLAUDE.md`) are gitignored and should not be committed.

### Running Tests

```bash
bats test/smoke.bats
```

The smoke suite validates JSON files, the session-start hook output, skill and command file integrity, and hook executability. It runs automatically before every push once you've run `dev-setup.sh`. CI also runs it on every push and PR to `main`.

Bug reports and feature requests: open an issue at [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
