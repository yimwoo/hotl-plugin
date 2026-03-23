# Performance and Boundary Conditions Checklist

These are review heuristics, not merge policy. Reviewers use professional judgment to decide severity based on context, frequency of the code path, and potential for silent failure.

## Performance

- **N+1 queries:** A loop that issues one database/API query per item instead of batching. Common in ORM code where related objects are loaded lazily inside iterations.
- **CPU-intensive ops in hot paths:** Expensive operations (sorting large collections, regex compilation, deep cloning) inside frequently executed code paths (request handlers, event loops, render cycles).
- **Missing cache:** Repeated computation or fetching of data that doesn't change between calls. Look for identical queries in the same request, repeated file reads, or recomputed constants.
- **Unbounded memory allocation:** Reading entire files, result sets, or streams into memory without size limits. Look for `.readAll()`, collecting unbounded iterators into arrays, or accumulating data in loops without caps.

## Boundary Conditions

- **Null/undefined handling:** Code that assumes values are present without checking. Look for unguarded property access on nullable types, missing null checks after lookups, and optional chaining gaps.
- **Empty collections:** Code that assumes collections are non-empty. Look for direct indexing (`arr[0]`), `.reduce()` without initial value, and `.first()` / `.last()` on potentially empty results.
- **Numeric boundaries:** Integer overflow/underflow, floating-point precision issues, division by zero, negative values where only positive are expected.
- **Off-by-one errors:** Fencepost errors in loop bounds, slice/substring ranges, pagination offsets, and array indexing. Common in manual index arithmetic.

## Error Handling

- **Swallowed exceptions:** Empty catch blocks, catch-and-continue patterns that silently drop errors, or catch blocks that log but don't propagate or handle the failure.
- **Overly broad catch:** Catching generic `Exception`/`Error` when only specific error types are expected, masking unexpected failures.
- **Missing async error handling:** Unhandled promise rejections, missing `.catch()` on promise chains, `async` functions called without `await` or error handling.
- **Silent failures:** Functions that return default values or empty results on error instead of signaling the failure to the caller.
