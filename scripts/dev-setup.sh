#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK_FILE="${REPO_ROOT}/.git/hooks/pre-push"

echo "Installing pre-push hook..."

cat > "${HOOK_FILE}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v bats &>/dev/null; then
    echo "ERROR: bats is not installed. Run: brew install bats-core"
    exit 1
fi

echo "Running smoke tests before push..."
bats "${REPO_ROOT}/test/smoke.bats"
EOF

chmod +x "${HOOK_FILE}"

echo "Pre-push hook installed at ${HOOK_FILE}"
echo "Smoke tests will run automatically before every git push."
echo ""
echo "To run tests manually: bats test/smoke.bats"
