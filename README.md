# HOTL — Human-on-the-Loop AI Development for Claude Code, Cline, Cursor, Codex

Stop AI from blindly writing code. HOTL enforces structured workflows — brainstorm before coding, plan before implementing, verify before claiming done. One natural language request triggers the entire pipeline automatically.

Works with **Claude Code**, **Cline** (Oracle Code Assist, OpenAI, Anthropic, any provider), **Cursor**, **Codex**, and **GitHub Copilot**. No external dependencies. Works offline on corporate networks.

---

## Just Tell It What You Want

You don't call skills one by one. Describe what you need, and HOTL handles the workflow:

```text
You:  "Help me add user authentication to this FastAPI app"

HOTL: → Brainstorm: asks about auth method, session handling, security constraints
      → Design doc saved with intent/verification/governance contracts
      → Plan: creates hotl-workflow-add-auth.md with 9 atomic steps
      → Execute: writes tests first, implements, retries on failure, pauses at security gates
      → Review: verifies all tests pass, lint clean, contracts met
```

```text
You:  "Let's debug why the payment webhook is timing out"

HOTL: → Reproduce: finds minimal reproduction case
      → Understand: reads error logs, traces call path, checks recent commits
      → Hypothesize: forms 2 theories (connection pool exhaustion vs retry storm)
      → Fix + Verify: patches root cause, runs reproduction, full test suite passes
```

```text
You:  "Plan and build a rate limiter for our API"

HOTL: → Brainstorm: proposes sliding window vs token bucket vs fixed window
      → Design doc with contracts: 60 req/min default, Redis-backed, human gate on config
      → Plan: 7 steps from failing test to Docker build
      → Loop execute: retries automatically on test failures, pauses at security gate
```

HOTL picks the right skills based on what you say. No memorizing commands.

---

## Install

### Claude Code

```text
/plugin marketplace add yimwoo/hotl-plugin
/plugin install hotl@hotl-plugin
```

### Cline (VS Code)

Works with any API provider — Oracle Code Assist, OpenAI, Anthropic, Google, local models.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh)
```

Installs globally. Rules apply to all projects. No per-project setup.

Detailed docs: [docs/README.cline.md](docs/README.cline.md)

### Cursor

```text
/plugin-add hotl
```

### Codex

```text
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.codex/INSTALL.md
```

### Manual

```bash
git clone https://github.com/yimwoo/hotl-plugin
cd hotl-plugin && bash install.sh
```

### Update

One script updates all installed platforms:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh)
```

Pulls latest code, refreshes Claude Code plugin cache, syncs Cline global rules.

---

## End-to-End Workflow

Here's what happens when you say **"help me add rate limiting to our API"**:

### 1. Brainstorm

HOTL asks clarifying questions one at a time, proposes 2-3 approaches with trade-offs, then defines three contracts:

```yaml
# Intent Contract
intent: Add Redis-backed sliding window rate limiter to FastAPI service
constraints: Must not break existing auth middleware; no new external dependencies beyond Redis
success_criteria: Rate limiter returns 429 after threshold; configurable per-endpoint
risk_level: medium

# Verification Contract
verify_steps:
  - run tests: pytest tests/test_rate_limiter.py
  - check: 429 response after exceeding limit
  - confirm: existing test suite still passes

# Governance Contract
approval_gates: rate limit config review (security-sensitive)
rollback: revert rate limiter middleware registration
ownership: you
```

Design doc saved to `docs/plans/2026-03-10-rate-limiter-design.md`.

### 2. Plan

HOTL creates `hotl-workflow-add-rate-limiter.md` with atomic steps:

```yaml
---
intent: Add Redis-backed sliding window rate limiter to FastAPI service
success_criteria: 429 after threshold, configurable per-endpoint, all tests pass
risk_level: medium
auto_approve: true
---
```

Each step has an action, loop condition, verify command, and optional gate.

### 3. Execute

HOTL runs each step, retries on failure, pauses at gates:

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

### 4. Summary

| Step | Status | Iterations |
| --- | --- | --- |
| 1. Write failing test | done | 1 |
| 2. Implement rate limiter | done | 3 (Redis mock + window fix) |
| 3. Fix lint errors | done | 2 (ruff auto-fix) |
| 4. Integration test | done | 1 |
| 5. Full test suite | done | 1 |
| 6. Review rate limit config | done | 1 (human gate) |
| 7. Build Docker image | done | 1 |

Steps retry automatically on failure. High-risk gates always pause for human approval.

---

## How It Works

### Three Contracts

Every HOTL workflow defines:

1. **Intent contract** — what you're building, what must not break, how you know it's done
2. **Verification contract** — test commands and checks for each step
3. **Governance contract** — which steps need human approval, how to roll back

### Document Review

Before execution, HOTL validates your design docs and plans:

- **Structural lint** (`scripts/document-lint.sh`) — deterministic checks, runs in CI or locally
- **AI review** (`hotl:document-review`) — catches YAGNI violations, oversized steps, missing gates

Lint failures are hard blockers. AI review concerns can be human-overridden.

### Risk Levels

| Level | Examples | Behavior |
| --- | --- | --- |
| **low** | UI changes, new endpoints, non-critical features | Auto-approve gates |
| **medium** | Schema changes, refactors, performance work | Proceed with caution |
| **high** | Auth, encryption, privacy, billing | Always pauses for human approval |

---

## Skills Reference

HOTL automatically selects the right skill based on your request:

| Skill | Triggered by | What it does |
| --- | --- | --- |
| `hotl:brainstorming` | "brainstorm", "design this", "let's think about" | Explores intent, proposes approaches, defines three contracts |
| `hotl:writing-plans` | "plan this", "create a workflow" | Creates `hotl-workflow-<slug>.md` with atomic steps and gates |
| `hotl:loop-execution` | "execute", "run the plan", "loop" | Autonomous execution with retries and auto-approve |
| `hotl:executing-plans` | "execute with checkpoints" | Linear execution with human review every 3 steps |
| `hotl:document-review` | "review the design", "check the plan" | Two-phase review: structural lint + AI quality check |
| `hotl:tdd` | "use TDD", "test first" | RED-GREEN-REFACTOR cycle |
| `hotl:systematic-debugging` | "debug this", "why is this failing" | 4-phase: reproduce, understand, hypothesize, fix |
| `hotl:code-review` | "review the code" | Checklist review with BLOCK/WARN/NOTE severity |
| `hotl:dispatch-agents` | "run these in parallel" | Dispatches independent tasks to sub-agents |
| `hotl:verification-before-completion` | (automatic before claiming done) | Runs tests, linter, confirms behavior — evidence before assertions |
| `hotl:setup-project` | "set up HOTL for my team" | Generates adapter files for Codex, Cline, Cursor, Copilot |

### Commands (Claude Code)

| Command | Purpose |
| --- | --- |
| `/hotl:brainstorm` | Design a feature with HOTL contracts |
| `/hotl:write-plan` | Create an implementation plan |
| `/hotl:loop` | Autonomous execution with auto-approve |
| `/hotl:execute-plan` | Linear execution with checkpoints |
| `/hotl:dispatch` | Parallel sub-agent execution |
| `/hotl:setup` | Generate adapter files for your team |

---

## Multi-Tool Support

| Tool | How HOTL integrates |
| --- | --- |
| **Claude Code** | Plugin with skills, commands, and hooks — fully automatic |
| **Cline** | Global rules in `~/Documents/Cline/Rules/` — works with any API provider |
| **Cursor** | Plugin marketplace |
| **Codex** | `AGENTS.md` adapter |
| **GitHub Copilot** | `.github/copilot-instructions.md` |

Run `/hotl:setup` to generate the right config files for your team.

---

## Contributing

1. Fork the repo: [github.com/yimwoo/hotl-plugin](https://github.com/yimwoo/hotl-plugin)
2. Create a branch for your change
3. Run `bash scripts/dev-setup.sh` to install the pre-push smoke test hook
4. Submit a pull request

### Running Tests

```bash
bats test/smoke.bats
```

Validates JSON files, session-start hook output, skill and command file integrity, and hook executability. Runs automatically before every push and in CI.

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
