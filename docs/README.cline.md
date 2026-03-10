# HOTL for Cline — Structured AI Development Workflows

Stop Cline from jumping straight to code. HOTL (Human-on-the-Loop) adds structured workflows to Cline: brainstorm before coding, plan before implementing, verify before claiming done.

Works with **any API provider** — Oracle Code Assist (OCA), OpenAI (GPT-4, GPT-5), Anthropic (Claude), Google (Gemini), local models, and more.

## Install (One Command)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh)
```

Or clone first:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.cline/hotl
bash ~/.cline/hotl/install-cline.sh
```

### What the script does

1. Installs HOTL skills to `~/.cline/hotl/` (full skill files for detailed instructions)
2. Copies HOTL rules to `~/Documents/Cline/Rules/` (Cline's global rules directory)

**No per-project setup.** Rules apply to all projects automatically. No settings to paste. No VS Code restart needed — just start a new Cline task.

## How to Use

Tell Cline what you need in natural language. HOTL rules teach Cline to follow structured workflows instead of jumping to code.

| What you say | What Cline does |
| --- | --- |
| "brainstorm this feature" | Asks clarifying questions one at a time, proposes 2-3 approaches, defines HOTL contracts (intent, verification, governance), saves a design doc |
| "plan the implementation" | Creates a `hotl-workflow-<slug>.md` with atomic steps, verify commands, and approval gates |
| "execute the plan" | Runs the workflow step by step with human checkpoints every 3 steps |
| "use TDD" | Follows RED-GREEN-REFACTOR — writes a failing test before any implementation code |
| "debug this" | Systematic 4-phase process: reproduce, understand, hypothesize, fix and verify |
| "review the code" | Checklist review: plan alignment, code quality, governance — reports BLOCK/WARN/NOTE issues |

## How It Works

Cline reads `~/Documents/Cline/Rules/` for global rules. HOTL installs 7 rule files that teach Cline structured workflows:

| Rule file | What it enforces |
| --- | --- |
| `hotl-operating-model.md` | Core HOTL principles — never code without a design, three contracts required, risk levels |
| `hotl-brainstorming.md` | Full brainstorming process — questions, approaches, contracts, design doc |
| `hotl-planning.md` | Create workflow files with atomic steps, verify commands, gates |
| `hotl-execution.md` | Execute plans with checkpoints, never skip failed steps, show evidence |
| `hotl-tdd.md` | RED-GREEN-REFACTOR — never write code before a failing test |
| `hotl-debugging.md` | 4-phase debugging — reproduce, understand, hypothesize, fix |
| `hotl-code-review.md` | Review against plan with BLOCK/WARN/NOTE severity |

Each rule file contains:

- **Condensed skill** — the full workflow process inline, works with any model
- **Skill routing** — tells Cline to read the detailed skill file from `~/.cline/hotl/skills/` when the model supports file reading

This hybrid approach works with any API provider and any model.

## The HOTL Workflow

```text
brainstorm  →  design doc with intent/verification/governance contracts
plan        →  hotl-workflow-<slug>.md with atomic steps and gates
execute     →  step-by-step execution with verification at each step
review      →  checklist review before claiming done
```

### Three Contracts

Every workflow defines:

1. **Intent contract** — what you're building, what must not break, how you know it's done
2. **Verification contract** — test commands and checks for each step
3. **Governance contract** — which steps need human approval, how to roll back

### Risk Levels

| Level | Examples | Behavior |
| --- | --- | --- |
| **low** | UI changes, new endpoints | Auto-approve |
| **medium** | Schema changes, refactors | Proceed with caution |
| **high** | Auth, encryption, privacy, billing | Always pauses for human approval |

## Workflow Files

Plans are saved as `hotl-workflow-<slug>.md` in the project root (e.g., `hotl-workflow-add-auth.md`):

```yaml
---
intent: one sentence goal
success_criteria: how you know it's done
risk_level: low | medium | high
auto_approve: true | false
---

## Steps

### 1. Write failing test for auth
action: Create test for login endpoint
loop: false
verify: npm test -- --grep "login"
gate: auto

### 2. Implement auth logic
action: Add login handler
loop: until tests pass
max_iterations: 3
verify: npm test
gate: human
```

## Updating

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh)
```

Or if already cloned:

```bash
bash ~/.cline/hotl/update.sh
```

This pulls the latest code and syncs global rules automatically. Also updates Claude Code if installed.

## FAQ

**Does it work with Oracle Code Assist (OCA)?**
Yes. HOTL rules are model-agnostic. They work with OCA, GPT-4/5, Claude, Gemini, and local models.

**Do I need to set up each project?**
No. Rules install globally to `~/Documents/Cline/Rules/` and apply to all projects.

**Does it work offline / on corporate networks?**
Yes. No external dependencies after installation. Everything is local Markdown files.

**Can I customize the rules?**
Yes. Edit the files in `~/Documents/Cline/Rules/` to add project-specific or team-specific guidelines.

**Does it conflict with existing `.clinerules`?**
No. Global rules in `~/Documents/Cline/Rules/` coexist with per-project `.clinerules/` files.
