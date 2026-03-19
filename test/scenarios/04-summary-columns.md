# Scenario: Final Summary Table Column Rules

## Given
- Execution has completed (all steps done or stopped)

## Expected Behavior

The final summary table must follow strict column rules:

| Column | Contains | Example |
|--------|----------|---------|
| Step | Step number only | `1`, `2`, `3` |
| Name | Step name from workflow | `Write failing tests` |
| Status | Outcome + details | `✓ Done (17 tests)`, `⚡ Auto-approved` |
| Iterations | Attempt count only | `1`, `2`, `3`, `-` |

### Status values
- `✓ Done` — step completed
- `✓ Done (N tests)` — step completed, test count in Status
- `⚡ Auto-approved` — gate auto-approved
- `✓ Approved` — gate approved by human
- `✗ Failed` — step verify failure
- `✗ Blocked` — executor stopped (max retries, gate denied)

### Rules
- Test counts (e.g., "34 tests") belong in Status, NEVER in Iterations
- Iterations is always a number or `-` for gates
- Gates use `-` for Iterations since they have no retry count

## Not Expected
- Test counts in the Iterations column
- Free-form text in the Iterations column
- Missing status values for any step
