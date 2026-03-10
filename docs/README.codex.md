# HOTL Plugin for Codex

## Installation

1. Clone the repo:

```bash
# From GitHub (internet)
git clone https://github.com/yimwoo/hotl-plugin ~/.codex/hotl-plugin

# From OraHub (corporate network)
git clone git@orahub.oci.oraclecorp.com:.../hotl-plugin ~/.codex/hotl-plugin
```

2. Create the skills symlink:

```bash
mkdir -p ~/.agents/skills
ln -s ~/.codex/hotl-plugin/skills ~/.agents/skills/hotl
```

3. Restart Codex.

## How It Works

Codex discovers skills in `~/.agents/skills/` at startup. The `using-hotl` skill
is loaded automatically and guides Codex to use the right skill for each task.

## Key Skills

- `hotl:brainstorming` — design with HOTL contracts before implementation
- `hotl:writing-plans` — create `hotl-workflow-<slug>.md` files
- `hotl:document-review` — run structural lint and qualitative review before execution
- `hotl:loop-execution` — autonomous execution with retries
- `hotl:executing-plans` — manual checkpointed execution
- `hotl:subagent-execution` — same-session delegated execution with controller-owned verification

## Updating

```bash
cd ~/.codex/hotl-plugin && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl-plugin
```
