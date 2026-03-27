#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="hotl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── flag parsing ─────────────────────────────────────────────────────────────

CODEX_PLUGIN=false
LOCAL=false

while [ $# -gt 0 ]; do
    case "$1" in
        --codex-plugin) CODEX_PLUGIN=true; shift ;;
        --local)        LOCAL=true; shift ;;
        --help|-h)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no flags)       Install HOTL as a Claude Code plugin (default)"
            echo "  --codex-plugin   Register HOTL in the Codex plugin marketplace"
            echo "  --local          With --codex-plugin: write to repo-local marketplace"
            echo "                   instead of user-global (~/.agents/plugins/marketplace.json)"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run install.sh --help for usage." >&2
            exit 1
            ;;
    esac
done

# ── Codex plugin install ─────────────────────────────────────────────────────

if [ "$CODEX_PLUGIN" = true ]; then
    if [ "$LOCAL" = true ]; then
        MARKETPLACE_DIR=".agents/plugins"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        echo "Registering HOTL in repo-local Codex marketplace: ${MARKETPLACE_FILE}"
    else
        MARKETPLACE_DIR="${HOME}/.agents/plugins"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        echo "Registering HOTL in user-global Codex marketplace: ${MARKETPLACE_FILE}"
    fi

    SOURCE_FILE="${SCRIPT_DIR}/.codex-plugin/marketplace.json"
    if [ ! -f "$SOURCE_FILE" ]; then
        echo "Error: ${SOURCE_FILE} not found." >&2
        echo "Are you running install.sh from the hotl-plugin repository?" >&2
        exit 1
    fi

    # Extract the HOTL plugin entry from the source marketplace template
    if ! command -v python3 &>/dev/null; then
        echo "Error: python3 is required for Codex plugin install." >&2
        exit 1
    fi

    mkdir -p "$MARKETPLACE_DIR"

    python3 -c "
import json, sys, os

source_path = sys.argv[1]
dest_path = sys.argv[2]

# Read the HOTL plugin entry from the source template
with open(source_path) as f:
    source = json.load(f)
hotl_entry = source['plugins'][0]

# Read or create the destination marketplace file
if os.path.exists(dest_path):
    with open(dest_path) as f:
        dest = json.load(f)
else:
    dest = {
        'name': 'codex-plugins',
        'description': 'Codex plugin marketplace',
        'owner': {'name': os.environ.get('USER', 'unknown')},
        'plugins': []
    }

# Merge: update existing hotl entry or append
updated = False
for i, plugin in enumerate(dest['plugins']):
    if plugin.get('name') == 'hotl':
        dest['plugins'][i] = hotl_entry
        updated = True
        break
if not updated:
    dest['plugins'].append(hotl_entry)

with open(dest_path, 'w') as f:
    json.dump(dest, f, indent=2)
    f.write('\n')

action = 'Updated' if updated else 'Added'
print(f'{action} HOTL plugin entry (version {hotl_entry[\"version\"]})')
" "$SOURCE_FILE" "$MARKETPLACE_FILE"

    # Warn if an existing native-skills install is detected
    if [ -L "${HOME}/.agents/skills/hotl" ] || [ -d "${HOME}/.codex/hotl" ]; then
        echo ""
        echo "Note: an existing native-skills install was detected at"
        [ -L "${HOME}/.agents/skills/hotl" ] && echo "  ~/.agents/skills/hotl"
        [ -d "${HOME}/.codex/hotl" ] && echo "  ~/.codex/hotl"
        echo ""
        echo "HOTL plugin install does not remove the native-skills install automatically."
        echo "If both Codex install modes remain present, Codex may discover more than one"
        echo "HOTL source and the active source is not guaranteed by HOTL."
        echo ""
        echo "Recommended:"
        echo "  - To use plugin mode as your primary Codex install, remove"
        echo "    ~/.agents/skills/hotl after confirming the plugin works."
        echo "  - To keep the fastest local development loop, continue using"
        echo "    native skills instead of plugin mode."
    fi

    echo ""
    echo "HOTL Codex plugin registered. Next steps:"
    echo "  1. Restart Codex to discover the plugin"
    echo "  2. Install/enable HOTL from the Codex plugin list"
    echo ""
    echo "To update later, use Codex's plugin refresh flow."
    echo "For native skills install (dev/iteration), see docs/README.codex.md"
    exit 0
fi

# ── default Claude Code install ──────────────────────────────────────────────

INSTALL_DIR="${HOME}/.claude/plugins/${PLUGIN_NAME}"

echo "Installing HOTL plugin to ${INSTALL_DIR}..."

if [ -d "${INSTALL_DIR}" ]; then
    echo "Existing installation found. Running unified updater..."
    bash "${INSTALL_DIR}/update.sh"
else
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    cp -r "${SCRIPT_DIR}" "${INSTALL_DIR}"
fi

# Ensure session-start hook is executable
chmod +x "${INSTALL_DIR}/hooks/session-start" 2>/dev/null || true
chmod +x "${INSTALL_DIR}/hooks/run-hook.cmd" 2>/dev/null || true

# Guide user to configure Claude Code settings
SETTINGS_FILE="${HOME}/.claude/settings.json"
if [ -f "${SETTINGS_FILE}" ]; then
    if grep -q "\"${PLUGIN_NAME}\"" "${SETTINGS_FILE}" 2>/dev/null; then
        echo "Plugin already configured in ${SETTINGS_FILE}"
    else
        echo ""
        echo "Add the following to ${SETTINGS_FILE} under 'plugins':"
        echo "  \"${PLUGIN_NAME}\": \"${INSTALL_DIR}\""
    fi
else
    echo ""
    echo "Claude Code settings not found at ${SETTINGS_FILE}"
    echo "Manually add plugin path to your Claude Code settings: ${INSTALL_DIR}"
fi

echo ""
echo "HOTL plugin installed. Start a new Claude Code session to activate."
echo ""
echo "Available commands:"
echo "  /hotl:brainstorm   — Design a feature with HOTL contracts"
echo "  /hotl:write-plan   — Create a hotl-workflow-<slug>.md plan"
echo "  /hotl:loop         — Execute workflow file with auto-approve"
echo "  /hotl:execute-plan — Linear execution with checkpoints"
echo "  /hotl:subagent-execute — Same-session delegated execution with controller-owned verification"
echo "  /hotl:setup        — Generate adapter files for your team's tools"
echo ""
echo "For Codex setup: see docs/README.codex.md"
echo "For Cline setup:  see docs/README.cline.md"
