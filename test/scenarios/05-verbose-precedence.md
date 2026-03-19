# Scenario: Verbose Progress Precedence

## Given
- A workflow that may or may not have `progress: verbose` in frontmatter
- An executor that may or may not receive a verbose override at invocation

## Expected Behavior

### Precedence (highest to lowest)
1. **Executor invocation override** — user says "run with verbose progress" → verbose
2. **Workflow frontmatter** — `progress: verbose` → verbose
3. **Default** — no setting → non-verbose (per-step log only)

### When verbose is enabled
- Print a compact step list at each step transition
- Step transitions = before starting a step, after a step completes/fails/auto-approves
- Use these symbols:
  - `✓` completed
  - `→` current step (include attempt info if looping)
  - `·` pending
  - `⚡` auto-approved gate
  - `✗` blocked/failed
- Use compact list format, NOT a table

### When verbose is disabled (default)
- Print only per-step one-line logs after each step completes
- Do NOT print the full step list

## Not Expected
- Verbose progress enabled by default without explicit opt-in
- Frontmatter overriding an explicit invocation setting
- Verbose rendering as a markdown table instead of compact list
- Verbose printing mid-step (only at transitions)
