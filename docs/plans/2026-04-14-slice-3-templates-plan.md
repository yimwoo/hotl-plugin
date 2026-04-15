# Slice 3 — Initiative-Tier Templates

**Status:** Proposed — for review
**Date:** 2026-04-14
**Depends on:** `docs/designs/initiative-support.md` (accepted), `docs/plans/2026-04-14-slice-1-config-reader-plan.md` (shipped), `docs/plans/2026-04-14-slice-2-plan-rename-plan.md` (shipped)
**Strategy reference:** `docs/designs/initiative-support.md` §7 two templates, §11 adapters row, §12 Slice 3

---

## 1. Intent contract

**What this slice is for.** Ship four template files under `adapters/` so that Slice 4 (`brainstorming` scope question) and Slice 5 (`setup-project` scaffolder) have concrete artifacts to read and render. No skill, command, runtime, or scaffolder consumes these yet — the files are intentionally inert after this slice lands.

The four templates are:

1. **`adapters/strategic-design.template.md`** — parent doc for a multi-phase initiative. Lives in `docs/designs/` when rendered. Borrows structure from ODAP's `design-doc-template.md`, generalized.
2. **`adapters/tactical-plan.template.md`** — child execution-prep doc for one phase or one feature. Lives in `docs/plans/` when rendered. Borrows from ODAP's `plan-template.md`, generalized, and **must satisfy `document-lint.sh` design-doc rules when placeholders are filled with real values**.
3. **`adapters/initiative-playbook.template.md`** — per-initiative prompt library, one prompt per phase × role. Borrows structure from ODAP's `ai-assurance-playbook.md`, generalized.
4. **`adapters/initiative-operating-model.template.md`** — roles + decision-rights matrix + escalation tripwires for one initiative. Borrows from ODAP's `hotl-operating-model.md`, generalized.

**What this slice is NOT for.**

- **No consumers wired.** `brainstorming`, `setup-project`, `writing-plans`, and the runtime are unchanged. The templates are inert.
- **No changes to the linter.** `document-lint.sh` retains its current classification rules; three of the four templates (`strategic-design`, `initiative-playbook`, `initiative-operating-model`) are outside its coverage and are verified via a generic render check, not by `document-lint.sh`.
- **No schema changes** to `.hotl/config.yml`.
- **No ODAP-specific prose** in any template. All four must read as generic HOTL artifacts — no references to Oracle DB, ODAP, AI Assurance, or any one project.
- **No rendering logic.** Slice 5 adds the setup-project question + render step; this slice ships only the source templates.

**Primary audience.** Plugin maintainers preparing Slice 4 (`brainstorming` will read `strategic-design.template.md`) and Slice 5 (`setup-project` will render all four into a user's repo on opt-in). End users see nothing from Slice 3 alone.

---

## 2. Verification contract

### Definition of done

All tests in §2.1 pass when run via `bats test/slice-3-smoke.bats`. Full `bats test/` remains green (194 prior + new Slice 3 tests).

### 2.1 Smoke test spec (runnable)

Group letters continue from Slices 1 (A–D) and 2 (E–H). Slice 3 uses I/J/K/L.

#### Group I — Template presence and required sections

**I1. All four templates exist under `adapters/`.**

```bash
for tmpl in \
    adapters/strategic-design.template.md \
    adapters/tactical-plan.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    [ -f "$REPO_ROOT/$tmpl" ] || { echo "FAIL: missing $tmpl"; return 1; }
    # Non-empty (> 200 bytes) — a placeholder-only file would not be useful.
    SIZE=$(wc -c < "$REPO_ROOT/$tmpl" | tr -d ' ')
    [ "$SIZE" -gt 200 ] || { echo "FAIL: $tmpl is too small ($SIZE bytes)"; return 1; }
done
```

**I2. `strategic-design.template.md` carries the required sections.**

```bash
tmpl="$REPO_ROOT/adapters/strategic-design.template.md"
for section in \
    'Problem statement' \
    'Vision' \
    'Non-goals' \
    'Stakeholders' \
    'Phase breakdown' \
    'Risks'; do
    grep -qi "$section" "$tmpl" \
        || { echo "FAIL: strategic-design template missing '$section'"; return 1; }
done
```

**I3. `tactical-plan.template.md` carries the three HOTL contracts plus scope and task breakdown.**

```bash
tmpl="$REPO_ROOT/adapters/tactical-plan.template.md"
for section in \
    'Intent contract' \
    'Verification contract' \
    'Governance contract' \
    'Scope' \
    'Task breakdown'; do
    grep -qi "$section" "$tmpl" \
        || { echo "FAIL: tactical-plan template missing '$section'"; return 1; }
done
```

**I4. `initiative-playbook.template.md` has the per-phase / per-role prompt structure.**

```bash
tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
# Must document: session discipline, the repeating per-phase pattern, and
# provide at least one example prompt block (fenced code).
grep -qi 'session discipline\|one session' "$tmpl"
grep -qi 'repeating pattern\|per phase\|per-phase' "$tmpl"
# At least one fenced prompt example.
grep -q '^```' "$tmpl"
```

**I5. `initiative-operating-model.template.md` carries roles, decision rights, and tripwires.**

```bash
tmpl="$REPO_ROOT/adapters/initiative-operating-model.template.md"
for section in \
    'Roles' \
    'Decision rights' \
    'Tripwire\|Escalation'; do
    grep -qiE "$section" "$tmpl" \
        || { echo "FAIL: operating-model template missing '$section'"; return 1; }
done
```

**I6. No ODAP-specific prose in any template.**

```bash
for tmpl in \
    adapters/strategic-design.template.md \
    adapters/tactical-plan.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    # Case-insensitive grep for ODAP-specific terms. All must NOT match.
    for term in 'ODAP' 'AI Assurance' 'Oracle DB' 'vdb-e2e' 'ai-assurance-playbook'; do
        if grep -qi "$term" "$REPO_ROOT/$tmpl"; then
            echo "FAIL: $tmpl contains ODAP-specific term '$term'"
            return 1
        fi
    done
done
```

#### Group J — `tactical-plan.template.md` produces a lint-passing plan doc

**J1. Template instantiation round-trip: substitute placeholders with example values and lint the result.**

```bash
# Copy the template to a dated *-plan.md filename so document-lint.sh
# classifies it as a HOTL plan doc (vs. skipping as unrecognized).
cp "$REPO_ROOT/adapters/tactical-plan.template.md" \
   "$TMP/2026-04-14-demo-plan.md"

# Fill {{PLACEHOLDER}} tokens with safe example values — enough to produce
# a doc that passes lint's structural checks. Placeholders that need real
# content: {{INITIATIVE_NAME}}, {{PHASE_ID}}, {{DATE}}.
sed -i.bak \
    -e 's/{{INITIATIVE_NAME}}/demo-initiative/g' \
    -e 's/{{PHASE_ID}}/phase-1/g' \
    -e 's/{{DATE}}/2026-04-14/g' \
    "$TMP/2026-04-14-demo-plan.md"

# Document-lint must classify this as a design doc (suffix -plan.md) and
# pass all structural checks with exit 0.
run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-plan.md"
[ "$status" -eq 0 ]
echo "$output" | grep -qi 'lint passed'
```

**J2. Template carries all required HOTL-contract fields (pre-check independent of lint).**

```bash
# The fields lint requires for a design-doc classification.
tmpl="$REPO_ROOT/adapters/tactical-plan.template.md"
grep -qi 'intent:' "$tmpl"
grep -qi 'constraints:' "$tmpl"
grep -qi 'success_criteria:' "$tmpl"
grep -qi 'risk_level:' "$tmpl"
# risk_level value must already be one of low|medium|high (a placeholder
# like <low|medium|high> would fail lint's case statement).
grep -qiE 'risk_level:[[:space:]]*(low|medium|high)\b' "$tmpl"
grep -qi 'approval_gates\|approval gates' "$tmpl"
grep -qi 'rollback:' "$tmpl"
# Verification contract has at least one verify/check/confirm keyword.
grep -qi 'verify\|check\|confirm\|run test' "$tmpl"
```

#### Group K — Generic render check for the other three templates

`document-lint.sh` does not cover `strategic-design.template.md`, `initiative-playbook.template.md`, `initiative-operating-model.template.md`. Verification honors the design §12 promise of "renders without error, all internal anchor links resolve" by combining:

- **K1** — anchor-link resolution (bash only)
- **K2** — balanced placeholder and code-fence structural check (bash only)
- **K3** — H1 present (bash only)
- **K4** — real Markdown parse via `pandoc` when available; `bats skip` when not

**K1. Internal anchor links resolve.**

```bash
# For each of the three templates, extract every markdown anchor link of the
# form [text](#anchor-id) and confirm a matching heading exists.
for tmpl in \
    adapters/strategic-design.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    file="$REPO_ROOT/$tmpl"
    # Extract all referenced anchors.
    ANCHORS=$(grep -oE '\]\(#[a-zA-Z0-9_-]+\)' "$file" | sed -E 's/.*\(#([a-zA-Z0-9_-]+)\).*/\1/' | sort -u)
    for anchor in $ANCHORS; do
        # Generate the expected anchor from each heading: lowercase, spaces
        # to dashes, strip most punctuation. This mirrors GitHub's default.
        grep -qE "^#+[[:space:]]+.*" "$file" \
            || { echo "FAIL: $tmpl has anchor ref '#$anchor' but no headings"; return 1; }
        # A looser check: the anchor string must appear somewhere in a
        # heading (case-insensitive, dash-tolerant).
        HEADING_PATTERN=$(echo "$anchor" | tr '-' ' ')
        grep -qiE "^#+[[:space:]]+.*${HEADING_PATTERN}" "$file" \
            || { echo "FAIL: $tmpl anchor '#$anchor' has no matching heading"; return 1; }
    done
done
```

**K2. Structural balance — placeholders and code fences.**

```bash
# Templates use {{PLACEHOLDER_NAME}} — the opening and closing braces must
# always balance. A stray {{ or }} signals a typo.
# Code fences (```) must balance — an odd count breaks rendering.
for tmpl in \
    adapters/strategic-design.template.md \
    adapters/tactical-plan.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    file="$REPO_ROOT/$tmpl"
    OPEN=$(grep -o '{{' "$file" | wc -l | tr -d ' ')
    CLOSE=$(grep -o '}}' "$file" | wc -l | tr -d ' ')
    [ "$OPEN" -eq "$CLOSE" ] \
        || { echo "FAIL: $tmpl has unbalanced {{ ($OPEN) vs }} ($CLOSE)"; return 1; }

    FENCES=$(grep -c '^```' "$file")
    [ $((FENCES % 2)) -eq 0 ] \
        || { echo "FAIL: $tmpl has odd number of code fences ($FENCES)"; return 1; }
done
```

**K3. Each template has at least one H1.**

```bash
for tmpl in \
    adapters/strategic-design.template.md \
    adapters/tactical-plan.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    file="$REPO_ROOT/$tmpl"
    # At least one top-level H1 — a convention that keeps rendered docs clean.
    H1_COUNT=$(grep -c '^# ' "$file")
    [ "$H1_COUNT" -ge 1 ] || { echo "FAIL: $tmpl missing H1"; return 1; }
done
```

**K4. Templates parse cleanly via a real Markdown renderer (pandoc).**

This is the "renders without error" check that the design §12 promises. Run `pandoc -f markdown -t html` against each template and assert exit 0. `pandoc` is widely available via Homebrew / apt / Nix and is already used by many dev environments, but not guaranteed on every CI runner — the test gracefully skips when absent so we never silently downgrade from a real render check to a text grep.

```bash
if ! command -v pandoc >/dev/null 2>&1; then
    skip "pandoc not installed — skipping K4 (real Markdown render check)"
fi

for tmpl in \
    adapters/strategic-design.template.md \
    adapters/tactical-plan.template.md \
    adapters/initiative-playbook.template.md \
    adapters/initiative-operating-model.template.md; do
    file="$REPO_ROOT/$tmpl"
    # -t html so pandoc exercises its full markdown parser.
    # --fail-if-warnings surfaces structural issues pandoc would normally
    # emit as warnings (broken links, missing references, etc.).
    run pandoc --fail-if-warnings -f markdown -t html -o /dev/null "$file"
    [ "$status" -eq 0 ] || { echo "FAIL: $tmpl did not render cleanly via pandoc"; echo "$output"; return 1; }
done
```

Governance note: if K4 skips on a given run, reviewers must run K4 locally (with `pandoc` installed) before approving the Slice 3 PR. The manual verification step (§2 verification plan step 9) adds a reminder to run `pandoc` locally to avoid a silent-skip gap.

#### Group L — small-user safety regression

**L1. Templates are inert — no skill / command / runtime reads them yet.**

```bash
# If any production skill or runtime starts referencing these templates
# before Slice 4/5 ships, that's orphaned-producer territory. Assert the
# templates are mentioned ONLY in docs/ and test/ at this stage.
for tmpl_name in \
    strategic-design.template.md \
    tactical-plan.template.md \
    initiative-playbook.template.md \
    initiative-operating-model.template.md; do
    REFS=$(grep -rl "$tmpl_name" "$REPO_ROOT" 2>/dev/null \
        | grep -vE '^'"$REPO_ROOT"'/(docs/|test/|adapters/|\.git/|CHANGELOG\.md)')
    if [ -n "$REFS" ]; then
        echo "FAIL: $tmpl_name referenced by non-docs/non-test files:"
        echo "$REFS"
        return 1
    fi
done
```

**L2. Baseline command and skill counts unchanged from pre-Slice-3 snapshot.**

```bash
EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-3-command-count.txt")
ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
[ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-3-skill-count.txt")
ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
[ "$ACTUAL_SKILLS" -eq "$EXPECTED_SKILLS" ]
```

**L3. Slice 3 surface creates no forbidden initiative-support artifacts in a clean repo.**

```bash
git init -q

# Exercise any Slice 3 surface that could create files. No shell-executable
# Slice 3 artifacts exist — the templates are inert Markdown. But we still
# exercise every prior-slice surface to confirm the safety contract holds
# in an integrated state.
bash "$HOTL_RT" log-decision '{"event":"test"}'
bash "$HOTL_CONFIG_SH" get workflows_dir --default=. >/dev/null

for forbidden in \
    .hotl/config.yml \
    .hotl/decisions.log \
    docs/designs \
    docs/decisions \
    docs/requirements \
    docs/reviews \
    docs/prompts; do
    [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden created"; return 1; }
done
```

**L4. Prior slice smoke suites remain green.**

```bash
# Slice 1 and Slice 2 smoke tests must still pass unchanged.
run bats "$REPO_ROOT/test/slice-1-smoke.bats"
[ "$status" -eq 0 ]
run bats "$REPO_ROOT/test/slice-2-smoke.bats"
[ "$status" -eq 0 ]
```

### Verification plan

1. Capture `test/fixtures/pre-slice-3-command-count.txt` and `pre-slice-3-skill-count.txt` as the FIRST commit of this slice.
2. Draft `adapters/tactical-plan.template.md` with all three HOTL contracts, safe placeholder tokens (`{{INITIATIVE_NAME}}`, `{{PHASE_ID}}`, `{{DATE}}`), and `risk_level: medium  # REVIEW BEFORE APPROVAL: confirm low | medium | high based on scope` as the default (conservative default + must-edit marker per §7 Q2).
3. Draft `adapters/strategic-design.template.md` (problem / vision / non-goals / stakeholders / maturity / phase breakdown / risks), generalized from ODAP's `design-doc-template.md` with all ODAP-specific prose stripped.
4. Draft `adapters/initiative-playbook.template.md` (session discipline, repeating per-phase × per-role pattern, example prompt block), generalized from ODAP's `ai-assurance-playbook.md`.
5. Draft `adapters/initiative-operating-model.template.md` (roles, decision-rights matrix, escalation tripwires), generalized from ODAP's `hotl-operating-model.md`.
6. Author `test/slice-3-smoke.bats` with Groups I/J/K/L. Make all tests green.
7. Run full `bats test/` — must be green (194 prior + ~17 new).
8. Update `CHANGELOG.md`.
9. **Manual review** of each template: read each file end-to-end, confirm it reads as generic HOTL content (no ODAP-specific terms, no project-specific prose), confirm placeholder tokens are obvious, confirm section structure is the one documented above. If K4 was skipped during automated `bats` because `pandoc` was unavailable on the CI runner, the reviewer must install `pandoc` locally (`brew install pandoc` / `apt-get install pandoc`), re-run K4, and confirm exit 0 before approving. This closes the silent-skip gap for the render check.

### Regression surface

- `adapters/` — pure additions. Existing `AGENTS.md.template`, `copilot-instructions.template`, `cursor-rules.template` unchanged.
- No skill, runtime, or test suite consumes the new templates in this slice (L1 enforces).
- `scripts/document-lint.sh` — unchanged. Slice 2's extension still handles both suffixes; J1 exercises the `-plan.md` classification with a real template instance.

---

## 3. Governance contract

**Approvers.** Plugin owner (yimwoo). Review process mirrors Slices 1 and 2.

**Review gates.**

1. Plan review (this doc) — approved when §2.1 is deemed sufficient and runnable and the template sourcing approach (ODAP templates generalized) is acceptable.
2. Code review on the implementation PR — reviewer runs `bats test/slice-3-smoke.bats` and full suite locally. Plus an eyeball pass on each template for ODAP-specific prose.
3. Pre-merge: full `bats test/` green + manual template review (§2 verification step 9).

**Exit criteria.**

- `test/slice-3-smoke.bats` green (Groups I, J, K, L).
- Full `bats test/` green — 194+ prior tests plus all new Slice 3 tests.
- Pre-slice-3 fixtures captured before any template lands and checked in.
- All four templates free of ODAP-specific prose (I6 enforces automatically; manual review is the belt-and-suspenders check).
- `CHANGELOG.md` entry added under `Unreleased`.

**Rollback plan.** Slice 3 is pure-additive — four new files in `adapters/`, one new bats file, two fixtures, a CHANGELOG entry. Revert the implementation commit — nothing else depends on the templates yet (Slices 4 and 5 are downstream). No migrations, no renames, no schema changes.

---

## 4. Scope

### In scope (ships in this slice)

1. `adapters/strategic-design.template.md` — generic template for multi-phase initiative designs. Sections per I2.
2. `adapters/tactical-plan.template.md` — generic template for phase / feature plans. Sections per I3; fields per J2; lint-passing after placeholder substitution per J1.
3. `adapters/initiative-playbook.template.md` — generic per-initiative prompt library. Structure per I4.
4. `adapters/initiative-operating-model.template.md` — generic operating model. Structure per I5.
5. `test/slice-3-smoke.bats` — Groups I/J/K/L runnable spec.
6. `test/fixtures/pre-slice-3-command-count.txt` — baseline snapshot.
7. `test/fixtures/pre-slice-3-skill-count.txt` — baseline snapshot.
8. `CHANGELOG.md` — `Unreleased` entry.

### Out of scope (deferred to later slices)

- `brainstorming` scope question (Slice 4) — which of the four templates to read is Slice 4's concern.
- `setup-project` scaffolder that renders templates into a user repo (Slice 5).
- `phase-kickoff` workflow template (Slice 6).
- Any linter extension to cover strategic / playbook / operating-model template types — explicit non-goal per design §12. If wanted later, tracked in backlog.
- Any change to existing adapter files (`AGENTS.md.template`, `copilot-instructions.template`, `cursor-rules.template`).
- Any change to `.hotl/config.yml` schema — no new fields consumed by templates.

---

## 5. Module-level changes

| File | Change |
|---|---|
| `adapters/strategic-design.template.md` (NEW) | Generic strategic design template per I2 |
| `adapters/tactical-plan.template.md` (NEW) | Generic tactical plan template per I3 / J1 / J2. Default `risk_level: medium  # REVIEW BEFORE APPROVAL: confirm low \| medium \| high based on scope` — conservative default value with an explicit must-edit marker per §7 Q2 |
| `adapters/initiative-playbook.template.md` (NEW) | Generic per-initiative playbook per I4 |
| `adapters/initiative-operating-model.template.md` (NEW) | Generic operating-model template per I5 |
| `test/slice-3-smoke.bats` (NEW) | Groups I/J/K/L runnable spec |
| `test/fixtures/pre-slice-3-command-count.txt` (NEW) | Baseline snapshot |
| `test/fixtures/pre-slice-3-skill-count.txt` (NEW) | Baseline snapshot |
| `CHANGELOG.md` | `Unreleased` entry |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. Capture baselines: write `test/fixtures/pre-slice-3-command-count.txt` and `pre-slice-3-skill-count.txt` from current `main`. **First commit.**
2. Draft `adapters/tactical-plan.template.md` — write it first because Group J's lint round-trip is the strongest test, and getting this template right unblocks the others. Use `risk_level: medium  # REVIEW BEFORE APPROVAL: confirm low | medium | high based on scope` as the default (see §7 Q2).
3. Draft `adapters/strategic-design.template.md` — generalize from ODAP's `design-doc-template.md`. Strip all ODAP-specific examples and wording.
4. Draft `adapters/initiative-playbook.template.md` — generalize from ODAP's `ai-assurance-playbook.md`. Keep the session-discipline and repeating-per-phase-per-role skeleton; drop every ODAP-specific prompt.
5. Draft `adapters/initiative-operating-model.template.md` — generalize from ODAP's `hotl-operating-model.md`. Keep the roles + decision-rights-matrix + tripwires shape; generic role names only.
6. Author `test/slice-3-smoke.bats` with Groups I/J/K/L. Run and confirm green.
7. Run full `bats test/` — must be green end-to-end.
8. Update `CHANGELOG.md`.
9. **Manual review:** read each of the four templates end-to-end; confirm no ODAP-specific prose slipped through (I6 is an automated sanity check, not a substitute for reading).

---

## 7. Open questions

1. **Placeholder syntax:** `{{PLACEHOLDER_NAME}}` is the intended convention (balanced-brace check in K2 relies on it). An alternative is angle-bracket style `<PLACEHOLDER>` — rejected because raw `<...>` in Markdown is often interpreted as HTML. Confirming `{{...}}` is the final choice.

2. **`risk_level` default — conservative, not permissive.** J2 requires `risk_level:` to be a valid literal (`low|medium|high`) so the un-substituted template lints cleanly. The reviewer correctly flagged that `low` optimizes for lint-friction, not safety — a user who forgets to edit the default inherits the least-restrictive path by accident. Fixing in two layers:

   - **Default value: `medium`.** Neutral-conservative. Same lintability as `low`. Forces some gate activity even on an unedited template, so forgetting to edit surfaces before merge rather than after.
   - **Explicit must-edit marker.** The template line reads `risk_level: medium  # REVIEW BEFORE APPROVAL: confirm low | medium | high based on scope`. The comment is preserved by `document-lint.sh` (value before `#` is what lint reads). Reviewers scanning the rendered plan can't miss it.

   Open only for confirmation; not for reversal back to `low`.

3. **Roles vs. skill names — the playbook and operating model agree on roles.** The reviewer correctly pushed back on collapsing "role" into skill names — the operating-model template defines roles + decision rights, and the playbook is a per-phase × per-role prompt library. Skill names (`brainstorming`, `writing-plans`, `executing-plans`) are workflow skills, not roles.

   Resolution: both templates use a **generic role vocabulary** derived from ODAP's operating model but agent-neutral and not tied to any project. Proposed minimal set:

   | Role | Primary artifact |
   |---|---|
   | `@pm` | Requirements / acceptance criteria |
   | `@architect` | Designs, plans, ADRs |
   | `@dev` | Source code, tests |
   | `@qa` | Test plans, regression suites |
   | `@reviewer` | Review memos |
   | `@researcher` | Research notes |

   Each playbook prompt is scoped to one role ("use role `@architect` to produce `docs/plans/<phase>-plan.md`") and typically invokes one or more skills to do it (e.g., `writing-plans`). The two concepts are orthogonal: **roles** describe who owns an artifact; **skills** describe the workflow that produces it. The operating-model template defines the role vocabulary and decision-rights matrix; the playbook template references the same role vocabulary in its session table.

   Open only for confirmation of the six-role minimum set (the list may be shorter if we want to start narrower; not larger without triggering its own design review).
