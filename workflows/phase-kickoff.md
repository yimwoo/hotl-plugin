---
intent: "Kick off phase {{PHASE_ID}} of initiative {{SLUG}}: review prior docs, triage findings, produce the phase requirements"
success_criteria: "Three artifacts exist and are human-approved — kickoff review memo in docs/reviews/, triage memo in docs/reviews/, requirements doc in docs/requirements/"
risk_level: medium
auto_approve: false
---

<!--
    Reusable phase-kickoff workflow.

    How to use:
      1. Copy this file to the root of your project as
         `hotl-workflow-{{SLUG}}-phase-{{PHASE_ID}}-kickoff.md`
         (substitute real values for {{SLUG}} and {{PHASE_ID}}).
      2. Replace every {{SLUG}} and {{PHASE_ID}} token in the frontmatter,
         action lines, and verify lines below.
      3. Run via `/hotl:loop <copied-filename>` or `/hotl:execute-plan
         <copied-filename>`. Each of the three steps is gate: human —
         you will be asked to approve after every artifact is produced.

    What it does:
      - Step 1 (Review) reads docs/designs/{{SLUG}}.md, prior phase
        plans, any ADRs that constrain this phase, and produces a
        kickoff-review memo flagging inconsistencies, risks, and open
        questions.
      - Step 2 (Triage) turns each review finding into an explicit
        accept / defer / reject decision, plus any new-ADR markers.
      - Step 3 (Requirements) produces the @pm-style requirements doc
        that the per-phase brainstorming session will consume.

    After the three artifacts land, start a fresh session and run
    `/hotl:brainstorm` with scope: phase — the requirements doc is
    now its input.
-->

## Steps

- [ ] **Step 1: Review**
action: Read docs/designs/{{SLUG}}.md in full, plus any prior phase plans under docs/plans/ that precede phase {{PHASE_ID}}, plus any ADRs in docs/decisions/ that constrain this phase. Produce docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-kickoff-review.md with (a) a plain-language summary of the phase's scope per the design, (b) inconsistencies or gaps between the design and the current codebase, (c) three concrete risks the design underweights for this phase, (d) any prerequisites that must land before the phase can start (missing fixtures, missing schema, feature flags), and (e) a short section of open questions for triage.
loop: false
verify: confirm docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-kickoff-review.md exists and contains the five labeled sections (summary, inconsistencies, risks, prerequisites, open questions)
gate: human

- [ ] **Step 2: Triage**
action: Read docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-kickoff-review.md. For every finding, produce docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-triage.md with an explicit accept / defer / reject verdict, and for each accepted finding classify it as either (a) a doc fix in the existing design / plan / ADR, or (b) a new ADR that needs to be written before the phase can proceed. Do not fix docs or write ADRs in this step — only produce the triage memo.
loop: false
verify: confirm docs/reviews/{{SLUG}}-phase-{{PHASE_ID}}-triage.md exists, lists every review finding with a verdict, and classifies each accepted finding as doc-fix or new-ADR
gate: human

- [ ] **Step 3: Requirements**
action: Read docs/designs/{{SLUG}}.md (phase {{PHASE_ID}} row of §7 phase breakdown), plus the accepted triage items from step 2. Produce docs/requirements/{{SLUG}}-phase-{{PHASE_ID}}.md with (a) user stories and personas for this phase, (b) acceptance criteria that are testable and observable, (c) UX copy and interaction expectations where applicable, (d) explicit non-goals for this phase, and (e) an exit gate — what "done" looks like from a user-visible perspective. No architecture, no module boundaries — that is the @architect's job in the next session. Do not write any code.
loop: false
verify: confirm docs/requirements/{{SLUG}}-phase-{{PHASE_ID}}.md exists and contains all five sections (user stories, acceptance criteria, UX, non-goals, exit gate)
gate: human
