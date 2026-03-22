---
name: receiving-code-review
description: Use when review findings arrive — verify each claim against the codebase and HOTL contracts before making changes. Governs how agents respond to review feedback.
---

# HOTL Receiving Code Review

## Core Rule

Treat review feedback as input to evaluate, not instructions to obey. Verify each claim against the current codebase, the workflow, and the HOTL contracts before making changes.

## When This Applies

- After any code review — from the `hotl:code-reviewer` agent, PR review, human reviewer, or external contributor
- Before implementing any suggested change
- Whenever review findings are returned to an executor at a review checkpoint

## Process

### 1. Verify

Check whether each finding is factually correct in the current code:

- Confirm the file:line reference exists and matches the claim
- Run any verification commands that would confirm or refute the finding
- If the finding references a pattern or convention, check whether it actually applies to this codebase
- If the code changed since the review was written, re-evaluate the finding against current HEAD before doing anything

### 2. Evaluate

For each verified finding, check against HOTL contracts:

- Does acting on it violate the intent contract?
- Does it expand scope beyond success_criteria? (YAGNI)
- Does it conflict with existing constraints?
- Does it change risk_level or require a new gate?
- Does it contradict a prior human-approved decision?

Classify each finding:

- **Accept** — verified correct, within scope, improves the work
- **Reject** — factually wrong, out of scope, or conflicts with contracts
- **Defer** — valid but belongs in a separate workflow (scope expansion)

### 3. Respond

For each finding, produce a decision record:

| Field | Content |
|---|---|
| **Finding** | What was raised |
| **Disposition** | accept / reject / defer |
| **Evidence** | What was checked, what was found |
| **Next action** | What will be done, or why nothing will be done |

### 4. Implement

- Only implement accepted findings
- BLOCK findings first, then WARN, then NOTE
- If an accepted finding changes scope, constraints, or risk_level, stop implementation and return to planning/governance before proceeding
- Run verification after each change — do not batch blind
- If a change breaks verification, revert and re-evaluate

## Handling Unclear Feedback

- Do not implement the unclear finding
- You may proceed with other findings that are independently verified and clearly in scope
- Ask for clarification on the unclear items before implementing them

## Source-Specific Rules

**HOTL code-reviewer agent:**
Findings include file:line refs and severity. Treat severity as the reviewer's initial priority signal, but still verify the impact before acting.

**Human reviewer:**
Human reviewers are authoritative on product intent, priorities, and approved scope decisions. Technical claims still need verification against the code.

**External reviewer:**
Verify everything. Check whether suggestions fit this codebase's patterns, constraints, and HOTL contracts. Push back with evidence when they don't.

## Push-Back Protocol

When rejecting a finding:

- Use technical reasoning, not defensiveness
- Reference specific code, tests, or contract clauses
- If the finding conflicts with a human-approved gate decision, escalate to the human rather than overriding
