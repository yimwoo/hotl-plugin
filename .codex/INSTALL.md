# Installing HOTL for Codex

Enable HOTL skills in Codex via native skill discovery.

## Prerequisites

- Git

## Installation

1. **Clone the HOTL repository:**
   ```bash
   git clone https://github.com/yimwoo/hotl-plugin.git ~/.codex/hotl
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\hotl" "$env:USERPROFILE\.codex\hotl\skills"
   ```

3. **Restart Codex** to discover the skills.

## Verify

```bash
ls -la ~/.agents/skills/hotl
```

You should see a symlink pointing to your HOTL skills directory.

## Available Skills

- `hotl:brainstorming` — Design a feature with HOTL contracts before writing code
- `hotl:writing-plans` — Create a `hotl-workflow.md` plan
- `hotl:loop-execution` — Execute `hotl-workflow.md` with auto-approve
- `hotl:executing-plans` — Linear execution with checkpoints
- `hotl:tdd` — RED-GREEN-REFACTOR cycle
- `hotl:systematic-debugging` — 4-phase root cause process

## Updating

```bash
cd ~/.codex/hotl && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl
```
