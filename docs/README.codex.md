# HOTL Plugin for Codex

## Installation

1. Clone the repo:

```bash
# From GitHub (internet)
git clone https://github.com/your-org/hotl-plugin ~/.codex/hotl-plugin

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

## Updating

```bash
cd ~/.codex/hotl-plugin && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl-plugin
```
