# Installing the HOTL Plugin for Codex

Install HOTL in Codex as a Codex plugin. HOTL is a Human-on-the-Loop AI coding workflow that adds structured design, workflow execution, review, and verification skills to Codex.

The plugin install works for both Codex CLI and Codex app users. CLI-only users
do not need the app: after the installer registers HOTL, use `/plugins` in
Codex CLI to install or enable it. Native skill discovery is still available as
a fallback for older Codex builds and local HOTL development.

## Prerequisites

- Git
- A Codex build with plugin support

## Installation

### Plugin Install

1. Clone the HOTL repository:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git /tmp/hotl-plugin
```

2. Register HOTL as a local Codex plugin:

```bash
bash /tmp/hotl-plugin/install.sh --codex-plugin
```

3. Restart Codex.

4. In Codex CLI, open the plugin directory and install HOTL:

```text
codex
/plugins
```

Switch to **Local Plugins**, open **HOTL**, and select `Install plugin`. If HOTL
is already installed but disabled, press `Space` to enable it.

Codex app users can use the same installer, then open **Plugins**, switch to
**Local Plugins**, and install HOTL there.

## Native Skills Fallback

Use this path for older Codex versions or HOTL development.

### macOS / Linux

1. Clone the HOTL repository:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.codex/hotl
```

2. Create the skills symlink:

```bash
mkdir -p ~/.agents/skills
ln -s ~/.codex/hotl/skills ~/.agents/skills/hotl
```

3. Restart Codex to discover the skills.

### Windows (PowerShell)

1. Clone the HOTL repository:

```powershell
git clone https://github.com/yimwoo/hotl-plugin.git "$env:USERPROFILE\.codex\hotl"
```

2. Create the skills junction:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\hotl" "$env:USERPROFILE\.codex\hotl\skills"
```

3. Restart Codex to discover the skills.

## Stable Channel

`~/.codex/hotl` (macOS/Linux) or `%USERPROFILE%\.codex\hotl` (Windows) is the HOTL stable channel and should track `origin/main`.
If you want to modify HOTL itself, use a separate clone or worktree elsewhere
and keep this install on `main`.

## Verify

### Plugin Install

Start Codex and open `/plugins`. HOTL should appear under **Local Plugins** and
show as installed/enabled after you complete the install step.

You can also confirm that the installer registered the source checkout:

```bash
test -d ~/.codex/plugins/hotl-source && test -f ~/.agents/plugins/marketplace.json
```

### Native Skills Fallback

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
- `writing-plans` — Create `docs/plans/YYYY-MM-DD-<slug>-workflow.md`
- `document-review` — Review design docs and workflow files before execution
- `loop-execution` — Execute workflow files with auto-approve
- `executing-plans` — Linear execution with checkpoints
- `subagent-execution` — Execute reviewed workflows in-session with delegated subagent steps
- `finishing-a-development-branch` — Merge back, publish/PR, keep, or discard an execution branch/worktree
- `pr-reviewing` — Review a PR across description, code, scan, and tests
- `code-review` — Review branch changes against the workflow and HOTL contracts
- `verification-before-completion` — Require test and command output before claiming success
- `tdd` — RED-GREEN-REFACTOR cycle
- `systematic-debugging` — 4-phase root cause process

## Running A Saved Workflow In Codex

Codex does not use Claude-style `/hotl:*` slash commands. After HOTL writes a
workflow file, continue with the matching skill name instead:

- Requests like `Use $hotl:loop-execution to run docs/plans/YYYY-MM-DD-<slug>-workflow.md` for autonomous execution
- Requests like `Use $hotl:executing-plans to run docs/plans/YYYY-MM-DD-<slug>-workflow.md` for manual checkpoints
- Requests like `Use $hotl:subagent-execution to run docs/plans/YYYY-MM-DD-<slug>-workflow.md` for delegated execution
- Requests like `Use $hotl:resuming to continue docs/plans/YYYY-MM-DD-<slug>-workflow.md` for interrupted runs
- Requests like `Use $hotl:finishing-a-development-branch for run <run-id>` after execution to merge back, publish, keep, or discard the execution checkout

## Updating

### Plugin Install

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Or update only the plugin checkout:

```bash
bash ~/.codex/plugins/hotl-source/update.sh --codex-plugin
```

Restart Codex after updating so it reloads the plugin files.

### Native Skills Fallback

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

### Plugin Install

```bash
rm -rf ~/.codex/plugins/hotl-source
# Edit ~/.agents/plugins/marketplace.json and remove the hotl entry
```

### Native Skills Fallback

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
