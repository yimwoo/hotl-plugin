---
intent: Demonstrate HOTL design, planning, and execution artifacts end to end with throwaway files
success_criteria: A temporary design doc, workflow file, execution report, and final summary are produced and then cleaned up
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Create demo workspace**
action: Create a throwaway workspace for HOTL simulation artifacts
loop: false
verify: test -d .hotl-demo/simulation

- [ ] **Step 2: Write demo note**
action: Write a throwaway note that proves step execution can create user-visible artifacts
loop: false
verify: test -f .hotl-demo/simulation/demo-note.md

- [ ] **Step 3: Demo review gate**
action: Pause at a low-risk human gate so the final summary shows gate handling
loop: false
gate: human
