# Hand-authored design doc that happens to use the dated convention

This fixture is dated and ends with `-design.md`, so it matches the conventional HOTL filename pattern. But it has NO YAML frontmatter and no HOTL marker.

After the Phase 1.6 opt-in change, the lint must NOT classify this as a HOTL design doc just because the filename pattern matches. It must SKIP and exit 0.

## Why this fixture matters

Without this regression guard, a future change could silently re-enable filename-based classification, and HOTL would once again hard-fail human-authored design docs that happen to follow the dated pattern.

## Plain prose

The doc deliberately omits Intent / Verification / Governance Contract sections to prove that the SKIP path runs BEFORE the existing contract-section FAIL checks.
