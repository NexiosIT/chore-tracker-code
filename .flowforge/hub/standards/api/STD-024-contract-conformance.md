---
id: STD-024
name: "Code-to-Contract Conformance"
version: "1.2.0"
category: api
status: active
last_reviewed: "2026-08-31"
---

# Code-to-Contract Conformance

> Producer services MUST prove, at test time, that the request and response bodies their code actually accepts and emits conform to the use case's contract schemas — by validating the envelope-unwrapped body against the contract, woven into the integration tests that already exist.

## Motivation

The contract (`contract.openapi.yml` / `contract.asyncapi.yml`) is the source of truth, and code is generated from it — but generation is probabilistic and review is qualitative. Nothing today proves the *running* code honors the contract: Iron Dome checks **spec↔spec** in the hub before handover; `ie manifest verify` checks **manifest↔spec** drift; CI lints the contract **file** for well-formedness. A controller that drops a field, renames one, returns the wrong status, or forgets the response envelope passes all of them.

This standard is the missing **code↔contract** proof. It is deterministic, rides along in the integration tests generation already produces, and needs no running broker or cross-service stack (that is the journey-smoke's job). It is the producer-side guarantee that lets a consumer trust the same contract at compile time.

Those tests run in the **project's own** CI workflow, not in IE's `quality-gates.yml` — so make that workflow's checks required on the integration branch, or this proof never runs on a PR. `quality-gates.yml` still runs the deterministic `ie contracts coverage` cross-check, which reports operations with no passing conformance test; that check reads the coverage table, it does not execute the tests.

## Where the boundary is (read STD-001 first)

The contract describes the **unwrapped body in camelCase**; the `{ data, error, meta }` envelope (STD-001) and the snake_case wire (STD-010) are uniform transforms. Conformance therefore validates the **unwrapped body** against the contract schema and treats the envelope + casing as transforms — see STD-001's **Contract representation** section.

## Rules

1. **Every contract operation MUST have a conformance test.** For each sync operation (`paths`.{path}.{method}) and each async operation (`contract.asyncapi.yml` channel × `send`/`receive`), an integration test MUST assert code-to-contract conformance. An operation with no conformance test is a coverage gap that blocks feature completion (it also appears as a row in the feature Traceability Matrix).

2. **Response conformance.** In the integration test, after asserting the business outcome, unwrap the envelope and validate:
   - success → the `data` body against the operation's success schema (e.g. `{Response}`);
   - error → the `error` body against `Error` (STD-001 shape: `code`, `message`, optional `details[].{field,rule,message}`), and assert `data` is `null`.

3. **The oracle schema is projected to the wire dialect, never the data.** Validation adapts the contract schema (the oracle) to what the wire actually carries, then validates the raw body against it — it never re-shapes the response data. Two structural projections:
   - **Casing:** the wire is snake_case and the contract is camelCase, so project the schema's property keys camelCase → snake_case (a transform over known schema keys). It MUST NOT recursively transform response-data keys — free-form map values (`additionalProperties`) carry data keys that are not field names and must not be re-cased.
   - **Schema dialect:** when the contract is OpenAPI 3.0 but the validator enforces JSON Schema (draft-7+), translate OpenAPI-only constructs so real values validate — chiefly `nullable: true`, which must become an explicit `null` in the property's `type` (`{type: string, nullable: true}` → `type: [string, null]`), recursing into nested and composed schemas. The first nullable field in a hub hits this; a schema with none is unaffected.

4. **Request conformance.** Inbound request bodies are validated against the request schema (e.g. `{Request}`) by the producer. Conformance tests MUST assert that a representative conforming request is accepted and that a malformed request fails with the contract's error body (mapped from the relevant error scenario).

5. **Async payloads.** For a UC with `contract.asyncapi.yml`, emitted payloads (`send`) MUST be validated against the channel message's `components.schemas` payload before/at publish, and consumed payloads (`receive`) MUST be validated on ingest. The same envelope/casing rules do not apply to broker payloads — validate the payload schema directly. See STD-021 / STD-022.

6. **Generate the helper once; reuse it — do not reimplement per test.** IE ships no code templates, so it ships no helper. Generate a small conformance test helper once per service following the stack's test-pattern standard (spring-boot: STD-009), commit it to the repo's test sources, and reuse it across every operation. Assert the envelope shape + casing strategy once per service (a single foundation test), not on every endpoint.

7. **Read the contract from the materialized snapshot, scanning — not hardcoding — the UC set.** Conformance reads schemas from `.flowforge/contracts/` (the snapshot materialized at handover) so tests build and run standalone — no live product-hub access at test time. The helper MUST **discover contracts by scanning** `.flowforge/contracts/` for every `*/contract.openapi.yml` and index schemas by name, rather than bake in a single UC's path — but a name that two contracts define **incompatibly** MUST fail the lookup, naming the schema and both use cases, rather than one silently replacing the other. Two contracts sharing a name is ordinary: STD-001 gives every use case an `Error`, two use cases touching one entity both declare it, and the snapshot accumulates (it carries this service's use cases plus any cross-service callee it stands on, and `ie generation finalize` leaves it in place). Where the definitions agree the collision is the no-op this rule assumes; where they diverge, last-one-wins means the enforced contract is chosen by directory order, and the assertions of whichever use case lost keep passing while checking nothing. Write it that way from the **first** UC so a second UC's operations are a drop-in — no helper edit, no call-site change (the same scan-don't-hardcode rule as STD-010's frontend type generation). Snapshot↔hub drift is surfaced by `ie manifest verify`, not by these tests.

   **Incompatible means a difference that changes what the helper accepts** — not any difference at all, because failing on a harmless one blocks a use case that did nothing wrong. Compare the **resolved** schemas: follow local `$ref` and flatten `allOf`, on property values as well as on the schema itself, or one contract writing an agreed shape the other way round fails for no reason. Two definitions are incompatible when any of these holds:

   - a property's `type` differs;
   - both sides constrain a property's value set and the sets differ, **or** one side constrains it (`enum`, `pattern`, `format`, numeric or length bounds) and the other leaves it open — the open side accepts everything the constrained side forbids;
   - a property is `required` on one side and optional on the other;
   - a property is declared **and** `required` on one side, and absent on the other.

   They are compatible — the no-op this rule assumes — when the only difference is an **optional** property one side declares and the other omits: under OpenAPI defaults both accept the same payloads, so a use case with no field-error scenario may prune the optional `details[]` from its `Error` without failing every lookup that touches it.

## Realization (per stack)

This standard is stack-agnostic; each stack ships the helper through its foundation.

- **Spring Boot (backend):** a JSON-Schema validator (e.g. `networknt/json-schema-validator`) over the unwrapped `data`/`error` node, against the snake-projected contract schema. Woven into the `SpringBootTest + MockMvc` integration tests of STD-009. Illustrative:

  ```java
  // CP3 integration test — after the business assertions:
  MvcResult res = mockMvc.perform(get("/accounts/{id}", id))
      .andExpect(status().isOk())
      .andReturn();

  // Helper (generated once per service per STD-009): unwraps the envelope,
  // snake-projects the contract schema, validates the `data` body. Throws on divergence.
  ContractConformance.assertResponseData(res, "GetAccountResponse");
  ```

  Backend models codegen (generating DTOs from `components.schemas`) is an **optional** ergonomic layer (STD-025) — it strengthens compile-time shape checking but is **not** required for conformance; this runtime validation is the gate.

- **Frontend (Next.js):** conformance is **compile-time**, not runtime — types generated from the same contract (`openapi-typescript`) bind STD-010's client, and `tsc` is the gate. That gate lives in the project's own CI workflow (a `typecheck` step), so it must be a required check on the integration branch to actually hold. This standard's runtime rules apply to **producer** (backend / gateway) services.

## Applicability

- **Service types:** backend, gateway
- **Domains:** all
- **Checkpoints:** CP1 (request/response schema awareness), CP3 (the woven conformance assertions). Bound via the `api` category (see `/ie/generate` standards-to-checkpoint binding).
- **Exceptions:** Health/readiness endpoints (no contract). Event-only UCs validate async payloads per Rule 5 instead of HTTP bodies.

## References

- `ie integrity check` (Iron Dome): spec↔spec integrity before handover — the sibling check, and distinct from this one
- `ie manifest verify`: manifest↔spec drift, which is what covers the materialized snapshot going stale
- STD-001: API Response Envelope (the envelope + contract-representation convention)
- STD-002: Error Handling Strategy (the `error` body's `code`)
- STD-009: Test Patterns (where the conformance assertions are woven, spring-boot)
- STD-021 / STD-022: Event Publisher / Consumer (async payload validation)
