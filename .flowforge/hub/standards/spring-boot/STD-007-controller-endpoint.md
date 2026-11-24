---
id: STD-007
name: "Controller Endpoint Pattern"
version: "1.1.0"
category: spring-boot
status: active
last_reviewed: "2026-07-18"
discovery_layer: "generation-extracted"
---

# Controller Endpoint Pattern

> REST controllers MUST use constructor injection, map their base path from the UC contract, wrap responses in a standard envelope, use the HTTP status codes the contract declares, and delegate all error handling to a global exception handler.

## Motivation

Without a consistent controller pattern, generated endpoints are error-prone. Responses lack consistency. Status codes drift from the contract. Error handling is scattered across endpoints. A standard controller pattern ensures every endpoint structures responses uniformly, honours the contract's declared status codes, and maintains a clean separation between HTTP concerns (status codes, headers) and domain logic.

## Rules

1. Controllers MUST be annotated with `@RestController` and a `@RequestMapping` whose base path matches the resource paths declared in the UC's `contract.openapi.yml`. Do NOT hardcode an API-version prefix (e.g. `/api/v1`) unless the contract's paths include one — the contract is authoritative for the URL structure.

2. Controllers MUST use **constructor injection only**. Field injection (`@Autowired` on class fields) is prohibited. All dependencies are injected via the constructor and stored as `private final` fields.

3. Request body validation is triggered by `@Valid` on the `@RequestBody` parameter. If validation fails, the global exception handler catches `MethodArgumentNotValidException` and returns a 400 response with field-level errors. Controllers MUST NOT duplicate validation logic.

4. Query parameter validation MUST be collected in a `List<FieldError>` within the controller method. If validation fails, throw a `DomainException` with the list of field errors, which the global exception handler will translate to a 400 response.

5. All successful responses MUST be wrapped in an `ApiEnvelope`:
   - `ApiEnvelope.success(data)` for single-item responses
   - `ApiEnvelope.successPaginated(data, pageNumber, pageSize, totalCount)` for paginated list responses

   The HTTP status carried by the response follows Rule 6.

6. HTTP status codes MUST match the UC contract's declared response for the operation. Conventional defaults, used only when the contract leaves the code open:
   - a POST that **creates** a resource returns `201 CREATED`;
   - reads (`GET`) and in-place updates (`PATCH`/`PUT`) return `200 OK`;
   - a delete returns `200 OK` (with a body) or `204 NO CONTENT` (without one).

   The contract's declared status code always wins over these conventions — do not force every mutation to `201`.

7. Controllers MUST NOT contain try-catch blocks for domain errors. All `DomainException` instances are caught by the global `GlobalExceptionHandler`, translated to appropriate HTTP status codes, and wrapped in the envelope's `error` field.

8. Path variables MUST be retrieved from the URL path (e.g., `@PathVariable UUID id`). Path validation (non-null, format checks) is handled by Spring's binding layer; controllers assume valid binding.

9. Response status codes are set via the endpoint's return type or `ResponseEntity`. For consistency, use `@GetMapping` / `@PostMapping` / `@PatchMapping` / `@DeleteMapping` with the correct HTTP method annotation rather than `@RequestMapping(method=...)`.

## Examples

### Compliant: GET endpoint

```java
@RestController
@RequestMapping("/accounts")
@RequiredArgsConstructor
public class AccountController {
  private final AccountService accountService;

  @GetMapping("/{id}")
  public ResponseEntity<ApiEnvelope<AccountResponse>> getAccount(@PathVariable UUID id) {
    AccountResponse response = accountService.getAccount(id);
    return ResponseEntity.ok(ApiEnvelope.success(response));
  }
}
```

### Compliant: POST endpoint that creates a resource (201 response)

```java
@PostMapping
public ResponseEntity<ApiEnvelope<AccountResponse>> createAccount(
    @Valid @RequestBody CreateAccountRequest request) {
  AccountResponse response = accountService.createAccount(request);
  return ResponseEntity.status(HttpStatus.CREATED).body(ApiEnvelope.success(response));
}
```

### Compliant: List endpoint with query parameters and pagination

```java
@GetMapping
public ResponseEntity<ApiEnvelope<List<AccountResponse>>> listAccounts(
    @RequestParam(defaultValue = "1") int page,
    @RequestParam(defaultValue = "10") int size,
    @RequestParam(required = false) String status) {

  // Validate query parameters
  List<FieldError> errors = new ArrayList<>();
  if (page < 1) {
    errors.add(new FieldError("page", "must be >= 1"));
  }
  if (size < 1 || size > 100) {
    errors.add(new FieldError("size", "must be between 1 and 100"));
  }
  if (!errors.isEmpty()) {
    throw new DomainException(
      "VALIDATION_INVALID_PAGINATION",
      "Pagination parameters invalid",
      errors
    );
  }

  PagedResponse<AccountResponse> response = accountService.listAccounts(page, size, status);

  return ResponseEntity.ok(ApiEnvelope.successPaginated(
    response.getContent(),
    response.getPageNumber(),
    response.getPageSize(),
    response.getTotalCount()
  ));
}
```

### Compliant: PATCH endpoint returns 200 (in-place update)

```java
@RestController
@RequestMapping("/accounts")
@RequiredArgsConstructor
public class AccountController {
  private final AccountService accountService;

  @PatchMapping("/{id}")
  public ResponseEntity<ApiEnvelope<AccountResponse>> updateAccount(
      @PathVariable UUID id,
      @Valid @RequestBody UpdateAccountRequest request) {
    AccountResponse response = accountService.updateAccount(id, request);
    return ResponseEntity.ok(ApiEnvelope.success(response));
  }
}
```

### Compliant: Error handling delegated to GlobalExceptionHandler

```java
@RestController
@RequestMapping("/accounts")
@RequiredArgsConstructor
public class AccountController {
  private final AccountService accountService;

  @PostMapping("/{id}/withdraw")
  public ResponseEntity<ApiEnvelope<AccountResponse>> withdraw(
      @PathVariable UUID id,
      @Valid @RequestBody WithdrawRequest request) {
    // No try-catch; DomainException thrown by service is caught by GlobalExceptionHandler
    AccountResponse response = accountService.withdraw(id, request.getAmount());
    return ResponseEntity.ok(ApiEnvelope.success(response));
  }
}

@RestControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler(DomainException.class)
  public ResponseEntity<ApiEnvelope<Void>> handleDomainException(
      DomainException ex,
      HttpServletRequest request) {
    HttpStatus status = mapCategoryToStatus(ex.getCategory());
    return ResponseEntity.status(status).body(
      ApiEnvelope.error(ex.getCode(), ex.getMessage(), ex.getDetails())
    );
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiEnvelope<Void>> handleValidationException(
      MethodArgumentNotValidException ex) {
    List<FieldError> errors = ex.getBindingResult().getFieldErrors()
      .stream()
      .map(fe -> new FieldError(fe.getField(), fe.getDefaultMessage()))
      .collect(Collectors.toList());
    return ResponseEntity.badRequest().body(
      ApiEnvelope.error("VALIDATION_FAILED", "Validation failed", errors)
    );
  }
}
```

### Non-Compliant: Field injection instead of constructor injection

```java
// BAD: Field injection — violates Rule 2
@RestController
@RequestMapping("/accounts")
public class AccountController {
  @Autowired
  private AccountService accountService;

  @GetMapping("/{id}")
  public ResponseEntity<ApiEnvelope<AccountResponse>> getAccount(@PathVariable UUID id) {
    // accountService is injected via field, not constructor
    return ResponseEntity.ok(ApiEnvelope.success(accountService.getAccount(id)));
  }
}
```

### Non-Compliant: Forcing 201 on an in-place update (Rule 6)

```java
// BAD: PATCH is an in-place update — the contract declares 200, not 201
@PatchMapping("/{id}")
public ResponseEntity<ApiEnvelope<AccountResponse>> updateAccount(
    @PathVariable UUID id,
    @Valid @RequestBody UpdateAccountRequest request) {
  AccountResponse response = accountService.updateAccount(id, request);
  return ResponseEntity.status(HttpStatus.CREATED).body(ApiEnvelope.success(response)); // Wrong: 201
}
```

### Non-Compliant: Try-catch in controller for domain errors

```java
// BAD: Domain error handling in controller violates Rule 7
@PostMapping("/{id}/withdraw")
public ResponseEntity<ApiEnvelope<AccountResponse>> withdraw(
    @PathVariable UUID id,
    @Valid @RequestBody WithdrawRequest request) {
  try {
    AccountResponse response = accountService.withdraw(id, request.getAmount());
    return ResponseEntity.ok(ApiEnvelope.success(response));
  } catch (DomainException ex) {
    // Error handling should be in GlobalExceptionHandler, not here
    return ResponseEntity.badRequest().body(
      ApiEnvelope.error(ex.getCode(), ex.getMessage())
    );
  }
}
```

### Non-Compliant: Unwrapped response

```java
// BAD: Response not wrapped in ApiEnvelope — inconsistent API contract
@GetMapping("/{id}")
public AccountResponse getAccount(@PathVariable UUID id) {
  // Response should be wrapped in ApiEnvelope.success()
  return accountService.getAccount(id);
}
```

### Non-Compliant: Validation logic in controller

```java
// BAD: Validation duplicated in controller instead of using @Valid
@PostMapping
public ResponseEntity<ApiEnvelope<AccountResponse>> createAccount(
    @RequestBody CreateAccountRequest request) {
  // Validation should use @Valid on @RequestBody, not manual checks here
  if (request.getName() == null || request.getName().isEmpty()) {
    throw new IllegalArgumentException("Name is required");
  }
  if (request.getInitialBalance().compareTo(BigDecimal.ZERO) < 0) {
    throw new IllegalArgumentException("Balance must be positive");
  }
  AccountResponse response = accountService.createAccount(request);
  return ResponseEntity.status(HttpStatus.CREATED).body(ApiEnvelope.success(response));
}
```

## Applicability

- **Service types:** backend REST APIs
- **Domains:** all
- **Exceptions:** None. All REST controllers follow this pattern.

## References

- STD-001: API Response Envelope (response wrapping and structure)
- STD-002: Error Handling Strategy (GlobalExceptionHandler implements the strategy)
- STD-006: Service Layer Pattern (controllers delegate to services)
