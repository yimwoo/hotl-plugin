# HOTL Plugin for Codex

HOTL for Codex can be installed either as a native Codex plugin or as native skills. Plugin install is the recommended path for reusable, versioned team setup; native skills remain the lightweight option for local development and older Codex builds. Both modes give you the same HOTL skills to brainstorm, plan, execute, review, and verify changes with more structure.

## Installation

| Mode | Best for | Updates managed by |
|---|---|---|
| **Plugin Install** (recommended) | Stable versioned team installs | Codex plugin lifecycle |
| **Native Skills Install** (fallback / development) | Fast iteration, contributors, older Codex | `update.sh` |

### Plugin Install (Recommended)

Requires a Codex version with plugin support. Register HOTL as a Codex plugin for
stable, versioned team distribution. Codex manages the plugin cache and lifecycle —
no manual symlinks needed.

1. Clone the repo (or use an existing checkout):

```bash
git clone https://github.com/yimwoo/hotl-plugin /tmp/hotl-plugin
```

2. Run the installer with the `--codex-plugin` flag:

```bash
bash /tmp/hotl-plugin/install.sh --codex-plugin
```

This merges the HOTL plugin entry into `~/.agents/plugins/marketplace.json`.

3. Restart Codex and install/enable HOTL from the plugin list.

**For contributors** testing the plugin packaging from a repo checkout, use `--local`
to write to the repo-local marketplace instead of your user-global config:

```bash
bash install.sh --codex-plugin --local
```

Plugin updates are handled through Codex's plugin refresh flow, not `update.sh`.

### Native Skills Install (Fallback / Development)

Works with all Codex versions. Clone the repo and symlink the skills directory.
This gives you direct access to skill files for fast iteration and development.

#### macOS / Linux

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

#### Windows (PowerShell)

1. Clone the repo:

```powershell
# From GitHub (internet)
git clone https://github.com/yimwoo/hotl-plugin "$env:USERPROFILE\.codex\hotl"

# From OraHub (corporate network)
git clone git@orahub.oci.oraclecorp.com:.../hotl-plugin "$env:USERPROFILE\.codex\hotl"
```

2. Create the skills junction:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\hotl" "$env:USERPROFILE\.codex\hotl\skills"
```

3. Restart Codex.

## Stable Channel

For the **Native Skills Install**, `~/.codex/hotl` is the HOTL stable channel and
should track `origin/main`. Do not do feature work inside that directory. If you
want to develop HOTL itself, use a separate clone or worktree somewhere else and
keep `~/.codex/hotl` for the version Codex discovers.

For the **Plugin Install**, Codex manages the cached copy. Updates come through
Codex's plugin lifecycle.

## How It Works

Both install modes expose the same HOTL skills to Codex. The difference is how
Codex discovers them:

- **Plugin Install:** Codex installs HOTL from the marketplace entry and caches
  the plugin under `~/.codex/plugins/cache/`. Skills are discovered from the
  plugin's skill directory.
- **Native Skills Install:** Codex discovers skills in `~/.agents/skills/` at
  startup. The symlink at `~/.agents/skills/hotl` points to the canonical skill
  files. Codex discovers every entry under `~/.agents/skills/`, so the Installed
  skills screen mixes HOTL with any other installed skill packs.

In both cases, the `using-hotl` skill provides the HOTL skill index and routing
guidance for the rest of the skill set. Codex uses the skill files directly.

There is no `/hotl:brainstorm` or `/hotl:pr-review` command syntax in Codex.
Instead, describe the task in natural language and let HOTL route it, or
explicitly mention an installed skill such as `$brainstorming`, `$writing-plans`,
or `$pr-reviewing`.

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
  - **Output contract:** `docs/contracts/execution-report-output.md` defines the execution report schema, status vocabulary, and platform rendering tables
  - **Optional dependency:** State persistence and resumable execution require [`jq`](https://jqlang.github.io/jq/). Without it, HOTL still works but runs without state files or durable reports.
  - **Codex native progress (mandatory):** HOTL must use the native progress card as the primary live step visibility surface. If the native tool is unavailable or errors, immediately switch to per-step chat logs.
  - **Codex final summary:** must use compact step list in chat (not wide markdown table). Durable report keeps the full table.
  - **Codex helper path:** use `scripts/finalize-codex-summary.sh` so finalize and rendering happen sequentially from one helper instead of separate ad hoc commands.
  - **Codex final response:** the rendered compact summary must appear directly in the final assistant message as visible chat text. A narrative wrap-up can follow, but cannot replace the summary lines.
  - **Current step helper:** use `scripts/show-codex-current-step.sh` when you need an explicit current-step readout in Codex chat.
  - **Deterministic renderer:** `scripts/finalize-codex-summary.sh` delegates to `scripts/render-execution-summary.sh`, which remains the source of truth for Codex summary formatting.
- `executing-plans` — manual checkpointed execution (references same output contract)
- `subagent-execution` — same-session delegated execution with controller-owned verification (references same output contract)
- `pr-reviewing` — review a PR across description, code, scan, and tests
  - **Output contract:** `docs/contracts/pr-review-output.md` defines the canonical 9-section review schema
  - **Codex rendering (advisory):** emit platform-native inline findings first (e.g., `::code-comment` directives for BLOCK and WARN findings with file:line), then render the full 9-section structured summary. Use plain markdown for the summary.
- `code-review` — user-facing entry point for code review; dispatches the full `code-reviewer` agent by default, returns findings only
  - **Output contract:** `docs/contracts/code-review-output.md` defines the canonical 6-section review schema
  - **Codex rendering profile:**
    - Emit `::code-comment` directives only for actionable, file-localized defects at BLOCK or WARN severity
    - Keep `priority` and `confidence` as machine-readable metadata in the directive — do not surface `[P1]`/`[P2]` in the title. Titles must be plain descriptive text (e.g., `"Debug server exposed on all interfaces"`)
    - Workflow/governance findings, NOTE-severity observations, and findings without a specific file:line stay in the markdown summary only — no `::code-comment`
    - `::code-comment` is additive rendering — the full 6-section structured summary is always emitted regardless of how many annotations exist
    - Dedup: when inline annotations are emitted, the Findings section uses a grouped one-liner (1–5: category breakdown; 6+: collapsed) instead of restating each finding
- `requesting-code-review` — dispatched by executors at review checkpoints with git range, contracts, and verification evidence
- `receiving-code-review` — governs how agents handle review findings: verify each claim against the codebase and HOTL contracts before acting (Verify → Evaluate → Respond → Implement)
- `verification-before-completion` — require test and command output before claiming success

## Updating

### Native Skills Install

Use `update.sh` to update the native skills install at `~/.codex/hotl`.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Or if already cloned:

```bash
bash ~/.codex/hotl/update.sh
```

**Windows (PowerShell):**

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.ps1" -OutFile "$env:TEMP\hotl-update.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\hotl-update.ps1"
```

Or if already cloned:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hotl\update.ps1"
```

---

The updater fetches the latest script first, then refreshes the stable install at
`~/.codex/hotl` (macOS/Linux) or `%USERPROFILE%\.codex\hotl` (Windows).

If the install drifted onto another branch, the updater switches it back to
the stable `main` branch before syncing.
If it finds local changes in the Codex install, it saves a snapshot under
`~/.codex/backups/hotl/<timestamp>/` (or `%USERPROFILE%\.codex\backups\hotl\` on Windows) and then resets the stable install to the
latest `origin/main`.

If you intentionally want to discard local Codex changes without saving that
backup, run:

```bash
bash ~/.codex/hotl/update.sh --force-codex        # macOS/Linux
```

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hotl\update.ps1" -ForceCodex   # Windows
```

To check if an update is available without updating:

```bash
bash ~/.codex/hotl/update.sh --check               # macOS/Linux
```

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hotl\update.ps1" -Check        # Windows
```

Codex does not have a guaranteed HOTL startup-notice path for native skills
installs, so do not rely on a SessionStart update banner. Use the manual check
command above when you want to verify whether `~/.codex/hotl` is behind.

Restart Codex after updating so it re-discovers the latest skill files.

### Plugin Install

Plugin updates are managed through Codex's plugin lifecycle. When a new HOTL
version is available, refresh or reinstall the plugin through Codex's plugin UI.
`update.sh` does not apply to plugin installs.

## Codex Manual Canary

Use this short canary when you want to validate Codex execution UX in the real app:

1. Run a HOTL workflow that has at least one gate and at least one verified implementation step.
2. Confirm the native progress card appears immediately after runtime initialization.
3. Confirm only one workflow step is shown as active at a time.
4. Confirm the run ends with a visible final chat summary that includes every step, its status, and its attempt count or gate marker.
5. If the native progress card does not appear or errors, confirm HOTL falls back to per-step chat logs and still shows the final chat summary.

Expected compliant final Codex response shape:

```text
Execution Summary

✓ Step 1: Write failing tests - Done (1 attempt)
✓ Step 2: Implement auth logic - Done (3 attempts)
⚡ Step 3: Security review gate - Auto-approved (-)
✓ Step 4: Run full test suite - Done (65 tests, 1 attempt)
✓ Step 5: Human review - Approved (1 attempt)

Tests: 65 passed
Behavior: walkthrough completed in the app
```

Non-compliant example:

```text
The workflow finished successfully. Tests passed and the app looks good.
```

That prose-only wrap-up is not enough because it omits the rendered step-by-step execution summary.

When the repo includes `scripts/render-execution-summary.sh`, use it as the source of truth for final-summary formatting. If chat output disagrees with `.hotl/reports/<run-id>.md` or the renderer output, trust the runtime artifacts first.

## Uninstalling

### Native Skills Install

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

### Plugin Install

Uninstall HOTL through Codex's plugin UI. To also remove the marketplace entry:

**macOS / Linux:** Edit `~/.agents/plugins/marketplace.json` and remove the `hotl` entry.

**Repo-local:** Delete `.agents/plugins/marketplace.json` or remove the `hotl` entry from it.
