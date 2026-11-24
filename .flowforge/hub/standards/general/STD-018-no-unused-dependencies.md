---
id: STD-018
name: "No Unused Dependencies"
version: "1.0.0"
category: general
status: active
last_reviewed: "2026-05-27"
---

# No Unused Dependencies

> Every dependency in the project manifest MUST be actively used in source code. Do not add dependencies speculatively. Remove dependencies that are no longer referenced.

## Motivation

Unused dependencies bloat install times, increase attack surface, cause phantom version conflicts, and confuse developers who assume every listed package is load-bearing. Speculative additions ("we might need this later") create maintenance debt that compounds silently.

## Rules

1. **Do not add a dependency unless code in the current changeset imports or references it.** Planning to use it later is not sufficient — add it when the consuming code is written.

2. **Remove any dependency that is no longer imported or referenced** by source code, tests, build config, or tooling config. When deleting code that was the sole consumer of a package, remove the package in the same commit.

3. **Transitive dependencies** MUST NOT be imported directly. If you need a sub-dependency, declare it explicitly in the project manifest.

4. **Dev dependencies vs production dependencies** MUST be correctly categorized. Test frameworks, linters, and build tools go in `devDependencies` / `testImplementation` / equivalent — never in production dependencies.

5. **Peer dependencies** MUST match the host project's version range. Do not add a peer dependency that the host does not already provide.

6. **Verification:** Before completing a checkpoint or PR, run the stack's unused-dependency detection if available:
   - Node/TypeScript: `npx depcheck` or equivalent
   - Java/Kotlin: Gradle `dependencyAnalysis` plugin or manual review of imports
   - Python: `pip-extra-reqs` / `deptry` or manual review
   - If no automated tool exists, manually verify each dependency has at least one import in the codebase.

## Examples

### Compliant

```json
// package.json — every dependency is imported somewhere
{
  "dependencies": {
    "express": "^4.18.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "vitest": "^1.0.0",
    "typescript": "^5.3.0"
  }
}
```

### Non-Compliant

```json
// package.json — lodash added "just in case", moment never imported
{
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "^4.17.0",
    "moment": "^2.29.0",
    "vitest": "^1.0.0"
  }
}
```

Problems: `lodash` added speculatively, `moment` never imported, `vitest` in production dependencies.

## Scope (not a build-vs-buy directive)

This standard governs *unused* and *speculative* dependencies. A dependency that is needed and actually imported/used is **compliant** — including one adopted to realize a design-system component (an inventory entry whose `impl: { kind: dependency }`). Such a package is *used* by construction, so it never violates this standard.

This standard is **not** a build-vs-buy directive and must not be read as "hand-roll a solved problem to avoid a dependency." Which shared library (if any) realizes a design-system component is decided once, by a human, in the design-system component inventory (`impl`) — not by this standard. STD-018 has nothing to say about that choice; it only forbids carrying packages no code uses.

## Applicability

- **Service types:** all (backend, frontend, gateway)
- **Domains:** all
- **Exceptions:** Framework-required implicit dependencies (e.g., `@types/*` packages that provide ambient types, Babel presets consumed by config only) are exempt from the "must be imported" rule but must still be actively needed by the build.

## References

- STD-003: Naming Conventions (consistent dependency aliasing)
