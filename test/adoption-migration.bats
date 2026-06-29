#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    ROUTER="$REPO_ROOT/runtime/drivers/route.sh"
    ADOPTION="$REPO_ROOT/scripts/hotl-adoption-report.sh"
    MEMORY="$REPO_ROOT/scripts/hotl-memory-proposal.sh"
    TEST_DIR=$(mktemp -d)
    cp -R "$REPO_ROOT/test/fixtures" "$TEST_DIR/fixtures"
    cd "$TEST_DIR"
    printf '%s\n' '#!/usr/bin/env bash' 'echo fake' > fake-host
    chmod +x fake-host
}

teardown() { rm -rf "$TEST_DIR"; }

@test "router defaults to generic without trusted host context" {
    result=$(env -u CODEX_HOME -u CLAUDE_PLUGIN_ROOT -u HOTL_ACTIVE_HOST -u HOTL_HOST "$ROUTER" preflight fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.driver' <<< "$result")" = "generic" ]
}

@test "router honors explicit and trusted Codex context without assuming native capability" {
    explicit=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$ROUTER" --host codex preflight fixtures/hotl-workflow-runtime-sample.md)
    contextual=$(CODEX_HOME="$TEST_DIR/codex" HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$ROUTER" preflight fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.driver' <<< "$explicit")" = "codex" ]
    [ "$(jq -r '.resolved_mode' <<< "$explicit")" = "fallback" ]
    [ "$(jq -r '.driver' <<< "$contextual")" = "codex" ]
}

@test "adoption report is read-only and handles no local runs" {
    before=$(find . -maxdepth 2 -type f | sort)
    report=$("$ADOPTION")
    after=$(find . -maxdepth 2 -type f | sort)
    [ "$before" = "$after" ]
    [ "$(jq -r '.total_runs' <<< "$report")" = "0" ]
    [ "$(jq -r '.recommendation' <<< "$report")" = "collect_local_evidence" ]
    [ "$(jq -r '.telemetry_uploaded' <<< "$report")" = "false" ]
}

@test "adoption report aggregates durable driver and executor evidence" {
    generic_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md --executor-mode loop)
    codex_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md --executor-mode codex-native --driver codex --host codex)
    report=$("$ADOPTION")
    [ "$(jq -r '.total_runs' <<< "$report")" = "2" ]
    [ "$(jq -r '.by_driver.generic' <<< "$report")" = "1" ]
    [ "$(jq -r '.by_driver.codex' <<< "$report")" = "1" ]
    [ "$(jq -r '.native_runs' <<< "$report")" = "1" ]
    [ -f ".hotl/state/$generic_id.json" ]
    [ -f ".hotl/state/$codex_id.json" ]
}

@test "memory proposal is evidence-linked review-required and performs no write" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    before=$(shasum ".hotl/state/$run_id.json")
    proposal=$("$MEMORY" "$run_id" --fact 'Use the portable driver for governed releases' --scope project)
    after=$(shasum ".hotl/state/$run_id.json")
    [ "$before" = "$after" ]
    [ "$(jq -r '.status' <<< "$proposal")" = "needs-human-review" ]
    [ "$(jq -r '.writes_performed' <<< "$proposal")" = "false" ]
    [ "$(jq -r '.proposed_facts[0].status' <<< "$proposal")" = "proposed" ]
    [ "$(jq -r '.evidence_refs[0].run_id' <<< "$proposal")" = "$run_id" ]
}

@test "governed execution is indexed and compatibility profiles remain" {
    [ -s "$REPO_ROOT/skills/governed-execution/SKILL.md" ]
    grep -q 'hotl:governed-execution' "$REPO_ROOT/skills/using-hotl/SKILL.md"
    grep -q 'governed-execution' "$REPO_ROOT/docs/skills.md"
    grep -q 'governed-execution' "$REPO_ROOT/docs/README.codex.md"
    for skill in loop-execution executing-plans subagent-execution resuming; do
        [ -s "$REPO_ROOT/skills/$skill/SKILL.md" ]
    done
    for command in loop execute-plan subagent-execute resume; do
        [ -s "$REPO_ROOT/commands/$command.md" ]
    done
}

@test "migration guide forbids automatic memory and entry-point removal" {
    grep -q 'No execution entry point is removed' "$REPO_ROOT/docs/migration-host-native.md"
    grep -q 'never writes memory' "$REPO_ROOT/docs/migration-host-native.md"
    grep -q 'manually installed and explicitly enabled' "$REPO_ROOT/docs/migration-host-native.md"
}

@test "Cline native installers and updaters include governed execution" {
    grep -q 'NATIVE_SKILLS=.*governed-execution' "$REPO_ROOT/install-cline.sh"
    grep -q 'NATIVE_SKILLS=.*governed-execution' "$REPO_ROOT/update.sh"
    grep -q 'NativeSkillNames.*governed-execution' "$REPO_ROOT/install-cline.ps1"
    grep -q 'NativeSkillNames.*governed-execution' "$REPO_ROOT/update.ps1"
    grep -q '11 native skills' "$REPO_ROOT/docs/README.cline.md"
}
