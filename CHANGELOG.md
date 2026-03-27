# Changelog

All notable changes to the HOTL plugin will be documented in this file.

## [2.10.0] - 2026-03-26

### Added
- Codex plugin packaging — `.codex-plugin/plugin.json` and `.codex-plugin/marketplace.json` let HOTL be installed as a native Codex plugin for stable, versioned team distribution
- `install.sh --codex-plugin` registers HOTL in the user-global Codex marketplace (`~/.agents/plugins/marketplace.json`)
- `install.sh --codex-plugin --local` registers in the repo-local marketplace for contributors testing plugin packaging
- `update.sh --status` / `update.ps1 -Status` — read-only report of all HOTL install modes with paths and versions
- Plugin detection in `update.sh` and `update.ps1` — warns when HOTL is registered as a Codex plugin and directs to Codex's plugin UI for updates
- Coexistence warnings in installer, updaters, and docs when both Codex install modes are present
- `docs/README.codex.md` "Coexisting With Native Skills" section with recommended migration path

### Changed
- Codex documentation is now plugin-first: Plugin Install (recommended) before Native Skills Install (fallback/development)
- `update.sh` and `update.ps1` Codex messaging renamed from "plugin" to "native-skills install"
- `CLAUDE.md` version file list expanded from 3 to 6 locations (adds `VERSION`, `.codex-plugin/plugin.json`, `.codex-plugin/marketplace.json`)
- Smoke tests extended to validate `.codex-plugin/` manifest versions against `VERSION`

## [2.9.7] - 2026-03-25

### Added
- Native Cline skills mode via `--native-skills` / `-NativeSkills` installer flag
- When enabled: installs 1 operating-model rule + 10 native Cline skills (lazy-loaded, token-efficient) instead of 10 always-on rules
- Install mode persisted in `~/.cline/hotl/.cline-install-mode` — updates honor the persisted mode without heuristic detection
- Mode switch cleanup: native-skills removes legacy workflow rules, legacy removes native skills directory
- Missing marker file defaults to `legacy-rules` for backward compatibility with existing installs
- `update.sh` and `update.ps1` support `--native-skills` / `-NativeSkills` to switch modes during update
- `docs/README.cline.md` documents both install modes with comparison table

## [2.9.6] - 2026-03-25

### Added
- Native Windows (PowerShell) support — `install.ps1`, `install-cline.ps1`, `update.ps1` for installing, updating, and running HOTL on Windows without bash/WSL
- `hooks/session-start.ps1` — native PowerShell session-start hook, no Git Bash dependency
- `hooks/run-hook.cmd` now tries PowerShell first on Windows, with clear error message if neither PowerShell nor bash is available (no more silent failure)
- Cline rule path templating — rules use `__HOTL_HOME__` and `__SCRIPTS_HOME__` placeholders, replaced with OS-appropriate paths at install time
- Windows sections in `.codex/INSTALL.md`, `docs/README.codex.md`, and `docs/README.cline.md`

### Changed
- `install-cline.sh` now replaces path placeholders with Unix paths after copying rules
- `hooks/run-hook.cmd` exits with error code 1 and diagnostic message instead of silent `exit /b 0` when no hook runner is found

## [2.9.5] - 2026-03-24

### Improved
- `hotl-rt` now shows platform-specific `jq` install commands when `jq` is missing (macOS/brew, Debian/apt, Fedora/dnf, Windows/scoop/choco/winget)
- `loop-execution` skill documents graceful fallback to inline execution when `hotl-rt` is unavailable due to missing `jq`
- Added `jq` as a documented prerequisite in README.md, docs/README.codex.md, and docs/README.cline.md

## [2.9.4] - 2026-03-24

### Fixed
- `runtime/hotl-rt` was missing from the Claude Code plugin cache, causing execution to fall back to inline logging instead of proper state persistence and summary rendering
- `install-cline.sh` and `update.sh` Cline section now copy `runtime/hotl-rt` alongside other scripts

### Added
- Session-start hook now injects the HOTL plugin base path so the agent can resolve `hotl-rt` and scripts from any user project working directory
- `skills/loop-execution/SKILL.md` includes a Path Resolution section with per-platform fallback order (Claude Code hook → Codex → Cline → local repo)

## [2.9.3] - 2026-03-23

### Added
- `docs/contracts/README.md` — cross-contract conventions layer with three vocabularies (severity, verdict, execution status) and four convention rules (semantics vs rendering, severity vocabulary, section ordering, clean-report requirement)
- `docs/contracts/execution-report-output.md` — execution report output contract covering report format, execution status vocabulary, final summary semantics, and platform rendering tables

### Changed
- `skills/loop-execution/SKILL.md` — extracted ~200 lines of inline report spec into the execution report contract; retained live execution behavior (step visibility, Codex native progress, verbose view)
- `skills/executing-plans/SKILL.md` and `skills/subagent-execution/SKILL.md` — replaced "inherits from loop-execution" with direct contract reference
- Updated README.md, docs/README.codex.md with contracts directory and execution report contract references

## [2.9.2] - 2026-03-23

### Added
- `docs/contracts/code-review-output.md` — platform-neutral 6-section output contract for code reviews (Scope, Reviewed Dimensions, Findings, What Was Not Covered, Residual Risks, Verdict)
- Codex rendering profile in `docs/README.codex.md` — clean `::code-comment` titles (no `[P1]`/`[P2]`), BLOCK/WARN-only inline annotations, dedup via grouped one-liner

### Changed
- `agents/code-reviewer.md` now references the shared output contract and requires all 6 sections (adds Scope with verification evidence, What Was Not Covered, Residual Risks)
- `skills/code-review/SKILL.md` inline fallback references the same contract with platform-native annotation dedup rule
- Severity vocabulary unified: BLOCK/WARN/NOTE is the only user-facing severity system; `priority`/`confidence` remain as directive metadata only

## [2.9.1] - 2026-03-22

### Added
- Shared review checklists under `docs/checklists/` — four reusable heuristic files (architecture-and-design, security-and-reliability, performance-and-boundary-conditions, removal-and-simplification) plus a README index
- `code-review` inline fallback expanded from 3 to 6 review dimensions: plan alignment, code quality and design, security and reliability, performance and boundary conditions, removal and simplification, HOTL governance
- Clean-review statement in both `code-review` and `pr-reviewing` — when no issues found, reviews must state what was checked, what was not covered, and residual risks/verification gaps
- `pr-reviewing` subagent B now references architecture-and-design and removal-and-simplification checklists
- `pr-reviewing` subagent C now references security-and-reliability checklist with expanded items (race conditions, TOCTOU, unsafe deserialization, weak crypto, rate limits)
- `pr-reviewing` subagent D now references performance-and-boundary-conditions checklist for test edge-case assessment
- Per-dimension clean-review requirement added to `pr-review-output.md` contract (Section 9)
- All checklist references include graceful fallback for portability

## [2.9.0] - 2026-03-22

### Added
- `docs/authoring-skills-vs-agents.md` — canonical reference for writing HOTL skills and agents, covering decision framework (skill vs agent vs inline), repo conventions, 8 annotated common mistakes, 3 real examples, pre-merge checklist, and copy-paste templates for both skills and agents
- Platform-neutral language throughout — no Claude Code-specific tool names or slash commands in the guide

## [2.8.0] - 2026-03-22

### Changed
- `code-review` skill now dispatches the full `code-reviewer` agent as a subagent by default; falls back to inline review (same output contract) on platforms without subagent support
- Context gathered automatically: base branch fallback ladder (PR base → origin/HEAD → main → master), composite review scope (committed + staged + unstaged), workflow/contract detection, verification evidence from hotl-rt artifacts
- Direct reviews use new `direct` review type with final-review verdict model (READY / READY WITH WARNINGS / NOT READY)
- Findings returned only — no auto-fix unless user explicitly asks (then `receiving-code-review` is invoked)
- `requesting-code-review` dispatch template updated with `direct` review type and review type definitions
- Cline code-review rule updated for dispatch-first inline path
- README, Codex docs, Cline docs updated with new code-review descriptions

## [2.7.1] - 2026-03-22

### Fixed
- Codex updater no longer skips stable installs that have local drift or incidental edits. It now snapshots local changes under `~/.codex/backups/hotl/<timestamp>/`, returns the install to `origin/main`, and refreshes the discovered HOTL skills.
- `--force-codex` now has real behavior: discard local Codex install drift without creating a backup, then reset to the latest stable `main`.
- `update.sh` is now `shellcheck` clean.

### Changed
- Codex update docs now recommend the remote updater command so users always fetch the latest updater script before refreshing installed HOTL environments.
- README and Codex install docs now explicitly describe `~/.codex/hotl` as a stable runtime install, not a development clone.
- Smoke coverage now verifies clean updates, branch drift recovery, dirty-install backup behavior, and forced Codex resets.

## [2.7.0] - 2026-03-22

### Added
- `receiving-code-review` skill — governs how agents handle review feedback: Verify → Evaluate → Respond → Implement. Treats review findings as claims to verify, not instructions to obey.
- `requesting-code-review` skill — standardizes review dispatch at executor checkpoints with git range, HOTL contracts, and verification evidence.
- Review checkpoints wired into all executors: `executing-plans` (batch boundaries), `subagent-execution` (controller-owned after meaningful batches), `loop-execution` (final completion + conditional at intermediate gates)
- Dual verdict model: checkpoint reviews use PROCEED/PROCEED WITH WARNINGS/HOLD; final reviews use READY/READY WITH WARNINGS/NOT READY
- Code-reviewer agent: scope-gated architecture & design review for feature-level, cross-module, and high-risk changes
- Code-reviewer agent: graceful degradation without a workflow file (plan alignment skipped, other dimensions still run)
- Code-reviewer agent: verification acknowledgment — does not re-raise issues that verification evidence disproves

### Changed
- Code-reviewer agent now requires file:line + why + fix on all localized findings
- Code-reviewer agent uses review type from request to select checkpoint vs final verdict
- `code-review` skill updated to describe the full review lifecycle (requesting → reviewing → receiving)
- `dispatch-agents` skill references the review lifecycle instead of bare `hotl:code-review`
- `using-hotl` skill index includes both new review lifecycle skills
- Cline rules updated: `hotl-code-review.md`, `hotl-operating-model.md`, `hotl-subagent-execution.md`
- Codex docs updated with review lifecycle skills
- Cline docs updated with enriched code-review rule description
- Adapter templates updated: AGENTS.md, cursor-rules, copilot-instructions
- `docs/how-it-works.md` adds Phase 6: Code Review at Checkpoints
- README.md skills table includes `requesting-code-review` and `receiving-code-review`

## [2.6.0] - 2026-03-20

### Added
- `runtime/hotl-rt` — shared shell runtime that owns execution state persistence and verification
- Runtime API: `init`, `step` (start/verify/retry/block), `gate`, `finalize`, `summary`
- State JSON (`.hotl/state/<run-id>.json`) created at init with full step list — authoritative from the start
- Reports (`.hotl/reports/<run-id>.md`) initialized at init, updated incrementally at each transition
- Atomic verify: runtime runs the command, captures stdout/stderr, transitions to done/fail in one call
- Unsupported verify types now block loudly with a clear reason instead of silently skipping
- Canonical summary payload via `finalize --json` and `summary <run-id> --json`
- 39 runtime unit tests (`test/runtime.bats`)
- 8 runtime integration tests (`test/runtime-integration.bats`) — agent conformance spec
- Test fixtures for runtime testing (`hotl-workflow-runtime-sample.md`, `hotl-workflow-unsupported-verify.md`)

### Changed
- `loop-execution` state machine now calls `hotl-rt` for all state transitions instead of managing persistence inline
- `executing-plans` uses `hotl-rt` for state management instead of inline sidecar lifecycle
- `subagent-execution` controller calls `hotl-rt` — subagents do implementation only
- Run ID format changed from `<slug>-<unix-timestamp>` to `<slug>-<YYYYMMDDTHHMMSSZ>` (human-readable UTC)
- `docs/workflow-format.md` documents the runtime API and new run ID format
- `CLAUDE.md` directory structure includes `runtime/`

## [2.5.0] - 2026-03-19

### Changed
- Execution reporting is now **mandatory**, not advisory — every run must provide live step visibility and a final chat summary
- Platform-specific rendering: Claude Code/Cline use markdown table, Codex uses compact list
- Codex native progress card is required (with chat fallback if unavailable)
- All "advisory" and "prefer" language replaced with "must" in the execution reporting contract
- Platform rendering table added to the canonical execution spec

### Fixed
- Claude Code was incorrectly using compact list for final summary (now uses markdown table)
- Sidecar state must be persisted before any visible progress update (v2.4.1)
- HOTL-owned artifacts (workflow files, design docs, `.hotl/`) excluded from dirty worktree checks (v2.4.0)

### Added
- Durable execution reports at `.hotl/reports/<run-id>.md` with summary table + timestamped event log (v2.3.0)
- `report_detail: full` frontmatter field for verbose verify output
- `dirty_worktree: allow` frontmatter field for non-HOTL dirty files
- 4 new execution scenario tests for mandatory UX contract

## [2.3.1] - 2026-03-19

### Fixed
- Removed the unsupported Codex `sessionStartNotice` update-notification path and kept Codex update checks manual-only.
- Updated smoke coverage so session-start validates clean JSON output without assuming notification delivery.

### Changed
- Codex loop-execution guidance now uses the native progress card as an additive top-level progress surface when available.
- Codex compact execution summaries now keep status and iteration counts inline on each step while preserving table-based summaries for other agents.

## [1.9.1] - 2026-03-13

### Fixed
- **Version correction** — v1.9.0 was published on the wrong commit (pointed at 7a326a8, which was the v1.8.0 codebase). This release is the corrective release that restores monotonic versioning.

### Added
- Non-HOTL document review with generic AI rubric
- Greenfield project detection in brainstorming to avoid wasting tokens in empty projects
- Execution options to Cline brainstorming step 7
- Canonical PR review output contract for cross-platform consistency

### Fixed
- Copy scripts to `~/Documents/Cline/Scripts/` so `document-lint` is reachable

## [1.8.0] - 2026-03-11

### Fixed
- Renamed `pr-review` skill to `pr-reviewing` to avoid command/skill name collision
- Removed `disable-model-invocation` from `pr-review` command

### Added
- Command/skill name collision guard smoke test
- Naming convention documentation

### Changed
- Stabilized Codex HOTL installs
- Clarified Codex HOTL usage docs

## [1.7.0] - 2026-03-11

### Added
- **PR review skill** — multi-dimension parallel subagent PR reviews
- Codex support in `update.sh`

### Fixed
- PR review dimension mismatch, verdict clarity, API example

### Changed
- README restructured for readability and SEO

## [1.6.0] - 2026-03-10

### Added
- **Git branch isolation** — execution skills now create a dedicated branch before running any workflow steps, preventing direct changes to main/master
  - Default branch name derived from workflow slug: `hotl-workflow-add-auth.md` → `hotl/add-auth`
  - Optional `branch:` frontmatter field for teams that need custom naming conventions
  - Optional `worktree: true` for full filesystem isolation via git worktrees
- **Preflight safety checks** — dirty repo hard-fails, existing branches always prompt, non-git repos skip gracefully
- 5 new E2E tests validating preflight consistency across all execution skills

### Changed
- All three execution skills (loop-execution, executing-plans, subagent-execution) share an identical Branch/Worktree Preflight contract
- `workflow-format.md` documents `branch` and `worktree` frontmatter fields
- `writing-plans` skill mentions optional branch/worktree fields in format example
- README updated with Git Branch Isolation section and 6-step workflow overview

## [1.5.0] - 2026-03-10

### Added
- `hotl:subagent-execution` skill and `/hotl:subagent-execute` command for governed same-session workflow execution with delegated subagent steps
- `hotl-subagent-execution.md` rule for Cline users

### Changed
- Workflow parsing and documentation now recognize checkbox-style steps as the preferred format
- Planning guidance now offers three reviewed execution options: loop, manual, and subagent execution
- Codex install docs now list the current HOTL skill set
- README rewritten around Claude Code, Codex, and Cline workflow discovery with explicit execution-mode guidance

## [1.4.0] - 2026-03-10

### Added
- **Unified update script** (`update.sh`) — single command updates both Claude Code and Cline installations, refreshes plugin cache and global rules
- **README rewrite** — end-to-end workflow examples, natural language trigger showcase, SEO-friendly structure
- **Realistic execution example** — Python FastAPI rate limiter walkthrough replacing generic placeholder

## [1.3.0] - 2026-03-10

### Added
- **Document review system** — two-layer validation before execution
  - `scripts/document-lint.sh` — deterministic structural lint for design docs and workflow files (hard gate)
  - `hotl:document-review` skill — AI-driven qualitative review with PASS/REVISE/HUMAN_OVERRIDE_REQUIRED outcomes (soft gate)
  - Cline rule file `hotl-document-review.md` for Cline users
- **Checkbox progress tracking** — `writing-plans` skill now uses `- [ ] **Step N:**` syntax for visible progress in workflow files
- **Execution summary example** in README showing real loop execution output with varied iterations

### Changed
- `using-hotl` skill index updated with `hotl:document-review` entry

## [1.2.0] - 2026-03-10

### Added
- **Cline integration** — 7 global rule files for brainstorming, planning, execution, TDD, debugging, and code review
- `install-cline.sh` — one-command installer that copies rules to `~/Documents/Cline/Rules/` (applies to all projects)
- Works with any Cline API provider: Oracle Code Assist, OpenAI, Anthropic, Google, local models

### Changed
- README rewritten with SEO-friendly content and multi-tool install instructions
- Cline docs (`docs/README.cline.md`) expanded with FAQ, provider compatibility, workflow examples
- `.cline/INSTALL.md` updated to reflect global rules approach

## [1.1.0] - 2026-03-10

### Added
- Marketplace support for Claude Code, Cursor, Codex, Cline, and OpenCode
- Brainstorming skill auto-discovers design docs in `docs/plans/`
- Smoke tests, pre-push hook, and GitHub Actions CI
- `marketplace.json` so the repo can serve as its own plugin marketplace

### Fixed
- Unique workflow filenames (`hotl-workflow-<slug>.md`) to prevent multi-agent conflicts
- Removed unsupported `agents` field from plugin manifest

### Changed
- Workspace artifacts and IDE files added to `.gitignore`

## [1.0.0] - Initial Release

### Added
- Core HOTL skills: brainstorming, writing-plans, executing-plans, loop-execution, dispatch-agents
- TDD, systematic-debugging, code-review, verification-before-completion skills
- SessionStart hook for automatic skill injection
- Slash commands: `/hotl:brainstorm`, `/hotl:write-plan`, `/hotl:loop`, `/hotl:execute-plan`, `/hotl:setup`
- Adapter templates for Codex, Cline, Cursor, and GitHub Copilot
- `install.sh` for manual installation
