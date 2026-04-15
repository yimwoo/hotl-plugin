# Sample Design — Slice 2 Lint Fixture

Minimal HOTL-contract design doc used by Slice 2's Group E (document-lint
acceptance of both `-design.md` and `-plan.md` suffixes) and Group H (legacy
`-design.md` files remain accepted by every consumer).

Not real planning content — this file exists only to give `document-lint.sh`
something with the required structural fields to chew on.

---

## 1. Intent Contract

- intent: validate that `document-lint.sh` classifies this file as a HOTL
  design doc and accepts it with exit 0 under both `-design.md` and
  `-plan.md` filenames.
- constraints: keep the fixture byte-for-byte identical between filename
  renames; the lint outcome must depend only on the classification branch.
- success_criteria: `document-lint.sh` exits 0 for both filenames.
- risk_level: low

## 2. Verification Contract

- Run `bash scripts/document-lint.sh <fixture-copy-with-design-suffix>` and
  confirm exit 0.
- Run `bash scripts/document-lint.sh <fixture-copy-with-plan-suffix>` and
  confirm exit 0.

## 3. Governance Contract

- approval_gates: none (fixture is test-only, not a real plan).
- rollback: delete the fixture; no production code depends on it.
