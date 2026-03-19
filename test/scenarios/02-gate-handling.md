# Scenario: Gate Handling (Human vs Auto-Approve)

## Given
- A workflow with `auto_approve: true` and `risk_level: low`
- Steps with `gate: human`

## Expected Behavior

### When auto_approve: true AND risk_level != high
1. `gate: human` steps are auto-approved
2. Log: "Auto-approved: Step N gate (risk: low)"
3. Continue without pausing

### When auto_approve: false OR risk_level: high
1. `gate: human` steps MUST pause
2. Show summary of what was done in the step
3. Ask: "Gate reached at Step N. Continue?"
4. Wait for explicit human response before proceeding

### gate: auto
1. Always continue without pausing
2. Log: "Auto-approved: Step N gate"

## Not Expected
- Auto-approving a human gate when auto_approve is false
- Skipping a gate entirely without logging
- Continuing past a human gate without explicit approval when required
