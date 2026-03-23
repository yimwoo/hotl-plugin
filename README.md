# HOTL — Human-on-the-Loop AI Development

**Structured guardrails for AI coding tools.** HOTL ensures every AI-generated change goes through design, planning, review, and verification — so nothing lands on `main` without evidence it works.

Works with **Claude Code**, **Codex**, and **Cline**. Adapters available for Cursor and GitHub Copilot.

## Table of Contents

- [Why HOTL](#why-hotl)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [When To Use It](#smart-task-routing)
- [Commands & Usage](#commands--usage)
- [Skills Overview](#skills-overview)
- [Updating](#updating)
- [Supported Tools](#supported-tools)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)

## Why HOTL

Most AI coding sessions fail in predictable ways: code starts before requirements are clear, plans skip verification, risky changes execute without review, and the agent claims success without evidence.

HOTL prevents all four by enforcing structured workflows for implementation tasks while staying out of the way for code questions, quick fixes, and debugging.

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

Restart Codex after install. Full guide: [`.codex/INSTALL.md`](.codex/INSTALL.md)

`~/.codex/hotl` is the HOTL stable channel and should track `origin/main`. Codex discovers HOTL skills from `~/.agents/skills/hotl`.

### Cline

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh | bash
```

Full guide: [`docs/README.cline.md`](docs/README.cline.md)

## How It Works

Implementation tasks follow seven phases:

| Phase | What happens |
| --- | --- |
| **Brainstorm** | Clarify requirements. Compare approaches. Define intent, verification, and governance contracts. |
| **Plan** | Generate a `hotl-workflow-<slug>.md` with steps, verification, loop conditions, and gates. |
| **Lint** | Self-check built into planning. Structural lint runs automatically in execution preflight. |
| **Branch** | Create an isolated git branch. Dirty repos hard-fail. |
| **Execute** | Run the plan in loop, manual, or subagent mode. |
| **Review** | Review findings are checked against the codebase and HOTL contracts before acting. |
| **Verify** | Run tests, lint, and verify commands. No green light without proof. |

Here is what a real HOTL feature-delivery session can look like:

```text
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

Every step has a verify command. If verification fails, execution stops and reports instead of silently claiming success.

**Resumable execution:** HOTL persists state in `.hotl/state/` so interrupted runs can pick up where they stopped. Resume is verify-first: HOTL re-checks the last step before advancing. For the deeper execution model, see [`docs/how-it-works.md`](docs/how-it-works.md) and [`docs/workflow-format.md`](docs/workflow-format.md).

## Smart Task Routing

HOTL does not force ceremony on every task. It routes by intent:

| What you're doing | What HOTL does |
| --- | --- |
| Asking a question ("how does this work?") | Just answers — no workflow |
| Quick fix (typo, config, one-liner) | Fixes it, verifies, reports back |
| Debugging ("why is this failing?") | Structured debugging — no brainstorm needed |
| Building something new | Full workflow: brainstorm, plan, execute, verify |

## Commands & Usage

### Claude Code

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

### Codex

There is no `/hotl:brainstorm` or `/hotl:pr-review` syntax in Codex. Instead, describe the task in natural language and let HOTL route it, or mention a skill explicitly with `$brainstorming`, `$writing-plans`, or `$pr-reviewing`. For setup and prompt examples, see [`.codex/INSTALL.md`](.codex/INSTALL.md) and [`docs/README.codex.md`](docs/README.codex.md).

## Skills Overview

| Category | Skills | What they do |
| --- | --- | --- |
| Design & Planning | `brainstorming`, `writing-plans`, `document-review` | Clarify requirements, define contracts, and create executable workflow plans |
| Execution | `loop-execution`, `executing-plans`, `subagent-execution`, `resuming`, `dispatch-agents` | Run workflows with verification, retries, persistence, and delegation |
| Quality & Review | `pr-reviewing`, `code-review`, `requesting-code-review`, `receiving-code-review`, `verification-before-completion` | Review changes and require evidence before completion |
| Dev Practices | `tdd`, `systematic-debugging` | Apply test-first development and structured debugging workflows |
| Setup | `setup-project`, `using-hotl` | Generate adapter files and establish HOTL operating context |

For detailed descriptions and phase mappings, see the [full skills reference](docs/skills.md).

Want to create or modify HOTL skills? See [Authoring Skills vs Agents](docs/authoring-skills-vs-agents.md).

## Updating

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Covers Claude Code, Codex, and Cline, and skips tools that are not installed. In Claude Code, you can also run `/hotl:check-update`. For backup behavior, manual checks, and `--force-codex`, see [Updating HOTL](docs/updating.md).

## Supported Tools

| Tool | Integration |
| --- | --- |
| Claude Code | Plugin — commands, skills, and hooks |
| Codex | Native skill discovery |
| Cline | Global rules + local skill files |
| Cursor | Adapter templates via `/hotl:setup` |
| GitHub Copilot | Adapter templates via `/hotl:setup` |

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
