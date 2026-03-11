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

## How It Works

Codex discovers skills in `~/.agents/skills/` at startup. The `using-hotl` skill
is loaded automatically and guides Codex to use the right skill for each task.
Codex uses the skill files directly. Claude-style slash commands such as
`/hotl:pr-review` are not part of the Codex integration.
There is no `/hotl:brainstorm` or `/hotl:pr-review` command syntax in Codex. Ask Codex to use `hotl:brainstorming`, `hotl:writing-plans`, `hotl:pr-review`, or another HOTL skill in plain English.

## How To Invoke HOTL Skills In Codex

Ask Codex to use a skill by name inside your prompt. If you do not name a skill,
Codex can still choose from the installed HOTL skills based on your request, but
being explicit is better when you want a specific workflow.

Examples:

```text
Ask Codex to use `hotl:brainstorming` before writing code for this feature.

Use `hotl:writing-plans` to create a hotl-workflow file for adding rate limiting.

Use `hotl:document-review` on hotl-workflow-add-rate-limiting.md.

Use `hotl:pr-review` to review https://github.com/org/repo/pull/123.

Use `hotl:code-review` on this branch before merge.

Use HOTL for this task and choose the most appropriate skill automatically.
```

## Codex vs Claude Code

| Tool | How HOTL is invoked |
| --- | --- |
| Codex | Natural-language prompts that name a skill, for example `Use hotl:brainstorming ...` |
| Claude Code | Slash commands such as `/hotl:brainstorm` and `/hotl:pr-review` |

## Key Skills

- `hotl:brainstorming` — design with HOTL contracts before implementation
- `hotl:writing-plans` — create `hotl-workflow-<slug>.md` files
- `hotl:document-review` — run structural lint and qualitative review before execution
- `hotl:loop-execution` — autonomous execution with retries
- `hotl:executing-plans` — manual checkpointed execution
- `hotl:subagent-execution` — same-session delegated execution with controller-owned verification

## Updating

```bash
cd ~/.codex/hotl && git pull
```

Restart Codex after updating so it re-discovers the latest skill files.

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl
```
