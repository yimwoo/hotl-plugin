#!/usr/bin/env bats
#
# Slice 3 smoke tests — enforces the four initiative-tier templates contract
# per docs/plans/2026-04-14-slice-3-templates-plan.md §2.1.
# Groups I/J/K/L continue the letter sequence from Slices 1 (A/B/C/D) and
# 2 (E/F/G/H).

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    DOCUMENT_LINT="$REPO_ROOT/scripts/document-lint.sh"
    HOTL_CONFIG_SH="$REPO_ROOT/scripts/hotl-config.sh"
    HOTL_CONFIG_RESOLVE="$REPO_ROOT/scripts/hotl-config-resolve.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TMP=$(mktemp -d)
    cd "$TMP"
}

teardown() {
    rm -rf "$TMP"
}

# ── Group I: template presence and required sections ───────────────────────

@test "I1: all four templates exist under adapters/" {
    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/tactical-plan.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        [ -f "$REPO_ROOT/$tmpl" ] || { echo "FAIL: missing $tmpl"; return 1; }
        local size
        size=$(wc -c < "$REPO_ROOT/$tmpl" | tr -d ' ')
        [ "$size" -gt 200 ] || { echo "FAIL: $tmpl is too small ($size bytes)"; return 1; }
    done
}

@test "I2: strategic-design.template.md carries required sections" {
    local tmpl="$REPO_ROOT/adapters/strategic-design.template.md"
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
}

@test "I3: tactical-plan.template.md carries the three HOTL contracts plus scope and task breakdown" {
    local tmpl="$REPO_ROOT/adapters/tactical-plan.template.md"
    for section in \
        'Intent contract' \
        'Verification contract' \
        'Governance contract' \
        'Scope' \
        'Task breakdown'; do
        grep -qi "$section" "$tmpl" \
            || { echo "FAIL: tactical-plan template missing '$section'"; return 1; }
    done
}

@test "I4: initiative-playbook.template.md has the per-phase x per-role structure" {
    local tmpl="$REPO_ROOT/adapters/initiative-playbook.template.md"
    grep -qi 'session discipline\|one session' "$tmpl" \
        || { echo "FAIL: playbook missing session discipline section"; return 1; }
    grep -qi 'repeating pattern\|per phase\|per-phase' "$tmpl" \
        || { echo "FAIL: playbook missing repeating per-phase pattern"; return 1; }
    grep -q '^```' "$tmpl" \
        || { echo "FAIL: playbook missing at least one fenced prompt example"; return 1; }
}

@test "I5: initiative-operating-model.template.md has roles, decision rights, and tripwires" {
    local tmpl="$REPO_ROOT/adapters/initiative-operating-model.template.md"
    # Each required section must be present (case-insensitive match).
    grep -qi 'Roles' "$tmpl" \
        || { echo "FAIL: operating-model template missing Roles"; return 1; }
    grep -qi 'Decision rights\|Decision-rights' "$tmpl" \
        || { echo "FAIL: operating-model template missing Decision rights"; return 1; }
    grep -qiE 'Tripwire|Escalation' "$tmpl" \
        || { echo "FAIL: operating-model template missing Tripwires/Escalation"; return 1; }
}

@test "I6: no ODAP-specific prose in any template" {
    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/tactical-plan.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        for term in 'ODAP' 'AI Assurance' 'Oracle DB' 'vdb-e2e' 'ai-assurance-playbook'; do
            if grep -qi "$term" "$REPO_ROOT/$tmpl"; then
                echo "FAIL: $tmpl contains ODAP-specific term '$term'"
                return 1
            fi
        done
    done
}

# ── Group J: tactical-plan.template.md produces a lint-passing plan doc ─────

@test "J1: tactical-plan template round-trip — substitute placeholders and lint green" {
    cp "$REPO_ROOT/adapters/tactical-plan.template.md" \
       "$TMP/2026-04-14-demo-plan.md"

    # Fill required placeholders with example values.
    sed -i.bak \
        -e 's/{{INITIATIVE_NAME}}/demo-initiative/g' \
        -e 's/{{PHASE_ID}}/1/g' \
        -e 's/{{DATE}}/2026-04-14/g' \
        "$TMP/2026-04-14-demo-plan.md"

    run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-plan.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'lint passed'
}

@test "J2: tactical-plan template carries all lint-required fields" {
    local tmpl="$REPO_ROOT/adapters/tactical-plan.template.md"
    grep -qi 'intent:' "$tmpl"
    grep -qi 'constraints:' "$tmpl"
    grep -qi 'success_criteria:' "$tmpl"
    grep -qi 'risk_level:' "$tmpl"
    # risk_level value is a valid literal, not a placeholder
    grep -qiE 'risk_level:[[:space:]]*(low|medium|high)\b' "$tmpl"
    grep -qi 'approval_gates\|approval gates' "$tmpl"
    grep -qi 'rollback:' "$tmpl"
    grep -qi 'verify\|check\|confirm\|run test' "$tmpl"
}

# ── Group K: generic render check for the other three templates ─────────────

@test "K1: internal anchor links resolve" {
    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        local file="$REPO_ROOT/$tmpl"
        local anchors
        anchors=$(grep -oE '\]\(#[a-zA-Z0-9_-]+\)' "$file" \
            | sed -E 's/.*\(#([a-zA-Z0-9_-]+)\).*/\1/' | sort -u)
        # If no anchor refs in the file, pass trivially.
        [ -z "$anchors" ] && continue
        # If there are refs, there must be at least some headings.
        grep -qE "^#+[[:space:]]+" "$file" \
            || { echo "FAIL: $tmpl has anchor refs but no headings"; return 1; }
        for anchor in $anchors; do
            local pattern
            pattern=$(echo "$anchor" | tr '-' ' ')
            grep -qiE "^#+[[:space:]]+.*${pattern}" "$file" \
                || { echo "FAIL: $tmpl anchor '#$anchor' has no matching heading"; return 1; }
        done
    done
}

@test "K2: placeholder braces and code fences balance" {
    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/tactical-plan.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        local file="$REPO_ROOT/$tmpl"
        local open close fences
        open=$(grep -o '{{' "$file" | wc -l | tr -d ' ')
        close=$(grep -o '}}' "$file" | wc -l | tr -d ' ')
        [ "$open" -eq "$close" ] \
            || { echo "FAIL: $tmpl unbalanced {{ ($open) vs }} ($close)"; return 1; }

        # grep -c returns exit 1 when count is 0; coerce to 0 so set -e does
        # not trip in tests.
        fences=$(grep -c '^```' "$file" || true)
        [ -z "$fences" ] && fences=0
        [ $((fences % 2)) -eq 0 ] \
            || { echo "FAIL: $tmpl odd number of code fences ($fences)"; return 1; }
    done
}

@test "K3: each template has at least one H1" {
    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/tactical-plan.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        local file="$REPO_ROOT/$tmpl"
        local h1_count
        h1_count=$(grep -c '^# ' "$file")
        [ "$h1_count" -ge 1 ] || { echo "FAIL: $tmpl missing H1"; return 1; }
    done
}

@test "K4: templates parse cleanly via pandoc (real Markdown render)" {
    if ! command -v pandoc >/dev/null 2>&1; then
        skip "pandoc not installed — skipping K4 (real Markdown render check)"
    fi

    for tmpl in \
        adapters/strategic-design.template.md \
        adapters/tactical-plan.template.md \
        adapters/initiative-playbook.template.md \
        adapters/initiative-operating-model.template.md; do
        local file="$REPO_ROOT/$tmpl"
        run pandoc --fail-if-warnings -f markdown -t html -o /dev/null "$file"
        [ "$status" -eq 0 ] || { echo "FAIL: $tmpl did not render cleanly via pandoc"; echo "$output"; return 1; }
    done
}

# ── Group L: small-user safety regression ───────────────────────────────────

@test "L1: all four Slice 3 templates still exist in adapters/" {
    # NOTE: The original L1 asserted "all four templates inert". Slice 4 and
    # Slice 5 legitimately consumed them all (strategic-design by
    # brainstorming, the other three by hotl-init-initiative.sh). The
    # "all four consumed" invariant is now enforced by slice-5-smoke.bats
    # S3. L1 is narrowed to a structural check: the four Slice 3 template
    # files must still exist in adapters/ so later slices can keep reading
    # them.
    for tmpl_name in \
        strategic-design.template.md \
        tactical-plan.template.md \
        initiative-playbook.template.md \
        initiative-operating-model.template.md; do
        [ -f "$REPO_ROOT/adapters/$tmpl_name" ] \
            || { echo "FAIL: $tmpl_name missing from adapters/"; return 1; }
    done
}

@test "L2: command count unchanged and skill count is at least the pre-Slice-3 baseline" {
    local expected_cmds actual_cmds expected_skills actual_skills
    expected_cmds=$(cat "$REPO_ROOT/test/fixtures/pre-slice-3-command-count.txt")
    actual_cmds=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$actual_cmds" -eq "$expected_cmds" ]

    expected_skills=$(cat "$REPO_ROOT/test/fixtures/pre-slice-3-skill-count.txt")
    actual_skills=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$actual_skills" -ge "$expected_skills" ]
}

@test "L3: Slice 3 surface creates no forbidden initiative-support artifacts in a clean repo" {
    git init -q

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
        [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created"; return 1; }
    done
}

@test "L4: prior slice smoke suites remain green after Slice 3" {
    run bats "$REPO_ROOT/test/slice-1-smoke.bats"
    [ "$status" -eq 0 ]

    run bats "$REPO_ROOT/test/slice-2-smoke.bats"
    [ "$status" -eq 0 ]
}
