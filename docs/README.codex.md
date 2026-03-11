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
There is no `/hotl:brainstorm` or `/hotl:pr-review` command syntax in Codex. Ask Codex to use `hotl:brainstorming`, `hotl:writing-plans`, `hotl:pr-reviewing`, or another HOTL skill in plain English.

## How To Invoke HOTL Skills In Codex

Ask Codex to use a skill by name inside your prompt. If you do not name a skill,
Codex can still choose from the installed HOTL skills based on your request, but
being explicit is better when you want a specific workflow.

Examples:

```text
Use `hotl:brainstorming` to compare OAuth and API-key auth before writing code.

Use `hotl:writing-plans` to create `hotl-workflow-add-rate-limiting.md`.

Use `hotl:document-review` on `hotl-workflow-add-rate-limiting.md` and tell me if it is ready to execute.

Use `hotl:subagent-execution` to execute `hotl-workflow-add-rate-limiting.md` in this session.

Use `hotl:pr-reviewing` to review https://github.com/org/repo/pull/123.

Use `hotl:verification-before-completion` before you say this task is done.

Use HOTL for this task and choose the most appropriate skill automatically.
```

## Codex vs Claude Code

| Tool | How HOTL is invoked |
| --- | --- |
| Codex | Natural-language prompts that name a skill, for example `Use hotl:brainstorming ...` |
| Claude Code | Slash commands such as `/hotl:brainstorm` and `/hotl:pr-review` |

## Common Skills

- `hotl:brainstorming` — design with HOTL contracts before implementation
- `hotl:writing-plans` — create `hotl-workflow-<slug>.md` files
- `hotl:document-review` — run structural lint and qualitative review before execution
- `hotl:loop-execution` — autonomous execution with retries
- `hotl:executing-plans` — manual checkpointed execution
- `hotl:subagent-execution` — same-session delegated execution with controller-owned verification
- `hotl:pr-reviewing` — review a PR across description, code, scan, and tests
- `hotl:code-review` — review branch changes against the workflow and HOTL contracts
- `hotl:verification-before-completion` — require test and command output before claiming success

## Updating

```bash
bash ~/.codex/hotl/update.sh
```

If the install drifted onto another branch, the updater switches it back to the
stable `main` branch before pulling the latest HOTL skills.

Restart Codex after updating so it re-discovers the latest skill files.

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl
```
