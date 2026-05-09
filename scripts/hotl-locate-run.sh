#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE' >&2
usage: hotl-locate-run.sh [--workflow <workflow-file>] [--run-id <run-id>] [--all]

Locate HOTL runtime state from the current checkout, linked git worktrees, and
HOTL's default .hotl-worktrees directory. Prints a JSON array of matching runs.

By default, completed and abandoned runs are excluded.
USAGE
    exit 1
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required but not found." >&2
        exit 1
    fi
}

abspath_if_possible() {
    local path="$1"
    local dir base

    if [ -z "$path" ]; then
        echo ""
        return 0
    fi

    dir=$(dirname "$path")
    base=$(basename "$path")
    if [ -d "$dir" ]; then
        (
            cd "$dir"
            printf '%s/%s\n' "$(pwd -P)" "$base"
        )
    else
        printf '%s\n' "$path"
    fi
}

add_root() {
    local root="$1"
    [ -n "$root" ] || return 0
    [ -d "$root" ] || return 0
    (
        cd "$root"
        pwd -P
    ) >> "$roots_tmp"
}

workflow=""
run_id=""
include_all=0

while [ $# -gt 0 ]; do
    case "$1" in
        --workflow)
            [ $# -ge 2 ] || usage
            workflow="$2"
            shift 2
            ;;
        --run-id)
            [ $# -ge 2 ] || usage
            run_id="$2"
            shift 2
            ;;
        --all)
            include_all=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage
            ;;
    esac
done

require_jq

workflow="$(abspath_if_possible "$workflow")"

roots_tmp="$(mktemp)"
matches_tmp="$(mktemp)"
cleanup() {
    rm -f "$roots_tmp" "$matches_tmp"
}
trap cleanup EXIT

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ]; then
    repo_root="$(cd "$repo_root" && pwd -P)"
fi

add_root "$(pwd -P)"
add_root "$repo_root"

if [ -n "$repo_root" ]; then
    while IFS= read -r worktree_root; do
        add_root "$worktree_root"
    done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')

    worktree_base="$(dirname "$repo_root")/.hotl-worktrees/$(basename "$repo_root")"
    if [ -d "$worktree_base" ]; then
        for hotl_worktree in "$worktree_base"/*; do
            add_root "$hotl_worktree"
        done
    fi
fi

sort -u "$roots_tmp" | while IFS= read -r root; do
    [ -n "$root" ] || continue
    state_dir="$root/.hotl/state"
    [ -d "$state_dir" ] || continue

    for state_file in "$state_dir"/*.json; do
        [ -f "$state_file" ] || continue
        jq -c \
            --arg state_file "$state_file" \
            --arg run_root "$root" \
            --arg run_id "$run_id" \
            --arg workflow "$workflow" \
            --argjson include_all "$include_all" '
            def status_matches:
              if $include_all == 1 then
                true
              else
                ((.status // "") != "completed" and (.status // "") != "abandoned")
              end;
            def run_matches:
              ($run_id == "" or .run_id == $run_id);
            def workflow_matches:
              ($workflow == "" or .workflow_path == $workflow or .source_workflow_path == $workflow);

            select(status_matches and run_matches and workflow_matches)
            | {
                run_id: .run_id,
                status: .status,
                current_step: .current_step,
                total_steps: .total_steps,
                branch: .branch,
                executor_mode: .executor_mode,
                last_update: .last_update,
                workflow_path: .workflow_path,
                source_workflow_path: .source_workflow_path,
                repo_root: .repo_root,
                execution_root: .execution_root,
                worktree_path: .worktree_path,
                report_path: .report_path,
                state_file: $state_file,
                run_root: $run_root
              }
        ' "$state_file" >> "$matches_tmp" 2>/dev/null || true
    done
done

if [ -s "$matches_tmp" ]; then
    jq -s 'sort_by(.last_update // "") | reverse' "$matches_tmp"
else
    printf '[]\n'
fi
