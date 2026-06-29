#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOTL_RT="${HOTL_RT:-$SCRIPT_DIR/../hotl-rt}"

usage() {
    cat <<'USAGE'
usage: generic.sh <describe|preflight|launch|step|gate|status|receipt|finalize|finish> [args]
USAGE
}

[ $# -gt 0 ] || { usage >&2; exit 1; }
command_name="$1"
shift

case "$command_name" in
    describe)
        jq -cn '{protocol:"hotl.driver/v1",id:"generic",host:"fallback",maturity:"conformant",execution:"hotl-rt",supports:["normalize","launch","step","gate","status","receipt","finalize","finish"]}'
        ;;
    preflight)
        [ $# -eq 1 ] || { echo "usage: generic.sh preflight <workflow>" >&2; exit 1; }
        normalized=$("$HOTL_RT" normalize "$1" --json)
        jq -cn --argjson workflow "$normalized" '{protocol:"hotl.driver/v1",driver:"generic",ready:true,fallback:false,workflow:$workflow}'
        ;;
    launch)
        [ $# -ge 1 ] || { echo "usage: generic.sh launch <workflow> [init options]" >&2; exit 1; }
        workflow="$1"
        shift
        "$HOTL_RT" init "$workflow" --executor-mode generic --driver generic --host fallback "$@"
        ;;
    step|gate|finalize|finish)
        "$HOTL_RT" "$command_name" "$@"
        ;;
    status)
        [ $# -eq 1 ] || { echo "usage: generic.sh status <run-id>" >&2; exit 1; }
        "$HOTL_RT" summary "$1" --json
        ;;
    receipt)
        [ $# -eq 1 ] || { echo "usage: generic.sh receipt <run-id>" >&2; exit 1; }
        "$HOTL_RT" receipt "$1" --json
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        echo "ERROR: Unknown generic driver command: $command_name" >&2
        usage >&2
        exit 1
        ;;
esac
