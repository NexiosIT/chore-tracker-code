---
id: STD-008
name: "Entity & Repository Pattern"
version: "1.1.0"
category: spring-boot
status: active
last_reviewed: "2026-07-18"
discovery_layer: "generation-extracted"
---

# Entity & Repository Pattern

> Entities MUST use an application-assigned primary key (UUID by default, or the contract's declared id type), avoid relational mapping in code, use enums for domain types, and maintain audit timestamps. Repositories MUST use Specifications for complex filtering and support batch loading to prevent N+1 problems. Migrations MUST follow sequential naming and define indexes separately.

## Motivation

Without consistent entity and repository patterns, generated code scatters data access logic unpredictably. Relational mapping creates tight coupling. Auto-increment IDs make sharding impossible. Migrations conflict. A standard pattern ensures entities are durable, portable, and consistent across features.

## Rules

### Entity Rules

1. Every entity MUST use an **application-assigned** `@Id` primary key, never a database-generated auto-increment integer. **UUID is the default** and SHOULD be used unless the contract pins a different id type:
   ```java
   @Id
   private UUID id;
   ```
   When the UC's `contract.openapi.yml` declares the resource `id` as a non-UUID string (an external code or human-readable identifier), the entity's `@Id` MUST match the contract's type (e.g. `private String id;`). The contract is authoritative for the id's wire type; this rule only forbids database-generated surrogate keys.

2. Enum fields MUST use `@Enumerated(EnumType.STRING)` for database portability (not ordinal-based, which breaks on enum reordering).

3. Monetary/financial columns MUST use `BigDecimal` with `@Column(precision=12, scale=2)` to enforce database-level precision:
   ```java
   @Column(name = "balance", precision = 12, scale = 2)
   private BigDecimal balance;
   ```

4. Column names MUST be `snake_case` in the database:
   ```java
   @Column(name = "created_at")
   private LocalDateTime createdAt;
   ```

5. Reserved SQL keywords in column names MUST be escaped in the `@Column(name="...")` annotation (e.g., `status`, `type`, `order`).

6. Audit fields (`createdAt`, `updatedAt`) MUST be present on every entity and use `LocalDateTime` (UTC):
   ```java
   @Column(name = "created_at", nullable = false, updatable = false)
   private LocalDateTime createdAt;

   @Column(name = "updated_at", nullable = false)
   private LocalDateTime updatedAt;
   ```

7. Entities are **dumb data holders** — they contain ONLY fields, getters, setters, and `@Embeddable` value objects. Zero business logic. No `@PrePersist` hooks that perform calculations.

8. **Relational mappings are prohibited.** No `@ManyToOne`, `@OneToMany`, `@ManyToMany`. Use UUID foreign key fields instead. If you need related entities, load them separately in the service layer via repository queries.

9. `equals()` and `hashCode()` MUST NOT be overridden. Use default object identity.

### Repository Rules

1. Repository interfaces MUST extend both `JpaRepository<Entity, UUID>` AND `JpaSpecificationExecutor<Entity>` to support both simple queries and complex Specifications.

2. Batch loading MUST use `findByIdIn()` or equivalent to prevent N+1 queries:
   ```java
   List<Order> findByIdIn(Collection<UUID> ids);
   ```

3. When using `JpaSpecificationExecutor`, compose predicates for complex or dynamic filtering. Keep each Specification focused and reusable:
   ```java
   Specification<Order> spec = (root, query, cb) ->
     cb.equal(root.get("status"), "PENDING");
   List<Order> orders = orderRepository.findAll(spec);
   ```

4. Free-text search MUST use case-insensitive matching on both sides:
   ```java
   Specification<Product> spec = (root, query, cb) ->
     cb.like(
       cb.lower(root.get("name")),
       "%" + searchTerm.toLowerCase() + "%"
     );
   ```

5. Pagination is 1-based in HTTP requests. Controllers MUST convert to 0-based before passing to `PageRequest`:
   ```java
   // HTTP request: page=1 (first page)
   // Convert to: PageRequest.of(0, size)
   PageRequest pageRequest = PageRequest.of(httpPageNumber - 1, pageSize);
   Page<Order> page = orderRepository.findAll(spec, pageRequest);
   ```

6. Repositories MAY provide custom query methods with `@Query` for complex scenarios. The service layer decides which query method to use based on the use case.

### Migration Rules

1. Flyway migrations MUST follow the naming convention `V{YYYYMMDD}_{sequence}__{description}.sql` (e.g., `V20260401_01__create_users_table.sql`). Versions MUST be sequential with no gaps.

2. Every table MUST declare its primary key on the entity's id column:
   ```sql
   CREATE TABLE accounts (
     id UUID PRIMARY KEY,
     balance NUMERIC(12, 2) NOT NULL,
     created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
     updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
   );
   ```

3. Enum columns MUST be defined as `VARCHAR` with a `CHECK` constraint:
   ```sql
   CREATE TABLE orders (
     id UUID PRIMARY KEY,
     status VARCHAR(50) NOT NULL CHECK(status IN ('PENDING', 'PROCESSING', 'COMPLETED'))
   );
   ```

4. Monetary columns MUST use `NUMERIC(12, 2)` precision:
   ```sql
   ALTER TABLE accounts ADD COLUMN balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
   ```

5. Primary keys are application-assigned and MUST NOT use database-level sequence or auto-increment generation.

6. Indexes MUST be created in a **separate migration** from the schema creation. Use meaningful index names:
   ```sql
   CREATE INDEX idx_orders_status ON orders(status);
   CREATE INDEX idx_accounts_created ON accounts(created_at DESC);
   ```

## Examples

### Compliant: Entity with all fields

```java
@Entity
@Table(name = "orders")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Order {
  @Id
  private UUID id;

  @Column(name = "customer_id", nullable = false)
  private UUID customerId;  // FK as UUID, not @ManyToOne

  @Column(name = "status", nullable = false)
  @Enumerated(EnumType.STRING)
  private OrderStatus status;

  @Column(name = "total_amount", precision = 12, scale = 2)
  private BigDecimal totalAmount;

  @Column(name = "created_at", nullable = false, updatable = false)
  private LocalDateTime createdAt;

  @Column(name = "updated_at", nullable = false)
  private LocalDateTime updatedAt;
}
```

### Compliant: Repository

```java
public interface OrderRepository extends JpaRepository<Order, UUID>, JpaSpecificationExecutor<Order> {
  List<Order> findByStatus(OrderStatus status);

  List<Order> findByIdIn(Collection<UUID> ids);

  Page<Order> findAll(Pageable pageable);
}
```

### Compliant: Specifications for complex filtering

```java
@Component
public class OrderSpecifications {
  public static Specification<Order> withStatus(OrderStatus status) {
    return (root, query, cb) -> cb.equal(root.get("status"), status);
  }

  public static Specification<Order> createdAfter(LocalDateTime date) {
    return (root, query, cb) -> cb.greaterThan(root.get("createdAt"), date);
  }

  public static Specification<Order> search(String customerName) {
    return (root, query, cb) ->
      cb.like(cb.lower(root.get("customerName")), "%" + customerName.toLowerCase() + "%");
  }
}
```

### Compliant: Migration with schema and indexes

```sql
-- V20260401_01__create_orders_table.sql
CREATE TABLE orders (
  id UUID PRIMARY KEY,
  customer_id UUID NOT NULL,
  status VARCHAR(50) NOT NULL CHECK(status IN ('PENDING', 'PROCESSING', 'COMPLETED')),
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- V20260401_02__create_orders_indexes.sql
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

### Non-Compliant: Entity with business logic

```java
// BAD: Entity contains calculations (business logic forbidden)
@Entity
@Table(name = "orders")
public class Order {
  @Id
  private UUID id;

  private BigDecimal itemTotal;
  private BigDecimal taxAmount;

  // BAD: calculation logic in entity
  public BigDecimal getGrandTotal() {
    return itemTotal.add(taxAmount).multiply(new BigDecimal("1.1"));
  }
}
```

### Non-Compliant: Relational mapping instead of UUID FK

```java
// BAD: @ManyToOne creates tight coupling, prevents sharding
@Entity
@Table(name = "orders")
public class Order {
  @Id
  private UUID id;

  @ManyToOne(fetch = FetchType.LAZY)  // BAD
  @JoinColumn(name = "customer_id")
  private Customer customer;  // Navigating relationships in code
}

// Load logic now tied to ORM — hard to scale
Order order = orderRepository.findById(orderId).orElseThrow();
String customerName = order.getCustomer().getName();  // Implicit lazy load, N+1 risk
```

### Non-Compliant: Enum with ordinal mapping

```java
// BAD: Ordinal mapping breaks if enum is reordered
@Entity
public class Order {
  @Enumerated(EnumType.ORDINAL)  // BAD
  private OrderStatus status;
}
```

### Non-Compliant: Database-generated surrogate key

```java
// BAD: Auto-increment key is database-generated — violates Rule 1
@Entity
public class Order {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)  // BAD
  private Long id;
}
```

### Non-Compliant: Pagination not converting from 1-based to 0-based

```java
// BAD: HTTP page=1 passed directly to PageRequest without conversion
@Transactional(readOnly = true)
public Page<Order> listOrders(int page, int size) {
  // page=1 from HTTP is passed as 1 to PageRequest — off by one
  PageRequest pageRequest = PageRequest.of(page, size);  // Wrong
  return orderRepository.findAll(pageRequest);
}

// CORRECT:
PageRequest pageRequest = PageRequest.of(page - 1, size);
```

## Applicability

- **Service types:** backend services with persistent data
- **Domains:** all
- **Exceptions:** None. All entity and repository layers follow this pattern.

## References

- STD-006: Service Layer Pattern (services call repositories, manage transactions)
- STD-002: Error Handling Strategy (repositories throw DomainException for not found)
