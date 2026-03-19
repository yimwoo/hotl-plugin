# Scenario: Retry and Max-Iterations Stop

## Given
- A workflow step with `loop: until [condition]`
- `max_iterations: 3`
- `verify: [command]`

## Expected Behavior

1. After executing the step, run the verify command
2. If verify passes: log success, mark step complete, advance to next step
3. If verify fails and attempts < max_iterations: log retry with attempt count (e.g., "Retrying (2/3)..."), re-execute the step
4. If verify fails and attempts = max_iterations: STOP execution
   - Report: "Step N reached max iterations (3). [condition] not met."
   - Show the last verify output
   - Wait for human guidance — do not continue automatically

## Not Expected
- Silently skipping a failed step
- Continuing after max iterations without human input
- Retrying without logging the attempt number
