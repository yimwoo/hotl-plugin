# Some Hand-Authored Architecture Doc

This fixture has NO YAML frontmatter and no HOTL marker. After the Phase 1.6 opt-in change lands, the lint must skip this file with a clear message and exit 0.

## Background

A human author put this file in `docs/designs/` (or wherever) without using the brainstorming skill. It is not HOTL-managed.

## Some Section

The doc deliberately omits Intent / Verification / Governance Contract sections. The pre-Phase-1.6 lint would hard-fail with FAIL-level errors for missing contract sections; the post-Phase-1.6 lint must SKIP cleanly.

## Another Section

Plain prose continues. No HOTL ceremony.
