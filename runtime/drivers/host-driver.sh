#!/usr/bin/env bash
set -euo pipefail

[ $# -ge 2 ] || { echo "usage: host-driver.sh <codex|claude> <command> [args]" >&2; exit 1; }
HOST_ID="$1"; shift
COMMAND_NAME="$1"; shift

case "$HOST_ID" in
    codex) HOST_BIN="${HOTL_CODEX_BIN:-codex}"; OPT_IN="${HOTL_CODEX_NATIVE:-0}" ;;
    claude) HOST_BIN="${HOTL_CLAUDE_BIN:-claude}"; OPT_IN="${HOTL_CLAUDE_NATIVE:-0}" ;;
    *) echo "ERROR: Unsupported host driver: $HOST_ID" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOTL_RT="${HOTL_RT:-$SCRIPT_DIR/../hotl-rt}"
GENERIC="$SCRIPT_DIR/generic.sh"

host_present() {
    if [[ "$HOST_BIN" == */* ]]; then [ -x "$HOST_BIN" ]; else command -v "$HOST_BIN" >/dev/null 2>&1; fi
}

resolve_mode() {
    case "$1" in
        fallback) echo fallback ;;
        native)
            host_present || { echo "ERROR: $HOST_ID native mode requested but host executable is unavailable" >&2; return 1; }
            echo native
            ;;
        auto)
            if [ "$OPT_IN" = "1" ] && host_present; then echo native; else echo fallback; fi
            ;;
        *) echo "ERROR: mode must be auto, native, or fallback" >&2; return 1 ;;
    esac
}

parse_mode() {
    REQUESTED_MODE=auto
    REMAINING=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)
                [ $# -ge 2 ] || { echo "ERROR: --mode requires auto, native, or fallback" >&2; return 1; }
                REQUESTED_MODE="$2"; shift 2
                ;;
            *) REMAINING+=("$1"); shift ;;
        esac
    done
}

case "$COMMAND_NAME" in
    describe)
        jq -cn --arg id "$HOST_ID" '{protocol:"hotl.driver/v1",id:$id,host:$id,maturity:"experimental",opt_in_required:true,execution:"host-native-with-hotl-evidence",supports:["normalize","preflight","envelope","launch","owner","step","gate","action","budget","status","receipt","reconcile","finalize","finish"]}'
        ;;
    preflight)
        [ $# -ge 1 ] || { echo "usage: $HOST_ID.sh preflight <workflow> [--mode auto|native|fallback]" >&2; exit 1; }
        workflow="$1"; shift; parse_mode "$@"
        [ "${#REMAINING[@]}" -eq 0 ] || { echo "ERROR: Unknown preflight option: ${REMAINING[0]}" >&2; exit 1; }
        resolved=$(resolve_mode "$REQUESTED_MODE")
        normalized=$("$HOTL_RT" normalize "$workflow" --json)
        present=false; host_present && present=true
        reason=null
        if [ "$resolved" = fallback ]; then
            if [ "$REQUESTED_MODE" = fallback ]; then reason='"explicit_fallback"'
            elif [ "$present" = false ]; then reason='"host_unavailable"'
            else reason='"native_opt_in_missing_or_capability_unknown"'; fi
        fi
        jq -cn --arg driver "$HOST_ID" --arg requested "$REQUESTED_MODE" --arg resolved "$resolved" --argjson present "$present" --argjson reason "$reason" --argjson workflow "$normalized" '{protocol:"hotl.driver/v1",driver:$driver,ready:true,requested_mode:$requested,resolved_mode:$resolved,fallback:($resolved=="fallback"),fallback_reason:$reason,host_present:$present,workflow:$workflow}'
        ;;
    envelope)
        [ $# -ge 1 ] || { echo "usage: $HOST_ID.sh envelope <workflow> [--mode auto|native|fallback]" >&2; exit 1; }
        workflow="$1"; shift; parse_mode "$@"
        [ "${#REMAINING[@]}" -eq 0 ] || { echo "ERROR: Unknown envelope option: ${REMAINING[0]}" >&2; exit 1; }
        resolved=$(resolve_mode "$REQUESTED_MODE")
        normalized=$("$HOTL_RT" normalize "$workflow" --json)
        if [ "$HOST_ID" = codex ]; then
            features='["plan","goal-mode","automations","thread-handoff","hooks","subagents","worktrees","review"]'
            continuation='[{"id":"goal-mode","maturity":"stable","opt_in":false,"completion_authority":false},{"id":"automations","maturity":"stable","opt_in":false,"completion_authority":false},{"id":"thread-handoff","maturity":"stable","opt_in":false,"completion_authority":false},{"id":"hooks","maturity":"stable","opt_in":false,"completion_authority":false}]'
        else
            features='["goal-loop","background-subagents","agent-view","dynamic-workflows","subagents","agent-teams","worktrees"]'
            continuation='[{"id":"goal-loop","maturity":"stable","opt_in":false,"completion_authority":false},{"id":"background-subagents","maturity":"stable","opt_in":false,"completion_authority":false},{"id":"agent-view","maturity":"research_preview","opt_in":true,"completion_authority":false}]'
        fi
        jq -cn --arg driver "$HOST_ID" --arg mode "$resolved" --argjson workflow "$normalized" --argjson features "$features" --argjson continuation "$continuation" '{protocol:"hotl.driver/v1",driver:$driver,resolved_mode:$mode,workflow:$workflow,native_feature_hints:$features,continuation_hints:$continuation,rules:["Host permissions remain authoritative","Record every owner, step, gate, action, budget, and finish transition through HOTL runtime","Host continuation is scheduling and liveness only; HOTL state and receipts remain authoritative","Do not claim completion until receipt sufficiency is true","External writes require explicit policy approval and durable effect evidence"]}'
        ;;
    launch)
        [ $# -ge 1 ] || { echo "usage: $HOST_ID.sh launch <workflow> [--mode auto|native|fallback] [init options]" >&2; exit 1; }
        workflow="$1"; shift; parse_mode "$@"
        resolved=$(resolve_mode "$REQUESTED_MODE")
        if [ "$resolved" = fallback ]; then
            if [ "${#REMAINING[@]}" -gt 0 ]; then "$GENERIC" launch "$workflow" "${REMAINING[@]}"; else "$GENERIC" launch "$workflow"; fi
        else
            if [ "${#REMAINING[@]}" -gt 0 ]; then
                "$HOTL_RT" init "$workflow" --require-owner --executor-mode "$HOST_ID-native" --driver "$HOST_ID" --host "$HOST_ID" "${REMAINING[@]}"
            else
                "$HOTL_RT" init "$workflow" --require-owner --executor-mode "$HOST_ID-native" --driver "$HOST_ID" --host "$HOST_ID"
            fi
        fi
        ;;
    owner|step|gate|action|budget|reconcile|finalize|finish)
        "$HOTL_RT" "$COMMAND_NAME" "$@"
        ;;
    status)
        [ $# -eq 1 ] || { echo "usage: $HOST_ID.sh status <run-id>" >&2; exit 1; }
        "$HOTL_RT" summary "$1" --json
        ;;
    receipt)
        [ $# -eq 1 ] || { echo "usage: $HOST_ID.sh receipt <run-id>" >&2; exit 1; }
        "$HOTL_RT" receipt "$1" --json
        ;;
    *) echo "ERROR: Unknown $HOST_ID driver command: $COMMAND_NAME" >&2; exit 1 ;;
esac
