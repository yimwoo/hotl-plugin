# Authoring Skills vs Agents

A canonical reference for writing HOTL skills and agents. Covers what each is, when to use which, repo conventions, common mistakes, real examples, and copy-paste templates.

**Quick links:** [Jump to Skill Template](#appendix-a-skill-template) | [Jump to Agent Template](#appendix-b-agent-template)

## Table of Contents

- [What Is a Skill?](#what-is-a-skill)
- [What Is an Agent?](#what-is-an-agent)
- [Decision Framework: Skill vs Agent vs Inline](#decision-framework-skill-vs-agent-vs-inline)
- [Repo Conventions](#repo-conventions)
- [Common Mistakes](#common-mistakes)
- [Annotated Examples](#annotated-examples)
- [Pre-Merge Checklist](#pre-merge-checklist)
- [Appendix A: Skill Template](#appendix-a-skill-template)
- [Appendix B: Agent Template](#appendix-b-agent-template)

---

## What Is a Skill?

A **skill** is a platform-facing workflow entry point. Each platform discovers and invokes skills through its own mechanism — the important thing is that skills are the user-facing surface. For platform-specific invocation details, see the linked install docs (`docs/README.codex.md`, `docs/README.cline.md`).

Skills **orchestrate** — they coordinate multi-step processes, enforce discipline, and make decisions about what to do next. They run in the caller's context and have access to the full conversation state.

**Key traits:**

- Lives at `skills/<name>/SKILL.md`
- Has YAML frontmatter: `name` (required), `description` (required), `model` (optional)
- Body is Markdown describing the process, steps, and rules
- Platform-discoverable — the platform can match a skill to a task based on its `description`
- Invoked by users (directly or via commands) or by other skills

**Examples in this repo:** `brainstorming`, `code-review`, `loop-execution`, `writing-plans`, `pr-reviewing`

---

## What Is an Agent?

An **agent** is a repo-internal specialized worker definition. It is dispatched programmatically by a skill as a fresh subagent. Agents are **not** user-discoverable — they are implementation details of the skills that dispatch them.

Agents **judge or produce structured output** — they have a defined persona, structured output contract (findings format, verdict model), and review dimensions. They run in an isolated context with no state leakage from the caller.

**Key traits:**

- Lives at `agents/<role>.md`
- Has the same YAML frontmatter as skills: `name`, `description`, `model`
- Body defines: persona, inputs, output contract, and verdict model
- **Not** platform-discoverable — only dispatched by skills that know about them
- Runs in fresh, isolated context (no conversation history from the caller)

**Examples in this repo:** `code-reviewer`

---

## Decision Framework: Skill vs Agent vs Inline

### Quick Decision Table

| Signal | Skill | Agent | Inline prompt |
|---|---|---|---|
| Orchestrates multiple steps or decisions | Yes | No | No |
| Needs a reusable specialized worker with a stable structured output contract | No | Yes | No |
| Runs in the caller's conversation context | Yes | No | N/A |
| Needs isolation (fresh context, no state leakage) | No | Yes | No |
| User invokes directly or via command | Yes | No | No |
| Dispatched programmatically by another skill | Sometimes | Yes | Yes |
| Short prompt tightly coupled to one skill | No | No | Yes |

### Three-Line Heuristic

1. **"Does it orchestrate?"** → Skill
2. **"Does it judge or produce structured findings as a reusable worker?"** → Agent
3. **"Is it a short prompt embedded in one skill?"** → Inline, no new file needed

### Reuse Convention

- If a role is **reused by multiple skills**, define it as `agents/<role>.md` so each skill dispatches the same contract.
- If a role is **tightly coupled to one workflow**, inline the prompt inside that skill — creating a separate file adds maintenance cost with no reuse benefit.

---

## Repo Conventions

### Directory Structure

| Type | Location | Example |
|---|---|---|
| Skill | `skills/<name>/SKILL.md` | `skills/brainstorming/SKILL.md` |
| Agent | `agents/<role>.md` | `agents/code-reviewer.md` |
| Command | `commands/<name>.md` | `commands/brainstorm.md` |

### Frontmatter (shared format)

Both skills and agents use the same YAML frontmatter:

```yaml
---
name: <identifier>          # Required. Used for matching and dispatch.
description: <one sentence> # Required. Platforms use this for discovery (skills) or dispatch context (agents).
model: <model hint>         # Optional. Inherits from platform default if omitted.
---
```

The `description` field is critical — it determines when a skill gets invoked. Write it as a precise one-sentence trigger, not a generic summary. See [Common Mistakes](#common-mistakes) for examples of vague vs specific descriptions.

### Naming Rules

**Skills and commands must have different names.** If they share a name, the platform may loop infinitely or block with an error. Follow the existing convention — command uses a short name, skill uses a longer variant:

| Command | Skill |
|---|---|
| `brainstorm` | `brainstorming` |
| `write-plan` | `writing-plans` |
| `loop` | `loop-execution` |
| `execute-plan` | `executing-plans` |
| `pr-review` | `pr-reviewing` |

**Agent naming:** use `<role>.md` (e.g., `code-reviewer.md`). No established convention for multi-word slugs yet — follow kebab-case.

### Indexing

When you add a new skill, you **must** add it to the skill index in `skills/using-hotl/SKILL.md`. The index provides HOTL's routing guidance — it tells the session which skills exist and when to use each one. Platforms may also discover skills through their own mechanisms (e.g., Codex discovers installed skills from `~/.agents/skills/`), but the `using-hotl` index is what connects a new skill to HOTL's workflow routing. If you skip this step, the skill file exists on disk but HOTL won't know to route tasks to it.

Agents do not need indexing — they are dispatched explicitly by the skills that use them.

### Cross-References

For full installation and contributor docs, see:
- `README.md` — project overview and installation
- `docs/README.codex.md` — Codex-specific setup
- `docs/README.cline.md` — Cline-specific setup
- `CLAUDE.md` — Claude Code contributor instructions

---

## Common Mistakes

1. **Naming a skill the same as its command.**
   The platform resolves the command, loads the skill, the skill invokes itself — infinite loop or `disable-model-invocation` error. Always use a different (usually longer) name for the skill. See the naming table above.

2. **Building an agent that orchestrates instead of judges.**
   Agents run in isolated context with no conversation history. If your agent needs to coordinate multiple steps, make decisions about what to do next, or interact with the user — it should be a skill. Agents that try to orchestrate end up with bloated prompts, unclear output, and no way to pause for human input.

3. **Making a skill when you need isolation.**
   If the task requires a clean slate (no state leakage from prior steps), fresh context, and a structured output contract — that's an agent. Skills share the caller's context, which is powerful but means state accumulates.

4. **Forgetting to update the `using-hotl` skill index.**
   The skill file exists on disk but HOTL's routing doesn't know about it, so sessions never invoke it. Always add new skills to `skills/using-hotl/SKILL.md`.

5. **Writing a vague `description` in frontmatter.**
   Bad: `description: Helps with code reviews`. Good: `description: Use after completing implementation steps and before merging — reviews against plan and HOTL contracts.` The description is a trigger — it must tell the platform *when* to activate, not just *what* the skill does.

6. **Creating an agent without a defined output contract.**
   The dispatching skill parses the agent's output. If the agent doesn't define a structured format (findings, verdicts, severity levels), the caller can't reliably extract results. Every agent needs an explicit output section.

7. **Using platform-specific tool names in a skill.**
   Writing `Use the Skill tool to invoke...` breaks on Codex (which uses native skill discovery) and Cline (which uses rules). Use platform-neutral language: "invoke the skill" rather than naming a specific tool.

8. **Implying agents are user-discoverable.**
   Agents live under `agents/` and are dispatched by skills. They are not listed in the skill index, not matched by the platform, and not invokable by users. Documentation and descriptions should never suggest otherwise.

---

## Annotated Examples

### Example 1: `skills/code-review/SKILL.md` — Why This Is a Skill

```yaml
---
name: code-review
description: Use after completing implementation steps and before merging — reviews against plan and HOTL contracts.
---
```

```markdown
User-facing entry point for getting a code review. Dispatches the full
`code-reviewer` agent by default; falls back to inline review when
subagents aren't available.

## Process
### 1. Gather Context
### 2. Dispatch Review
### 3. Return Findings
```

**Why a skill:** This orchestrates a multi-step workflow — it resolves the review scope, detects the platform, decides whether to dispatch an agent or run inline, and presents results. It makes branching decisions (subagent available? workflow file present?) that require caller context. Users invoke it directly via the corresponding command.

---

### Example 2: `agents/code-reviewer.md` — Why This Is an Agent

```yaml
---
name: code-reviewer
description: |
  Use after completing a step or batch of implementation work. Reviews against
  the hotl-workflow-*.md plan and HOTL contracts. Flags BLOCK/WARN/NOTE issues.
model: inherit
---
```

```markdown
You are a Senior Code Reviewer operating within a Human-on-the-Loop
development model.

## Review Dimensions
- Plan Alignment
- Code Quality
- HOTL Governance
- Architecture & Design (scope-gated)

## Findings Format
- [SEVERITY]: file/path:line — description
  Why: [why this matters]
  Fix: [expected remediation direction]

## Verdict Model
- Checkpoint: PROCEED | PROCEED WITH WARNINGS | HOLD
- Final: READY | READY WITH WARNINGS | NOT READY
```

**Why an agent:** This is a specialized judge with a defined persona, structured output contract (findings format + severity levels), and a dual verdict model. It runs in isolation — no conversation history, no orchestration decisions. Multiple skills dispatch it (`code-review`, `requesting-code-review`), so it lives in `agents/` as a reusable definition rather than being inlined.

---

### Example 3: `skills/pr-reviewing/SKILL.md` — When Inline Subagent Prompts Are Fine

```yaml
---
name: pr-reviewing
description: Review a PR across multiple dimensions — description, code changes, code scan,
  unit tests — using parallel subagents.
---
```

The PR review skill dispatches 4 parallel subagents (description, code changes, code scan, unit tests), but each subagent's prompt is **defined inline** within the skill file itself:

```markdown
### Subagent A: Description & Ticket Review
Prompt template:
---
You are reviewing a PR's description and ticket alignment.
...
Return EXACTLY this format:
DIMENSION: Description
VERDICT: PASS | WARN | BLOCK
---

### Subagent B: Code Change Review
Prompt template:
---
You are reviewing code changes in a PR.
...
---
```

**Why inline, not separate agent files:** These subagent prompts are tightly coupled to the PR review workflow. They are not reused by any other skill. Each prompt is short (20-40 lines) and specific to one dimension of PR review. Creating 4 separate `agents/*.md` files would add maintenance cost with zero reuse benefit. If another skill later needs the same "code change reviewer" role, that would be the signal to extract it to `agents/`.

---

## Pre-Merge Checklist

Before merging a new or modified skill or agent, verify:

- [ ] **Correct abstraction?** Does the [decision table](#decision-framework-skill-vs-agent-vs-inline) confirm your choice of skill vs agent vs inline?
- [ ] **Skill index updated?** If you added a skill, is it listed in `skills/using-hotl/SKILL.md`?
- [ ] **No name collision?** If you added both a command and a skill, do they have different names?
- [ ] **Description is a trigger?** Does the `description` field say *when* to activate, not just *what* it does?
- [ ] **Agent has output contract?** If you added an agent, does it define findings format and verdict model?
- [ ] **README updated?** Does `README.md` reflect the new skill/agent/command?
- [ ] **Codex docs updated?** Does `docs/README.codex.md` reflect any skill changes?
- [ ] **Cline docs updated?** Does `docs/README.cline.md` reflect any rule changes?
- [ ] **Smoke tests pass?** Run `bats test/smoke.bats`

---

## Appendix A: Skill Template

Copy this to `skills/<your-skill-name>/SKILL.md` and fill in the sections.

```markdown
---
name: <skill-name>
description: Use when <specific trigger condition> — <what the skill does in one clause>.
---

# <Skill Title>

## Overview

<One paragraph: what this skill does and why it exists.>

## Process

### 1. <First Step Name>

<What to do, what to check, what decisions to make.>

### 2. <Second Step Name>

<Continue the workflow...>

## Key Rules

- <Rule 1: constraint or invariant>
- <Rule 2: what must not happen>
- <Rule 3: when to stop or escalate>
```

**Checklist for your skill:**
- `name` differs from any command name
- `description` is a precise trigger (says *when*, not just *what*)
- Added to `skills/using-hotl/SKILL.md` index
- Process steps are numbered and actionable
- Platform-neutral language throughout

---

## Appendix B: Agent Template

Copy this to `agents/<your-role>.md` and fill in the sections.

```markdown
---
name: <role-name>
description: |
  <When this agent is dispatched and what it reviews/produces.
  Written for the dispatching skill's context, not for end users.>
model: inherit
---

You are a <Role Title> operating within a Human-on-the-Loop development model.

Your job is to <one sentence purpose>.

## Inputs

The dispatch request specifies:
- **<Input 1>:** <what it is and when it may be absent>
- **<Input 2>:** <what it is>

## <Review/Analysis> Dimensions

### <Dimension 1>

<What to evaluate, criteria, edge cases.>

### <Dimension 2>

<Continue...>

## Findings Format

Every finding must include:

- [SEVERITY]: file/path:line — description
  Why: [why this matters]
  Fix: [expected remediation direction]

Severity levels:
- **BLOCK:** Must fix before proceeding
- **WARN:** Should fix soon
- **NOTE:** Consider for future improvement

## Output

<Structured output format the dispatching skill expects to parse.>

## Verdict Model

- **<Verdict A>** — <when to use>
- **<Verdict B>** — <when to use>
- **<Verdict C>** — <when to use>
```

**Checklist for your agent:**
- `description` explains when it is dispatched (not user-facing)
- Persona is defined in the opening line
- Output contract is explicit and parseable
- Verdict model matches the dispatching skill's expectations
- At least one skill dispatches this agent (otherwise it's dead code)
