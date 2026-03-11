# HOTL — Human-on-the-Loop AI Development

**Structured guardrails for AI coding tools.** HOTL ensures every AI-generated change goes through design, planning, review, and verification — so nothing lands on `main` without evidence it works.

Works with **Claude Code**, **Codex**, and **Cline**. Adapters available for Cursor and GitHub Copilot.

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

HOTL prevents all four by enforcing one workflow for every change.

---

## The HOTL Workflow

Every task follows six phases. No shortcuts, no skipping.

| Phase | What happens |
| --- | --- |
| **Brainstorm** | Clarify requirements. Compare approaches. Define intent, verification, and governance contracts. |
| **Plan** | Generate a `hotl-workflow-<slug>.md` with steps, verify commands, loop conditions, and gates. |
| **Review** | Lint the plan structure. AI-review the plan quality. Hard-block on failures. |
| **Branch** | Create an isolated git branch (`hotl/<slug>` by default). Dirty repos hard-fail. |
| **Execute** | Run the plan — choose loop (autonomous), manual (checkpoints), or subagent (delegated) mode. |
| **Verify** | Run tests, lint, and verify commands. Check success criteria against actual output. No green light without proof. |

For a deep dive into each phase, see [How HOTL Works](docs/how-it-works.md).

---

## Commands and Skills

### Claude Code Commands

| Command | What it does |
| --- | --- |
| `/hotl:brainstorm` | Design the change before coding |
| `/hotl:write-plan` | Create a `hotl-workflow-<slug>.md` |
| `/hotl:loop` | Run the workflow with autonomous loop execution |
| `/hotl:execute-plan` | Run the workflow with manual checkpoints |
| `/hotl:subagent-execute` | Run the workflow with delegated subagent execution |
| `/hotl:setup` | Generate adapter files for other tools |

### Codex Skills

`hotl:brainstorming` · `hotl:writing-plans` · `hotl:document-review` · `hotl:loop-execution` · `hotl:executing-plans` · `hotl:subagent-execution` · `hotl:tdd` · `hotl:systematic-debugging`

### Cline Rules

Brainstorming · Planning · Execution · Subagent execution · TDD · Debugging · Code review

---

## Example

```text
You:   Help me add rate limiting to this FastAPI app

HOTL:  Brainstorm  → clarify requirements, compare approaches, write contracts
       Plan        → create hotl-workflow-add-rate-limiter.md
       Review      → lint structure, review plan quality
       Branch      → create hotl/add-rate-limiter
       Execute     → choose loop, manual, or subagent mode
       Verify      → run tests and success checks before marking done
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

---

## Contributing

Run the smoke tests:

```bash
bats test/smoke.bats
```

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
