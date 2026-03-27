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
            echo "  --codex-plugin   Install HOTL as a local Codex plugin and register it"
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
    if ! command -v python3 &>/dev/null; then
        echo "Error: python3 is required for Codex plugin install." >&2
        exit 1
    fi

    if [ "$LOCAL" = true ]; then
        INSTALL_ROOT="${SCRIPT_DIR}"
        MARKETPLACE_DIR="${INSTALL_ROOT}/.agents/plugins"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        PLUGIN_ROOT="${INSTALL_ROOT}/.codex/plugins/${PLUGIN_NAME}"
        PLUGIN_SOURCE_PATH="./.codex/plugins/${PLUGIN_NAME}"
        echo "Installing HOTL in repo-local Codex plugin directory: ${PLUGIN_ROOT}"
        echo "Registering HOTL in repo-local Codex marketplace: ${MARKETPLACE_FILE}"
    else
        INSTALL_ROOT="${HOME}"
        MARKETPLACE_DIR="${HOME}/.agents/plugins"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        PLUGIN_ROOT="${HOME}/.codex/plugins/${PLUGIN_NAME}"
        PLUGIN_SOURCE_PATH="./.codex/plugins/${PLUGIN_NAME}"
        echo "Installing HOTL in user-global Codex plugin directory: ${PLUGIN_ROOT}"
        echo "Registering HOTL in user-global Codex marketplace: ${MARKETPLACE_FILE}"
    fi

    PLUGIN_MANIFEST="${SCRIPT_DIR}/.codex-plugin/plugin.json"
    if [ ! -f "$PLUGIN_MANIFEST" ]; then
        echo "Error: ${PLUGIN_MANIFEST} not found." >&2
        echo "Are you running install.sh from the hotl-plugin repository?" >&2
        exit 1
    fi

    mkdir -p "$MARKETPLACE_DIR" "$(dirname "${PLUGIN_ROOT}")"
    rsync -a --delete \
        --exclude '.git' \
        --exclude '.codex/plugins' \
        --exclude '.agents/plugins' \
        "${SCRIPT_DIR}/" "${PLUGIN_ROOT}/"

    python3 -c "
import json, sys, os

manifest_path = sys.argv[1]
dest_path = sys.argv[2]
plugin_source_path = sys.argv[3]
owner_name = os.environ.get('USER', 'unknown')

with open(manifest_path) as f:
    manifest = json.load(f)

manifest.setdefault('interface', {
    'displayName': 'HOTL',
    'shortDescription': 'Human-on-the-Loop workflows for structured AI development',
    'longDescription': 'Use HOTL to brainstorm, plan, execute, review, and verify software changes with explicit human-on-the-loop contracts.',
    'developerName': owner_name,
    'category': 'Productivity',
    'capabilities': ['Interactive', 'Read', 'Write'],
    'defaultPrompt': 'Plan, execute, review, and verify coding tasks with HOTL workflows'
})

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
    f.write('\n')

hotl_entry = {
    'name': manifest['name'],
    'description': manifest['description'],
    'version': manifest['version'],
    'author': manifest.get('author', {'name': owner_name}),
    'source': {
        'source': 'local',
        'path': plugin_source_path,
    },
    'policy': {
        'installation': 'AVAILABLE',
        'authentication': 'ON_INSTALL',
    },
    'category': 'Productivity',
}

# Read or create the destination marketplace file
if os.path.exists(dest_path):
    with open(dest_path) as f:
        dest = json.load(f)
else:
    dest = {
        'name': 'codex-plugins',
        'description': 'Codex plugin marketplace',
        'owner': {'name': owner_name},
        'interface': {'displayName': 'Local Plugins'},
        'plugins': []
    }

dest.setdefault('name', 'codex-plugins')
dest.setdefault('description', 'Codex plugin marketplace')
dest.setdefault('owner', {'name': owner_name})
dest.setdefault('interface', {'displayName': 'Local Plugins'})
dest.setdefault('plugins', [])

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
" "$PLUGIN_ROOT/.codex-plugin/plugin.json" "$MARKETPLACE_FILE" "$PLUGIN_SOURCE_PATH"

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
    echo "HOTL Codex plugin prepared. Next steps:"
    echo "  1. Restart Codex to discover the plugin"
    echo "  2. Open the Codex plugin directory, switch to Local Plugins,"
    echo "     and click Add to Codex for HOTL"
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
