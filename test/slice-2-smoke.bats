#!/usr/bin/env bats
#
# Slice 2 smoke tests — enforces the -plan.md rename + workflows_dir consumer
# contract per docs/plans/2026-04-14-slice-2-plan-rename-plan.md §2.1.
# Groups E/F/G/H continue the letter sequence from Slice 1 (A/B/C/D).

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

# ── Group E: document-lint.sh accepts both suffixes ─────────────────────────

@test "E1: lint accepts *-plan.md and *-design.md identically" {
    cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-demo-design.md"
    cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-demo-plan.md"

    run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-design.md"
    [ "$status" -eq 0 ]

    run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-plan.md"
    [ "$status" -eq 0 ]
}

@test "E2: lint skips files with neither suffix nor hotl-workflow- prefix" {
    cp "$FIXTURES/sample-design.md" "$TMP/random-notes.md"
    run bash "$DOCUMENT_LINT" "$TMP/random-notes.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "skip"
}

@test "E3: lint usage text mentions both design and plan suffixes" {
    run bash "$DOCUMENT_LINT"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q '\-design\.md'
    echo "$output" | grep -q '\-plan\.md'
}

# ── Group F: SKILL.md content parity between suffixes ───────────────────────

@test "F1: brainstorming default output path is -plan.md" {
    grep -E 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' \
        "$REPO_ROOT/skills/brainstorming/SKILL.md"
}

@test "F2: executor/reviewer rule lines name both suffixes on the same line" {
    # Canonical form required: two literal globs on one line, either order.
    # Brace-expansion forms not accepted.
    local pattern='docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md'

    for skill in \
        skills/loop-execution/SKILL.md \
        skills/executing-plans/SKILL.md \
        skills/document-review/SKILL.md \
        cline/rules/hotl-execution.md \
        cline/rules/hotl-document-review.md; do
        grep -E "$pattern" "$REPO_ROOT/$skill" \
            || { echo "FAIL: $skill rule line does not name both suffixes"; return 1; }
    done
}

@test "F2b: loop-execution exclusion glob actually matches a representative *-plan.md file" {
    local pattern='docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md'
    GLOB_LINE=$(grep -E "$pattern" \
        "$REPO_ROOT/skills/loop-execution/SKILL.md" | head -1)
    [ -n "$GLOB_LINE" ]

    for glob in 'docs/plans/*-plan.md' 'docs/plans/*-design.md'; do
        echo "$GLOB_LINE" | grep -qF "$glob"
    done

    # Behavioral: the -plan.md glob actually resolves a representative file.
    mkdir -p docs/plans
    touch docs/plans/2026-04-14-demo-plan.md
    shopt -s nullglob
    MATCHES=(docs/plans/*-plan.md)
    [ ${#MATCHES[@]} -eq 1 ]
    [ "${MATCHES[0]}" = "docs/plans/2026-04-14-demo-plan.md" ]
}

@test "F3: cline hotl-brainstorming mirror updated to -plan.md" {
    grep -q 'docs/plans/YYYY-MM-DD-<topic>-plan\.md' \
        "$REPO_ROOT/cline/rules/hotl-brainstorming.md"
}

# ── Group G: writing-plans honors workflows_dir ─────────────────────────────

@test "G1: writing-plans SKILL.md documents workflows_dir resolution" {
    # Must reference the resolver (command proxy) and the --default=.
    grep -q 'hotl-config-resolve\.sh' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q 'workflows_dir' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q -- '--default=\.' "$REPO_ROOT/skills/writing-plans/SKILL.md"
}

@test "G2: config resolver returns workflows_dir override from .hotl/config.yml" {
    mkdir -p .hotl
    echo "workflows_dir: docs/workflows" > .hotl/config.yml
    run bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=.
    [ "$status" -eq 0 ]
    [ "$output" = "docs/workflows" ]
}

@test "G3: config resolver returns default when .hotl/config.yml absent" {
    run bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=.
    [ "$status" -eq 0 ]
    [ "$output" = "." ]
}

# ── Group H: small-user safety regression ───────────────────────────────────

@test "H1: existing -design.md files remain accepted by every consumer" {
    # Behavioral: a real -design.md file still passes lint end-to-end.
    cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-legacy-design.md"
    run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-legacy-design.md"
    [ "$status" -eq 0 ]

    # Rule-line: document-review classification must still carry both literal
    # globs including -design.md (canonical F2 form).
    local pattern='docs/plans/\*-design\.md.*docs/plans/\*-plan\.md|docs/plans/\*-plan\.md.*docs/plans/\*-design\.md'
    grep -E "$pattern" "$REPO_ROOT/skills/document-review/SKILL.md" \
        || { echo "FAIL: document-review classification does not carry both globs"; return 1; }

    # Rule-line: executor exclusions must still list the literal
    # docs/plans/*-design.md glob.
    for skill in \
        skills/loop-execution/SKILL.md \
        skills/executing-plans/SKILL.md; do
        grep -qF 'docs/plans/*-design.md' "$REPO_ROOT/$skill" \
            || { echo "FAIL: $skill exclusion no longer names literal -design.md"; return 1; }
    done

    # Behavioral round-trip: -design.md glob still resolves a legacy file.
    mkdir -p docs/plans
    touch docs/plans/2026-04-14-legacy-design.md
    shopt -s nullglob
    MATCHES=(docs/plans/*-design.md)
    [ ${#MATCHES[@]} -eq 1 ]
}

@test "H2: command and skill counts unchanged from pre-Slice-2 baseline" {
    EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-command-count.txt")
    ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

    EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-skill-count.txt")
    ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$ACTUAL_SKILLS" -eq "$EXPECTED_SKILLS" ]
}

@test "H3: Slice 2 surface in clean repo creates no forbidden initiative-support artifacts" {
    git init -q

    # Exercise all Slice 2 surfaces that could create files.
    bash "$HOTL_RT" log-decision '{"event":"test"}'
    bash "$HOTL_CONFIG_SH" get workflows_dir --default=. >/dev/null
    bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=. >/dev/null
    bash "$DOCUMENT_LINT" "$FIXTURES/sample-design.md" >/dev/null

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

@test "H4: existing runtime-integration.bats remains green after Slice 2" {
    run bats "$REPO_ROOT/test/runtime-integration.bats"
    [ "$status" -eq 0 ]
}
