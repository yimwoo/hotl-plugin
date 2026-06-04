# HOTL Codex PR Review Prompt

Use this as a `prompt-file` for `openai/codex-action@v1` or as the body of a
manual `codex exec` PR-review run.

Review the current pull request with HOTL review discipline.

Scope:
- Review this branch against the pull request base branch.
- Prioritize correctness, regressions, missing tests, security-sensitive paths,
  and HOTL contract drift.
- If this repository has HOTL contracts, workflows, `.hotl/state/`, or
  `.hotl/reports/`, use them as review context.

Output:
- Follow the 9-section PR review contract in `docs/contracts/pr-review-output.md`
  when that file exists.
- Otherwise use: Scope, Summary, Findings, Test Gaps, Security Notes,
  What Was Not Covered, Residual Risks, Verdict.
- Include file and line references for every actionable finding.
- Do not modify files.
- Do not claim tests passed unless the command output is available in the run.
