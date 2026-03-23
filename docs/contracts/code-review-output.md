# Code Review Output Contract

This contract defines the canonical output schema for HOTL code reviews (`code-review` skill and `code-reviewer` agent). It specifies required sections, severity vocabulary, deduplication rules, and clean-review requirements. All platforms must emit every section. Presentation is platform-specific; semantics are not.

## Required Sections

Every code review artifact must contain these 6 sections, in order, regardless of the verdict.

### 1. Scope

- Files reviewed
- Base reference: workflow file, design doc, or branch diff used as the review baseline
- Review type: checkpoint, final, follow-up, or direct
- Verification evidence: commands run (tests, linters, compilers), artifacts inspected, manual checks performed — brief, just enough to show what informed the review

### 2. Reviewed Dimensions

List which review lenses were applied. Common dimensions:

- Plan alignment (when a workflow is provided)
- Code quality and design
- Security and reliability
- Performance and boundary conditions
- Removal and simplification
- HOTL governance

State which dimensions were included and which were skipped (with reason).

### 3. Findings

Findings fall into two categories based on whether the platform emits native annotations:

**Platform-annotated findings** (those also emitted as platform-native annotations, e.g., inline comments):
- Summarized as a grouped one-liner only. Do not restate Why/Fix — details live in the annotations.
- 1–5 findings: `"3 platform-native findings emitted: security (1), reliability (1), validation (1). See annotations for details."`
- 6+ findings: `"7 platform-native findings across security, reliability, validation, and docs. See annotations."`

**Non-annotated findings** (governance gaps, workflow issues, broad architectural concerns, or anything without a specific file:line anchor):
- Full format in the section body:

```
- [SEVERITY]: file/path:line — description
  Why: [why this matters]
  Fix: [expected remediation direction]
```

For scope-level findings without a precise file:line, provide the narrowest evidence available and explain why a specific location cannot be given.

**Workflow and governance findings** always appear in this section as non-annotated findings — they are not suitable for platform-native annotations.

### 4. What Was Not Covered

Explicit gaps in the review:
- Dimensions that could not be assessed (e.g., "No test files in diff — test quality not assessed")
- Types of analysis not performed (e.g., "No load testing", "No manual playtest", "No browser compatibility check")
- Scope limitations (e.g., "Large PR — only sampled 3 of 12 changed files in detail")

### 5. Residual Risks

Known risks that remain even if all findings are addressed:
- Inherent review limits (e.g., "Static analysis only — runtime concurrency behavior unverified")
- Environmental gaps (e.g., "Not a git repo — reviewed full tree statically instead of branch diff")
- Deployment concerns (e.g., "Migration not tested against production-scale data")

### 6. Verdict

- **READY** — safe to merge
- **READY WITH WARNINGS** — safe to merge but warnings should be addressed soon
- **NOT READY** — blocking issues must be resolved before merge

For checkpoint reviews, use: **PROCEED** / **PROCEED WITH WARNINGS** / **HOLD**

The verdict must include one-sentence reasoning. NOT READY and HOLD verdicts must list every blocking issue.

## Severity Vocabulary

The only severity system in user-facing text:

| Severity | Meaning |
|---|---|
| **BLOCK** | Must fix before merge. Security issues, failing tests, broken logic. |
| **WARN** | Should fix soon. Not a merge blocker, but a real concern. |
| **NOTE** | Consider for future improvement. Style, minor suggestions. |

No other severity labels (P1/P2, priority numbers, confidence scores) may appear in user-facing prose. Platform-native annotation metadata (e.g., `priority`, `confidence` fields in directives) is permitted as machine-readable data but must not surface in titles or summaries.

## Deduplication Rule

When a platform emits native annotations for localized findings:
- The Findings section must not restate those findings verbatim
- Instead, use the grouped one-liner format described above
- This prevents the same issue from appearing twice in the user's view

## Clean-Review Requirement

When a dimension has no findings, it must still state:
- What was checked within that dimension
- What was not covered
- Residual risks specific to that dimension

This ensures reviewers cannot silently skip dimensions.

## Platform Rendering

This contract defines semantics. Platform-specific rendering profiles define how findings are surfaced natively (e.g., inline comments, annotation directives). See platform documentation for rendering details.
