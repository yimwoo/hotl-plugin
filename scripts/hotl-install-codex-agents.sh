#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOTL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${HOTL_ROOT}/adapters/codex-agents"
TARGET_ROOT="$(pwd -P)"
FORCE=0

usage() {
    echo "usage: hotl-install-codex-agents.sh [--target-root <path>] [--force]" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --target-root)
            [ $# -ge 2 ] || { usage; exit 1; }
            TARGET_ROOT="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: HOTL Codex agent templates not found at ${SOURCE_DIR}" >&2
    exit 1
fi

mkdir -p "${TARGET_ROOT}/.codex/agents"

installed=0
skipped=0

for source_file in "$SOURCE_DIR"/*.toml; do
    [ -f "$source_file" ] || continue

    dest_file="${TARGET_ROOT}/.codex/agents/$(basename "$source_file")"
    if [ -f "$dest_file" ] && [ "$FORCE" -ne 1 ]; then
        echo "SKIP: ${dest_file} already exists"
        skipped=$((skipped + 1))
        continue
    fi

    cp "$source_file" "$dest_file"
    echo "INSTALLED: ${dest_file}"
    installed=$((installed + 1))
done

if [ "$installed" -eq 0 ] && [ "$skipped" -eq 0 ]; then
    echo "ERROR: no HOTL Codex agent templates found in ${SOURCE_DIR}" >&2
    exit 1
fi

echo "Codex agent templates complete: ${installed} installed, ${skipped} skipped"
