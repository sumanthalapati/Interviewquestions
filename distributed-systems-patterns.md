# Distributed Systems Patterns - Interview Guide

> Distributed systems fail in partial, delayed, duplicated, and out-of-order ways. Every topic keeps the reference answer and its failure walkthrough together: **problem → unsafe flow → safe flow → surviving state → recovery → trade-off → exercise**.

**Related guides:** [Backend Design Patterns](backend-design-patterns.md) covers patterns inside one application boundary. [Dependency Injection](dependency-injection.md) explains how implementations, resilience policies, and provider clients are composed.

---

## Table of Contents

1. [Timeout and Deadline](#dsp-1-timeout-and-deadline-pattern)
2. [Retry with Backoff and Jitter](#dsp-2-retry-with-exponential-backoff-and-jitter)
3. [Circuit Breaker](#dsp-3-circuit-breaker-pattern)
4. [Bulkhead](#dsp-4-bulkhead-pattern)
5. [Rate Limiting and Load Shedding](#dsp-5-rate-limiting-and-load-shedding)
6. [Idempotent Consumer and Inbox](#dsp-6-idempotent-consumer-and-inbox-pattern)
7. [Transactional Outbox](#dsp-7-transactional-outbox-pattern)
8. [Saga](#dsp-8-saga-pattern)
9. [CQRS and Materialized View](#dsp-9-cqrs-and-materialized-view-pattern)
10. [Event Sourcing](#dsp-10-event-sourcing-pattern)
11. [Leader Election and Lease](#dsp-11-leader-election-and-lease-pattern)
12. [Distributed Lock and Fencing Token](#dsp-12-distributed-lock-and-fencing-token-pattern)
13. [Consistent Hashing](#dsp-13-consistent-hashing-pattern)
14. [Sharding](#dsp-14-sharding-pattern)
15. [Replication and Quorum](#dsp-15-replication-and-quorum-pattern)
16. [Competing Consumers](#dsp-16-competing-consumers-pattern)
17. [Publish/Subscribe](#dsp-17-publishsubscribe-pattern)
18. [Retry Queue, DLQ, and Parking Lot](#dsp-18-retry-queue-dlq-and-parking-lot-pattern)
19. [Scatter-Gather](#dsp-19-scatter-gather-pattern)
20. [Cell-Based Architecture](#dsp-20-cell-based-architecture-pattern)

---

## DSP-1. Timeout and Deadline Pattern

**Question:** Why must every remote call have a timeout, and how is a deadline different?

**Answer:** A timeout limits one operation's wait. A deadline is the remaining time budget for the entire request and should propagate through downstream calls.

**What problem does this concept solve?** It prevents slow dependencies from holding threads, connections, and memory forever.

**Before this concept:** Requests waited until operating-system defaults expired. A few slow calls consumed the entire connection pool.

❌ **Wrong example:**

```csharp
var response = await httpClient.GetAsync(url); // no caller deadline or cancellation
```

✅ **Correct example:**

```csharp
using var deadline = CancellationTokenSource.CreateLinkedTokenSource(requestAborted);
deadline.CancelAfter(TimeSpan.FromMilliseconds(800));
using var response = await httpClient.GetAsync(url, deadline.Token);
```

**How it works after this pattern:** Work stops when its useful time budget ends, cancellation propagates, and capacity becomes available for other requests.

**Trade-off:** A timeout that is too short creates false failures; one that is too long fails to protect capacity. Set it from measured latency and the caller's SLO.

### Failure walkthrough — Timeout and deadline: checkout calls pricing

#### Before the pattern

Checkout calls pricing without an application timeout. Pricing waits on its database for 30 seconds, so checkout holds a socket, request object, and database connection. At 500 concurrent requests, the pool is exhausted and unrelated endpoints fail. The caller eventually disconnects, but downstream work may continue because cancellation was never propagated.

```text
Client budget 2s -> Checkout waits 30s -> Pricing waits 30s -> DB
Client leaves at 2s; servers keep doing useless work.
```

#### After the pattern

The edge gives the request a two-second deadline. Checkout reserves time for its own work and passes the *remaining* budget—perhaps 700 ms—to pricing. Pricing passes a smaller remaining budget to its database and honors the cancellation token.

```text
0ms request starts -> 700ms pricing deadline -> 900ms fallback/decision -> <2s response
```

**What the pattern solves:** it bounds resource occupancy; it does not make the dependency reliable. Choose budgets from an end-to-end latency objective, not arbitrary identical timeouts at every hop. A deadline is an absolute expiry shared across hops; repeatedly starting a fresh timeout can accidentally exceed the original budget.

**Production checks:** record timeout rate separately from other failures, cancel abandoned work, and never retry after the useful deadline has expired.

**Try it:** with a 1,000 ms API objective and three downstream calls, write a budget that retains time for serialization and a controlled fallback.

---

## DSP-2. Retry with Exponential Backoff and Jitter

**Question:** When should a distributed system retry, and why add exponential backoff and jitter?

**Answer:** Retry only transient failures and safe operations. Exponential backoff increases delay after each failure; jitter randomizes it so clients do not retry together.

**What problem does this concept solve?** It recovers from brief faults without turning one outage into a synchronized retry storm.

**Before this concept:** Calls either failed immediately on a brief network issue or retried in tight loops that increased provider load.

❌ **Wrong example:**

```csharp
while (true)
{
    try { return await client.SendAsync(request); }
    catch { } // infinite immediate retry, even for invalid input
}
```

✅ **Correct example:**

```csharp
var delays = new[] { 100, 250, 600 };
for (var attempt = 0; ; attempt++)
{
    try { return await client.SendAsync(request, ct); }
    catch (HttpRequestException) when (attempt < delays.Length)
    {
        var jitter = Random.Shared.Next(0, 100);
        await Task.Delay(delays[attempt] + jitter, ct);
    }
}
```

**How it works after this pattern:** Brief failures recover, repeated failures spread over time, and retry count remains bounded.

**Trade-off:** Retries increase latency and load. Do not automatically retry non-idempotent writes or permanent `4xx` failures.

### Failure walkthrough — Retry with backoff and jitter: recover from a brief provider error

#### Before the pattern

One thousand clients receive `503` and retry immediately every 100 ms. Their retries remain synchronized, so the recovering provider is hit by another thousand requests at each interval. This is a retry storm; “reliability code” prolongs the outage.

#### After the pattern

Each caller retries only transient, safe operations. Delay grows exponentially and receives random jitter, so attempts spread over time. A total attempt limit and deadline cap the extra load.

```text
Before: 0ms [1000] -> 100ms [1000] -> 200ms [1000]
After:  0ms [1000] -> retries distributed across 100-300ms, then 300-900ms
```

**What the pattern solves:** brief faults can recover without synchronized pressure. It cannot make a non-idempotent charge safe: a timed-out charge may already have succeeded. Use an idempotency key or do not automatically retry it.

**Production checks:** retry connection resets, selected `429/5xx` responses, and not validation failures; honor `Retry-After`; emit the attempt number; combine retries with a circuit breaker and a single overall deadline.

**Try it:** classify DNS failure, HTTP 400, 429, 503, and read timeout as retryable or not, and justify each choice.

---

## DSP-3. Circuit Breaker Pattern

**Question:** How does a circuit breaker prevent cascading failure?

**Answer:** It stops calls to a dependency when recent failure or latency exceeds a threshold, then allows limited probes after a cooling period.

**What problem does this concept solve?** It prevents every caller from waiting on a dependency already known to be unhealthy.

**Before this concept:** Every request called the failing provider, exhausted resources, retried, and spread failure to otherwise healthy services.

❌ **Wrong example:** Keep calling a provider during an outage and increase retries because the success rate is falling.

✅ **Correct example:**

```text
Closed --failure threshold--> Open --cooldown--> Half-Open
   ^                                             | success
   +---------------------------------------------+
                          failure -> Open
```

```csharp
var pipeline = new ResiliencePipelineBuilder<HttpResponseMessage>()
    .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions {
        FailureRatio = 0.5,
        MinimumThroughput = 20,
        SamplingDuration = TimeSpan.FromSeconds(30),
        BreakDuration = TimeSpan.FromSeconds(20)
    }).Build();
```

**How it works after this pattern:** Calls fail fast or use a safe fallback while the dependency recovers; half-open probes decide when to resume.

**Trade-off:** Poor thresholds can open during harmless spikes or keep traffic away too long. Monitor state changes and rejected calls.

### Failure walkthrough — Circuit breaker: stop calling a failed tax provider

#### Before the pattern

The tax provider is down. Every checkout waits one second, retries twice, and consumes three outbound calls. Traffic backs up until checkout itself appears down, even though its own code and database are healthy.

#### After the pattern

The breaker observes failures in a rolling window. When the threshold is exceeded it opens and fails fast for a cool-down period. In half-open state, a small number of probes test recovery; success closes it, while failure reopens it.

```text
Closed --failure threshold--> Open --cool-down--> Half-open
   ^                                               |
   +---------------- successful probes ------------+
```

**What the pattern solves:** it prevents repeated expensive attempts against a known-bad dependency and protects caller capacity. It does not repair the dependency. A fallback must be genuinely safe—for example, mark tax as pending rather than inventing a zero tax.

**Production checks:** scope breakers by dependency/operation, avoid letting one tenant open a global breaker, expose state transitions, and place retries inside the breaker so one logical request contributes one final outcome.

**Try it:** decide what checkout should do in each breaker state and how the user sees a recoverable pending result.

---

## DSP-4. Bulkhead Pattern

**Question:** What is a bulkhead, and how does it isolate failures?

**Answer:** A bulkhead gives workloads separate, bounded resource pools such as concurrency limits, queues, threads, or connections.

**What problem does this concept solve?** One slow tenant or dependency cannot consume every resource and take down unrelated work.

**Before this concept:** All outbound calls shared one unbounded pool. A slow reporting provider starved payment traffic.

❌ **Wrong example:** Allow unlimited concurrent report exports and payment calls through the same worker and connection pool.

✅ **Correct example:**

```csharp
var paymentGate = new SemaphoreSlim(50);
await paymentGate.WaitAsync(ct);
try { return await paymentClient.ChargeAsync(command, ct); }
finally { paymentGate.Release(); }
```

**How it works after this pattern:** Payment, reporting, and tenant workloads have independent limits, so saturation remains contained.

**Trade-off:** Reserved capacity may sit idle, and limits require tuning. Prefer explicit rejection over unbounded queues.

### Failure walkthrough — Bulkhead: isolate reporting from payments

#### Before the pattern

Report downloads and payment calls share a 200-connection outbound pool. The report provider slows down and occupies all connections. Payments now wait for a resource unrelated to payment correctness.

#### After the pattern

Payments receive their own bounded pool and queue; reports receive a different pool with a lower limit. When reporting saturates, only reporting requests are rejected or delayed.

```text
Payment traffic -> pool 40, queue 80 -> payment provider
Report traffic  -> pool 10, queue 20 -> report provider
```

**What the pattern solves:** resource exhaustion stays inside a compartment. The limits must be bounded; an infinite queue only moves the outage into memory and latency.

**Production checks:** monitor active slots, queue length, rejection rate, and wait time. Isolate by dependency, criticality, tenant, or workload only when the failure domains justify the operational cost.

**Try it:** allocate 100 connections among checkout, notifications, and reports, then explain which traffic is rejected first during overload.

---

## DSP-5. Rate Limiting and Load Shedding

**Question:** How do rate limiting and load shedding differ?

**Answer:** Rate limiting enforces planned usage policy per caller or key. Load shedding rejects lower-priority work when the system is currently overloaded.

**What problem does this concept solve?** It protects capacity before queues, latency, and failure rates become uncontrollable.

**Before this concept:** The system accepted every request and slowed all users until instances and databases collapsed.

❌ **Wrong example:** Return `500` only after all worker threads and database connections are exhausted.

✅ **Correct example:**

```text
Gateway: per-tenant token bucket -> 429 + Retry-After
Service: concurrency limit -> reject low-priority work
Queue: maximum depth -> pause producers or shed optional jobs
```

**How it works after this pattern:** Excess work fails early and predictably while reserved capacity serves critical operations.

**Trade-off:** Rejection is visible to users, so prioritize fairly, communicate retry behavior, and measure shed work.

### Failure walkthrough — Rate limiting and load shedding: protect login capacity

#### Before the pattern

The service accepts every login attempt. A bot spike creates a long queue, password hashing consumes all CPU, and legitimate users also wait until requests time out. Autoscaling reacts too slowly because the bottleneck is the database and hashing cost.

#### After the pattern

An edge limiter applies per-IP and per-account token buckets; a global concurrency limit protects the service; critical internal traffic has reserved capacity. Excess requests receive an immediate `429` with retry guidance instead of entering an impossible queue.

**What the pattern solves:** controlled rejection keeps accepted work within the system’s safe operating envelope. Rate limiting enforces a policy over time; load shedding rejects work because current capacity is exhausted. They complement rather than replace each other.

**Production checks:** avoid one global key, make distributed counters sufficiently accurate, protect against hot tenants, and return consistent headers. Never use client-supplied identity without trusted authentication or proxy configuration.

**Try it:** design separate limits for anonymous login attempts, authenticated reads, and payment creation.

---

## DSP-6. Idempotent Consumer and Inbox Pattern

**Question:** How does a consumer safely process an at-least-once message?

**Answer:** Store a unique message ID in an inbox table in the same transaction as the business update. A repeated ID is acknowledged without repeating the side effect.

**What problem does this concept solve?** Brokers may redeliver after timeout, crash, or lost acknowledgement.

**Before this concept:** Every delivery sent another email, deducted stock again, or created a second payment.

❌ **Wrong example:** Check an in-memory `HashSet` of processed IDs; restart loses it, and several instances do not share it.

✅ **Correct example:**

```sql
BEGIN TRANSACTION;
INSERT INTO Inbox(MessageId, ProcessedAt)
VALUES (@messageId, SYSUTCDATETIME()); -- unique key

UPDATE Inventory SET Reserved = Reserved + @quantity WHERE Sku = @sku;
COMMIT;
```

**How it works after this pattern:** The first delivery commits inbox and business state atomically. Duplicate insert failure identifies redelivery and prevents a second update.

**Trade-off:** The inbox grows and needs retention. Scope IDs correctly and keep processing deterministic.

### Failure walkthrough — Idempotent consumer and inbox: process a payment event twice

#### Before the pattern

A consumer deducts gift-card balance and then crashes before acknowledging the message. The broker redelivers it. The consumer deducts the balance again because it cannot distinguish retry from new work.

```text
Delivery 1: deduct ✓ -> crash -> no ack
Delivery 2: deduct again ✗
```

#### After the pattern

The event has a stable message ID. In one local transaction, the consumer inserts that ID into an inbox table and applies the balance change. A unique constraint makes a redelivery detectable; if the inbox record already exists, the consumer acknowledges without repeating the business mutation.

**What the pattern solves:** at-least-once delivery becomes effectively-once *for the protected local effect*. The inbox must commit with the business update. Merely checking Redis and then writing the database leaves a race/crash gap.

**Production checks:** define deduplication retention, partition the inbox, distinguish event identity from correlation ID, and make downstream effects idempotent too.

**Try it:** crash at every line between receive, inbox insert, balance update, commit, and acknowledge; predict the redelivery result.

---

## DSP-7. Transactional Outbox Pattern

**Question:** How does the outbox solve the database-and-message dual-write problem?

**Answer:** Write the business change and an outgoing message record in one local transaction. A relay publishes committed outbox records later.

**What problem does this concept solve?** A process can crash between updating its database and publishing an event.

**Before this concept:** Either the database changed without an event or an event published for a transaction that later rolled back.

❌ **Wrong example:**

```csharp
await db.SaveChangesAsync(ct);
await broker.PublishAsync(new OrderPlaced(order.Id), ct); // crash gap
```

✅ **Correct example:**

```csharp
db.Orders.Add(order);
db.Outbox.Add(OutboxMessage.From(new OrderPlaced(order.Id)));
await db.SaveChangesAsync(ct); // one local transaction
// Relay publishes unpublished rows and marks them published.
```

**How it works after this pattern:** Every committed business change has a durable event to publish. Relay retries may duplicate delivery, so consumers remain idempotent.

**Trade-off:** Publication is eventually consistent and requires relay monitoring, cleanup, ordering rules, and lag metrics.

### Failure walkthrough — Transactional outbox: save an order and publish its event

#### Before the pattern

Two naïve orders both fail:

```text
DB commit -> crash -> publish never happens
Publish -> DB rollback -> consumers see an order that does not exist
```

There is no atomic transaction across a normal database and message broker.

#### After the pattern

The order and an outbox row are saved in one database transaction. A relay later reads unpublished rows, publishes them, and records progress. If it crashes after publishing but before marking the row, it publishes again, so consumers use inbox/idempotency.

**What the pattern solves:** no committed local change permanently loses its intent to publish. It provides at-least-once publication, not magical exactly-once delivery.

**Production checks:** preserve per-aggregate ordering when needed, lock/claim batches safely, alert on oldest unpublished age, archive rows, and include schema version and trace context in the event envelope.

**Try it:** explain how two relay replicas divide work and what happens when one loses its lease after publishing.

---

## DSP-8. Saga Pattern

**Question:** How does a saga coordinate a business transaction across services?

**Answer:** A saga breaks the workflow into local transactions and defines compensating actions for completed steps when a later step fails.

**What problem does this concept solve?** Independent service databases cannot share one simple ACID transaction.

**Before this concept:** A long distributed transaction held locks across order, payment, and inventory systems, or failures left partial state with no recovery process.

❌ **Wrong example:** Begin a database transaction, call three remote services while holding locks, and assume rollback can undo their external effects.

✅ **Correct example:**

```text
Create Order -> Reserve Inventory -> Authorize Payment -> Confirm Order
                     | failure              | failure
                     v                      v
                Cancel Order       Release Inventory + Cancel Order
```

**How it works after this pattern:** Each step commits locally and records saga state. Retries resume safely; compensation moves the business to an accepted alternative state.

**Trade-off:** Compensation is not time travel and may fail. Define business-visible intermediate states and manual recovery.

### Failure walkthrough — Saga: place an order across inventory and payment

#### Before the pattern

Order, inventory, and payment databases are updated as though one global transaction exists. A payment succeeds after inventory later rejects, leaving partial state and no durable record of what to undo. Holding distributed locks makes availability and recovery worse.

#### After the pattern

An orchestrated saga records its state and commands one local step at a time:

```text
Create Pending Order
 -> Reserve Inventory
 -> Authorize Payment
 -> Confirm Order

Failure at payment -> Release Inventory -> Mark Order Rejected
```

Every step and compensation is idempotent. Compensation is a business action, not database time travel: refunding a payment creates a new auditable transaction.

**What the pattern solves:** it provides explicit progress and recovery for a workflow that spans local transactions. It accepts intermediate states and requires users/support tools to understand them.

**Production checks:** persist saga state before dispatch, define retry versus compensation, handle stuck/manual states, and test messages arriving late or out of order.

**Try it:** add shipment creation after payment and decide what to do when cancellation arrives after dispatch.

---

## DSP-9. CQRS and Materialized View Pattern

**Question:** How does a materialized read model improve distributed queries?

**Answer:** Events or CDC update a query-specific projection so reads avoid synchronous joins across service-owned databases.

**What problem does this concept solve?** Cross-service reads are slow, fragile, and violate data ownership when they query databases directly.

**Before this concept:** A dashboard called five services on every request and failed if any one service was unavailable.

❌ **Wrong example:** Join Order, Payment, Customer, and Shipping databases directly from one reporting service.

✅ **Correct example:**

```text
Order events ----+
Payment events --+--> Dashboard Projector --> DashboardReadModel
Shipping events -+                              |
                                                +--> fast GET /dashboard
```

**How it works after this pattern:** Writes remain owned by source services; the dashboard reads one denormalized projection and exposes its freshness timestamp.

**Trade-off:** The view is eventually consistent and needs replay, schema evolution, deduplication, and reconciliation.

### Failure walkthrough — CQRS materialized view: serve an order dashboard

#### Before the pattern

Every dashboard request synchronously calls order, payment, customer, and shipping services. Latencies add, traffic multiplies, and one unavailable service makes the whole dashboard fail. Querying their databases directly would break ownership.

#### After the pattern

Each source publishes changes. A projector maintains a denormalized `OrderDashboard` read model. The API performs one local query and includes an `updatedAt` or sequence watermark so freshness is visible.

**What the pattern solves:** expensive cross-service joins move from request time to asynchronous projection time. Reads become fast and resilient, but temporarily stale.

**Production checks:** make projector updates idempotent, checkpoint consumed offsets, support replay/rebuild, monitor lag, and provide read-your-writes behavior for workflows that require it.

**Try it:** choose whether a newly placed order should be shown optimistically, read from the write service, or wait for the projection.

---

## DSP-10. Event Sourcing Pattern

**Question:** What is event sourcing, and how is it different from ordinary event publishing?

**Answer:** Event sourcing stores an aggregate's ordered domain events as its authoritative state. Current state is reconstructed by replay, often accelerated with snapshots.

**What problem does this concept solve?** It preserves complete history and supports temporal queries, audit, and rebuilding projections.

**Before this concept:** Updates overwrote rows, so the system knew current balance but not exactly how it got there.

❌ **Wrong example:** Save arbitrary integration events as JSON and assume that alone makes the system event sourced.

✅ **Correct example:**

```text
GiftCardIssued(+1000)
GiftCardRedeemed(-300)
GiftCardRefunded(+100)
Current balance after replay = 800
```

```csharp
var stream = await eventStore.LoadAsync(giftCardId, ct);
var card = GiftCard.Rehydrate(stream.Events);
var newEvents = card.Redeem(new Money(300));
await eventStore.AppendAsync(giftCardId, stream.Version, newEvents, ct);
```

**How it works after this pattern:** Optimistic stream versioning protects concurrency, events explain every transition, and projections can be rebuilt.

**Trade-off:** Event schemas are permanent history. Debugging, privacy deletion, migrations, and eventual projections are substantially more complex.

### Failure walkthrough — Event sourcing: preserve an account’s history

#### Before the pattern

An `Accounts` row stores only the current balance. Corrections overwrite values, so investigators cannot reconstruct which commands produced the total. An audit table written separately can diverge.

#### After the pattern

The aggregate stream stores immutable facts such as `AccountOpened`, `MoneyDeposited`, and `MoneyWithdrawn`. Current state is a fold over the ordered stream. A command appends only if the expected stream version still matches, preventing lost updates.

```text
version 1 Opened(0)
version 2 Deposited(100)
version 3 Withdrawn(30) -> state balance 70
```

**What the pattern solves:** history is authoritative and projections can be rebuilt. The cost is event schema evolution, replay tooling, storage growth, and eventual projections. Snapshots speed loading but are disposable caches, not the source of truth.

**Try it:** change the meaning of a fee event without rewriting history; design an upcaster or new event version.

---

## DSP-11. Leader Election and Lease Pattern

**Question:** How can many service instances ensure only one performs coordinator work?

**Answer:** Instances compete for a time-limited lease in a consensus-backed store. The leader renews it; another instance takes over after expiry.

**What problem does this concept solve?** It avoids duplicate coordination while still recovering when the current leader dies.

**Before this concept:** Every replica ran the same scheduler, sending duplicate invoices or compaction jobs.

❌ **Wrong example:** Set `IsLeader=true` in local memory on the first instance that starts.

✅ **Correct example:**

```text
Acquire lease(key, owner, expiresAt) with compare-and-set
Renew before expiry only if owner/version still matches
Stop work immediately when renewal fails
```

**How it works after this pattern:** One live lease holder coordinates work; expiry enables failover without manual intervention.

**Trade-off:** Clock assumptions and pauses matter. Use a proven coordination system and pair the lease with fencing for protected resources.

### Failure walkthrough — Leader election and lease: run one scheduler

#### Before the pattern

Five service replicas all run the hourly invoice scheduler. Customers receive five invoice attempts. A static `IS_LEADER=true` setting avoids duplication until that instance dies, after which nothing runs.

#### After the pattern

Replicas compete for a time-bounded lease in a consensus-capable store. The owner renews it periodically; if renewals stop, another replica acquires the lease. The job itself still uses idempotency because leadership can be briefly uncertain during pauses or network partitions.

**What the pattern solves:** coordination has one active owner with automatic failover. A lease is a time claim, not proof that an old process cannot resume—use fencing when stale writes would be dangerous.

**Production checks:** use monotonic/authoritative time, renew well before expiry, stop work on renewal failure, expose current leader, and make scheduled operations resumable.

**Try it:** pause the leader longer than the lease, let a new leader start, then resume the old process. Identify every operation that needs fencing.

---

## DSP-12. Distributed Lock and Fencing Token Pattern

**Question:** Why is a distributed lock alone insufficient for safe exclusive writes?

**Answer:** A paused lock holder may resume after its lease expired and write stale data. A monotonically increasing fencing token lets the protected resource reject older holders.

**What problem does this concept solve?** It prevents split-brain writes caused by delays, pauses, or uncertain lock ownership.

**Before this concept:** A worker assumed it still owned a lock after a long pause and overwrote work from the new owner.

❌ **Wrong example:** Acquire Redis lock for 30 seconds, perform a 60-second job, and write without checking ownership or version.

✅ **Correct example:**

```text
Worker A acquires token 41 -> pauses
Lease expires
Worker B acquires token 42 -> storage accepts write(42)
Worker A resumes -> storage rejects write(41)
```

**How it works after this pattern:** The lock limits concurrent intent, while the resource's token check provides correctness even when an old holder resumes.

**Trade-off:** The destination must enforce token ordering. Prefer database constraints or partition ownership when they solve the problem more simply.

### Failure walkthrough — Distributed lock plus fencing token: protect a file writer

#### Before the pattern

Worker A gets a lock and pauses for garbage collection. Its lock expires; worker B gets the lock and writes a newer file. Worker A resumes and, believing its old work is valid, overwrites B. The lock alone did not protect the resource.

#### After the pattern

Every successful lock acquisition receives a strictly increasing token. The storage target remembers the highest accepted token and rejects lower tokens.

```text
A gets token 41 -> pauses
B gets token 42 -> write accepted
A resumes with 41 -> write rejected as stale
```

**What the pattern solves:** the resource can reject stale owners even when processes disagree about lock validity. This requires the protected system to enforce tokens; a random lock ID that the resource never checks is not fencing.

**Try it:** design the conditional SQL update or object metadata check that rejects token 41 after 42.

---

## DSP-13. Consistent Hashing Pattern

**Question:** How does consistent hashing minimize redistribution when nodes change?

**Answer:** Place keys and virtual nodes in a hash space so adding or removing a node affects mainly neighboring ranges.

**What problem does this concept solve?** Modulo hashing remaps most keys whenever cluster size changes.

**Before this concept:** Adding one cache server caused a near-total cache miss storm.

❌ **Wrong example:**

```csharp
var server = servers[Hash(key) % servers.Count];
```

✅ **Correct example:**

```text
Ring: N1 -- vN2 -- N3 -- vN1 -- N2 -- vN3
Key walks clockwise to the next virtual node.
```

**How it works after this pattern:** Membership changes move a bounded share of keys; virtual nodes improve balance and support weighted capacity.

**Trade-off:** It does not solve hot keys, replication, or membership consensus. Rendezvous hashing may be simpler.

### Failure walkthrough — Consistent hashing: add a cache node

#### Before the pattern

Keys use `hash(key) % nodeCount`. Changing from four to five nodes changes the modulo result for roughly most keys, causing a huge cache miss wave and data movement.

#### After the pattern

Nodes and keys are placed on a logical hash ring. A key belongs to the next node clockwise. Adding a node moves only the neighboring range. Virtual nodes give each physical node many positions for smoother distribution.

**What the pattern solves:** membership changes remap a limited portion of keys. It does not automatically replicate data or handle very hot keys; add replicas, bounded load, and hot-key strategy where necessary.

**Production checks:** choose enough virtual nodes, weight heterogeneous servers, maintain compatible ring membership, and warm/migrate ranges without overloading the source.

**Try it:** draw an eight-slot ring, place three nodes, then add a fourth and mark exactly which key ranges move.

---

## DSP-14. Sharding Pattern

**Question:** How do you choose a shard key?

**Answer:** A shard key should distribute load, support dominant queries, preserve useful locality, and remain stable as the system grows.

**What problem does this concept solve?** It spreads data and traffic beyond one database's capacity.

**Before this concept:** One database handled every tenant and eventually hit storage, write, or maintenance limits.

❌ **Wrong example:** Shard sequential orders by current month when nearly all writes target the newest month, creating one hot shard.

✅ **Correct example:**

```text
Tenant SaaS: shard = hash(TenantId)
Queries include TenantId and route directly.
Large tenants can move to dedicated shards through a shard map.
```

**How it works after this pattern:** A router resolves the shard, most operations remain single-shard, and capacity grows by adding partitions.

**Trade-off:** Cross-shard transactions, joins, rebalancing, and globally unique constraints become harder.

### Failure walkthrough — Sharding: scale tenant data

#### Before the pattern

One database holds every tenant. CPU, storage, and write IOPS reach the machine limit. A few large tenants create noisy-neighbor effects, and maintenance affects everyone.

#### After the pattern

A shard map routes `tenantId` to a database. Rows retain the tenant key, unique constraints include it, and most transactions remain inside one shard. Large tenants can receive dedicated shards, while smaller tenants share balanced shards.

**What the pattern solves:** data and write load scale horizontally and failure domains shrink. Cross-shard joins, global uniqueness, rebalancing, and multi-shard transactions become harder.

**Production checks:** choose a stable high-cardinality key, prevent scatter queries on hot paths, version the shard map, and migrate with dual-read/verification or change capture.

**Try it:** explain why sharding orders by `orderId` may make “all orders for tenant” expensive, and propose a better key.

---

## DSP-15. Replication and Quorum Pattern

**Question:** How do read and write quorums affect consistency and availability?

**Answer:** With `N` replicas, a write quorum `W` and read quorum `R` overlap when `W + R > N`, increasing the chance a read observes the latest accepted write.

**What problem does this concept solve?** Replication improves durability and availability while quorum rules manage conflicting copies.

**Before this concept:** One copy was a failure risk, or asynchronous replicas returned stale values without a stated consistency model.

❌ **Wrong example:** Write to any one of three replicas and read from any one, then promise strong consistency.

✅ **Correct example:**

```text
N = 3, W = 2, R = 2
Write succeeds after two acknowledgements.
Read compares two versions and repairs stale replicas.
```

**How it works after this pattern:** The system tolerates some replica failures and has an explicit consistency/latency trade-off.

**Trade-off:** Quorums do not automatically provide linearizability; conflict resolution, clocks, partitions, and leader rules still matter.

### Failure walkthrough — Replication and quorum: keep a profile store available

#### Before the pattern

One database copy is the only source. A disk or host failure makes reads and writes unavailable and risks data loss. A simple asynchronous replica helps reads but may serve stale data or lose acknowledged writes during failover.

#### After the pattern

With `N` replicas, a write waits for `W` acknowledgements and a read consults `R` copies. When `W + R > N`, the sets overlap under the model, improving the chance of reading the latest version. Versions/vector clocks or last-write rules resolve conflicts.

**What the pattern solves:** copies improve fault tolerance and read scale, with tunable latency/consistency. Quorum mathematics does not eliminate sloppy quorums, partitions, clock issues, or application-level conflicts.

**Production checks:** define failover data-loss tolerance, replication lag SLO, read consistency by operation, repair divergent replicas, and test zone loss.

**Try it:** for `N=3`, compare `W=1/R=1`, `W=2/R=2`, and `W=3/R=1` for latency and consistency.

---

## DSP-16. Competing Consumers Pattern

**Question:** How does a queue scale background processing safely?

**Answer:** Several consumers share one subscription; each message is leased or delivered to one consumer, allowing parallel work.

**What problem does this concept solve?** It increases throughput and balances variable-duration jobs without assigning work manually.

**Before this concept:** One worker processed everything serially and became a backlog bottleneck.

❌ **Wrong example:** Start 100 consumers for a database that supports only 20 concurrent writes, creating more contention than throughput.

✅ **Correct example:**

```text
Queue depth -> autoscaling policy -> bounded worker count
Worker: receive -> process idempotently -> commit -> acknowledge
Failure: visibility timeout expires -> another worker retries
```

**How it works after this pattern:** Work distributes across healthy consumers and scales with backlog within downstream capacity.

**Trade-off:** Ordering is limited and duplicates are possible. Partition messages when related work requires ordering.

### Failure walkthrough — Competing consumers: scale image processing

#### Before the pattern

One worker reads an image queue sequentially. A traffic burst creates hours of lag. Starting another worker incorrectly causes both to process every message because work ownership/acknowledgement is not coordinated.

#### After the pattern

Many consumers join one consumer group. The broker gives each message to one active consumer, reassigns unacknowledged work after failure, and exposes lag for autoscaling. Consumers remain idempotent because reassignment can redeliver.

**What the pattern solves:** independent messages are processed in parallel. Ordering is generally guaranteed only within a partition, so partition by image/job identity when related operations must remain ordered.

**Production checks:** bound per-worker concurrency, extend visibility for long work, scale on lag and processing time, and route poison messages away from the main queue.

**Try it:** choose a partition key for ordered transformations of the same uploaded file without serializing all customers.

---

## DSP-17. Publish/Subscribe Pattern

**Question:** When should a system publish an event rather than place a task on one work queue?

**Answer:** Publish when several independent consumers need the same fact. Each subscription receives its own copy and can scale with competing consumers.

**What problem does this concept solve?** It decouples producers from a growing set of reactions.

**Before this concept:** Order service called inventory, analytics, email, and loyalty APIs directly.

❌ **Wrong example:** Put `OrderPlaced` on one queue and expect four different systems all to receive it; competing consumers divide rather than broadcast messages.

✅ **Correct example:**

```text
OrderPlaced topic
  +-- Inventory subscription -> inventory workers
  +-- Analytics subscription -> analytics workers
  +-- Email subscription     -> email workers
  +-- Loyalty subscription   -> loyalty workers
```

**How it works after this pattern:** New subscribers can react without changing the producer, and each consumer controls its own retries and lag.

**Trade-off:** Schema governance, duplicate handling, ordering, retention, and replay become platform responsibilities.

### Failure walkthrough — Publish/subscribe: distribute `OrderPlaced`

#### Before the pattern

The order service calls inventory, email, analytics, and loyalty APIs directly. Adding a subscriber changes the publisher, and one slow consumer delays the order request.

#### After the pattern

The service publishes one versioned business event. Independent subscriptions receive their own copies and track their own progress. Email can retry without replaying analytics, and a new fraud consumer subscribes without modifying the order service.

**What the pattern solves:** publisher and subscribers evolve independently in time and ownership. It introduces eventual consistency and makes global event contracts part of the platform API.

**Production checks:** use an outbox at the publisher, inbox/idempotency at subscribers, evolve schemas compatibly, secure topics, and distinguish domain facts from commands aimed at one owner.

**Try it:** decide whether `SendOrderEmail` should be an event or command and identify the owner of failure handling.

---

## DSP-18. Retry Queue, DLQ, and Parking Lot Pattern

**Question:** How should a messaging system handle messages that keep failing?

**Answer:** Retry transient failures with delayed queues; move exhausted or invalid messages to a dead-letter queue; use a parking lot for investigated messages awaiting controlled replay.

**What problem does this concept solve?** One poison message should not block a partition or retry forever.

**Before this concept:** Consumers immediately retried the same bad message, consuming CPU and preventing later messages from progressing.

❌ **Wrong example:** Catch every exception, place the message back on the same queue immediately, and record no attempt count or error context.

✅ **Correct example:**

```text
Main queue -> transient error -> Retry-1m -> Retry-10m -> Retry-1h
           -> permanent/exhausted -> DLQ
DLQ triage -> fixed/repaired -> Parking Lot -> controlled replay
```

**How it works after this pattern:** Transient faults get time to recover, poison messages are isolated with diagnostic metadata, and replay is deliberate and auditable.

**Trade-off:** Operations must own DLQ alerts, retention, repair tooling, and replay safety. A DLQ without a process is just hidden data loss.

### Failure walkthrough — Retry queue, DLQ, and parking lot: handle poison messages

#### Before the pattern

A malformed message fails, returns immediately to the head of the queue, and is retried thousands of times. It consumes CPU, floods logs, and may block its ordered partition.

#### After the pattern

Transient failures move through delayed retry levels with a bounded attempt count. Non-retryable or exhausted messages go to a DLQ with error context. Operators investigate, fix data/code, and replay through a controlled parking-lot workflow.

```text
Main -> retry-1m -> retry-10m -> retry-1h -> DLQ -> inspect/fix -> replay
```

**What the pattern solves:** bad work no longer monopolizes normal throughput, and failed input remains available for diagnosis. A DLQ is not a graveyard; alert on age/count and assign ownership.

**Try it:** specify which validation errors skip retries and what metadata is required for safe replay.

---

## DSP-19. Scatter-Gather Pattern

**Question:** How does scatter-gather query several sources within one latency budget?

**Answer:** Send requests in parallel, gather responses until a deadline or completion rule, then combine partial or complete results.

**What problem does this concept solve?** It reduces sequential latency for federated search, pricing, or availability.

**Before this concept:** The coordinator called providers one after another, so latencies added together.

❌ **Wrong example:** Wait forever for every provider, even when one is down and three good results are sufficient.

✅ **Correct example:**

```csharp
using var deadline = new CancellationTokenSource(TimeSpan.FromMilliseconds(500));
var tasks = providers.Select(p => p.SearchAsync(query, deadline.Token)).ToList();
var responses = await Task.WhenAll(tasks.Select(t => t.CatchAsResult()));
return MergeAndRank(responses.Where(x => x.IsSuccess).SelectMany(x => x.Value));
```

**How it works after this pattern:** Providers run concurrently, the coordinator enforces one deadline, and policy decides whether partial results are acceptable.

**Trade-off:** Fan-out multiplies downstream load. Bound concurrency, cancel slow work, and expose partial-result status when relevant.

### Failure walkthrough — Scatter-gather: search several suppliers

#### Before the pattern

The coordinator calls five suppliers sequentially. At 200 ms each, best-case latency is one second; one hung supplier can delay everything. Waiting for every source is unnecessary when three offers are enough.

#### After the pattern

Requests start concurrently under one 500 ms deadline. The gatherer merges successful replies until all complete or the business completion rule is met, cancels remaining work, and marks whether results are partial.

```text
t=0: scatter A B C D E
t=180ms: A,C return
t=260ms: D returns -> minimum 3 reached -> cancel B,E -> rank
```

**What the pattern solves:** latency becomes closer to the slowest accepted branch instead of the sum. Fan-out multiplies downstream traffic, so cap concurrency and avoid retrying every branch independently without a total retry budget.

**Try it:** define whether a price-comparison result may be partial and how the UI communicates that fact.

---

## DSP-20. Cell-Based Architecture Pattern

**Question:** How does cell-based architecture limit blast radius?

**Answer:** Divide the system into mostly independent cells, each serving a subset of tenants or users with its own compute and data dependencies.

**What problem does this concept solve?** A regional shared dependency failure should not affect the entire customer base.

**Before this concept:** All tenants used one large service and database cluster; overload or a bad deployment became global.

❌ **Wrong example:** Call a design “cell-based” while every cell still depends synchronously on one global database and cache.

✅ **Correct example:**

```text
Global routing/control plane
  +-- Cell A: API + workers + cache + tenant shards A
  +-- Cell B: API + workers + cache + tenant shards B
  +-- Cell C: API + workers + cache + tenant shards C
```

**How it works after this pattern:** A tenant maps to one cell, scaling happens by adding cells, and most failures remain inside one bounded group.

**Trade-off:** Cells duplicate infrastructure and complicate placement, migration, capacity planning, and carefully minimized global services.

### Failure walkthrough — Cell-based architecture: contain a tenant outage

#### Before the pattern

All tenants share one regional application, cache, queue, and database cluster. A bad deployment or one runaway tenant saturates shared dependencies; the entire region becomes one blast radius.

#### After the pattern

Tenants are assigned to self-contained cells, each with API, workers, queues, cache, and data shards. A thin control plane maps tenants to cells, but normal request paths avoid global synchronous dependencies. Deployment proceeds cell by cell and stops if health degrades.

```text
Tenant router -> Cell A [API, queue, cache, DB]
              -> Cell B [API, queue, cache, DB]
              -> Cell C [API, queue, cache, DB]
```

**What the pattern solves:** overload, failures, and bad releases affect a bounded population. The costs are duplicated infrastructure, uneven capacity, tenant placement/migration, and careful design of global identity/configuration.

**Production checks:** define maximum cell size, automate placement and evacuation, make control-plane data cacheable, test a complete cell loss, and measure per-cell saturation.

**Try it:** list every supposedly global service in your design and remove it from the synchronous request path or explain why it cannot be removed.

---

## Distributed Pattern Selection Cheat Sheet

| Failure or scaling problem | Pattern |
|---|---|
| Remote call may wait indefinitely | Timeout / Deadline |
| Brief transient failures | Retry + Backoff + Jitter |
| Dependency is persistently unhealthy | Circuit Breaker |
| One workload exhausts shared resources | Bulkhead |
| Incoming load exceeds safe capacity | Rate Limit / Load Shedding |
| Message can be delivered twice | Inbox / Idempotent Consumer |
| Database update and publish must not diverge | Transactional Outbox |
| Workflow spans several service databases | Saga |
| Cross-service read is too slow | Materialized View |
| Complete state history is authoritative | Event Sourcing |
| One coordinator must be active | Leader Lease |
| Old lock owner might resume | Fencing Token |
| Node changes should move few keys | Consistent Hashing |
| One database cannot hold the workload | Sharding |
| Copies must survive failures | Replication / Quorum |
| One queue needs more throughput | Competing Consumers |
| Many consumers need the same event | Publish/Subscribe |
| Poison messages block progress | Retry Queue / DLQ / Parking Lot |
| Query many sources in parallel | Scatter-Gather |
| Global blast radius is too large | Cell-Based Architecture |

---
