# HOTL — Human-on-the-Loop AI Development

**Structured guardrails for AI coding tools.** HOTL ensures every AI-generated change goes through design, planning, review, and verification — so nothing lands on `main` without evidence it works.

Works with **Claude Code**, **Codex**, and **Cline**. Adapters available for Cursor and GitHub Copilot.

---

## What You Get

Here's what a real HOTL feature-delivery session can look like — 12 steps executed with verification at every stop:

```
Execution Summary

| Step                                          | Status             | Iterations |
|-----------------------------------------------|--------------------|------------|
| Step 1: Add feature flag and config wiring    | Done               | 1          |
| Step 2: Add backend endpoint for saved views  | Done               | 2          |
| Step 3: Add database migration and model      | Done               | 1          |
| Step 4: Build saved views panel UI            | Done               | 3          |
| Step 5: Connect UI to API state flow          | Done               | 2          |
| Step 6: Add analytics + audit logging         | Done               | 1          |
| Step 7: Add unit tests for reducers/hooks     | Done (28/28)       | 2          |
| Step 8: Add API integration tests             | Done (12/12)       | 2          |
| Step 9: Add e2e coverage for create/apply     | Done (6/6)         | 3          |
| Step 10: Run lint and typecheck               | Done               | 2          |
| Step 11: Run full test suite                  | Done (46/46)       | 1          |
| Step 12: Human review and acceptance          | Approved           | 1          |

9 files modified, 1 migration added, 3 new test files. Unit, integration, and e2e suites all passing.
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
Codex discovers skills from `~/.agents/skills/hotl`. In Codex, you can either describe the task in natural language and let HOTL route it, or explicitly mention a skill such as `$brainstorming`. In the app UI, these may appear as title-cased names like `Brainstorming`.

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

### Update Notifications

HOTL can check for new versions automatically on session start where hook delivery is available.

- Claude Code: best-effort session-start notice
- Codex: treat update checks as manual for now; the current Codex integration is skills-based and does not guarantee a startup notice
- All platforms: manual explicit check is always available

Use the manual check when you want to verify the installed version:

```bash
bash update.sh --check
```

Or in Claude Code: `/hotl:check-update`

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

Implementation tasks (new features, refactors, significant changes) follow seven phases:

| Phase | What happens |
| --- | --- |
| **Brainstorm** | Clarify requirements. Compare approaches. Define intent, verification, and governance contracts. |
| **Plan** | Generate a `hotl-workflow-<slug>.md` with steps, typed verification, loop conditions, and gates. |
| **Lint** | Self-check built into planning. Structural lint runs automatically in execution preflight. |
| **Branch** | Create an isolated git branch (`hotl/<slug>` by default). Dirty repos hard-fail. |
| **Execute** | Run the plan — choose loop (autonomous), manual (checkpoints), or subagent (delegated) mode. |
| **Review** | Code review at executor checkpoints — findings verified against the codebase and HOTL contracts before acting. |
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
- **UI is advisory** — chat logs and Codex's native progress card should mirror execution, but `.hotl/state/*.json` and `.hotl/reports/*.md` are the canonical persisted record

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
| `/hotl:check-update` | Check if a newer HOTL version is available |
| `/hotl:setup` | Generate adapter files for other tools |

---

## How To Use HOTL In Codex

If you are using OpenAI Codex, invoke HOTL with normal prompts, not slash commands.

There is no `/hotl:brainstorm` or `/hotl:pr-review` syntax in Codex. Instead, either describe the task naturally and let Codex pick the right HOTL skill from the installed set, or explicitly mention the installed skill with a `$` prefix such as `$brainstorming`.

### Codex Prompt Examples

```text
Use $brainstorming to design this feature before writing code.

Please use HOTL to design this feature before writing code.

Use $writing-plans to create a hotl-workflow file for adding OAuth login.

Review hotl-workflow-add-oauth.md with HOTL before implementation.

Use $pr-reviewing to review https://github.com/org/repo/pull/123.

Run a HOTL code review on the changes in this branch before merge.

Use HOTL for this task and choose the correct skill automatically.
```

### Claude Code vs Codex

| Tool | How you invoke HOTL |
| --- | --- |
| Claude Code | Slash commands such as `/hotl:brainstorm` or `/hotl:pr-review` |
| Codex | Natural-language prompts or explicit skill mentions such as `Use HOTL to plan this` or `$brainstorming` |

For a Codex-specific setup and usage guide, see [`.codex/INSTALL.md`](.codex/INSTALL.md) and [`docs/README.codex.md`](docs/README.codex.md).

---

## Skills

All skills work with **Claude Code** and **Codex**. Cline users get equivalent rules automatically.

### Design & Planning

| Skill | Description | Phase |
| --- | --- | --- |
| `brainstorming` | Explore intent, requirements, and design. Produces HOTL contracts (intent, verification, governance) before implementation. Prefers multiple-choice questions and includes a design-doc self-check. | Brainstorm |
| `writing-plans` | Create a `hotl-workflow-<slug>.md` implementation plan with typed verification (shell, browser, human-review, artifact), loop/gate definitions, and a built-in self-check loop. | Plan |
| `document-review` | Optional utility for reviewing existing docs, external specs, or hand-authored plans. Runs deterministic lint then AI-driven qualitative review. | Review |

### Execution

| Skill | Description | Phase |
| --- | --- | --- |
| `loop-execution` | The canonical HOTL execution engine — mandatory live step visibility, platform-specific rendering (Codex: native progress card, Claude Code/Cline: chat logs + markdown table). Persists state for resume. | Execute |
| `executing-plans` | Loop execution with explicit human checkpoints between batches of tasks. | Execute |
| `subagent-execution` | Delegated step runner over the loop execution engine — delegates eligible steps to fresh subagents while the controller keeps governance and verification. | Execute |
| `resuming` | Resume an interrupted workflow run — verify-first strategy with sidecar state persistence. | Execute |
| `dispatch-agents` | Run 2+ independent tasks in parallel with no shared state — dispatches parallel subagents for each task. | Execute |

### Quality & Review

| Skill | Description | Phase |
| --- | --- | --- |
| `pr-reviewing` | Review a PR across multiple dimensions — description/ticket, code changes, code scan, unit tests — using parallel subagents. Supports GitHub, GitLab, and enterprise platforms. | Review |
| `requesting-code-review` | Dispatched by executors at review checkpoints — standardizes what context the reviewer receives (git range, contracts, verification evidence). | Review |
| `receiving-code-review` | Governs how agents handle review findings — verify each claim against the codebase and HOTL contracts before acting (Verify → Evaluate → Respond → Implement). | Review |
| `code-review` | Post-implementation review against the workflow plan and HOTL contracts. Checks plan alignment, code quality, and governance compliance. | Verify |
| `verification-before-completion` | Run verification commands and confirm output before claiming work is complete. Evidence before assertions. | Verify |

### Development Practices

| Skill | Description | Phase |
| --- | --- | --- |
| `tdd` | Enforce RED-GREEN-REFACTOR cycle before writing any implementation code. | Execute |
| `systematic-debugging` | Structured debugging workflow — reproduce, isolate, fix, verify. Use before proposing fixes for any bug or test failure. | Execute |

### Setup & Configuration

| Skill | Description | Phase |
| --- | --- | --- |
| `setup-project` | Generate adapter files for the current project — creates AGENTS.md, .clinerules, cursor rules, or copilot instructions depending on tools the team uses. | Setup |
| `using-hotl` | Auto-loaded on session start. Establishes the skill index and HOTL operating principles. | Setup |

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

## Contributing

Run the smoke tests:

```bash
bats test/smoke.bats
```

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
