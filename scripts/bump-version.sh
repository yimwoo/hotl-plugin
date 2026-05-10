#!/usr/bin/env bash
#
# bump-version.sh - check, audit, or update HOTL version fields.
#
# Usage:
#   scripts/bump-version.sh --check
#   scripts/bump-version.sh --audit
#   scripts/bump-version.sh <new-version>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v jq >/dev/null || die "jq not found in PATH"
[ -f "$CONFIG" ] || die ".version-bump.json not found"

jq_path_for_field() {
    local field="$1"
    echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./'
}

read_json_field() {
    local file="$1"
    local field="$2"
    local jq_path

    jq_path="$(jq_path_for_field "$field")"
    jq -r "$jq_path" "$file"
}

write_json_field() {
    local file="$1"
    local field="$2"
    local value="$3"
    local jq_path
    local tmp

    jq_path="$(jq_path_for_field "$field")"
    tmp="${file}.tmp"
    jq "$jq_path = \"$value\"" "$file" > "$tmp"
    mv "$tmp" "$file"
}

declared_files() {
    jq -r '.files[] | [.path, (.type // "json"), (.field // "")] | @tsv' "$CONFIG"
}

audit_excludes() {
    jq -r '.audit.exclude[]?' "$CONFIG"
}

read_declared_version() {
    local path="$1"
    local type="$2"
    local field="$3"
    local fullpath="$REPO_ROOT/$path"

    [ -f "$fullpath" ] || return 2

    case "$type" in
        text)
            tr -d '[:space:]' < "$fullpath"
            ;;
        json)
            [ -n "$field" ] || die "missing field for JSON file $path"
            read_json_field "$fullpath" "$field"
            ;;
        *)
            die "unknown version file type '$type' for $path"
            ;;
    esac
}

write_declared_version() {
    local path="$1"
    local type="$2"
    local field="$3"
    local version="$4"
    local fullpath="$REPO_ROOT/$path"

    [ -f "$fullpath" ] || die "declared version file missing: $path"

    case "$type" in
        text)
            printf '%s\n' "$version" > "$fullpath"
            ;;
        json)
            [ -n "$field" ] || die "missing field for JSON file $path"
            write_json_field "$fullpath" "$field" "$version"
            ;;
        *)
            die "unknown version file type '$type' for $path"
            ;;
    esac
}

cmd_check() {
    local has_drift=0
    local versions=()
    local path type field version

    echo "Version check:"
    echo

    while IFS=$'\t' read -r path type field; do
        if ! version="$(read_declared_version "$path" "$type" "$field")"; then
            printf '  %-45s  MISSING\n' "$path"
            has_drift=1
            continue
        fi

        printf '  %-45s  %s\n' "$path" "$version"
        versions+=("$version")
    done < <(declared_files)

    echo

    if [ "${#versions[@]}" -eq 0 ]; then
        echo "No declared version files."
        return 1
    fi

    unique_count="$(printf '%s\n' "${versions[@]}" | sort -u | wc -l | tr -d ' ')"
    if [ "$unique_count" -gt 1 ]; then
        echo "DRIFT DETECTED - versions are not in sync:"
        printf '%s\n' "${versions[@]}" | sort | uniq -c | sort -rn | sed 's/^/  /'
        has_drift=1
    else
        echo "All declared files are in sync at ${versions[0]}"
    fi

    return "$has_drift"
}

cmd_audit() {
    local current_version
    local exclude_args=()
    local pattern
    local declared_paths=()
    local path type field
    local found_undeclared=0

    cmd_check
    echo

    current_version="$(
        while IFS=$'\t' read -r path type field; do
            read_declared_version "$path" "$type" "$field" 2>/dev/null || true
        done < <(declared_files) | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
    )"
    [ -n "$current_version" ] || die "could not determine current version"

    while IFS= read -r pattern; do
        [ -n "$pattern" ] || continue
        exclude_args+=("--exclude=$pattern" "--exclude-dir=$pattern")
    done < <(audit_excludes)
    exclude_args+=("--exclude-dir=.git" "--exclude-dir=node_modules" "--binary-files=without-match")

    while IFS=$'\t' read -r path type field; do
        declared_paths+=("$path")
    done < <(declared_files)

    echo "Audit: scanning repo for version string '$current_version'..."
    echo

    while IFS= read -r match; do
        local rel_path
        local is_declared=0

        rel_path="${match%%:*}"
        rel_path="${rel_path#"$REPO_ROOT"/}"
        for path in "${declared_paths[@]}"; do
            if [ "$rel_path" = "$path" ]; then
                is_declared=1
                break
            fi
        done

        if [ "$is_declared" -eq 0 ]; then
            if [ "$found_undeclared" -eq 0 ]; then
                echo "UNDECLARED files containing '$current_version':"
                found_undeclared=1
            fi
            echo "  $match"
        fi
    done < <(grep -rn "${exclude_args[@]}" -F "$current_version" "$REPO_ROOT" 2>/dev/null || true)

    if [ "$found_undeclared" -eq 0 ]; then
        echo "No undeclared files contain the version string."
    else
        echo
        echo "Review these files. Add them to .version-bump.json if they should be bumped."
        return 1
    fi
}

cmd_bump() {
    local new_version="$1"
    local path type field old_version

    if ! echo "$new_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$'; then
        die "'$new_version' does not look like a version (expected X.Y.Z)"
    fi

    echo "Bumping declared version files to $new_version..."
    echo

    while IFS=$'\t' read -r path type field; do
        old_version="$(read_declared_version "$path" "$type" "$field")"
        write_declared_version "$path" "$type" "$field" "$new_version"
        printf '  %-45s  %s -> %s\n' "$path" "$old_version" "$new_version"
    done < <(declared_files)

    echo
    cmd_check
}

case "${1:-}" in
    --check)
        cmd_check
        ;;
    --audit)
        cmd_audit
        ;;
    --help|-h|"")
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    --*)
        die "unknown flag '$1'"
        ;;
    *)
        cmd_bump "$1"
        ;;
esac
