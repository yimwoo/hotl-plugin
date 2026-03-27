# Installing the HOTL Plugin for Codex

Install HOTL in Codex via native skill discovery. HOTL is a Human-on-the-Loop AI coding workflow that adds structured planning, execution, review, and verification skills to Codex.

If you want the recommended Codex plugin install with UI screenshots, use
[`docs/README.codex.md`](../docs/README.codex.md).

## Prerequisites

- Git

## Installation

### macOS / Linux

1. **Clone the HOTL repository:**
   ```bash
   git clone https://github.com/yimwoo/hotl-plugin.git ~/.codex/hotl
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
   ```

3. **Restart Codex** to discover the skills.

### Windows (PowerShell)

1. **Clone the HOTL repository:**
   ```powershell
   git clone https://github.com/yimwoo/hotl-plugin.git "$env:USERPROFILE\.codex\hotl"
   ```

2. **Create the skills junction:**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\hotl" "$env:USERPROFILE\.codex\hotl\skills"
   ```

3. **Restart Codex** to discover the skills.

## Stable Channel

`~/.codex/hotl` (macOS/Linux) or `%USERPROFILE%\.codex\hotl` (Windows) is the HOTL stable channel and should track `origin/main`.
If you want to modify HOTL itself, use a separate clone or worktree elsewhere
and keep this install on `main`.

## Verify

**macOS / Linux:**
```bash
ls -la ~/.agents/skills/hotl
```

**Windows (PowerShell):**
```powershell
Get-Item "$env:USERPROFILE\.agents\skills\hotl"
```

You should see a symlink (or junction on Windows) pointing to your HOTL skills directory.
Codex discovers every entry under `~/.agents/skills/`, so HOTL skills are the
ones coming from `~/.agents/skills/hotl`.

## Available Skills

- `brainstorming` — Design a feature with HOTL contracts before writing code
- `writing-plans` — Create a `hotl-workflow-<slug>.md` plan
- `document-review` — Review design docs and workflow plans before execution
- `loop-execution` — Execute workflow files with auto-approve
- `executing-plans` — Linear execution with checkpoints
- `subagent-execution` — Execute reviewed workflows in-session with delegated subagent steps
- `pr-reviewing` — Review a PR across description, code, scan, and tests
- `code-review` — Review branch changes against the workflow and HOTL contracts
- `verification-before-completion` — Require test and command output before claiming success
- `tdd` — RED-GREEN-REFACTOR cycle
- `systematic-debugging` — 4-phase root cause process

## Running A Saved Plan In Codex

Codex does not use Claude-style `/hotl:*` slash commands. After HOTL writes a
workflow file, continue with the matching skill name instead:

- Requests like `Use $loop-execution to run hotl-workflow-<slug>.md` for autonomous execution
- Requests like `Use $executing-plans to run hotl-workflow-<slug>.md` for manual checkpoints
- Requests like `Use $subagent-execution to run hotl-workflow-<slug>.md` for delegated execution
- Requests like `Use $resuming to continue hotl-workflow-<slug>.md` for interrupted runs

## Updating

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.ps1" -OutFile "$env:TEMP\hotl-update.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\hotl-update.ps1"
```

Or if already cloned:

**macOS / Linux:**
```bash
bash ~/.codex/hotl/update.sh
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hotl\update.ps1"
```

This is the recommended Codex update path because it downloads the newest
updater first.

`~/.codex/hotl` is the HOTL stable channel. If it drifted onto another branch,
the updater switches it back to `main`. If it has local changes, the updater
backs them up under `~/.codex/backups/hotl/<timestamp>/` and then resets the
stable install to the latest `origin/main`.

Use `--force-codex` (bash) or `-ForceCodex` (PowerShell) only when you want to discard
local Codex changes without creating that backup.

Restart Codex after updating so it re-discovers the latest skill files.

## Uninstalling

**macOS / Linux:**
```bash
rm ~/.agents/skills/hotl
rm -rf ~/.codex/hotl
```

**Windows (PowerShell):**
```powershell
Remove-Item "$env:USERPROFILE\.agents\skills\hotl" -Force
Remove-Item -Recurse -Force "$env:USERPROFILE\.codex\hotl"
```
