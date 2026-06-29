# HOTL Plugin for Codex

HOTL for Codex can be installed either as a Codex plugin or as native skills. Plugin install is the recommended path for reusable, versioned team setup; native skills remain the lightweight option for local development and older Codex builds. Both modes give you the same HOTL skills to brainstorm design docs, write executable workflows, execute, review, and verify changes with more structure.

Codex plugin install has two separate steps:

1. Make HOTL available through a marketplace.
2. Install and enable HOTL in Codex.

The HOTL installer handles the marketplace step. CLI-only users can complete
installation directly with `codex plugin add hotl@codex-plugins`, or use the
interactive `/plugins` browser. Codex app users complete the same install from
the app's Plugins screen. If both surfaces use the same Codex profile,
installing or enabling HOTL once applies to that shared profile.

Official Codex plugin docs:

- [Use and install plugins](https://developers.openai.com/codex/plugins)
- [Build plugins and marketplaces](https://developers.openai.com/codex/plugins/build)

## Installation

| Mode | Best for | Updates managed by |
|---|---|---|
| **Plugin Install** (recommended) | Stable versioned team installs for Codex CLI and app users | Codex plugin lifecycle + HOTL updater |
| **Native Skills Install** (fallback / development) | Fast iteration, contributors, older Codex | `update.sh` |

### Plugin Install (Recommended)

Requires a Codex version with plugin support. The installer clones the HOTL repo
to a source checkout at `~/.codex/plugins/hotl-source/`, registers it in
`~/.agents/plugins/marketplace.json` as a local Codex plugin, and either refreshes
an existing Codex plugin cache or seeds one when no cache exists yet.

1. Clone the repo (or use an existing checkout):

```bash
git clone https://github.com/yimwoo/hotl-plugin /tmp/hotl-plugin
```

2. Run the installer with the `--codex-plugin` flag:

```bash
bash /tmp/hotl-plugin/install.sh --codex-plugin
```

This clones HOTL to `~/.codex/plugins/hotl-source/` and writes a marketplace
entry with `"source": "local"` pointing at that checkout.

3. Finish the install in Codex CLI or the Codex app, then start a new Codex
   session.

#### Codex CLI

Install directly from the registered marketplace:

```bash
codex plugin add hotl@codex-plugins
```

To use the interactive plugin browser instead, start Codex and open the plugin
directory:

```text
codex
/plugins
```

In the CLI plugin browser:

1. Switch to the **Local Plugins** marketplace.
2. Open **HOTL**.
3. Select `Install plugin`.
4. If HOTL is already installed but disabled, press `Space` on the installed
   plugin to enable it.
5. Start a new thread and ask Codex to use HOTL with `@hotl`, or invoke a
   specific bundled skill with `$hotl:skill-name`.

#### Codex App

If you use the Codex app, open **Plugins** and finish the same install there:

1. Switch the source filter to **Local Plugins**.

   ![Codex plugin source set to Local Plugins](assets/codex/plugin-install-step-1-local-plugins.svg)

2. Find **HOTL** in the list and click the `+` button to open the install dialog.

   ![HOTL plugin card in the Local Plugins list](assets/codex/plugin-install-step-2-pick-hotl.svg)

3. Review the plugin details and click **Install HOTL**.

   ![HOTL install dialog in Codex](assets/codex/plugin-install-step-3-confirm.svg)

4. After installation, confirm the HOTL plugin page opens and shows **Try in chat**.

   ![HOTL plugin page after installation](assets/codex/plugin-install-step-4-installed.svg)

If the plugin list is long, use the search box to filter for `HOTL`.

The CLI and app use the same Codex plugin configuration when they run under the
same Codex profile, so you do not need to install HOTL separately in both
surfaces.

**For contributors** testing the plugin from a working copy, use `--local`
to point the marketplace at your current checkout without cloning:

```bash
bash install.sh --codex-plugin --local
```

This writes a repo-local marketplace entry at `.agents/plugins/marketplace.json`
pointing at your checkout directory. Restart Codex, then use `/plugins` in the
CLI or the app Plugins screen to install or enable HOTL from that local
marketplace entry.

**Essential generated marketplace fields:** the real entry also includes the
plugin description, version, author, and Codex interface metadata from
`.codex-plugin/plugin.json`.

```json
{
  "name": "hotl",
  "source": {
    "source": "local",
    "path": "./.codex/plugins/hotl-source"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  },
  "category": "Productivity"
}
```

`update.sh --codex-plugin` refreshes plugin source and cache contents. Marketplace
version metadata and the Codex-installed version are separate lifecycle state;
see Updating below when moving to a new HOTL release.

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

For the **Plugin Install**, HOTL keeps the source checkout at
`~/.codex/plugins/hotl-source/`. Codex reads the marketplace entry and caches the
installed plugin under `~/.codex/plugins/cache/`. Use the HOTL updater to refresh
the source checkout and cache.

### Coexisting With Native Skills

Plugin install does not remove an existing native-skills install at `~/.codex/hotl`
or the symlink at `~/.agents/skills/hotl`.

If both install modes are present, Codex may discover more than one HOTL source.
Because both sources expose the same skill names, HOTL does not guarantee which
source Codex will use.

Recommended migration path:

1. Install HOTL in plugin mode.
2. Restart Codex and confirm the plugin works.
3. Remove `~/.agents/skills/hotl` if you want plugin mode to be the only active
   Codex install.
4. Optionally remove `~/.codex/hotl` too if you no longer want the native-skills
   checkout on disk.

If you want the fastest local iteration workflow as a HOTL contributor, keep using
Native Skills Install instead of plugin mode.

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

### Governed Driver Selection

`governed-execution` is the preferred workflow execution entry point. Its
default `auto` mode is intentionally conservative: merely finding the `codex`
executable does not prove that native execution is entitled, enabled, or usable,
so HOTL selects the generic `hotl-rt` fallback unless native execution is
explicitly enabled.

Use either of these opt-in paths:

```bash
HOTL_CODEX_NATIVE=1 runtime/drivers/codex.sh preflight docs/plans/<workflow>.md
runtime/drivers/codex.sh launch docs/plans/<workflow>.md --mode native
```

`--mode fallback` always selects the generic driver. Host permissions,
sandboxes, managed policy, and approvals remain authoritative in every mode.
Native host output never replaces the state-derived completion receipt. See
[Host-Native Drivers](host-native-drivers.md), the
[migration guide](migration-host-native.md), and the
[portable workflow and receipt contract](contracts/portable-workflow-and-receipt.md).

### Optional Codex Custom Agents

HOTL also ships Codex custom agent templates under `adapters/codex-agents/` for
roles such as reviewer, architect, researcher, QA, dev, and PM. Codex only
discovers project-scoped custom agents when those TOML files live in the project
being worked on as `.codex/agents/*.toml`, so plugin installation alone does not
make them available in every target repository.

To install the templates into a project, run the helper from that project root:

```bash
bash ~/.codex/plugins/hotl-source/scripts/hotl-install-codex-agents.sh
```

For native skills installs, use:

```bash
bash ~/.codex/hotl/scripts/hotl-install-codex-agents.sh
```

The helper creates `.codex/agents/`, copies HOTL's tracked templates into it,
and skips existing files unless `--force` is explicitly provided.

When a HOTL skill needs a bundled helper such as `document-lint.sh`,
`render-execution-summary.sh`, or `runtime/hotl-rt`, resolve it from the HOTL
install rather than from the repo being worked on. In Codex, the relevant
install roots are:

- Native skills: `~/.codex/hotl/`
- Plugin source checkout: `~/.codex/plugins/hotl-source/`
- Plugin cache fallback: `~/.codex/plugins/cache/codex-plugins/hotl/*/`

There is no `/hotl:brainstorm` or `/hotl:pr-review` command syntax in Codex.
Instead, either mention the plugin with `@hotl` and describe the task in
natural language, or explicitly mention an installed skill such as
`$hotl:brainstorming`, `$hotl:writing-plans`, or `$hotl:pr-reviewing`. Plain
text like `hotl:brainstorming` is not a reliable user-facing invocation form in
Codex. In the picker, Codex may display these as title-cased labels like
`Hotl:brainstorming`.

## How To Invoke HOTL Skills In Codex

You can invoke HOTL in two ways:

- Mention the plugin with `@hotl` and describe the task in natural language.
- Explicitly mention a specific installed skill with `$hotl:skill-name` when you want a precise workflow.

If you do not name a skill, Codex can still choose from the installed HOTL skills
based on your request. Use the `$hotl:skill-name` form when you want to force a specific skill.
Codex may display these skills in the UI as title-cased labels such as
`Hotl:brainstorming` or `Hotl:code-review`.

Examples:

```text
Use `@hotl` to compare OAuth and API-key auth before writing code.

Please use HOTL to compare OAuth and API-key auth before writing code.

Use `$hotl:writing-plans` to create `docs/plans/2026-04-22-add-rate-limiting-workflow.md`.

After a workflow is saved, prefer `$hotl:governed-execution`, or use `$hotl:loop-execution`, `$hotl:executing-plans`,
`$hotl:subagent-execution`, or `$hotl:resuming` with the workflow filename
instead of Claude-style `/hotl:*` commands.

Review `docs/plans/2026-04-22-add-rate-limiting-workflow.md` with HOTL and tell me if it is ready to execute.

Use `$hotl:subagent-execution` to execute `docs/plans/2026-04-22-add-rate-limiting-workflow.md` in this session.

Use `$hotl:governed-execution` to execute `docs/plans/2026-04-22-add-rate-limiting-workflow.md` with the best available governed driver.

Use `$hotl:loop-execution` to execute `docs/plans/2026-04-22-add-rate-limiting-workflow.md` in this session.

Use `$hotl:executing-plans` to execute `docs/plans/2026-04-22-add-rate-limiting-workflow.md` with manual checkpoints.

Use `$hotl:resuming` to continue `docs/plans/2026-04-22-add-rate-limiting-workflow.md`.

After execution finishes, use `$hotl:finishing-a-development-branch` for the run id to merge back, publish/create a PR, keep the execution checkout, or discard it.

Use `$hotl:pr-reviewing` to review https://github.com/org/repo/pull/123.

Before you say this task is done, use `$hotl:verification-before-completion`.

Use HOTL for this task and choose the most appropriate skill automatically.
```

## Codex vs Claude Code

| Tool | How HOTL is invoked |
| --- | --- |
| Codex | Natural-language prompts with `@hotl`, or explicit skill mentions such as `$hotl:brainstorming` |
| Claude Code | Slash commands such as `/hotl:brainstorm` and `/hotl:pr-review` |

## Common Skills

- `brainstorming` — design with HOTL contracts before implementation
- `writing-plans` — create `docs/plans/YYYY-MM-DD-<slug>-workflow.md` files
- `document-review` — run structural lint and qualitative review before execution
- `governed-execution` — preferred native-or-fallback execution router with evidence receipts
  - **Driver selection:** auto mode uses fallback unless `HOTL_CODEX_NATIVE=1` or `--mode native` explicitly opts into the experimental Codex driver
  - **Portable governance:** sensitive actions, budgets, and verify-first recovery follow `docs/contracts/policy-budget-recovery.md`
  - **Adoption tools:** `scripts/hotl-adoption-report.sh` is read-only; `scripts/hotl-memory-proposal.sh` only proposes memory candidates and never writes them directly
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
- `finishing-a-development-branch` — closes the execution lifecycle intentionally
  - **Execution provenance:** uses `source_branch`, `branch`, `execution_root`, and `worktree_path` from HOTL runtime state so authoring and execution checkouts stay distinguishable
  - **Helper path:** use `scripts/hotl-finish-execution.sh` to merge back, publish, keep, or discard while recording the disposition in HOTL state
  - **Safety rule:** merge/discard must not delete the durable report; isolated worktree runs preserve `.hotl/state/` and `.hotl/reports/` back into the repo checkout before cleanup
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
- `skill-authoring` — create, edit, or review HOTL behavior-shaping skill and agent instructions

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

The updater fetches the latest script first, then scans for all supported HOTL
installs and refreshes every one it finds in the same run. If you have Claude
Code, Codex, and Cline installs side by side, one updater run will process them
sequentially.

For the native-skills Codex install, the updater refreshes the stable install at
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

The standard curl one-liner also updates the plugin source checkout if it exists:

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

Or update only the plugin checkout:

```bash
bash ~/.codex/plugins/hotl-source/update.sh --codex-plugin
```

If the source checkout has local changes, they are backed up to
`~/.codex/backups/hotl-plugin/<timestamp>/` before resetting.
Use `--force-codex-plugin` to skip the backup.

Important:

- `update.sh --codex-plugin` updates `~/.codex/plugins/hotl-source`
- It also refreshes the local Codex plugin cache at `~/.codex/plugins/cache/codex-plugins/hotl/` when present
- It does not rewrite the HOTL entry's version in `~/.agents/plugins/marketplace.json`
  or reconcile the version recorded in Codex's installed-plugin configuration
- If you still have the old copied-bundle install at `~/.codex/plugins/hotl`,
  the updater reports it and skips it; migrate with `bash install.sh --codex-plugin`

For a source/cache-only refresh, restart Codex after updating. When moving to a
new released version and you also want marketplace and installed-version metadata
to match, rerun the installer to rewrite the marketplace entry, then reconcile
HOTL through the plugin CLI or UI:

```bash
bash ~/.codex/plugins/hotl-source/install.sh --codex-plugin
codex plugin add hotl@codex-plugins
```

If the CLI reports that HOTL is already installed rather than reconciling it,
use the Plugins UI to update it, or remove and add the plugin again. Removing the
plugin does not remove the source checkout.

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

First remove the installed plugin and its active cache/configuration:

```bash
codex plugin remove hotl@codex-plugins
```

That is sufficient to stop using HOTL. To also remove the optional local source
checkout and marketplace listing:

**macOS / Linux:**

```bash
rm -rf ~/.codex/plugins/hotl-source
# Optionally edit ~/.agents/plugins/marketplace.json and remove only the hotl entry
```

**Repo-local:** Delete `.agents/plugins/marketplace.json` or remove the `hotl` entry from it.
