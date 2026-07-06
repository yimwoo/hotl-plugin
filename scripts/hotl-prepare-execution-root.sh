#!/usr/bin/env bash
set -euo pipefail

workflow=""
executor_mode="loop"

if [ $# -lt 1 ]; then
    echo "usage: hotl-prepare-execution-root.sh <workflow-file> [--executor-mode <mode>]" >&2
    exit 1
fi

workflow="$1"
shift

while [ $# -gt 0 ]; do
    case "$1" in
        --executor-mode)
            executor_mode="$2"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not found." >&2
    exit 1
fi

abspath_existing() {
    local path="$1"
    local dir
    dir=$(cd "$(dirname "$path")" && pwd -P)
    echo "${dir}/$(basename "$path")"
}

slug_from_workflow() {
    local file="$1"
    local base
    base=$(basename "$file" .md)
    case "$base" in
        hotl-workflow-*)
            echo "${base#hotl-workflow-}"
            ;;
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*-workflow)
            echo "$base" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.*)-workflow$/\1/'
            ;;
        *-workflow)
            echo "${base%-workflow}"
            ;;
        *)
            echo "$base"
            ;;
    esac
}

sanitize_for_path() {
    printf '%s' "$1" | sed 's#[^A-Za-z0-9._-]#-#g'
}

frontmatter_value() {
    local frontmatter="$1"
    local key="$2"
    printf '%s\n' "$frontmatter" | { grep -i "^${key}:" || true; } | head -1 | sed "s/^[[:space:]]*${key}:[[:space:]]*//I"
}

frontmatter_token() {
    printf '%s' "$1" | sed 's/[[:space:]]#.*$//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
}

is_hotl_transient_path() {
    case "$1" in
        hotl-workflow-*.md|docs/plans/*-workflow.md|docs/designs/*.md|docs/plans/*-design.md|docs/plans/*-plan.md|.hotl|.hotl/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

collect_non_hotl_dirty_paths() {
    git status --porcelain=v1 --untracked-files=all | while IFS= read -r line; do
        [ -z "$line" ] && continue
        local path="${line:3}"
        case "$path" in
            *" -> "*)
                path="${path##* -> }"
                ;;
        esac
        if ! is_hotl_transient_path "$path"; then
            printf '%s\n' "$path"
        fi
    done | sort -u
}

json_string_or_null() {
    local value="${1:-}"
    if [ -n "$value" ]; then
        jq -Rn --arg value "$value" '$value'
    else
        echo "null"
    fi
}

workflow_abs=$(abspath_existing "$workflow")
if [ ! -f "$workflow_abs" ]; then
    echo "ERROR: Workflow file not found: $workflow" >&2
    exit 1
fi

frontmatter=$(sed -n '/^---$/,/^---$/p' "$workflow_abs" | sed '1d;$d')
slug=$(slug_from_workflow "$workflow_abs")
branch=$(frontmatter_value "$frontmatter" "branch")
branch_was_set=1
if [ -z "$branch" ]; then
    branch_was_set=0
    branch="hotl/${slug}"
fi
worktree_enabled=$(frontmatter_token "$(frontmatter_value "$frontmatter" "worktree")")
worktree_was_set=1
if [ -z "$worktree_enabled" ]; then
    worktree_was_set=0
    worktree_enabled="true"
fi
dirty_worktree_mode=$(frontmatter_value "$frontmatter" "dirty_worktree")

case "$worktree_enabled" in
    true|false|host) ;;
    *)
        echo "ERROR: Invalid worktree mode '$worktree_enabled'." >&2
        echo "       Expected one of: true, false, host." >&2
        exit 1
        ;;
esac

repo_root=""
execution_root=""
worktree_path=""
workflow_target="$workflow_abs"
source_branch=""
source_head=""

cleanup_worktree=0
cleanup_worktree_path=""

cleanup_on_error() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$cleanup_worktree" -eq 1 ] && [ -n "$cleanup_worktree_path" ] && [ -n "$repo_root" ]; then
        git -C "$repo_root" worktree remove --force "$cleanup_worktree_path" >/dev/null 2>&1 || true
    fi
    exit "$exit_code"
}
trap cleanup_on_error EXIT

if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    execution_root=$(pwd -P)
    jq -n \
        --arg branch "$branch" \
        --arg executor_mode "$executor_mode" \
        --arg execution_root "$execution_root" \
        --arg workflow_path "$workflow_abs" \
        --arg source_workflow_path "$workflow_abs" \
        '{
            branch: $branch,
            executor_mode: $executor_mode,
            repo_root: $execution_root,
            execution_root: $execution_root,
            workflow_path: $workflow_path,
            source_workflow_path: $source_workflow_path,
            source_branch: null,
            source_head: null,
            worktree_path: null
        }'
    trap - EXIT
    exit 0
fi

repo_root=$(cd "$repo_root" && pwd -P)
execution_root="$repo_root"
source_branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
source_head="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"

if ! git -C "$repo_root" rev-parse HEAD >/dev/null 2>&1; then
    jq -n \
        --arg branch "$branch" \
        --arg executor_mode "$executor_mode" \
        --arg repo_root "$repo_root" \
        --arg workflow_path "$workflow_abs" \
        --arg source_workflow_path "$workflow_abs" \
        --argjson source_branch "$(json_string_or_null "$source_branch")" \
        --argjson source_head "$(json_string_or_null "$source_head")" \
        '{
            branch: $branch,
            executor_mode: $executor_mode,
            repo_root: $repo_root,
            execution_root: $repo_root,
            workflow_path: $workflow_path,
            source_workflow_path: $source_workflow_path,
            source_branch: $source_branch,
            source_head: $source_head,
            worktree_path: null
        }'
    trap - EXIT
    exit 0
fi

git_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-dir)"
git_common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)"
is_linked_worktree=0
if [ "$git_dir" != "$git_common_dir" ]; then
    is_linked_worktree=1
fi

if [ "$worktree_was_set" -eq 0 ] && [ "$branch_was_set" -eq 0 ] && [ "$is_linked_worktree" -eq 1 ] && [ -n "$source_branch" ]; then
    worktree_enabled="host"
    branch="$source_branch"
fi

workflow_rel="${workflow_abs#"${repo_root}"/}"
if [ "$workflow_rel" = "$workflow_abs" ]; then
    echo "ERROR: Workflow file must live inside the git repo: $workflow_abs" >&2
    exit 1
fi

dirty_paths="$(collect_non_hotl_dirty_paths || true)"
if [ -n "$dirty_paths" ] && [ "$dirty_worktree_mode" != "allow" ]; then
    echo "ERROR: Non-HOTL dirty files block execution." >&2
    printf '%s\n' "$dirty_paths" >&2
    exit 1
fi

if [ "$worktree_enabled" = "host" ]; then
    if [ -z "$source_branch" ]; then
        echo "ERROR: worktree: host requires the current checkout to be on a named branch." >&2
        exit 1
    fi
    case "$source_branch" in
        main|master)
            echo "ERROR: worktree: host cannot execute directly on protected branch '$source_branch'." >&2
            echo "       Use worktree: true for an isolated HOTL worktree, or switch to a feature branch first." >&2
            exit 1
            ;;
    esac
    if [ "$branch_was_set" -eq 1 ] && [ "$branch" != "$source_branch" ]; then
        echo "ERROR: worktree: host uses the current checkout branch, but branch is '$branch'." >&2
        echo "       Current branch is '$source_branch'. Remove branch:, set it to '$source_branch', or use worktree: true." >&2
        exit 1
    fi
    branch="$source_branch"
    execution_root="$repo_root"
    workflow_target="$workflow_abs"
elif [ "$worktree_enabled" = "true" ]; then
    branch_safe=$(sanitize_for_path "$branch")
    worktree_base="$(dirname "$repo_root")/.hotl-worktrees/$(basename "$repo_root")"
    worktree_path="${worktree_base}/${branch_safe}"

    if [ -n "$source_branch" ] && [ "$branch" = "$source_branch" ]; then
        echo "ERROR: Execution branch '$branch' is already checked out in the current checkout." >&2
        echo "       To continue on this exact branch, set 'branch: $source_branch' with 'worktree: false' or 'worktree: host'." >&2
        echo "       Otherwise choose a different execution branch or omit branch: to use HOTL's default isolated branch." >&2
        exit 1
    fi

    if [ -e "$worktree_path" ]; then
        echo "ERROR: Worktree path already exists: $worktree_path" >&2
        echo "       Automatic reuse/recreate prompts are not implemented by the helper yet." >&2
        echo "       Remove or rename the existing worktree path, or choose a different execution branch, then re-run." >&2
        exit 1
    fi

    mkdir -p "$worktree_base"
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$repo_root" worktree add "$worktree_path" "$branch" >/dev/null 2>&1
    else
        git -C "$repo_root" worktree add -b "$branch" "$worktree_path" HEAD >/dev/null 2>&1
    fi
    cleanup_worktree=1
    cleanup_worktree_path="$worktree_path"

    execution_root="$worktree_path"
    workflow_target="${execution_root}/${workflow_rel}"
    mkdir -p "$(dirname "$workflow_target")"
    cp "$workflow_abs" "$workflow_target"
else
    current_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
    if [ "$current_branch" != "$branch" ]; then
        if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
            echo "ERROR: Branch already exists: $branch." >&2
            echo "       Automatic reuse/recreate prompts are not implemented by the helper yet." >&2
            echo "       Switch to that branch manually or pick a different execution branch, then re-run." >&2
            exit 1
        fi
        git -C "$repo_root" switch -c "$branch" >/dev/null 2>&1
    fi
fi

jq -n \
    --arg branch "$branch" \
    --arg executor_mode "$executor_mode" \
    --arg repo_root "$repo_root" \
    --arg execution_root "$execution_root" \
    --arg workflow_path "$workflow_target" \
    --arg source_workflow_path "$workflow_abs" \
    --argjson source_branch "$(json_string_or_null "$source_branch")" \
    --argjson source_head "$(json_string_or_null "$source_head")" \
    --argjson worktree_path "$(json_string_or_null "$worktree_path")" \
    '{
        branch: $branch,
        executor_mode: $executor_mode,
        repo_root: $repo_root,
        execution_root: $execution_root,
        workflow_path: $workflow_path,
        source_workflow_path: $source_workflow_path,
        source_branch: $source_branch,
        source_head: $source_head,
        worktree_path: $worktree_path
    }'

cleanup_worktree=0
trap - EXIT
