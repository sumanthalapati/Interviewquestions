# Systems & Software Engineering Practice Workbook

This workbook connects the repository's algorithm, architecture, distributed-systems, security, cloud, operations, quality, and engineering-communication guides. It is designed for repeated closed-book practice: explain the invariant, inspect a weak design, produce a corrected design, test failure behavior, and name the evidence that proves it works.

## How to Use This Workbook

For every module:

1. Answer the questions without notes.
2. Draw the request/data/failure flow.
3. Compare your answer with the key.
4. Run the build or failure task.
5. Record what failed, why, and which metric/test exposed it.

## Module Index

1. [Algorithms, data structures, and complexity](#1-algorithms-data-structures-and-complexity)
2. [Object-oriented design, SOLID, and patterns](#2-object-oriented-design-solid-and-patterns)
3. [Low-level design, domain modeling, and concurrency](#3-low-level-design-domain-modeling-and-concurrency)
4. [System-design method, requirements, and capacity](#4-system-design-method-requirements-and-capacity)
5. [API contracts, protocols, compatibility, and pagination](#5-api-contracts-protocols-compatibility-and-pagination)
6. [Caching, CDNs, load balancing, and traffic management](#6-caching-cdns-load-balancing-and-traffic-management)
7. [Storage, replication, sharding, and consistency](#7-storage-replication-sharding-and-consistency)
8. [Queues, streams, events, and idempotency](#8-queues-streams-events-and-idempotency)
9. [Timeouts, retries, backpressure, and resilience](#9-timeouts-retries-backpressure-and-resilience)
10. [Real-time, collaborative, and social systems](#10-real-time-collaborative-and-social-systems)
11. [Security, identity, authorization, and threat modeling](#11-security-identity-authorization-and-threat-modeling)
12. [Cloud, containers, Kubernetes, and infrastructure](#12-cloud-containers-kubernetes-and-infrastructure)
13. [CI/CD, Azure DevOps, rollout, and recovery](#13-cicd-azure-devops-rollout-and-recovery)
14. [Observability, incidents, and production diagnosis](#14-observability-incidents-and-production-diagnosis)
15. [Testing strategy, code review, and technical debt](#15-testing-strategy-code-review-and-technical-debt)
16. [Behavioral judgment and technical communication](#16-behavioral-judgment-and-technical-communication)

---

## 1. Algorithms, Data Structures, and Complexity

**Study first:** [DSA](dsa.md), [Entry-Level Questions](entry-level-questions.md), and [Company Interview Guides](company-specific-interview-guides.md).

### Concept map

Choose a representation and algorithm from constraints, not from the problem's nouns. State time and auxiliary-space complexity, prove the invariant, test edge cases, and explain the trade-off between preprocessing, memory, update cost, and query cost.

### Practice questions

1. When does a hash table beat a balanced tree, and when does it not?
2. Explain the loop invariant for binary search and why `mid = low + (high-low)/2` is safer.
3. Compare BFS, DFS, Dijkstra, and topological sorting by graph assumptions and output.
4. How do a heap and a full sort differ for top-`k` streaming data?
5. What makes dynamic programming different from ordinary recursion or greedy choice?

### Wrong/before example

```csharp
// Sorts every element even though only the largest k are required.
public static int[] TopK(int[] values, int k) =>
    values.OrderByDescending(x => x).Take(k).ToArray();
```

### Corrected/after example

```csharp
public static int[] TopK(IEnumerable<int> values, int k)
{
    if (k < 0) throw new ArgumentOutOfRangeException(nameof(k));
    var heap = new PriorityQueue<int, int>();

    foreach (var value in values)
    {
        heap.Enqueue(value, value);
        if (heap.Count > k)
            heap.Dequeue();
    }

    return heap.UnorderedItems.Select(x => x.Element)
        .OrderByDescending(x => x)
        .ToArray();
}
```

### Answer key

1. Hash tables give expected `O(1)` exact lookup/update and are ideal when order/range queries are irrelevant; trees give deterministic `O(log n)`, ordered iteration, predecessor/successor, and range operations. Hash quality, collision attacks, resizing, memory overhead, and worst-case guarantees matter.
2. One useful invariant is: if the target exists, it lies in the inclusive search interval `[low, high]`. Each comparison removes a region that cannot contain the target. The safer midpoint avoids `low+high` overflow in fixed-width integer languages.
3. BFS gives shortest unweighted edge count and explores levels; DFS explores depth and supports cycle/component/backtracking reasoning; Dijkstra finds shortest paths with nonnegative weights; topological sorting orders a DAG so every dependency precedes its dependent.
4. Sorting costs `O(n log n)` and stores all results. A min-heap of size `k` uses `O(n log k)` time and `O(k)` retained state, which fits streams. Sorting may be simpler or faster when `k≈n` or all-order output is needed.
5. DP has overlapping subproblems and an optimal-substructure recurrence; memoization/tabulation ensures each state is solved once. Greedy choice needs a proof that a locally optimal step can be extended globally. Recursion alone may repeat exponential work.

### Production and failure checks

- Test empty, singleton, duplicate, sorted/reverse, overflow, invalid-parameter, and maximum-size inputs.
- State whether complexity is worst-case, amortized, or expected.
- Include data-loading, allocation, hashing/comparison, and output-order costs.
- Prefer measured simple solutions until constraints justify sophistication.

### Build/debug task

Implement binary search, LRU cache, top-`k`, shortest path, and one DP problem. Add property-based tests that compare each optimized implementation with a slow reference on generated small inputs.

---

## 2. Object-Oriented Design, SOLID, and Patterns

**Study first:** [OOP & Design Patterns](oop-design-patterns.md), [Backend Patterns](backend-design-patterns.md), and [Dependency Injection](dependency-injection.md).

### Concept map

Objects should protect invariants and expose behavior at a cohesive boundary. SOLID principles are diagnostic tools, not goals to maximize. Patterns name recurring forces and trade-offs; use them when they reduce coupling or make variation explicit, not to increase class count.

### Practice questions

1. Distinguish encapsulation from merely making fields private.
2. Give a Liskov Substitution Principle violation that compiles successfully.
3. Compare Strategy, State, Command, Decorator, and Adapter by the variation they isolate.
4. When is composition preferable to inheritance, and when is inheritance valid?
5. How does dependency injection differ from the service-locator anti-pattern?

### Wrong/before example

```csharp
public sealed class InvoiceService
{
    public void Send(Invoice invoice)
    {
        var repository = new SqlInvoiceRepository("prod-connection");
        repository.Save(invoice);
        new SmtpClient("mail.internal").Send(invoice.ToEmail());
    }
}
```

### Corrected/after example

```csharp
public sealed class InvoiceService(
    IInvoiceRepository repository,
    IInvoiceNotifier notifier,
    IClock clock)
{
    public async Task IssueAsync(Invoice invoice, CancellationToken cancellationToken)
    {
        invoice.Issue(clock.GetUtcNow());
        await repository.SaveAsync(invoice, cancellationToken);
        await notifier.NotifyIssuedAsync(invoice.Id, cancellationToken);
    }
}
```

### Answer key

1. Encapsulation keeps a valid state by controlling operations and hiding representational choices. Private setters with an `UpdateEverything` method may still expose invalid transitions; a behavior such as `Approve(approver, time)` can enforce the rule.
2. A subtype that throws for a valid base operation, strengthens preconditions, weakens postconditions, or changes observable semantics violates substitutability even though method signatures match—for example a read-only collection subtype whose inherited `Add` throws.
3. Strategy selects an interchangeable algorithm; State changes behavior with lifecycle state; Command packages an action/request; Decorator adds behavior around the same interface; Adapter translates an incompatible interface/protocol.
4. Composition is safer for reusable capabilities and runtime variation without inheriting unwanted contracts. Inheritance is valid for a genuine stable “is-a” abstraction whose substitutability is tested and whose protected extension surface is intentional.
5. DI supplies declared dependencies at a composition boundary. Service location lets behavior request hidden dependencies from a container at runtime, weakening readability, validation, and test control.

The corrected example improves dependency ownership and testability, but DI does not make `SaveAsync` and `NotifyIssuedAsync` one atomic operation. If notification must eventually happen whenever an invoice commits, save an outbox record with the invoice and let an idempotent worker deliver it. If notification is only best effort, state that contract explicitly and expose the failure through metrics or status.

### Production and failure checks

- Test invariants, subtype contracts, decorator order, lifetime/scope, and composition-root resolution.
- Avoid interfaces with only one accidental implementation unless they protect a boundary or test seam.
- Record pattern trade-offs and delete abstractions whose variation never materialized.
- Keep I/O, time, randomness, and external state explicit at business boundaries.

### Build/debug task

Refactor a checkout class that constructs database/payment/email clients. Introduce ports, a composition root, typed expected failures, and tests proving time and external effects are controllable. Explain every abstraction you did not introduce.

---

## 3. Low-Level Design, Domain Modeling, and Concurrency

**Study first:** [Low-Level Design](lld.md), [OOP & Design Patterns](oop-design-patterns.md), and [Concurrency/Code Flow](dotnet-code-flow.md).

### Concept map

Low-level design translates use cases and invariants into responsibilities, state transitions, interfaces, data structures, concurrency ownership, and extension points. Model the unsafe race and failure timeline before choosing locks, queues, optimistic versions, or actors.

### Practice questions

1. How do entity, value object, aggregate, service, and repository responsibilities differ?
2. Design a parking lot or elevator by invariants rather than class nouns.
3. Compare pessimistic locking, optimistic concurrency, atomic operations, and single-owner serialization.
4. Why is thread safety not guaranteed by using a concurrent collection?
5. What makes an API operation idempotent under concurrent retries?

### Wrong/before example

```csharp
if (inventory.Available >= quantity)
{
    inventory.Available -= quantity; // two requests can both pass the check
    await repository.SaveAsync(inventory);
}
```

### Corrected/after example

```sql
UPDATE Inventory
SET Available = Available - @Quantity,
    Version = Version + 1
WHERE ProductId = @ProductId
  AND Available >= @Quantity
  AND Version = @ExpectedVersion;

-- Exactly one row means the invariant was preserved for this attempt.
```

```csharp
if (affectedRows != 1)
    return ReservationResult.ConflictOrInsufficientStock();
```

### Answer key

1. An entity has continuity/identity; a value object is defined by values and is usually immutable; an aggregate is a consistency boundary with one entry root; a domain service holds behavior that fits no one object; a repository abstracts aggregate persistence, not every table query.
2. Begin with constraints such as one vehicle per occupied spot, only compatible spot types, one active ticket, and atomic assignment/release. Then assign an owner for allocation, state transitions, pricing, and persistence; names alone do not reveal races.
3. Pessimistic locks prevent concurrent access but block/deadlock; optimistic versions detect conflict and retry/reject; atomics fit small single-memory updates; single-owner queues/actors serialize a key's decisions but add messaging and availability considerations.
4. A concurrent dictionary makes individual operations safe, not a multi-step invariant across reads/writes or values. `ContainsKey` followed by `Add`, or updates across two collections, can still race.
5. Give the logical command a stable idempotency key, bind it to a request fingerprint/principal, atomically reserve/store result with the effect, and return the recorded result on retry. “Check then insert” without a unique constraint/transaction races.

### Production and failure checks

- Name aggregate and concurrency boundaries; test simultaneous operations with barriers, not only loops.
- Put unique/check/version constraints in durable storage as the final invariant guard.
- Define timeout, cancellation, retry, deadlock, partial-effect, and recovery behavior.
- Avoid holding process locks across network/database awaits.

### Build/debug task

Implement a thread-safe seat reservation with expiry and idempotent confirmation. Run 100 concurrent attempts for the last seat, inject persistence timeout after commit, and prove exactly one durable owner plus safe retry behavior.

---

## 4. System-Design Method, Requirements, and Capacity

**Study first:** [System Design Interview Guide](system-design-interview-guide.md), [System Design Fundamentals](system-design-fundamentals-extended.md), and [HLD](hld.md).

### Concept map

A design starts with users, functional flows, invariants, scale, latency/availability/durability/security targets, consistency, data lifecycle, and failure model. Estimate orders of magnitude, choose the simplest architecture that meets them, then walk the critical path, overload, recovery, and evolution.

### Practice questions

1. Which questions must be answered before drawing a social-feed or file-storage architecture?
2. How do QPS, concurrency, bandwidth, storage growth, and replication estimates connect?
3. Distinguish SLA, SLO, SLI, RPO, and RTO.
4. Why should one design show both the write path and read path plus failure recovery?
5. What signals that an architectural component is premature?

### Wrong/before example

```text
Requirements: "Design a scalable notification service."
Architecture: Client -> API Gateway -> 15 microservices -> Kafka ->
Redis -> Cassandra -> Elasticsearch -> three regions
```

### Corrected/after example

```text
Functional: accept notification command; honor preference/consent; deliver;
track status; retry safe failures; support email/SMS/push.

Invariant: one logical command may be retried but must not create an
unbounded duplicate effect; opt-out must be enforced before send.

Scale assumptions: peak commands/s, channels per command, payload bytes,
provider quotas, retention, burst factor.

SLO/failure: API acceptance p99, delivery objective by channel, durability,
provider outage behavior, regional RPO/RTO.

Initial design: stateless API + durable command/outbox + channel workers +
status store. Add partitions/caches/regions only where estimates require them.
```

### Answer key

1. Actors, core flows, ordering/deduplication, privacy, consistency, retention, read/write ratios, object sizes, geography, latency/availability/durability targets, growth, abuse, and explicitly out-of-scope features.
2. Average QPS comes from operations/time; peak applies a measured/assumed burst factor. Concurrency is approximately arrival rate × service time (Little's Law under stable assumptions). Multiply operations by payload for bandwidth and durable records by size/retention/index/replica overhead for storage.
3. SLI is a measurement; SLO is the internal target; SLA is a customer/business commitment with consequences. RPO is acceptable data loss measured in time/records; RTO is acceptable recovery time.
4. Components are justified by traffic/data flows. Recovery reveals ownership of queued/in-flight/replicated state, while only a happy-path box diagram hides partial failure and consistency gaps.
5. No measured/estimated requirement justifies it; the team cannot name failure/owner/metric; a simpler component meets headroom; or it adds coordination/consistency cost without removing the current bottleneck.

### Production and failure checks

- Write assumptions with units and uncertainty; sanity-check from two directions.
- Identify source of truth, derived projections, ownership, and rebuild path.
- Walk dependency slowdown, retry storm, region loss, overload, and bad deploy.
- State trade-offs and the threshold for the next architectural step.

### Build/debug task

Design a notification service at two scales: 100 requests/s and 100,000 requests/s. Produce estimates, API/data model, paths, failure timeline, SLOs, security/abuse controls, rollout, and explain which components are unnecessary at the smaller scale.

---

## 5. API Contracts, Protocols, Compatibility, and Pagination

**Study first:** [API Design](api-design.md), [ASP.NET Core API Design](aspnet-core-api-design.md), and [HLD](hld.md).

### Concept map

An API is a durable contract: resource/command semantics, authentication/authorization, validation, idempotency, status/error schema, pagination/filter/sort, concurrency, versioning, rate limits, observability, and deprecation. Choose REST, GraphQL, gRPC, WebSocket, SSE, or events from interaction needs.

### Practice questions

1. How do PUT, PATCH, POST, and idempotency keys differ?
2. When should an API return `202 Accepted`, and what must accompany it?
3. Compare offset, cursor, and keyset pagination under concurrent writes.
4. How do additive and breaking API changes differ across JSON and Protobuf?
5. When should communication be synchronous versus asynchronous?

### Wrong/before example

```http
POST /api/doEverything
200 OK
{"success":false,"message":"Something went wrong"}
```

### Corrected/after example

```http
POST /orders
Idempotency-Key: 7d4d...
Content-Type: application/json

{"customerId":"C42","items":[{"sku":"P7","quantity":2}]}

202 Accepted
Location: /order-operations/OP93
Retry-After: 2

{"operationId":"OP93","status":"Pending"}
```

### Answer key

1. PUT replaces/creates a known resource and is semantically idempotent; PATCH applies a partial change whose operation format determines retry safety; POST usually creates/commands and needs an idempotency key for safe retry when effects are non-idempotent.
2. Use `202` when work is durably accepted but not complete. Return an operation/status resource, stable ID, polling/retry guidance or callback mechanism, terminal states, error contract, retention, and cancellation rules.
3. Offset is simple/jumpable but deep pages scan/discard and positions drift. Cursor is an opaque continuation contract. Keyset seeks after a stable unique ordered tuple, performs well and resists front insert drift but cannot naturally jump to arbitrary pages.
4. Adding optional JSON fields is often compatible if clients ignore unknowns; changing meaning/type/requiredness is breaking. Protobuf field numbers/types carry compatibility rules: never reuse removed tags, add new fields, and preserve unknown fields/semantics.
5. Synchronous fits immediate required answers and simple failure ownership. Async fits slow/bursty work, decoupled reactions, independent availability, and replay—but adds lag, duplicates, state/status, and eventual consistency.

### Production and failure checks

- Contract-test status/errors/schema, retries, idempotency, pagination, authorization, and limits.
- Use deterministic unique ordering and sign opaque cursors when tampering matters.
- Version behavior, not merely URL strings; publish deprecation telemetry/timeline.
- Propagate correlation, deadlines, cancellation, and retry-safe semantics.

### Build/debug task

Design an export API with `202`, status, cancellation, idempotency, auth, pagination of results, webhook option, retention, quotas, and retry/failure states. Write consumer and provider contract tests.

---

## 6. Caching, CDNs, Load Balancing, and Traffic Management

**Study first:** [Advanced Topics](advanced-topics.md), [Cloud & DevOps](cloud-devops.md), [HLD](hld.md), and [Backend Patterns](backend-design-patterns.md).

### Concept map

Cache derived/recomputable data with an explicit owner, key, freshness bound, invalidation, miss/stampede policy, and degraded path. CDNs move cache/termination close to users. Load balancers route healthy traffic; algorithms should use connection/work/locality signals that match workload cost.

### Practice questions

1. Compare cache-aside, read/write-through, write-behind, and refresh-ahead.
2. How do TTL jitter, single-flight, stale-while-revalidate, and negative caching prevent stampedes?
3. What belongs in a safe CDN cache key, and what must not be publicly cached?
4. Compare round robin, least connections/work, weighted, consistent-hash, and locality-aware routing.
5. Why can a 99% cache hit rate still hide a dangerous design?

### Wrong/before example

```csharp
var key = $"profile:{userId}"; // tenant/authorization/version omitted
return await cache.GetOrCreateAsync(key, _ => repository.GetAsync(userId));
```

### Corrected/after example

```csharp
var viewerSubject = principal.FindFirst("sub")?.Value
    ?? throw new UnauthorizedAccessException("A stable subject claim is required.");

// This example caches a viewer-specific representation. A representation shared
// by a role or policy needs a policy-derived partition plus entitlement invalidation.
var key = $"profile:v3:tenant:{tenantId}:user:{userId}:viewer:{viewerSubject}";
return await cache.GetOrCreateSingleFlightAsync(
    key,
    ttl: TimeSpan.FromMinutes(5) + RandomJitter.UpToSeconds(30),
    factory: ct => repository.GetAuthorizedAsync(tenantId, userId, principal, ct),
    cancellationToken);
```

### Answer key

1. Cache-aside lets the app load on miss; read-through makes cache load; write-through updates cache/source synchronously; write-behind buffers source writes with durability/ordering risk; refresh-ahead renews before expiry based on predicted demand.
2. Jitter avoids synchronized expiry; single-flight coalesces same-key misses; stale-while-revalidate serves bounded stale data while one refresher runs; negative caching bounds repeated not-found/invalid lookups but must use short safe TTLs.
3. Include all representation dimensions: host/path/query normalization, content encoding/language, authorization/tenant/personalization where caching is permitted, version. Never shared-cache private/session-specific responses without a correct partition. A role name alone is unsafe when two users with that role have different resource grants. Honor `Cache-Control`, cookies, and `Vary` carefully.
4. Round robin assumes equal work; least connections/work adapts to variable duration; weights represent capacity; consistent hash preserves locality but hot keys skew; locality-aware routing balances reuse against queue pressure.
5. The remaining 1% may be expensive synchronized misses, hot keys, authorization leaks, stale correctness failures, or enough load to overwhelm the source. Inspect miss rate by key class, origin load, age, and failure behavior.

### Production and failure checks

- Monitor hit/miss/stale/eviction by key class, load latency, coalescing, hot keys, origin pressure, and correctness incidents.
- Test cold start, mass expiry, cache outage, node addition, invalidation loss, and poisoned entries.
- Bound object/key size and tenant quotas; authenticate/encrypt distributed caches as required.
- Decide whether cancellation removes only one waiter or also cancels a shared single-flight fill; one disconnected request should not accidentally fail every waiter.
- Do not make cache availability necessary for source correctness unless it is intentionally the source.

### Build/debug task

Implement cache-aside for a catalogue with single-flight, jitter, negative caching, invalidation, stale-if-error, tenant-safe keys, and metrics. Load-test cold start and cache outage; prove the database remains within capacity.

---

## 7. Storage, Replication, Sharding, and Consistency

**Study first:** [Technology Fundamentals](technologies-fundamentals.md), [Distributed Patterns](distributed-systems-patterns.md), [HLD](hld.md), and [SQL Server](sql-server.md).

### Concept map

Choose storage from access patterns, transactions/invariants, scale, durability, retention, and operations. Replication creates copies with lag/failover trade-offs. Sharding divides ownership. Consistency is a per-workflow promise such as linearizable, read-your-writes, monotonic, causal, or eventual—not one database label.

### Practice questions

1. Compare relational, document, key-value, wide-column, graph, object, search, and analytical stores.
2. How do synchronous and asynchronous replication change write latency, availability, and RPO?
3. What makes a good shard key, and how do logical buckets ease resharding?
4. Explain quorum intuition and why `R+W>N` alone is not a full correctness proof.
5. When can eventual consistency be acceptable, and what must the UX expose?

### Wrong/before example

```text
Write order to primary -> immediately read confirmation from any async replica
Result: user may see "order not found" and retry the purchase.
```

### Corrected/after example

```text
Write returns order ID + commit token.
Confirmation reads leader or replica whose replay position >= token.
Catalogue browsing may use bounded-stale replicas.
Analytics/search are rebuildable asynchronous projections.
```

### Answer key

1. Relational fits transactions/joins/constraints; document fits aggregate-shaped flexible documents; key-value fits exact-key access; wide-column fits partition/range scale; graph fits relationship traversal; object fits large immutable blobs; search fits analyzed text/ranking; analytical columnar stores fit scans/aggregations.
2. Synchronous acknowledgement waits for replicas, lowering potential data loss but adding latency and reducing availability when replicas fail. Async improves latency/availability but acknowledged writes may lag or be lost on failover; document RPO by failure scope.
3. Stable, high-cardinality, evenly distributes bytes/work, aligns with common queries/ownership, and avoids one hot tenant/range. Hash into many logical buckets mapped to fewer physical shards so moves change placement metadata rather than the hash formula/all keys.
4. Quorum overlap is useful under defined replica/version assumptions, but sloppy quorums, stale replicas, concurrent versions, clocks, repair, hinted handoff, membership, and conflict resolution affect real guarantees.
5. When temporary stale/partial views do not violate critical invariants—for feeds, counts, search projections. Show pending state, preserve session guarantees where expected, explain freshness, reconcile, and never use eventual views to authorize money/inventory/security decisions without safeguards.

### Production and failure checks

- Measure replication lag, shard skew, hot keys, quorum/repair, failover/fencing, and reconciliation.
- Test read-your-writes, monotonic reads, conflict, partition, replica loss, and restore.
- Replication is not backup; keep independent versioned backups and prove restore.
- Define source of truth and rebuild for every projection.

### Build/debug task

Design storage for marketplace orders, carts, product search, images, and analytics. Specify owner/store, partition key, replication, consistency, retention, backup/restore, projection lag, and region-failure behavior.

---

## 8. Queues, Streams, Events, and Idempotency

**Study first:** [Distributed Patterns](distributed-systems-patterns.md), [Technology Fundamentals](technologies-fundamentals.md), and [System Design Extended](system-design-extended.md).

### Concept map

Queues distribute commands/work; streams retain ordered partition logs for independent consumers/replay; pub/sub broadcasts facts to subscriptions. At-least-once delivery requires idempotent effects. Outbox/CDC connects database commits to messages without unsafe dual writes.

### Practice questions

1. Distinguish command, event, work queue, pub/sub, and event stream.
2. Why is “exactly once” usually an end-to-end effect property rather than a broker setting?
3. How do outbox and inbox/deduplication work together?
4. Choose a partition key for order events and explain ordering/parallelism.
5. What belongs in retry, visibility-timeout, poison-message, and DLQ policy?

### Wrong/before example

```csharp
await db.SaveChangesAsync(cancellationToken);
await broker.PublishAsync(new OrderPlaced(order.Id), cancellationToken);
// Crash between calls leaves committed order without event.
```

### Corrected/after example

```csharp
await using var tx = await db.Database.BeginTransactionAsync(cancellationToken);
db.Orders.Add(order);
db.Outbox.Add(OutboxMessage.From(new OrderPlaced(order.Id), order.Version));
await db.SaveChangesAsync(cancellationToken);
await tx.CommitAsync(cancellationToken);

// Separate publisher claims committed outbox rows and retries safely.
```

### Answer key

1. A command asks one owner to act; an event states a past fact. A work queue gives each job to one competing worker. Pub/sub gives each subscription its copy. A stream retains records by partition/offset so consumer groups progress/replay independently.
2. Broker deduplication cannot guarantee database/email/payment effects across timeout/crash. Stable operation IDs plus an atomic durable effect/dedup record can guarantee one committed effect at that consumer's local transactional boundary. An email or payment provider is a different boundary and still needs provider idempotency, an authorization/capture workflow, or reconciliation for ambiguous outcomes.
3. The producer commits domain state and outbox atomically; a publisher retries dispatch. The consumer records message/operation ID with its local effect in one transaction and returns the stored outcome/ignores duplicates.
4. Use `OrderId` when each order's events must be ordered; it distributes orders but serializes one order. Global ordering sacrifices parallelism and is rarely necessary. Hot keys require special treatment.
5. Retry only transient faults with bounded exponential backoff/jitter; visibility/lease exceeds normal work and renews safely; cap attempts/time; classify permanent invalid messages; DLQ has owner, alert, inspection, replay after fix, retention, and no infinite poison loop.

### Production and failure checks

- Monitor oldest age/lag, ingress/egress, retries, lease expiry, duplicate suppression, poison/DLQ age, and partition skew.
- Test crash before/after effect and before/after acknowledgement.
- Version schemas compatibly; keep consumers tolerant and replay tested.
- Do not put secrets/large blobs in messages; use references with controlled access/lifetime.

### Build/debug task

Build an order-to-notification flow with transactional outbox, idempotent consumer, retry/DLQ, schema version, replay, correlation, and metrics. Inject a crash after email-provider success but before acknowledgement. Prevent duplicate customer impact with a provider idempotency key; if the provider offers no such contract, record the ambiguity and implement reconciliation rather than claiming certainty.

---

## 9. Timeouts, Retries, Backpressure, and Resilience

**Study first:** [Distributed Patterns](distributed-systems-patterns.md), [Advanced Topics](advanced-topics.md), and [Production Scenarios](production-scenarios.md).

### Concept map

Resilience is a budgeted control loop: deadlines bound work, cancellation stops useless work, retry handles selected transient faults, jitter prevents synchronization, circuit breaking protects dependencies, bulkheads isolate capacity, rate limits/load shedding reject early, and backpressure makes producers respond to finite consumer capacity.

### Practice questions

1. Distinguish timeout, deadline, cancellation, and retry budget.
2. When is a retry safe, and how does retry amplification create outages?
3. Compare circuit breaker, rate limiter, concurrency limiter, and bulkhead.
4. How does backpressure differ for synchronous APIs, queues, and streams?
5. Why should tail latency and queue age drive overload decisions?

### Wrong/before example

```csharp
for (var attempt = 0; attempt < 10; attempt++)
{
    try { return await dependency.CallAsync(request); }
    catch { await Task.Delay(100); }
}
```

### Corrected/after example

```csharp
using var budget = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
// In a real request, choose the smaller of this dependency budget and the
// caller's remaining end-to-end deadline.
budget.CancelAfter(TimeSpan.FromSeconds(2));

TransientException? lastError = null;

// Retrying is valid only if request is naturally idempotent or carries a stable
// operation key that the dependency uses to deduplicate the effect.
try
{
    for (var attempt = 1; attempt <= 3; attempt++)
    {
        try
        {
            return await dependency.CallAsync(request, budget.Token);
        }
        catch (TransientException exception)
        {
            lastError = exception;

            if (attempt == 3 || budget.IsCancellationRequested)
                break;

            await Task.Delay(Backoff.WithJitter(attempt), budget.Token);
        }
    }
}
catch (OperationCanceledException exception)
    when (!cancellationToken.IsCancellationRequested && budget.IsCancellationRequested)
{
    throw new TimeoutException("The dependency call exhausted its time budget.", exception);
}

if (cancellationToken.IsCancellationRequested)
    throw new OperationCanceledException(cancellationToken);

if (budget.IsCancellationRequested)
    throw new TimeoutException("The dependency call exhausted its time budget.", lastError);

throw new DependencyUnavailableException("Transient attempts were exhausted.", lastError);
```

### Answer key

1. A timeout is a component's wait limit; a deadline is end-to-end remaining time; cancellation communicates no further value; retry budget bounds extra attempts/time/load across layers. Each downstream timeout must fit remaining deadline.
2. Retry only transient, idempotent/deduplicated operations when enough deadline remains. If every layer retries three times, one request may multiply into many calls, increasing saturation and failure. Retry at one owned boundary with budgets and `Retry-After`/jitter.
3. Circuit breaker temporarily avoids a failing dependency; rate limiter controls arrivals over time; concurrency limiter bounds in-flight work; bulkhead partitions capacity so one workload/dependency cannot consume all resources.
4. APIs reject/queue with bounded concurrency; queues slow publishers, cap backlog, or shed/expire work; streams expose consumer lag and require partition/consumer scaling or admission. Hiding infinite buffers only converts overload into stale work/OOM.
5. Averages hide stragglers and saturation. Queue age predicts whether accepted work can meet deadline; tail latency shows user-impacting slowdown. Admission should protect goodput before the system collapses.

### Production and failure checks

- Trace attempt count, retry reason, remaining deadline, cancellation, breaker state, queue age, and rejected load.
- Test dependency slow, partial failure, rate limit, timeout-after-commit, and recovery.
- Ensure fallbacks are cheaper, correct, bounded, and do not overload another dependency.
- Load shed before accepting work that cannot meet its SLO.

### Build/debug task

Create a dependency simulator with latency/error modes. Compare no protection, layered retries, and deadline + bounded retry + circuit + concurrency limit. Plot goodput, p99, dependency calls/request, and recovery time.

---

## 10. Real-Time, Collaborative, and Social Systems

**Study first:** [Real-Time Collaborative Systems](real-time-collaborative-systems.md), [Social & Messaging Infrastructure](social-messaging-infrastructure.md), and [System Design Extended](system-design-extended.md).

### Concept map

Real-time systems manage sessions, ordering, presence, reconnect/resume, fan-out, backpressure, and partial connectivity. Collaborative state needs conflict semantics such as server serialization, operational transformation, or CRDTs. Social feeds choose fan-out-on-write/read hybrids based on follower distribution and freshness.

### Practice questions

1. Compare WebSocket, SSE, long polling, and broker-backed events.
2. How do sequence numbers, acknowledgements, and replay support reconnect?
3. Compare OT and CRDTs at a high level; what does neither solve automatically?
4. When should a feed use fan-out-on-write versus fan-out-on-read?
5. How do presence and typing indicators differ from durable chat messages?

### Wrong/before example

```text
Client reconnects -> server sends only new live messages.
Messages sent during disconnection are silently lost; duplicates have no IDs.
```

### Corrected/after example

```text
Each conversation is routed to an ordering owner/partition that assigns durable
message IDs and a monotonic sequence within that conversation.
Client reconnects with last acknowledged cursor.
Server replays missing durable messages, then attaches live stream.
Presence/typing use expiring best-effort state and are not replayed as messages.
```

### Answer key

1. WebSocket is bidirectional persistent communication; SSE is server-to-client HTTP streaming with simpler browser reconnection; long polling works broadly but adds repeated requests; broker events decouple backend components and do not by themselves define client transport/session semantics.
2. Stable IDs deduplicate; a sequence/cursor identifies progress within a named ordering scope; acknowledgement records what the client processed; retention/replay fills gaps. A single conversation sequence needs one ordering owner or a consensus/serialization mechanism. Resume tokens need authorization and expiration, and reconnect must close the race between replay and attaching the live stream.
3. OT transforms concurrent operations relative to history; CRDT operations/state merge by mathematical convergence rules. Neither automatically solves intent, access control, undo UX, storage, presence, large-document performance, or malicious clients.
4. Write fan-out gives fast reads for normal users but write amplification/celebrity problems. Read fan-out avoids huge write fan-out but adds merge latency. Hybrid precomputes ordinary feeds and merges celebrity/recent content at read.
5. Messages require durable ordering/deduplication/history. Presence/typing are ephemeral, expire, tolerate loss/reordering, and should not create durable load or false certainty.

### Production and failure checks

- Monitor active connections, reconnects, replay gaps, send buffers, fan-out latency, slow consumers, and regional session distribution.
- Test network flap, duplicate/out-of-order delivery, server restart, stale resume token, and authorization change.
- Bound per-connection queues and disconnect/degrade slow consumers.
- Separate ephemeral and durable semantics explicitly.

### Build/debug task

Build a chat prototype with durable IDs, reconnect cursor, replay, idempotent send, presence TTL, slow-client backpressure, and authorization. Inject disconnects and server restarts while verifying no missing durable messages and that transport retries collapse to one stored/displayed message ID.

---

## 11. Security, Identity, Authorization, and Threat Modeling

**Study first:** [Security](security.md), [Security Production Scenarios](security-production-scenarios.md), and [PR Review](pr-review.md).

### Concept map

Security starts with assets, actors, trust boundaries, data flow, threats, and abuse cases. Authentication proves an identity claim; authorization decides a specific action on a specific resource. Validate at boundaries, parameterize data access, minimize privilege/data, protect secrets, encrypt appropriately, log safely, and plan detection/response.

### Practice questions

1. Distinguish authentication, authorization, session, OAuth 2.0, and OpenID Connect.
2. Why is checking a valid JWT insufficient authorization?
3. Explain SQL injection, XSS, CSRF, SSRF, IDOR/BOLA, and unsafe deserialization by trust boundary.
4. How should secrets and encryption keys be stored, rotated, and audited?
5. What does a threat model add before penetration testing?

### Wrong/before example

```csharp
[Authorize]
[HttpGet("orders/{id}")]
public Task<Order?> Get(Guid id) => db.Orders.FindAsync(id).AsTask();
// Any authenticated caller who guesses an ID can access another user's order.
```

### Corrected/after example

```csharp
[Authorize(Policy = "CustomerOrderReader")]
[HttpGet("orders/{id}")]
public async Task<IResult> Get(Guid id, CancellationToken cancellationToken)
{
    var subject = User.FindFirstValue("sub");
    var tenantId = User.FindFirstValue("tenant_id");

    if (string.IsNullOrWhiteSpace(subject) || string.IsNullOrWhiteSpace(tenantId))
        return Results.Forbid();

    var order = await db.Orders.SingleOrDefaultAsync(
        x => x.Id == id &&
             x.TenantId == tenantId &&
             x.CustomerSubject == subject,
        cancellationToken);

    return order is null ? Results.NotFound() : Results.Ok(order.ToDto());
}
```

### Answer key

1. Authentication establishes identity; authorization evaluates permission. A session maintains authenticated state. OAuth delegates authorization/access tokens; OIDC adds identity/authentication claims on OAuth. The concrete token/session mechanism does not replace resource policy.
2. Signature/issuer/audience/expiry prove token validity, not that this principal may read order X now. Check tenant/owner/role/scope/relationship and current policy at the resource/action boundary. Scope the lookup itself, as in the corrected example, so an omitted later check cannot return another tenant's row; return the same not-found shape when resource-existence disclosure matters.
3. Injection lets untrusted input alter SQL; XSS executes untrusted script in a browser origin; CSRF abuses ambient browser credentials; SSRF makes a server access unintended networks; IDOR skips object authorization; unsafe deserialization instantiates/executes attacker-controlled types/data behavior.
4. Use a managed vault/HSM or platform identity, no source/config/log plaintext, least-privilege access, short-lived credentials, versioned rotation with overlap, access audit/alerts, and tested revocation/recovery.
5. Threat modeling identifies assets/flows/trust, likely attacker goals, design controls, residual risk, and test priorities before an implementation exists. Pen testing samples an implemented system and cannot compensate for unknown ownership/invariants.

### Production and failure checks

- Test horizontal/vertical privilege escalation, tenant isolation, revoked users, token confusion, and fail-closed policy behavior.
- Scan dependencies/secrets/artifacts and secure CI/CD/supply chain.
- Redact logs/traces; define retention, deletion, breach detection, and incident playbook.
- Rate-limit/abuse-protect expensive and sensitive actions.

### Build/debug task

Threat-model an order API with browser, mobile app, identity provider, API, database, payment provider, queue, and support admin. Create abuse cases and automated authorization/injection/CSRF/SSRF/secrets tests.

---

## 12. Cloud, Containers, Kubernetes, and Infrastructure

**Study first:** [Cloud & DevOps](cloud-devops.md), [Azure DevOps](azure-devops.md), and [Production Scenarios](production-scenarios.md).

### Concept map

Cloud design assigns compute, network, storage, identity, availability, scalability, and cost ownership. Containers package user space, not the kernel. Kubernetes reconciles desired state but does not supply application correctness, readiness, safe rollout, data durability, or sensible resource budgets automatically.

### Practice questions

1. Compare VM, container, serverless function, and managed platform by control/operations/startup/state.
2. Distinguish image, container, pod, deployment, service, ingress/gateway, and node.
3. Why do liveness, readiness, startup, and deep health need different semantics?
4. How do requests/limits, autoscaling, disruption budgets, and topology spread interact?
5. What belongs in infrastructure-as-code review and state protection?

### Wrong/before example

```yaml
livenessProbe:
  httpGet: { path: /health, port: 8080 }
# /health fails whenever the database is briefly slow, so Kubernetes restarts
# every healthy application process and amplifies the incident.
```

### Corrected/after example

```yaml
startupProbe:
  httpGet: { path: /health/startup, port: 8080 }
  failureThreshold: 30
readinessProbe:
  httpGet: { path: /health/ready, port: 8080 }
livenessProbe:
  httpGet: { path: /health/live, port: 8080 }
```

### Answer key

1. VMs provide OS isolation/control with slower startup/ops; containers package processes efficiently but share kernel; serverless abstracts servers and scales events with runtime/limits/cold-start trade-offs; managed platforms reduce ops but constrain versions/network/runtime and may increase lock-in/cost.
2. Image is immutable filesystem/config template; container is running process isolation; pod is Kubernetes scheduling unit; deployment manages replicas/rollout; service gives stable discovery/load balancing; ingress/gateway routes external traffic/policy; node hosts pods.
3. Startup allows slow initialization; readiness controls traffic; liveness detects unrecoverable process failure; deep health informs diagnostics without always triggering restart. Conflation creates restart storms or sends traffic too early.
4. Requests drive scheduling and often autoscaling denominator; limits cap/throttle/kill; autoscaling adds replicas but downstream limits matter; disruption budgets control voluntary loss; topology spread prevents replicas concentrating in one failure domain.
5. Provider/version pinning, plan review, least privilege, network/data exposure, encryption, backups, destructive replacement, drift/import, cost, naming/tags, policy checks, remote encrypted locked state, and recovery.

### Production and failure checks

- Test node/zone loss, image-pull failure, slow startup, rollout, drain, quota, DNS/network policy, and secret rotation.
- Set requests/limits from measurement and monitor throttling/OOM/eviction/scheduling.
- Keep application/state backups and restore independent of desired-state manifests.
- Model cost and egress; tag ownership and expiry.

### Build/debug task

Containerize an API, deploy locally to Kubernetes with probes, resources, HPA inputs, disruption budget, topology hints, config/secrets, network policy, and rolling update. Inject bad readiness and node drain; document recovery.

---

## 13. CI/CD, Azure DevOps, Rollout, and Recovery

**Study first:** [Azure DevOps](azure-devops.md), [Cloud & DevOps](cloud-devops.md), and [Testing](unit-testing.md).

### Concept map

CI proves a change is buildable, testable, reviewable, and traceable. CD promotes one immutable artifact through environments with policy, security, migration, observability, and rollback. Deployment is a risk-control workflow, not a script that copies files.

### Practice questions

1. Distinguish build once/promote from rebuilding per environment.
2. Compare rolling, blue-green, canary, feature flag, and shadow deployment.
3. How should backward-compatible database migrations be sequenced?
4. What are safe secret, artifact, and pipeline identity practices?
5. What must a rollback trigger and procedure contain?

### Wrong/before example

```yaml
steps:
- script: dotnet test
- script: dotnet publish
- script: deploy production
# Same job has broad permanent credentials; no artifact provenance/gates/canary.
```

### Corrected/after example

```text
PR: format/lint -> unit/contract/security -> build immutable signed artifact
main: integration/e2e -> publish SBOM/provenance
deploy: short-lived environment identity -> prechecks -> compatible migration
        -> 1% canary -> SLO/business/security gates -> staged promotion
        -> automatic halt/rollback decision with operator ownership
```

### Answer key

1. Build once ensures the tested bits equal deployed bits. Environment differences belong in validated configuration/secrets, not recompilation that changes provenance.
2. Rolling gradually replaces instances; blue-green switches full environments with fast rollback/cost; canary exposes a measured subset; flags separate deploy from activation but need lifecycle; shadow duplicates input without user-visible effect and must suppress side effects/sensitive leakage.
3. Expand schema first (add nullable/new structures), deploy code that handles old/new and backfills safely, switch reads/writes, then contract only after all old code/data dependencies are gone. Rollback must remain compatible during overlap.
4. Use short-lived workload federation/managed identity, least privilege/environment approvals, protected variables/vault, signed immutable artifacts, SBOM/provenance, branch controls, no secrets in logs/artifacts/forks.
5. Objective thresholds, observation window, who decides/automates, exact artifact/config/data implications, traffic/flag steps, migration compatibility, verification, communication, and forward-fix criteria. “Redeploy old version” is incomplete.

### Production and failure checks

- Rehearse rollback and failed migration in staging-like data/traffic.
- Gate on SLO/error budget plus business/security correctness, not deployment success only.
- Track lead time, failure rate, recovery time, flaky tests, artifact lineage, and environment drift.
- Clean feature flags and old artifacts by owner/expiry policy.

### Build/debug task

Write an Azure DevOps/GitHub-style pipeline for an API with immutable artifact, unit/integration/contract/security tests, SBOM, federated identity, expand-contract migration, canary metrics, approval boundaries, and rollback drill.

---

## 14. Observability, Incidents, and Production Diagnosis

**Study first:** [Production Scenarios](production-scenarios.md), [Cloud & DevOps](cloud-devops.md), and [Advanced Topics](advanced-topics.md).

### Concept map

Observability connects user impact to internal causes using metrics, logs, traces, profiles, events, and domain signals. SLOs and error budgets focus alerts. Incident response prioritizes safety/restoration, maintains a timeline and communication, then produces tested follow-up rather than blame.

### Practice questions

1. Compare metrics, logs, traces, profiles, and audit events.
2. Why do p95/p99, saturation, and queue age matter beyond averages?
3. How do SLI, SLO, error budget, alert, and runbook connect?
4. What are the first steps in a production latency incident?
5. What makes a postmortem useful rather than ceremonial?

### Wrong/before example

```text
Alert: CPU > 70% for 1 minute on any pod.
Action: restart all pods.
```

### Corrected/after example

```text
Alert: checkout availability/latency error-budget burn across fast + slow windows.
Triage: confirm user impact -> compare change/dependency/traffic timeline ->
inspect request rate, errors, duration, saturation, queue/pool waits and traces ->
mitigate with rollback/load shed/capacity only when evidence supports it.
```

### Answer key

1. Metrics summarize numeric trends/alerts; logs record discrete context; traces connect distributed request spans; profiles attribute CPU/allocation/lock time; audit events are tamper-aware records of sensitive actions. Each has sampling/cardinality/privacy trade-offs.
2. Averages hide small severe cohorts. Tail latency determines fan-out and user pain; saturation shows capacity; queue age predicts whether accepted work can still meet deadlines.
3. SLI measures the promise; SLO defines target; budget quantifies allowed failure; burn alerts signal unsustainable consumption; runbook turns the alert into safe diagnosis/mitigation/escalation.
4. Establish commander/roles and impact, freeze risky change, inspect recent deploy/config/dependency/traffic, preserve evidence, mitigate reversibly, communicate timestamps/next update, and avoid untested broad restarts.
5. Evidence-based timeline, contributing system conditions, detection/response gaps, what helped, causal actions with owners/dates/tests, and learning shared without blaming individuals for systemic incentives.

### Production and failure checks

- Bound label cardinality and redact sensitive data; sample traces intentionally.
- Test alert delivery/runbooks and run game days/restore drills.
- Correlate deploy/config/feature/provider events with telemetry.
- Verify dashboards from user and dependency perspectives.

### Build/debug task

Instrument a three-service request with OpenTelemetry-style traces, RED metrics, structured logs, correlation, queue/pool signals, and an SLO burn alert. Inject a slow dependency and write the incident timeline, mitigation, and postmortem actions.

---

## 15. Testing Strategy, Code Review, and Technical Debt

**Study first:** [Unit Testing](unit-testing.md), [PR Review](pr-review.md), and [Production Scenarios](production-scenarios.md).

### Concept map

Tests provide evidence at the cheapest reliable boundary: pure unit tests for logic, integration/contract tests for boundaries, end-to-end tests for critical journeys, performance/security/chaos tests for nonfunctional promises. Review targets correctness, security, operability, and maintainability. Debt is a risk/cost hypothesis with evidence and a repayment plan.

### Practice questions

1. What should be unit, integration, contract, and end-to-end tested?
2. Why is code coverage not a sufficient quality measure?
3. How do deterministic fakes differ from over-mocking implementation details?
4. What should a reviewer examine beyond style and happy-path correctness?
5. How do you prioritize technical debt against feature work?

### Wrong/before example

```csharp
[Fact]
public async Task CreateOrder_CallsRepository()
{
    await service.CreateAsync(request);
    repository.Verify(x => x.AddAsync(It.IsAny<Order>()), Times.Once);
}
```

### Corrected/after example

```csharp
[Fact]
public async Task SameIdempotencyKey_CreatesOneOrder_AndReturnsSameResult()
{
    var first = await harness.CreateOrderAsync(request, key: "K1");
    var retry = await harness.CreateOrderAsync(request, key: "K1");

    retry.Should().BeEquivalentTo(first);
    (await harness.CountOrdersAsync()).Should().Be(1);
    (await harness.CountOutboxEventsAsync("OrderPlaced")).Should().Be(1);
}
```

### Answer key

1. Unit-test branching/invariants; integration-test database/broker/files/framework adapters; contract-test consumer/provider compatibility; E2E-test a small set of critical user flows. Add load/security/recovery where requirements demand them.
2. Coverage measures execution, not assertion quality, missing cases, behavior, production realism, mutation resistance, or criticality. High coverage can assert nothing useful.
3. Fakes model stable dependency behavior/time/failure to test outcomes. Over-mocking asserts private call order/count, couples tests to refactoring, and can reproduce the implementation rather than external contract.
4. Trust boundaries/input/auth, concurrency/retries/idempotency, error/cancellation/resource cleanup, migrations/compatibility, performance/query count, logs/metrics/privacy, rollout/rollback, tests and ownership.
5. Estimate probability × impact plus recurring friction/interest, affected business goals, blast radius, evidence, and cheapest incremental mitigation. Turn debt into measurable work with owner/exit criteria rather than a vague rewrite.

### Production and failure checks

- Track flakiness, duration, mutation/defect escape, critical path coverage, and test-environment realism.
- Review generated/migration/infrastructure/config changes, not only application code.
- Prefer small reversible refactors with characterization tests over big-bang rewrites.
- Verify tests fail for the intended defect.

### Build/debug task

Choose one service and write a test strategy matrix by invariant/failure/boundary. Add a regression test for a retry/concurrency bug, a database integration test, consumer contract, critical E2E flow, load threshold, and rollback verification.

---

## 16. Behavioral Judgment and Technical Communication

**Study first:** [Behavioral Questions](behavioral.md), [Behavioral Mastery](behavioral-interview-mastery.md), and [Company Interview Guides](company-specific-interview-guides.md).

### Concept map

Strong engineering communication makes context, ownership, constraints, decisions, evidence, trade-offs, impact, learning, and follow-up visible. Behavioral answers should demonstrate judgment through a specific situation, not recite values. Technical leadership includes disagreement, incidents, ambiguity, mentoring, and changing one's mind from evidence.

### Practice questions

1. Tell a story where you disagreed with an architecture proposal. What evidence changed the outcome?
2. Describe a production incident you helped resolve. Separate mitigation from root cause.
3. Explain a mistake or failed project without blaming others or hiding impact.
4. Describe prioritizing reliability/debt against a feature deadline.
5. Explain a complex design to a product manager and then to a staff engineer.

### Wrong/before example

```text
"The team wanted microservices, but I knew a monolith was better. I convinced
them, and the project succeeded."
```

### Corrected/after example

```text
Situation/constraint: releases were slow, but profiling showed shared database
coupling—not deployment size—caused most risk.
Action: I wrote two options with ownership, migration, SLO, cost, and rollback;
ran a modular-boundary pilot; and invited objections from platform/product.
Result: we kept one deployable initially, isolated billing behind contracts,
cut test time 35%, and set measurable triggers for extraction.
Learning: I had initially underestimated team autonomy; the trigger document
made the future trade-off explicit instead of declaring either architecture final.
```

### Answer key / self-review rubric

1. **Specificity:** real scale, constraints, people/roles, and timeline without confidential detail.
2. **Ownership:** what you personally decided/did while crediting others.
3. **Judgment:** options, trade-offs, data, risk, and why the choice fit then.
4. **Execution:** communication, conflict handling, rollout, measurement, and recovery.
5. **Impact:** quantified user/business/engineering result with honest uncertainty.
6. **Learning:** what changed in your model and what process/system improved afterward.

### Production and failure checks

- Prepare 8-10 adaptable stories across success, failure, conflict, leadership, ambiguity, incident, mentoring, and delivery.
- Do not reveal proprietary/customer/personal data; anonymize responsibly.
- Avoid hero narratives; show systems and collaboration.
- Practice two-minute and six-minute versions plus deep follow-ups.

### Build/debug task

Create a story bank. For each story write raw facts, STAR/decision timeline, alternative options, metrics, trade-offs, hardest follow-up, and learning. Record yourself, remove vague claims, and ask a reviewer to identify what only you did versus what the team did.

---

## Cumulative Systems Capstone

Design and build one small but production-minded system—ticket booking, notification delivery, file processing, collaborative notes, or marketplace orders.

Your evidence portfolio must include:

1. Requirements, invariants, scale estimates, SLO/RPO/RTO, threat model.
2. API/event/data contracts and compatibility strategy.
3. One concurrency/idempotency invariant tested under failure.
4. Cache/queue/storage choices with measured trade-offs.
5. Deployment pipeline, migration, canary, rollback, and feature lifecycle.
6. Metrics/logs/traces, alert, runbook, and injected incident.
7. Test strategy and code-review checklist.
8. Architecture decision record stating when not to use the chosen design.
9. A five-minute explanation for an interviewer and a two-minute explanation for a product stakeholder.

**Completion standard:** You can implement the happy path, preserve the invariant under named failures, diagnose it from evidence, operate it within a budget, and explain the trade-offs without notes.
