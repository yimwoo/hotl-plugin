#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="hotl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_PLUGIN_CACHE_ROOT="${HOME}/.codex/plugins/cache/codex-plugins/hotl"

refresh_codex_plugin_cache() {
    local source_dir="$1"
    local cache_root="${CODEX_PLUGIN_CACHE_ROOT}"
    local refreshed=0

    if [ ! -d "${source_dir}" ]; then
        return 0
    fi

    if [ -d "${cache_root}" ]; then
        for cache_dir in "${cache_root}"/*/; do
            [ -d "${cache_dir}" ] || continue
            echo "Refreshing Codex plugin cache at ${cache_dir}..."
            mkdir -p "${cache_dir}"
            rsync -a --delete --exclude '.git' "${source_dir}/" "${cache_dir}"
            refreshed=1
        done
    fi

    if [ "${refreshed}" -eq 0 ]; then
        local seed_dir="${cache_root}/local"
        echo "Seeding Codex plugin cache at ${seed_dir}..."
        mkdir -p "${seed_dir}"
        rsync -a --delete --exclude '.git' "${source_dir}/" "${seed_dir}/"
        refreshed=1
    fi

    if [ "${refreshed}" -eq 1 ]; then
        echo "  Codex plugin cache refreshed."
    fi
}

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

    GIT_REPO_URL="https://github.com/yimwoo/hotl-plugin.git"

    if [ "$LOCAL" = true ]; then
        # Local/contributor mode: point marketplace at the current checkout
        MARKETPLACE_DIR="${HOTL_LOCAL_MARKETPLACE_DIR:-${SCRIPT_DIR}/.agents/plugins}"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        PLUGIN_SOURCE_PATH="${SCRIPT_DIR}"
        MARKETPLACE_PLUGIN_PATH="${SCRIPT_DIR}"
        echo "Registering HOTL in repo-local Codex marketplace: ${MARKETPLACE_FILE}"
        echo "Plugin source: current checkout at ${SCRIPT_DIR}"
    else
        # User-global mode: clone source checkout
        MARKETPLACE_DIR="${HOME}/.agents/plugins"
        MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"
        PLUGIN_SOURCE_PATH="${HOME}/.codex/plugins/hotl-source"
        # Codex resolves paths relative to $HOME; use ./ prefix
        MARKETPLACE_PLUGIN_PATH="./.codex/plugins/hotl-source"

        if [ -d "${PLUGIN_SOURCE_PATH}/.git" ]; then
            echo "Updating existing source checkout at ${PLUGIN_SOURCE_PATH}..."
            git -C "${PLUGIN_SOURCE_PATH}" fetch origin main
            git -C "${PLUGIN_SOURCE_PATH}" reset --hard origin/main
        else
            echo "Cloning HOTL to ${PLUGIN_SOURCE_PATH}..."
            mkdir -p "$(dirname "${PLUGIN_SOURCE_PATH}")"
            git clone "${GIT_REPO_URL}" "${PLUGIN_SOURCE_PATH}"
        fi

        # Migration: remove old copied-bundle install if present
        OLD_BUNDLE="${HOME}/.codex/plugins/hotl"
        if [ -d "${OLD_BUNDLE}" ] && [ ! -d "${OLD_BUNDLE}/.git" ]; then
            echo ""
            echo "Migrating from copied-bundle plugin install at ${OLD_BUNDLE}"
            echo "to source checkout at ${PLUGIN_SOURCE_PATH}..."
            rm -rf "${OLD_BUNDLE}"
            echo "Old bundle removed."
        fi
    fi

    PLUGIN_MANIFEST="${PLUGIN_SOURCE_PATH}/.codex-plugin/plugin.json"
    if [ ! -f "$PLUGIN_MANIFEST" ]; then
        echo "Error: ${PLUGIN_MANIFEST} not found." >&2
        exit 1
    fi

    mkdir -p "$MARKETPLACE_DIR"

    python3 -c "
import json, sys, os

manifest_path = sys.argv[1]
dest_path = sys.argv[2]
plugin_source_path = sys.argv[3]
owner_name = os.environ.get('USER', 'unknown')

with open(manifest_path) as f:
    manifest = json.load(f)

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

if manifest.get('interface'):
    hotl_entry['interface'] = manifest['interface']

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
" "$PLUGIN_MANIFEST" "$MARKETPLACE_FILE" "$MARKETPLACE_PLUGIN_PATH"

    refresh_codex_plugin_cache "${PLUGIN_SOURCE_PATH}"

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
    echo "  2. Codex CLI: run 'codex', open '/plugins', switch to Local Plugins,"
    echo "     open HOTL, and select Install plugin"
    echo "     If HOTL is installed but disabled, press Space to enable it"
    echo "  3. Codex app: open Plugins, switch to Local Plugins, and install HOTL"
    echo ""
    echo "To update later, run: update.sh (updates all installs) or update.sh --codex-plugin (plugin only)"
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
echo "  /hotl:write-plan   — Create docs/plans/YYYY-MM-DD-<slug>-workflow.md"
echo "  /hotl:loop         — Execute workflow file with auto-approve"
echo "  /hotl:execute-plan — Linear execution with checkpoints"
echo "  /hotl:subagent-execute — Same-session delegated execution with controller-owned verification"
echo "  /hotl:setup        — Generate adapter files for your team's tools"
echo ""
echo "For Codex setup: see docs/README.codex.md"
echo "For Cline setup:  see docs/README.cline.md"
