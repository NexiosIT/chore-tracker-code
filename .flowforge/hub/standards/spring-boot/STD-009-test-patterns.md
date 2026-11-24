---
id: STD-009
name: "Test Patterns"
version: "1.3.2"
category: spring-boot
status: active
last_reviewed: "2026-08-31"
discovery_layer: "generation-extracted"
---

# Test Patterns

> Unit tests MUST use Mockito without Spring context, follow Arrange-Act-Assert structure, and use descriptive method names. Integration tests MUST use real databases and verify the response envelope. All tests MUST use constant UUIDs for reproducibility and clear error assertions.

## Motivation

Without consistent test patterns, generated test code is brittle, slow, and unreliable. Tests mix test concerns with Spring concerns. Test data is non-deterministic. Error cases are not tested systematically. A standard test pattern ensures fast unit tests, trustworthy integration tests, and comprehensive coverage of the API contract.

## Rules

### Unit Test Rules

1. Unit tests MUST use `@ExtendWith(MockitoExtension.class)` and MUST NOT use `@SpringBootTest`. No Spring context is loaded.

2. The service under test MUST be constructed manually in an `@BeforeEach` method:
   ```java
   private AccountService accountService;
   private AccountRepository mockRepository;

   @BeforeEach
   void setUp() {
     mockRepository = mock(AccountRepository.class);
     accountService = new AccountService(mockRepository);
   }
   ```

3. Test method names MUST follow the pattern `{operation}_{scenario}_{expectedOutcome}`:
   - `withdraw_sufficientBalance_deductsAmountAndReturnsNewBalance`
   - `withdraw_insufficientBalance_throwsDomainException`
   - `createAccount_validRequest_assignsUuid`

4. Every test method MUST use a `@DisplayName` annotation with a human-readable description of what is being tested.

5. Tests MUST follow the **Arrange-Act-Assert** structure, with each section separated by a blank line (as in STD-029). Bare `// Arrange` / `// Act` / `// Assert` markers MAY label the sections — three words maximum, no prose, no scenario narration (STD-032):
   ```java
   @Test
   @DisplayName("Withdraw deducts amount when balance is sufficient")
   void withdraw_sufficientBalance_deductsAmountAndReturnsNewBalance() {
     // Arrange
     UUID accountId = ACCOUNT_ID_1;
     BigDecimal initialBalance = new BigDecimal("100.00");
     BigDecimal withdrawAmount = new BigDecimal("30.00");

     Account account = new Account();
     account.setId(accountId);
     account.setBalance(initialBalance);
     when(mockRepository.findById(accountId))
       .thenReturn(Optional.of(account));

     // Act
     AccountResponse response = accountService.withdraw(accountId, withdrawAmount);

     // Assert
     assertThat(response.getBalance()).isEqualByComparingTo(new BigDecimal("70.00"));
     verify(mockRepository).save(any(Account.class));
   }
   ```

6. Error assertions MUST use `assertThatThrownBy()` and verify both exception type and error code:
   ```java
   assertThatThrownBy(() -> accountService.withdraw(accountId, amount))
     .isInstanceOf(DomainException.class)
     .hasFieldOrPropertyWithValue("code", "BUSINESS_INSUFFICIENT_BALANCE");
   ```

7. Mock setup MUST use `when(...).thenReturn(...)` syntax. Inline mocks are discouraged; use `@Mock` or `mock(...)` in `@BeforeEach`.

8. Test data helpers (builders, factories) MUST be defined as private static methods at the bottom of the test class:
   ```java
   private static Account buildAccount(UUID id, BigDecimal balance) {
     Account account = new Account();
     account.setId(id);
     account.setBalance(balance);
     account.setCreatedAt(LocalDateTime.now());
     account.setUpdatedAt(LocalDateTime.now());
     return account;
   }
   ```

9. Constant test data (fixed UUIDs, test strings) MUST be defined as `private static final` fields at the top of the test class:
   ```java
   private static final UUID ACCOUNT_ID_1 = UUID.fromString("00000000-0000-0000-0000-000000000100");
   private static final UUID ACCOUNT_ID_2 = UUID.fromString("00000000-0000-0000-0000-000000000101");
   private static final BigDecimal INITIAL_BALANCE = new BigDecimal("1000.00");
   ```

10. Tests MUST verify behavior, not implementation. Avoid over-specifying mock interactions (e.g., don't assert the exact number of method calls unless the count matters to the requirement).

### Integration Test Rules

1. Integration tests MUST use `@SpringBootTest` and `@AutoConfigureMockMvc` to start the full application context with a real (in-memory) database.

2. Test data setup MUST use `@BeforeEach` to populate test data and MUST call `deleteAll()` first to ensure a clean state:
   ```java
   @BeforeEach
   void setUp() {
     accountRepository.deleteAll();
     orderRepository.deleteAll();
     // populate test data
   }
   ```

3. HTTP requests MUST be made via `MockMvc`, including whatever headers the endpoint's security configuration requires (e.g. a bearer token when the service authenticates its callers). A service whose test profile has no authentication needs no auth headers:
   ```java
   mockMvc.perform(
       get("/accounts/00000000-0000-0000-0000-000000000100")
     )
     .andExpect(status().isOk());
   ```

4. Response validation MUST use `jsonPath()` to verify the response envelope structure and data. A successful response sets `error` to null (STD-001) — assert on `data` and, where useful, that `error` is empty:
   ```java
   mockMvc.perform(get("/accounts/" + ACCOUNT_ID_1))
     .andExpect(status().isOk())
     .andExpect(jsonPath("$.error").isEmpty())
     .andExpect(jsonPath("$.data.id").value(ACCOUNT_ID_1.toString()))
     .andExpect(jsonPath("$.data.balance").value(100.00));
   ```

5. Error scenario testing MUST verify the HTTP status code and error code in the response envelope. An error response sets `data` to null (STD-001):
   ```java
   mockMvc.perform(
       post("/accounts/00000000-0000-0000-0000-000000000100/withdraw")
         .contentType(MediaType.APPLICATION_JSON)
         .content("""{"amount": 5000.00}""")
     )
     .andExpect(status().isUnprocessableEntity())  // 422 for business error
     .andExpect(jsonPath("$.data").isEmpty())
     .andExpect(jsonPath("$.error.code").value("BUSINESS_INSUFFICIENT_BALANCE"));
   ```

6. POST/PATCH request bodies MUST be provided as JSON strings via `content()`:
   ```java
   mockMvc.perform(
       post("/accounts")
         .contentType(MediaType.APPLICATION_JSON)
         .content("""{"name": "Savings", "initialBalance": 500.00}""")
     )
     .andExpect(status().isCreated())
     .andExpect(jsonPath("$.data.id").isNotEmpty());
   ```

7. Integration tests MUST use constant test UUIDs (same as unit tests) for consistency and reproducibility.

### Contract Conformance Rules (STD-024)

These realize STD-024 for Spring Boot — proving the controller's actual request/response bodies conform to the UC's `contract.openapi.yml`. Distinct from the `jsonPath` assertions above (which check specific values): conformance validates the whole unwrapped body against the contract schema.

8. A `ContractConformance` test helper MUST be generated **once per service** (e.g. `src/test/java/.../support/ContractConformance.java`) and reused across **every** UC the service implements. IE ships no such helper; generate it following these rules, then reuse it. It:
   - **discovers contracts by scanning `.flowforge/contracts/` for every `*/contract.openapi.yml`**, loads each contract's whole `components.schemas` block (so intra-file `$ref`s resolve), and indexes the schemas **by name** into one registry — never a hardcoded single-UC path, and never the live product-hub. Write it this way from the **first** UC: a second UC's schemas are then picked up with no helper edit and no call-site change. This is the same "scan, don't hardcode a UC list" rule STD-010 Rule 20 applies to the frontend's type generation. Two contracts declaring one schema name is ordinary — every use case has an `Error`, two use cases touching one entity both declare it, and the snapshot accumulates — so **indexing by name must not silently last-one-win**: where two definitions are compatible the collision is a no-op, and where they are incompatible the **lookup MUST throw**, naming the schema and both use cases (STD-024 Rule 7 defines incompatible, and one foundation test per service MUST cover the throw).
   - unwraps the envelope — takes the `data` node (success) or the `error` node (error) from the response body (STD-001);
   - validates that node against the named contract schema with a JSON-Schema validator (e.g. `com.networknt:json-schema-validator`, test scope), after projecting the schema camelCase → snake_case **and** normalizing OpenAPI 3.0 `nullable` to JSON-Schema nullability (Rule 10).

9. Every contract operation MUST have at least one integration test that calls the helper, after the existing status/value assertions:
   ```java
   MvcResult res = mockMvc.perform(get("/accounts/" + ACCOUNT_ID_1))
       .andExpect(status().isOk())
       .andReturn();

   ContractConformance.assertResponseData(res, "GetAccountResponse");
   ```
   For an error scenario, validate the `error` body instead:
   ```java
   ContractConformance.assertResponseError(res, "Error");
   ```

10. **Project the oracle schema, never re-shape the data.** The helper adapts the **contract schema** (the oracle) before validating the raw body against it — it never transforms the response data. Two structural projections:
    - **Casing.** The contract is camelCase; the wire is snake_case (STD-001, STD-010). Rename the schema's property keys camelCase → snake_case (a transform over known keys). It MUST NOT recursively re-case response-data keys — `additionalProperties` maps carry data keys that are not field names.
    - **Nullable dialect.** The contract is OpenAPI 3.0; the validator (networknt) enforces JSON Schema draft-7, which has no `nullable` keyword. A field marked `nullable: true` (e.g. `reason: { type: string, nullable: true }`) keeps a bare `type: string` in draft-7, so a real `null` value fails validation. Normalize it: `nullable: true` → add `"null"` to the property's `type` (`type: string` → `type: ["string", "null"]`), recursing into nested `properties`, array `items`, and composed (`allOf`/`oneOf`/`anyOf`) schemas. An all-non-null hub never hits this; the first nullable field does.

11. The envelope shape (STD-001: `data`/`error`/`meta`) and the snake_case naming strategy (Jackson `SNAKE_CASE`) MUST be asserted **once per service** in a single foundation test — not on every endpoint. Per-endpoint tests then assert only the unwrapped body via the helper.

### Scenario-Key Binding Rules (STD-035)

These realize STD-035 for Spring Boot — every scenario-verifying test declares its scenario by key, so `ie scenarios coverage` can join the Surefire/Failsafe XML against the spec deterministically.

12. Every test that verifies a Gherkin scenario MUST carry the scenario's derived key (from `ie spec scenarios -u <UC-id>`) in a `@DisplayName`, key at the end after a human-readable phrase:
    ```java
    @Test
    @DisplayName("a PM creates an engagement UC-003-create-engagement#318aa8d41f26")
    void projectManagerCreatesEngagement() { ... }
    ```

13. **Maven:** Surefire and Failsafe MUST be configured to emit phrased (display) names into the XML report — by default they report the bare method name and the key never reaches the report. Enable the stateless reporter's phrased test-case names (`usePhrasedTestCaseMethodName` on `statelessTestsetReporter`, Surefire/Failsafe 3.x) in the service's build config. **Gradle:** no configuration needed — the `test` task writes `@DisplayName` text into the JUnit XML `name` attribute natively (reports land under `build/test-results/test/`). Either way this is proven once at foundation time by running `ie scenarios coverage --results <report-dir>` against the first UC's tests — a 0% result with keys visibly present in `@DisplayName` means the names are not reaching the XML.

## Examples

### Compliant: Unit test with Mockito

```java
@ExtendWith(MockitoExtension.class)
class AccountServiceTest {
  private static final UUID ACCOUNT_ID_1 = UUID.fromString("00000000-0000-0000-0000-000000000100");

  private AccountService accountService;
  private AccountRepository mockRepository;

  @BeforeEach
  void setUp() {
    mockRepository = mock(AccountRepository.class);
    accountService = new AccountService(mockRepository);
  }

  @Test
  @DisplayName("Withdraw deducts amount when balance is sufficient")
  void withdraw_sufficientBalance_deductsAmountAndReturnsNewBalance() {
    // Arrange
    BigDecimal initialBalance = new BigDecimal("100.00");
    BigDecimal withdrawAmount = new BigDecimal("30.00");
    Account account = buildAccount(ACCOUNT_ID_1, initialBalance);

    when(mockRepository.findById(ACCOUNT_ID_1))
      .thenReturn(Optional.of(account));

    // Act
    AccountResponse response = accountService.withdraw(ACCOUNT_ID_1, withdrawAmount);

    // Assert
    assertThat(response.getBalance()).isEqualByComparingTo(new BigDecimal("70.00"));
    verify(mockRepository).save(any(Account.class));
  }

  @Test
  @DisplayName("Withdraw throws exception when balance insufficient")
  void withdraw_insufficientBalance_throwsDomainException() {
    // Arrange
    BigDecimal initialBalance = new BigDecimal("20.00");
    BigDecimal withdrawAmount = new BigDecimal("30.00");
    Account account = buildAccount(ACCOUNT_ID_1, initialBalance);

    when(mockRepository.findById(ACCOUNT_ID_1))
      .thenReturn(Optional.of(account));

    // Act & Assert
    assertThatThrownBy(() -> accountService.withdraw(ACCOUNT_ID_1, withdrawAmount))
      .isInstanceOf(DomainException.class)
      .hasFieldOrPropertyWithValue("code", "BUSINESS_INSUFFICIENT_BALANCE");
  }

  @Test
  @DisplayName("Withdraw throws exception when account not found")
  void withdraw_accountNotFound_throwsDomainException() {
    // Arrange
    when(mockRepository.findById(ACCOUNT_ID_1))
      .thenReturn(Optional.empty());

    // Act & Assert
    assertThatThrownBy(() -> accountService.withdraw(ACCOUNT_ID_1, new BigDecimal("10.00")))
      .isInstanceOf(DomainException.class)
      .hasFieldOrPropertyWithValue("code", "NOT_FOUND_ACCOUNT");
  }

  private static Account buildAccount(UUID id, BigDecimal balance) {
    Account account = new Account();
    account.setId(id);
    account.setBalance(balance);
    account.setCreatedAt(LocalDateTime.now());
    account.setUpdatedAt(LocalDateTime.now());
    return account;
  }
}
```

### Compliant: Integration test verifying the response envelope

```java
@SpringBootTest
@AutoConfigureMockMvc
class AccountControllerIntegrationTest {
  private static final UUID ACCOUNT_ID_1 = UUID.fromString("00000000-0000-0000-0000-000000000100");

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private AccountRepository accountRepository;

  @BeforeEach
  void setUp() {
    accountRepository.deleteAll();
  }

  @Test
  @DisplayName("GET /accounts/{id} returns the account in the envelope")
  void getAccount_existing_returnsAccount() throws Exception {
    // Arrange
    createAndSaveAccount(ACCOUNT_ID_1, "Account 1", new BigDecimal("100.00"));

    // Act & Assert
    mockMvc.perform(get("/accounts/" + ACCOUNT_ID_1))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.error").isEmpty())
      .andExpect(jsonPath("$.data.id").value(ACCOUNT_ID_1.toString()))
      .andExpect(jsonPath("$.data.balance").value(100.00));
  }

  @Test
  @DisplayName("POST /accounts creates account with UUID and timestamps")
  void createAccount_validRequest_assignsUuidAndTimestamps() throws Exception {
    // Act
    mockMvc.perform(
        post("/accounts")
          .contentType(MediaType.APPLICATION_JSON)
          .content("""{"name": "Checking", "initialBalance": 500.00}""")
      )
      // Assert
      .andExpect(status().isCreated())
      .andExpect(jsonPath("$.error").isEmpty())
      .andExpect(jsonPath("$.data.id").isNotEmpty())
      .andExpect(jsonPath("$.data.balance").value(500.00))
      .andExpect(jsonPath("$.data.createdAt").isNotEmpty())
      .andExpect(jsonPath("$.data.updatedAt").isNotEmpty());
  }

  @Test
  @DisplayName("POST /accounts/withdraw fails with 422 when insufficient balance")
  void withdrawFunds_insufficientBalance_returns422WithErrorCode() throws Exception {
    // Arrange
    createAndSaveAccount(ACCOUNT_ID_1, "Account", new BigDecimal("50.00"));

    // Act
    mockMvc.perform(
        post("/accounts/" + ACCOUNT_ID_1 + "/withdraw")
          .contentType(MediaType.APPLICATION_JSON)
          .content("""{"amount": 100.00}""")
      )
      // Assert
      .andExpect(status().isUnprocessableEntity())  // 422
      .andExpect(jsonPath("$.data").isEmpty())
      .andExpect(jsonPath("$.error.code").value("BUSINESS_INSUFFICIENT_BALANCE"))
      .andExpect(jsonPath("$.error.message").isNotEmpty());
  }

  @Test
  @DisplayName("GET /accounts/{id} returns 404 for non-existent account")
  void getAccount_notFound_returns404WithErrorCode() throws Exception {
    // Act
    mockMvc.perform(get("/accounts/00000000-0000-0000-0000-000000000999"))
      // Assert
      .andExpect(status().isNotFound())
      .andExpect(jsonPath("$.data").isEmpty())
      .andExpect(jsonPath("$.error.code").value("NOT_FOUND_ACCOUNT"));
  }

  private Account createAndSaveAccount(UUID accountId, String name, BigDecimal balance) {
    Account account = new Account();
    account.setId(accountId);
    account.setName(name);
    account.setBalance(balance);
    account.setCreatedAt(LocalDateTime.now());
    account.setUpdatedAt(LocalDateTime.now());
    return accountRepository.save(account);
  }
}
```

### Non-Compliant: Unit test with Spring context

```java
// BAD: Using @SpringBootTest for a unit test — slow, unnecessary
@SpringBootTest
class AccountServiceTest {
  @Autowired
  private AccountService accountService;

  @MockBean
  private AccountRepository mockRepository;

  @Test
  void testWithdraw() {
    // This test loads the entire Spring context just to test one service method — waste
  }
}
```

### Non-Compliant: Non-deterministic test data

```java
// BAD: UUIDs generated randomly — tests are non-reproducible
@ExtendWith(MockitoExtension.class)
class AccountServiceTest {
  @Test
  void withdraw_sufficientBalance_deductsAmount() {
    UUID accountId = UUID.randomUUID();  // BAD: random UUID each test run
    Account account = buildAccount(accountId, new BigDecimal("100.00"));
    // ...
  }
}
```

### Non-Compliant: Asserting a non-existent `success` field

```java
// BAD: the STD-001 envelope has no `success` field — success is signalled by error == null
@Test
void getAccount_returnsAccount() throws Exception {
  mockMvc.perform(get("/accounts/" + ACCOUNT_ID_1))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.success").value(true));  // BAD: `$.success` does not exist
}
```

### Non-Compliant: Missing error code verification

```java
// BAD: Error response not validated properly
@Test
void withdraw_insufficientBalance_throwsException() {
  assertThatThrownBy(() -> accountService.withdraw(accountId, amount))
    .isInstanceOf(Exception.class);  // Too generic, error code not verified
}
```

## Applicability

- **Service types:** backend services with business logic and persistence
- **Domains:** all
- **Exceptions:** None. All backend services and controllers are tested with these patterns.

## References

- STD-001: API Response Envelope (the envelope the conformance helper unwraps; success is `error: null`, not a `success` flag)
- STD-006: Service Layer Pattern (unit tests target service methods)
- STD-007: Controller Endpoint Pattern (integration tests validate HTTP contracts)
- STD-008: Entity & Repository Pattern (integration tests use real database)
- STD-024: Code-to-Contract Conformance (the conformance rules realized here)
