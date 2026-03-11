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

Codex uses the HOTL skill files from `~/.agents/skills/hotl`. Claude slash commands such as `/hotl:pr-review` do not exist in Codex.
There is no `/hotl:*` command syntax in Codex. Ask Codex to use `hotl:brainstorming`, `hotl:writing-plans`, `hotl:pr-review`, or another HOTL skill in plain English.

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

## Commands

### Claude Code Slash Commands

| Command | What it does |
| --- | --- |
| `/hotl:brainstorm` | Design the change before coding |
| `/hotl:write-plan` | Create a `hotl-workflow-<slug>.md` |
| `/hotl:loop` | Run the workflow with autonomous loop execution |
| `/hotl:execute-plan` | Run the workflow with manual checkpoints |
| `/hotl:subagent-execute` | Run the workflow with delegated subagent execution |
| `/hotl:pr-review` | Review a PR across multiple dimensions (description, code, scan, tests) |
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

Use hotl:pr-review to review https://github.com/org/repo/pull/123.

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
| `hotl:brainstorming` | Explore intent, requirements, and design. Produces HOTL contracts (intent, verification, governance) before implementation. | Brainstorm |
| `hotl:writing-plans` | Create a `hotl-workflow-<slug>.md` implementation plan with bite-sized tasks, exact file paths, and loop/gate definitions. | Plan |
| `hotl:document-review` | Review design specs and workflow plans before execution. Runs deterministic lint first, then AI-driven qualitative review. | Review |

### Execution

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:loop-execution` | Execute a `hotl-workflow-*.md` autonomously — loops until success criteria met, auto-approves low-risk gates, pauses at high-risk gates. | Execute |
| `hotl:executing-plans` | Execute an implementation plan linearly with explicit human checkpoints between batches of tasks. | Execute |
| `hotl:subagent-execution` | Execute a reviewed `hotl-workflow-*.md` by delegating steps to fresh subagents while the controller keeps governance and verification. | Execute |
| `hotl:dispatch-agents` | Run 2+ independent tasks in parallel with no shared state — dispatches parallel subagents for each task. | Execute |

### Quality & Review

| Skill | Description | Phase |
| --- | --- | --- |
| `hotl:pr-review` | Review a PR across multiple dimensions — description/ticket, code changes, code scan, unit tests — using parallel subagents. Supports GitHub, GitLab, and enterprise platforms. | Review |
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
Restart Codex after updating so it re-discovers the latest skills.

---

## Contributing

Run the smoke tests:

```bash
bats test/smoke.bats
```

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
