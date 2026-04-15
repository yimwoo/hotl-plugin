# Slice 1 — Config Reader + Opt-In Decision Log

**Status:** Accepted — ready for implementation
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted)
**Strategy reference:** `docs/designs/initiative-support.md` §8, §10.1, §12 Slice 1

---

## 1. Intent contract

**What this slice is for.** Ship the canonical config reader (`scripts/hotl-config.sh`) and the opt-in decision-log primitive in `hotl-rt`. This is the foundation Slices 2–5 depend on; nothing user-visible changes in this slice.

**What this slice is NOT for.**

- No rename of tactical outputs (that is Slice 2).
- No changes to `brainstorming`, `writing-plans`, `setup-project`, or any markdown skill (those come in later slices).
- No new templates, no scaffolder, no new commands.
- No auto-detection, no scale flag, no new `using-hotl` skill index entries.

**Primary audience / user story.** Plugin maintainers implementing Slices 2–5. After Slice 1 ships they have a single canonical tool for resolving `.hotl/config.yml` fields and a runtime primitive they can opt-in to for decision logging. End users — both small and large — observe no behavioral change.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-1-smoke.bats`. The test file is a runnable spec authored as part of this slice; it must exist and pass before any other slice begins.

### 2.1 Smoke test spec (runnable)

Tests are grouped by the contract they enforce. Each test has a setup, an action, and an observable assertion.

#### Group A — `hotl-config.sh` exit contract

**A1. Field absent, no default → empty stdout, exit 0.**

```bash
# GIVEN a temp repo with no .hotl/config.yml
cd "$(mktemp -d)"
# WHEN we ask for a field
OUT=$(bash "$HOTL_CONFIG_SH" get plans_dir)
RC=$?
# THEN exit 0 and empty stdout
[ "$RC" -eq 0 ]
[ -z "$OUT" ]
```

**A2. Field absent, default provided → default on stdout, exit 0.**

```bash
cd "$(mktemp -d)"
OUT=$(bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans)
[ "$?" -eq 0 ]
[ "$OUT" = "docs/plans" ]
```

**A3. Field present in config → value on stdout, exit 0.**

```bash
cd "$(mktemp -d)"
mkdir -p .hotl
echo "plans_dir: custom/plans" > .hotl/config.yml
OUT=$(bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans)
[ "$?" -eq 0 ]
[ "$OUT" = "custom/plans" ]
```

**A4. Malformed config → non-zero exit, stderr explains.**

```bash
cd "$(mktemp -d)"
mkdir -p .hotl
printf "plans_dir: [unterminated\n" > .hotl/config.yml
OUT=$(bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans 2>&1 >/dev/null)
RC=$?
[ "$RC" -ne 0 ]
echo "$OUT" | grep -qi "config"
```

**A5. Unknown subcommand → non-zero exit, usage on stderr.**

```bash
bash "$HOTL_CONFIG_SH" foo 2>&1 >/dev/null | grep -qi "usage"
[ "${PIPESTATUS[0]}" -ne 0 ]
```

#### Group B — Install-path resolution

`$HOTL_CONFIG_SH` is set to `scripts/hotl-config.sh` (in-repo canonical path) for all other groups. Group B validates the documented resolution list and exercises a synthetic install.

**B1. Documentation parity with `document-lint.sh`.** Always runs. Parses the resolution list from `skills/document-review/SKILL.md:39-46` and the (new) equivalent block in the skill that documents `hotl-config.sh`. Asserts both lists share identical path shapes (same six locations, same order), differing only by the script filename.

```bash
# Extract resolution paths from each block
LINT_PATHS=$(awk '/^Resolve .document-lint\.sh/,/^Do not assume/' skills/document-review/SKILL.md \
  | grep -Eo '`[^`]+document-lint\.sh`' | sed 's|document-lint\.sh|CANONICAL|')
CFG_PATHS=$(awk '/^Resolve .hotl-config\.sh/,/^Do not assume/' skills/document-review/SKILL.md \
  | grep -Eo '`[^`]+hotl-config\.sh`' | sed 's|hotl-config\.sh|CANONICAL|')
[ -n "$LINT_PATHS" ]
[ -n "$CFG_PATHS" ]
[ "$LINT_PATHS" = "$CFG_PATHS" ]
```

**B2. Synthetic install resolves and forwards.** Always runs. Creates a fake install directory, places `hotl-config.sh` there, and verifies the resolver locates the script and forwards the subcommand to it. Does not depend on any real plugin install being present.

```bash
FAKE_INSTALL_ROOT="$(mktemp -d)"
mkdir -p "$FAKE_INSTALL_ROOT/hotl/scripts"
cp scripts/hotl-config.sh "$FAKE_INSTALL_ROOT/hotl/scripts/"
cd "$(mktemp -d)"

# The resolver is a command proxy: it locates hotl-config.sh under the install
# tree (using the six-location order, with HOTL_INSTALL_OVERRIDE taking priority
# when set) and forwards argv to it. Output matches what hotl-config.sh would have
# printed directly.
OUT=$(HOTL_INSTALL_OVERRIDE="$FAKE_INSTALL_ROOT" \
      bash "$HOTL_CONFIG_RESOLVE" get plans_dir --default=docs/plans)
[ "$OUT" = "docs/plans" ]
```

**Resolver contract (unambiguous).** `scripts/hotl-config-resolve.sh` is a **command proxy**, not a pure path locator. Its job:

1. Locate `hotl-config.sh` by trying the six resolution locations in documented order. `HOTL_INSTALL_OVERRIDE` (if set) takes priority over all six and is used only by tests.
2. `exec` the located script with all received arguments forwarded unchanged.
3. stdout, stderr, and exit code are passed through from the target.

This means callers (including `hotl-rt`) invoke `hotl-config-resolve.sh get <field> [--default=<v>]` and get identical output to calling `hotl-config.sh` directly — they just do not need to know where `hotl-config.sh` lives. In-repo callers can skip the resolver and use `scripts/hotl-config.sh` directly.

#### Group C — Decision log opt-in contract

**C1. No config → no log file created.**

```bash
cd "$(mktemp -d)"
# WHEN hotl-rt decision-log primitive is invoked
bash "$HOTL_RT" log-decision '{"event":"test"}'
[ "$?" -eq 0 ]
# THEN no .hotl/ directory and no decisions log exist
[ ! -e .hotl ]
[ ! -e .hotl/decisions.log ]
find . -name 'decisions.log' | head -1 | grep -q . && exit 1 || true
```

**C2. `decision_log_path` set → writes to that path.**

```bash
cd "$(mktemp -d)"
mkdir -p .hotl
echo "decision_log_path: .hotl/decisions.log" > .hotl/config.yml
bash "$HOTL_RT" log-decision '{"event":"approved","risk":"low"}'
[ -f .hotl/decisions.log ]
grep -q '"event":"approved"' .hotl/decisions.log
```

**C3. `decision_log_path` points to a new directory → directory is created.**

```bash
cd "$(mktemp -d)"
mkdir -p .hotl
echo "decision_log_path: docs/decisions/log.md" > .hotl/config.yml
bash "$HOTL_RT" log-decision '{"event":"approved"}'
[ -f docs/decisions/log.md ]
```

**C4. Append-only semantics.**

```bash
cd "$(mktemp -d)"
mkdir -p .hotl
echo "decision_log_path: .hotl/decisions.log" > .hotl/config.yml
bash "$HOTL_RT" log-decision '{"event":"first"}'
bash "$HOTL_RT" log-decision '{"event":"second"}'
LINES=$(wc -l < .hotl/decisions.log)
[ "$LINES" -eq 2 ]
grep -q '"event":"first"' .hotl/decisions.log
grep -q '"event":"second"' .hotl/decisions.log
```

#### Group D — Small-user safety regression

The load-bearing tests. Enforce §9 of the design doc for non-opted-in users. Scoped to the Slice 1 surface: the new runtime primitive + resolver. End-to-end coverage of the higher-level flows (`brainstorming`, `writing-plans`, `setup-project`) is NOT automated in Slice 1 — those skills are untouched here, and the manual verification step (§2 verification plan step 7) covers the real end-to-end path. Automated assertions in D1/D1b are narrower, as documented per-test below.

**D1. `hotl-rt` with no config creates no initiative-support artifacts.** Exercises the actual Slice 1 surface directly — no end-to-end driver needed.

```bash
cd "$(mktemp -d)"
git init -q

# Invoke every new Slice 1 surface that could create files.
bash "$HOTL_RT" log-decision '{"event":"test"}'
bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans >/dev/null
bash "$HOTL_CONFIG_SH" get decision_log_path >/dev/null

# THEN none of the forbidden initiative-support artifacts (§9) exist:
for forbidden in \
  .hotl/config.yml \
  .hotl/decisions.log \
  docs/designs \
  docs/decisions \
  docs/requirements \
  docs/reviews \
  docs/prompts; do
  [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created"; exit 1; }
done
```

Note: this test forbids only the initiative-support artifacts listed in §9 of the design doc. Baseline runtime artifacts under `.hotl/state/` and `.hotl/reports/` are existing behavior produced by normal execution flows and are NOT forbidden — they are out of scope for this test because Slice 1 does not invoke those flows.

**D1b. Baseline `hotl-rt` behavior remains green.** Runs `bats test/runtime-integration.bats` unmodified and asserts exit 0. What this proves: the existing `hotl-rt` commands (state/reports creation, workflow execution against fixture workflows) behave identically after Slice 1 lands. What it does NOT prove: anything about `brainstorming`, `writing-plans`, `setup-project`, or real end-to-end user flows — those are out of scope for automated Slice 1 checks and are verified manually per §2 verification plan step 7.

**D2. Command inventory unchanged.**

```bash
# WHEN we list hotl commands
CMDS=$(ls commands/*.md | wc -l)
# THEN count equals the pre-Slice-1 baseline (captured as a fixture)
[ "$CMDS" -eq "$(cat test/fixtures/pre-slice-1-command-count.txt)" ]
```

**D3. `using-hotl` skill-table length unchanged.**

```bash
# Extract skill count from using-hotl/SKILL.md
SKILLS=$(grep -c '^| `' skills/using-hotl/SKILL.md)
[ "$SKILLS" -eq "$(cat test/fixtures/pre-slice-1-skill-count.txt)" ]
```

### Verification plan

1. Implement `scripts/hotl-config.sh` (see §4 Scope).
2. Extend `runtime/hotl-rt` with the `log-decision` subcommand.
3. Author `test/slice-1-smoke.bats` containing Groups A–D.
4. Capture baseline fixtures (`pre-slice-1-command-count.txt`, `pre-slice-1-skill-count.txt`) from main before any Slice 1 code lands.
5. Run `bats test/slice-1-smoke.bats` — must be all green.
6. Run the existing `bats test/smoke.bats` — must remain all green (no regressions).
7. Manual: on a personal repo with no prior `.hotl/config.yml`, run `/hotl:brainstorm` → `/hotl:write-plan` → `/hotl:loop` on a trivial feature. Expected afterwards:
   - **Must not exist** (forbidden initiative-support artifacts, per §9): `.hotl/config.yml`, `.hotl/decisions.log`, `docs/designs/`, `docs/decisions/`, `docs/requirements/`, `docs/reviews/`, `docs/prompts/`.
   - **May exist** (baseline runtime artifacts produced by normal execution — not forbidden): `.hotl/state/*.json`, `.hotl/reports/*.md`, `hotl-workflow-*.md` at project root, the tactical plan under `docs/plans/`. These are existing behavior, not Slice 1 changes.

### Regression surface

- `runtime/hotl-rt` — new subcommand; existing commands must not change behavior.
- `scripts/document-lint.sh` — no changes, but its resolution pattern is reused; if that pattern changes, our resolution documentation must follow.
- `test/smoke.bats` — existing tests must continue to pass.
- `skills/using-hotl/SKILL.md` — must NOT change (§D3 enforces).
- `commands/` — must NOT gain new files (§D2 enforces).

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo). This is infrastructure; no PM sign-off needed since there is no user-visible surface in this slice.

**Review gates.**

1. Plan review (this doc) → approved when the smoke-test spec in §2.1 is deemed both sufficient and runnable.
2. Code review on the implementation PR → reviewer runs `bats test/slice-1-smoke.bats` locally.
3. Pre-merge check: full `bats test/` suite green + manual trial on a scratch repo (§2 verification step 7).

**Exit criteria.**

- `scripts/hotl-config.sh` exists and passes Groups A, B.
- `runtime/hotl-rt log-decision` exists and passes Group C.
- `test/slice-1-smoke.bats` exists and is green in CI.
- Baseline fixtures captured and checked in.
- No user-visible change (Group D green).
- CHANGELOG.md entry added under `Unreleased`.

**Rollback plan.** Slice 1 is pure-additive (one new script, one new `hotl-rt` subcommand, one new test file, two fixture files). Revert the implementation commit — no migrations, no file moves, no renames. Existing users are unaffected whether Slice 1 is present or not.

---

## 4. Scope

### In scope (ships in this slice)

1. `scripts/hotl-config.sh` — canonical config reader with `get <field> [--default=<value>]` subcommand. Parses `.hotl/config.yml` from the caller's working directory. Handles absence, unset field, and malformed config per §2.1 Group A.
2. `scripts/hotl-config-resolve.sh` — command proxy per §2.1 Group B2. Locates `hotl-config.sh` via the six-location order (honoring `HOTL_INSTALL_OVERRIDE` when set — test-only), then `exec`s it with argv forwarded unchanged. No independent parsing; stdout, stderr, and exit code pass through from the target.
3. `runtime/hotl-rt` — new `log-decision <json>` subcommand. Reads `decision_log_path` via `hotl-config-resolve.sh get decision_log_path` (no default). Empty result → no-op. Non-empty result → append JSON line to the path, creating parent dirs if needed. Must not parse YAML independently.
4. `skills/document-review/SKILL.md` — documentation-only addition: a six-location resolution block for `hotl-config.sh` mirroring the existing `document-lint.sh` block shape. Source of truth for §2.1 Group B1 parity test. No behavioral change.
5. `test/slice-1-smoke.bats` — the runnable spec from §2.1.
6. `test/fixtures/pre-slice-1-command-count.txt` — baseline command count.
7. `test/fixtures/pre-slice-1-skill-count.txt` — baseline skill-table row count.
8. `CHANGELOG.md` — `Unreleased` entry noting the new scripts and the opt-in decision-log primitive.

### Out of scope (deferred to later slices)

- Any *behavioral* change to `brainstorming`, `writing-plans`, `setup-project`, or `document-review`. (The documentation-only resolution block added to `skills/document-review/SKILL.md` is in scope — see §4 in-scope item 4 — but it adds no new behavior.)
- The `-plan.md` rename (Slice 2).
- Any new `.hotl/config.yml` field being *consumed* by a skill (Slice 2 onward).
- Templates, scaffolder, operating-model docs (Slices 3–5).

---

## 5. Module-level changes

| File | Change |
|---|---|
| `scripts/hotl-config.sh` (NEW) | Canonical config reader (parses `.hotl/config.yml`) |
| `scripts/hotl-config-resolve.sh` (NEW) | Command proxy: locates `hotl-config.sh` via six-location order (honoring `HOTL_INSTALL_OVERRIDE` for tests), then `exec`s it with argv forwarded unchanged. Used by `hotl-rt` and by callers outside the plugin repo. In-repo callers use `scripts/hotl-config.sh` directly |
| `runtime/hotl-rt` | Add `log-decision` subcommand (shells out via `hotl-config-resolve.sh`) |
| `test/slice-1-smoke.bats` (NEW) | Smoke test file for this slice |
| `test/fixtures/pre-slice-1-command-count.txt` (NEW) | Baseline |
| `test/fixtures/pre-slice-1-skill-count.txt` (NEW) | Baseline |
| `skills/document-review/SKILL.md` | Add a six-location resolution block for `hotl-config.sh` mirroring the existing `document-lint.sh` block (so B1 doc-parity test has something to compare against) |
| `CHANGELOG.md` | `Unreleased` entry |

No other files change in Slice 1. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown (feeds `writing-plans`)

1. Capture baselines: `ls commands/*.md | wc -l` and `grep -c '^| \`' skills/using-hotl/SKILL.md` → check into `test/fixtures/`. **Must be the first commit.**
2. Implement `scripts/hotl-config.sh` with the `get` subcommand. Include shebang, `set -euo pipefail`, usage text on stderr for unknown subcommands.
3. Implement `scripts/hotl-config-resolve.sh` — command proxy. Locates `hotl-config.sh` via the six-location order (honoring `HOTL_INSTALL_OVERRIDE` when set, test-only) and `exec`s it with argv forwarded unchanged. No independent parsing — all output comes from the located target.
4. Add the `hotl-config.sh` resolution block to `skills/document-review/SKILL.md` mirroring the `document-lint.sh` block shape.
5. Author Group A tests in `test/slice-1-smoke.bats` and make them pass.
6. Author Group B tests (B1 doc-parity, B2 synthetic install — both always run).
7. Extend `runtime/hotl-rt` with `log-decision` subcommand. Must shell out via `hotl-config-resolve.sh` — do not parse YAML independently.
8. Author Group C tests. Verify they pass.
9. Author Group D tests. D1 exercises the Slice 1 surface directly (no end-to-end driver); D1b runs `bats test/runtime-integration.bats` unmodified and asserts green.
10. Run full `bats test/` — must be green, including all pre-existing suites.
11. Update `CHANGELOG.md`.
12. Open PR; reviewer reruns the full suite and inspects the diff against the file list in §5.

---

## 7. Open questions

None. If any emerge during implementation, add them here and re-review before proceeding.
