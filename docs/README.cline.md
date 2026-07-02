# HOTL Plugin for Cline

HOTL is a Human-on-the-Loop AI coding workflow for Cline. It adds structured brainstorming, design, workflow planning, review, and verification so Cline does not jump straight into implementation without guardrails.

Works with **any API provider** — Oracle Code Assist (OCA), OpenAI (GPT-4, GPT-5), Anthropic (Claude), Google (Gemini), local models, and more.

## Install (One Command)

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh | bash
```

Or clone first:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.cline/hotl
bash ~/.cline/hotl/install-cline.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/yimwoo/hotl-plugin.git "$env:USERPROFILE\.cline\hotl"
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cline\hotl\install-cline.ps1"
```

### What the script does

1. Installs HOTL skills to `~/.cline/hotl/` (macOS/Linux) or `%USERPROFILE%\.cline\hotl\` (Windows)
2. Copies HOTL rules to `~/Documents/Cline/Rules/` (macOS/Linux) or `%USERPROFILE%\Documents\Cline\Rules\` (Windows)
3. Replaces path placeholders in rules with OS-appropriate paths at install time

**No per-project setup.** Rules apply to all projects automatically. No settings to paste. No VS Code restart needed — just start a new Cline task.

## How to Use

Tell Cline what you need in natural language. HOTL rules teach Cline to follow structured workflows instead of jumping to code.

| What you say | What Cline does |
| --- | --- |
| "brainstorm this feature" | Asks clarifying questions one at a time, proposes 2-3 approaches, defines HOTL contracts (intent, verification, governance), saves a design doc in `docs/designs/` |
| "plan the implementation" | Uses `writing-plans` semantics to create a dated workflow in `docs/plans/` with atomic steps, verify commands, and approval gates |
| "execute the plan" | Routes through `governed-execution`; Cline normally uses the conformant generic driver and the requested manual, loop, or delegated profile |
| "subagent execute the plan" | Delegates implementation-friendly workflow steps to fresh subagents while keeping verification and gates in the controller |
| "use TDD" | Follows RED-GREEN-REFACTOR — writes a failing test before any implementation code |
| "debug this" | Systematic 4-phase process: reproduce, understand, hypothesize, fix and verify |
| "review the workflow" | Runs document lint plus qualitative workflow review before execution |
| "review the code" | Checklist review: plan alignment, code quality, governance — reports BLOCK/WARN/NOTE issues with file:line references |

## How It Works

Cline reads `~/Documents/Cline/Rules/` for global rules. HOTL installs 10 rule files that teach Cline structured workflows:

| Rule file | What it enforces |
| --- | --- |
| `hotl-operating-model.md` | Core HOTL principles — never code without a design, three contracts required, risk levels |
| `hotl-brainstorming.md` | Full brainstorming process — questions, approaches, contracts, design doc |
| `hotl-planning.md` | Create workflow files with atomic steps, verify commands, gates |
| `hotl-document-review.md` | Lint and review design docs and workflow files before execution |
| `hotl-execution.md` | Execute plans with checkpoints, per-step chat logs for live visibility, markdown table for final summary. State persistence and resumable execution require [`jq`](https://jqlang.github.io/jq/); without it, HOTL still works but runs without state files or durable reports. |
| `hotl-subagent-execution.md` | Execute reviewed plans in-session with delegated subagent steps and controller-owned gates |
| `hotl-tdd.md` | RED-GREEN-REFACTOR — never write code before a failing test |
| `hotl-debugging.md` | 4-phase debugging — reproduce, understand, hypothesize, fix |
| `hotl-code-review.md` | Dispatch-first code review: gathers context automatically, runs inline review with same output contract as the full reviewer, findings only (no auto-fix), BLOCK/WARN/NOTE with file:line references |
| `hotl-pr-review.md` | PR review rendering — follow `docs/contracts/pr-review-output.md` for the 9-section output schema |

Each rule file contains:

- **Condensed skill** — the full workflow process inline, works with any model
- **Skill routing** — tells Cline to read the detailed skill file from `~/.cline/hotl/skills/` when the model supports file reading

This hybrid approach works with any API provider and any model.

For execution, `governed-execution` is the preferred router. HOTL currently
ships host-native drivers for Codex and Claude Code, not Cline, so normal Cline
sessions select the generic `hotl-rt` fallback. This keeps workflow state,
verification, gates, receipts, and finish behavior portable across hosts.

## The HOTL Workflow

```text
brainstorm     →  design doc in docs/designs/ with intent/verification/governance contracts
writing-plans  →  dated workflow in docs/plans/ with atomic steps and gates
review         →  lint and qualitative review before execution
execute        →  step-by-step execution with verification at each step
verify         →  review code and confirm evidence before claiming done
finish         →  merge back, publish, keep, or discard the execution checkout intentionally
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

### Portable Governance and Recovery

Governed execution records more than step completion:

- `external_write`, `production_change`, and `secret_access` actions require a
  persisted human decision before execution
- Configured attempt, agent, cost, and elapsed-time budgets are evaluated from
  observed runtime evidence; unavailable telemetry remains `unknown`
- Interrupted or ambiguous runs use read-only, verify-first reconciliation
- Completion is proven by a state-derived receipt, not a chat success message

These durable controls require `jq`. See
[`contracts/policy-budget-recovery.md`](contracts/policy-budget-recovery.md),
[`contracts/portable-workflow-and-receipt.md`](contracts/portable-workflow-and-receipt.md),
and [`host-native-drivers.md`](host-native-drivers.md).

### Measured Adaptive Evaluation

Run `scripts/hotl-evaluation-report.sh --format text <evaluation.json> ...` to
compare existing evaluation records locally. Recommendation eligibility
requires two explicit profiles, three shared scenario/revision pairs, and a
fully known matching environment. Incomplete outcomes, contract failures, and
post-completion defects disqualify a profile. Unavailable duration, agent,
token, or cost telemetry remains unknown rather than becoming zero.

The model-neutral result may be `collect_more_evidence`,
`human_review_required`, or `review_profile_candidate`. Every outcome remains a
human decision and the helper never changes Cline's model, provider, permission,
policy, driver, effort, or routing configuration. See the
[`evaluation summary contract`](contracts/evaluation-summary-output.md).

### Continuous Evaluation and Drift Detection

Cline can inspect, validate, and report the same model-neutral campaign and
history artifacts with `scripts/hotl-evaluation-campaign.sh`,
`scripts/hotl-evaluation-history.sh`, and
`scripts/hotl-evaluation-proposal.sh`. Live Codex or Claude Code profiles still
require their host binaries and an explicit `--approve-live` collection outside
Cline's model/provider selection.

Append-only reports separate workload, prompt/schema, host, model/adapter,
toolchain, telemetry, incomplete-campaign, and quality-regression evidence.
Profile proposals are advisory only: `human_review_required: true`,
`automatic_selection_performed: false`, and
`configuration_changes_performed: false`. HOTL does not change Cline's model,
provider, permissions, rules, or routing. See
[`Continuous Evaluation and Drift Detection`](continuous-evaluation.md).

## Workflow Files

Canonical workflows are saved as `docs/plans/YYYY-MM-DD-<slug>-workflow.md` (for example, `docs/plans/2026-04-22-add-auth-workflow.md`). Legacy root files such as `hotl-workflow-add-auth.md` remain readable during migration, but new writes should use the canonical `docs/plans/` location:

```yaml
---
intent: one sentence goal
success_criteria: how you know it's done
risk_level: low | medium | high
auto_approve: true | false
# worktree: host  # optional: use only when the host tool already put this task on a feature-branch worktree
---

## Steps

- [ ] **Step 1: Write failing test for auth**
action: Create test for login endpoint
loop: false
verify: npm test -- --grep "login"
gate: auto

- [ ] **Step 2: Implement auth logic**
action: Add login handler
loop: until tests pass
max_iterations: 3
verify: npm test
gate: human
```

## Updating

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Or if already cloned:

```bash
bash ~/.cline/hotl/update.sh
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.ps1" -OutFile "$env:TEMP\hotl-update.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\hotl-update.ps1"
```

Or if already cloned:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cline\hotl\update.ps1"
```

This pulls the latest code and syncs global rules automatically. Also updates Claude Code and Codex if installed. On Windows, rule path placeholders are re-applied during update.

## Native Skills Mode (Cline 3.48.0+)

If your Cline version supports native skills (`use_skill` tool), you can install HOTL as native Cline skills instead of rules. This gives you:

- **Token savings** — skills are lazy-loaded on-demand instead of always in the system prompt
- **UI discoverability** — HOTL skills appear in Cline's Skills menu
- **Same workflows** — identical capabilities, just a more efficient delivery mechanism

### Install with native skills

**macOS / Linux:**
```bash
bash ~/.cline/hotl/install-cline.sh --native-skills
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cline\hotl\install-cline.ps1" -NativeSkills
```

This installs:
- 1 global rule: `hotl-operating-model.md` (always-on task router)
- 11 native skills, including `governed-execution`, to `~/.cline/skills/hotl/` (macOS/Linux) or `%USERPROFILE%\.cline\skills\hotl\` (Windows)

The install mode is persisted in `~/.cline/hotl/.cline-install-mode`. Updates automatically refresh the correct mode.

### Switching modes

To switch from legacy rules to native skills (or back), re-run the installer with the desired flag:

```bash
bash ~/.cline/hotl/install-cline.sh --native-skills   # switch to native skills
bash ~/.cline/hotl/install-cline.sh                    # switch back to legacy rules
```

Or during an update:

```bash
bash ~/.cline/hotl/update.sh --native-skills           # switch to native skills during update
```

Switching modes automatically cleans up the previous mode's artifacts — no manual cleanup needed.

### Which mode should I use?

| | Legacy rules (default) | Native skills (`--native-skills`) |
|---|---|---|
| **Cline version** | Any | 3.48.0+ with `use_skill` support |
| **Token cost** | All 10 rules always in context | Only operating model rule always in context |
| **Activation** | Passive (user says trigger phrase) | Active (Cline matches skill description) |
| **UI** | No skills menu | Skills appear in Cline's Skills menu |

When in doubt, use the default. If you're on a modern Cline and want better token efficiency, use `--native-skills`.

## FAQ

**Does it work with Oracle Code Assist (OCA)?**
Yes. HOTL rules are model-agnostic. They work with OCA, GPT-4/5, Claude, Gemini, and local models.

**Do I need to set up each project?**
No. Rules install globally to `~/Documents/Cline/Rules/` and apply to all projects.

**Does it work offline / on corporate networks?**
The HOTL rules, skills, workflow files, and generic runtime are local and can be
used without HOTL network services. Durable state, reports, receipts, budgets,
and recovery require a local `jq` installation. Cline model access and any
host-native or provider feature still depend on the selected provider and your
organization's network and policy.

**Can I customize the rules?**
Yes, but HOTL updates replace the installed `hotl-*.md` copies in
`~/Documents/Cline/Rules/`. Put project-specific guidance in the project's
`.clinerules/`, or maintain team-wide HOTL changes in a fork/source checkout and
reinstall from there.

**Does it conflict with existing `.clinerules`?**
No. Global rules in `~/Documents/Cline/Rules/` coexist with per-project `.clinerules/` files.
