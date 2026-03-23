#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOTL_RT="$REPO_ROOT/runtime/hotl-rt"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not found." >&2
    exit 1
fi

state_file="$(ls -t .hotl/state/*.json 2>/dev/null | head -1 || true)"
if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
    echo "ERROR: No active HOTL run found in .hotl/state/" >&2
    exit 1
fi

run_id="$(jq -r '.run_id' "$state_file")"
summary_json="$("$HOTL_RT" summary "$run_id" --json)"
state_current_step="$(jq -r '.current_step // 1' "$state_file")"
current_index="$(echo "$summary_json" | jq -r '
    .steps
    | map(select(.status == "in_progress"))[0].number // empty
')"
if [ -z "$current_index" ]; then
    current_index="$state_current_step"
fi
step_total="$(echo "$summary_json" | jq -r '.total_steps')"
step_name="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].name')"
step_status="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].status')"
step_attempts="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].attempts')"

cat <<EOF
Current step: ${current_index}/${step_total}
Name: ${step_name}
Status: ${step_status}
Attempts: ${step_attempts}
EOF
