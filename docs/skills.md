# HOTL Skills Reference

HOTL provides a set of focused skills for structured AI development. All skills work with **Claude Code** and **Codex**. Cline users get equivalent rules automatically.

Want to create or modify HOTL abstractions? See [Authoring Skills vs Agents](authoring-skills-vs-agents.md) for guidance on when to create a skill, an agent, or an inline prompt.

## Skills

### Design & Planning

| Skill | Description | Phase |
| --- | --- | --- |
| [`brainstorming`](../skills/brainstorming/SKILL.md) | Explore intent, requirements, and design. Produces HOTL contracts (intent, verification, governance) before implementation. Prefers multiple-choice questions and includes a design-doc self-check. | Brainstorm |
| [`writing-plans`](../skills/writing-plans/SKILL.md) | Create a dated executable workflow in `docs/plans/YYYY-MM-DD-<slug>-workflow.md` with typed verification (shell, browser, human-review, artifact), loop/gate definitions, and a built-in self-check loop. | Plan |
| [`document-review`](../skills/document-review/SKILL.md) | Optional utility for reviewing existing docs, external specs, design docs, workflows, or hand-authored legacy plans. Runs deterministic lint then AI-driven qualitative review. | Review |

### Execution

| Skill | Description | Phase |
| --- | --- | --- |
| [`loop-execution`](../skills/loop-execution/SKILL.md) | The canonical HOTL execution engine — mandatory live step visibility, platform-specific rendering (Codex: native progress card, Claude Code/Cline: chat logs + markdown table). Persists state for resume. | Execute |
| [`executing-plans`](../skills/executing-plans/SKILL.md) | Loop execution with explicit human checkpoints between batches of tasks. | Execute |
| [`subagent-execution`](../skills/subagent-execution/SKILL.md) | Delegated step runner over the loop execution engine — delegates eligible steps to fresh subagents while the controller keeps governance and verification. | Execute |
| [`resuming`](../skills/resuming/SKILL.md) | Resume an interrupted workflow run — verify-first strategy with sidecar state persistence. | Execute |
| [`dispatch-agents`](../skills/dispatch-agents/SKILL.md) | Run 2+ independent tasks in parallel with no shared state — dispatches parallel subagents for each task. | Execute |
| [`finishing-a-development-branch`](../skills/finishing-a-development-branch/SKILL.md) | Close the execution lifecycle intentionally — merge back, publish/create a PR, keep the execution checkout, or discard it while recording the outcome in HOTL state. | Finish |

### Quality & Review

| Skill | Description | Phase |
| --- | --- | --- |
| [`pr-reviewing`](../skills/pr-reviewing/SKILL.md) | Review a PR across multiple dimensions — description/ticket, code changes, code scan, unit tests — using parallel subagents. Supports GitHub, GitLab, and enterprise platforms. | Review |
| [`requesting-code-review`](../skills/requesting-code-review/SKILL.md) | Dispatched by executors at review checkpoints — standardizes what context the reviewer receives (git range, contracts, verification evidence). | Review |
| [`receiving-code-review`](../skills/receiving-code-review/SKILL.md) | Governs how agents handle review findings — verify each claim against the codebase and HOTL contracts before acting (Verify -> Evaluate -> Respond -> Implement). | Review |
| [`code-review`](../skills/code-review/SKILL.md) | User-facing entry point for code review. Dispatches the full `code-reviewer` agent by default; falls back to inline review on platforms without subagent support. Returns findings only — no auto-fix. | Review |
| [`verification-before-completion`](../skills/verification-before-completion/SKILL.md) | Run verification commands and confirm output before claiming work is complete. Evidence before assertions. | Verify |

### Development Practices

| Skill | Description | Phase |
| --- | --- | --- |
| [`tdd`](../skills/tdd/SKILL.md) | Enforce RED-GREEN-REFACTOR cycle before writing any implementation code. | Execute |
| [`systematic-debugging`](../skills/systematic-debugging/SKILL.md) | Structured debugging workflow — reproduce, isolate, fix, verify. Use before proposing fixes for any bug or test failure. | Execute |
| [`skill-authoring`](../skills/skill-authoring/SKILL.md) | Create, edit, or review HOTL skills, agents, command prompts, and behavior-shaping instructions with trigger-only descriptions, routing updates, and verification. | Setup |

### Setup & Configuration

| Skill | Description | Phase |
| --- | --- | --- |
| [`setup-project`](../skills/setup-project/SKILL.md) | Generate adapter files for the current project — creates AGENTS.md, .clinerules, cursor rules, or copilot instructions depending on tools the team uses. | Setup |
| [`using-hotl`](../skills/using-hotl/SKILL.md) | Auto-loaded on session start. Establishes the skill index and HOTL operating principles. | Setup |
