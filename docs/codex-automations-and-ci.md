# Codex Automations and CI Templates

HOTL's default workflow stays local and interactive. These optional templates
adapt HOTL review and follow-up prompts to Codex Automations and the Codex
GitHub Action without changing repository behavior until a team copies them
into its own project.

## Local Codex Automations

Use these prompts in the Codex app automation creator after HOTL is installed
and enabled for the project.

### PR Feedback Watcher

```text
Every 30 minutes, check the current pull request for new reviewer feedback.
If there are new actionable comments, use $hotl:receiving-code-review to verify
each finding against the codebase and HOTL contracts before proposing fixes.
If there is nothing new to report, archive this run without changing files.
Stop when the pull request is merged, closed, or I explicitly ask you to stop.
```

### Interrupted HOTL Run Watcher

```text
Every weekday morning, inspect .hotl/state/ for interrupted HOTL runs.
For each paused, blocked, or running run, summarize the workflow, current step,
report path, and next safe action. Do not modify files. If all runs are
completed or there is no .hotl/state/ directory, archive this run.
```

### Documentation Drift Check

```text
Weekly, compare HOTL-facing docs against the current skill and command
inventory. Check README.md, docs/skills.md, docs/README.codex.md,
docs/README.cline.md, and skills/using-hotl/SKILL.md. Report drift only; do not
edit files unless I explicitly ask you to update them.
```

### Continuous Evaluation

The fuller continuous-evaluation prompt and setup guide live under
[`automations/continuous-evaluation/`](../automations/continuous-evaluation/).
Unlike the read-only examples above, an approved campaign makes provider calls
and writes local evidence. Run `scripts/hotl-evaluation-schedule.sh preflight`
first, then review the exact campaign, cadence, credentials, call/time/cost
budgets, and capture/retention policy before creating a standalone Codex
project automation.

HOTL ships no `automation.toml` and installation never registers this task.
Every resulting profile proposal remains human-reviewed and declares
`automatic_selection_performed: false` and
`configuration_changes_performed: false`.

## GitHub Actions PR Review

Use the templates in `adapters/` when a team wants Codex to leave a read-only
HOTL-style review comment on pull requests:

- `adapters/github-actions-codex-pr-review.template.yml`
- `adapters/codex-pr-review-prompt.template.md`

Copy the workflow template to `.github/workflows/hotl-codex-pr-review.yml` and
copy the prompt template to `.github/codex/prompts/hotl-pr-review.md`. Store the
OpenAI API key as a GitHub secret named `OPENAI_API_KEY`.

The workflow template uses `openai/codex-action@v1`, `sandbox: read-only`, and
`--ephemeral` so it can review without modifying files or persisting local
sessions on the runner.

## Safety Notes

- Keep review automation read-only until the prompt has been tested manually.
- Do not run repository-controlled setup or build scripts in the same step that
  receives the OpenAI API key.
- Prefer prompt files committed by trusted maintainers over prompt text derived
  from issue bodies, PR descriptions, or comments.
- Treat automation findings as review input, not merge approval.
