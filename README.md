# HOTL Plugin

A Code plugin implementing the Human-on-the-Loop (HOTL) operating model.
AI executes autonomously within guardrails you define. You review outcomes, not every step.

## What Makes This Different

**Loop execution:** Define steps with success criteria. Claude loops until criteria are met.
**Auto-approve:** Low-risk gates skip automatically. High-risk gates always pause.
**Multi-tool:** Works with Claude Code, Codex, Cline, Cursor, and GitHub Copilot.
**Offline:** No external dependencies. Works on corporate networks without internet.

## Install

> Installation differs by platform. Claude Code and Cursor have built-in plugin marketplaces. Codex and OpenCode require manual setup.

### Claude Code (via Plugin Marketplace)

Register the marketplace, then install:

```
/plugin marketplace add yimwoo/hotl-plugin
/plugin install hotl@hotl-plugin
```

### Cursor (via Plugin Marketplace)

In Cursor Agent chat:

```
/plugin-add hotl
```

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.codex/INSTALL.md
```

Detailed docs: [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.opencode/INSTALL.md
```

### Cline

Tell Cline:

```
Fetch and follow instructions from https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/.cline/INSTALL.md
```

Detailed docs: [docs/README.cline.md](docs/README.cline.md)

### Manual (git)

```bash
git clone https://github.com/yimwoo/hotl-plugin
cd hotl-plugin && bash install.sh
```

## Update

```bash
cd ~/.claude/plugins/hotl && git pull
```

---

## Usage

### Brainstorm a feature

Before writing any code, use brainstorming to design with intent, verification, and governance contracts:

```
/hotl:brainstorm
```

Claude first scans `docs/plans/` for existing design docs to understand prior decisions. If you reference a doc path in your message, it reads that too. Then it asks about your objective, constraints, and success criteria. It produces a design doc with three HOTL contracts before any implementation begins.

**Example:**
```
You: /hotl:brainstorm
Claude: [reads docs/plans/ for prior decisions, if any]
Claude: What feature are you building? What are the constraints? What does success look like?
→ Produces: intent contract, verification contract, governance contract
```

### Write a plan

After design approval, convert the design doc into a step-by-step execution plan:

```
/hotl:write-plan
```

Produces a `hotl-workflow.md` with bite-sized tasks, exact file paths, loop definitions, and approval gates.

### Loop execute (autonomous)

Execute `hotl-workflow.md` with loop execution and auto-approve for low-risk steps:

```
/hotl:loop
```

Claude reads each step, executes it, verifies success criteria, and loops until done. Low-risk gates auto-approve. High-risk gates (deploy, delete, push) always pause for your review.

**Example flow:**
```
/hotl:loop
→ Step 1: Create file X... done. Criteria met.
→ Step 2: Run tests... failed. Retrying...
→ Step 2: Run tests... passed. Criteria met.
→ [HIGH-RISK GATE] About to push to main. Approve? (y/n)
```

### Linear execute (with checkpoints)

Execute a plan step by step with an explicit human checkpoint between each batch:

```
/hotl:execute-plan
```

Use this when you want to review and approve each step before Claude proceeds.

### Parallel agents

Dispatch 2+ independent tasks to run in parallel:

```
/hotl:dispatch
```

Claude spawns sub-agents for each independent task and consolidates results.

### Setup for your team's tools

Generate adapter config files for Codex, Cline, Cursor, or GitHub Copilot:

```
/hotl:setup
```

---

## Commands

| Command | Purpose |
|---|---|
| `/hotl:brainstorm` | Design a feature with HOTL contracts before writing code |
| `/hotl:write-plan` | Create a `hotl-workflow.md` plan |
| `/hotl:loop` | Execute `hotl-workflow.md` with loop execution + auto-approve |
| `/hotl:execute-plan` | Linear execution with explicit checkpoints |
| `/hotl:dispatch` | Dispatch parallel sub-agents for independent tasks |
| `/hotl:setup` | Generate adapter files for your team's tools |

## The Workflow

```
/hotl:brainstorm  → design doc with intent/verification/governance contracts
/hotl:write-plan  → hotl-workflow.md
/hotl:loop        → autonomous execution, auto-approve low-risk, pause at high-risk
```

## Skills Reference

| Skill | Description |
|---|---|
| `hotl:brainstorming` | Design-first with HOTL contracts |
| `hotl:writing-plans` | Produces `hotl-workflow.md` |
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
- **Codex:** `AGENTS.md`
- **Cline:** `.clinerules`
- **Cursor:** `.cursor/rules/hotl.md`
- **GitHub Copilot:** `.github/copilot-instructions.md`

---

## Contributing

Contributions are welcome.

To contribute:
1. Fork the repo: [github.com/yimwoo/hotl-plugin](https://github.com/yimwoo/hotl-plugin)
2. Create a branch for your change
3. Submit a pull request with a clear description of what you changed and why
4. For new skills, follow the existing skill format and include a usage example

Workspace artifacts generated while developing the plugin (`hotl-workflow.md`, `docs/plans/`, `CLAUDE.md`) are gitignored and should not be committed.

Bug reports and feature requests: open an issue at [github.com/yimwoo/hotl-plugin/issues](https://github.com/yimwoo/hotl-plugin/issues)
