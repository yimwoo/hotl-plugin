# HOTL Skills Reference

HOTL provides a set of focused skills for structured AI development. All skills work with **Claude Code** and **Codex**. Cline users get equivalent rules automatically.

Want to create or modify HOTL abstractions? See [Authoring Skills vs Agents](authoring-skills-vs-agents.md) for guidance on when to create a skill, an agent, or an inline prompt.

## Skills

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
| `receiving-code-review` | Governs how agents handle review findings — verify each claim against the codebase and HOTL contracts before acting (Verify -> Evaluate -> Respond -> Implement). | Review |
| `code-review` | User-facing entry point for code review. Dispatches the full `code-reviewer` agent by default; falls back to inline review on platforms without subagent support. Returns findings only — no auto-fix. | Review |
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
