#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
host="${HOTL_HOST:-auto}"

if [ "${1:-}" = --host ]; then
    [ $# -ge 3 ] || { echo "usage: route.sh [--host auto|codex|claude|generic] <driver-command> [args]" >&2; exit 1; }
    host="$2"
    shift 2
fi

[ $# -gt 0 ] || { echo "usage: route.sh [--host auto|codex|claude|generic] <driver-command> [args]" >&2; exit 1; }

if [ "$host" = auto ]; then
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || [ "${HOTL_ACTIVE_HOST:-}" = claude ]; then
        host=claude
    elif [ -n "${CODEX_HOME:-}" ] || [ "${HOTL_ACTIVE_HOST:-}" = codex ]; then
        host=codex
    else
        host=generic
    fi
fi

case "$host" in
    codex|claude|generic) exec "$SCRIPT_DIR/$host.sh" "$@" ;;
    *) echo "ERROR: host must be auto, codex, claude, or generic" >&2; exit 1 ;;
esac
