# Hands-On Engineering Labs

Use these labs to turn the repository's explanations into working engineering judgment. Each lab connects related guides, begins with a deliberately weak design, names the invariant, introduces failure cases, and ends with observable acceptance criteria.

The practice method is informed by Fanout’s advice to define the invariant and fault model first, build in stages, make failures observable, and finish with an engineering note. See [System design labs for distributed systems](https://www.fanout.sh/blog/system-design-labs-for-distributed-systems-engineers) and the [Fanout System Design roadmap](https://fanout.sh/roadmaps/system-design).

## Lab Index

1. [Lab 1 — Dependency Injection and Service Boundaries](#lab-1--dependency-injection-and-service-boundaries)
2. [Lab 2 — Idempotency, Transactions, and the Outbox Pattern](#lab-2--idempotency-transactions-and-the-outbox-pattern)
3. [Lab 3 — SQL, EF Core, Concurrency, and Pagination](#lab-3--sql-ef-core-concurrency-and-pagination)
4. [Lab 4 — Durable Queues, Backpressure, and Worker Recovery](#lab-4--durable-queues-backpressure-and-worker-recovery)
5. [Lab 5 — Angular, RxJS, and UI State](#lab-5--angular-rxjs-and-ui-state)
6. [Lab 6 — Fan-Out, Fan-In, and Tail Latency](#lab-6--fan-out-fan-in-and-tail-latency)
7. [Lab 7 — Search Indexing, Ranking, and Safe Rebuilds](#lab-7--search-indexing-ranking-and-safe-rebuilds)
8. [Lab 8 — System Design and Failure Analysis](#lab-8--system-design-and-failure-analysis)

## How to Use a Lab

For every lab, create a short `engineering-note.md` containing:

```text
Goal:
Invariant — what must always remain true:
Fault model — which failures are in scope:
Architecture and ownership:
Test strategy:
Failure timeline observed:
Metrics/traces used to explain it:
Trade-offs and weaker guarantees:
What remains risky:
```

Build in small stages. Keep the system runnable after each stage so you know which assumption caused a regression.

1. Make the single-process happy path work.
2. Add deterministic tests for the invariant.
3. Introduce concurrency or asynchronous work.
4. Inject one named failure.
5. Add recovery and prove the invariant again.
6. Measure latency, throughput, resource use, or recovery time.
7. Write the engineering note in your own words.

## Mastery Rubric

Score each lab from 0 to 4. Do not award points for code volume.

| Score | Evidence |
|---:|---|
| 0 — Recognize | You can identify the terms only after reading the guide. |
| 1 — Explain | You can explain the problem and draw the main flow without notes. |
| 2 — Implement | The happy path works and has focused tests. |
| 3 — Recover | Named failures are injected; recovery preserves the invariant. |
| 4 — Operate | Metrics, security, rollout, capacity, and trade-offs are documented and tested. |

The goal is not to score 4 immediately. Record the smallest missing piece and revisit it after one day and one week.

---

## Lab 1 — Dependency Injection and Service Boundaries

**Study first:** [Dependency Injection](dependency-injection.md), [Backend Design Patterns](backend-design-patterns.md), and [Angular frontend patterns](angular.md#frontend-design-patterns).

**Invariant:** A valid checkout either returns one order identifier or a stable expected rejection. Infrastructure construction must not be hidden inside business classes.

**Starting design:**

```csharp
public sealed class CheckoutService
{
    public async Task<Guid> Checkout(CreateOrder request)
    {
        using var db = new AppDbContext("production-connection");
        var payment = new PaymentSdk(Environment.GetEnvironmentVariable("PAYMENT_KEY"));
        await payment.Charge(request.CardToken, request.Total);
        var order = new Order(request.CustomerId, request.Total);
        db.Add(order);
        await db.SaveChangesAsync();
        return order.Id;
    }
}
```

**Build stages:**

1. Extract application-shaped ports such as `IPaymentGateway`, `IOrderRepository`, `IClock`, and `IUnitOfWork`.
2. Make required dependencies constructor parameters; keep runtime request data in the method parameters.
3. Create one composition root that chooses real adapters and lifetimes.
4. Return a typed result for expected rejection; let unexpected failures remain exceptions.
5. Add an Angular checkout facade that owns request state while the component owns rendering and user interaction.
6. Write unit tests with a controlled clock and payment fake, adapter contract tests, and one composition-root resolution test.

**Failure drills:**

- payment declines normally;
- payment times out;
- database save fails after payment succeeds;
- two users check out concurrently;
- the client disconnects during a cancellable read.

**Observable definition of done:**

- no business class calls the container or constructs provider/database clients;
- lifetime validation succeeds;
- expected errors map to stable API codes;
- tests prove dependencies and time are controllable;
- logs contain an order correlation ID but no card token or secret.

**Stretch:** Introduce an outbox so post-order communication is not performed inside the request transaction.

---

## Lab 2 — Idempotency, Transactions, and the Outbox Pattern

**Study first:** [ASP.NET Core API Design](aspnet-core-api-design.md#aspa-mastery), [Distributed Systems Patterns](distributed-systems-patterns.md), and [Entity Framework](entity-framework.md).

**Invariant:** Ten retries of the same accepted command create one order and one logical `OrderPlaced` event. Reusing the key with a different request is rejected.

**Starting design:**

```csharp
app.MapPost("/orders", async (CreateOrder request, AppDbContext db, EventBus bus) =>
{
    var order = Order.Create(request);
    db.Add(order);
    await db.SaveChangesAsync();
    await bus.Publish(new OrderPlaced(order.Id));
    return Results.Created($"/orders/{order.Id}", order);
});
```

**Build stages:**

1. Require an idempotency key scoped by tenant and operation.
2. Hash a canonical request representation and add a unique database constraint.
3. Store the order, replayable response, and outbox entry in one local transaction.
4. Relay unpublished outbox rows with bounded batches and safe multi-worker claiming.
5. Make the consumer idempotent with an inbox or effect-specific unique key.
6. Add status and trace correlation so an operator can follow request → transaction → relay → consumer.

**Failure drills:** Crash at each boundary:

1. before the transaction;
2. after the order insert but before commit;
3. after commit but before the HTTP response;
4. after event publication but before marking the outbox row published;
5. after consumer effect but before acknowledgement.

**Observable definition of done:**

- concurrent identical requests return the same order ID;
- a different payload with the same key returns conflict;
- no committed order lacks an outbox record;
- duplicate publication does not duplicate the consumer effect;
- oldest unpublished age and retry count are visible metrics.

**Stretch:** Forward the stable idempotency key to a fake payment provider and model the payment as a recoverable state machine.

---

## Lab 3 — SQL, EF Core, Concurrency, and Pagination

**Study first:** [SQL Server](sql-server.md), [Entity Framework](entity-framework.md), and [System Design Technologies](technologies-fundamentals.md#tech-mastery).

**Invariant:** A stock item never becomes negative, and a paginated product query stays below its latency target for the representative dataset.

**Starting design:**

```csharp
var products = await db.Products
    .Include(x => x.Reviews)
    .ToListAsync(ct);

return products
    .Where(x => x.Name.Contains(term, StringComparison.OrdinalIgnoreCase))
    .Skip(page * 100)
    .Take(100);
```

**Build stages:**

1. Seed enough representative rows for the query planner to make realistic choices.
2. Capture generated SQL and the actual execution plan.
3. Project only required fields and move filtering/pagination to the database.
4. Add an index whose leading columns match the filter and stable sort.
5. Replace deep offset pagination with a unique cursor when the use case permits it.
6. Protect stock using an atomic conditional update or an explicit concurrency token.
7. Add a retry policy only for the specific concurrency/deadlock outcome that is safe to retry.

**Failure drills:**

- 100 buyers attempt to purchase the last 10 units;
- two rows share the same visible sort timestamp;
- a row is inserted between page requests;
- the query parameter has no matches;
- the database cancels a deliberately slow query.

**Observable definition of done:**

- the execution plan uses the intended access path without an avoidable full materialization;
- pagination returns no duplicate or skipped stable rows under concurrent inserts;
- exactly 10 purchases succeed and stock ends at zero;
- cancelled work releases the database connection;
- query latency and concurrency-conflict rate are measured.

**Stretch:** Compare database full-text search with a separate index and write the threshold that would justify the added system.

---

## Lab 4 — Durable Queues, Backpressure, and Worker Recovery

**Study first:** [TECH-M3 queue lag](technologies-fundamentals.md#tech-m3--queue-lag-backpressure-and-useful-autoscaling), [TECH-M4 PostgreSQL queue](technologies-fundamentals.md#tech-m4--a-postgresql-work-queue-with-skip-locked), and [Distributed Systems Patterns](distributed-systems-patterns.md).

**Invariant:** Once a job is accepted, it remains discoverable until it succeeds or reaches a visible terminal failure state. A duplicate attempt cannot create two final effects.

**Build stages:**

1. Store job state, availability time, attempts, lease owner, lease expiry, and an idempotency/effect key.
2. Claim ordered batches atomically with a short transaction.
3. Process outside the claim transaction and acknowledge conditionally.
4. Recover expired leases and add exponential backoff with jitter.
5. Move permanent/poison failures into a visible parking state with repair metadata.
6. Reject or defer new work when the promised completion time cannot be met.
7. Export depth, oldest-ready age, processing duration, attempt count, and dead-letter age.

**Failure drills:**

- kill a worker immediately after claim;
- kill it after creating the external effect but before acknowledgement;
- delay one job beyond its lease;
- enqueue a permanently invalid payload;
- make arrival rate exceed completion rate for five minutes.

**Observable definition of done:**

- two workers never own the same active lease;
- expired jobs recover without duplicate final effects;
- poison work does not block healthy work;
- overload produces a deliberate response instead of unbounded growth;
- the dashboard can predict time-to-drain from measured rates.

**Stretch:** Replace the database queue with a broker and document which guarantees, costs, and operational responsibilities changed.

---

## Lab 5 — Angular, RxJS, and UI State

**Study first:** [Angular](angular.md), [RxJS](rxjs.md), [NgRx](ngrx.md), and [TypeScript](typescript.md).

**Invariant:** The UI never displays results for an older query after a newer query has been entered. Loading, empty, error, and success states are explicit and accessible.

**Starting design:**

```typescript
search(term: string) {
  this.loading = true;
  this.http.get<Product[]>(`/api/search?q=${term}`).subscribe(items => {
    this.items = items;
    this.loading = false;
  });
}
```

**Build stages:**

1. Represent the term as a typed input stream or signal.
2. Normalize, debounce, and ignore identical queries.
3. Use `switchMap` so a new query unsubscribes from the stale request.
4. Model `idle | loading | success | empty | error` as one discriminated state.
5. Move API mapping and error normalization behind an adapter/facade.
6. Render semantic status text, keyboard focus behavior, and retry controls.
7. Test with virtual time or controlled observables rather than real delays.

**Failure drills:**

- make query A respond after query B;
- return an empty result;
- return a typed validation error and an unexpected server error;
- destroy the component while a request is active;
- simulate a slow network and rapid typing.

**Observable definition of done:**

- stale result A never replaces current result B;
- request cancellation is visible in the browser/network test;
- every state has one accessible rendering;
- the component contains no transport DTO mapping;
- tests assert behavior, not private implementation details.

**Stretch:** Add cursor pagination without allowing page-two results from an old query to enter the current state.

---

## Lab 6 — Fan-Out, Fan-In, and Tail Latency

**Study first:** [TECH-M2 fan-out and tail latency](technologies-fundamentals.md#tech-m2--fan-out-fan-in-and-tail-latency), [Scatter-Gather](distributed-systems-patterns.md#dsp-19-scatter-gather-pattern), and [Production Scenarios](production-scenarios.md).

**Invariant:** The aggregator returns within its deadline and states whether the answer is complete. Work that cannot affect the answer is cancelled.

**Build stages:**

1. Create 20 local shard processes or controlled test doubles.
2. Give most calls low latency and a small percentage a long-tail delay.
3. Measure branch and aggregate p50/p95/p99 separately.
4. Add a single end-to-end deadline and cancellation propagation.
5. Bound fan-out and define the minimum successful branches or quorum.
6. Add partial-result semantics only if the product permits them.
7. Experiment with a delayed hedge for idempotent reads and measure added load.

**Failure drills:**

- one slow shard;
- five unavailable shards;
- a hot shard receiving disproportionate traffic;
- the client disconnecting before completion;
- a retry policy that accidentally doubles fan-out.

**Observable definition of done:**

- traces show every branch under one logical request;
- p99 is measured rather than inferred from averages;
- unfinished branches stop after the response decision;
- partial responses cannot be mistaken for complete ones;
- the report includes latency improvement and extra request cost of hedging.

**Stretch:** Compare fan-out-on-write, fan-out-on-read, and a hybrid design for a celebrity social feed.

---

## Lab 7 — Search Indexing, Ranking, and Safe Rebuilds

**Study first:** [TECH-M7 search synchronization](technologies-fundamentals.md#tech-m7--search-index-synchronization-ranking-and-evaluation), [Search and Indexing](technologies-fundamentals.md#search), and [AI Engineering Design](ai-engineering-design.md).

**Invariant:** Every committed source record eventually appears in the active index at its newest version, and a complete rebuild can occur while writes continue.

**Build stages:**

1. Create a small source database and an outbox/change stream.
2. Build an idempotent indexer using per-document source versions.
3. Implement query analysis, inverted retrieval, and a clear ranking formula.
4. Create 20 judged queries with expected relevant documents.
5. Measure recall at K and one rank-aware metric before tuning.
6. Rebuild into a new index version, catch up changes, verify, and switch an alias.
7. Add authorization/tenant filtering that cannot be bypassed by the index.

**Failure drills:**

- deliver changes twice and out of order;
- reject one malformed document;
- stop the indexer for ten minutes;
- change the document schema;
- fail during alias switch or rebuild catch-up.

**Observable definition of done:**

- indexing lag and rejected-document count are visible;
- old events cannot overwrite newer documents;
- rebuild produces the expected document count and judged-query quality;
- rollback to the previous alias is immediate;
- protected documents never appear for an unauthorized principal.

**Stretch:** Add hybrid lexical/vector retrieval and prove the change improves the judged set rather than only a demonstration query.

---

## Lab 8 — System Design and Failure Analysis

**Study first:** [System Design Interview Guide](system-design-interview-guide.md), [System Design Fundamentals](system-design-fundamentals-extended.md), and [HLD](hld.md).

Choose one: notification service, ticket booking, collaborative editor, file sync, search service, or social feed.

**Invariant:** Write one sentence naming the most important guarantee. Examples: “a confirmed seat is never sold twice” or “an acknowledged edit is recoverable after one node fails.”

**45-minute design sequence:**

1. Clarify actors, scope, non-goals, and success criteria.
2. Estimate traffic, storage, bandwidth, and peak factor with units.
3. Define APIs/events, stable errors, authorization, and idempotency.
4. Model data ownership, indexes, retention, and deletion.
5. Draw the critical write and read paths.
6. Deepen one risk: consistency, ordering, fan-out, hot keys, or recovery.
7. Define degradation, backpressure, retry ownership, and manual recovery.
8. Add SLOs, metrics, traces, alerts, rollout, rollback, and cost.

**Failure review after the design:**

- Which state was acknowledged but not durable?
- What happens when a message is duplicated or reordered?
- Which dependency controls tail latency?
- Where can one tenant consume another tenant’s capacity or data?
- What is the largest blast radius?
- How is a bad schema or deployment rolled back?
- Can backup data actually be restored within the recovery objective?

**Observable definition of done:**

- every arrow in the diagram names data/protocol and ownership;
- estimates can be recalculated when one assumption changes;
- the design states at least two rejected alternatives;
- one failure timeline shows detection, containment, recovery, and repair;
- a reviewer can identify the next bottleneck without asking for hidden assumptions.

**Stretch:** Implement the smallest critical slice and run one of the named failure experiments instead of stopping at the diagram.

---

## Suggested Evidence Portfolio

Keep evidence small and inspectable:

| Artifact | What it proves |
|---|---|
| One architecture diagram | You understand boundaries and data flow |
| One invariant and fault model | You know what correctness means |
| Before/after code diff | You can improve a concrete design |
| Deterministic concurrency/failure test | Recovery is not wishful thinking |
| Trace or metric screenshot/export | You can explain runtime behavior |
| Capacity calculation | Scale claims have units and assumptions |
| Short engineering note | You can communicate trade-offs and remaining risk |

Do not wait for a perfect portfolio. One deeply tested lab is stronger evidence than ten copied projects.
