---
id: STD-017
name: "No Magic Values"
version: "1.0.0"
category: general
status: active
last_reviewed: "2026-05-27"
---

# No Magic Values

> All numeric literals and string literals that carry domain or configuration meaning MUST be extracted into named static constants. No magic numbers, no hardcoded strings in logic or conditions.

## Motivation

Magic values obscure intent — `if (retries > 3)` tells you nothing about *why* 3 was chosen. When the same value appears in multiple places, a change requires a multi-file hunt. Named constants make the codebase self-documenting, refactoring safe, and review efficient.

## Rules

1. **Numeric literals** used in conditions, thresholds, calculations, or configuration MUST be named constants. Exceptions: `0`, `1`, `-1` when used idiomatically (loop init, increment, not-found sentinel) and array/string index `0`.

2. **String literals** used in status checks, role comparisons, event names, error codes, configuration keys, or API paths MUST be named constants or enum values.

3. **Constants** MUST use SCREAMING_SNAKE_CASE (per STD-003 Rule 6) and live in a dedicated constants file or the relevant class/module scope:
   - Small scope (one file): top of the file or class-level static field.
   - Shared across files: dedicated `constants.ts`, `Constants.java`, `constants.py`, or equivalent.

4. **Enum-like values** (status strings, role names, category labels) MUST use language-native enums or frozen objects — not scattered string literals.

5. **Configuration values** that vary by environment (URLs, ports, feature flags) MUST come from config/environment, not hardcoded constants.

## Examples

### Compliant

```typescript
const MAX_RETRY_ATTEMPTS = 3;
const SESSION_TIMEOUT_MS = 30_000;

if (attempts > MAX_RETRY_ATTEMPTS) { throw new RetriesExhaustedError(); }
setTimeout(logout, SESSION_TIMEOUT_MS);
```

```java
public static final int MAX_LOGIN_ATTEMPTS = 5;
public static final String STATUS_ACTIVE = "ACTIVE";

if (user.getLoginAttempts() >= MAX_LOGIN_ATTEMPTS) { lockAccount(user); }
if (STATUS_ACTIVE.equals(user.getStatus())) { grantAccess(); }
```

### Non-Compliant

```typescript
// Magic number — what does 3 mean?
if (attempts > 3) { throw new Error("Too many retries"); }

// Hardcoded string — fragile, not searchable
if (user.role === "admin") { showDashboard(); }

// Hardcoded timeout — why 30000?
setTimeout(logout, 30000);
```

## Applicability

- **Service types:** all (backend, frontend, gateway)
- **Domains:** all
- **Exceptions:** Test fixtures may use inline literals when the value is self-evident from context (e.g., `expect(sum(2, 3)).toBe(5)`). Framework-required annotations/decorators that accept literal arguments (e.g., `@Column(length = 255)`) are exempt when the value is a framework default.

## References

- STD-003: Naming Conventions (Rule 6 — constant naming)
