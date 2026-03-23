#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
RENDERER="$REPO_ROOT/scripts/render-execution-summary.sh"

if ! command -v mktemp >/dev/null 2>&1; then
    echo "ERROR: mktemp is required but not found." >&2
    exit 1
fi

summary_json="$(mktemp)"
cleanup() {
    rm -f "$summary_json"
}
trap cleanup EXIT

"$HOTL_RT" finalize --json > "$summary_json"
"$RENDERER" --platform codex "$summary_json"
