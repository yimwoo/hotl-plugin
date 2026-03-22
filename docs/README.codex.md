# HOTL Plugin for Codex

## Installation

1. Clone the repo:

```bash
# From GitHub (internet)
git clone https://github.com/yimwoo/hotl-plugin ~/.codex/hotl

# From OraHub (corporate network)
git clone git@orahub.oci.oraclecorp.com:.../hotl-plugin ~/.codex/hotl
```

2. Create the skills symlink:

```bash
mkdir -p ~/.agents/skills
ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
```

3. Restart Codex.

## Stable Channel

`~/.codex/hotl` is the HOTL stable channel and should track `origin/main`.
Do not do feature work inside that directory. If you want to develop HOTL itself,
use a separate clone or worktree somewhere else and keep `~/.codex/hotl` for the
version Codex discovers.

## How It Works

Codex discovers skills in `~/.agents/skills/` at startup. The `using-hotl` skill
provides the HOTL skill index and routing guidance for the rest of the skill set.
Codex uses the skill files directly. Claude-style slash commands such as
`/hotl:pr-review` are not part of the Codex integration.
Codex discovers every entry under `~/.agents/skills/`, so the Installed skills
screen mixes HOTL with any other installed skill packs. HOTL skills are the ones
coming from `~/.agents/skills/hotl`.
There is no `/hotl:brainstorm` or `/hotl:pr-review` command syntax in Codex. In Codex, either describe the task in natural language and let HOTL route it, or explicitly mention an installed skill such as `$brainstorming`, `$writing-plans`, or `$pr-reviewing`.

## How To Invoke HOTL Skills In Codex

You can invoke HOTL in two ways:

- Describe the task in natural language and let Codex choose the right HOTL skill.
- Explicitly mention a specific installed skill with a `$` prefix when you want a precise workflow.

If you do not name a skill, Codex can still choose from the installed HOTL skills
based on your request. Use the `$skill-name` form when you want to force a specific skill.
Codex may display these skills in the UI as title-cased labels such as `Brainstorming`
or `Code Review`.

Examples:

```text
Use `$brainstorming` to compare OAuth and API-key auth before writing code.

Please use HOTL to compare OAuth and API-key auth before writing code.

Use `$writing-plans` to create `hotl-workflow-add-rate-limiting.md`.

Review `hotl-workflow-add-rate-limiting.md` with HOTL and tell me if it is ready to execute.

Use `$subagent-execution` to execute `hotl-workflow-add-rate-limiting.md` in this session.

Use `$pr-reviewing` to review https://github.com/org/repo/pull/123.

Before you say this task is done, use `$verification-before-completion`.

Use HOTL for this task and choose the most appropriate skill automatically.
```

## Codex vs Claude Code

| Tool | How HOTL is invoked |
| --- | --- |
| Codex | Natural-language prompts or explicit skill mentions such as `Use HOTL to plan this` or `$brainstorming` |
| Claude Code | Slash commands such as `/hotl:brainstorm` and `/hotl:pr-review` |

## Common Skills

- `brainstorming` — design with HOTL contracts before implementation
- `writing-plans` — create `hotl-workflow-<slug>.md` files
- `document-review` — run structural lint and qualitative review before execution
- `loop-execution` — autonomous execution with retries
  - **Codex native progress (mandatory):** HOTL must use the native progress card as the primary live step visibility surface. If the native tool is unavailable or errors, immediately switch to per-step chat logs.
  - **Codex final summary:** must use compact step list in chat (not wide markdown table). Durable report keeps the full table.
  - **Deterministic renderer:** final summaries should be rendered via `scripts/render-execution-summary.sh` instead of freehand formatting when the repo provides that script.
- `executing-plans` — manual checkpointed execution
- `subagent-execution` — same-session delegated execution with controller-owned verification
- `pr-reviewing` — review a PR across description, code, scan, and tests
  - **Output contract:** `docs/contracts/pr-review-output.md` defines the canonical 9-section review schema
  - **Codex rendering (advisory):** emit platform-native inline findings first (e.g., `::code-comment` directives for BLOCK and WARN findings with file:line), then render the full 9-section structured summary. Use plain markdown for the summary.
- `code-review` — review branch changes against the workflow and HOTL contracts
- `verification-before-completion` — require test and command output before claiming success

## Updating

```bash
bash ~/.codex/hotl/update.sh
```

If the install drifted onto another branch, the updater switches it back to the
stable `main` branch before pulling the latest HOTL skills.

To check if an update is available without updating:

```bash
bash ~/.codex/hotl/update.sh --check
```

Codex currently discovers HOTL through `~/.agents/skills/hotl`. It does not
have a guaranteed HOTL startup-notice path, so do not rely on a SessionStart
update banner in the app. Use the manual check command above when you want to
verify whether `~/.codex/hotl` is behind.

Restart Codex after updating so it re-discovers the latest skill files.

## Codex Manual Canary

Use this short canary when you want to validate Codex execution UX in the real app:

1. Run a HOTL workflow that has at least one gate and at least one verified implementation step.
2. Confirm the native progress card appears immediately after runtime initialization.
3. Confirm only one workflow step is shown as active at a time.
4. Confirm the run ends with a visible final chat summary that includes every step, its status, and its attempt count or gate marker.
5. If the native progress card does not appear or errors, confirm HOTL falls back to per-step chat logs and still shows the final chat summary.

When the repo includes `scripts/render-execution-summary.sh`, use it as the source of truth for final-summary formatting. If chat output disagrees with `.hotl/reports/<run-id>.md` or the renderer output, trust the runtime artifacts first.

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl
```
