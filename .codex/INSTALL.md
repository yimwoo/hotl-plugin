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

## Stable Channel

`~/.codex/hotl` is the HOTL stable channel and should track `origin/main`.
If you want to modify HOTL itself, use a separate clone or worktree elsewhere
and keep this install on `main`.

## Verify

```bash
ls -la ~/.agents/skills/hotl
```

You should see a symlink pointing to your HOTL skills directory.
Codex discovers every entry under `~/.agents/skills/`, so HOTL skills are the
ones coming from `~/.agents/skills/hotl`.

## Available Skills

- `hotl:brainstorming` — Design a feature with HOTL contracts before writing code
- `hotl:writing-plans` — Create a `hotl-workflow-<slug>.md` plan
- `hotl:document-review` — Review design docs and workflow plans before execution
- `hotl:loop-execution` — Execute workflow files with auto-approve
- `hotl:executing-plans` — Linear execution with checkpoints
- `hotl:subagent-execution` — Execute reviewed workflows in-session with delegated subagent steps
- `hotl:pr-review` — Review a PR across description, code, scan, and tests
- `hotl:code-review` — Review branch changes against the workflow and HOTL contracts
- `hotl:verification-before-completion` — Require test and command output before claiming success
- `hotl:tdd` — RED-GREEN-REFACTOR cycle
- `hotl:systematic-debugging` — 4-phase root cause process

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
