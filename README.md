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

One script updates both Claude Code and Cline (whichever is installed):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh)
```

Or if already cloned:

```bash
bash ~/.claude/plugins/hotl/update.sh
# or
bash ~/.cline/hotl/update.sh
```

This pulls the latest code, refreshes the Claude Code plugin cache, and syncs Cline global rules — all automatically.

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

**Example — adding a rate limiter to a Python FastAPI service:**

```text
→ Step 1: Write failing test for rate limit middleware
✓ Step 1: Write failing test (1 iteration)

→ Step 2: Implement rate limiter middleware
✗ Step 2: pytest — 2 of 3 tests failing (missing Redis connection)
↻ Retrying (1/3)... added Redis mock
✗ Step 2: pytest — 1 test still failing (off-by-one in window calc)
↻ Retrying (2/3)... fixed sliding window logic
✓ Step 2: Implement rate limiter (3 iterations, all tests pass)

→ Step 3: Fix lint errors
✗ Step 3: ruff check — 4 violations (unused import, line length)
↻ Retrying (1/3)... applied ruff fixes
✓ Step 3: Fix lint errors (2 iterations)

→ Step 4: Add integration test with TestClient
✓ Step 4: Add integration test (1 iteration)

→ Step 5: Run full test suite
✓ Step 5: Full test suite — 47 passed, 0 failed (1 iteration)

→ Step 6: Review rate limit config
⏸ [HUMAN GATE] Rate limit thresholds set to 100 req/min.
  Security-sensitive: controls API abuse protection.
  Approve? (yes/no/show-details)
  → Human approved with note: "lower to 60 req/min for /auth endpoints"
✓ Step 6: Config review (1 iteration, human-approved)

→ Step 7: Build and verify Docker image
✓ Step 7: Docker build + health check passed (1 iteration)
```

**Execution summary:**

| Step | Status | Iterations |
| --- | --- | --- |
| 1. Write failing test | done | 1 |
| 2. Implement rate limiter | done | 3 (Redis mock + window fix) |
| 3. Fix lint errors | done | 2 (ruff auto-fix) |
| 4. Integration test | done | 1 |
| 5. Full test suite | done | 1 |
| 6. Review rate limit config | done | 1 (human gate) |
| 7. Build Docker image | done | 1 |

Steps that fail verification retry automatically (up to `max_iterations`). High-risk gates always pause for human approval regardless of `auto_approve` setting.

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
