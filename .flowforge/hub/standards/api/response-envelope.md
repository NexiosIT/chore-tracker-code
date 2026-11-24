---
id: STD-001
name: "API Response Envelope"
version: "1.1.0"
category: api
status: active
last_reviewed: "2026-07-18"
---

# API Response Envelope

> All API endpoints MUST return responses in a consistent envelope structure with `data`, `error`, and `meta` fields.

## Motivation

Without a standard response shape, every endpoint invents its own structure. Clients must handle N different formats. Error handling becomes inconsistent. Pagination metadata appears in different places. A consistent envelope means clients parse one structure regardless of endpoint, error handling is uniform, and pagination is predictable.

## Rules

1. All API responses MUST use a standard envelope with three top-level fields: `data`, `error`, and `meta`.

2. Successful responses MUST populate `data` with the response payload and set `error` to `null`.

3. Error responses MUST populate `error` and set `data` to `null`.

4. The `error` object MUST contain:
   - `code` — a machine-readable string identifier (e.g., `VALIDATION_ERROR`, `NOT_FOUND`)
   - `message` — a human-readable description safe to display to end users
   - `details` — an optional array of field-level errors (see Rule 8)

5. The `meta` object MUST always include `request_id` (a unique identifier for tracing).

6. **Paginated** list endpoints MUST include pagination in `meta`:
   - `page` — current page number (1-indexed)
   - `per_page` — items per page
   - `total_count` — total items matching the query
   - `total_pages` — computed total pages

   A list endpoint whose contract returns the full result set (a naturally bounded or reference collection, with no page/size query parameters) is not paginated and MUST NOT invent pagination `meta`. Whether an endpoint paginates is the UC contract's decision, not this standard's.

7. HTTP status codes MUST align with the response content: 2xx for success, 4xx for client errors, 5xx for server errors. The envelope does not replace HTTP semantics — it complements them.

8. Validation errors (HTTP 400) MUST include `details` as an array of objects, each with:
   - `field` — the field path that failed validation (e.g., `email`, `address.zipCode`)
   - `rule` — the validation rule that was violated (e.g., `required`, `format`, `min_length`)
   - `message` — a human-readable explanation

9. The envelope structure MUST NOT be nested inside another wrapper. The envelope IS the root of the response body.

## Contract representation

The OpenAPI/AsyncAPI contract describes the **unwrapped body, in camelCase** — not the wire:

- A success response schema defines the `data` payload; an error response schema defines the `error` body. The `data`/`error`/`meta` envelope (Rules 1–9) is applied **uniformly** by the service and is **not** repeated per endpoint in the contract.
- Field names are **camelCase** in the contract and in code. The wire representation is **snake_case**, applied by the producer's serialization strategy (e.g. Jackson `SNAKE_CASE`) and converted at the client edge (STD-010).
- Code-to-contract conformance (STD-024) unwraps the envelope and validates the body against the contract schema, projecting the contract's camelCase schema to snake_case on the **schema (oracle)** side — never transforming response-data keys (which may include free-form map keys).

The envelope shape and the casing strategy are each asserted **once per service** (a foundation fixture), not per endpoint.

## Examples

### Compliant: Successful single-resource response

```json
{
  "data": {
    "id": "usr-42",
    "name": "Jane Doe",
    "email": "jane@example.com"
  },
  "error": null,
  "meta": {
    "request_id": "req-a1b2c3d4"
  }
}
```

### Compliant: Paginated list response

```json
{
  "data": [
    { "id": "prod-1", "name": "Widget A" },
    { "id": "prod-2", "name": "Widget B" }
  ],
  "error": null,
  "meta": {
    "request_id": "req-e5f6g7h8",
    "page": 1,
    "per_page": 20,
    "total_count": 47,
    "total_pages": 3
  }
}
```

### Compliant: Validation error response

```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid fields.",
    "details": [
      { "field": "email", "rule": "format", "message": "Must be a valid email address" },
      { "field": "age", "rule": "min", "message": "Must be at least 18" }
    ]
  },
  "meta": {
    "request_id": "req-z9y8x7w6"
  }
}
```

### Non-Compliant: Missing envelope structure

```json
{
  "id": "usr-42",
  "name": "Jane Doe"
}
```

This response returns the resource directly without the `data`/`error`/`meta` envelope.

### Non-Compliant: Error without code field

```json
{
  "data": null,
  "error": {
    "message": "Something went wrong"
  },
  "meta": {
    "request_id": "req-bad123"
  }
}
```

The `error` object is missing the required `code` field.

## Applicability

- **Service types:** backend, gateway
- **Domains:** all
- **Exceptions:** Health check endpoints (`/health`, `/ready`) MAY return a simple `{ "status": "ok" }` without the envelope. WebSocket and streaming responses are not covered by this standard.

## References

- STD-002: Error Handling Strategy (error categories map to the `code` field in this envelope)
