#!/usr/bin/env bats
#
# Slice 6 smoke tests — enforces the phase-kickoff workflow contract per
# docs/plans/2026-04-14-slice-6-phase-kickoff-plan.md §2.1.
# Groups T/U/V continue the letter sequence from prior slices (A–S).

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    DOCUMENT_LINT="$REPO_ROOT/scripts/document-lint.sh"
    HOTL_CONFIG_RESOLVE="$REPO_ROOT/scripts/hotl-config-resolve.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    TMP=$(mktemp -d)
    cd "$TMP"
}

teardown() {
    rm -rf "$TMP"
}

# ── Group T: workflows/phase-kickoff.md structural contract ────────────────

@test "T1: workflows/phase-kickoff.md exists and is non-trivial" {
    [ -f "$REPO_ROOT/workflows/phase-kickoff.md" ]
    local size
    size=$(wc -c < "$REPO_ROOT/workflows/phase-kickoff.md" | tr -d ' ')
    [ "$size" -gt 400 ]
}

@test "T2: phase-kickoff template passes document-lint when copied to hotl-workflow-*.md" {
    cp "$REPO_ROOT/workflows/phase-kickoff.md" "$TMP/hotl-workflow-demo-phase-1-kickoff.md"
    run bash "$DOCUMENT_LINT" "$TMP/hotl-workflow-demo-phase-1-kickoff.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'lint passed'
}

@test "T3: three expected steps present in order — review → triage → requirements" {
    local file="$REPO_ROOT/workflows/phase-kickoff.md"

    local review_line triage_line reqs_line
    review_line=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Rr]eview' "$file" | head -1 | cut -d: -f1)
    triage_line=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Tt]riage' "$file" | head -1 | cut -d: -f1)
    reqs_line=$(grep -nE '^- \[[ xX]\] \*\*Step [0-9]+:.*[Rr]equirement' "$file" | head -1 | cut -d: -f1)

    [ -n "$review_line" ] || { echo "FAIL: no review step found"; return 1; }
    [ -n "$triage_line" ] || { echo "FAIL: no triage step found"; return 1; }
    [ -n "$reqs_line" ]   || { echo "FAIL: no requirements step found"; return 1; }

    [ "$review_line" -lt "$triage_line" ] \
        || { echo "FAIL: review step is not before triage step"; return 1; }
    [ "$triage_line" -lt "$reqs_line" ] \
        || { echo "FAIL: triage step is not before requirements step"; return 1; }
}

@test "T4: each step has a gate: human line — human approval between steps is load-bearing" {
    local file="$REPO_ROOT/workflows/phase-kickoff.md"
    local gates
    gates=$(grep -c '^gate:[[:space:]]*human' "$file")
    [ "$gates" -ge 3 ] || { echo "FAIL: expected >= 3 gate: human lines, got $gates"; return 1; }
}

@test "T5: output paths reference the initiative-support taxonomy (docs/reviews, docs/requirements)" {
    local file="$REPO_ROOT/workflows/phase-kickoff.md"
    grep -q 'docs/reviews/' "$file" \
        || { echo "FAIL: template must reference docs/reviews/"; return 1; }
    grep -q 'docs/requirements/' "$file" \
        || { echo "FAIL: template must reference docs/requirements/"; return 1; }
}

@test "T6: placeholders balance; {{SLUG}} and {{PHASE_ID}} present" {
    local file="$REPO_ROOT/workflows/phase-kickoff.md"
    local open close
    open=$(grep -o '{{' "$file" | wc -l | tr -d ' ')
    close=$(grep -o '}}' "$file" | wc -l | tr -d ' ')
    [ "$open" -eq "$close" ] \
        || { echo "FAIL: unbalanced {{ ($open) vs }} ($close)"; return 1; }
    grep -q '{{SLUG}}' "$file"
    grep -q '{{PHASE_ID}}' "$file"
}

@test "T7: no ODAP-specific prose in phase-kickoff template" {
    local file="$REPO_ROOT/workflows/phase-kickoff.md"
    for term in 'ODAP' 'AI Assurance' 'Oracle DB' 'vdb-e2e' 'ai-assurance-playbook'; do
        if grep -qi "$term" "$file"; then
            echo "FAIL: phase-kickoff template contains ODAP-specific term '$term'"
            return 1
        fi
    done
}

# ── Group U: playbook template references the phase-kickoff workflow ───────

@test "U1: initiative-playbook template points to workflows/phase-kickoff.md" {
    local tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
    grep -qE 'workflows/phase-kickoff\.md|phase-kickoff workflow|phase-kickoff template' "$tmpl"
}

@test "U2: playbook names the install-path resolution rule for the workflow" {
    local tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
    grep -qE 'six-location|install-path|document-review/SKILL\.md|HOTL install' "$tmpl"
}

# ── Group V: small-user safety regression ──────────────────────────────────

@test "V1: command count unchanged and skill count is at least the pre-Slice-6 baseline" {
    local expected_cmds actual_cmds expected_skills actual_skills
    expected_cmds=$(cat "$REPO_ROOT/test/fixtures/pre-slice-6-command-count.txt")
    actual_cmds=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$actual_cmds" -eq "$expected_cmds" ]

    expected_skills=$(cat "$REPO_ROOT/test/fixtures/pre-slice-6-skill-count.txt")
    actual_skills=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$actual_skills" -ge "$expected_skills" ]
}

@test "V2: Slice 6 surface in a clean repo creates no forbidden initiative-support artifacts" {
    git init -q

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
}

@test "V3: existing workflows/*.md templates unchanged; phase-kickoff.md added" {
    for tmpl in \
        workflows/feature.md \
        workflows/bugfix.md \
        workflows/refactor.md; do
        [ -f "$REPO_ROOT/$tmpl" ] \
            || { echo "FAIL: $tmpl missing"; return 1; }
    done

    ls "$REPO_ROOT/workflows/" | grep -qx 'feature.md'
    ls "$REPO_ROOT/workflows/" | grep -qx 'bugfix.md'
    ls "$REPO_ROOT/workflows/" | grep -qx 'refactor.md'
    ls "$REPO_ROOT/workflows/" | grep -qx 'phase-kickoff.md'
}

@test "V4: prior slice smoke suites remain directly discoverable" {
    for suite in \
        test/slice-1-smoke.bats \
        test/slice-2-smoke.bats \
        test/slice-3-smoke.bats \
        test/slice-4-smoke.bats \
        test/slice-5-smoke.bats; do
        [ -f "$REPO_ROOT/$suite" ]
    done
}
