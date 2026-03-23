# Architecture and Design Checklist

These are review heuristics, not merge policy. Reviewers use professional judgment to decide severity based on context, impact, and codebase conventions.

## SOLID Principles

- **SRP (Single Responsibility):** Does the module have unrelated responsibilities? Would it change for different reasons? Look for classes/modules that mix I/O, business logic, and presentation.
- **OCP (Open/Closed):** Are frequent edits required to add new behavior instead of using extension points? Look for growing switch/case blocks or repeated conditional logic.
- **LSP (Liskov Substitution):** Do subclasses break expectations of their parent type? Look for type checks at call sites (`instanceof`, type guards) that suggest substitutability is broken.
- **ISP (Interface Segregation):** Are interfaces wider than their consumers need? Look for implementations that stub out or ignore methods they don't use.
- **DIP (Dependency Inversion):** Does high-level logic directly depend on low-level implementations? Look for direct imports of concrete infrastructure (database drivers, HTTP clients) from business logic modules.

## Architecture Smells

- **God objects:** Classes or modules that accumulate unrelated functionality and become central coupling points.
- **Hidden coupling:** Modules that depend on each other through shared mutable state, global variables, or implicit ordering rather than explicit interfaces.
- **Circular dependencies:** Module A depends on B, which depends on A (directly or transitively). Often a sign that responsibilities need to be split.
- **Leaky abstractions:** Internal implementation details exposed through public interfaces, forcing consumers to understand internals.
- **Inappropriate intimacy:** A module reaches into another module's internals rather than using its public API.
- **Shotgun surgery:** A single logical change requires edits across many unrelated files, suggesting missing abstractions.
