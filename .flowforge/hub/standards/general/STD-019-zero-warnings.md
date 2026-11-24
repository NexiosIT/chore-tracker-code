---
id: STD-019
name: "Zero Warnings"
version: "1.0.0"
category: general
status: active
last_reviewed: "2026-05-27"
---

# Zero Warnings

> Code MUST compile and pass all linting, type-checking, and build steps with zero warnings. Warnings MUST NOT be introduced, and any pre-existing warnings encountered during a changeset MUST be fixed before completion.

## Motivation

Warnings are deferred bugs. Each unaddressed warning erodes signal-to-noise ratio — teams stop reading build output once it scrolls past dozens of ignored warnings. Suppressed warnings mask real issues. A zero-warning policy keeps build output meaningful and catches regressions the moment they appear.

## Rules

1. **No new warnings.** A changeset MUST NOT introduce any compiler warnings, linter warnings, type-checker warnings, or build-tool warnings. If a change triggers a warning, fix the root cause — do not suppress it.

2. **Fix encountered warnings.** If existing warnings appear in files touched by the changeset, they MUST be fixed in the same commit. Warnings in untouched files are out of scope (fix-forward, not fix-everything).

3. **No warning suppression annotations.** `@SuppressWarnings`, `// eslint-disable`, `// @ts-ignore`, `# type: ignore`, `#pragma warning disable`, `noinspection`, and equivalent constructs are forbidden unless ALL of these conditions are met:
   - The warning is a verified false positive from the tool.
   - A comment explains WHY it is a false positive.
   - No alternative code structure can eliminate the warning.

4. **Deprecation warnings MUST be resolved immediately.** Do not call deprecated APIs, methods, or constructors. Use the replacement API. If no replacement exists, document the situation and raise it as a spec gap.

5. **Build output verification.** Before claiming a checkpoint or task is complete, the developer/agent MUST:
   1. Run the full compile/build step.
   2. Run the linter.
   3. Run the type-checker (if applicable).
   4. Confirm zero warnings in the output of all three.
   This is part of the verification gate (STD-015).

## Examples

### Compliant

```java
// No SuppressWarnings, no unchecked casts, no unused imports
import java.util.List;

public class OrderService {
  private final OrderRepository orderRepository;

  public List<Order> findActive(UUID tenantId) {
    return orderRepository.findByTenantIdAndStatus(tenantId, OrderStatus.ACTIVE);
  }
}
```

```typescript
// No @ts-ignore, no unused variables, no implicit any
export function calculateTotal(items: LineItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

### Non-Compliant

```java
// BAD: Unused import triggers warning
import java.util.Map;
import java.util.List;

public class OrderService {
  // BAD: SuppressWarnings hides a real unchecked cast
  @SuppressWarnings("unchecked")
  public List<Order> findActive(UUID tenantId) {
    return (List<Order>) orderRepository.findByTenantId(tenantId);
  }
}
```

```typescript
// BAD: @ts-ignore hides a type error
// @ts-ignore
const result = someFunction(wrongType);

// BAD: unused variable triggers warning
const unusedConfig = loadConfig();
```

## Applicability

- **Service types:** all (backend, frontend, gateway)
- **Domains:** all
- **Exceptions:** Third-party generated code (e.g., OpenAPI codegen, Protobuf stubs) may be excluded if the generator produces unavoidable warnings AND the generated files are in a clearly separated directory. Add that directory to the linter's ignore list, not per-line suppressions.

## References

- STD-015: Verification Protocol (build output verification is part of the completion gate)
- STD-003: Naming Conventions (unused imports are a common warning source)
