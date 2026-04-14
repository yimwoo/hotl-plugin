#!/usr/bin/env bash
# hotl-config-resolve.sh — command proxy for hotl-config.sh
#
# Locates hotl-config.sh under the plugin install tree using the documented
# six-location order (mirroring the document-lint.sh resolution pattern), then
# execs it with all received arguments forwarded unchanged.
#
# This helper exists so callers (notably runtime/hotl-rt and any out-of-repo
# consumer) do not need to know where the plugin is installed. In-repo callers
# may invoke scripts/hotl-config.sh directly and skip the resolver.
#
# Test-only override:
#   HOTL_INSTALL_OVERRIDE=<dir>   takes priority over the six default paths.
#                                 Expected layout: <dir>/hotl/scripts/hotl-config.sh
#
# Per docs/designs/slice-1-config-reader-plan.md §2.1 Group B2,
# stdout, stderr, and exit code pass through from the located target.

set -euo pipefail

# In-repo path (when this script lives in scripts/ alongside hotl-config.sh).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

candidates=()

# 1. Test-only override — checked first when set.
if [ -n "${HOTL_INSTALL_OVERRIDE:-}" ]; then
    candidates+=("$HOTL_INSTALL_OVERRIDE/hotl/scripts/hotl-config.sh")
fi

# 2. Sibling in the same scripts/ directory (in-repo or any flat install).
candidates+=("$SCRIPT_DIR/hotl-config.sh")

# 3. The six documented install locations — same shape as document-lint.sh.
candidates+=(
    "$HOME/.codex/hotl/scripts/hotl-config.sh"
    "$HOME/.codex/plugins/hotl-source/scripts/hotl-config.sh"
    "$HOME/.cline/hotl/scripts/hotl-config.sh"
    "$HOME/.claude/plugins/hotl/scripts/hotl-config.sh"
)

# Codex plugin cache fallback uses a glob — expand if any match.
for cached in "$HOME"/.codex/plugins/cache/codex-plugins/hotl/*/scripts/hotl-config.sh; do
    [ -e "$cached" ] && candidates+=("$cached")
done

for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
        exec bash "$candidate" "$@"
    fi
done

echo "ERROR: hotl-config.sh not found in any known install location" >&2
echo "Searched:" >&2
for candidate in "${candidates[@]}"; do
    echo "  - $candidate" >&2
done
exit 1
