# Slice 2 — Tactical Rename and Workflows-Dir Consumer

**Status:** Proposed — for review
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted), `docs/plans/2026-04-14-slice-1-config-reader-plan.md` (shipped)
**Strategy reference:** `docs/designs/initiative-support.md` §2 scope-of-no-change, §5 three tiers, §12 Slice 2

---

## 1. Intent contract

**What this slice is for.** Bundle two changes that must ship together:

1. Rename the tactical default output suffix from `-design.md` to `-plan.md` in all producers and every downstream consumer that treats `-design.md` as a HOTL-owned artifact.
2. Make `writing-plans` honor `workflows_dir` from `.hotl/config.yml` (via `hotl-config-resolve.sh` from Slice 1), so opted-in projects can park `hotl-workflow-*.md` anywhere — default stays project root.

These are bundled because the no-orphaned-pairs rule (design §12) forbids shipping the rename producer (`brainstorming`'s new default suffix) without also shipping every consumer that would otherwise treat `-plan.md` as generic markdown. Bundling in one slice leaves no window where the new suffix exists and is rejected.

**What this slice is NOT for.**

- No new templates, no scaffolder, no new commands, no new skills (those come in Slices 3–6).
- No migration of existing `-design.md` files. Consumers continue to accept both suffixes forever; old files are never renamed.
- No behavior change to `hotl-workflow-*.md` format or execution semantics.
- No change to the decision-log primitive from Slice 1.
- No auto-creation of `docs/designs/`, `docs/decisions/`, or any other initiative-support directory.

**Primary audience / user story.** Existing hotl-plugin users continue using `/hotl:brainstorm` → `/hotl:write-plan` → `/hotl:loop` exactly as today; the only observable change is the filename suffix of new tactical plan docs. Projects that opt in via `.hotl/config.yml: workflows_dir: …` can collocate their workflow files with their plans.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-2-smoke.bats`. The plan's tests are authored as part of this slice and must be green before the CHANGELOG entry is written.

Existing bats suites (`test/smoke.bats`, `test/runtime.bats`, `test/runtime-integration.bats`, `test/slice-1-smoke.bats`, plus all scenario suites) remain green with zero regressions.

### 2.1 Smoke test spec (runnable)

Tests are grouped by the contract they enforce. Group letters continue from Slice 1 (A–D used) so naming stays unambiguous across the rollout.

#### Group E — `document-lint.sh` accepts both suffixes

**E1. Lint classifies `*-plan.md` as design doc and validates it identically to `*-design.md`.**

```bash
# GIVEN two fixtures with identical HOTL-contract content, one named
#       *-design.md and one named *-plan.md
cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-demo-design.md"
cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-demo-plan.md"

# WHEN lint runs on each
run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-design.md"
LINT_DESIGN_STATUS="$status"
run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-plan.md"
LINT_PLAN_STATUS="$status"

# THEN both pass with exit 0 (same classification, same checks)
[ "$LINT_DESIGN_STATUS" -eq 0 ]
[ "$LINT_PLAN_STATUS" -eq 0 ]
```

**E2. Lint rejects a file that has neither suffix nor `hotl-workflow-` prefix.**

```bash
# Preserves today's skip-non-HOTL behavior: unrelated markdown exits 0 silently.
cp "$FIXTURES/sample-design.md" "$TMP/random-notes.md"
run bash "$DOCUMENT_LINT" "$TMP/random-notes.md"
[ "$status" -eq 0 ]
echo "$output" | grep -qi "skip"
```

**E3. Lint usage text mentions both suffixes.**

```bash
run bash "$DOCUMENT_LINT"
[ "$status" -ne 0 ]
# Usage text must document both accepted design suffixes.
echo "$output" | grep -q '\-design\.md'
echo "$output" | grep -q '\-plan\.md'
```

#### Group F — SKILL.md content parity between suffixes

These tests read SKILL.md files directly and assert that every place today's docs mention `-design.md` either still mentions it, or mentions both. This protects against a half-finished rename.

**F1. `brainstorming` default output path is `-plan.md`.**

```bash
# The canonical output-path instruction line must now produce -plan.md.
grep -E 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' \
    "$REPO_ROOT/skills/brainstorming/SKILL.md"
```

**F2. Every executor/reviewer rule line that previously named `*-design.md` now names both suffixes.**

Presence of the strings `-design.md` and `-plan.md` somewhere in a file is not sufficient — a stale rule could keep the old glob while the new suffix shows up only in surrounding prose. The assertions below match the actual rule lines (exclusion globs, classification-table entries) and require both literal globs `docs/plans/*-design.md` and `docs/plans/*-plan.md` to appear on the same rule line.

**Allowed form — two literal globs on one line, in either order.** Brace-expansion forms like `docs/plans/*-{design,plan}.md` are **not** accepted by this spec: they complicate the behavioral check in F2b and are not idiomatic for the HOTL docs. Implementers must write both globs out explicitly.

```bash
# Executor dirty-worktree exclusion globs must name both suffixes on the
# same rule line (line 44 of loop-execution, line 32 of executing-plans).
for skill in \
    skills/loop-execution/SKILL.md \
    skills/executing-plans/SKILL.md; do
    # A single line must contain BOTH literal globs.
    grep -E 'docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md' \
        "$REPO_ROOT/$skill" \
        || { echo "FAIL: $skill exclusion line does not name both suffixes"; return 1; }
done

# document-review classification table (line 22) must name both suffixes
# in the same row/line.
grep -E 'docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md' \
    "$REPO_ROOT/skills/document-review/SKILL.md" \
    || { echo "FAIL: document-review classification line does not name both suffixes"; return 1; }

# cline mirrors must carry the same updated rule line.
for mirror in \
    cline/rules/hotl-execution.md \
    cline/rules/hotl-document-review.md; do
    grep -E 'docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md' \
        "$REPO_ROOT/$mirror" \
        || { echo "FAIL: $mirror rule line does not name both suffixes"; return 1; }
done
```

**F2b. Executor exclusion glob actually exempts a representative `*-plan.md` file (behavioral, not text-only).**

```bash
# Realize the behavior by constructing a repo state where a *-plan.md file
# is dirty and confirming the executor exclusion logic considers it HOTL-
# owned. Since the executor itself is a markdown skill (not a direct shell
# binary), this test reuses the existing smoke.bats pattern: extract the
# glob list from the rule line (F2's canonical two-literal-globs form) and
# assert both appear, then assert the *-plan.md glob actually matches a
# representative file.
GLOB_LINE=$(grep -E 'docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md' \
    "$REPO_ROOT/skills/loop-execution/SKILL.md" | head -1)
[ -n "$GLOB_LINE" ]
# Both literal globs (guaranteed by F2's canonical form).
for glob in 'docs/plans/*-plan.md' 'docs/plans/*-design.md'; do
    echo "$GLOB_LINE" | grep -qF "$glob"
done

# Behavioral: the -plan.md glob actually resolves a representative file.
cd "$TMP"
mkdir -p docs/plans
touch docs/plans/2026-04-14-demo-plan.md
shopt -s nullglob
MATCHES=(docs/plans/*-plan.md)
[ ${#MATCHES[@]} -eq 1 ]
[ "${MATCHES[0]}" = "docs/plans/2026-04-14-demo-plan.md" ]
```

**F3. `cline/rules/hotl-brainstorming.md` mirror updated to `-plan.md`.**

```bash
grep -q 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' \
    "$REPO_ROOT/cline/rules/hotl-brainstorming.md"
```

#### Group G — `writing-plans` honors `workflows_dir`

**G1. Without config, `writing-plans` guidance still points to project root.**

`writing-plans` is a markdown skill — the test verifies that the SKILL.md content documents the resolution rule and references `hotl-config-resolve.sh`. No runtime behavior to exercise directly.

```bash
# Default path documented
grep -qE 'Save to (project root|workflows_dir)' \
    "$REPO_ROOT/skills/writing-plans/SKILL.md"
# Config resolver documented as the source of truth for workflows_dir
grep -q 'hotl-config-resolve\.sh' \
    "$REPO_ROOT/skills/writing-plans/SKILL.md" \
    || grep -q 'workflows_dir' "$REPO_ROOT/skills/writing-plans/SKILL.md"
```

**G2. Config resolver honors `workflows_dir` override.**

```bash
# Exercise the end-to-end contract from the runtime side: the same proxy
# that writing-plans instructs the agent to call must return the custom dir.
cd "$TMP"
mkdir -p .hotl
echo "workflows_dir: docs/workflows" > .hotl/config.yml
OUT=$(bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=.)
[ "$OUT" = "docs/workflows" ]
```

**G3. Default preserved when config absent.**

```bash
cd "$TMP"
OUT=$(bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=.)
[ "$OUT" = "." ]
```

#### Group H — small-user safety regression

Scoped to Slice 2 producers + `writing-plans`. The load-bearing invariant is still design §9: no new non-opt-in files appear in a user repo.

**H1. Existing `-design.md` files remain accepted by every consumer — both behaviorally (lint) and by the specific rule lines in each consumer file.**

```bash
# Behavioral: a real -design.md file still passes lint end-to-end.
cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-legacy-design.md"
run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-legacy-design.md"
[ "$status" -eq 0 ]

# Rule-line: document-review classification table row (line 22 today) must
# still name docs/plans/*-design.md as one of its two literal globs — the
# same canonical form F2 requires. This rules out a stale rule that kept
# only -plan.md while -design.md appears only in surrounding prose.
grep -E 'docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md' \
    "$REPO_ROOT/skills/document-review/SKILL.md" \
    || { echo "FAIL: document-review classification line does not carry both literal globs"; return 1; }

# Rule-line: executor dirty-worktree exclusion globs (loop-execution line 44,
# executing-plans line 32) must still list the literal docs/plans/*-design.md
# glob.
for skill in \
    skills/loop-execution/SKILL.md \
    skills/executing-plans/SKILL.md; do
    grep -qF 'docs/plans/*-design.md' "$REPO_ROOT/$skill" \
        || { echo "FAIL: $skill exclusion no longer names literal docs/plans/*-design.md"; return 1; }
done

# Behavioral round-trip: a -design.md file in docs/plans/ matches the glob.
cd "$TMP"
mkdir -p docs/plans
touch docs/plans/2026-04-14-legacy-design.md
shopt -s nullglob
MATCHES=(docs/plans/*-design.md)
[ ${#MATCHES[@]} -eq 1 ]
```

**H2. Baseline counts unchanged from pre-Slice-2 snapshot.**

Slice 2 captures a fresh `pre-slice-2-*.txt` fixture pair (commands + skills) before any code changes. D2/D3-equivalent assertions confirm neither count changed.

```bash
EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-command-count.txt")
[ "$(ls $REPO_ROOT/commands/*.md | wc -l | tr -d ' ')" -eq "$EXPECTED_CMDS" ]
EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-skill-count.txt")
[ "$(grep -c '^| `' $REPO_ROOT/skills/using-hotl/SKILL.md)" -eq "$EXPECTED_SKILLS" ]
```

**H3. No new forbidden initiative-support artifacts appear.**

```bash
cd "$TMP" && git init -q
bash "$HOTL_RT" log-decision '{"event":"test"}'
bash "$HOTL_CONFIG_SH" get workflows_dir --default=. >/dev/null
for forbidden in \
    .hotl/config.yml .hotl/decisions.log \
    docs/designs docs/decisions docs/requirements docs/reviews docs/prompts; do
    [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden created"; return 1; }
done
```

**H4. `runtime-integration.bats` remains green.** Same rationale as Slice 1 D1b — proves the hotl-rt changes in this slice (none planned) do not regress baseline runtime behavior.

### Verification plan

1. Capture `test/fixtures/pre-slice-2-command-count.txt` and `pre-slice-2-skill-count.txt` as the FIRST commit of this slice, before any other change.
2. Create `test/fixtures/sample-design.md` — a minimal HOTL-contract design doc used by Group E and H1.
3. Update `scripts/document-lint.sh` to accept both suffixes (classification branch + usage text).
4. Update each SKILL.md and cline rule listed in §5.
5. Update `skills/brainstorming/SKILL.md` default output line to `-plan.md`.
6. Update `skills/writing-plans/SKILL.md` to document `workflows_dir` config via the resolver.
7. Author `test/slice-2-smoke.bats` with Groups E–H. Make it green.
8. Run `bats test/` — must be all green, no regressions.
9. Update `CHANGELOG.md`.
10. **Manual verification** on a personal scratch repo with no prior `.hotl/config.yml`. The scratch repo is a normal consuming repo — `scripts/document-lint.sh` does not exist locally there. Resolve the lint script using the documented six-location order (see `skills/document-review/SKILL.md:39-46`); the agent should pick whichever of the following paths exists first:
    - `~/.codex/hotl/scripts/document-lint.sh`
    - `~/.codex/plugins/hotl-source/scripts/document-lint.sh`
    - `~/.codex/plugins/cache/codex-plugins/hotl/*/scripts/document-lint.sh`
    - `~/.cline/hotl/scripts/document-lint.sh`
    - `~/.claude/plugins/hotl/scripts/document-lint.sh`

    Call the resolved path as `bash <resolved-document-lint.sh> <file>`. Trial steps:
    - Run `/hotl:brainstorm` on a trivial feature. Confirm the produced design doc lands at `docs/plans/YYYY-MM-DD-<topic>-plan.md` (new suffix) and passes the resolved lint with exit 0.
    - Run `/hotl:write-plan` from that file. Confirm the produced workflow lands at project root as `hotl-workflow-<slug>.md` (unchanged default).
    - Add `workflows_dir: docs/workflows` to `.hotl/config.yml`, repeat `/hotl:write-plan` on a second scratch feature, confirm the workflow file lands in `docs/workflows/` instead of root.
    - Confirm no new forbidden initiative-support directories (`docs/designs/`, `docs/decisions/`, etc.) are created.

### Regression surface

- `scripts/document-lint.sh` — extension, not replacement. Existing `-design.md` classification path stays.
- Every SKILL.md and cline rule touched — documentation-only edits for the suffix acceptance (plus one producer line in `brainstorming`).
- `skills/writing-plans/SKILL.md` — adds config-resolver instruction. Default behavior unchanged when no config.
- `test/smoke.bats` — contains existing tests for document-lint behavior (e.g., line 152 `document-lint accepts demo simulation workflow fixture`). All must stay green.

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo). Review process mirrors Slice 1 — review this plan, then review the implementation PR.

**Review gates.**

1. Plan review (this doc) — approved when the smoke-test spec in §2.1 is deemed both sufficient and runnable.
2. Code review on the implementation PR — reviewer runs `bats test/slice-2-smoke.bats` and full suite locally.
3. Pre-merge: full `bats test/` green (§2 verification step 8) + manual trial on a scratch repo (§2 verification step 10).

**Exit criteria.**

- `test/slice-2-smoke.bats` green (all four groups).
- Full `bats test/` green — 180+ tests, zero regressions.
- Pre-slice-2 fixtures captured before any code change and checked in.
- `-design.md` files continue to be accepted by every updated consumer.
- `CHANGELOG.md` entry added under `Unreleased`.

**Rollback plan.** Slice 2 is a bundle of coordinated documentation edits and one small `document-lint.sh` extension. Revert the implementation commit — existing `-design.md` files are untouched (they were never in the rename path) and no new files were required. Users who had already started generating `-plan.md` files retain them as working plan docs; the pre-rollback consumers will fall back to treating them as generic markdown until re-ship. This is the only scenario where a rollback has a visible side-effect, and it is bounded and recoverable (rename the file, or re-ship the slice).

---

## 4. Scope

### In scope (ships in this slice)

1. `scripts/document-lint.sh` — classification branch accepts `*-plan.md` in addition to `*-design.md`. Usage text updated to mention both suffixes.
2. `skills/brainstorming/SKILL.md` — line 59 output path changes from `-design.md` to `-plan.md`. Line 22 discovery check ("check for `docs/plans/*.md`") unchanged — it already accepts both.
3. `skills/writing-plans/SKILL.md` — document the `workflows_dir` resolution:
   1. Resolve the install path of `hotl-config-resolve.sh` using the same six-location rule already documented for `document-lint.sh` and `hotl-config.sh` in `skills/document-review/SKILL.md:39`.
   2. Invoke `bash <resolved-hotl-config-resolve.sh> get workflows_dir --default=.` — the resolver is a command proxy (per Slice 1's accepted contract) that locates `hotl-config.sh` and forwards argv; no intermediate "path locator" step.
   3. Use the returned directory as the target for `hotl-workflow-<slug>.md`. Default behavior (project root) unchanged when config is absent — the `--default=.` fallback handles the no-config case.
4. `skills/loop-execution/SKILL.md` — line 44 exclusion glob extended to cover both `*-design.md` and `*-plan.md`.
5. `skills/executing-plans/SKILL.md` — line 32 exclusion glob extended similarly.
6. `skills/document-review/SKILL.md` — lines 22 and 69 classification text mentions both suffixes.
7. `cline/rules/hotl-brainstorming.md` — mirror the producer change in `brainstorming` (line 74).
8. `cline/rules/hotl-execution.md` — mirror the exclusion-glob extension (line 24).
9. `cline/rules/hotl-document-review.md` — mirror the classification-text change (line 23).
10. `test/slice-2-smoke.bats` — Groups E/F/G/H runnable spec.
11. `test/fixtures/pre-slice-2-command-count.txt` — pre-Slice-2 snapshot.
12. `test/fixtures/pre-slice-2-skill-count.txt` — pre-Slice-2 snapshot.
13. `test/fixtures/sample-design.md` — minimal HOTL-contract design doc fixture for lint round-trips.
14. `CHANGELOG.md` — `Unreleased` entry.

### Out of scope (deferred to later slices)

- Any new skill or command (Slices 3–6).
- Templates in `adapters/` (Slice 3).
- Scope question in `brainstorming` (Slice 4).
- Scaffolder in `setup-project` (Slice 5).
- `phase-kickoff` workflow (Slice 6).
- Rename or migration of existing `-design.md` files — they are untouched forever and remain valid.
- Introduction of any new `.hotl/config.yml` field beyond `workflows_dir` (already in the Slice 1 schema). No schema change.

---

## 5. Module-level changes

| File | Change |
|---|---|
| `scripts/document-lint.sh` | Line 10 usage text + line 25 classification branch accept `*-plan.md` alongside `*-design.md` |
| `skills/brainstorming/SKILL.md` | Line 59 default output path: `-design.md` → `-plan.md` |
| `skills/writing-plans/SKILL.md` | Add paragraph documenting `workflows_dir` resolution via `hotl-config-resolve.sh get workflows_dir --default=.`; default behavior (project root) preserved when config absent |
| `skills/loop-execution/SKILL.md` | Line 44 exclusion glob accepts both suffixes |
| `skills/executing-plans/SKILL.md` | Line 32 exclusion glob accepts both suffixes |
| `skills/document-review/SKILL.md` | Lines 22 and 69 classification text mentions both suffixes |
| `cline/rules/hotl-brainstorming.md` | Mirror brainstorming line 74 producer change |
| `cline/rules/hotl-execution.md` | Mirror executor exclusion-glob extension |
| `cline/rules/hotl-document-review.md` | Mirror document-review classification text |
| `test/slice-2-smoke.bats` (NEW) | Runnable smoke-test spec from §2.1 |
| `test/fixtures/pre-slice-2-command-count.txt` (NEW) | Baseline |
| `test/fixtures/pre-slice-2-skill-count.txt` (NEW) | Baseline |
| `test/fixtures/sample-design.md` (NEW) | Minimal HOTL-contract design doc (used by E1, E2, H1) |
| `CHANGELOG.md` | `Unreleased` entry |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. Capture baselines: write `test/fixtures/pre-slice-2-command-count.txt` and `pre-slice-2-skill-count.txt` from current `main`. **Must be the first commit.**
2. Create `test/fixtures/sample-design.md` — a minimal HOTL-contract design doc that passes current `document-lint.sh`. Will be reused by Groups E and H1.
3. Extend `scripts/document-lint.sh` (usage text + classification branch) to accept `*-plan.md`.
4. Update `skills/brainstorming/SKILL.md` line 59 default output path to `-plan.md`.
5. Update `skills/writing-plans/SKILL.md` to document the `workflows_dir` resolver invocation.
6. Update `skills/loop-execution/SKILL.md`, `executing-plans/SKILL.md`, `document-review/SKILL.md` consumer lines to mention both suffixes.
7. Update the three cline mirror files.
8. Author `test/slice-2-smoke.bats` with Groups E/F/G/H. Verify all pass.
9. Run `bats test/` — must be green, all 180+ tests.
10. Update `CHANGELOG.md`.

---

## 7. Open questions

1. `skills/writing-plans/SKILL.md` currently instructs the agent to save to project root with a very specific rationale (agent-concurrency). When documenting `workflows_dir`, should we keep the default rationale and just add an opt-in override, or re-explain the whole thing? Leaning: minimal append — the agent-concurrency rationale stays; opt-in override added as a short paragraph.
2. Should `test/fixtures/sample-design.md` be a new fixture or should we reuse one of the existing `hotl-workflow-*-sample.md` files? Leaning: new fixture, because the existing samples are workflow files, not design docs, and we need a real design-doc HOTL structure for `document-lint.sh` to exercise.
3. No other open questions. If any arise during implementation, record them here and re-review before proceeding.
