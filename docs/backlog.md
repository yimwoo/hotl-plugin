# HOTL Plugin Backlog

Follow-up items that are not part of any active design/plan. Lightweight — each
item is a short pointer, not a design. When an item matures into real work, it
graduates to `docs/designs/` (if multi-phase) or `docs/plans/` (if single-slice).

---

## Skill-name / artifact-name mismatch (post Slice-1–6)

**Problem.** The skill `writing-plans` does not write to `docs/plans/`; it writes
an executable `hotl-workflow-*.md` to the project root. Meanwhile the skill that
actually produces the tactical plan doc in `docs/plans/` is `brainstorming`. The
names evolved before the three-tier taxonomy (strategic / tactical / executable)
was formalized in `docs/designs/initiative-support.md` §5.

**Candidate direction.** Rename `writing-plans` → `writing-workflows` (or
similar) so the skill name matches what it produces. Optionally split
`brainstorming` so idea-exploration and tactical-plan authoring become separate
skills with distinct outputs.

**Why deferred.** Breaking change for muscle memory (`/hotl:write-plan` slash
command, Codex prompts, Cline rules, adapter templates). Deserves its own
design discussion and migration plan rather than riding on the initiative-
support rollout.

**When to pick up.** After Slice 6 of initiative-support ships. Rename has no
architectural dependency on that rollout, but keeping it separate avoids
piling renames on top of taxonomy changes.

---

## Template for new backlog entries

```
## Short title

**Problem.** One paragraph — what is wrong or missing.

**Candidate direction.** One paragraph — the leaning solution (not a design).

**Why deferred.** One or two sentences — why it is not in an active plan yet.

**When to pick up.** A trigger or time frame, not a commitment.
```
