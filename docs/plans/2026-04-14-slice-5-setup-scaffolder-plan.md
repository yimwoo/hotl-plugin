# Slice 5 — Setup-Project Scaffolder

**Status:** Proposed — for review
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted), Slices 1–4 (shipped)
**Strategy reference:** `docs/designs/initiative-support.md` §8 config schema, §9 small-user safety, §11 adapters row, §12 Slice 5

---

## 1. Intent contract

**What this slice is for.** Give `setup-project` an opt-in initiative-support question. When the user answers yes, run a new `scripts/hotl-init-initiative.sh --name <slug>` helper that writes `.hotl/config.yml` with `taxonomy: initiative`, creates the `docs/{designs,plans,decisions,requirements,reviews,prompts}/` taxonomy, and materializes the four Slice 3 templates under `docs/prompts/` **per the accepted design §10.3** — playbook and operating-model are **per-initiative** (filenames include the initiative slug, `{{INITIATIVE_NAME}}` placeholders substituted); design-doc and plan templates are **generic project references** (copied as-is with flat `.md` names, no substitution).

**Rendering scheme (closes design §14 open question on playbook granularity):**

| Source in `adapters/` | Rendered path | Per-initiative? | Substitution |
|---|---|---|---|
| `strategic-design.template.md` | `docs/prompts/design-doc-template.md` | No — generic reference | None |
| `tactical-plan.template.md` | `docs/prompts/plan-template.md` | No — generic reference | None |
| `initiative-playbook.template.md` | `docs/prompts/<slug>-playbook.md` | Yes — per-initiative | `{{INITIATIVE_NAME}}` → `<slug>` |
| `initiative-operating-model.template.md` | `docs/prompts/<slug>-operating-model.md` | Yes — per-initiative | `{{INITIATIVE_NAME}}` → `<slug>`, `{{DATE}}` → today |

Matches ODAP's actual `docs/prompts/` convention (flat `.md` filenames, `<initiative>-playbook.md` and `hotl-operating-model.md` style). Closes the "what naming does Slice 5 use" ambiguity definitively.

This slice wires the three templates that Slice 4 did NOT consume (`tactical-plan.template.md`, `initiative-playbook.template.md`, `initiative-operating-model.template.md`) into a real consumer. After Slice 5, every Slice 3 template is consumed by at least one skill or scaffolder.

**What this slice is NOT for.**

- No change to `brainstorming`, `writing-plans`, `executing-plans`, `loop-execution`, or the runtime.
- No change to the existing adapter files (`AGENTS.md.template`, `copilot-instructions.template`, `cursor-rules.template`) — those ship unchanged with their existing behavior.
- No new commands in the `/hotl:*` menu. The opt-in question lives inside the existing `setup-project` skill.
- No phase-kickoff workflow (Slice 6).
- No substitution beyond `{{INITIATIVE_NAME}}` and `{{DATE}}`. Other placeholders (`{{PHASE_ID}}`, `{{PHASE_1_NAME}}`, etc.) remain in the rendered files for the user to edit.
- No modification of existing user files. If `.hotl/config.yml` already exists, the scaffolder refuses and exits with a helpful message. If any of the four target outputs under `docs/prompts/` (`design-doc-template.md`, `plan-template.md`, `<slug>-playbook.md`, `<slug>-operating-model.md`) already exists (user edit or prior partial init), the scaffolder leaves it alone byte-for-byte and emits a one-line `SKIP:` message. Other `docs/prompts/*.md` files owned by the user or unrelated tools are ignored entirely — the scaffolder neither reads them nor touches them.

**Primary audience / user story.** A user running `/hotl:setup` on a repo that needs multi-phase initiative support answers `yes` to "Will this project run multi-phase initiatives?" (default `no`), provides the initiative slug when asked (e.g., `ai-assurance`, `v2-migration`), and gets the full initiative-support taxonomy + a playbook named `docs/prompts/ai-assurance-playbook.md` and an operating model named `docs/prompts/ai-assurance-operating-model.md` — both with the initiative name already filled in. A user answering `no` (or who never opts in) sees zero change from today's `setup-project` behavior.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-5-smoke.bats`. Full `bats test/` remains green (222 prior + new Slice 5 tests).

### 2.1 Smoke test spec (runnable)

Group letters continue: Slice 5 uses Q/R/S.

#### Group Q — `hotl-init-initiative.sh` scaffolder behavior

**Q1. Creates `.hotl/config.yml` with `taxonomy: initiative`.**

```bash
cd "$TMP"
git init -q
run bash "$HOTL_INIT_INITIATIVE" --name demo
[ "$status" -eq 0 ]
[ -f .hotl/config.yml ]
grep -qE '^taxonomy:[[:space:]]*initiative\b' .hotl/config.yml
```

**Q2. Creates the six `docs/<tier>/` directories.**

```bash
cd "$TMP"
git init -q
bash "$HOTL_INIT_INITIATIVE" --name demo
for dir in \
    docs/designs \
    docs/plans \
    docs/decisions \
    docs/requirements \
    docs/reviews \
    docs/prompts; do
    [ -d "$dir" ] || { echo "FAIL: $dir was not created"; return 1; }
done
```

**Q3. Renders the four templates per the §1 scheme — generic references as-is, per-initiative instances with placeholders substituted.**

```bash
cd "$TMP"
git init -q
bash "$HOTL_INIT_INITIATIVE" --name demo

# Generic references — copied from adapters/ with flat .md filenames
# (drop the .template.md suffix). Content byte-for-byte identical to
# source (no substitution).
diff -q "docs/prompts/design-doc-template.md" \
        "$REPO_ROOT/adapters/strategic-design.template.md" >/dev/null \
    || { echo "FAIL: design-doc-template.md diverges from source"; return 1; }
diff -q "docs/prompts/plan-template.md" \
        "$REPO_ROOT/adapters/tactical-plan.template.md" >/dev/null \
    || { echo "FAIL: plan-template.md diverges from source"; return 1; }

# Per-initiative instances — filenames include the slug; content has
# {{INITIATIVE_NAME}} substituted.
[ -f "docs/prompts/demo-playbook.md" ] \
    || { echo "FAIL: demo-playbook.md was not rendered"; return 1; }
[ -f "docs/prompts/demo-operating-model.md" ] \
    || { echo "FAIL: demo-operating-model.md was not rendered"; return 1; }

grep -q 'demo' "docs/prompts/demo-playbook.md"
grep -q 'demo' "docs/prompts/demo-operating-model.md"

# No raw {{INITIATIVE_NAME}} should remain in the rendered instances.
! grep -q '{{INITIATIVE_NAME}}' "docs/prompts/demo-playbook.md"
! grep -q '{{INITIATIVE_NAME}}' "docs/prompts/demo-operating-model.md"

# The operating-model template has {{DATE}}; verify the substitution ran.
# Assert today's UTC date appears AND raw {{DATE}} is gone.
TODAY=$(date -u +%Y-%m-%d)
grep -q "$TODAY" "docs/prompts/demo-operating-model.md" \
    || { echo "FAIL: expected today's date ($TODAY) in demo-operating-model.md"; return 1; }
! grep -q '{{DATE}}' "docs/prompts/demo-operating-model.md" \
    || { echo "FAIL: raw {{DATE}} still present in demo-operating-model.md"; return 1; }

# None of the FOUR RENDERED OUTPUTS from THIS run keep the .template.md
# suffix. Scoped to the four files we produced — a pre-existing unrelated
# *.template.md file owned by the user must not fail this test.
for f in \
    docs/prompts/design-doc-template.md \
    docs/prompts/plan-template.md \
    docs/prompts/demo-playbook.md \
    docs/prompts/demo-operating-model.md; do
    [ -f "$f" ] || { echo "FAIL: $f missing"; return 1; }
    case "$(basename "$f")" in
        *.template.md)
            echo "FAIL: $f should not use the .template.md suffix after rendering"
            return 1
            ;;
    esac
done
```

**Q4. Refuses when `.hotl/config.yml` already exists — does not silently overwrite.**

```bash
cd "$TMP"
git init -q
mkdir -p .hotl
echo "taxonomy: default" > .hotl/config.yml
ORIGINAL=$(cat .hotl/config.yml)

run bash "$HOTL_INIT_INITIATIVE" --name demo
[ "$status" -ne 0 ]
# Existing file preserved byte-for-byte.
[ "$(cat .hotl/config.yml)" = "$ORIGINAL" ]
# Error message names the conflict.
echo "$output" | grep -qi 'exists\|already'
```

**Q5. Idempotent against partial prior state — every one of the four target output files is preserved byte-for-byte when it pre-exists, with a SKIP message for each.**

```bash
cd "$TMP"
git init -q
# Simulate a prior partial init: config absent (so Q4 doesn't fire) but
# ALL FOUR target files already exist with distinct user content, so we
# can prove each is preserved individually — not just one.
mkdir -p docs/prompts
echo "USER EDIT: design-doc"       > docs/prompts/design-doc-template.md
echo "USER EDIT: plan"             > docs/prompts/plan-template.md
echo "USER EDIT: playbook"         > docs/prompts/demo-playbook.md
echo "USER EDIT: operating-model"  > docs/prompts/demo-operating-model.md

run bash "$HOTL_INIT_INITIATIVE" --name demo
[ "$status" -eq 0 ]

# Each pre-existing target file is preserved byte-for-byte.
[ "$(cat docs/prompts/design-doc-template.md)" = "USER EDIT: design-doc" ]
[ "$(cat docs/prompts/plan-template.md)" = "USER EDIT: plan" ]
[ "$(cat docs/prompts/demo-playbook.md)" = "USER EDIT: playbook" ]
[ "$(cat docs/prompts/demo-operating-model.md)" = "USER EDIT: operating-model" ]

# A SKIP line is emitted for each preserved file (verifies the scaffolder
# surfaces the no-overwrite decision rather than silently skipping).
for f in \
    design-doc-template.md \
    plan-template.md \
    demo-playbook.md \
    demo-operating-model.md; do
    echo "$output" | grep -qiE "skip.*docs/prompts/$f" \
        || { echo "FAIL: no SKIP message for docs/prompts/$f"; return 1; }
done
```

**Q6. Required `--name` argument — scaffolder refuses without a name.**

```bash
cd "$TMP"
git init -q
run bash "$HOTL_INIT_INITIATIVE"
[ "$status" -ne 0 ]
# Error message explains the required argument.
echo "$output" | grep -qiE 'name|required|usage'
# No files were created — refusal is clean.
[ ! -e .hotl/config.yml ]
[ ! -d docs/designs ]
```

**Q7. Install-path resolution — scaffolder finds `adapters/` via the same six-location order used for `hotl-config.sh`.**

```bash
# Synthetic install test — place the adapters/ dir under a fake install
# root and point HOTL_INSTALL_OVERRIDE at it. Scaffolder must resolve via
# the override and still produce the full taxonomy.
FAKE_INSTALL_ROOT=$(mktemp -d)
mkdir -p "$FAKE_INSTALL_ROOT/hotl/adapters"
cp "$REPO_ROOT/adapters"/*.template.md "$FAKE_INSTALL_ROOT/hotl/adapters/"

cd "$TMP"
git init -q
run env HOTL_INSTALL_OVERRIDE="$FAKE_INSTALL_ROOT" \
    bash "$HOTL_INIT_INITIATIVE" --name demo
[ "$status" -eq 0 ]

# All four rendered outputs resolved from the fake install.
[ -f "docs/prompts/design-doc-template.md" ]
[ -f "docs/prompts/plan-template.md" ]
[ -f "docs/prompts/demo-playbook.md" ]
[ -f "docs/prompts/demo-operating-model.md" ]

rm -rf "$FAKE_INSTALL_ROOT"
```

#### Group R — `setup-project` SKILL.md content

**R1. SKILL documents the opt-in question with `no` as the default.**

```bash
skill="$REPO_ROOT/skills/setup-project/SKILL.md"
# The question text appears in the skill.
grep -qi 'multi-phase initiative\|initiative support' "$skill"
# Default is no — documented explicitly.
grep -qiE '(default|prefill)[[:space:]:]+.*no\b' "$skill"
```

**R2. SKILL references the scaffolder script and documents its install-path resolution.**

```bash
skill="$REPO_ROOT/skills/setup-project/SKILL.md"
grep -q 'hotl-init-initiative\.sh' "$skill"
# The skill lists the six install locations for the scaffolder (same
# pattern as document-lint.sh / hotl-config.sh).
for loc in \
    'scripts/hotl-init-initiative\.sh' \
    '\.codex/hotl/scripts/hotl-init-initiative\.sh' \
    '\.codex/plugins/hotl-source/scripts/hotl-init-initiative\.sh' \
    '\.codex/plugins/cache/codex-plugins/hotl/\*/scripts/hotl-init-initiative\.sh' \
    '\.cline/hotl/scripts/hotl-init-initiative\.sh' \
    '\.claude/plugins/hotl/scripts/hotl-init-initiative\.sh'; do
    grep -qE "$loc" "$skill" \
        || { echo "FAIL: setup-project SKILL missing resolution location matching /$loc/"; return 1; }
done
```

**R3. SKILL documents that the scaffolder is invoked ONLY when the user opts in.**

```bash
skill="$REPO_ROOT/skills/setup-project/SKILL.md"
# There must be language gating the scaffolder invocation on a yes/opt-in
# answer. Negative phrasing (do NOT run if no) also acceptable.
grep -qiE 'opt.in|answered yes|if yes|only when.*yes|only if.*yes' "$skill"
```

#### Group S — small-user safety regression

**S1. Command and skill counts unchanged from pre-Slice-5 baseline.**

```bash
EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-5-command-count.txt")
ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
[ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-5-skill-count.txt")
ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
[ "$ACTUAL_SKILLS" -eq "$EXPECTED_SKILLS" ]
```

**S2. Slice 5 surface in a clean repo creates no forbidden initiative-support artifacts UNTIL the scaffolder is explicitly invoked.**

```bash
cd "$TMP"
git init -q

# Exercise the entire Slice 1–5 non-scaffolder surface. None of these
# should cause any initiative-support artifacts to appear.
bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs >/dev/null
bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=. >/dev/null
bash "$HOTL_RT" log-decision '{"event":"test"}'

for forbidden in \
    .hotl/config.yml \
    .hotl/decisions.log \
    docs/designs \
    docs/decisions \
    docs/requirements \
    docs/reviews \
    docs/prompts; do
    [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created (non-opt-in path)"; return 1; }
done

# Now explicitly invoke the scaffolder — artifacts SHOULD appear.
bash "$HOTL_INIT_INITIATIVE" --name demo
[ -f .hotl/config.yml ]
[ -d docs/designs ]
[ -d docs/prompts ]
[ -f docs/prompts/demo-playbook.md ]
[ -f docs/prompts/demo-operating-model.md ]
[ -f docs/prompts/design-doc-template.md ]
[ -f docs/prompts/plan-template.md ]
```

**S3. All four Slice 3 templates are now consumed — none remain inert.**

```bash
# Slice 4 already wired strategic-design.template.md. Slice 5 wires the
# other three via hotl-init-initiative.sh.
for tmpl_name in \
    strategic-design.template.md \
    tactical-plan.template.md \
    initiative-playbook.template.md \
    initiative-operating-model.template.md; do
    # Each template must now be referenced by at least one non-inert
    # consumer — a skill, a script, a runtime, or a command.
    # hotl-init-initiative.sh references all four.
    # skills/brainstorming/SKILL.md references strategic-design only.
    # Both counts fine as long as each template has >=1 consumer.
    refs=$(grep -rl "$tmpl_name" "$REPO_ROOT" 2>/dev/null \
        | grep -vE '^'"$REPO_ROOT"'/(docs/|test/|adapters/|\.git/|CHANGELOG\.md)' \
        || true)
    [ -n "$refs" ] \
        || { echo "FAIL: $tmpl_name has no consumer — remains inert"; return 1; }
done
```

**S4. Prior slice smoke suites remain green.**

```bash
for suite in \
    test/slice-1-smoke.bats \
    test/slice-2-smoke.bats \
    test/slice-3-smoke.bats \
    test/slice-4-smoke.bats; do
    run bats "$REPO_ROOT/$suite"
    [ "$status" -eq 0 ]
done
```

### Verification plan

1. Capture `test/fixtures/pre-slice-5-command-count.txt` and `pre-slice-5-skill-count.txt`. **First commit.**
2. Implement `scripts/hotl-init-initiative.sh` per §5. Resolves `adapters/` via the same six-location order as `hotl-config.sh`, honoring `HOTL_INSTALL_OVERRIDE`.
3. Update `skills/setup-project/SKILL.md` with the opt-in question + six-location resolution block for `hotl-init-initiative.sh` + invocation instruction.
4. Author `test/slice-5-smoke.bats` with Groups Q/R/S. Make all tests green.
5. Run full `bats test/` — must be green (222 prior plus Slice 5 additions).
6. Update `CHANGELOG.md` with Unreleased entries.
7. **Manual verification** — four scenarios. Scenarios A, B, and C each use a fresh scratch repo (`git init -q` in a new `mktemp -d`). Scenario D intentionally reuses Scenario B's repo — the existing `.hotl/config.yml` from B is the precondition D needs to exercise the refusal path.

   - **Scenario A — default-no path (safety invariant).** Run `/hotl:setup`, select Codex + Claude Code, answer `no` to the initiative question. Confirm adapter files generated as before; no `.hotl/` or new `docs/` artifacts created.

   - **Scenario B — opt-in happy path (rendering invariant).** Fresh repo. Run `/hotl:setup`, answer `yes`, provide slug `ai-assurance` when prompted. Confirm `.hotl/config.yml` exists with `taxonomy: initiative`, all six `docs/<tier>/` directories exist, and `docs/prompts/` contains the four rendered outputs: `design-doc-template.md`, `plan-template.md`, `ai-assurance-playbook.md` (with `ai-assurance` visible in the body), `ai-assurance-operating-model.md` (with `ai-assurance` AND today's UTC date visible, and no raw `{{DATE}}` remaining). None of the **four rendered outputs** uses the `.template.md` suffix. Pre-existing user-owned `*.template.md` files under `docs/prompts/` (if any) are left untouched.

   - **Scenario C — partial-init idempotency (no config, one target file exists).** Fresh repo with NO `.hotl/config.yml`. Pre-create `docs/prompts/ai-assurance-playbook.md` with a line like "USER EDIT — DO NOT TOUCH". Run `bash <resolved-hotl-init-initiative.sh> --name ai-assurance` directly (the scaffolder script, not `/hotl:setup`, because `/hotl:setup` re-entry is covered by Scenario D). Confirm exit 0, a `SKIP: docs/prompts/ai-assurance-playbook.md` line in stdout, and the user edit preserved byte-for-byte. The other three target outputs are rendered normally.

   - **Scenario D — refusal on existing config (safety invariant).** Re-use Scenario B's repo (which already has `.hotl/config.yml`). Run `/hotl:setup` again, answer `yes`. Confirm it refuses cleanly — exit non-zero, no silent overwrite of the existing config, error message names the conflict. This is the contract in §3 and Q4. Running the scaffolder when config already exists is ALWAYS a refusal, regardless of whether target-output files exist or not.

   Scenarios C and D test different invariants and must be run on different repos — Scenario C's idempotency check is only meaningful before config exists, and Scenario D's refusal check requires config to exist.

### Regression surface

- `scripts/document-lint.sh`, `scripts/hotl-config.sh`, `scripts/hotl-config-resolve.sh` — unchanged.
- `runtime/hotl-rt` — unchanged.
- `skills/brainstorming/SKILL.md`, `skills/writing-plans/SKILL.md`, `skills/loop-execution/SKILL.md`, `skills/executing-plans/SKILL.md`, `skills/document-review/SKILL.md` — unchanged.
- Existing adapter files (`AGENTS.md.template`, `copilot-instructions.template`, `cursor-rules.template`) — unchanged; behavior preserved.
- The four Slice 3 templates in `adapters/` — unchanged; Slice 5 only COPIES them, never rewrites them.
- Prior slice smoke suites (S4 enforces green).

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo).

**Review gates.**

1. Plan review (this doc) — approved when §2.1 is sufficient and runnable and the refusal-on-existing-config behavior (Q4) is deemed correct.
2. Code review on the implementation PR — reviewer runs `bats test/slice-5-smoke.bats` and full suite locally.
3. Pre-merge: full `bats test/` green (§2 step 5) + manual scratch-repo trial (§2 step 7).

**Exit criteria.**

- `test/slice-5-smoke.bats` green.
- Full `bats test/` green — 222+ prior tests plus Slice 5.
- Pre-slice-5 fixtures captured before any code change and checked in.
- Default (no opt-in) flow produces identical output to today's `setup-project` — no new files, no new directories.
- Opt-in flow produces all expected artifacts (config, six tier dirs, four rendered templates).
- Refuse-on-existing-config behavior passes Q4 — no silent overwrite.
- `CHANGELOG.md` entries added.

**Rollback plan.** Slice 5 touches one skill (`skills/setup-project/SKILL.md`) + one new script (`scripts/hotl-init-initiative.sh`) + tests. Revert the implementation commit — `setup-project` returns to today's tool-adapter-only behavior. Any `.hotl/config.yml` and `docs/<tier>/` directories created by users via the scaffolder remain as user-owned files (not auto-deleted); they are valid Markdown/YAML independently of the plugin and keep working if re-installed. Users who want to undo an init run manually delete `.hotl/` and any empty `docs/<tier>/` directories.

---

## 4. Scope

### In scope (ships in this slice)

1. `scripts/hotl-init-initiative.sh` — new scaffolder. Takes **required `--name <slug>`** argument. Creates `.hotl/config.yml` with `taxonomy: initiative`; creates the six `docs/<tier>/` dirs; renders the four Slice 3 templates under `docs/prompts/` per the §1 rendering scheme (generic `design-doc-template.md` + `plan-template.md` copied as-is; per-initiative `<slug>-playbook.md` + `<slug>-operating-model.md` with `{{INITIATIVE_NAME}}` → `<slug>` and `{{DATE}}` → today). Resolves `adapters/` via the six-location install-path order (honors `HOTL_INSTALL_OVERRIDE` for tests). Refuses when `.hotl/config.yml` already exists. If any of the four target outputs already exists under `docs/prompts/`, leaves it byte-for-byte unchanged and emits a `SKIP:` line. Unrelated `docs/prompts/*.md` files owned by the user are neither read nor touched.
2. `skills/setup-project/SKILL.md` — adds the opt-in question ("Will this project run multi-phase initiatives?", default `no`); when yes, asks a follow-up for the initiative slug; documents the six-location install-path resolution for `hotl-init-initiative.sh`; instructs the agent to invoke the scaffolder with `--name <slug>` only when the user opts in and provides a slug.
3. `test/slice-5-smoke.bats` — Groups Q/R/S runnable spec.
4. `test/fixtures/pre-slice-5-command-count.txt` — baseline snapshot.
5. `test/fixtures/pre-slice-5-skill-count.txt` — baseline snapshot.
6. `CHANGELOG.md` — Unreleased entry.

### Out of scope (deferred to later slices or backlog)

- `phase-kickoff` workflow (Slice 6).
- Flag-based overrides for the scaffolder beyond `--name` (e.g., `--designs-dir=docs/strategy`) — first implementation uses defaults; overrides happen by editing `.hotl/config.yml` after init.
- Substitution beyond `{{INITIATIVE_NAME}}` and `{{DATE}}`. Other placeholders (`{{PHASE_ID}}`, `{{PHASE_1_NAME}}`, etc.) remain in the rendered files for the user to edit.
- An "undo" command for the scaffolder — rollback is manual deletion as described in §3.
- An `--update` flag for re-running against an existing config — deferred to backlog (see §7 Q3).
- Any change to existing adapter-file templates (`AGENTS.md.template`, etc.).
- Any new skill or command — opt-in lives inside existing `setup-project`.

---

## 5. Module-level changes

| File | Change |
|---|---|
| `scripts/hotl-init-initiative.sh` (NEW) | Scaffolder script. Shebang `#!/usr/bin/env bash`, `set -euo pipefail`. Required `--name <slug>` argument. Resolves `adapters/` install location via six-location order + `HOTL_INSTALL_OVERRIDE`. Refuses when `.hotl/config.yml` exists. Renders per §1 scheme (two generic references + two per-initiative instances with `{{INITIATIVE_NAME}}` and `{{DATE}}` substituted). Idempotent against any of the four target outputs — SKIPs each pre-existing one with a one-line message. Unrelated `docs/prompts/*.md` files are neither read nor touched. |
| `skills/setup-project/SKILL.md` | New opt-in question ("multi-phase initiative?", default `no`) + follow-up ask for initiative slug when yes; six-location resolution block for `hotl-init-initiative.sh`; instruction to invoke the scaffolder with `--name <slug>` only when the user opts in. |
| `test/slice-5-smoke.bats` (NEW) | Groups Q/R/S runnable spec. |
| `test/fixtures/pre-slice-5-command-count.txt` (NEW) | Baseline. |
| `test/fixtures/pre-slice-5-skill-count.txt` (NEW) | Baseline. |
| `CHANGELOG.md` | Unreleased entry. |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. Capture baselines: write `test/fixtures/pre-slice-5-command-count.txt` and `pre-slice-5-skill-count.txt` from current `main`. **First commit.**
2. Implement `scripts/hotl-init-initiative.sh` per §5. Required `--name <slug>` argument; validate slug is non-empty and kebab-safe (`[a-z0-9][a-z0-9-]*`). Use the same six-location resolution pattern as `hotl-config-resolve.sh`. Implement the §1 rendering scheme: two generic copies (`design-doc-template.md`, `plan-template.md`) with no substitution; two per-initiative instances (`<slug>-playbook.md`, `<slug>-operating-model.md`) with `{{INITIATIVE_NAME}}` replaced by `<slug>` and `{{DATE}}` replaced by `$(date -u +%Y-%m-%d)`. For each of the **four target outputs** that already exists in `docs/prompts/`, leave it byte-for-byte unchanged and emit a `SKIP:` line. Do not scan, read, or touch unrelated `docs/prompts/*.md` files owned by the user.
3. Update `skills/setup-project/SKILL.md`: add the opt-in question (default `no`), the follow-up ask for initiative slug when yes, the six-location resolution block for `hotl-init-initiative.sh`, and the gated invocation instruction (`bash <resolved-hotl-init-initiative.sh> --name <slug>` only when the user answers yes).
4. Author `test/slice-5-smoke.bats` with Groups Q/R/S. Verify all pass.
5. Run full `bats test/` — must be green.
6. Update `CHANGELOG.md`.

---

## 7. Open questions

1. ~~**Template naming in `docs/prompts/`.**~~ **Resolved.** The §1 rendering scheme closes this. None of the four outputs keep the `.template.md` suffix — design-doc and plan references use flat `.md` names (`design-doc-template.md`, `plan-template.md`, matching ODAP's `docs/prompts/` convention); per-initiative playbook and operating-model use `<slug>-playbook.md` and `<slug>-operating-model.md`. Q3/Q5/Q7 smoke tests enforce the scheme.

2. ~~**SKIP behavior for existing files.**~~ **Resolved.** For each of the four target outputs that already exists under `docs/prompts/`, the scaffolder emits a one-line `SKIP: docs/prompts/<file>.md` and leaves the file unchanged. Files outside the four-target list are neither read nor touched — Q5 now seeds all four to prove this invariant per-file, not just for the playbook.

3. **`--update` mode for re-running against an existing config.** Q4 refuses when `.hotl/config.yml` exists. A future `--update` flag is out of scope for Slice 5 (deferred to `docs/backlog.md` if wanted). Today's refusal is strict and safe; update-mode semantics are subtle (re-copy templates? merge config? no-op for some fields?) and deserve their own design discussion.
