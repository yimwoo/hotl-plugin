#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOTL_RT="${HOTL_RT:-$SCRIPT_DIR/../runtime/hotl-rt}"
STATE_DIR="${HOTL_STATE_DIR:-.hotl/state}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }

receipts='[]'
shopt -s nullglob
for state in "$STATE_DIR"/*.json; do
    run_id=$(jq -r '.run_id' "$state")
    state_root=$(cd "$(dirname "$STATE_DIR")/.." && pwd -P)
    receipt=$(cd "$state_root" && "$HOTL_RT" receipt "$run_id" --json)
    receipts=$(jq -cn --argjson current "$receipts" --argjson receipt "$receipt" '$current + [$receipt]')
done
shopt -u nullglob

jq -cn --argjson receipts "$receipts" '
    ($receipts|length) as $total |
    ([$receipts[]|select(.implementation.driver!="generic")]|length) as $native |
    ([$receipts[]|select(.sufficiency.sufficient)]|length) as $sufficient |
    {
      schema:"hotl.adoption/v1",
      source:"local-state-only",
      total_runs:$total,
      sufficient_receipts:$sufficient,
      incomplete_or_insufficient:($total-$sufficient),
      by_driver:([$receipts[].implementation.driver] | group_by(.) | map({key:.[0],value:length}) | from_entries),
      by_executor:([$receipts[].run.executor_mode] | group_by(.) | map({key:.[0],value:length}) | from_entries),
      native_runs:$native,
      telemetry_uploaded:false,
      recommendation:(if $total==0 then "collect_local_evidence" elif $native==0 then "keep_fallback_default" elif $native>=3 and $sufficient==$total then "review_native_default_with_humans" else "continue_native_pilot" end)
    }'
