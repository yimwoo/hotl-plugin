# HOTL — Human-on-the-Loop AI Development

**Structured guardrails for AI coding tools.** HOTL ensures every AI-generated change goes through design, planning, review, and verification — so nothing lands on `main` without evidence it works.

Works with **Claude Code**, **Codex**, and **Cline**. Adapters available for Cursor and GitHub Copilot.

---

## What You Get

Here's what a real HOTL session looks like — 12 steps executed autonomously, all verified:

```
Execution Summary

| Step                                    | Status          | Iterations |
|-----------------------------------------|-----------------|------------|
| Step 1: Update workflow format spec     | Done            | 1          |
| Step 2: Add test fixtures               | Done            | 1          |
| Step 3: Update lint script              | Done            | 1          |
| Step 4: Add smoke tests                 | Done (34/34)    | 1          |
| Step 5: Update loop-execution           | Done            | 1          |
| Step 6: Update executing-plans          | Done            | 1          |
| Step 7: Update subagent-execution       | Done            | 1          |
| Step 8: Update writing-plans            | Done            | 1          |
| Step 9: Update Cline execution rule     | Done            | 1          |
| Step 10: Update Cline planning rule     | Done            | 1          |
| Step 11: Run full smoke tests           | Done (34/34)    | 1          |
| Step 12: Human review                   | Auto-approved   | 1          |

12 files modified, 1 new fixture. All 34 smoke tests passing.
```

Every step has a verify command. Every verify runs before the step is marked done. If a step fails, execution stops and reports — no silent failures.

---

## Quick Start

### Claude Code

```text
/plugin marketplace add yimwoo/hotl-plugin
/plugin install hotl@hotl-plugin
```

### Codex

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.codex/hotl
mkdir -p ~/.agents/skills && ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
```

Then restart Codex. Full instructions: [`.codex/INSTALL.md`](.codex/INSTALL.md)

`~/.codex/hotl` is the HOTL stable channel and should track `origin/main`.
Codex discovers skills from `~/.agents/skills/hotl`. Ask Codex to use `hotl:brainstorming`, `hotl:writing-plans`, or another HOTL skill in plain English.

### Cline

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh | bash
```

Full instructions: [`docs/README.cline.md`](docs/README.cline.md)

### Manual Install (Claude Code)

```bash
git clone https://github.com/yimwoo/hotl-plugin && cd hotl-plugin && bash install.sh
```

---

## Why HOTL

Most AI coding sessions fail in predictable ways: code starts before requirements are clear, plans skip verification, risky changes execute without review, and the agent claims success without evidence.

HOTL prevents all four by enforcing structured workflows for implementation tasks — while staying out of the way for code questions, quick fixes, and debugging.

---

## Smart Task Routing

HOTL doesn't force ceremony on every task. It routes by intent:

| What you're doing | What HOTL does |
| --- | --- |
| Asking a question ("how does this work?") | Just answers — no workflow |
| Quick fix (typo, config, one-liner) | Fixes it, verifies, reports back |
| Debugging ("why is this failing?") | Structured debugging — no brainstorm needed |
| Building something new | Full workflow: brainstorm, plan, execute, verify |

---

## The HOTL Workflow

Implementation tasks (new features, refactors, significant changes) follow six phases:

| Phase | What happens |
| --- | --- |
| **Brainstorm** | Clarify requirements. Compare approaches. Define intent, verification, and governance contracts. |
| **Plan** | Generate a `hotl-workflow-<slug>.md` with steps, typed verification, loop conditions, and gates. |
| **Review** | Self-check built into planning. Structural lint runs automatically in execution preflight. |
| **Branch** | Create an isolated git branch (`hotl/<slug>` by default). Dirty repos hard-fail. |
| **Execute** | Run the plan — choose loop (autonomous), manual (checkpoints), or subagent (delegated) mode. |
| **Verify** | Run tests, lint, and verify commands. Check success criteria against actual output. No green light without proof. |

For a deep dive into each phase, see [How HOTL Works](docs/how-it-works.md).

---

## Resumable Execution

Session crashed? Laptop died? HOTL remembers where you left off.

HOTL persists execution state in `.hotl/state/<run-id>.json` so interrupted runs can be picked up exactly where they stopped:

```text
You:   /hotl:resume hotl-workflow-add-auth.md

HOTL:  Found interrupted run: add-auth-1710700000
       Progress: step 5/8, branch: hotl/add-auth, started 2h ago

       Running verify on Step 5...
       Verify PASSED — step already succeeded before the crash.
       Advancing to Step 6.

       → Step 6: Update API docs
```

- **`/hotl:resume`** — explicitly resume by workflow name or run ID
- **Auto-detect** — `/hotl:loop` detects interrupted runs and asks: "Resume from step 5, or start fresh?"
- **Verify-first** — re-runs the last step's verification before deciding whether to redo or advance
- **Crash-safe** — sidecar state file is the source of truth; workflow checkboxes are repaired on resume

Add `.hotl/` to your project's `.gitignore` — execution state is local.

---

## Typed Verification

Every step can specify exactly how to verify success — not just shell commands:

```yaml
# Shell (default — scalar shorthand accepted)
verify: pytest tests/ -v

# Browser (capability-gated — falls back to human-review if unavailable)
verify:
  type: browser
  url: http://localhost:3000/dashboard
  check: priority badge renders with correct color

# Human review (always pauses, never auto-approved)
verify:
  type: human-review
  prompt: Check that priority colors match the approved design spec

# Artifact (structured assertions)
verify:
  type: artifact
  path: migrations
  assert:
    kind: matches-glob
    value: "*.sql"
```

Multiple checks per step are supported — all must pass. See [`docs/workflow-format.md`](docs/workflow-format.md) for the full schema.

---

## Commands

### Claude Code Slash Commands

| Command | What it does |
| --- | --- |
| `/hotl:brainstorm` | Design the change before coding |
| `/hotl:write-plan` | Create a `hotl-workflow-<slug>.md` |
| `/hotl:loop` | Run the workflow with autonomous loop execution |
| `/hotl:execute-plan` | Run the workflow with manual checkpoints |
| `/hotl:subagent-execute` | Run the workflow with delegated subagent execution |
| `/hotl:resume` | Resume an interrupted workflow run |
| `/hotl:pr-review` | Review a PR across multiple dimensions |
| `/hotl:setup` | Generate adapter files for other tools |

---

## How To Use HOTL In Codex

If you are using OpenAI Codex, invoke HOTL with normal prompts, not slash commands.

There is no `/hotl:brainstorm` or `/hotl:pr-review` syntax in Codex. Instead, ask Codex to use a HOTL skill by name, or describe the task and let Codex pick the right HOTL skill from the installed set.

### Codex Prompt Examples

```text
Use hotl:brainstorming to design this feature before writing code.

Use hotl:writing-plans to create a hotl-workflow file for adding OAuth login.

Use hotl:document-review on hotl-workflow-add-oauth.md before implementation.

Use hotl:pr-reviewing to review https://github.com/org/repo/pull/123.

Use hotl:code-review on the changes in this branch before merge.

Use HOTL for this task and choose the correct skill automatically.
```

### Claude Code vs Codex

| Tool | How you invoke HOTL |
| --- | --- |
| Claude Code | Slash commands such as `/hotl:brainstorm` or `/hotl:pr-review` |
| Codex | Natural-language prompts that name the skill, such as `Use hotl:brainstorming...` |

For a Codex-specific setup and usage guide, see [`.codex/INSTALL.md`](.codex/INSTALL.md) and [`docs/README.codex.md`](docs/README.codex.md).

---

## Skills

All skills work with **Claude Code** and **Codex**. Cline users get equivalent rules automatically.

### Design & Planning

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:brainstorming` | Explore intent, requirements, and design. Produces HOTL contracts (intent, verification, governance) before implementation. Prefers multiple-choice questions and includes a design-doc self-check. | Brainstorm |
| `hotl:writing-plans` | Create a `hotl-workflow-<slug>.md` implementation plan with typed verification (shell, browser, human-review, artifact), loop/gate definitions, and a built-in self-check loop. | Plan |
| `hotl:document-review` | Optional utility for reviewing existing docs, external specs, or hand-authored plans. Runs deterministic lint then AI-driven qualitative review. | Review |

### Execution

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:loop-execution` | The canonical HOTL execution engine — loops until success criteria met, auto-approves low-risk gates, pauses at high-risk gates. Persists state for resume. | Execute |
| `hotl:executing-plans` | Loop execution with explicit human checkpoints between batches of tasks. | Execute |
| `hotl:subagent-execution` | Delegated step runner over the loop execution engine — delegates eligible steps to fresh subagents while the controller keeps governance and verification. | Execute |
| `hotl:resuming` | Resume an interrupted workflow run — verify-first strategy with sidecar state persistence. | Execute |
| `hotl:dispatch-agents` | Run 2+ independent tasks in parallel with no shared state — dispatches parallel subagents for each task. | Execute |

### Quality & Review

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:pr-reviewing` | Review a PR across multiple dimensions — description/ticket, code changes, code scan, unit tests — using parallel subagents. Supports GitHub, GitLab, and enterprise platforms. | Review |
| `hotl:code-review` | Post-implementation review against the workflow plan and HOTL contracts. Checks plan alignment, code quality, and governance compliance. | Verify |
| `hotl:verification-before-completion` | Run verification commands and confirm output before claiming work is complete. Evidence before assertions. | Verify |

### Development Practices

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:tdd` | Enforce RED-GREEN-REFACTOR cycle before writing any implementation code. | Execute |
| `hotl:systematic-debugging` | Structured debugging workflow — reproduce, isolate, fix, verify. Use before proposing fixes for any bug or test failure. | Execute |

### Setup & Configuration

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:setup-project` | Generate adapter files for the current project — creates AGENTS.md, .clinerules, cursor rules, or copilot instructions depending on tools the team uses. | Setup |
| `hotl:using-hotl` | Auto-loaded on session start. Establishes the skill index and HOTL operating principles. | Setup |

---

## Example

```text
You:   Help me add rate limiting to this FastAPI app

HOTL:  Brainstorm  → clarify requirements, compare approaches, write contracts
       Plan        → create hotl-workflow-add-rate-limiter.md
       Branch      → create hotl/add-rate-limiter
       Execute     → 8 steps, all verified, 2 retries on step 4
       Verify      → pytest passing, lint clean, success criteria met
```

---

## Supported Tools

| Tool | Integration |
| --- | --- |
| Claude Code | Plugin — commands, skills, and hooks |
| Codex | Native skill discovery |
| Cline | Global rules + local skill files |
| Cursor | Adapter templates via `/hotl:setup` |
| GitHub Copilot | Adapter templates via `/hotl:setup` |

---

## Repository Structure

```text
skills/          HOTL skills (loaded by Skill tool or native discovery)
commands/        Claude Code slash command definitions
hooks/           SessionStart hook for Claude Code
workflows/       Workflow templates (feature, bugfix, refactor)
cline/rules/     Global rules for Cline
adapters/        Templates for AGENTS.md, Cursor, Copilot, and other tools
scripts/         Utility scripts including document-lint.sh
docs/            Setup docs, workflow format reference, and detailed guides
```

---

## Update

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Or from a local clone:

```bash
bash update.sh
```

Covers Claude Code, Codex, and Cline — skips any tool that isn't installed.
Restart Codex after updating so it re-discovers the latest skills.

---

## Contributing

Run the smoke tests:

```bash
bats test/smoke.bats
```

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
