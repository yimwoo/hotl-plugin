#!/usr/bin/env bash
set -euo pipefail

# HOTL Update Check
# Compares installed version against latest GitHub release.
# Caches result for 24 hours. Silent on failure or when current.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GITHUB_REPO="yimwoo/hotl-plugin"

# ── Read installed version ───────────────────────────────────────────────────

VERSION_FILE="${REPO_DIR}/VERSION"
if [ ! -f "$VERSION_FILE" ]; then
    exit 0
fi
INSTALLED_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
if [ -z "$INSTALLED_VERSION" ]; then
    exit 0
fi

# ── Determine install-specific update command ────────────────────────────────

UPDATE_CMD="bash update.sh"
case "$REPO_DIR" in
    */.claude/plugins/hotl)  UPDATE_CMD="bash ~/.claude/plugins/hotl/update.sh" ;;
    */.codex/hotl)           UPDATE_CMD="bash ~/.codex/hotl/update.sh" ;;
    */.cline/hotl)           UPDATE_CMD="bash ~/.cline/hotl/update.sh" ;;
esac

# ── Cache setup ──────────────────────────────────────────────────────────────

if [ -d "${HOME}/.cache" ]; then
    CACHE_DIR="${HOME}/.cache/hotl"
else
    CACHE_DIR="${HOME}/.hotl/cache"
fi
CACHE_FILE="${CACHE_DIR}/update-check.json"

# ── Check cache freshness (24h TTL) ─────────────────────────────────────────

use_cache() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local checked_at
    checked_at=$(python3 -c "
import json, sys
try:
    data = json.load(open('$CACHE_FILE'))
    print(data.get('checked_at', ''))
except: pass
" 2>/dev/null || true)

    if [ -z "$checked_at" ]; then
        return 1
    fi

    local age_ok
    age_ok=$(python3 -c "
from datetime import datetime, timezone
try:
    checked = datetime.fromisoformat('$checked_at'.replace('Z', '+00:00'))
    age = (datetime.now(timezone.utc) - checked).total_seconds()
    print('yes' if age < 86400 else 'no')
except: print('no')
" 2>/dev/null || echo "no")

    [ "$age_ok" = "yes" ]
}

read_cached_version() {
    python3 -c "
import json
try:
    data = json.load(open('$CACHE_FILE'))
    print(data.get('latest_version', ''))
except: pass
" 2>/dev/null || true
}

# ── Fetch latest version ─────────────────────────────────────────────────────

fetch_from_api() {
    local response
    response=$(curl -sf --max-time 5 \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) || return 1

    local tag_name release_url
    tag_name=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tag_name', ''))
except: pass
" 2>/dev/null) || return 1

    release_url=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('html_url', ''))
except: pass
" 2>/dev/null) || true

    if [ -z "$tag_name" ]; then
        return 1
    fi

    # Normalize: strip leading v
    local version="${tag_name#v}"
    echo "${version}|github-api|${release_url}"
}

fetch_from_git() {
    local tags
    tags=$(git -C "$REPO_DIR" ls-remote --tags origin 2>/dev/null) || return 1

    local latest
    latest=$(echo "$tags" | grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sed 's|refs/tags/v||' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -1) || return 1

    if [ -z "$latest" ]; then
        return 1
    fi

    echo "${latest}|git-remote|https://github.com/${GITHUB_REPO}/releases/tag/v${latest}"
}

# ── Write cache ──────────────────────────────────────────────────────────────

write_cache() {
    local version="$1"
    local source="$2"
    local release_url="$3"
    local now

    now=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "$CACHE_DIR"
    cat > "$CACHE_FILE" <<CEOF
{
  "latest_version": "${version}",
  "checked_at": "${now}",
  "source": "${source}",
  "release_url": "${release_url}"
}
CEOF
}

# ── Compare versions ─────────────────────────────────────────────────────────

is_outdated() {
    local installed="$1"
    local latest="$2"

    if [ "$installed" = "$latest" ]; then
        return 1
    fi

    # Try python3 tuple comparison
    local result
    result=$(python3 -c "
i = tuple(int(x) for x in '$installed'.split('.'))
l = tuple(int(x) for x in '$latest'.split('.'))
print('outdated' if i < l else 'current')
" 2>/dev/null || echo "unknown")

    if [ "$result" = "outdated" ]; then
        return 0
    elif [ "$result" = "current" ]; then
        return 1
    fi

    # Fallback: string differs means potentially outdated
    [ "$installed" != "$latest" ]
}

# ── Main ─────────────────────────────────────────────────────────────────────

LATEST_VERSION=""

if use_cache; then
    LATEST_VERSION="$(read_cached_version)"
fi

if [ -z "$LATEST_VERSION" ]; then
    FETCH_RESULT=""
    FETCH_RESULT=$(fetch_from_api) || FETCH_RESULT=$(fetch_from_git) || true

    if [ -z "$FETCH_RESULT" ]; then
        exit 0
    fi

    LATEST_VERSION="${FETCH_RESULT%%|*}"
    FETCH_SOURCE="$(echo "$FETCH_RESULT" | cut -d'|' -f2)"
    FETCH_URL="$(echo "$FETCH_RESULT" | cut -d'|' -f3)"

    write_cache "$LATEST_VERSION" "$FETCH_SOURCE" "$FETCH_URL"
fi

if is_outdated "$INSTALLED_VERSION" "$LATEST_VERSION"; then
    echo "HOTL update available: ${INSTALLED_VERSION} → ${LATEST_VERSION} — run: ${UPDATE_CMD}"
fi
