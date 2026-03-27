#!/usr/bin/env bash
set -euo pipefail

# HOTL Plugin Update Script
# Updates Claude Code, Codex, and Cline installations if present.

FORCE_CODEX=0
CHECK_ONLY=0
SWITCH_NATIVE_SKILLS=0
STATUS_ONLY=0
CODEX_PLUGIN=0
FORCE_CODEX_PLUGIN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force-codex)
            FORCE_CODEX=1
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        --native-skills)
            SWITCH_NATIVE_SKILLS=1
            ;;
        --status)
            STATUS_ONLY=1
            ;;
        --codex-plugin)
            CODEX_PLUGIN=1
            ;;
        --force-codex-plugin)
            FORCE_CODEX_PLUGIN=1
            CODEX_PLUGIN=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: bash update.sh [--check] [--force-codex] [--native-skills] [--status] [--codex-plugin] [--force-codex-plugin]" >&2
            exit 1
            ;;
    esac
    shift
done

# Resolve script directory (BASH_SOURCE is empty when piped via curl | bash)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR=""
fi

# --check: just report whether an update is available, then exit
if [ "$CHECK_ONLY" -eq 1 ]; then
    if [ -n "${SCRIPT_DIR}" ]; then
        bash "${SCRIPT_DIR}/scripts/check-update.sh" || true
    else
        echo "Error: --check requires running from a local script, not curl | bash." >&2
        exit 1
    fi
    exit 0
fi
CODEX_MARKETPLACE_USER="${HOME}/.agents/plugins/marketplace.json"
CODEX_MARKETPLACE_LOCAL=""
if [ -n "${SCRIPT_DIR}" ]; then
    CODEX_MARKETPLACE_LOCAL="${SCRIPT_DIR}/.agents/plugins/marketplace.json"
fi

# Check if a marketplace JSON file contains a hotl plugin entry.
# Returns 0 (true) if found, 1 (false) otherwise.
# Usage: hotl_in_marketplace "/path/to/marketplace.json"
hotl_in_marketplace() {
    local mkt_path="$1"
    [ -f "${mkt_path}" ] || return 1
    command -v python3 &>/dev/null || return 1
    python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    plugins = data.get('plugins', [])
    sys.exit(0 if any(p.get('name') == 'hotl' for p in plugins) else 1)
except Exception:
    sys.exit(1)
" "${mkt_path}" 2>/dev/null
}

# Extract the version of the hotl entry from a marketplace file.
# Prints the version string or exits non-zero.
hotl_marketplace_version() {
    local mkt_path="$1"
    [ -f "${mkt_path}" ] || return 1
    command -v python3 &>/dev/null || return 1
    python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    for p in data.get('plugins', []):
        if p.get('name') == 'hotl':
            print(p.get('version', 'unknown'))
            sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
" "${mkt_path}" 2>/dev/null
}

is_git_work_tree() {
    local path="$1"
    [ -e "${path}" ] && git -C "${path}" rev-parse --is-inside-work-tree > /dev/null 2>&1
}

current_branch() {
    git -C "$1" branch --show-current 2>/dev/null || true
}

has_local_changes() {
    local path="$1"
    [ -n "$(git -C "${path}" status --short --untracked-files=all 2>/dev/null)" ]
}

resolve_path() {
    local path="$1"
    (
        cd "${path}" > /dev/null 2>&1 && pwd -P
    )
}

backup_codex_install() {
    local path="$1"
    local real_path backup_root timestamp backup_dir

    real_path="$(resolve_path "${path}")"
    backup_root="${HOME}/.codex/backups/hotl"
    timestamp="$(date +"%Y%m%d-%H%M%S")"
    backup_dir="${backup_root}/${timestamp}"

    mkdir -p "${backup_dir}/worktree"
    git -C "${path}" status --short --branch > "${backup_dir}/git-status.txt" 2>/dev/null || true
    rsync -a --exclude '.git' "${real_path}/" "${backup_dir}/worktree/"

    printf '%s\n' "${backup_dir}"
}

refresh_codex_plugin_cache() {
    local source_dir="$1"
    local cache_root="${HOME}/.codex/plugins/cache/codex-plugins/hotl"
    local refreshed=0

    [ -d "${source_dir}" ] || return 0

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

# --status: read-only report of all HOTL install modes, then exit
if [ "$STATUS_ONLY" -eq 1 ]; then
    echo "HOTL Installation Status"
    echo ""

    # Claude Code
    _claude_dir="${HOME}/.claude/plugins/hotl"
    if [ -d "${_claude_dir}" ] && git -C "${_claude_dir}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        _claude_ver="$(cat "${_claude_dir}/VERSION" 2>/dev/null | tr -d '[:space:]')"
        echo "Claude Code:     installed (v${_claude_ver:-unknown}) at ${_claude_dir}"
    else
        echo "Claude Code:     not found"
    fi

    # Codex native-skills
    _codex_native_found=0
    _codex_dir="${HOME}/.codex/hotl"
    if [ -d "${_codex_dir}" ] && git -C "${_codex_dir}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        _codex_rev="$(git -C "${_codex_dir}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
        echo "Codex native:    installed (rev ${_codex_rev}) at ${_codex_dir}"
        _codex_native_found=1
    else
        echo "Codex native:    not found"
    fi

    # Codex plugin (check both user-global and repo-local marketplaces)
    _codex_plugin_found=0
    _codex_plugin_reported=0
    for _codex_mkt in "${CODEX_MARKETPLACE_USER}" "${CODEX_MARKETPLACE_LOCAL}"; do
        if hotl_in_marketplace "${_codex_mkt}"; then
            _plugin_ver="$(hotl_marketplace_version "${_codex_mkt}")"
            if [ "${_codex_plugin_reported}" -eq 0 ]; then
                echo "Codex plugin:    registered (v${_plugin_ver}) in ${_codex_mkt}"
                _codex_plugin_reported=1
            else
                echo "                 also registered (v${_plugin_ver}) in ${_codex_mkt}"
            fi
            _codex_plugin_found=1
        fi
    done
    if [ "${_codex_plugin_found}" -eq 0 ]; then
        echo "Codex plugin:    not found"
    fi

    # Show source checkout health
    _codex_source="${HOME}/.codex/plugins/hotl-source"
    if [ "${_codex_plugin_found}" -eq 1 ]; then
        if [ -d "${_codex_source}/.git" ]; then
            _src_rev="$(git -C "${_codex_source}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
            echo "                 source checkout (rev ${_src_rev}) at ${_codex_source}"
        else
            echo "                 WARNING: source checkout not found at ${_codex_source}"
        fi
    elif [ -d "${_codex_source}/.git" ]; then
        _src_rev="$(git -C "${_codex_source}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
        echo "Codex plugin:    source checkout (rev ${_src_rev}) at ${_codex_source} (no marketplace entry)"
    fi

    # Warn if both Codex modes are present
    if [ "${_codex_native_found}" -eq 1 ] && [ "${_codex_plugin_found}" -eq 1 ]; then
        echo ""
        echo "Warning: both Codex install modes are present. HOTL cannot guarantee which"
        echo "source Codex will use when duplicate skill names exist."
        echo "Recommendation: keep only one active Codex install mode at a time."
    fi

    # Cline
    echo ""
    _cline_dir="${HOME}/.cline/hotl"
    if [ -d "${_cline_dir}" ] && git -C "${_cline_dir}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        _cline_mode_file="${_cline_dir}/.cline-install-mode"
        _cline_mode="legacy-rules"
        [ -f "${_cline_mode_file}" ] && _cline_mode="$(cat "${_cline_mode_file}" | tr -d '[:space:]')"
        echo "Cline:           installed (${_cline_mode}) at ${_cline_dir}"
    else
        echo "Cline:           not found"
    fi

    exit 0
fi

# --codex-plugin: update the plugin source checkout, then exit
if [ "$CODEX_PLUGIN" -eq 1 ]; then
    CODEX_PLUGIN_SOURCE="${HOME}/.codex/plugins/hotl-source"

    if [ ! -d "${CODEX_PLUGIN_SOURCE}/.git" ]; then
        echo "No HOTL plugin source checkout found at ${CODEX_PLUGIN_SOURCE}."
        echo "Run install.sh --codex-plugin first."
        if [ -d "${HOME}/.codex/hotl" ]; then
            echo ""
            echo "Hint: a native-skills install exists at ~/.codex/hotl."
            echo "Use update.sh (without --codex-plugin) to update that instead."
        fi
        exit 1
    fi

    echo "Updating Codex plugin source checkout at ${CODEX_PLUGIN_SOURCE}..."

    if has_local_changes "${CODEX_PLUGIN_SOURCE}"; then
        if [ "${FORCE_CODEX_PLUGIN}" -eq 1 ]; then
            echo "Source checkout has local changes; --force-codex-plugin set, skipping backup."
        else
            _backup_root="${HOME}/.codex/backups/hotl-plugin"
            _timestamp="$(date +"%Y%m%d-%H%M%S")"
            _backup_dir="${_backup_root}/${_timestamp}"
            mkdir -p "${_backup_dir}/worktree"
            git -C "${CODEX_PLUGIN_SOURCE}" status --short --branch > "${_backup_dir}/git-status.txt" 2>/dev/null || true
            rsync -a --exclude '.git' "${CODEX_PLUGIN_SOURCE}/" "${_backup_dir}/worktree/"
            echo "Source checkout has local changes; backed them up to ${_backup_dir}."
        fi
    fi

    git -C "${CODEX_PLUGIN_SOURCE}" fetch origin main
    git -C "${CODEX_PLUGIN_SOURCE}" reset --hard origin/main
    git -C "${CODEX_PLUGIN_SOURCE}" clean -fd

    _ver="$(cat "${CODEX_PLUGIN_SOURCE}/VERSION" 2>/dev/null | tr -d '[:space:]')"
    refresh_codex_plugin_cache "${CODEX_PLUGIN_SOURCE}"
    echo "  Updated to version ${_ver:-unknown}."
    echo ""
    echo "Restart Codex to pick up the updated plugin."
    exit 0
fi

CLAUDE_PLUGIN_DIR="${HOME}/.claude/plugins/hotl"
CLAUDE_CACHE_DIR="${HOME}/.claude/plugins/cache/hotl-plugin/hotl"
CODEX_HOTL_DIR="${HOME}/.codex/hotl"
CLINE_HOTL_DIR="${HOME}/.cline/hotl"
CLINE_RULES_DIR="${HOME}/Documents/Cline/Rules"
CLINE_SCRIPTS_DIR="${HOME}/Documents/Cline/Scripts"
CLINE_SKILLS_DIR="${HOME}/.cline/skills/hotl"
CLINE_MODE_FILE="${CLINE_HOTL_DIR}/.cline-install-mode"

FOUND=0
UPDATED=0
SKIPPED=0

# ── Claude Code ───────────────────────────────────────────────────────────────

if is_git_work_tree "${CLAUDE_PLUGIN_DIR}"; then
    FOUND=$((FOUND + 1))
    echo "Updating Claude Code plugin at ${CLAUDE_PLUGIN_DIR}..."
    git -C "${CLAUDE_PLUGIN_DIR}" pull

    # Refresh plugin cache if it exists
    if [ -d "${CLAUDE_CACHE_DIR}" ]; then
        # Find the cached version directory (e.g., 1.0.0/)
        for CACHE_VER_DIR in "${CLAUDE_CACHE_DIR}"/*/; do
            [ -d "${CACHE_VER_DIR}" ] || continue
            echo "Refreshing plugin cache at ${CACHE_VER_DIR}..."

            # Sync skills
            if [ -d "${CLAUDE_PLUGIN_DIR}/skills" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/skills/" "${CACHE_VER_DIR}skills/"
            fi

            # Sync commands
            if [ -d "${CLAUDE_PLUGIN_DIR}/commands" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/commands/" "${CACHE_VER_DIR}commands/"
            fi

            # Sync hooks
            if [ -d "${CLAUDE_PLUGIN_DIR}/hooks" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/hooks/" "${CACHE_VER_DIR}hooks/"
            fi

            # Sync scripts
            if [ -d "${CLAUDE_PLUGIN_DIR}/scripts" ]; then
                mkdir -p "${CACHE_VER_DIR}scripts/"
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/scripts/" "${CACHE_VER_DIR}scripts/"
            fi

            # Sync runtime
            if [ -d "${CLAUDE_PLUGIN_DIR}/runtime" ]; then
                mkdir -p "${CACHE_VER_DIR}runtime/"
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/runtime/" "${CACHE_VER_DIR}runtime/"
            fi
        done
        echo "  Cache refreshed."
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Claude Code plugin updated."
    echo ""
fi

# ── Codex ─────────────────────────────────────────────────────────────────────

# Update Codex plugin source checkout if it exists
CODEX_PLUGIN_SOURCE="${HOME}/.codex/plugins/hotl-source"
if [ -d "${CODEX_PLUGIN_SOURCE}/.git" ]; then
    FOUND=$((FOUND + 1))
    echo "Updating Codex plugin source checkout at ${CODEX_PLUGIN_SOURCE}..."

    if has_local_changes "${CODEX_PLUGIN_SOURCE}"; then
        if [ "${FORCE_CODEX_PLUGIN}" -eq 1 ]; then
            echo "  Source checkout has local changes; --force-codex-plugin set, skipping backup."
        else
            _backup_root="${HOME}/.codex/backups/hotl-plugin"
            _timestamp="$(date +"%Y%m%d-%H%M%S")"
            _backup_dir="${_backup_root}/${_timestamp}"
            mkdir -p "${_backup_dir}/worktree"
            git -C "${CODEX_PLUGIN_SOURCE}" status --short --branch > "${_backup_dir}/git-status.txt" 2>/dev/null || true
            rsync -a --exclude '.git' "${CODEX_PLUGIN_SOURCE}/" "${_backup_dir}/worktree/"
            echo "  Source checkout has local changes; backed them up to ${_backup_dir}."
        fi
    fi

    git -C "${CODEX_PLUGIN_SOURCE}" fetch origin main
    git -C "${CODEX_PLUGIN_SOURCE}" reset --hard origin/main
    git -C "${CODEX_PLUGIN_SOURCE}" clean -fd

    _ver="$(cat "${CODEX_PLUGIN_SOURCE}/VERSION" 2>/dev/null | tr -d '[:space:]')"
    refresh_codex_plugin_cache "${CODEX_PLUGIN_SOURCE}"
    UPDATED=$((UPDATED + 1))
    echo "  Codex plugin source updated (v${_ver:-unknown})."
    echo ""
elif [ -d "${HOME}/.codex/plugins/hotl" ] && [ ! -d "${CODEX_PLUGIN_SOURCE}/.git" ]; then
    # Old copied-bundle install detected, no source checkout yet
echo "Note: HOTL is installed as a Codex plugin via copied bundle at ~/.codex/plugins/hotl."
    echo "This install is reported but skipped by update.sh."
    echo "The updater can refresh multiple HOTL installs in one run, but it does not"
    echo "update this copied bundle from GitHub directly."
    echo "To enable Codex plugin updates, migrate to the"
    echo "source checkout model by running:"
    echo ""
    echo "  bash install.sh --codex-plugin"
    echo ""
    echo "This will clone to ~/.codex/plugins/hotl-source/ and remove the old bundle."
    echo ""
    SKIPPED=$((SKIPPED + 1))
fi

if is_git_work_tree "${CODEX_HOTL_DIR}"; then
    FOUND=$((FOUND + 1))
    CODEX_BRANCH="$(current_branch "${CODEX_HOTL_DIR}")"
    CODEX_BRANCH_DISPLAY="${CODEX_BRANCH:-detached HEAD}"
    CODEX_DIRTY=0

    if has_local_changes "${CODEX_HOTL_DIR}"; then
        CODEX_DIRTY=1
    fi

    echo "Updating Codex native-skills install at ${CODEX_HOTL_DIR}..."

    if [ "${CODEX_DIRTY}" -eq 1 ] && [ "${FORCE_CODEX}" -eq 0 ]; then
        CODEX_BACKUP_DIR="$(backup_codex_install "${CODEX_HOTL_DIR}")"
        echo "Codex native-skills install has local changes; backed them up to ${CODEX_BACKUP_DIR} before updating."
        echo ""
    elif [ "${CODEX_DIRTY}" -eq 1 ]; then
        echo "Codex native-skills install has local changes; --force-codex set, skipping backup and resetting to origin/main."
        echo ""
    fi

    if [ "${CODEX_BRANCH_DISPLAY}" != "main" ]; then
        echo "Codex install is on branch ${CODEX_BRANCH_DISPLAY}; switching back to stable branch main."
        git -C "${CODEX_HOTL_DIR}" switch main
        echo ""
    fi

    git -C "${CODEX_HOTL_DIR}" fetch origin main
    git -C "${CODEX_HOTL_DIR}" reset --hard origin/main
    git -C "${CODEX_HOTL_DIR}" clean -fd

    if [ -L "${HOME}/.agents/skills/hotl" ]; then
        echo "  Skills symlink intact at ~/.agents/skills/hotl"
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Codex native-skills install updated."
    echo ""
fi

# ── Cline ─────────────────────────────────────────────────────────────────────

if is_git_work_tree "${CLINE_HOTL_DIR}"; then
    FOUND=$((FOUND + 1))
    echo "Updating Cline plugin at ${CLINE_HOTL_DIR}..."
    git -C "${CLINE_HOTL_DIR}" pull

    # Determine Cline install mode
    CLINE_MODE="legacy-rules"
    if [ "${SWITCH_NATIVE_SKILLS}" -eq 1 ]; then
        CLINE_MODE="native-skills"
        echo "${CLINE_MODE}" > "${CLINE_MODE_FILE}"
        echo "  Switching Cline install mode to native-skills."
    elif [ -f "${CLINE_MODE_FILE}" ]; then
        CLINE_MODE="$(cat "${CLINE_MODE_FILE}")"
    fi

    # The 10 native Cline skills and 9 legacy workflow rule names
    NATIVE_SKILLS="brainstorming writing-plans document-review executing-plans subagent-execution tdd systematic-debugging code-review pr-reviewing loop-execution"
    LEGACY_WORKFLOW_RULES="hotl-brainstorming.md hotl-planning.md hotl-execution.md hotl-document-review.md hotl-subagent-execution.md hotl-tdd.md hotl-debugging.md hotl-code-review.md hotl-pr-review.md"

    replace_cline_placeholders() {
        local file="$1"
        sed -i.bak \
            -e "s|__HOTL_HOME__|~/.cline/hotl|g" \
            -e "s|__SCRIPTS_HOME__|~/Documents/Cline/Scripts|g" \
            "${file}"
        rm -f "${file}.bak"
    }

    mkdir -p "${CLINE_RULES_DIR}"

    if [ "${CLINE_MODE}" = "native-skills" ]; then
        echo "  Refreshing Cline in native-skills mode..."

        # Refresh operating model rule only
        if [ -f "${CLINE_HOTL_DIR}/cline/rules/hotl-operating-model.md" ]; then
            cp "${CLINE_HOTL_DIR}/cline/rules/hotl-operating-model.md" "${CLINE_RULES_DIR}/"
            replace_cline_placeholders "${CLINE_RULES_DIR}/hotl-operating-model.md"
        fi

        # Remove legacy workflow rules
        for rule_name in ${LEGACY_WORKFLOW_RULES}; do
            rm -f "${CLINE_RULES_DIR}/${rule_name}"
        done

        # Refresh native skill symlinks
        mkdir -p "${CLINE_SKILLS_DIR}"
        for skill_name in ${NATIVE_SKILLS}; do
            skill_src="${CLINE_HOTL_DIR}/skills/${skill_name}"
            skill_dst="${CLINE_SKILLS_DIR}/${skill_name}"
            if [ -d "${skill_src}" ]; then
                rm -f "${skill_dst}" 2>/dev/null || rm -rf "${skill_dst}" 2>/dev/null || true
                ln -s "${skill_src}" "${skill_dst}"
            fi
        done
        echo "  1 rule + 10 native skills refreshed."
    else
        echo "  Refreshing Cline in legacy-rules mode..."

        # Remove native skills if they exist
        if [ -d "${CLINE_SKILLS_DIR}" ]; then
            rm -rf "${CLINE_SKILLS_DIR}"
        fi

        # Refresh all rules
        if [ -d "${CLINE_HOTL_DIR}/cline/rules" ]; then
            for rule_file in "${CLINE_HOTL_DIR}"/cline/rules/hotl-*.md; do
                [ -f "${rule_file}" ] || continue
                cp "${rule_file}" "${CLINE_RULES_DIR}/"
            done
            # Replace placeholders
            for rule_file in "${CLINE_RULES_DIR}"/hotl-*.md; do
                [ -f "${rule_file}" ] || continue
                replace_cline_placeholders "${rule_file}"
            done
            RULE_COUNT=$(find "${CLINE_RULES_DIR}" -maxdepth 1 -name 'hotl-*.md' | wc -l | tr -d ' ')
            echo "  ${RULE_COUNT} rule files updated."
        fi
    fi

    # Refresh global scripts
    if [ -d "${CLINE_HOTL_DIR}/scripts" ]; then
        mkdir -p "${CLINE_SCRIPTS_DIR}"
        for script_file in "${CLINE_HOTL_DIR}"/scripts/*.sh; do
            [ -f "${script_file}" ] || continue
            cp "${script_file}" "${CLINE_SCRIPTS_DIR}/"
            chmod +x "${CLINE_SCRIPTS_DIR}/$(basename "${script_file}")"
        done
        echo "  Scripts refreshed at ${CLINE_SCRIPTS_DIR}."
    fi

    # Refresh runtime (hotl-rt)
    if [ -f "${CLINE_HOTL_DIR}/runtime/hotl-rt" ]; then
        mkdir -p "${CLINE_SCRIPTS_DIR}"
        cp "${CLINE_HOTL_DIR}/runtime/hotl-rt" "${CLINE_SCRIPTS_DIR}/hotl-rt"
        chmod +x "${CLINE_SCRIPTS_DIR}/hotl-rt"
        echo "  Runtime (hotl-rt) refreshed."
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Cline plugin updated (mode: ${CLINE_MODE})."
    echo ""
fi

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$FOUND" -eq 0 ]; then
    echo "No HOTL installations found."
    echo ""
    echo "Install for Claude Code:  bash install.sh"
    echo "Install for Codex:        see docs/README.codex.md"
    echo "Install for Cline:        bash install-cline.sh"
    exit 1
fi

echo "Done. ${UPDATED} installation(s) updated in this run."
if [ "$SKIPPED" -gt 0 ]; then
    echo "${SKIPPED} installation(s) skipped."
fi
echo "Restart your Claude Code session or start a new Cline task to use the latest version."
