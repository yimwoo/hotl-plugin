# Slice 6 — Phase-Kickoff Workflow

**Status:** Proposed — for review
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted), Slices 1–5 (shipped)
**Strategy reference:** `docs/designs/initiative-support.md` §11 workflows row, §12 Slice 6

---

## 1. Intent contract

**What this slice is for.** Ship `workflows/phase-kickoff.md` — a reusable HOTL workflow template that automates the three-step kickoff each new phase of a multi-phase initiative goes through: **review → triage → requirements**. A user starting phase N of an initiative copies this template to `hotl-workflow-<slug>-phase-kickoff.md`, edits the frontmatter placeholders, and runs it via `/hotl:loop` or `/hotl:execute-plan`. The workflow produces three artifacts in the initiative's `docs/` taxonomy:

1. **Kickoff review memo** at `docs/reviews/<slug>-phase-N-kickoff-review.md` — summary of the design doc + prior phases + risks and open questions
2. **Triage memo** at `docs/reviews/<slug>-phase-N-triage.md` — accept / defer / reject decisions for each review finding, plus any new ADR needs
3. **Requirements doc** at `docs/requirements/<slug>-phase-N.md` — user stories, acceptance criteria, non-goals, exit gate

After the three artifacts exist and are human-approved, the phase enters the normal `brainstorming` (scope: phase) → `writing-plans` → execution flow.

This is the **final slice** of the initiative-support rollout. After Slice 6 ships, every Slice 3 template has a consumer, every opt-in path works end-to-end, and the workflow gap between "initiative design exists" and "first phase plan is written" is filled.

**What this slice is NOT for.**

- No change to `brainstorming`, `writing-plans`, `setup-project`, or the runtime.
- No change to the existing workflow templates (`feature.md`, `bugfix.md`, `refactor.md`) — those ship unchanged with their existing behavior.
- No new skill, no new command.
- No change to `hotl-init-initiative.sh` — phase-kickoff is not rendered into user repos by the Slice 5 scaffolder; it lives in the plugin install and is referenced via the six-location rule when a user needs it.
- No linter extension — `phase-kickoff.md` is a workflow template, not a live workflow file, so `document-lint.sh` SKIPs it today (same as `feature.md`/`bugfix.md`/`refactor.md`). When copied and renamed to `hotl-workflow-*.md` the lint applies normally.
- No automation of the human-review steps. The workflow guides the agent through three structured steps, but each produces an artifact that requires human approval before the next step runs. The three `gate: human` checkpoints are load-bearing — they are the whole point of "phase kickoff."

**Primary audience / user story.** A user who has run `hotl-init-initiative.sh --name ai-assurance` (Slice 5) and written their strategic design at `docs/designs/ai-assurance.md` now wants to kick off phase 1. They open the `initiative-playbook.template.md` rendered by Slice 5, find the pointer to `workflows/phase-kickoff.md`, copy it into their repo as `hotl-workflow-ai-assurance-phase-1-kickoff.md`, fill in the frontmatter placeholders, and run `/hotl:loop`. After the three gates, they have a kickoff-review memo, a triage memo, and a requirements doc — ready inputs for the normal per-phase brainstorming flow.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-6-smoke.bats`. Full `bats test/` remains green (236 prior + new Slice 6 tests).

### 2.1 Smoke test spec (runnable)

Group letters continue from prior slices (A–S used). Slice 6 uses T, U, V.

#### Group T — `workflows/phase-kickoff.md` structural contract

**T1. `workflows/phase-kickoff.md` exists and is non-trivial.**

```bash
[ -f "$REPO_ROOT/workflows/phase-kickoff.md" ]
# > 400 bytes — a three-step workflow with human gates cannot be shorter.
SIZE=$(wc -c < "$REPO_ROOT/workflows/phase-kickoff.md" | tr -d ' ')
[ "$SIZE" -gt 400 ]
```

**T2. Valid HOTL workflow frontmatter — passes `document-lint.sh` when copied to a `hotl-workflow-*.md` filename.**

```bash
# Copy the template to a hotl-workflow-* filename so document-lint classifies
# it as a workflow file (today lint SKIPs on the bare phase-kickoff.md name).
cp "$REPO_ROOT/workflows/phase-kickoff.md" "$TMP/hotl-workflow-demo-phase-1-kickoff.md"
run bash "$DOCUMENT_LINT" "$TMP/hotl-workflow-demo-phase-1-kickoff.md"
[ "$status" -eq 0 ]
echo "$output" | grep -qi 'lint passed'
```

**T3. The three expected steps are present, in order — review → triage → requirements.**

```bash
file="$REPO_ROOT/workflows/phase-kickoff.md"

# Step headers must appear in the correct order. Use grep with -n to extract
# line numbers and confirm strict ordering.
REVIEW_LINE=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Rr]eview' "$file" | head -1 | cut -d: -f1)
TRIAGE_LINE=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Tt]riage' "$file" | head -1 | cut -d: -f1)
REQS_LINE=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Rr]equirement' "$file" | head -1 | cut -d: -f1)

[ -n "$REVIEW_LINE" ] || { echo "FAIL: no review step found"; return 1; }
[ -n "$TRIAGE_LINE" ] || { echo "FAIL: no triage step found"; return 1; }
[ -n "$REQS_LINE" ]   || { echo "FAIL: no requirements step found"; return 1; }

[ "$REVIEW_LINE" -lt "$TRIAGE_LINE" ] \
    || { echo "FAIL: review step is not before triage step"; return 1; }
[ "$TRIAGE_LINE" -lt "$REQS_LINE" ] \
    || { echo "FAIL: triage step is not before requirements step"; return 1; }
```

**T4. Each step has a `gate: human` line — human approval between steps is load-bearing.**

```bash
file="$REPO_ROOT/workflows/phase-kickoff.md"
# At least three `gate: human` lines (one per step). Kickoff is human-gated
# end-to-end; auto-approving any step would defeat the point.
GATES=$(grep -c '^gate:[[:space:]]*human' "$file")
[ "$GATES" -ge 3 ] || { echo "FAIL: expected >= 3 gate: human lines, got $GATES"; return 1; }
```

**T5. Output paths reference the initiative-support taxonomy.**

```bash
file="$REPO_ROOT/workflows/phase-kickoff.md"
# The template must produce artifacts in docs/reviews/ and docs/requirements/
# — the initiative-support tiers set up by Slice 5's scaffolder.
grep -q 'docs/reviews/' "$file" \
    || { echo "FAIL: template must reference docs/reviews/"; return 1; }
grep -q 'docs/requirements/' "$file" \
    || { echo "FAIL: template must reference docs/requirements/"; return 1; }
```

**T6. Placeholders follow the `{{…}}` convention; braces balance.**

```bash
file="$REPO_ROOT/workflows/phase-kickoff.md"
OPEN=$(grep -o '{{' "$file" | wc -l | tr -d ' ')
CLOSE=$(grep -o '}}' "$file" | wc -l | tr -d ' ')
[ "$OPEN" -eq "$CLOSE" ] \
    || { echo "FAIL: unbalanced {{ ($OPEN) vs }} ($CLOSE)"; return 1; }
# At least {{SLUG}} and {{PHASE_ID}} are present — the two per-invocation
# placeholders.
grep -q '{{SLUG}}' "$file"
grep -q '{{PHASE_ID}}' "$file"
```

**T7. No ODAP-specific prose.**

```bash
file="$REPO_ROOT/workflows/phase-kickoff.md"
for term in 'ODAP' 'AI Assurance' 'Oracle DB' 'vdb-e2e' 'ai-assurance-playbook'; do
    if grep -qi "$term" "$file"; then
        echo "FAIL: phase-kickoff template contains ODAP-specific term '$term'"
        return 1
    fi
done
```

#### Group U — playbook template references the phase-kickoff workflow

**U1. `adapters/initiative-playbook.template.md` points users to `workflows/phase-kickoff.md`.**

```bash
tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
grep -qE 'workflows/phase-kickoff\.md|phase-kickoff workflow|phase-kickoff template' "$tmpl"
```

**U2. The pointer names the install-path resolution rule — reader knows to resolve the workflow via the six-location order like any other shared asset.**

```bash
tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
# The playbook must tell the user how to locate the workflow across installs —
# either by naming the resolution rule explicitly or referencing skills/document-review/SKILL.md.
grep -qE 'six-location|install-path|document-review/SKILL\.md|HOTL install' "$tmpl"
```

#### Group V — small-user safety regression

**V1. Command and skill counts unchanged from pre-Slice-6 baseline.**

```bash
EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-6-command-count.txt")
ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
[ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-6-skill-count.txt")
ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
[ "$ACTUAL_SKILLS" -eq "$EXPECTED_SKILLS" ]
```

**V2. Slice 6 surface in a clean repo creates no forbidden initiative-support artifacts.**

The workflow template is an inert file in the plugin install — it does not run by itself. Any artifacts appear only when a user copies it into `hotl-workflow-*.md` and runs it via `/hotl:loop`, which is out of scope for an automated smoke test.

```bash
git init -q
# Exercise the prior-slice shell surface — none of this should touch
# initiative-support paths.
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

**V3. Existing `workflows/*.md` templates unchanged.**

```bash
for tmpl in \
    workflows/feature.md \
    workflows/bugfix.md \
    workflows/refactor.md; do
    [ -f "$REPO_ROOT/$tmpl" ] \
        || { echo "FAIL: $tmpl missing"; return 1; }
done

# The phase-kickoff template does not collide with the existing naming —
# each existing template's filename must still appear in workflows/.
ls "$REPO_ROOT/workflows/" | grep -qx 'feature.md'
ls "$REPO_ROOT/workflows/" | grep -qx 'bugfix.md'
ls "$REPO_ROOT/workflows/" | grep -qx 'refactor.md'
ls "$REPO_ROOT/workflows/" | grep -qx 'phase-kickoff.md'
```

**V4. Prior slice smoke suites remain green.**

```bash
for suite in \
    test/slice-1-smoke.bats \
    test/slice-2-smoke.bats \
    test/slice-3-smoke.bats \
    test/slice-4-smoke.bats \
    test/slice-5-smoke.bats; do
    run bats "$REPO_ROOT/$suite"
    [ "$status" -eq 0 ]
done
```

### Verification plan

1. Capture `test/fixtures/pre-slice-6-command-count.txt` and `pre-slice-6-skill-count.txt`. **First commit.**
2. Draft `workflows/phase-kickoff.md` — three-step workflow (review → triage → requirements), each with `gate: human`, frontmatter with `{{SLUG}}` and `{{PHASE_ID}}` placeholders, output paths under `docs/reviews/` and `docs/requirements/`.
3. Update `adapters/initiative-playbook.template.md` with a pointer to `workflows/phase-kickoff.md` and the six-location resolution rule (or a reference to the canonical resolution-rule doc).
4. Author `test/slice-6-smoke.bats` with Groups T/U/V. Make all tests green.
5. Run full `bats test/` — must be green (236 prior plus Slice 6 additions).
6. Update `CHANGELOG.md` with Unreleased entry.
7. **Manual verification** on a personal scratch repo:
   - Run `hotl-init-initiative.sh --name demo` (Slice 5). Confirm `docs/prompts/demo-playbook.md` exists and references `workflows/phase-kickoff.md`.
   - Copy the phase-kickoff template to `hotl-workflow-demo-phase-1-kickoff.md`, substitute `{{SLUG}}` → `demo` and `{{PHASE_ID}}` → `1` by hand.
   - Run `bash scripts/document-lint.sh hotl-workflow-demo-phase-1-kickoff.md`. Confirm exit 0.
   - (Optional) Run `/hotl:loop hotl-workflow-demo-phase-1-kickoff.md` and walk through the three human gates. Confirm the three artifacts land in `docs/reviews/demo-phase-1-kickoff-review.md`, `docs/reviews/demo-phase-1-triage.md`, `docs/requirements/demo-phase-1.md`.

### Regression surface

- `workflows/feature.md`, `workflows/bugfix.md`, `workflows/refactor.md` — unchanged.
- `scripts/document-lint.sh` — unchanged. Classification for workflow files (`hotl-workflow-*.md`) already handles the copied-and-renamed case.
- `adapters/initiative-playbook.template.md` — small addition (the workflow pointer). No substitution semantics change.
- No runtime, skill, or command changes.
- Prior slice smoke suites (V4 enforces green).

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo).

**Review gates.**

1. Plan review (this doc) — approved when §2.1 is sufficient and runnable and the three-step (review → triage → requirements) structure is deemed correct.
2. Code review on the implementation PR — reviewer runs `bats test/slice-6-smoke.bats` and full suite locally.
3. Pre-merge: full `bats test/` green (§2 step 5) + manual scratch-repo trial (§2 step 7).

**Exit criteria.**

- `test/slice-6-smoke.bats` green (Groups T, U, V).
- Full `bats test/` green — 236+ prior tests plus Slice 6.
- Pre-slice-6 fixtures captured before any code change and checked in.
- Phase-kickoff template, when copied to `hotl-workflow-*.md`, passes `document-lint.sh`.
- Playbook template references the workflow and names the resolution rule.
- `CHANGELOG.md` entry added under `Unreleased`.

**Rollback plan.** Slice 6 is pure-additive — one new workflow template, one small addition to an existing template, tests, fixtures, CHANGELOG. Revert the implementation commit — nothing else depends on `workflows/phase-kickoff.md`. Users who copied it into `hotl-workflow-*.md` before the rollback keep their copy (valid Markdown; `document-lint.sh` still passes it).

---

## 4. Scope

### In scope (ships in this slice)

1. `workflows/phase-kickoff.md` — new workflow template. Three steps (review → triage → requirements), each `gate: human`. Frontmatter with `{{SLUG}}` and `{{PHASE_ID}}` placeholders. Output paths under `docs/reviews/` and `docs/requirements/`. Passes `document-lint.sh` when copied to `hotl-workflow-*.md`.
2. `adapters/initiative-playbook.template.md` — add a pointer to `workflows/phase-kickoff.md` with the six-location resolution rule (or a cross-reference).
3. `test/slice-6-smoke.bats` — Groups T/U/V runnable spec.
4. `test/fixtures/pre-slice-6-command-count.txt` — baseline snapshot.
5. `test/fixtures/pre-slice-6-skill-count.txt` — baseline snapshot.
6. `CHANGELOG.md` — Unreleased entry.

### Out of scope (deferred or not planned)

- Any change to `brainstorming`, `writing-plans`, `setup-project`, or the runtime.
- Any change to the existing workflow templates (`feature.md`, `bugfix.md`, `refactor.md`).
- Automation of the human gates — each step MUST require explicit approval.
- A cline mirror for the phase-kickoff template — workflow templates are language-neutral Markdown with YAML frontmatter; no mirror needed.
- Linter extension for `workflows/*.md` filenames that are not `hotl-workflow-*.md` — templates rely on the existing skip-and-apply-on-copy pattern.
- Any new Slice 5 scaffolder behavior (the scaffolder does not render `phase-kickoff.md` into user repos; it lives in the plugin install and is accessed via the six-location rule).

---

## 5. Module-level changes

| File | Change |
|---|---|
| `workflows/phase-kickoff.md` (NEW) | Three-step human-gated workflow (review → triage → requirements). `{{SLUG}}` and `{{PHASE_ID}}` placeholders. Output paths in `docs/reviews/` and `docs/requirements/`. `risk_level: medium` (kickoff touches planning docs but no code). `auto_approve: false` because every step is human-gated. |
| `adapters/initiative-playbook.template.md` | Add a pointer section naming `workflows/phase-kickoff.md` and the six-location resolution rule. Small addition — most of the template stays the same. |
| `test/slice-6-smoke.bats` (NEW) | Groups T/U/V runnable spec. |
| `test/fixtures/pre-slice-6-command-count.txt` (NEW) | Baseline. |
| `test/fixtures/pre-slice-6-skill-count.txt` (NEW) | Baseline. |
| `CHANGELOG.md` | Unreleased entry. |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. Capture baselines: write `test/fixtures/pre-slice-6-command-count.txt` and `pre-slice-6-skill-count.txt` from current `main`. **First commit.**
2. Draft `workflows/phase-kickoff.md`:
   - Frontmatter: `intent`, `success_criteria`, `risk_level: medium`, `auto_approve: false`, with `{{SLUG}}` and `{{PHASE_ID}}` placeholders.
   - Step 1 (Review): action reads `docs/designs/{{SLUG}}.md`, prior phase plans, relevant ADRs; produces `docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-kickoff-review.md`. `gate: human`.
   - Step 2 (Triage): action reads the review memo; produces `docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-triage.md` with accept/defer/reject verdicts. `gate: human`.
   - Step 3 (Requirements): action reads design + accepted triage items; produces `docs/requirements/{{SLUG}}-phase-{{PHASE_ID}}.md`. `gate: human`.
3. Update `adapters/initiative-playbook.template.md` with a short section pointing to `workflows/phase-kickoff.md`. Cross-reference the six-location install-path rule documented elsewhere.
4. Author `test/slice-6-smoke.bats` with Groups T/U/V. Verify all pass.
5. Run full `bats test/` — must be green.
6. Update `CHANGELOG.md`.

---

## 7. Open questions

1. **Placement of the phase-kickoff pointer in the playbook template.** Options:
   - **(a)** Add as a new section near `§2. Global Session 0 — kickoff and alignment` — grouping all kickoff machinery.
   - **(b)** Add under `§3. Phase 1 — {{PHASE_1_NAME}}` as a preparatory step before the requirements session.
   
   Leaning (a). The phase-kickoff workflow runs once per phase (not just phase 1), so it's more naturally grouped with the cross-cutting kickoff material than nested under a specific phase. Confirm before implementation.

2. **`risk_level` default for the workflow template.** Leaning `medium`. Rationale: kickoff touches planning docs that downstream phases depend on; mislabeling a scope or missing a risk in the kickoff review has cascading impact. `low` would be too permissive; `high` would force additional explicit human approvals beyond the three `gate: human` steps already present. Confirm.

3. **`auto_approve: false` — is that right?** Leaning yes. Every step is human-gated; `auto_approve: true` would be meaningless (no auto-approvable gates) and could confuse users who copy the template and change `risk_level`. Explicit `false` makes the intent unmistakable.
