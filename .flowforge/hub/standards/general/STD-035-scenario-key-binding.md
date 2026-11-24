---
id: STD-035
name: "Scenario-Key Test Binding"
version: "1.2.0"
category: general
status: active
last_reviewed: "2026-07-26"
---

# Scenario-Key Test Binding

> Every test that verifies a Gherkin scenario MUST carry that scenario's derived key in its test name, so machine-readable test results bind to spec scenarios deterministically. Coverage is a join over result files (`ie scenarios coverage`), never a keyword heuristic and never the generating agent's own claim.

## Motivation

The Traceability Matrix is written by the same agent that wrote the code, and the CI backstop that "verified" it matched scenario keywords against test files — a heuristic that passes almost anything. Deterministic binding replaces both: the spec side derives a stable key per scenario, the test side declares which scenario it verifies by embedding that key, and an independent join over the runner's own results decides covered / failed / uncovered / stale.

## Rules

1. **Key source.** Scenario keys come from `ie spec scenarios -u <UC-id>` (or `--path <spec-folder>`). A key is `{UC-id}#{12-hex}`, derived from the UC id plus the scenario's normalized steps. Keys are NEVER hand-computed, invented, or stored in the spec — the scenarios.feature file is the single source and the key is recomputed from it.

2. **Placement.** The bare key token MUST appear in the test's name as it is emitted into the JUnit XML report (`name` or `classname` attribute) — that is where `ie scenarios coverage` reads it. Anywhere in the name is valid; by convention put it at the end: `test('a PM creates an engagement UC-003-create-engagement#318aa8d41f26', …)`.

3. **Cardinality.** One test MAY carry several keys (a journey test verifying multiple scenarios); several tests MAY carry the same key (unit + integration angles on one scenario). Coverage joins worst-of: any failing test marks the scenario `covered-fail`.

4. **Format is verbatim.** The key is copied exactly — no sanitizing, re-casing, or abbreviating. Its charset (kebab + `#` + hex) is safe in every test-title string and in XML attributes.

5. **Stale keys are a signal, not noise.** When a scenario's steps change, its key changes. Tests still carrying the old key show up as *stale bindings* (`unknown_keys`) in the next coverage run. The response is fix-upstream order: re-verify the changed behavior, update the test, re-point the key — never delete the key to silence the warning.

6. **Which tests carry keys.** Every CP2 unit test that maps a scenario (STD-014 Rule 5) and every CP3 integration test that exercises a scenario's path. Foundation/infrastructure tests, helper tests, and tests for behavior no scenario specifies carry no key — an unkeyed test is legitimate; an uncovered scenario is not.

7. **Framework realization.**
   - String-titled frameworks (Playwright, Vitest, Jest, node:test): put the key in the test title — their JUnit reporters emit the title as the testcase `name`.
   - JUnit 5 (Spring Boot): the key rides `@DisplayName`; Surefire/Failsafe MUST be configured to emit phrased (display) names into the XML report — see STD-009's realization rules.
   - Verification: `ie scenarios coverage --manifest .flowforge/manifest.yml --hub <hub> --results <report-dir>` after the suite runs. Run it once at service foundation time against the first UC's tests to prove the names actually reach the XML.

## Project-owned E2E runner

The end-to-end suite is a project artifact. A suite driving **one** application lives **with the app it drives**, co-located in that app's repository. A suite whose journeys cross **more than one** application has no such home — filing it under whichever app the author happened to be working in is arbitrary — and lives in the hub's journey repo instead (`type: e2e`). Neither is a generic, product-agnostic E2E repository; both are project artifacts bound to this product.

These rules make the suite discoverable and machine-consumable; environment provisioning (how the stack gets up) deliberately stays project-owned and unpinned.

8. **Discovery.** A repo that owns an app and ships an e2e suite exposes the npm script **`test:e2e`**. The script is the single source of truth — anything that wants to run the suite reads package.json; there is no registry fact to declare.

9. **Runner contract.** `npm run test:e2e` is non-interactive, exits non-zero exactly when the suite verdict is red, and writes JUnit XML under **`e2e-results/`** (fixed conventional path, gitignored). Its tests carry scenario keys per Rules 1–7, so `ie scenarios coverage --results e2e-results` joins them like any other result stream.

10. **Self-sufficiency.** After `npm ci`, the runner needs nothing but a reachable stack. Every environment input it assumes (URLs, credentials, container names) is env-var-overridable with committed local defaults — no machine-local edits to run it.

11. **CI stance.** The suite runs in the **project's own** workflow, not in IE's `quality-gates.yml` — IE ships no build/test CI and runs none of your scripts. Keep it advisory at first: a job that is opt-in (a repo variable such as `E2E_IN_CI=true`) and `continue-on-error`, because most suites need a stack CI does not provide. Flipping it blocking is a later, explicit decision backed by measured stability — not a default. Whatever the suite needs in order to run — browsers, containers, a reachable stack — is provisioned by that workflow or by the script itself (an npm `pretest:e2e` hook), never by IE.

## Journey discipline

A **journey** is an end-to-end test that crosses more than one application, or that traverses a real trust boundary end to end. Rules 8–11 say where the runner lives and how CI finds it; these say what a journey may assert and how it earns trust. They bind wherever journeys are written — a co-located single-app suite or a dedicated journey repo alike.

12. **A mock never proves a boundary.** A scenario whose path crosses into an external system — the identity provider, the database under its real access rules, mail, any third party — is not proven by a mock, stub, in-memory double, hand-minted token, or test-profile bypass. Every substitute is *more permissive than the real dependency*: a stub answers the request the code knows how to make, while the real thing answers the request the protocol defines. The Traceability status such a test earns is "unit/integration green", never "boundary verified".

13. **Drive the surface a user drives.** The journey traverses the full path — browser through session through each service to the system of record. A token the suite mints for itself skips the path under test and proves nothing about it.

14. **Assert only what a public surface can show.** If proving a scenario needs database access, container control, or clock manipulation, it is an integration test belonging to the service that owns the behaviour — not a journey. Route it there rather than reaching past the surface, and do not claim its scenario key: a key claimed on a partial verification is the self-attestation Rules 1–7 exist to remove.

15. **Name the engines, and run more than one where the product has a browser.** A run's evidence is only about the engines it actually drove. Engine-specific defects in cookie, storage and layout behaviour are invisible to a single-engine run and reach users directly.

16. **Green at birth, idempotent thereafter, and never retried.** A journey is committed only after it has run and passed against a real stack — an unrun journey is worse than none, since it will be wrong about selectors and timing and will spend the suite's credibility on whoever runs it first. It either mutates nothing or seeds the state it needs with an identifier unique per run and per engine, so it never depends on residue. Retries are not configured: a journey that passes only on the second attempt is reporting something true about the system.

## Applicability

- **Service types:** all (backend, frontend, gateway, e2e)
- **Domains:** all
- **Exceptions:** none. Advisory at P1 — coverage runs report-only; a threshold gate is an explicit caller opt-in (`--min`).

## References

- STD-014: TDD Discipline (Rule 5 — scenario → test mapping this standard makes verifiable)
- STD-009: Test Patterns (Spring Boot realization)
- STD-024: Code-to-Contract Conformance (the same contract + per-stack-realization pairing, for contracts)
