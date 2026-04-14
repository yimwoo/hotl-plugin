# Multi-Phase Initiative Support — Design

**Status:** Draft — for review
**Date:** 2026-04-14
**Owner:** yimwoo
**Co-authors:** @pm, @architect (agent review cycle)
**Related:** `CLAUDE.md`, `skills/brainstorming/SKILL.md`, `skills/writing-plans/SKILL.md`, `skills/setup-project/SKILL.md`, `docs/how-it-works.md`

---

## 1. Problem statement

hotl-plugin today is shaped around a single-artifact workflow: one brainstorm produces one design doc, one plan produces one executable workflow, one feature ships. This works well for solo devs, small teams, and any change that fits in a single phase of work.

Large projects — v1/v2 rewrites, platform migrations, multi-service rollouts, AI platform build-outs — do not fit that shape. They need a **strategic layer** above the tactical plan: a durable document that names the initiative, lists its phases, fixes non-goals, and coordinates multiple plan docs that will be written and executed over weeks or months.

**Who is hurt today?** Users running multi-phase initiatives (e.g. the ODAP AI Assurance build-out) currently hand-roll their own taxonomy outside the plugin: `docs/designs/`, `docs/requirements/`, `docs/decisions/`, per-initiative playbooks, operating-model specs. The plugin is unaware of any of it. They get none of HOTL's gates, logs, or skill coordination at the initiative layer.

**What evidence do we have?** One documented instance: the ODAP project at `/Users/yimwu/Documents/workspace/oracledb/odap/docs/` — a full doc-driven multi-phase workflow the user built by hand because the plugin did not support it. The taxonomy, playbook, and operating-model model we inherit here come from that real-world usage.

---

## 2. Vision / intent

When this ships, a user starting a large initiative runs `/hotl:brainstorm`, answers "initiative" when asked the scope question, and gets a durable strategic design doc at `docs/designs/<topic>.md` listing phases, non-goals, and maturity stages. Each phase then flows through the existing tactical path — `docs/plans/*-plan.md` → `hotl-workflow-*.md` → execution — unchanged. Users running a small feature or bugfix never see the initiative tier; their workflow shape, commands, locations, and gates are identical to today.

One sentence: **add a strategic tier above the tactical one, opt-in, with no workflow-semantics change for existing small-project users.**

**Scope of "no change."** We promise no workflow change — same commands, same directories, same execution model, same gate behavior, no new files written without opt-in. One cosmetic naming change applies to all users: new tactical plans get the suffix `-plan.md` instead of `-design.md` (see §11 and §12 Slice 2 for consumer coverage). Existing `-design.md` files are never renamed or rewritten. This is the only user-visible change for non-opted-in users.

---

## 3. Non-goals

- **Not replacing ODAP's project-specific docs.** We generalize the structure, not the content. ODAP-specific prompts, role names, and domain taxonomy stay in the ODAP repo.
- **Not encoding a role model in the runtime.** Roles like `@pm`, `@architect`, `@dev` are project policy, not plugin infrastructure. They belong in the rendered adapter files (`AGENTS.md`, `CLAUDE.md`), not in `hotl-rt`.
- **Not branching runtime behavior by scale flag.** No `--scale=enterprise`. No "small mode" vs "enterprise mode." One product, opt-in depth via config.
- **Not auto-detecting project size.** The plugin never inspects repo size, file count, or team metadata to decide which flow to offer. User opts in explicitly in `/hotl:setup` or by answering the brainstorming scope question.
- **Not scaffolding empty directories.** Any folder the scaffolder creates must be consumed by at least one skill. No filing cabinets.
- **Not breaking workflow semantics for any user.** Commands, directories, execution model, and gate behavior stay the same for non-opted-in users. The only user-visible change is a cosmetic rename of new tactical output from `-design.md` to `-plan.md` (§2 scope-of-no-change). Existing `-design.md` files are never renamed or rewritten; all consumers continue to accept both suffixes.

---

## 4. Stakeholders

- **Primary users — small projects.** Solo devs, small teams. Invariant: their experience does not change. Same commands, same file locations, same skill table length.
- **Primary users — large projects.** Teams running multi-phase initiatives. They get durable strategic docs, per-phase tactical plans, and (optionally) decision logs and per-initiative playbooks.
- **Plugin maintainers.** Must be able to add the new surface without doubling the skill index or introducing behavior flags that branch every downstream skill.
- **Other-tool users (Codex, Cline, Cursor, Copilot).** Adapter files must remain generated from templates. Any new templates must ship in `adapters/`.

---

## 5. The three artifact tiers

This design locks in a clean three-tier mental model. Each tier lives in a different directory with a different filename convention, consumed by different skills.

| Tier | Directory | Filename | Durability | Scope | Created by |
|---|---|---|---|---|---|
| Strategic | `docs/designs/` | `<topic>.md` (undated) | Durable — rewritten, not patched | v1/v2, migrations, multi-phase initiatives | `brainstorming` with `scope: initiative` |
| Tactical | `docs/plans/` | `YYYY-MM-DD-<topic>-plan.md` (dated) | Transient — dated and frozen after phase ships | One feature, phase, milestone, or fix | `brainstorming` default (`scope: feature` or `phase`) |
| Executable | project root | `hotl-workflow-<slug>.md` | Transient — may be deleted after run | Decomposition of one tactical plan | `writing-plans` |

**Rename note.** Today's `brainstorming` writes to `docs/plans/YYYY-MM-DD-<topic>-design.md`. New outputs switch to `-plan.md` so the directory name and filename suffix agree. Existing `-design.md` files are left untouched — no migration.

---

## 6. Flow by scope

### 6.1 Feature scope (unchanged)

```
brainstorming (scope: feature)
  → docs/plans/YYYY-MM-DD-<topic>-plan.md
  → writing-plans
  → hotl-workflow-<slug>.md
  → execute
```

Identical to today. Tactical plan → executable workflow → run.

### 6.2 Phase scope (unchanged shape, new label)

Same flow as feature scope. The distinction is purely semantic: a phase is one slice of a larger initiative, but its plan doc and workflow file look the same.

### 6.3 Initiative scope (new)

```
brainstorming (scope: initiative)
  → docs/designs/<topic>.md         ← strategic, durable, multi-phase

  (for each phase defined in the design doc)
    brainstorming (scope: phase)
      → docs/plans/YYYY-MM-DD-phase-N-<name>-plan.md
      → writing-plans
      → hotl-workflow-<slug>.md
      → execute
```

The strategic design is a **parent artifact**. You do not execute it directly. You decompose it into phases, each of which follows the tactical flow. The strategic doc lists phases, names their owners, fixes non-goals, and is rewritten when the initiative changes direction.

---

## 7. Two templates

### 7.1 Strategic template — `adapters/strategic-design.template.md`

Borrowed from ODAP's `design-doc-template.md`, generalized to remove ODAP-specific language. Sections:

1. Problem statement
2. Vision / intent
3. Non-goals
4. Stakeholders
5. Scope (in / out)
6. Architecture / module-level changes
7. Maturity stages (optional — for rollout-heavy initiatives)
8. Phase breakdown (required — lists each phase with one-line intent)
9. Quality attributes (performance, security, cost, observability)
10. Risks and open questions

Undated. Rewritten when superseded. No per-task breakdown.

### 7.2 Tactical template — `adapters/tactical-plan.template.md`

Matches the existing `brainstorming` skill output shape, formalized:

1. Intent contract (what this phase is for, non-goals)
2. Verification contract (definition of done, verification plan, regression surface)
3. Governance contract (approvers, gates, exit criteria, rollback)
4. Scope (in / out)
5. Module-level changes
6. Task breakdown (feeds `writing-plans`)

Dated. Frozen after phase ships. One per phase or feature.

---

## 8. Configuration — `.hotl/config.yml`

To avoid scale flags and auto-detection, all tier-awareness is driven by a single optional config file.

**Location:** `.hotl/config.yml` at project root.

**Absence = default behavior (today's flow, no initiative tier).**

**Schema (all fields optional, all have defaults except `decision_log_path` which is opt-in only):**

```yaml
taxonomy: default | initiative       # default: "default"
designs_dir: docs/designs            # only read if taxonomy: initiative
plans_dir: docs/plans                # default: docs/plans (existing)
workflows_dir: .                     # default: project root
requirements_dir: docs/requirements  # only read if taxonomy: initiative
reviews_dir: docs/reviews            # only read if taxonomy: initiative
prompts_dir: docs/prompts            # only read if taxonomy: initiative

# decision_log_path is OPT-IN ONLY. No default value. Absence = no logging.
# Uncomment and set explicitly to enable the decision log:
#
# decision_log_path: docs/decisions/log.md   # example — writes to ADR dir
# decision_log_path: .hotl/decisions.log     # example — project-local silent log
```

**Who writes it:** `setup-project` asks a single question — *"Will this project run multi-phase initiatives?"* — and writes the file only if the user answers yes. Default answer is no.

**Who reads it — consumption model.** The plugin has two kinds of skills:

- **Markdown skills** (`brainstorming`, `writing-plans`, `setup-project`, `document-review`, etc.) — prompt text the agent follows. These do not run inside `hotl-rt`.
- **Runtime-managed execution** (`loop-execution`, `executing-plans`, `subagent-execution`) — coordinated by `hotl-rt`.

Both categories must resolve the same config. To avoid duplicating parser logic, Slice 1 ships a single shared helper — `hotl-config.sh` — that both kinds of caller use:

```
hotl-config.sh get <field> [--default=<value>]
```

**Install-path resolution.** `hotl-config.sh` ships in the plugin install, not in the user's project. Skills must resolve it the same way `document-lint.sh` is resolved today (see `skills/document-review/SKILL.md:39`):

1. If working in the `hotl-plugin` repo itself, use `scripts/hotl-config.sh`
2. Codex native-skills install: `~/.codex/hotl/scripts/hotl-config.sh`
3. Codex plugin install: `~/.codex/plugins/hotl-source/scripts/hotl-config.sh`
4. Codex plugin cache fallback: `~/.codex/plugins/cache/codex-plugins/hotl/*/scripts/hotl-config.sh`
5. Cline install fallback: `~/.cline/hotl/scripts/hotl-config.sh`
6. Claude Code plugin fallback: `~/.claude/plugins/hotl/scripts/hotl-config.sh`

Skills must not assume `scripts/hotl-config.sh` exists in the repo being worked on.

**Invocation:**

- Markdown skills instruct the agent: *"Resolve the `hotl-config.sh` install path (see list above), then run `bash <resolved-path> get plans_dir --default=docs/plans` to resolve the plans directory."* The agent shells out via `Bash` and reads stdout.
- `hotl-rt` shells out to the same helper internally when loading a workflow, using the same resolution order.

The helper is the single canonical parser. Skills never parse `.hotl/config.yml` themselves. Absence of the file (or an unset field) returns the `--default` value cleanly, with exit code 0 and no stderr noise. A field with no `--default` and no config value returns empty stdout and exit 0.

**Invariants:**
- Absence of `.hotl/config.yml` is always a valid state. The plugin keeps today's workflow semantics — same commands, same directories, same execution model, same gates — with the one documented cosmetic exception: new tactical output uses the `-plan.md` suffix instead of `-design.md` (see §2 scope-of-no-change).
- `scripts/hotl-config.sh get <field>` with no config returns the default and exit 0 — never an error.
- No skill ever *writes* to a config-driven path without the config being present — no accidental folder creation.
- Field names are stable across versions; deprecations require a minor-version note in `CHANGELOG.md`.

---

## 9. Small-user safety contract

This is the load-bearing invariant of the design. For a user who has not opted in:

- **No workflow-semantics change.** Same commands, same directories, same execution model, same gates, same defaults.
- No new commands in the `/hotl:*` menu.
- No new entries in the `using-hotl` skill table.
- **No new initiative-support files or directories beyond today's baseline HOTL outputs.** Baseline outputs (the tactical plan in `docs/plans/` and `hotl-workflow-<slug>.md` at project root) continue to be written as today — that is existing behavior, not an initiative-support artifact. Initiative-support artifacts that are forbidden without opt-in include: `.hotl/config.yml`, `.hotl/decisions.log`, `docs/designs/`, `docs/decisions/`, `docs/requirements/`, `docs/reviews/`, `docs/prompts/`, or any other new directory. The plugin's own scripts and templates live under the plugin install path, not the user repo.
- `brainstorming` asks the scope question but pre-fills "feature" and accepts a default answer silently.
- `writing-plans` still writes to `hotl-workflow-<slug>.md` at project root; tactical plans still land in `docs/plans/`.
- `setup-project` asks one new question with a default "no"; everything else is unchanged.
- The decision log is **opt-in only**. It writes only when `decision_log_path` is explicitly set in `.hotl/config.yml`. Absence of config = no logging. There is no default log path.
- **One cosmetic exception:** new tactical plans use suffix `-plan.md` instead of `-design.md`. This is a naming-only change — location, contents, template, and all consumer behavior are identical. Existing `-design.md` files are untouched and continue to be accepted by all consumers. This is the only user-visible change that applies without opt-in. Called out explicitly rather than hidden.

If any of the above changes (or a second non-opt-in change is added), the design has drifted — flag it in review.

---

## 10. Cross-cutting infrastructure

### 10.1 Decision log

An append-only log of autonomous gate decisions (risk evaluation, auto-approve verdict, loop iteration outcomes) written by `hotl-rt`.

**Opt-in only.** The log writes only when `decision_log_path` is explicitly set in `.hotl/config.yml`. Absence of config = no log. There is no default log path.

Typical configurations:
- Small user: no config, no log.
- Large project: `decision_log_path: docs/decisions/log.md` — writes into the ODAP-style ADR directory.
- Debugging: `decision_log_path: .hotl/decisions.log` — users who want a log but do not want it in `docs/` must set it explicitly.

The runtime never hard-codes any path. The path is resolved by `scripts/hotl-config.sh get decision_log_path` with no default; empty result means logging is disabled. This is the only piece of initiative infrastructure that touches runtime code.

### 10.2 Role model

**Not plugin infrastructure.** Roles (`@pm`, `@architect`, `@dev`, etc.) live in adapter templates (`AGENTS.md`, `CLAUDE.md`) that `setup-project` renders when taxonomy is `initiative`. The runtime and skills remain role-agnostic.

### 10.3 Per-initiative playbook

A static template rendered by `setup-project`, not a dialogic skill. One file per initiative, located at `docs/prompts/<initiative>-playbook.md`. Contents are prompt snippets the user copy-pastes per session. This is a documentation artifact, not an executable one.

---

## 11. Module boundaries

| Surface | Change | Notes |
|---|---|---|
| `scripts/hotl-config.sh` (NEW) | Canonical config reader: `get <field> [--default=<v>]` | Single source of truth for config parsing; used by markdown skills and runtime |
| `skills/brainstorming/SKILL.md` | Add scope question: feature / phase / initiative; update line 59 output path ; default new output suffix to `-plan.md` | Feature is default; initiative routes output to `docs/designs/` |
| `skills/writing-plans/SKILL.md` | Honor `workflows_dir` from config; no filename change (still `hotl-workflow-<slug>.md`) | Existing files untouched |
| `skills/loop-execution/SKILL.md` | Update dirty-worktree exclusion glob to match both `-design.md` and `-plan.md` (line 44) | Required to keep new files from tripping preflight |
| `skills/executing-plans/SKILL.md` | Same exclusion-glob update (line 32) | Required for same reason |
| `skills/document-review/SKILL.md` | Classification rules (lines 22, 56) accept both `-design.md` and `-plan.md` as HOTL plan docs | Without this, new plan docs get the generic-markdown path |
| `skills/setup-project/SKILL.md` | Add one opt-in question; render templates when yes | Default "no" preserves today's behavior |
| `skills/using-hotl/SKILL.md` | Unchanged skill count — no new skill entries | Critical: prevents index bloat |
| `scripts/document-lint.sh` | Usage text + file-type detection updated to handle `-plan.md` (line 10 and glob checks) | Lint must treat both suffixes as design docs for backwards compatibility |
| `cline/rules/hotl-brainstorming.md` | Mirror the output-path change from the canonical skill (line 74) | Cline rules mirror canonical skills — must stay in sync |
| `cline/rules/hotl-execution.md` | Mirror the exclusion-glob update (line 24) | Same mirror requirement |
| `cline/rules/hotl-document-review.md` | Mirror the classification rule update (line 23) | Same mirror requirement |
| `runtime/hotl-rt` | Add decision-log primitive that shells out to `scripts/hotl-config.sh` for path; no default path | Opt-in only — absence of config means no log |
| `adapters/` | Add `strategic-design.template.md`, `tactical-plan.template.md`, `initiative-playbook.template.md`, `initiative-operating-model.template.md` | Rendered only on opt-in |
| `workflows/` | Add `phase-kickoff.md` template | Reusable workflow, not a skill |
| `commands/` | No new commands | Setup gets the opt-in question |
| `docs/` | Add `docs/designs/` for our own dogfooding; this file is the first entry | Plugin repo eats its own dog food |

---

## 12. Maturity / rollout stages

This initiative rolls out in slices. Each slice ships independently and delivers value on its own.

Slices are listed in the order they ship. Each slice's dependencies are already satisfied by earlier slices — read the table top-down.

| Slice | Scope | Exit criteria |
|---|---|---|
| **Slice 1** | `scripts/hotl-config.sh` canonical reader + `.hotl/config.yml` schema documented; `hotl-rt` decision-log primitive as **opt-in only** (no default path, no default write) | Small users see zero change and zero new files in their repo; `hotl-config.sh get <field>` with no config returns default and exit 0; decision log is silent unless `decision_log_path` is explicitly configured; install-path resolution matches the `document-lint.sh` pattern |
| **Slice 2** | Tactical default output renamed to `-plan.md` AND all consumers updated in the same slice: `brainstorming` (line 59), `loop-execution` (line 44), `executing-plans` (line 32), `document-review` (lines 22, 56), `scripts/document-lint.sh` (line 10 + globs), plus cline mirrors (`hotl-brainstorming.md`, `hotl-execution.md`, `hotl-document-review.md`); `writing-plans` honors `workflows_dir` from config | Existing `-design.md` files are untouched and still treated as HOTL plan docs by all consumers; smoke test runs the default brainstorm flow and asserts the new output path is `docs/plans/YYYY-MM-DD-<topic>-plan.md`, that every downstream consumer (lint, document-review classification, executor dirty-worktree exclusion) accepts the new suffix, and that behavior is otherwise unchanged from today (same template contents, same gates, same execution flow) |
| **Slice 3** | Templates land in `adapters/`: `strategic-design.template.md`, `tactical-plan.template.md`, `initiative-playbook.template.md`, `initiative-operating-model.template.md` | All four templates exist and are generic (no ODAP-specific prose). Coverage: `tactical-plan.template.md` conforms to the existing `document-lint.sh` design-doc rules and passes lint. `strategic-design.template.md`, `initiative-playbook.template.md`, and `initiative-operating-model.template.md` are not covered by the existing linter — they are validated by a generic Markdown render check (renders without error, all internal anchor links resolve) plus a manual review. No linter extension is in scope for this slice; if a structural lint is wanted for these template types, it is deferred to a future slice and explicitly tracked as a non-goal of Slice 3 |
| **Slice 4** | `brainstorming` adds scope question (feature/phase/initiative); initiative scope writes to `docs/designs/<topic>.md` using the strategic template from Slice 3 | Default scope is feature; initiative output uses `adapters/strategic-design.template.md`; template is resolved from the plugin install path (same pattern as Slice 1's helper resolution) |
| **Slice 5** | `setup-project` adds opt-in question; writes `.hotl/config.yml` with `taxonomy: initiative` and renders the Slice 3 templates into the user's repo | Default answer no; no files created on default; yes answer produces the full docs/ taxonomy scaffold and the four rendered templates |
| **Slice 6** | `workflows/phase-kickoff.md` template (review → triage → requirements) | Optional workflow referenced by the initiative playbook |

**Ordering rationale.** The unifying rule across all slices is **no orphaned producer/consumer pairs** — never ship one side of a producer/consumer relationship without the other. Slice 1 ships the config reader that Slices 2–5 depend on. Slice 2 bundles the `-plan.md` rename (producer of new-suffix files) with every consumer update in one slice, so `-plan.md` files never exist while consumers still reject them. Slice 3 ships the templates (producers of template content) before Slice 4 (`brainstorming`) and Slice 5 (`setup-project`) consume them. Slice 5 ships the scaffolder (producer of the `docs/` taxonomy) only after every skill that would populate those folders has been updated.

Slices 1 and 2 ship value to all users (consistent config resolution; cleaner tactical naming). Slices 3–6 unlock the initiative tier without changing default behavior.

---

## 13. Quality attributes

**Skill-table size.** Must not grow. `using-hotl` is already 17 skills; adding initiative-specific skills would bloat the index and confuse small users. All initiative surface is delivered via extensions to existing skills + templates.

**Backwards compatibility.** Projects with no `.hotl/config.yml` keep today's workflow semantics — same commands, same directories, same execution model, same gates. The one user-visible change is the cosmetic rename of new tactical output from `-design.md` to `-plan.md` (see §2 scope-of-no-change and §9 exception). Existing `-design.md` files are never touched and remain accepted by every consumer. The `hotl-workflow-*.md` root location is unchanged by default.

**Discoverability.** Initiative tier is discovered through `/hotl:setup` (one new question) or the `brainstorming` scope prompt (one new option). No other discovery paths.

**Cost of opt-out.** A user who opts in and regrets it can delete `.hotl/config.yml` and the plugin reverts to default behavior. Existing strategic docs remain readable as normal Markdown.

**Agent-neutral.** Templates and config must work for Claude Code, Codex, Cline, Cursor, and Copilot. No agent-specific prose in templates.

---

## 14. Risks and open questions

**Risk: expectation inflation after opt-in.** Once a user scaffolds `docs/designs/` and `docs/decisions/`, they will expect every HOTL skill to "understand" these paths. Mitigation: the no-orphaned-pairs rule (§12 ordering rationale). The config reader ships in Slice 1; the scaffolder ships in Slice 5 only after every skill that would read those folders has been updated. A user cannot scaffold folders before the skills know what to do with them.

**Risk: template drift from ODAP.** If ODAP evolves its own templates, ours will drift. Mitigation: templates are generic by design — they do not track ODAP directly. We review them annually, not per ODAP change.

**Risk: small-user regression.** A subtle change in `brainstorming`'s default flow could surprise existing users. Mitigation: smoke test that runs the default brainstorming flow with scope: feature, asserts the output path is `docs/plans/YYYY-MM-DD-<topic>-plan.md`, and confirms every downstream consumer (lint, document-review classification, executor dirty-worktree exclusion) treats the new `-plan.md` suffix identically to today's `-design.md` output. The test is not "path matches today" — it is "behavior matches today apart from the documented suffix rename."

**Open question:** Does the scope question in `brainstorming` need to be confirmation-style (pre-filled recommendation) or free-form selection? Leaning confirmation, but deferred to implementation.

**Open question:** Should `workflows_dir: docs/workflows/` be suggested anywhere in the opt-in flow, or kept as a pure override? Leaning pure override — users who want it will configure it.

**Open question:** Per-initiative playbooks vs. one global playbook. ODAP uses per-initiative (`ai-assurance-playbook.md`). Our template should match — per-initiative, rendered once per `docs/designs/<topic>.md` created. Deferred to Slice 5 design.

---

## 15. Verification

This design is considered accepted when:

- A reviewer confirms the small-user safety contract (§9) is satisfied by the module-boundary plan (§11).
- Slice 1 acceptance criteria are expressed as a runnable smoke test spec before Slice 1 coding begins.
- A dogfood check: this file lives at `docs/designs/initiative-support.md` and is rewritten, not patched, if the design changes.

---

## 16. References

- `/Users/yimwu/Documents/workspace/oracledb/odap/docs/README.md` — source taxonomy
- `/Users/yimwu/Documents/workspace/oracledb/odap/docs/prompts/ai-assurance-playbook.md` — source playbook pattern
- `/Users/yimwu/Documents/workspace/oracledb/odap/docs/prompts/hotl-operating-model.md` — source role and decision-rights model
- `/Users/yimwu/Documents/workspace/oracledb/odap/docs/prompts/design-doc-template.md` — basis for `strategic-design.template.md`
- `/Users/yimwu/Documents/workspace/oracledb/odap/docs/prompts/plan-template.md` — basis for `tactical-plan.template.md`
- `CLAUDE.md` — plugin architecture and conventions
- `skills/brainstorming/SKILL.md` — tactical brainstorming (will be extended)
- `skills/writing-plans/SKILL.md` — tactical plan executor (will honor config)
- `skills/setup-project/SKILL.md` — adapter rendering (will gain opt-in question)
