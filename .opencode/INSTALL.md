# Installing HOTL for OpenCode

## Prerequisites

- [OpenCode](https://opencode.ai) installed
- Git installed

## Installation Steps

### 1. Clone HOTL

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.config/opencode/hotl
```

### 2. Symlink Skills

```bash
mkdir -p ~/.config/opencode/skills
rm -rf ~/.config/opencode/skills/hotl
ln -s ~/.config/opencode/hotl/skills ~/.config/opencode/skills/hotl
```

### 3. Restart OpenCode

Restart OpenCode. Skills will be automatically discovered.

Verify by asking: "do you have HOTL skills?"

## Usage

### Loading a Skill

Use OpenCode's native `skill` tool to load a specific skill:

```
use skill tool to load hotl/brainstorming
```

### Available Skills

- `hotl:brainstorming` — Design a feature with HOTL contracts before writing code
- `hotl:writing-plans` — Create `docs/plans/YYYY-MM-DD-<slug>-workflow.md`
- `hotl:loop-execution` — Execute workflow files with auto-approve
- `hotl:executing-plans` — Linear execution with checkpoints
- `hotl:tdd` — RED-GREEN-REFACTOR cycle
- `hotl:systematic-debugging` — 4-phase root cause process

## Updating

```bash
cd ~/.config/opencode/hotl && git pull
```

## Uninstalling

```bash
rm -rf ~/.config/opencode/skills/hotl
rm -rf ~/.config/opencode/hotl
```

## Getting Help

- Report issues: https://github.com/yimwoo/hotl-plugin/issues
