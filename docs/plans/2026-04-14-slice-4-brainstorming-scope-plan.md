# Slice 4 — Brainstorming Scope Question

**Status:** Proposed — for review
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted), Slices 1–3 (shipped)
**Strategy reference:** `docs/designs/initiative-support.md` §6 flow by scope, §9 small-user safety contract, §12 Slice 4

---

## 1. Intent contract

**What this slice is for.** Wire the first consumer of the Slice 3 strategic template into `brainstorming`. Add an explicit scope question (`feature | phase | initiative`) to the brainstorming flow, default it to `feature`, and route initiative scope to `docs/designs/<topic>.md` using `adapters/strategic-design.template.md` as the structural reference.

This is the slice where a template from Slice 3 stops being inert. Users who pick initiative scope opt into the initiative tier; everyone else sees unchanged behavior.

**What this slice is NOT for.**

- No `setup-project` scaffolder (Slice 5) — no `.hotl/config.yml` is created by this slice, no `docs/designs/` is pre-scaffolded, no taxonomy folders are pre-created.
- No change to the feature / phase output path or contents. `docs/plans/YYYY-MM-DD-<topic>-plan.md` remains the tactical default (established in Slice 2).
- No use of `tactical-plan.template.md` by the feature / phase paths. Those keep today's behavior; wiring the tactical template is a future slice if wanted.
- No changes to `writing-plans`, `executing-plans`, `loop-execution`, or the runtime.
- No new commands, no new skills in the `using-hotl` index.
- No phase-kickoff workflow (Slice 6).

**Primary audience / user story.** A user running `/hotl:brainstorm` on a multi-phase initiative answers "initiative" to a scope question and gets a durable strategic design doc at `docs/designs/<topic>.md`. The doc follows the structure of the Slice 3 strategic template — problem, vision, non-goals, stakeholders, phase breakdown, etc.

**Scope-question UX (single contract).** The scope question is always part of the flow — the skill documents it and the agent always decides between the three values. How that decision surfaces depends on the user's initial message:

- **Clear feature request** (e.g., "add a rate limiter to the API"). The agent selects `feature` and proceeds — optionally with a one-line confirmation ("Treating as feature scope; say so if this should be a phase or initiative"). No interactive prompt blocks the flow. For these users the experience is effectively identical to today.
- **Ambiguous or multi-phase intent** (e.g., "migrate the backend from v1 to v2 across services"). The agent explicitly asks the scope question with the three choices and the `feature` default, and waits for the user's answer before proceeding.

Both paths run the same scope-decision step; the difference is whether the agent proceeds on the pre-filled default or waits for an explicit override. This is the single UX contract — no second variant.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-4-smoke.bats`. Full `bats test/` remains green (210 prior + new Slice 4 tests).

### 2.1 Smoke test spec (runnable)

Group letters continue from Slices 1 (A–D), 2 (E–H), 3 (I–L). Slice 4 uses M/N/O/P.

#### Group M — SKILL.md scope question and path routing

**M1. `brainstorming` SKILL.md documents the three-choice scope question with `feature` as the default.**

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"

# All three scope values appear in the skill as whole words. Uses grep -w
# (POSIX-portable — \b is a GNU extension, not available in BSD/macOS grep).
grep -qw feature "$skill"
grep -qw phase "$skill"
grep -qw initiative "$skill"

# "Scope" is called out as a question or step (case-insensitive).
grep -qi 'scope.*question\|scope.*(feature.*phase.*initiative)\|ask.*scope' "$skill"

# feature is the default — documented as such.
grep -qiE '(default|prefill)[[:space:]:]+.*feature' "$skill"
```

**M2. Initiative scope routes output to `docs/designs/<topic>.md` (undated, durable).**

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
# The initiative output-path instruction line must name docs/designs/ with
# an undated <topic> placeholder — NOT a dated filename. Distinguish from
# the tactical path docs/plans/YYYY-MM-DD-<topic>-plan.md.
grep -qE 'docs/designs/<topic>\.md|docs/designs/\{\{TOPIC\}\}\.md' "$skill"
# The path must NOT be dated for initiative scope — guard against a
# half-done rename where someone prefixed docs/designs/ with YYYY-MM-DD-.
! grep -qE 'docs/designs/YYYY-MM-DD-' "$skill" \
    || { echo "FAIL: docs/designs/ path must be undated (durable tier)"; return 1; }
```

**M3. Feature/phase scope still routes output to `docs/plans/YYYY-MM-DD-<topic>-plan.md` (Slice 2 default preserved).**

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
grep -qE 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' "$skill"
```

**M4. `cline/rules/hotl-brainstorming.md` mirror carries the scope question.**

```bash
mirror="$REPO_ROOT/cline/rules/hotl-brainstorming.md"
# Whole-word matches via -w (POSIX-portable; \b is a GNU extension).
grep -qw feature "$mirror"
grep -qw phase "$mirror"
grep -qw initiative "$mirror"
grep -qi 'scope' "$mirror"
# And the initiative output-path line mirrored.
grep -qE 'docs/designs/<topic>\.md|docs/designs/\{\{TOPIC\}\}\.md' "$mirror"
# Tactical default from Slice 2 preserved in the mirror.
grep -qE 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' "$mirror"
```

#### Group N — Strategic-design template install-path resolution

**N1. `brainstorming` SKILL.md documents the six-location resolution for `adapters/strategic-design.template.md`.**

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
# Same six-location pattern as document-lint.sh and hotl-config.sh. The
# canonical in-repo form is `adapters/strategic-design.template.md` —
# relative-path variants like `scripts/../adapters/...` are NOT accepted,
# so N2's normalizer can unambiguously map the in-repo entry to <in-repo>.
for loc in \
    'adapters/strategic-design\.template\.md' \
    '\.codex/hotl/adapters/strategic-design\.template\.md' \
    '\.codex/plugins/hotl-source/adapters/strategic-design\.template\.md' \
    '\.codex/plugins/cache/codex-plugins/hotl/\*/adapters/strategic-design\.template\.md' \
    '\.cline/hotl/adapters/strategic-design\.template\.md' \
    '\.claude/plugins/hotl/adapters/strategic-design\.template\.md'; do
    grep -qE "$loc" "$skill" \
        || { echo "FAIL: brainstorming SKILL missing resolution location matching /$loc/"; return 1; }
done
```

**N2. Doc-parity: the six **install roots** match `document-lint.sh`'s resolution list, in order.**

Full-path equality cannot be asserted — `document-lint.sh` lives under `scripts/` while the template lives under `adapters/`. The invariant to enforce is that the same six **install roots** appear in the same order. For the in-repo entry the root is empty (normalized to `<in-repo>`); for the five external entries the root is everything before `scripts/` or `adapters/`.

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
dr="$REPO_ROOT/skills/document-review/SKILL.md"

# Strip the backticked path down to its install-root prefix. For each
# numbered-list path:
#   `scripts/document-lint.sh`                      → (empty) → <in-repo>
#   `~/.codex/hotl/scripts/document-lint.sh`        → ~/.codex/hotl/
#   ... and so on for the remaining five external locations.
LINT_ROOTS=$(grep -E '^[0-9]+\. ' "$dr" \
    | grep -Eo '`[^`]*document-lint\.sh`' \
    | sed 's|^`||; s|`$||' \
    | sed -E 's|(.*/)?scripts/document-lint\.sh$|\1|' \
    | sed 's|^$|<in-repo>|')
TMPL_ROOTS=$(grep -E '^[0-9]+\. ' "$skill" \
    | grep -Eo '`[^`]*strategic-design\.template\.md`' \
    | sed 's|^`||; s|`$||' \
    | sed -E 's|(.*/)?adapters/strategic-design\.template\.md$|\1|' \
    | sed 's|^$|<in-repo>|')

[ -n "$LINT_ROOTS" ]
[ -n "$TMPL_ROOTS" ]

LINT_COUNT=$(printf '%s\n' "$LINT_ROOTS" | wc -l | tr -d ' ')
TMPL_COUNT=$(printf '%s\n' "$TMPL_ROOTS" | wc -l | tr -d ' ')
[ "$LINT_COUNT" -eq 6 ]
[ "$TMPL_COUNT" -eq 6 ]

# First entry is <in-repo> in both (expected, subdir differs).
# Remaining five install roots must match exactly, in order.
[ "$LINT_ROOTS" = "$TMPL_ROOTS" ]
```

#### Group O — `designs_dir` config consumption

**O1. `hotl-config-resolve.sh get designs_dir --default=docs/designs` returns the default when no config is present.**

```bash
cd "$TMP"
run bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs
[ "$status" -eq 0 ]
[ "$output" = "docs/designs" ]
```

**O2. `hotl-config-resolve.sh get designs_dir` returns the configured override when `.hotl/config.yml` sets `designs_dir`.**

```bash
cd "$TMP"
mkdir -p .hotl
echo "designs_dir: docs/strategy" > .hotl/config.yml
run bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs
[ "$status" -eq 0 ]
[ "$output" = "docs/strategy" ]
```

**O3. `brainstorming` SKILL.md instructs the agent to resolve `designs_dir` via `hotl-config-resolve.sh`.**

```bash
skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
# The skill must mention hotl-config-resolve.sh AND the designs_dir field
# AND the --default=docs/designs fallback.
grep -q 'hotl-config-resolve\.sh' "$skill"
grep -q 'designs_dir' "$skill"
grep -q -- '--default=docs/designs' "$skill"
```

#### Group P — small-user safety regression

**P1. Command and skill counts unchanged from pre-Slice-4 baseline.**

```bash
EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-4-command-count.txt")
ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
[ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-4-skill-count.txt")
ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
[ "$ACTUAL_SKILLS" -eq "$EXPECTED_SKILLS" ]
```

**P2. Slice 4 surface in a clean repo creates no forbidden initiative-support artifacts when the default scope (feature) would apply.**

```bash
cd "$TMP"
git init -q

# Exercise the Slice 4 surface that is actually executable:
# - hotl-config-resolve.sh get designs_dir (Slice 4's new config consumer)
# - hotl-rt log-decision (prior slice, included for integration check)
# brainstorming itself is a markdown skill — its agent-facing flow is
# covered by the manual verification step in §2 verification plan.
bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs >/dev/null
bash "$HOTL_RT" log-decision '{"event":"test"}'

for forbidden in \
    .hotl/config.yml \
    .hotl/decisions.log \
    docs/designs \
    docs/decisions \
    docs/requirements \
    docs/reviews \
    docs/prompts; do
    [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created"; return 1; }
done
```

**P3. Templates from Slice 3 are now consumed by `brainstorming` — but only `strategic-design.template.md` (initiative scope). The other three remain inert.**

```bash
# strategic-design.template.md SHOULD now be referenced by brainstorming.
grep -q 'strategic-design\.template\.md' \
    "$REPO_ROOT/skills/brainstorming/SKILL.md"

# The other three templates must STILL be inert after Slice 4 — only
# referenced in docs/, test/, adapters/, .git/, CHANGELOG.md.
for tmpl_name in \
    tactical-plan.template.md \
    initiative-playbook.template.md \
    initiative-operating-model.template.md; do
    refs=$(grep -rl "$tmpl_name" "$REPO_ROOT" 2>/dev/null \
        | grep -vE '^'"$REPO_ROOT"'/(docs/|test/|adapters/|\.git/|CHANGELOG\.md)' \
        || true)
    [ -z "$refs" ] \
        || { echo "FAIL: $tmpl_name prematurely consumed by: $refs"; return 1; }
done
```

**P4. Prior slice smoke suites remain green.**

```bash
run bats "$REPO_ROOT/test/slice-1-smoke.bats"
[ "$status" -eq 0 ]
run bats "$REPO_ROOT/test/slice-2-smoke.bats"
[ "$status" -eq 0 ]
run bats "$REPO_ROOT/test/slice-3-smoke.bats"
[ "$status" -eq 0 ]
```

### Verification plan

1. Capture `test/fixtures/pre-slice-4-command-count.txt` and `pre-slice-4-skill-count.txt` from current `main`. **First commit.**
2. Update `skills/brainstorming/SKILL.md`:
   - Add an explicit scope-question step (with `feature` as the default) between the current "Explore context" step and the current "Ask clarifying questions" step — the placement resolved in §7 Q1. Do not place it before "Explore context".
   - Add a path-routing block that sends initiative scope to `docs/designs/<topic>.md` (undated) and feature/phase to the existing `docs/plans/YYYY-MM-DD-<topic>-plan.md` default.
   - Add the six-location install-path resolution block for `adapters/strategic-design.template.md` (mirroring `document-review/SKILL.md`'s hotl-config.sh block).
   - Add the `designs_dir` resolution instruction via `hotl-config-resolve.sh get designs_dir --default=docs/designs`.
3. Update `cline/rules/hotl-brainstorming.md` to mirror the same scope question and path routing.
4. Author `test/slice-4-smoke.bats` with Groups M/N/O/P. Make all tests green.
5. Run full `bats test/` — must be green end-to-end (210 prior plus Slice 4 additions).
6. Update `CHANGELOG.md` with an Unreleased entry.
7. **Manual verification** on a personal scratch repo with no prior `.hotl/config.yml`. The UX contract under test is documented in §1 ("Scope-question UX — single contract"); verify both paths.
   - **Clear-feature path.** Run `/hotl:brainstorm` with an unambiguous feature description (e.g., "add a rate limiter to the API"). Confirm the agent proceeds without blocking for a scope choice — either silently or with a one-line acknowledgment that it is treating the request as `feature` scope. Confirm the tactical plan lands at `docs/plans/YYYY-MM-DD-<topic>-plan.md` exactly as today.
   - **Ambiguous / multi-phase path.** Run `/hotl:brainstorm` with a request that reads as multi-phase (e.g., "migrate the backend from v1 to v2 across services"). Confirm the agent explicitly asks the scope question with `feature | phase | initiative` choices and `feature` as the pre-filled default. Answer `initiative`. Confirm the produced design doc lands at `docs/designs/<topic>.md` (undated filename), follows the structure of `adapters/strategic-design.template.md`, and does not touch any other `docs/<dir>/`.
   - **`designs_dir` override path.** Set `designs_dir: docs/strategy` in `.hotl/config.yml`, re-run with initiative scope, confirm the output lands in `docs/strategy/<topic>.md` instead.
   - **Safety invariants.** Confirm no other forbidden initiative-support directories (`docs/decisions/`, `docs/requirements/`, etc.) were created by any of the runs above.

### Regression surface

- `skills/brainstorming/SKILL.md` — adds new steps; the existing flow continues to apply when scope is `feature`. Backwards-compatible.
- `cline/rules/hotl-brainstorming.md` — mirror only. Same backwards-compat property.
- `scripts/hotl-config-resolve.sh` — unchanged. `designs_dir` is a new field it returns but the resolver is generic and already handles arbitrary fields.
- No runtime changes. `hotl-rt`, `scripts/document-lint.sh`, `scripts/hotl-config.sh` untouched.

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo). Review process mirrors prior slices.

**Review gates.**

1. Plan review (this doc) — approved when §2.1 is sufficient and runnable, and the SKILL changes are deemed backwards-compatible for the default `feature` path.
2. Code review on the implementation PR — reviewer runs `bats test/slice-4-smoke.bats` and full suite locally.
3. Pre-merge: full `bats test/` green (§2 step 5) + manual scratch-repo trial (§2 step 7).

**Exit criteria.**

- `test/slice-4-smoke.bats` green.
- Full `bats test/` green — 210+ prior tests plus new Slice 4 tests.
- Pre-slice-4 fixtures captured before any SKILL change and checked in.
- Default `feature` scope path produces output identical in location and structure to today's brainstorming flow (verified manually via step 7).
- `CHANGELOG.md` entry under `Unreleased`.

**Rollback plan.** Slice 4 touches one canonical skill (`skills/brainstorming/SKILL.md`) plus its cline mirror. Revert the implementation commit — brainstorming returns to today's feature-only flow. No files created in user repos before rollback need migration; `docs/designs/<topic>.md` files produced during Slice 4 remain valid Markdown even after rollback (they just become orphan docs until a later slice re-enables the initiative flow).

---

## 4. Scope

### In scope (ships in this slice)

1. `skills/brainstorming/SKILL.md` — scope question added (feature/phase/initiative, default feature), path routing logic added (initiative → `docs/designs/<topic>.md`, feature/phase → existing `docs/plans/YYYY-MM-DD-<topic>-plan.md`), six-location install-path resolution block added for `adapters/strategic-design.template.md`, `designs_dir` resolution via `hotl-config-resolve.sh` documented.
2. `cline/rules/hotl-brainstorming.md` — mirror of the canonical skill updates (scope question, path routing). The cline mirror does not need the full six-location resolution block — cline environments resolve templates via their own plugin install path.
3. `test/slice-4-smoke.bats` — Groups M/N/O/P runnable spec.
4. `test/fixtures/pre-slice-4-command-count.txt` — baseline snapshot.
5. `test/fixtures/pre-slice-4-skill-count.txt` — baseline snapshot.
6. `CHANGELOG.md` — Unreleased entry.

### Out of scope (deferred to later slices)

- `setup-project` scaffolder that writes `.hotl/config.yml` and renders the Slice 3 templates into a user repo (Slice 5).
- `phase-kickoff` workflow (Slice 6).
- Using `tactical-plan.template.md` as the structural reference for feature/phase scope — explicit non-goal. Feature/phase keep today's prose format.
- Any linter or skill that consumes `initiative-playbook.template.md` or `initiative-operating-model.template.md` — those remain inert until Slice 5.
- Any new `.hotl/config.yml` schema field beyond `designs_dir` (already present in the Slice 1 schema per design §8).

---

## 5. Module-level changes

| File | Change |
|---|---|
| `skills/brainstorming/SKILL.md` | Scope question (feature/phase/initiative, default feature); path routing (initiative → `docs/designs/<topic>.md`, feature/phase → `docs/plans/YYYY-MM-DD-<topic>-plan.md`); six-location install-path resolution block for `adapters/strategic-design.template.md` mirroring `document-review/SKILL.md:54-59`; `designs_dir` resolution via `bash <resolved-hotl-config-resolve.sh> get designs_dir --default=docs/designs` |
| `cline/rules/hotl-brainstorming.md` | Mirror: scope question + path routing. No six-location block needed for the mirror |
| `test/slice-4-smoke.bats` (NEW) | Runnable spec for Groups M/N/O/P |
| `test/fixtures/pre-slice-4-command-count.txt` (NEW) | Baseline |
| `test/fixtures/pre-slice-4-skill-count.txt` (NEW) | Baseline |
| `CHANGELOG.md` | Unreleased entry |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. Capture baselines: write `test/fixtures/pre-slice-4-command-count.txt` and `pre-slice-4-skill-count.txt` from current `main`. **First commit.**
2. Update `skills/brainstorming/SKILL.md` with the scope question, path routing, template install-path resolution block, and `designs_dir` resolver instruction.
3. Update `cline/rules/hotl-brainstorming.md` to mirror the scope question and path routing.
4. Author `test/slice-4-smoke.bats` with Groups M/N/O/P. Run and confirm green.
5. Run full `bats test/` — must be green.
6. Update `CHANGELOG.md`.

---

## 7. Open questions

1. ~~**Where in the skill flow does the scope question land?**~~ **Resolved.** Insert as a new step between "Explore context" (current step 1) and "Ask clarifying questions" (current step 2). The verification plan (§2 step 2) and smoke-test assertions already assume this placement; a later slice may relocate it if calibration shows a better fit. Rationale: scope determines the shape of every downstream step (output path, contract structure, depth of inquiry), so deciding it before the clarifying-questions loop avoids backtracking.
2. ~~**Silent-default mechanism.**~~ **Resolved.** The single UX contract is documented in §1 "Scope-question UX". Clear-feature requests proceed without blocking (optionally with a one-line acknowledgment); ambiguous or multi-phase requests surface the scope question explicitly. Both paths run the same scope-decision step — the only difference is whether the agent waits for an explicit override. The manual verification step (§2 verification plan step 7) exercises both paths.
3. **Template read depth.** For initiative scope, should brainstorming read `strategic-design.template.md` once at session start (using it as the design skeleton) or reference it by section as each is written? Leaning: read-once at start, cache the section ordering and any mandatory fields. Reduces back-and-forth and keeps the session shape stable.
