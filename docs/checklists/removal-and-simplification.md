# Removal and Simplification Checklist

These are review heuristics, not merge policy. Reviewers use professional judgment to decide whether flagged code should be removed now, deferred, or left as-is.

## What to Look For

- **Unused exports:** Functions, classes, constants, or types that are exported but have no consumers. Verify with grep or IDE usage search before flagging.
- **Unreachable branches:** Code paths that can never execute — dead `else` blocks, impossible conditions, switch cases that never match, early returns that make subsequent code unreachable.
- **Feature-flagged-off code:** Code behind feature flags that have been permanently off or fully rolled out. If the flag is no longer needed, the code guarded by it can be simplified.
- **Redundant abstractions:** Wrapper classes, helper functions, or abstraction layers that add indirection without adding value. A function that calls another function with the same arguments and no additional logic is a candidate.
- **Over-engineered patterns:** Factory patterns for single implementations, strategy patterns with one strategy, builder patterns for simple objects. Complexity without justification.
- **Duplicate code:** Near-identical logic in multiple places that could be consolidated, or copy-paste code that has drifted.

## Classification

When flagging removal candidates, classify each one:

- **Safe-delete-now:** Confirmed unused through usage analysis (grep, IDE references, test coverage). No external consumers. Removing it has no observable effect.
- **Defer-with-plan:** Possibly unused but needs broader analysis (cross-repo consumers, dynamic references, reflection-based access). Create a follow-up item with concrete verification steps.

## Confirmation Before Flagging

- Do not flag code as unused based on suspicion alone. Run `grep`, check import references, or verify with IDE tooling.
- Consider dynamic references: string-based imports, reflection, configuration-driven dispatch, and plugin systems may reference code that static analysis misses.
- Consider external consumers: libraries, APIs, and shared modules may have consumers outside the current repository.
- When uncertain, classify as defer-with-plan rather than safe-delete-now.
