---
id: STD-005
name: "Performance Budgets"
version: "1.0.0"
category: nfr
status: active
last_reviewed: "2026-04-06"
---

# Performance Budgets

> All services MUST meet quantified performance budgets for response times, page load, rendering, bundle size, and data access patterns.

## Motivation

Performance degrades incrementally — no single change causes a visible slowdown, but the cumulative effect is a sluggish product. Without explicit budgets, there is no baseline to measure against and no gate to enforce. Performance budgets provide hard constraints that code generation must satisfy and CI pipelines can enforce. A repeatable NFR pattern belongs in a standard.

## Rules

### API Performance

1. API read endpoints MUST respond within **200ms at p95**, measured at the service boundary (excluding network transit to the client).

2. API write endpoints MUST respond within **500ms at p95**, measured at the service boundary.

3. Long-running operations (>500ms) MUST NOT block the API response. They MUST be offloaded to an async processing mechanism and return **HTTP 202 Accepted** with a status/polling URL.

### Page Load Performance

4. Largest Contentful Paint (LCP) MUST be under **2.5 seconds** on a simulated 4G connection (1.6 Mbps down, 150ms RTT).

5. First Input Delay (FID) / Interaction to Next Paint (INP) MUST be under **200ms**.

6. Cumulative Layout Shift (CLS) MUST be under **0.1**.

### Client-Side Interactions

7. User interactions (click, tap) MUST produce visual feedback within **100ms**. If the underlying operation takes longer, a loading indicator MUST appear within 100ms while the operation completes.

8. List rendering MUST use virtualization (windowing) when the dataset exceeds **50 items**. Scrolling MUST maintain **60fps** (no frame drops visible to the user).

9. Search and filter inputs MUST debounce API calls with a minimum **300ms** delay to prevent excessive requests during rapid typing.

### Bundle Size

10. Total JavaScript payload for initial page load MUST NOT exceed **200KB gzipped**. This includes framework runtime, entry point, and above-the-fold components.

11. Per-route lazy-loaded chunks SHOULD NOT exceed **50KB gzipped**. Chunks exceeding this budget SHOULD be split further.

12. Image assets MUST use modern formats (WebP or AVIF with fallbacks). Images below the fold MUST be lazy-loaded.

### Data Access

13. Database queries MUST NOT use N+1 patterns. All relationships needed in a single API response MUST be fetched in a bounded number of queries — **maximum 3 queries per endpoint**.

14. Frequently accessed, rarely changed data SHOULD use caching with explicit TTL. Cache invalidation strategy MUST be documented per endpoint.

### Enforcement

15. All measurable performance budgets MUST be enforced in the **service repo's own CI workflow** — IE's `quality-gates.yml` runs no build or tests and cannot host these checks:
    - API response time: integration tests with time assertions
    - Bundle size: build-time budget check
    - Web Vitals (LCP, FID/INP, CLS): synthetic Lighthouse/Web Vitals CI checks
    - Violations produce **warnings** in development and **errors** in production builds
    - That workflow's checks MUST be required on the integration branch, or the budgets are advisory in practice

## Examples

### Compliant: Async long-running operation (pseudocode)

```
// POST /api/v1/reports/generate
function generateReport(request):
  jobId = backgroundQueue.enqueue(
    task: "generate-report",
    params: request.body
  )
  return Response(
    status: 202,
    body: envelope(
      data: { job_id: jobId, status: "processing" },
      meta: { status_url: "/api/v1/jobs/" + jobId }
    )
  )
```

### Compliant: Virtualized list threshold (pseudocode)

```
component ProductList:
  props: { products: Product[] }

  render:
    if props.products.length > 50:
      return <VirtualizedList               // windowed rendering
        items={props.products}
        itemHeight={72}
        renderItem={(product) => <ProductCard product={product} />}
      />
    else:
      return <SimpleList                    // direct rendering is fine
        items={props.products}
        renderItem={(product) => <ProductCard product={product} />}
      />
```

### Compliant: Debounced search (pseudocode)

```
component SearchBar:
  state:
    query = ""
    debouncedQuery = useDebounce(query, 300)  // 300ms minimum

  effect(debouncedQuery):
    if debouncedQuery.length >= 2:
      searchApi.fetch(debouncedQuery)

  render:
    <input
      value={query}
      onChange={(e) => setQuery(e.target.value)}
      placeholder="Search products..."
    />
```

### Compliant: Bounded queries (pseudocode)

```
// GOOD: 2 queries for an order with items
function getOrderWithItems(orderId):
  order = db.query("SELECT * FROM orders WHERE id = ?", orderId)
  items = db.query("SELECT * FROM order_items WHERE order_id = ?", orderId)
  return { ...order, items: items }
```

### Non-Compliant: N+1 query pattern

```
// BAD: N+1 queries — 1 for orders + N for items
function getOrdersWithItems():
  orders = db.query("SELECT * FROM orders LIMIT 20")
  for order in orders:
    order.items = db.query("SELECT * FROM order_items WHERE order_id = ?", order.id)
  return orders
  // Result: 21 queries instead of 2
```

### Non-Compliant: Blocking long-running operation

```
// BAD: Blocks for 30+ seconds while generating report
function generateReport(request):
  report = slowReportEngine.generate(request.body)  // blocks 30s+
  return Response(status: 200, body: envelope(data: report))
```

## Applicability

- **Service types:** all — backend rules (1-3, 13-14) apply to backend/gateway; frontend rules (4-12) apply to frontend; enforcement (15) applies to all
- **Domains:** all
- **Exceptions:** Batch processing endpoints (data imports, bulk operations) MAY exceed the 500ms write budget but MUST still use the async pattern from Rule 3. Internal admin dashboards MAY relax LCP to 4 seconds if documented in the service's constraints.

## References

- STD-001: API Response Envelope (async operations use the envelope with 202 status)
- STD-004: Component Structure (virtualization and rendering rules affect component design)
- Web Vitals: LCP, FID/INP, CLS thresholds align with Google's "good" thresholds
