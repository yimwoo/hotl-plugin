# PR Review Output Contract

This contract defines the canonical output schema for the `hotl:pr-reviewing` skill. It specifies required sections, verdict logic, and finding severities. All platforms must emit every section. Presentation is platform-specific; semantics are not.

## Required Sections

Every review artifact must contain these 9 sections, in order, regardless of the overall verdict. Even a BLOCK review must include the full decision record.

### 1. PR Metadata

- Repository (org/repo)
- PR/MR number
- Title
- Author
- Source branch → target branch
- Platform and mode (GitHub full, GitLab local-only, local-only fallback)
- Review date

### 2. Description Verdict

- Verdict: PASS | WARN | BLOCK
- Findings: quality of the PR description (explains why, what, how)
- Summary: one sentence

### 3. Ticket Alignment Verdict

- Verdict: PASS | WARN | BLOCK | N/A
- Findings: does the PR address the linked ticket's requirements? Scope creep or gap?
- N/A when no ticket is linked or accessible
- Summary: one sentence

### 4. Code Changes Verdict

- Verdict: PASS | WARN | BLOCK
- Findings: correctness, edge cases, readability, design, with file:line references where available
- Summary: one sentence

### 5. Code Scan Verdict

- Verdict: PASS | WARN | BLOCK
- Linter results: per-linter status (N issues | clean | not configured)
- AI scan results: security and quality findings with file:line references
- Summary: one sentence

### 6. Unit Tests Verdict

- Verdict: PASS | WARN | BLOCK
- Test results: total, passed, failed, skipped
- Coverage: per-file coverage status or "Coverage tooling not available"
- Test quality: AI assessment of test meaningfulness
- Summary: one sentence

### 7. Overall Verdict

- APPROVE | REQUEST_CHANGES | COMMENT
- Derived from dimension verdicts using the verdict logic below

### 8. Consolidated Findings

All findings from all dimensions, collected in one list. Each finding includes:

- Severity: BLOCK | WARN | NOTE
- Dimension: which review dimension produced it
- File and line: where applicable
- Summary: what the finding is

### 9. Verification Notes

- What was verified and how (tests run, linters executed, APIs called)
- What could not be verified and why (missing tooling, network restrictions, auth failures)
- Any limitations of the review (partial diff, large PR truncation, etc.)

**Per-dimension clean-review requirement:** When a dimension verdict is PASS with no findings, that dimension's section must include:
- What was checked within that dimension
- What was not covered (e.g., "no test files in diff — test quality not assessed")
- Residual risks and verification gaps (e.g., "security scan limited to static analysis of changed files")

## Verdict Logic

The overall verdict is derived from **dimension-level verdicts**, not individual findings:

| Condition | Overall Verdict |
|---|---|
| Any dimension has a BLOCK verdict | **REQUEST_CHANGES** |
| No BLOCKs, >2 dimensions have WARN verdict | **COMMENT** |
| No BLOCKs, ≤2 dimensions have WARN verdict | **APPROVE** |

There are 5 dimension verdicts: Description, Ticket Alignment, Code Changes, Code Scan, Unit Tests.

## Dimension Verdicts vs Individual Findings

These are distinct concepts and must not be conflated:

- A **dimension verdict** (PASS, WARN, BLOCK, N/A) summarizes the section as a whole.
- **Individual findings** within a section may have mixed severities (e.g., one BLOCK and two NOTEs).
- The dimension verdict is **not required** to equal the maximum finding severity, but it must be justified by the section summary.
- The **overall verdict** is derived from dimension verdicts, not from individual findings.

Example: A section may contain one WARN finding and two NOTE findings but still receive a PASS dimension verdict if the WARN is minor and the section as a whole is sound.

## Finding Severities

| Severity | Meaning |
|---|---|
| **BLOCK** | Must fix before merge. Security issues, failing tests, broken logic. |
| **WARN** | Should fix. Not a merge blocker, but a real concern. |
| **NOTE** | Consider for future improvement. Style, minor suggestions. |

## Rules

- All 9 sections are always present, even when the overall verdict is REQUEST_CHANGES.
- Findings include file:line when available.
- N/A is a valid verdict for Ticket Alignment when no ticket is linked.
- The contract defines semantics. Presentation (tables, inline comments, plain text) is determined by the platform, not this contract.
