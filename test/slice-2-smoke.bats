#!/usr/bin/env bats
#
# Slice 2 smoke tests — enforces canonical docs/designs + docs/plans workflow
# taxonomy with legacy compatibility for prior design/workflow locations.

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

# ── Group E: document-lint.sh accepts canonical + legacy HOTL artifacts ─────

@test "E1: lint accepts canonical docs/designs docs and legacy plan docs" {
    mkdir -p "$TMP/docs/designs"
    cp "$FIXTURES/sample-design.md" "$TMP/docs/designs/demo-initiative.md"
    cp "$FIXTURES/sample-design.md" "$TMP/2026-04-14-demo-plan.md"

    run bash "$DOCUMENT_LINT" "$TMP/docs/designs/demo-initiative.md"
    [ "$status" -eq 0 ]

    run bash "$DOCUMENT_LINT" "$TMP/2026-04-14-demo-plan.md"
    [ "$status" -eq 0 ]
}

@test "E2: lint accepts canonical docs/plans/*-workflow.md files" {
    mkdir -p "$TMP/docs/plans"
    cp "$FIXTURES/hotl-workflow-checkbox-sample.md" \
        "$TMP/docs/plans/2026-04-14-demo-workflow.md"

    run bash "$DOCUMENT_LINT" "$TMP/docs/plans/2026-04-14-demo-workflow.md"
    [ "$status" -eq 0 ]
}

@test "E3: lint skips files outside canonical and legacy HOTL paths" {
    cp "$FIXTURES/sample-design.md" "$TMP/random-notes.md"
    run bash "$DOCUMENT_LINT" "$TMP/random-notes.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "skip"
}

@test "E4: lint usage text mentions canonical design and workflow locations" {
    run bash "$DOCUMENT_LINT"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'docs/designs'
    echo "$output" | grep -q '\-workflow\.md'
}

# ── Group F: skill/rule parity for canonical taxonomy ───────────────────────

@test "F1: brainstorming default output path is docs/designs/*-design.md" {
    grep -q 'docs/designs/YYYY-MM-DD-<slug>-design.md' \
        "$REPO_ROOT/skills/brainstorming/SKILL.md"
    grep -q 'docs/designs/YYYY-MM-DD-phase-N-<slug>-design.md' \
        "$REPO_ROOT/skills/brainstorming/SKILL.md"
}

@test "F2: document-review classifies canonical and legacy HOTL docs" {
    local skill="$REPO_ROOT/skills/document-review/SKILL.md"
    grep -qF 'docs/designs/*.md' "$skill"
    grep -qF 'docs/plans/*-workflow.md' "$skill"
    grep -qF 'docs/plans/*-plan.md' "$skill"
    grep -qF 'hotl-workflow-*.md' "$skill"
}

@test "F3: executor exclusions name canonical and legacy HOTL artifacts" {
    for skill in \
        skills/loop-execution/SKILL.md \
        skills/executing-plans/SKILL.md; do
        grep -qF 'docs/plans/*-workflow.md' "$REPO_ROOT/$skill"
        grep -qF 'docs/designs/*.md' "$REPO_ROOT/$skill"
        grep -qF 'docs/plans/*-plan.md' "$REPO_ROOT/$skill"
        grep -qF 'hotl-workflow-*.md' "$REPO_ROOT/$skill"
    done
}

# ── Group G: writing-plans honors workflows_dir with docs/plans default ─────

@test "G1: writing-plans SKILL.md documents workflows_dir resolution with docs/plans default" {
    grep -q 'hotl-config-resolve\.sh' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q 'workflows_dir' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q -- '--default=docs/plans' "$REPO_ROOT/skills/writing-plans/SKILL.md"
}

@test "G2: config resolver returns workflows_dir override from .hotl/config.yml" {
    mkdir -p .hotl
    echo "workflows_dir: docs/workflows" > .hotl/config.yml
    run bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=docs/plans
    [ "$status" -eq 0 ]
    [ "$output" = "docs/workflows" ]
}

@test "G3: config resolver returns docs/plans default when config absent" {
    run bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=docs/plans
    [ "$status" -eq 0 ]
    [ "$output" = "docs/plans" ]
}

# ── Group H: compatibility and safety regression checks ─────────────────────

@test "H1: legacy design docs remain accepted by lint and review classification" {
    mkdir -p docs/plans
    cp "$FIXTURES/sample-design.md" "$TMP/docs/plans/2026-04-14-legacy-plan.md"

    run bash "$DOCUMENT_LINT" "$TMP/docs/plans/2026-04-14-legacy-plan.md"
    [ "$status" -eq 0 ]

    grep -qF 'docs/plans/*-plan.md' "$REPO_ROOT/skills/document-review/SKILL.md"
    shopt -s nullglob
    MATCHES=(docs/plans/*-plan.md)
    [ ${#MATCHES[@]} -eq 1 ]
}

@test "H2: command count unchanged and skill count is at least the pre-Slice-2 baseline" {
    EXPECTED_CMDS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-command-count.txt")
    ACTUAL_CMDS=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$ACTUAL_CMDS" -eq "$EXPECTED_CMDS" ]

    EXPECTED_SKILLS=$(cat "$REPO_ROOT/test/fixtures/pre-slice-2-skill-count.txt")
    ACTUAL_SKILLS=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$ACTUAL_SKILLS" -ge "$EXPECTED_SKILLS" ]
}

@test "H3: Slice 2 surface in clean repo creates no forbidden initiative-support artifacts" {
    git init -q

    bash "$HOTL_RT" log-decision '{"event":"test"}'
    bash "$HOTL_CONFIG_SH" get workflows_dir --default=docs/plans >/dev/null
    bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=docs/plans >/dev/null
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
