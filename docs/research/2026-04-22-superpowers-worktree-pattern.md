# Research: Superpowers Worktree Execution Pattern

**Date:** 2026-04-22
**Question:** Should HOTL move workflow execution to git worktrees, based on `obra/superpowers`?

## Current Status

Yes. HOTL has since adopted worktree-by-default execution for git repos with history. `worktree: false` is now the explicit opt-out for staying in the current checkout on a dedicated branch. The remaining value in this note is the ergonomic comparison with superpowers, not the original go/no-go question.

## Findings

### 1. What the superpowers worktree workflow does

Superpowers treats git worktree setup as a required workflow step before execution, not as an optional branch convenience. Both `executing-plans` and `subagent-driven-development` explicitly require `using-git-worktrees` before tasks begin, and both hand off to `finishing-a-development-branch` when implementation is done.  
Sources:
- https://github.com/obra/superpowers/blob/main/skills/executing-plans/SKILL.md
- https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md
- https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees
- https://github.com/obra/superpowers/blob/main/skills/finishing-a-development-branch/SKILL.md

`using-git-worktrees` is opinionated about setup:
- Prefer an existing project-local `.worktrees/`, then `worktrees/`
- Otherwise check `CLAUDE.md` for a preference
- Otherwise ask the user to choose between a project-local directory and a global `~/.config/superpowers/worktrees/<project>/...` location
- If the worktree directory is project-local, verify it is ignored by git before creating anything
- Create the worktree with `git worktree add <path> -b <branch>`
- Auto-detect project setup (`npm install`, `cargo build`, `poetry install`, etc.)
- Run a clean baseline test pass before starting implementation  
Source:
- https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees

`finishing-a-development-branch` closes the loop by forcing a post-implementation decision: merge locally, push/create PR, keep branch/worktree, or discard. For merge, PR, and discard, it removes the worktree; for “keep as-is,” it preserves it.  
Source:
- https://github.com/obra/superpowers/blob/main/skills/finishing-a-development-branch/SKILL.md

### 2. Why it helps with multi-session and subagent isolation

The practical gain is workspace isolation per execution session. Git worktrees let one repository hold multiple checked-out branches at once, so a feature run can happen in its own filesystem path without switching the user’s main checkout or colliding with another live session. Git also refuses to check out the same branch into another worktree unless forced, which provides a useful safety rail around branch reuse.  
Sources:
- https://git-scm.com/docs/git-worktree
- https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees

Superpowers combines that filesystem isolation with context isolation. Its subagent-driven flow says each task gets a fresh subagent that should not inherit controller session history; the controller curates only the task text and necessary context. That reduces context pollution even when the code is being changed inside the same worktree.  
Source:
- https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md

One important nuance: this is mostly **session-level isolation**, not “one worktree per subagent task.” Superpowers still warns against dispatching multiple implementation subagents in parallel because of conflicts.  
Source:
- https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md

### 3. Concrete ideas HOTL could still borrow

HOTL now uses worktree-first execution by default, so the remaining gap versus superpowers is mostly ergonomics and lifecycle polish rather than core isolation capability. See [docs/workflow-format.md](/Users/yimwu/Documents/workspace/hotl-plugin/docs/workflow-format.md) and [skills/executing-plans/SKILL.md](/Users/yimwu/Documents/workspace/hotl-plugin/skills/executing-plans/SKILL.md).

| Borrowable idea | Why it is useful | Trade-off |
|---|---|---|
| Make worktree setup a first-class executor mode, not just `worktree: true` | Closer to superpowers’ “isolated workspace first” model; better default for multi-session work | More setup friction for small/local runs |
| Add a deterministic worktree directory policy (`.worktrees/` > `worktrees/` > config > ask) | Makes runs predictable and resumable; reduces ad hoc path choices | Needs config/docs updates across Codex/Cline/HOTL docs |
| Verify project-local worktree dirs are gitignored before creation | Prevents accidental tracking of worktree contents | Superpowers auto-edits `.gitignore`; HOTL may want a prompt instead to avoid hidden repo mutation |
| Run setup + baseline verification immediately after worktree creation | Establishes a clean starting point before blaming later changes | Adds startup cost, especially in large repos |
| Add an explicit “finish branch/worktree” closeout flow | Gives users a standard merge/PR/keep/discard decision and cleanup policy | Adds another workflow surface to maintain |
| Surface `worktree_path` aggressively in state/report/resume UX | Makes suspended runs easier to resume and inspect | Mostly product polish, not core engine work |

### 4. Caveats

- Superpowers’ pattern does **not** by itself solve parallel workflow execution. It creates one isolated workspace for the run, but its own subagent workflow still warns against parallel implementation subagents. If HOTL wants DAG-style parallel execution, it would need separate orchestration rules on top of worktrees.  
  Sources:
  - https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md
  - https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees

- Git worktrees have branch-safety constraints: Git refuses to add a worktree for a branch that is already checked out elsewhere unless forced. HOTL would need deterministic branch naming and explicit branch-reuse handling if worktrees become the default.  
  Source:
  - https://git-scm.com/docs/git-worktree

- Superpowers’ ignore hygiene is stricter and more intrusive than HOTL’s current governance style. The skill says to add a missing ignore rule and commit it immediately for project-local worktree directories. That protects users, but it is a stronger automatic repo mutation than HOTL’s current documented principles around avoiding hidden state changes.  
  Sources:
  - https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees
  - [docs/workflow-format.md](/Users/yimwu/Documents/workspace/hotl-plugin/docs/workflow-format.md)

- Requiring dependency install/build/test on every fresh worktree is probably the right safety default, but it will raise executor startup time in larger repos. That is an inference from superpowers’ required setup and baseline-test steps, not an explicit performance claim in the repo.  
  Source:
  - https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees

## Recommendation

HOTL has already made the core move:

1. Keep worktree-first execution as the default for git-backed runs.
2. Keep `worktree: false` as the explicit escape hatch for users who intentionally want current-checkout execution.
3. Borrow superpowers’ best remaining ergonomics: deterministic directory selection, ignore verification, baseline setup/test, and explicit finish/cleanup flow.
4. Do **not** oversell this as parallel-subagent isolation. Treat it as per-run/session isolation unless HOTL later adds separate worktrees per parallel branch of execution.
