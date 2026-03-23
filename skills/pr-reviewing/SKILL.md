---
name: pr-reviewing
description: Review a PR across multiple dimensions — description, code changes, code scan, unit tests — using parallel subagents. Supports GitHub, GitLab, and enterprise platforms.
---

# HOTL PR Review

## Overview

Review a pull request end-to-end across 4 dimensions (description/ticket, code changes, code scan, unit tests) using parallel subagents. Produces a structured verdict report and optionally posts line-level comments on GitHub.

**Announce:** "Starting PR review. Detecting platform and fetching PR data..."

## Output Contract

This skill produces a structured review report. The canonical schema is defined in
`docs/contracts/pr-review-output.md`. All platforms must emit every section in that
contract. Platform-specific rendering (tables, inline comments, etc.) is handled by
platform docs, not this skill.

Key rules from the contract:
- All 9 sections always present, even on BLOCK
- Dimension verdicts summarize sections; individual findings may have mixed severities
- Overall verdict derived from dimension verdicts, not individual findings
- The contract is mandatory even when platform-native findings are emitted before it

## Step 1: Platform Detection & PR Fetching

### Resolve the PR

1. If the user provided a PR URL → parse org/repo and PR number from it
2. If no URL → detect from current branch:
   - Try `gh pr view --json number,title,body,baseRefName,headRefName,url` → if succeeds, use GitHub mode
   - Try `glab mr view` → if succeeds, use GitLab mode
   - If both fail → use **local-only mode** (git diff against base branch)

### Platform Modes

| Platform | CLI | Mode | Capabilities |
|---|---|---|---|
| GitHub (public) | `gh` | full | Local report + post review comments |
| GitLab | `glab` | local-only | Local report only |
| Enterprise/VPN | none | local-only | Local report only (git diff fallback) |

### Fetch PR Data

**Full mode (GitHub):**
```bash
gh pr view <number> --json title,body,baseRefName,headRefName,changedFiles,additions,deletions
gh pr diff <number>
```

**GitLab mode:**
```bash
glab mr view <number>
glab mr diff <number>
```

**Local-only fallback:**
```bash
git log --oneline main..HEAD
git diff main...HEAD
git diff --name-only main...HEAD
```

### Ticket Extraction

1. Scan the PR description for ticket references:
   - Patterns: `JIRA-1234`, `ABC-123`, `#123`, or full URLs (Jira, GitHub Issues, GitLab Issues, Linear)
2. Attempt to fetch ticket content:
   - GitHub Issues: `gh issue view <number> --json title,body`
   - Jira URL: `WebFetch` the ticket page (user must be authenticated/on VPN)
   - GitLab Issues: `glab issue view <number>`
   - Generic URL: `WebFetch` and extract text
3. If fetch fails → skip gracefully, note "Ticket not accessible" in report

## Step 2: Dispatch Parallel Subagents

Dispatch **4 subagents simultaneously** using the Agent tool. Pass each subagent the PR data collected in Step 1.

### Subagent A: Description & Ticket Review

```
Prompt template:
---
You are reviewing a PR's description and ticket alignment.

**PR Title:** {title}
**PR Description:**
{body}

**Linked Ticket (if available):**
{ticket_content or "No ticket linked/accessible"}

## Review Checklist

1. **Description quality:**
   - Does it explain WHY this change is needed?
   - Does it explain WHAT changed?
   - Does it explain HOW it works (if non-obvious)?
   - Is it clear enough for a reviewer unfamiliar with the context?

2. **Ticket alignment (if ticket available):**
   - Does the PR address the ticket's requirements?
   - Are all acceptance criteria covered?
   - Is there scope creep (PR does more than ticket asks)?
   - Is there scope gap (ticket asks for more than PR delivers)?

## Output Format

Return EXACTLY this format (two separate blocks — one for description, one for ticket):
```
DIMENSION: Description
VERDICT: PASS | WARN | BLOCK
FINDINGS:
- [BLOCK|WARN|NOTE]: [finding description]
SUMMARY: [one sentence]

DIMENSION: Ticket Alignment
VERDICT: PASS | WARN | BLOCK | N/A
FINDINGS:
- [BLOCK|WARN|NOTE]: [finding description] (or "No ticket linked" if none found)
SUMMARY: [one sentence]
```
---
```

### Subagent B: Code Change Review

```
Prompt template:
---
You are reviewing code changes in a PR.

**Changed files:** {file_list}

**Full diff:**
{diff}

## Review Checklist

1. **Correctness:** Logic errors, off-by-one, null/undefined risks, race conditions
2. **Edge cases:** Missing error handling at system boundaries, unhandled states
3. **Readability:** Unclear naming, magic numbers, overly complex logic
4. **Design:** YAGNI violations, unnecessary abstractions, code duplication. Reference `docs/checklists/architecture-and-design.md` for SOLID and architecture smell heuristics. These are review heuristics, not merge policy — use professional judgment to determine severity. If the checklist file is not available, continue with best-effort review.
5. **Security (quick scan):** Obvious injection risks, hardcoded secrets (detailed scan in separate subagent)
6. **Removal and simplification:** Reference `docs/checklists/removal-and-simplification.md`. Flag unused/redundant code introduced or left behind by this PR. Classify as safe-delete-now or defer-with-plan. If the checklist file is not available, continue with best-effort review.

## Output Format

Return EXACTLY this format:
```
DIMENSION: Code Changes
VERDICT: PASS | WARN | BLOCK
FINDINGS:
- [BLOCK|WARN|NOTE]: {file}:{line} — {description}
SUMMARY: [one sentence]
```
---
```

### Subagent C: Code Scan

```
Prompt template:
---
You are performing a code scan on PR changes.

**Changed files:** {file_list}

**Full diff:**
{diff}

## Phase 1: Project Linters

Discover and run existing linters/scanners on changed files ONLY:
1. Check for config files: `.eslintrc*`, `pylintrc`, `.flake8`, `pyproject.toml` (ruff), `biome.json`, `.semgreprc`, `tslint.json`
2. For each found linter, run it on changed files only
3. Report findings with file:line references

If no linters are configured, note "No project linters found" and proceed to Phase 2.

## Phase 2: AI Security & Quality Scan

Reference `docs/checklists/security-and-reliability.md` for expanded coverage beyond OWASP Top 10. If the checklist file is not available, continue with best-effort review.

Analyze the diff for:
1. **OWASP Top 10:** Injection (SQL, command, XSS), broken auth, sensitive data exposure, XXE, broken access control, security misconfiguration, insecure deserialization
2. **Hardcoded secrets:** API keys, tokens, passwords, connection strings in code
3. **Unsafe patterns:** eval(), dangerouslySetInnerHTML, shell exec with user input, unparameterized queries
4. **Dependency concerns:** New dependencies added — are they well-maintained? Known vulnerabilities?
5. **Concurrency risks:** Race conditions, TOCTOU (check-then-act without locks), missing synchronization on shared state
6. **Crypto and serialization:** Unsafe deserialization of untrusted input, weak or deprecated cryptographic algorithms, insecure defaults
7. **Resource exhaustion:** Missing rate limits, unbounded loops controlled by external input, CPU/memory hotspots

## Output Format

Return EXACTLY this format:
```
DIMENSION: Code Scan
VERDICT: PASS | WARN | BLOCK
LINTER_RESULTS:
- [linter_name]: [N issues | clean | not configured]
AI_SCAN_RESULTS:
- [BLOCK|WARN|NOTE]: {file}:{line} — {description}
SUMMARY: [one sentence]
```
---
```

### Subagent D: Unit Test Review

```
Prompt template:
---
You are reviewing the unit test status for a PR.

**Changed files:** {file_list}

**Full diff:**
{diff}

## Phase 1: Run Tests

1. Detect test framework from project config:
   - `package.json` → look for jest/vitest/mocha scripts
   - `pyproject.toml` / `setup.cfg` → pytest
   - `Cargo.toml` → cargo test
   - `go.mod` → go test
2. Run the test suite. Report: total tests, passed, failed, skipped.
3. If tests fail → this is a BLOCK finding.

## Phase 2: Coverage (if tooling exists)

1. Check if coverage tooling is configured (nyc, coverage.py, istanbul, c8)
2. If available, run coverage on changed files
3. Flag changed lines that are NOT covered by tests

## Phase 3: Test Quality (AI Review)

Use boundary-condition heuristics from `docs/checklists/performance-and-boundary-conditions.md` to assess whether tests cover risky input/state transitions. If the checklist file is not available, continue with best-effort review.

Review test files in the diff:
1. Are assertions meaningful (not just `expect(true).toBe(true)`)?
2. Are edge cases tested (empty input, boundaries, error paths)?
3. Are tests testing behavior, not implementation details?
4. Any redundant/duplicate tests?
5. Do tests cover risky boundary conditions (null/undefined, empty collections, numeric limits, off-by-one)?

## Output Format

Return EXACTLY this format:
```
DIMENSION: Unit Tests
VERDICT: PASS | WARN | BLOCK
TEST_RESULTS:
- Total: N, Passed: N, Failed: N, Skipped: N
COVERAGE:
- [covered | not covered]: {file}:{lines} (or "Coverage tooling not available")
TEST_QUALITY:
- [BLOCK|WARN|NOTE]: [finding description]
SUMMARY: [one sentence]
```
---
```

## Step 3: Assemble Summary

After all subagents return, the orchestrator assembles the final review artifact.

Assemble the final review artifact following `docs/contracts/pr-review-output.md`, and emit any platform-native inline review findings separately where supported.

Specifically:
1. Collect all subagent results (Subagent A produces 2 dimension verdicts: Description + Ticket Alignment; Subagents B, C, D each produce 1; total: 5)
2. Produce the canonical 9-section summary following the contract
3. Emit platform-native inline findings where the runtime supports them (e.g., `::code-comment` in Codex, line-level GitHub review comments in Claude Code full mode)
4. When a dimension verdict is PASS with no findings, that dimension's section must state: what was checked, what was not covered, and residual risks including verification gaps

## Step 4: Post to GitHub (Full Mode Only)

**Only when platform is GitHub (public) and mode is full:**

1. Post line-level review comments for BLOCK and WARN findings that have file:line references:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{number}/reviews --method POST \
     --field body="PR Review Summary: ..." \
     --field event="REQUEST_CHANGES" \
     --input - <<'EOF'
   {
     "comments": [
       {"path": "src/auth.ts", "line": 42, "body": "BLOCK: SQL concatenation — use parameterized query"},
       {"path": "src/auth.ts", "line": 78, "body": "WARN: Magic number 3600 — extract to named constant"}
     ]
   }
   EOF
   ```
2. If posting fails (auth, permissions) → fall back to local-only, log the error

**For GitLab and enterprise platforms:** Skip posting entirely. The local report is the deliverable.

## Graceful Degradation

| Scenario | Behavior |
|---|---|
| `gh` not installed | Local-only mode, skip GitHub posting |
| `glab` not installed | Local-only mode using git diff |
| Ticket URL unreachable | Skip ticket alignment, note in report |
| Linters not configured | Note "No linters found", AI scan still runs |
| Test framework not detected | Note "Could not detect test framework", skip test run, AI still reviews test files in diff |
| Coverage not configured | Note "Coverage not available", skip coverage analysis |
| GitHub API posting fails | Fall back to local report, log error |

## Usage

```
# Review current branch's PR (auto-detect)
/hotl:pr-review

# Review a specific PR by URL
/hotl:pr-review https://github.com/org/repo/pull/123

# Review a GitLab MR
/hotl:pr-review https://gitlab.company.com/team/repo/-/merge_requests/45
```
