# Scenario: Risk Level Overrides Auto-Approve

## Given
- A workflow with `risk_level: high` and `auto_approve: true`
- Steps with `gate: human` that contain security-sensitive keywords (auth, encrypt, secret, password, token, billing, permission)

## Expected Behavior

1. `risk_level: high` ALWAYS forces human approval at `gate: human` steps
2. `auto_approve: true` is ignored for high-risk workflows at human gates
3. The executor must explicitly state this override in its instructions
4. Security-sensitive keywords in step text trigger the same enforcement

## Not Expected
- Auto-approving any human gate when risk_level is high
- Treating auto_approve: true as sufficient for high-risk steps
- Silently skipping the risk override check
