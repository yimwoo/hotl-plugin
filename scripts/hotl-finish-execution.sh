#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_TOOL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOTL_RT="$REPO_TOOL_ROOT/runtime/hotl-rt"

usage() {
    cat <<'USAGE' >&2
usage: hotl-finish-execution.sh --run-id <run-id> --mode <keep|merge|publish|discard>
       [--target-branch <branch>] [--remote <name>] [--create-pr]
       [--pr-url <url>] [--notes <text>] [--confirm discard]
       --effect-action-id <id> --idempotency-key <key>   # required for publish

Finish a HOTL execution branch/worktree and record the disposition in runtime state.
USAGE
    exit 1
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required but not found." >&2
        exit 1
    fi
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
    local repo_root="$1"
    git -C "$repo_root" status --porcelain=v1 --untracked-files=all | while IFS= read -r line; do
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

ensure_clean_non_hotl_checkout() {
    local repo_root="$1"
    local dirty
    dirty="$(collect_non_hotl_dirty_paths "$repo_root" || true)"
    if [ -n "$dirty" ]; then
        echo "ERROR: Non-HOTL dirty files block finishing operations that switch or merge branches." >&2
        printf '%s\n' "$dirty" >&2
        exit 1
    fi
}

first_existing_branch() {
    local repo_root="$1"
    shift
    local name
    for name in "$@"; do
        [ -z "$name" ] && continue
        if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$name"; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

locate_run_root() {
    local repo_root="$1"
    local run_id="$2"
    local candidate

    for candidate in "$PWD" "$repo_root"; do
        if [ -f "$candidate/.hotl/state/${run_id}.json" ]; then
            echo "$candidate"
            return 0
        fi
    done

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if [ -f "$candidate/.hotl/state/${run_id}.json" ]; then
            echo "$candidate"
            return 0
        fi
    done < <(git -C "$repo_root" worktree list --porcelain | awk '/^worktree /{print substr($0,10)}')

    return 1
}

run_runtime_summary() {
    local run_root="$1"
    local run_id="$2"
    (
        cd "$run_root"
        "$HOTL_RT" summary "$run_id" --json
    )
}

run_runtime_finish() {
    local run_root="$1"
    shift
    (
        cd "$run_root"
        "$HOTL_RT" finish "$@"
    )
}

run_runtime_action() {
    local run_root="$1"
    shift
    (
        cd "$run_root"
        "$HOTL_RT" action "$@"
    )
}

validate_effect_action() {
    local run_root="$1"
    local run_id="$2"
    local action_id="$3"
    local key="$4"
    local expected_kind="$5"
    local expected_target="$6"
    local state_file="$run_root/.hotl/state/${run_id}.json"

    jq -e \
        --arg id "$action_id" \
        --arg key "$key" \
        --arg kind "$expected_kind" \
        --arg target "$expected_target" \
        '.external_actions[]? | select(
            .id==$id and .idempotency_key==$key and .kind==$kind and .target==$target and
            .status=="approved" and .effect_required==true and .effect.status=="not_started"
        )' "$state_file" >/dev/null || {
        echo "ERROR: Approved action does not match the bounded finish effect or is not ready to begin." >&2
        return 1
    }
}

preserve_run_artifacts_to_repo_root() {
    local run_root="$1"
    local repo_root="$2"
    local run_id="$3"

    if [ "$run_root" = "$repo_root" ]; then
        return 0
    fi

    mkdir -p "$repo_root/.hotl/state" "$repo_root/.hotl/reports"
    cp "$run_root/.hotl/state/${run_id}.json" "$repo_root/.hotl/state/${run_id}.json"
    cp "$run_root/.hotl/reports/${run_id}.md" "$repo_root/.hotl/reports/${run_id}.md"

    local repo_report="$repo_root/.hotl/reports/${run_id}.md"
    local repo_state="$repo_root/.hotl/state/${run_id}.json"
    jq --arg report_path "$repo_report" '.report_path = $report_path' "$repo_state" > "${repo_state}.tmp"
    mv "${repo_state}.tmp" "$repo_state"
}

remove_worktree_if_present() {
    local repo_root="$1"
    local worktree_path="$2"
    [ -n "$worktree_path" ] || return 0
    [ -d "$worktree_path" ] || return 0
    git -C "$repo_root" worktree remove --force "$worktree_path"
}

branch_exists() {
    local repo_root="$1"
    local branch="$2"
    git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"
}

run_id=""
mode=""
target_branch=""
remote="origin"
create_pr=0
pr_url=""
notes=""
confirm=""
effect_action_id=""
idempotency_key=""

while [ $# -gt 0 ]; do
    case "$1" in
        --run-id)
            run_id="$2"
            shift 2
            ;;
        --mode)
            mode="$2"
            shift 2
            ;;
        --target-branch)
            target_branch="$2"
            shift 2
            ;;
        --remote)
            remote="$2"
            shift 2
            ;;
        --create-pr)
            create_pr=1
            shift
            ;;
        --pr-url)
            pr_url="$2"
            shift 2
            ;;
        --notes)
            notes="$2"
            shift 2
            ;;
        --confirm)
            confirm="$2"
            shift 2
            ;;
        --effect-action-id)
            effect_action_id="$2"
            shift 2
            ;;
        --idempotency-key)
            idempotency_key="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$run_id" ] || usage
[ -n "$mode" ] || usage

case "$mode" in
    keep|merge|publish|discard) ;;
    *) usage ;;
esac

if { [ -n "$effect_action_id" ] && [ -z "$idempotency_key" ]; } || \
   { [ -z "$effect_action_id" ] && [ -n "$idempotency_key" ]; }; then
    echo "ERROR: --effect-action-id and --idempotency-key must be provided together." >&2
    exit 1
fi
if [ -n "$effect_action_id" ]; then
    case "$mode" in
        merge|publish) ;;
        *) echo "ERROR: effect lifecycle options are supported only for merge or publish." >&2; exit 1 ;;
    esac
fi
if [ "$mode" = publish ] && [ -z "$effect_action_id" ]; then
    echo "ERROR: Publish requires --effect-action-id and --idempotency-key for its governed external effect." >&2
    exit 1
fi

require_jq

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || {
    echo "ERROR: hotl-finish-execution.sh must run inside a git repository." >&2
    exit 1
}
repo_root="$(cd "$repo_root" && pwd -P)"

run_root="$(locate_run_root "$repo_root" "$run_id" || true)"
[ -n "$run_root" ] || {
    echo "ERROR: Could not locate HOTL run $run_id in the repo checkout or its worktrees." >&2
    exit 1
}
run_root="$(cd "$run_root" && pwd -P)"

summary_json="$(run_runtime_summary "$run_root" "$run_id")"

status="$(printf '%s\n' "$summary_json" | jq -r '.status')"
branch="$(printf '%s\n' "$summary_json" | jq -r '.branch')"
worktree_path="$(printf '%s\n' "$summary_json" | jq -r '.worktree_path // empty')"
source_branch="$(printf '%s\n' "$summary_json" | jq -r '.source_branch // empty')"
existing_finish="$(printf '%s\n' "$summary_json" | jq -r '.finish.disposition // empty')"

case "$mode" in
    merge|publish)
        { [ "$status" = "ready_to_finish" ] || [ "$status" = "completed" ]; } || {
            echo "ERROR: Mode '$mode' requires a completed run. Current status: $status" >&2
            exit 1
        }
        ;;
    keep|discard)
        case "$status" in
            ready_to_finish|completed|blocked) ;;
            *)
                echo "ERROR: Mode '$mode' requires a finalized run. Current status: $status" >&2
                exit 1
                ;;
        esac
        ;;
esac

if [ -n "$existing_finish" ]; then
    echo "ERROR: Run $run_id already has a recorded finish outcome: $existing_finish" >&2
    exit 1
fi

if [ -z "$target_branch" ]; then
    target_branch="$(first_existing_branch "$repo_root" "$source_branch" main master || true)"
fi

if [ -n "$effect_action_id" ]; then
    case "$mode" in
        publish)
            effect_target="publish $branch to $remote"
            if [ "$create_pr" -eq 1 ]; then
                [ -n "$target_branch" ] || {
                    echo "ERROR: Could not determine a PR base branch. Pass --target-branch explicitly." >&2
                    exit 1
                }
                effect_target="$effect_target and create PR against $target_branch"
            fi
            validate_effect_action "$run_root" "$run_id" "$effect_action_id" "$idempotency_key" external_write "$effect_target"
            ;;
        merge)
            [ -n "$target_branch" ] || {
                echo "ERROR: Could not determine a merge target branch. Pass --target-branch explicitly." >&2
                exit 1
            }
            effect_target="merge $branch into $target_branch"
            validate_effect_action "$run_root" "$run_id" "$effect_action_id" "$idempotency_key" production_change "$effect_target"
            ;;
    esac
fi

artifacts_preserved_at=""
branch_action=""
worktree_action=""
final_summary_root="$run_root"

case "$mode" in
    keep)
        branch_action="kept"
        if [ -n "$worktree_path" ]; then
            worktree_action="kept"
        fi
        run_runtime_finish "$run_root" kept --run-id "$run_id" \
            --branch-action "$branch_action" \
            --worktree-action "$worktree_action" \
            --notes "${notes:-Kept execution branch/worktree for later.}" >/dev/null
        ;;

    publish)
        git -C "$repo_root" rev-parse --verify "$branch" >/dev/null 2>&1 || {
            echo "ERROR: Execution branch not found locally: $branch" >&2
            exit 1
        }

        if [ -n "$effect_action_id" ]; then
            run_runtime_action "$run_root" begin "$effect_action_id" \
                --idempotency-key "$idempotency_key" --run-id "$run_id" >/dev/null
        fi

        git -C "$repo_root" push -u "$remote" "$branch"

        if [ "$create_pr" -eq 1 ]; then
            command -v gh >/dev/null 2>&1 || {
                echo 'ERROR: --create-pr requires the GitHub CLI (gh).' >&2
                exit 1
            }
            [ -n "$target_branch" ] || {
                echo "ERROR: Could not determine a PR base branch. Pass --target-branch explicitly." >&2
                exit 1
            }
            if ! pr_url="$(gh pr create --base "$target_branch" --head "$branch" --fill)"; then
                echo "ERROR: Pull request creation failed; the branch was pushed but no successful finish disposition was recorded." >&2
                exit 1
            fi
            [ -n "$pr_url" ] || {
                echo "ERROR: Pull request creation returned no URL; no successful finish disposition was recorded." >&2
                exit 1
            }
        fi

        if [ -n "$effect_action_id" ]; then
            effect_evidence="git-push:${remote}/${branch}"
            [ -z "$pr_url" ] || effect_evidence="pr:${pr_url}"
            run_runtime_action "$run_root" complete "$effect_action_id" succeeded \
                --evidence-ref "$effect_evidence" --run-id "$run_id" >/dev/null
        fi

        branch_action="kept"
        if [ -n "$worktree_path" ]; then
            worktree_action="kept"
        fi
        run_runtime_finish "$run_root" published --run-id "$run_id" \
            --target-branch "$target_branch" \
            --remote "$remote" \
            --pr-url "$pr_url" \
            --branch-action "$branch_action" \
            --worktree-action "$worktree_action" \
            --notes "${notes:-Published execution branch for review.}" >/dev/null
        ;;

    merge)
        [ -n "$target_branch" ] || {
            echo "ERROR: Could not determine a merge target branch. Pass --target-branch explicitly." >&2
            exit 1
        }
        [ "$target_branch" != "$branch" ] || {
            echo "ERROR: Execution branch and target branch are the same ($branch). Use keep/publish, or finish manually on the shared branch." >&2
            exit 1
        }
        branch_exists "$repo_root" "$target_branch" || {
            echo "ERROR: Target branch not found locally: $target_branch" >&2
            exit 1
        }
        ensure_clean_non_hotl_checkout "$repo_root"
        if [ -n "$effect_action_id" ]; then
            run_runtime_action "$run_root" begin "$effect_action_id" \
                --idempotency-key "$idempotency_key" --run-id "$run_id" >/dev/null
        fi
        cd "$repo_root"
        git -C "$repo_root" switch "$target_branch" >/dev/null
        if ! git -C "$repo_root" merge --no-ff --no-edit "$branch"; then
            git -C "$repo_root" merge --abort >/dev/null 2>&1 || true
            echo "ERROR: Merge failed. HOTL left the execution branch/worktree intact." >&2
            exit 1
        fi

        if [ -n "$effect_action_id" ]; then
            merge_head="$(git -C "$repo_root" rev-parse HEAD)"
            run_runtime_action "$run_root" complete "$effect_action_id" succeeded \
                --evidence-ref "git-merge:${target_branch}@${merge_head}" --run-id "$run_id" >/dev/null
        fi

        artifacts_preserved_at="$repo_root/.hotl"
        branch_action="merged-into-${target_branch}"
        if [ -n "$worktree_path" ]; then
            worktree_action="removed"
        fi
        run_runtime_finish "$run_root" merged --run-id "$run_id" \
            --target-branch "$target_branch" \
            --branch-action "$branch_action" \
            --worktree-action "$worktree_action" \
            --artifacts-preserved-at "$artifacts_preserved_at" \
            --notes "${notes:-Merged execution branch back into $target_branch.}" >/dev/null

        if [ -n "$worktree_path" ]; then
            preserve_run_artifacts_to_repo_root "$run_root" "$repo_root" "$run_id"
            final_summary_root="$repo_root"
            remove_worktree_if_present "$repo_root" "$worktree_path"
        fi
        if branch_exists "$repo_root" "$branch"; then
            git -C "$repo_root" branch -d "$branch" >/dev/null
        fi
        ;;

    discard)
        [ "$confirm" = "discard" ] || {
            echo "ERROR: Discard is destructive. Re-run with --confirm discard." >&2
            exit 1
        }

        if [ -z "$worktree_path" ] && { [ -z "$source_branch" ] || [ "$source_branch" = "$branch" ]; }; then
            echo "ERROR: Cannot safely auto-discard a shared-checkout run on the current/source branch." >&2
            echo "       Switch branches and clean up manually, or execute in an isolated worktree next time." >&2
            exit 1
        fi

        ensure_clean_non_hotl_checkout "$repo_root"
        if [ -z "$worktree_path" ]; then
            [ -n "$source_branch" ] || {
                echo "ERROR: Shared-checkout discard requires a source branch to switch back to." >&2
                exit 1
            }
            branch_exists "$repo_root" "$source_branch" || {
                echo "ERROR: Source branch not found locally: $source_branch" >&2
                exit 1
            }
            git -C "$repo_root" switch "$source_branch" >/dev/null
        fi

        artifacts_preserved_at="$repo_root/.hotl"
        branch_action="deleted"
        if [ -n "$worktree_path" ]; then
            worktree_action="removed"
        fi
        run_runtime_finish "$run_root" discarded --run-id "$run_id" \
            --branch-action "$branch_action" \
            --worktree-action "$worktree_action" \
            --artifacts-preserved-at "$artifacts_preserved_at" \
            --notes "${notes:-Discarded execution branch/worktree after review.}" >/dev/null

        if [ -n "$worktree_path" ]; then
            preserve_run_artifacts_to_repo_root "$run_root" "$repo_root" "$run_id"
            final_summary_root="$repo_root"
            remove_worktree_if_present "$repo_root" "$worktree_path"
        else
            preserve_run_artifacts_to_repo_root "$run_root" "$repo_root" "$run_id"
            final_summary_root="$repo_root"
        fi
        if branch_exists "$repo_root" "$branch"; then
            git -C "$repo_root" branch -D "$branch" >/dev/null
        fi
        ;;
esac

run_runtime_summary "$final_summary_root" "$run_id"
