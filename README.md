# HOTL for Claude Code, Codex, and Cline

HOTL (Human-on-the-Loop) is a workflow plugin for AI coding tools. It adds guardrails so Claude Code, Codex, and Cline do not jump straight into implementation without design, planning, review, and verification.

If you want a Claude Code plugin, a Codex skill pack, or Cline workflow rules that enforce structured AI development, HOTL is built for that.

Works with:
- **Claude Code** via plugin skills, commands, and hooks
- **Codex** via native skill discovery
- **Cline** via global rules plus local skill files

It also includes adapters for Cursor and GitHub Copilot.

## Why Use HOTL

Most AI coding sessions fail in predictable ways:
- code starts before requirements are clear
- plans skip verification
- risky changes execute before review
- the agent claims success without evidence

HOTL fixes that with one enforced workflow:

1. **Brainstorm** the change before coding
2. **Write a plan** as a `hotl-workflow-<slug>.md`
3. **Review the document** before execution
4. **Branch** into an isolated git branch automatically
5. **Execute** with the right level of autonomy
6. **Verify** before claiming the work is done

## How HOTL Works

### 1. Brainstorm

HOTL asks clarifying questions, proposes options, and writes a design around three contracts:

- **Intent contract**: what you are building, constraints, success criteria, risk level
- **Verification contract**: what commands or checks prove the work is correct
- **Governance contract**: where human review is required and how to roll back

### 2. Plan

HOTL creates a workflow file in the project root:

```yaml
---
intent: Add Redis-backed sliding window rate limiter to FastAPI service
success_criteria: 429 after threshold, configurable per-endpoint, all tests pass
risk_level: medium
auto_approve: true
branch: feat/add-rate-limiter   # optional — defaults to hotl/<slug>
worktree: false                 # optional — use git worktree for isolation
---

## Steps

- [ ] **Step 1: Write failing tests**
action: Write tests for rate limit behavior
loop: false
verify: pytest tests/test_rate_limit.py -v

- [ ] **Step 2: Implement rate limiting**
action: Add rate limiting middleware
loop: until tests pass
max_iterations: 5
verify: pytest tests/test_rate_limit.py -v
```

### 3. Review Before Execution

HOTL reviews both design docs and workflow plans before execution:

- **Structural lint** with `scripts/document-lint.sh`
- **AI review** with `hotl:document-review`

Lint failures are hard blockers. AI review can:
- `PASS`
- `REVISE`
- `HUMAN_OVERRIDE_REQUIRED`

That means execution does not start from a structurally broken or obviously weak plan.

### 4. Git Branch Isolation

Before executing any steps, HOTL creates a dedicated git branch so work never lands directly on main or master. This prevents merge conflicts in team environments and keeps AI-generated changes isolated until reviewed.

**How it works:**
- HOTL derives the branch name from the workflow filename: `hotl-workflow-add-auth.md` becomes `hotl/add-auth`
- Teams can override the branch name with `branch: feat/add-auth` in the workflow frontmatter
- Set `worktree: true` to create a git worktree for full filesystem isolation

**Safety checks before branching:**
- Uncommitted changes block execution (no auto-stash — you decide what to do)
- Existing branches always prompt: reuse, recreate, or abort
- Repos without git or with no commits skip branching and execute in place

This means every workflow execution starts clean, on its own branch, with no risk to the main branch.

### 5. Execute

After review, HOTL gives the user three execution options.

#### Option 1: Loop Execution

Best for users who want the most automation.

What it means to the user:
- HOTL runs the workflow step by step
- it retries steps that are allowed to loop
- it auto-approves low-risk gates
- it pauses on high-risk or human-gated steps

Use this when you want fast autonomous progress with guardrails.

#### Option 2: Manual Execution

Best for users who want tighter oversight.

What it means to the user:
- HOTL executes the workflow in order
- it stops for explicit human checkpoints
- you review progress before the next batch continues

Use this when you want to stay closely involved during implementation.

#### Option 3: Subagent Execution

Best for users who want same-session delegation without giving up control.

What it means to the user:
- HOTL stays in the current session as the controller
- implementation-friendly steps can be delegated to fresh subagents
- verification, stop conditions, and approval gates stay with the controller
- risky or human-gated steps are still controlled directly

Use this when you want cleaner task-level delegation but still want HOTL to own governance.

### 6. Verify Before Completion

HOTL does not treat “should work” as completion. It requires real evidence:

- test commands
- lint output
- verification commands from the workflow
- success criteria checked against the actual result

## Claude Code Plugin

HOTL is available as a Claude Code plugin with skills, commands, and hooks.

### Install for Claude Code

```text
/plugin marketplace add yimwoo/hotl-plugin
/plugin install hotl@hotl-plugin
```

### Claude Code Commands

| Command | What it does |
| --- | --- |
| `/hotl:brainstorm` | Design the change before coding |
| `/hotl:write-plan` | Create a `hotl-workflow-<slug>.md` |
| `/hotl:loop` | Run the workflow with autonomous loop execution |
| `/hotl:execute-plan` | Run the workflow with manual checkpoints |
| `/hotl:subagent-execute` | Run the workflow with same-session delegated subagent execution |
| `/hotl:setup` | Generate adapter files for other tools |

## Codex Skills

HOTL works in Codex through native skill discovery.

### Install for Codex

Follow the instructions in [`.codex/INSTALL.md`](.codex/INSTALL.md).

The short version:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.codex/hotl
mkdir -p ~/.agents/skills
ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
```

Then restart Codex so it discovers the new skills.

### Key Codex Skills

- `hotl:brainstorming`
- `hotl:writing-plans`
- `hotl:document-review`
- `hotl:loop-execution`
- `hotl:executing-plans`
- `hotl:subagent-execution`
- `hotl:tdd`
- `hotl:systematic-debugging`

## Cline Workflow Rules

HOTL works in Cline by installing global rules and local skill files.

### Install for Cline

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh | bash
```

Detailed instructions: [`docs/README.cline.md`](docs/README.cline.md)

### What Cline Gets

- brainstorming rules
- planning rules
- execution rules
- subagent execution rules
- TDD rules
- debugging rules
- code review rules

That gives Cline a repeatable operating model instead of one-off prompting.

## Example End-to-End Workflow

User request:

```text
Help me add rate limiting to this FastAPI app
```

HOTL flow:

```text
Brainstorm
  → clarify requirements
  → compare approaches
  → write contracts

Plan
  → create hotl-workflow-add-rate-limiter.md

Document Review
  → lint structure
  → review plan quality

Branch
  → create hotl/add-rate-limiter branch
  → verify clean workspace

Execute
  → choose loop, manual, or subagent execution

Verify
  → run tests, lint, and success checks before claiming done
```

## Supported Tools

| Tool | Integration |
| --- | --- |
| Claude Code | Plugin with commands, skills, and hooks |
| Codex | Native skill discovery |
| Cline | Global rules plus local skill files |
| Cursor | Adapter templates |
| GitHub Copilot | Adapter templates |

## Repository Structure

```text
skills/          HOTL skills
commands/        Claude Code slash command definitions
hooks/           SessionStart hook for Claude Code
workflows/       Workflow templates
cline/rules/     Global rules for Cline
adapters/        Templates for AGENTS.md, Cursor, Copilot, and other tools
docs/            Setup docs and workflow format reference
scripts/         Utility scripts, including document-lint.sh
```

## Manual Claude Code Install

```bash
git clone https://github.com/yimwoo/hotl-plugin
cd hotl-plugin
bash install.sh
```

`install.sh` installs the Claude Code plugin. For Codex and Cline, use the setup steps in the sections above.

## Update

For Claude Code and Cline, use the update script:

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

If you already have a local clone:

```bash
bash update.sh
```

For Codex installs, update the local clone directly:

```bash
cd ~/.codex/hotl
git pull
```

## Contributing

```bash
bats test/smoke.bats
```

The smoke suite validates:
- plugin JSON files
- hook output
- skill and command file presence
- checkbox workflow lint support

Bug reports and feature requests: [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
