# Scenario: Deterministic Codex Summary Rendering

## Given
- `hotl-rt finalize --json` returns the canonical summary payload
- A renderer converts that payload into final summary output for a target platform

## Expected Behavior

The renderer must produce deterministic final summaries from the same payload regardless of whether execution was initiated from Codex, Claude Code, or Cline.

### Codex compact-list rules
- Render `Execution Summary` followed by one line per workflow step
- Use the step symbol, step number, step name, and normalized outcome on every line
- Use plain ASCII ` - ` between step name and status detail
- Show attempts on non-gate lines: `1 attempt` or `N attempts`
- Show `(-)` for gate outcomes

### Outcome precedence
- `gate_result=approved` renders as `Approved`, not raw `Done`
- `gate_result=rejected` renders as `Rejected`, not raw `Done`
- `status=blocked` renders as `Blocked`
- `status=failed` renders as `Failed`
- `status=done` renders as `Done`

### Table-platform rules
- Claude Code and Cline render the same normalized outcomes in a markdown table
- The `Iterations` column contains only attempt counts or `-` for gates

## Not Expected
- Missing final chat summary when the runtime payload exists
- Raw gate steps shown as `Done (1 attempt)` instead of `Approved (-)` or `Rejected (-)`
- Platform-specific differences in the normalized semantic outcome for the same payload
