#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    CODEX_DRIVER="$REPO_ROOT/runtime/drivers/codex.sh"
    CLAUDE_DRIVER="$REPO_ROOT/runtime/drivers/claude.sh"
    TEST_DIR=$(mktemp -d)
    cp -R "$REPO_ROOT/test/fixtures" "$TEST_DIR/fixtures"
    cd "$TEST_DIR"
    printf '%s\n' '#!/usr/bin/env bash' 'echo fake-host' > fake-host
    chmod +x fake-host
}

teardown() { rm -rf "$TEST_DIR"; }

@test "Codex auto mode falls back when native capability is unknown" {
    preflight=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$CODEX_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.resolved_mode' <<< "$preflight")" = "fallback" ]
    [ "$(jq -r '.fallback_reason' <<< "$preflight")" = "native_opt_in_missing_or_capability_unknown" ]
}

@test "Codex native opt-in resolves native and records driver identity" {
    preflight=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" HOTL_CODEX_NATIVE=1 "$CODEX_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.resolved_mode' <<< "$preflight")" = "native" ]
    run_id=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$CODEX_DRIVER" launch fixtures/hotl-workflow-runtime-sample.md --mode native)
    [ "$(jq -r '.driver' ".hotl/state/$run_id.json")" = "codex" ]
    [ "$(jq -r '.host' ".hotl/state/$run_id.json")" = "codex" ]
    [ "$(jq -r '.executor_mode' ".hotl/state/$run_id.json")" = "codex-native" ]
    receipt=$("$CODEX_DRIVER" receipt "$run_id")
    [ "$(jq -r '.implementation.driver' <<< "$receipt")" = "codex" ]
}

@test "Codex explicitly required native mode fails when executable is absent" {
    run env HOTL_CODEX_BIN="$TEST_DIR/missing" "$CODEX_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md --mode native
    [ "$status" -ne 0 ]
    [[ "$output" == *"host executable is unavailable"* ]]
    [ ! -e .hotl ]
}

@test "Codex envelope is model-neutral and retains HOTL completion rules" {
    envelope=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$CODEX_DRIVER" envelope fixtures/hotl-workflow-runtime-sample.md --mode native)
    [ "$(jq -r '.workflow.schema' <<< "$envelope")" = "hotl.workflow/v1" ]
    jq -e '.native_feature_hints | index("subagents")' <<< "$envelope"
    jq -e '.rules | index("Do not claim completion until receipt sufficiency is true")' <<< "$envelope"
    run grep -E 'gpt-[0-9]|claude-[0-9]' <<< "$envelope"
    [ "$status" -ne 0 ]
}

@test "Claude auto and explicit fallback are deterministic" {
    auto=$(HOTL_CLAUDE_BIN="$TEST_DIR/fake-host" "$CLAUDE_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md)
    explicit=$(HOTL_CLAUDE_BIN="$TEST_DIR/fake-host" HOTL_CLAUDE_NATIVE=1 "$CLAUDE_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md --mode fallback)
    [ "$(jq -r '.resolved_mode' <<< "$auto")" = "fallback" ]
    [ "$(jq -r '.fallback_reason' <<< "$explicit")" = "explicit_fallback" ]
}

@test "Claude native launch and envelope use the shared contract" {
    run_id=$(HOTL_CLAUDE_BIN="$TEST_DIR/fake-host" "$CLAUDE_DRIVER" launch fixtures/hotl-workflow-runtime-sample.md --mode native)
    [ "$(jq -r '.driver' ".hotl/state/$run_id.json")" = "claude" ]
    [ "$(jq -r '.executor_mode' ".hotl/state/$run_id.json")" = "claude-native" ]
    envelope=$(HOTL_CLAUDE_BIN="$TEST_DIR/fake-host" "$CLAUDE_DRIVER" envelope fixtures/hotl-workflow-runtime-sample.md --mode native)
    jq -e '.native_feature_hints | index("dynamic-workflows")' <<< "$envelope"
    jq -e '.native_feature_hints | index("agent-teams")' <<< "$envelope"
}

@test "host driver auto fallback launches the generic implementation" {
    run_id=$(HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$CODEX_DRIVER" launch fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.driver' ".hotl/state/$run_id.json")" = "generic" ]
    [ "$(jq -r '.host' ".hotl/state/$run_id.json")" = "fallback" ]
}

@test "host driver reports a missing mode value clearly" {
    run env HOTL_CODEX_BIN="$TEST_DIR/fake-host" "$CODEX_DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md --mode
    [ "$status" -ne 0 ]
    [[ "$output" == *"--mode requires"* ]]
}
