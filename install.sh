#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="hotl"
INSTALL_DIR="${HOME}/.claude/plugins/${PLUGIN_NAME}"

echo "Installing HOTL plugin to ${INSTALL_DIR}..."

if [ -d "${INSTALL_DIR}" ]; then
    echo "Updating existing installation..."
    cd "${INSTALL_DIR}" && git pull
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
echo "  /hotl:setup        — Generate adapter files for your team's tools"
echo ""
echo "For Codex setup: see docs/README.codex.md"
echo "For Cline setup:  see docs/README.cline.md"
