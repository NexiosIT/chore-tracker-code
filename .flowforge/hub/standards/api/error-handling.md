---
id: STD-002
name: "Error Handling Strategy"
version: "1.2.0"
category: api
status: active
last_reviewed: "2026-11-23"
---

# Error Handling Strategy

> All backend services MUST classify errors into standard categories, map them to HTTP status codes, and prevent internal details from leaking to clients.

## Motivation

Without a consistent error strategy, services invent ad-hoc error handling. Stack traces leak to clients. Error logging is inconsistent. Downstream services cannot reliably interpret upstream failures. A standard error strategy ensures errors are classified, logged uniformly, and translated to safe client-facing responses.

## Rules

1. Errors MUST be classified into one of these categories:

   | Category | HTTP Status | When to Use |
   |----------|------------|-------------|
   | `validation` | 400 | Input fails format, type, or constraint checks |
   | `business` | 422 | Input is valid but violates a business rule |
   | `not_found` | 404 | Requested resource does not exist |
   | `conflict` | 409 | Operation conflicts with current state (e.g., duplicate, stale version) |
   | `authentication` | 401 | Missing or invalid credentials |
   | `authorization` | 403 | Valid credentials but insufficient permissions |
   | `internal` | 500 | Unexpected failures (bugs, unhandled exceptions) |
   | `external` | 502 | Third-party service failure |
   | `rate_limit` | 429 | Too many requests or attempts in a time window (e.g., throttling, a temporary lockout after repeated failed logins) |

2. Domain services MUST throw typed/structured errors with an explicit category, NOT raw exceptions or generic error types. The error structure MUST include at minimum: `category`, `code` (machine-readable identifier), and `message`.

3. The interface layer (API controllers, event handlers) MUST translate domain errors to HTTP responses using the category-to-status mapping in Rule 1. Domain code MUST NOT reference HTTP status codes directly.

4. Internal errors (category `internal`) MUST NOT expose stack traces, file paths, database details, or implementation specifics in API responses. The response MUST use a generic message (e.g., "An internal error occurred"). The full error MUST be logged server-side.

5. All errors MUST be logged with:
   - `error_category` — the classification from Rule 1
   - `error_code` — the machine-readable identifier
   - `request_id` — correlating to the response envelope's `meta.request_id`
   - `timestamp` — ISO 8601
   - `user_id` — if available (omit for unauthenticated requests)
   - `stack_trace` — for `internal` and `external` categories only

6. External service failures MUST be wrapped with context before propagation:
   - Which service failed
   - What operation was attempted
   - The original error (for logging, not for client response)

7. Validation errors MUST include field-level detail per STD-001 Rule 8: which field failed, which rule was violated, what value was received (sanitized — never log passwords or tokens).

8. Error codes MUST use SCREAMING_SNAKE_CASE. When a scenario (`scenarios.feature`) or a contract pins a specific error code, that code is authoritative and MUST be emitted verbatim — the spec wins over any naming convention. For codes not pinned upstream, follow the default pattern `{CATEGORY}_{SPECIFIC}`:
   - `VALIDATION_REQUIRED_FIELD`
   - `BUSINESS_INSUFFICIENT_BALANCE`
   - `NOT_FOUND_USER`
   - `EXTERNAL_PAYMENT_GATEWAY_TIMEOUT`
   - `RATE_LIMIT_LOGIN_LOCKED`

9. Services MUST NOT catch and silently swallow errors. Every caught exception MUST either be handled (with a meaningful recovery path) or re-thrown as a classified error.

10. **One exception type = one HTTP status code, everywhere.** The same exception class (or error category + code combination) MUST always map to the same HTTP status code regardless of which controller or endpoint handles it. This MUST be enforced via a **single centralized exception handler** (e.g., `@ControllerAdvice` in Spring, global error middleware in Express/NestJS). Controllers MUST NOT individually catch domain exceptions and choose status codes — the centralized handler owns the mapping. If a new exception type is introduced, it MUST be registered in the centralized handler before use.

11. **Every `rate_limit` (429) response MUST carry a `Retry-After` header** whose value is a whole number of seconds until the caller may try again. The domain error MUST carry that duration (for example a `retryAfterSeconds` field), and the centralized handler (Rule 10) sets the header from it. Domain code still does not reference HTTP (Rule 3). The error `message` MAY also state when to try again in words, but the header is the machine-readable source.

## Examples

### Compliant: Domain error structure (pseudocode)

```
class DomainError:
  category: ErrorCategory     // validation, business, not_found, etc.
  code: string                // e.g., "BUSINESS_INSUFFICIENT_BALANCE"
  message: string             // human-readable, safe for clients
  details: FieldError[]?      // optional, for validation errors
  cause: Error?               // original error, for logging only

// Domain service throws a typed error
function withdrawFunds(accountId, amount):
  account = repository.findById(accountId)
  if account is null:
    throw DomainError(
      category: "not_found",
      code: "NOT_FOUND_ACCOUNT",
      message: "Account not found"
    )
  if account.balance < amount:
    throw DomainError(
      category: "business",
      code: "BUSINESS_INSUFFICIENT_BALANCE",
      message: "Insufficient balance for this withdrawal"
    )
```

### Compliant: Interface layer translation (pseudocode)

```
// Controller catches domain errors and translates to HTTP
function handleRequest(request):
  try:
    result = domainService.execute(request.body)
    return Response(status: 200, body: envelope(data: result))
  catch error as DomainError:
    statusCode = STATUS_MAP[error.category]  // Rule 1 mapping
    log.error({
      error_category: error.category,
      error_code: error.code,
      request_id: request.id,
      timestamp: now(),
      stack_trace: error.cause?.stackTrace    // only for internal/external
    })
    return Response(status: statusCode, body: envelope(
      error: { code: error.code, message: error.message, details: error.details }
    ))
```

### Compliant: External service wrapping (pseudocode)

```
function chargePayment(orderId, amount):
  try:
    return paymentGateway.charge(amount)
  catch error:
    throw DomainError(
      category: "external",
      code: "EXTERNAL_PAYMENT_CHARGE_FAILED",
      message: "Payment processing is temporarily unavailable",
      cause: error   // preserved for logging, never sent to client
    )
```

### Compliant: Centralized exception handler (Rule 10)

```java
@ControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(DomainException.class)
  public ResponseEntity<ApiEnvelope<Void>> handleDomainException(DomainException ex) {
    HttpStatus status = switch (ex.getCategory()) {
      case "validation"     -> HttpStatus.BAD_REQUEST;           // 400
      case "not_found"      -> HttpStatus.NOT_FOUND;             // 404
      case "business"       -> HttpStatus.UNPROCESSABLE_ENTITY;  // 422
      case "conflict"       -> HttpStatus.CONFLICT;              // 409
      case "authentication" -> HttpStatus.UNAUTHORIZED;          // 401
      case "authorization"  -> HttpStatus.FORBIDDEN;             // 403
      case "external"       -> HttpStatus.BAD_GATEWAY;           // 502
      case "rate_limit"     -> HttpStatus.TOO_MANY_REQUESTS;     // 429
      default               -> HttpStatus.INTERNAL_SERVER_ERROR; // 500
    };
    return ResponseEntity.status(status).body(ApiEnvelope.error(ex.getCode(), ex.getMessage()));
  }
}
// Every controller benefits — no per-endpoint catch blocks needed.
```

### Compliant: Rate-limit error with Retry-After (Rule 11, pseudocode)

```
// Domain: a username is locked after repeated failed logins
throw DomainError(
  category: "rate_limit",
  code: "RATE_LIMIT_LOGIN_LOCKED",
  message: "Too many attempts. Try again at 16:42.",
  retryAfterSeconds: 900
)

// Centralized handler: status from the Rule 1 map, header from the error
response.status = STATUS_MAP[error.category]           // 429
if error.category == "rate_limit":
  response.headers["Retry-After"] = error.retryAfterSeconds
```

### Non-Compliant: Lockout mapped to another category, no Retry-After (Rules 1, 11)

```
// BAD: a lockout is not an authentication failure; this returns 401,
// and the client cannot tell when to try again
throw DomainError(
  category: "authentication",
  code: "AUTHENTICATION_LOCKED_OUT",
  message: "Account locked"
)
```

### Non-Compliant: Inconsistent status codes for the same exception (Rule 10)

```java
// BAD: Two controllers map the same exception to different HTTP codes
@RestController
public class OrderController {
  @PostMapping("/orders")
  public ResponseEntity<?> createOrder(...) {
    try { ... }
    catch (DomainException ex) {
      return ResponseEntity.status(400).body(ex.getMessage()); // 400 here
    }
  }
}

@RestController
public class PaymentController {
  @PostMapping("/payments")
  public ResponseEntity<?> createPayment(...) {
    try { ... }
    catch (DomainException ex) {
      return ResponseEntity.status(422).body(ex.getMessage()); // 422 there — inconsistent
    }
  }
}
```

### Non-Compliant: Raw exception with leaked details

```
// BAD: Throws raw error, leaks internals to client
function getUser(id):
  try:
    return database.query("SELECT * FROM users WHERE id = ?", id)
  catch error:
    throw new Error("Database error: " + error.message)
    // Leaks: database type, query structure, internal error message
```

### Non-Compliant: Swallowed error

```
// BAD: Silently swallows the error
function sendNotification(userId, message):
  try:
    notificationService.send(userId, message)
  catch error:
    // silently ignored — the caller never knows it failed
    pass
```

## Applicability

- **Service types:** backend, gateway
- **Domains:** all
- **Exceptions:** None. All backend services follow this strategy.

## References

- STD-001: API Response Envelope (error responses use the envelope's `error` field)
