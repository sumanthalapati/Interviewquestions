# System Design Technologies & Fundamentals

Quick reference for core technologies and patterns. Each includes definition, Q&A, when to use, pros/cons, and right vs wrong usage.

---

## Table of Contents
1. [API Design & Patterns](#api-design)
2. [Caching Strategies](#caching)
3. [Load Balancing](#load-balancing)
4. [Database Patterns](#databases)
5. [Message Queues & Event Systems](#messaging)
6. [Search & Indexing](#search)
7. [Consistency Patterns](#consistency)
8. [Distributed Systems Concepts](#distributed)
9. [Network & Protocol Concepts](#network)
10. [Resilience Patterns](#resilience)
11. [Applied System Design Deep Dives](#tech-mastery)

---

<a id="api-design"></a>
## API Design & Patterns

### Definition
API (Application Programming Interface) is contract between client and server. Design determines usability, versioning, security, rate-limiting.

### Core Concepts

**REST API**: HTTP methods (GET, POST, PUT, DELETE) for resources. Stateless, cacheable.

**GraphQL**: Query language. Client specifies fields needed. Reduces over-fetching, under-fetching.

**RPC (Remote Procedure Call)**: Call remote function like local function. gRPC uses Protocol Buffers + HTTP/2.

**Webhooks**: Server calls client on events (reverse of polling).

### Q&A

**Q: REST vs GraphQL - when use which?**
- A: REST for simple CRUD (70% of APIs). GraphQL for complex queries, multiple clients with different needs. GraphQL harder to cache, monitor, rate-limit.

**Q: How to version APIs without breaking clients?**
- A: URL versioning (/v1/, /v2/), header versioning, or feature flags. Deprecate old versions gracefully (6-12 months notice). Support multiple versions simultaneously.

**Q: What is idempotency and why critical for APIs?**
- A: Operation produces same result if repeated. Critical for payments (prevent double-charge), retry logic. Use request ID to deduplicate.

**Q: How to rate-limit APIs effectively?**
- A: Token bucket (smooth bursts), leaky bucket (strict), sliding window (precise). Per-user/IP/API key. Return 429 status when exceeded.

### Why This Approach
- **REST**: Simple, cacheable, stateless. Matches HTTP well.
- **GraphQL**: Efficiency (only fetch needed fields). Complex queries single roundtrip.
- **Webhooks**: Real-time (no polling). Reduces latency for events.

### Pros & Cons

**REST Pros**: Simple, cacheable (HTTP cache), standard, easy to understand.
**REST Cons**: Over-fetching (get extra fields), under-fetching (need multiple calls), version proliferation.

**GraphQL Pros**: Query flexibility, single request for complex data, introspection.
**GraphQL Cons**: Harder to cache (POST requests), complex resolvers (N+1 queries), larger learning curve.

**RPC/gRPC Pros**: Function-like calls, binary protocol (small payload), multiplexing.
**RPC/gRPC Cons**: Not human-readable, firewall issues (not HTTP), less compatible.

### Right vs Wrong Usage

**✅ Right**: REST for public APIs, CRUD, caching-heavy. GraphQL for complex queries, mobile (bandwidth). gRPC for internal services, high throughput.

**❌ Wrong**: Don't use GraphQL for simple reads (over-engineered). Don't skip rate-limiting (abuse). Don't version REST APIs in body (version in URL/header).

**Alternative**: REST → GraphQL if efficiency matters. GraphQL → REST if caching more important. Webhook → Long polling if webhook unreliable.

---

<a id="caching"></a>
## Caching Strategies

### Definition
Caching stores frequently accessed data in fast storage (memory) to reduce latency and load on slower storage (DB).

### Cache Levels
- **L1**: Application memory (milliseconds)
- **L2**: Local cache server (tens of ms)
- **L3**: Distributed cache (Redis, Memcached) (100ms)
- **L4**: CDN (network edge) (1 sec)
- **L5**: Database (100ms-1sec)

### Caching Patterns

**Cache-Aside (Lazy Loading)**
```
1. Check cache
2. If miss, load from DB, store in cache
3. Return data
```
Best for: Read-heavy workloads.

**Write-Through**
```
1. Write to cache AND DB simultaneously
2. Return when both complete
```
Best for: Critical data, consistency-first.

**Write-Behind (Write-Back)**
```
1. Write to cache immediately
2. Async write to DB (100ms later)
3. Return immediately
```
Best for: High throughput, acceptable eventual consistency.

### Q&A

**Q: What is cache stampede (thundering herd)?**
- A: When cache expires, 100 requests hit DB simultaneously. Solution: Use locks (single thread refreshes), early expiration (probabilistic), or secondary cache.

**Q: How to handle cache consistency?**
- A: TTL (time-to-live, e.g., 5 minutes). Invalidation (delete on update). Leases (soft TTL, refresh early). Depends on consistency needs.

**Q: When should you use Memcached vs Redis?**
- A: Memcached: Simple KV, fast, no persistence. Redis: Rich data types (lists, sets, hashes), persistence, pub/sub. Redis 2-3x slower but more features.

**Q: How to prevent cache pollution (useless data in cache)?**
- A: LRU (Least Recently Used) eviction. Bloom filters (check before caching). Frequency-based eviction. Monitor cache hit rate.

### Why This Approach
- **Cache-aside**: Simplest, cache only hot data.
- **Write-through**: Safer (DB always fresh), but slower writes.
- **Write-behind**: Faster writes, async DB reduces latency.

### Pros & Cons

**Cache-Aside Pros**: Simple, only caches accessed data, failures don't corrupt cache.
**Cache-Aside Cons**: Cache misses expensive (DB hit), cache can go stale, complexity handling misses.

**Write-Through Pros**: DB always consistent, simple, good for critical data.
**Write-Through Cons**: Slower writes (wait for DB), unnecessary writes if no reads.

**Write-Behind Pros**: Fast writes (cache hit = done), throughput maximized.
**Write-Behind Cons**: Stale data, data loss if cache fails before DB write, consistency issues.

**LRU Eviction Pros**: Fair eviction, matches most workloads.
**LRU Eviction Cons**: O(1) complexity requires hash table (memory overhead), doesn't account for access frequency.

### Right vs Wrong Usage

**✅ Right**: Cache-aside for reads. Write-through for financial data. Write-behind for analytics. LRU for general purpose.

**❌ Wrong**: Don't cache everything (memory waste). Don't forget TTL (stale data). Don't ignore cache hit rate (tuning indicator). Don't cache large objects (100MB).

**Alternative**: Cache → Database if consistency critical. Redis → Memcached if simplicity > features. Write-behind → Write-through if data loss unacceptable.

---

<a id="load-balancing"></a>
## Load Balancing

### Definition
Load balancer distributes traffic across multiple servers to improve throughput, reduce latency, enable scaling.

### Load Balancing Algorithms

**Round Robin**: Rotate through servers sequentially. Simple, fair. Ignores server health, capacity.

**Least Connections**: Route to server with fewest active connections. Better for long-lived connections (WebSocket, SSH).

**IP Hash**: Hash client IP to server. Sticky sessions, cache-friendly. But uneven if IPs correlated (all from one datacenter).

**Weighted**: Route based on server capacity. Server A (2x) gets 2x traffic. Manual tuning needed.

**Random**: Pick random server. Surprisingly effective, low overhead.

**Resource-Based**: Route by CPU, memory, load. Dynamic. Requires monitoring.

### Q&A

**Q: What is sticky session (session affinity)?**
- A: Client always routed to same server. Preserves in-memory state. But breaks resilience (if server dies, state lost). Better: Use central session store (Redis).

**Q: How to detect and handle failed servers?**
- A: Health checks (periodic HTTP request). Remove failed servers from rotation. Graceful shutdown (stop accepting new connections).

**Q: What is connection pooling and why important?**
- A: Reuse TCP connections instead of creating new ones per request. Reduces latency (3-way handshake overhead). Reduces file descriptor exhaustion.

**Q: Why does DNS load balancing fail?**
- A: DNS caches at OS/client level (often 5+ seconds TTL). If server dies, clients still send traffic to dead IP for 5 seconds. Use application-level LB (HAProxy, NGINX, AWS ELB) instead.

### Why This Approach
- **Round Robin**: Simple, no state. Fair distribution.
- **Least Connections**: Better for long connections. Handles heterogeneous workloads.
- **IP Hash**: Cache-friendly (same client always to same server). Stateless LB.

### Pros & Cons

**Round Robin Pros**: Simple, zero overhead, stateless.
**Round Robin Cons**: Ignores server health/capacity, uneven load if requests differ in cost.

**Least Connections Pros**: Adapts to heterogeneous requests, good for long-lived connections.
**Least Connections Cons**: Requires tracking connections, fails if connection count misleading (slow client).

**IP Hash Pros**: Stateless, cache-friendly, predictable.
**IP Hash Cons**: Uneven if IPs correlated, fails if server removed (rehashing nightmare).

**Weighted Pros**: Respects server capacity, manual fine-tuning.
**Weighted Cons**: Requires manual tuning, hard to get right, doesn't adapt to dynamic load.

### Right vs Wrong Usage

**✅ Right**: Round robin for stateless APIs. Least connections for long connections. IP hash for cache locality. Health checks always.

**❌ Wrong**: Don't forget health checks (dead servers). Don't use DNS LB for dynamic scaling (stale TTL). Don't skip graceful shutdown. Don't use sticky sessions without central store (brittle).

**Alternative**: Round Robin → Least connections if load uneven. IP Hash → Random if rehashing pain. Health checks → Keep-alive probes if simpler.

---

<a id="databases"></a>
## Database Patterns

### Definition
Database (SQL or NoSQL) is persistent storage. SQL for relational, ACID. NoSQL for horizontal scale, eventual consistency.

### Types

**SQL (Relational)**: PostgreSQL, MySQL, Oracle. ACID, JOIN, transactions. Strong consistency.

**NoSQL-KV**: Redis, Memcached. Key-value only. Fast, simple.

**NoSQL-Document**: MongoDB, Firebase. JSON-like documents. Flexible schema.

**NoSQL-Graph**: Neo4j. Relationships as first-class. Fast relationship queries.

**NoSQL-TimeSeries**: InfluxDB, Prometheus. Optimized for time-ordered data. Compression, downsampling.

### Q&A

**Q: When to use SQL vs NoSQL?**
- A: SQL for relational data, transactions, complex queries (banking, ERP). NoSQL for simple queries, horizontal scale, flexible schema (social media, content).

**Q: What is ACID and BASE?**
- A: ACID (Atomicity, Consistency, Isolation, Durability) = strong guarantees. BASE (Basically Available, Soft state, Eventually consistent) = high availability, weaker guarantees. Different ends of spectrum.

**Q: How to scale SQL databases?**
- A: Sharding (split by user ID, date). Replication (reads from replicas). Caching (Redis). Denormalization (sacrifice normalization for speed).

**Q: What is index and when to create?**
- A: Index speeds up queries on indexed column (B-tree in background). Create for WHERE, JOIN, ORDER BY columns. Cost: slower writes (update index too).

### Why This Approach
- **SQL**: ACID, relational. Simpler queries for complex data.
- **NoSQL**: Scale, availability. Simpler schema (no migrations).
- **Sharding**: Unlimited scale. Tradeoff: cross-shard queries hard.

### Pros & Cons

**SQL Pros**: ACID, relational, complex queries, transactions.
**SQL Cons**: Vertical scale limit, schema migrations, joins expensive at scale.

**NoSQL-KV Pros**: Ultra-fast (memory), simple scale, no schema.
**NoSQL-KV Cons**: Only KV queries, data loss if no persistence, limited datatype.

**NoSQL-Document Pros**: Flexible schema, nested queries, scales horizontally.
**NoSQL-Document Cons**: Weaker transactions, no JOINs (do in app), eventual consistency.

**Sharding Pros**: Unlimited scale, independent shard scaling.
**Sharding Cons**: Complex application logic, cross-shard joins, resharding painful.

### Right vs Wrong Usage

**✅ Right**: SQL for financial (need ACID), complex schema. NoSQL for user sessions, cache. Sharding for 10B+ rows.

**❌ Wrong**: Don't use NoSQL for financial (no transactions). Don't shard prematurely (overhead). Don't create index on every column (disk space, write slowdown). Don't denormalize if not necessary (harder to reason about).

**Alternative**: SQL → NoSQL if scale/availability critical. Sharding → Vertical scale if simpler. Index → Materialized view for complex aggregations.

---

<a id="messaging"></a>
## Message Queues & Event Systems

### Definition
Message queue (RabbitMQ, Kafka, SQS) decouples producer and consumer. Producer sends message, consumer processes asynchronously.

### Patterns

**Queue (FIFO)**: Messages processed in order. Good for transactions, ordering matters.

**Pub/Sub (Topic)**: Producer publishes, multiple consumers subscribe. No ordering guarantee. Good for notifications, events.

**Request/Reply**: Producer sends message, waits for response. Blocking. Like RPC.

**Dead Letter Queue**: Failed messages sent here instead of dropped. Allows retry, debugging.

### Q&A

**Q: Kafka vs RabbitMQ vs SQS - when use which?**
- A: SQS for simplicity (AWS managed). RabbitMQ for reliability, exact guarantees. Kafka for high throughput (100k msg/sec), durability, replay.

**Q: What is at-least-once vs exactly-once delivery?**
- A: At-least-once: Message may be delivered multiple times. Exactly-once: Once per consumer. Exactly-once harder (requires deduplication, idempotent ops).

**Q: How to handle message ordering in distributed system?**
- A: Use single partition/queue for ordering, or include sequence number. Kafka: Single partition = ordered. Multiple partitions = parallel but unordered across partitions.

**Q: What is backpressure and why important?**
- A: Producer creating messages faster than consumer can process. Solution: Slow down producer (TCP backpressure), buffer messages (disk), or drop low-priority messages.

### Why This Approach
- **Queue**: Decoupling, async processing, resilience (producer doesn't care if consumer dies).
- **Pub/Sub**: Real-time, broadcasts to multiple listeners.
- **Kafka**: Durability (messages persist on disk), replay (re-read messages), parallelism (partitions).

### Pros & Cons

**Queue Pros**: Decoupling, resilience, async processing, allows scaling.
**Queue Cons**: Latency (queued), complexity (monitoring), ordering (if not careful).

**Pub/Sub Pros**: Real-time, no coupling, scalable listeners.
**Pub/Sub Cons**: No guaranteed delivery (if no subscribers, message lost), high latency possible (subscribers slow).

**Kafka Pros**: Durability, replay, parallelism (partitions), high throughput.
**Kafka Cons**: Complexity, requires cluster, disks fill up (retention policy), harder operations.

### Right vs Wrong Usage

**✅ Right**: Queue for order-dependent operations (payments). Pub/Sub for notifications (email, logs). Kafka for event streaming (analytics).

**❌ Wrong**: Don't use Pub/Sub for critical operations (may lose messages). Don't ignore backpressure (crash). Don't skip dead-letter queue (messages vanish). Don't assume Kafka guarantees order across partitions.

**Alternative**: Queue → Database + polling if simpler. Pub/Sub → Webhooks if one consumer. Kafka → RabbitMQ if scale lower.

---

<a id="search"></a>
## Search & Indexing

### Definition
Inverted index (Elasticsearch, Solr) maps words to documents. Fast full-text search, filtering, aggregations.

### Index Structures

**Inverted Index**: Word → [Doc1, Doc2, Doc3]. Fast substring search, fuzzy matching.

**B-Tree Index**: Ordered structure. Fast range queries, sorting.

**Hash Index**: Hash(key) → value. O(1) lookup. No range queries.

**Trie**: Tree of characters. Fast prefix matching (autocomplete).

### Q&A

**Q: Why is full-text search hard?**
- A: SQL LIKE '%word%' requires scanning every row. Inverted index = constant time. But requires separate index maintenance.

**Q: What is stemming and why useful?**
- A: Reducing word to root (running → run, walked → walk). Helps match variations. But can over-match (universal → univers).

**Q: How to implement autocomplete efficiently?**
- A: Prefix tree (Trie). As user types, traverse tree, suggest completions. Or cache top N autocomplete queries.

**Q: What is relevance ranking?**
- A: Score documents by relevance (BM25 algorithm). Frequency (more matches = higher score), rarity (rare words boost), recency (newer docs higher).

### Why This Approach
- **Inverted Index**: Fast full-text search. Tradeoff: index storage, maintenance cost.
- **Stemming**: Increased recall (find variations). Tradeoff: Over-matching (precision loss).
- **Relevance**: Ranked results better UX than boolean search.

### Pros & Cons

**Inverted Index Pros**: Fast full-text search, flexible queries, aggregations.
**Inverted Index Cons**: Index storage (2-3x data size), write cost (update index), complexity.

**Stemming Pros**: Matches variations, increased recall.
**Stemming Cons**: Over-matching (reducing precision), language-dependent.

**BM25 Ranking Pros**: Proven relevance, handles term frequency naturally.
**BM25 Ranking Cons**: Tuning parameters, doesn't account for semantic meaning.

### Right vs Wrong Usage

**✅ Right**: Inverted index for full-text (search products). Stemming for natural language. BM25 for keyword ranking.

**❌ Wrong**: Don't use SQL LIKE for millions of documents (slow). Don't skip stemming if doing full-text. Don't assume relevance without ranking (users expect Google-like results).

**Alternative**: Inverted Index → SQL if small data. Stemming → Exact match if precision critical. Elasticsearch → Database if simplicity > search features.

---

<a id="consistency"></a>
## Consistency Patterns

### Definition
Consistency = different copies of data agree. Spectrum: Strong (immediate) to Eventual (eventually agree).

### Patterns

**Strong Consistency**: All reads see latest write. Wait for replication to complete before responding. Slow but safe.

**Eventual Consistency**: Reads may see stale data temporarily. Replication async. Fast but risky.

**Causal Consistency**: If A caused B, all readers see A before B. Middle ground.

**Read-Your-Writes**: Reader sees own writes immediately (but not others'). Session guarantee.

### Q&A

**Q: CAP theorem - explain the three:**
- A: Consistency (all agree), Availability (always respond), Partition-tolerance (survive network split). Pick 2. Usually trade Consistency for Availability + Partition-tolerance.

**Q: How does replication achieve strong consistency?**
- A: Synchronous replication (wait for majority quorum to confirm). Paxos, Raft consensus. Slow (latency = replication time) but safe.

**Q: How to handle split-brain (network partition)?**
- A: Quorum-based voting. If can't reach majority, stop serving (avoid divergence). Or last-write-wins (conflicts possible).

**Q: What is vector clock?**
- A: Tracks causality in distributed system. Each node increments own counter on event, includes in messages. Detects if two events concurrent or causal.

### Why This Approach
- **Strong**: Safe (no data loss). Cost: Latency.
- **Eventual**: Fast (no waiting for replication). Cost: Stale reads, conflict possible.
- **Quorum**: Balance. Require majority (harder to partition), still responsive.

### Pros & Cons

**Strong Consistency Pros**: No stale reads, simpler to reason about.
**Strong Consistency Cons**: Slower (wait for replication), lower availability if partition.

**Eventual Consistency Pros**: Fast, high availability, survives partitions.
**Eventual Consistency Cons**: Stale reads, conflicts possible, harder to code (race conditions).

**Quorum Pros**: Balance consistency and availability, handles partitions gracefully.
**Quorum Cons**: Latency (wait for majority), odd number nodes (3, 5, 7), parity nodes overhead.

### Right vs Wrong Usage

**✅ Right**: Strong consistency for financial transactions. Eventual for user profiles. Quorum for critical data.

**❌ Wrong**: Don't use eventual consistency for banking (unsafe). Don't ignore CAP theorem (impossible guarantees). Don't use 2-node cluster (no true quorum).

**Alternative**: Strong → Eventual if latency too high. Eventual → Strong if consistency non-negotiable. Quorum → Master-slave if simplicity matters.

---

<a id="distributed"></a>
## Distributed Systems Concepts

### Definition
Distributed system = multiple independent computers (nodes) that appear as single system to user.

### Key Concepts

**Fault Tolerance**: System continues despite failures. Replication, redundancy.

**Eventual Consistency**: All nodes eventually agree. No blocking for immediate consistency.

**Byzantine Fault Tolerance**: Tolerate nodes lying (malicious or buggy). Requires 2f+1 nodes to tolerate f failures.

**Latency**: Delay in message transmission. Network latency dominates.

**Throughput**: Messages/requests per second. Scale horizontally (add nodes).

**Sharding**: Split data across nodes. Scales storage, reduces per-node load.

### Q&A

**Q: What is two-phase commit (2PC) and why is it hard?**
- A: Coordinator asks all nodes to prepare (lock resources), then commit. If any node says no, rollback. Problem: If coordinator dies after prepare, nodes blocked. Rarely used (too slow, brittle).

**Q: What is consensus and why hard?**
- A: All nodes agree on value despite failures. Paxos, Raft, Byzantine algorithms. Hard because network unreliable (messages lost, delayed, duplicated, reordered).

**Q: What is leader election?**
- A: Designate one node as leader (coordinates writes). If leader dies, elect new one. Solutions: Bully algorithm, ring algorithm, Raft.

**Q: Why does clock synchronization matter?**
- A: Nodes need to agree on time for causality, timeouts, leases. Use NTP (Network Time Protocol) for rough sync (millisecond), or logical clocks (Lamport, Vector) for causality.

### Why This Approach
- **Replication**: Fault tolerance. Tradeoff: Consistency.
- **Sharding**: Unlimited scale. Tradeoff: Cross-shard queries.
- **Eventual Consistency**: High availability. Tradeoff: Stale reads, conflicts.

### Pros & Cons

**Replication Pros**: Fault tolerance, read scaling, resilience.
**Replication Cons**: Consistency complexity, storage overhead, network bandwidth.

**Sharding Pros**: Unlimited scale, reduced per-node load.
**Sharding Cons**: Complex queries (join across shards), uneven distribution (hot shards).

**Eventual Consistency Pros**: Fast, high availability, survives partitions.
**Eventual Consistency Cons**: Stale reads, conflicts (need resolution), harder to code.

### Right vs Wrong Usage

**✅ Right**: Replication for critical data. Sharding for 10B+ rows. Eventual consistency for high-scale systems.

**❌ Wrong**: Don't shard a 100M row table (overhead > benefit). Don't use 2PC (too slow). Don't ignore Byzantine failures if untrusted nodes.

**Alternative**: Replication → Master-only if simplicity. Sharding → Vertical if scale not needed. Eventual → Strong if possible.

---

<a id="network"></a>
## Network & Protocol Concepts

### Definition
Network = communication layer. Protocols = rules (TCP, HTTP, DNS, gRPC).

### Protocols

**TCP**: Reliable, ordered delivery. Connection-oriented. Slow (handshake, ACKs) but safe.

**UDP**: Fast, unreliable. Connectionless. Good for video, gaming (can tolerate loss).

**HTTP**: Request-response over TCP. Stateless. Built-in caching, security (HTTPS).

**gRPC**: Binary protocol (Protocol Buffers) over HTTP/2. Fast, multiplexing, language-agnostic.

**WebSocket**: Bidirectional persistent connection. Real-time, low latency.

**DNS**: Maps domain names to IPs. Cached (stale), decentralized.

### Q&A

**Q: Why does HTTPS matter?**
- A: Encrypts traffic (prevent eavesdropping), authenticates server (prevent man-in-middle). Cost: Handshake overhead (but caching, session resumption mitigate).

**Q: What is connection pooling and why important?**
- A: Reuse TCP connections. Avoids 3-way handshake overhead per request. Reduces latency, file descriptor exhaustion.

**Q: Why does DNS have stale results?**
- A: Clients cache DNS (often 5+ seconds TTL). If server dies, clients send to dead IP for 5 seconds. Solution: Shorter TTL (cost: more queries), or application-level LB.

**Q: What is HTTP/2 and how better than HTTP/1?**
- A: HTTP/1: One request per connection (slow). HTTP/2: Multiplexing (multiple requests on same connection). Push (server sends data proactively). Binary (smaller). Server push helps latency.

### Why This Approach
- **TCP**: Reliability beats speed. Use when correctness critical (file transfer).
- **UDP**: Speed beats reliability. Use when latency critical (video, gaming).
- **HTTP**: Simple, stateless, cacheable. Matches web.
- **WebSocket**: Persistent connection reduces latency vs polling.

### Pros & Cons

**TCP Pros**: Reliable, ordered, connection-oriented.
**TCP Cons**: Overhead (handshake, ACKs), slower than UDP.

**UDP Pros**: Fast, low latency, low overhead.
**UDP Cons**: Unreliable (packet loss), no ordering, no flow control.

**HTTP Pros**: Simple, stateless, cacheable, security built-in (HTTPS).
**HTTP Cons**: Overhead (headers), request-response only (polling needed for events).

**WebSocket Pros**: Persistent connection, real-time, low latency.
**WebSocket Cons**: Stateful (harder to scale), firewall issues (non-HTTP), battery drain on mobile.

### Right vs Wrong Usage

**✅ Right**: TCP for file transfer, databases. UDP for video, gaming. HTTP for web APIs. WebSocket for real-time (chat, notifications).

**❌ Wrong**: Don't use UDP for banking (unreliable). Don't skip HTTPS (security). Don't use WebSocket for simple reads (overkill). Don't ignore connection pooling (waste of TCP handshakes).

**Alternative**: TCP → UDP if latency more important. HTTP → gRPC if throughput critical. WebSocket → HTTP polling if battery/complexity concerns.

---

<a id="resilience"></a>
## Resilience Patterns

### Definition
Resilience = ability to recover from failures gracefully. Patterns prevent cascading failures.

### Patterns

**Circuit Breaker**: Stop calling failing service. After timeout, try again. Like electrical circuit breaker (stops current if overload).

**Retry**: Call failed service again. Exponential backoff (1sec, 2sec, 4sec) avoids thundering herd.

**Timeout**: Abort request if no response in N seconds. Prevents hanging requests.

**Bulkhead**: Isolate failures. Use separate thread pools, resources per service. Failure in one doesn't affect others.

**Graceful Degradation**: Reduce features if under load. Show cached data instead of real-time. Better UX than full outage.

### Q&A

**Q: Why exponential backoff vs linear?**
- A: Exponential avoids thundering herd (all retry at same time). Each retry waits longer (1s, 2s, 4s, 8s), reducing congestion. Linear (1s, 2s, 3s) can retry together.

**Q: What is idempotency and why important for retries?**
- A: Operation produces same result if repeated. Critical for retries (if network fails after server processes, retry should not double-charge). Use request ID.

**Q: How does bulkhead isolate failures?**
- A: Separate resource pools (threads, connections) per service. If service A slow, only A's requests wait. Service B unaffected.

**Q: What is health check and why critical?**
- A: Periodic check if service alive. If check fails, remove from load balancer. Prevents sending traffic to dead services.

### Why This Approach
- **Circuit Breaker**: Fails fast. Prevents cascading failures.
- **Retry + Backoff**: Handles transient failures. Reduces latency vs immediate fail.
- **Timeout**: Prevents hanging requests, improves UX.
- **Bulkhead**: Isolation prevents cascade. One service failure doesn't kill everything.

### Pros & Cons

**Circuit Breaker Pros**: Fails fast, prevents cascade, allows recovery time.
**Circuit Breaker Cons**: Requires tuning (open threshold, timeout), adds latency checking.

**Retry + Backoff Pros**: Handles transient failures, improves availability.
**Retry + Backoff Cons**: Increased latency (wait between retries), requires idempotency.

**Timeout Pros**: Prevents hanging requests, predictable latency SLA.
**Timeout Cons**: May timeout legitimate slow requests, requires tuning.

**Bulkhead Pros**: Isolation (failure contained), independent scaling.
**Bulkhead Cons**: Resource overhead (separate pools), complexity.

### Right vs Wrong Usage

**✅ Right**: Circuit breaker for external APIs. Retry + exponential backoff for transient errors. Timeout always. Bulkhead for critical services.

**❌ Wrong**: Don't retry without idempotency (double-charge). Don't ignore timeouts (hanging). Don't skip health checks (dead services accepted). Don't use short circuit-breaker timeout (flaps open/close).

**Alternative**: Circuit Breaker → Manual fallback if simpler. Retry → Fail immediately if latency critical. Timeout → Long timeout if operations must complete.

---

## Summary Table

| Technology | Problem | Solution | Trade-off |
|-----------|---------|----------|-----------|
| REST API | Flexibility | GraphQL | Caching complexity |
| Cache-Aside | Consistency | Check cache first | Stale data |
| Write-Through | Safety | Write to both | Slower writes |
| Round Robin | Even distribution | Simple algorithm | Ignores server health |
| SQL | Complex queries | Relational DB | Vertical scale limit |
| NoSQL | Horizontal scale | Loose schema | No transactions |
| Kafka | High throughput | Partitioned queue | Operational complexity |
| Inverted Index | Full-text search | Word → docs | Index storage |
| Strong Consistency | Safety | Synchronous replication | Higher latency |
| Circuit Breaker | Cascade failures | Stop calling failed service | Complex tuning |

---

**Key Takeaway**: Every technology trades something. No silver bullet. Choose based on constraints (latency, consistency, availability, cost).

---

<a id="tech-mastery"></a>
# Applied System Design Deep Dives

These additions close practical gaps identified while comparing this repository with the [Fanout System Design roadmap](https://fanout.sh/roadmaps/system-design). They complement the broader roadmap rather than reproduce it. Each topic connects a design decision to a failure you can observe and test.

## TECH-M1 — Cost-Aware Architecture and Knowing When Not to Add Infrastructure

**Question:** How do you decide whether a cache, message broker, search cluster, or new microservice is justified?

**Answer:** Start with a measured constraint and choose the simplest design that satisfies it with reasonable headroom. New infrastructure is justified only when it removes a named bottleneck or reliability risk whose cost is greater than the new operational burden.

**What problem does it solve?** It prevents teams from paying permanent complexity—deployments, monitoring, security, failure modes, migrations, and specialist knowledge—for hypothetical scale that may never arrive.

**Before this concept:** Architecture decisions were based on recognizable technology names instead of workload evidence.

❌ **Wrong/before example:**

```text
Requirement: create and list 20,000 internal tickets per month.

Proposed design:
API gateway -> six microservices -> Kafka -> Redis -> search cluster
                    |                         |
                    +------ three databases -+

No latency target, traffic estimate, failure model, or measured bottleneck exists.
```

✅ **After/correct example:**

```yaml
decision: Start with one modular service and PostgreSQL
assumptions:
  average_writes_per_second: 0.01
  peak_factor: 100
  searchable_rows_after_three_years: 720000
requirements:
  availability_slo: 99.9%
  p95_read_latency_ms: 300
  recovery_point_objective_minutes: 15
add_cache_when:
  - measured database read saturation exceeds 65% during representative peaks
  - a repeated read has a defined staleness budget
add_broker_when:
  - accepted work must survive request/process failure
  - producers and consumers need independent scaling or retry ownership
add_search_engine_when:
  - database text search misses a measured relevance, latency, or language requirement
```

**How it works now:** Requirements create decision thresholds. The initial design remains observable and modular, so a new component can be introduced when evidence crosses a threshold. The team records what would trigger the change instead of pretending the first design must last forever.

**Trade-offs and when not to use it:** Simplicity is not an excuse to ignore known scale or regulatory requirements. Introduce necessary infrastructure early when migration lead time is long, but state the evidence and cost explicitly.

**Production checks:** Track utilization, latency percentiles, error rate, growth, cloud spend, operational ownership, recovery objectives, and the migration plan for each declared threshold.

**Try it:** Remove one component from an existing design. Write the exact requirement that breaks, the metric that proves it, and the smallest component that restores the requirement.

---

## TECH-M2 — Fan-Out, Fan-In, and Tail Latency

**Question:** Why can a request become slow even when every downstream service has a good average latency?

**Answer:** A fan-out request completes when enough downstream branches complete. If it waits for every branch, the slowest branch controls response time, so rare slow calls become common at the aggregate level as fan-out width grows.

**What problem does it solve?** It explains why averages hide user-visible latency and why blindly querying more shards or services can make p99 latency and dependency load explode.

**Before this concept:** The aggregator launched every call and waited indefinitely for all results because parallel work appeared automatically fast.

❌ **Wrong/before example:**

```csharp
var tasks = allShards.Select(shard => shard.Search(query, CancellationToken.None));
var results = await Task.WhenAll(tasks); // one stalled shard stalls the response
return MergeAndRank(results);
```

✅ **After/correct example:**

```csharp
using var deadline = CancellationTokenSource.CreateLinkedTokenSource(requestAborted);
deadline.CancelAfter(TimeSpan.FromMilliseconds(450));

var pending = selectedShards
    .Select(shard => shard.Search(query, deadline.Token))
    .ToList();
var selectedCount = pending.Count;
var completed = new List<SearchResult>();

try
{
    while (pending.Count > 0 && completed.Count < requiredSuccessfulShards)
    {
        var next = await Task.WhenAny(pending).WaitAsync(deadline.Token);
        pending.Remove(next);

        try { completed.Add(await next); }
        catch (Exception exception) when (IsRecoverableShardFailure(exception))
        {
            // Record the failed shard; continue only if the response contract allows partial data.
        }
    }
}
catch (OperationCanceledException) when (deadline.IsCancellationRequested)
{
    // The response decision below applies the product's completeness rule.
}
finally
{
    await deadline.CancelAsync(); // stop branches whose results are no longer useful
}

return completed.Count >= requiredSuccessfulShards
    ? Results.Ok(new
      {
          items = MergeAndRank(completed),
          completeness = completed.Count == selectedCount ? "full" : "partial"
      })
    : Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
```

**How it works now:** One end-to-end deadline bounds resource use. The response contract states whether partial results are allowed, fan-out width is limited to useful shards, and abandoned work is cancelled. Metrics distinguish complete, partial, timed-out, and failed requests.

**Trade-offs and when not to use it:** Partial results are invalid for operations such as authorization or balance calculation. Hedged duplicate reads can reduce tails but increase load; use them only for safe, idempotent reads and delay the hedge until a measured percentile is exceeded.

**Production checks:** Monitor p50/p95/p99, per-branch latency, fan-out width, cancelled work, partial-result rate, dependency amplification, and deadline exhaustion. Load-test slow and failed branches, not only the happy path.

**Try it:** Simulate 50 shards where one percent of calls take two seconds. Compare average branch latency with aggregate p99 and test a 450 ms deadline.

Reference: [Fan-out, fan-in, feeds and tail latency](https://fanout.sh/blog/fan-out) and Google Research’s [The Tail at Scale](https://research.google/pubs/the-tail-at-scale/).

---

## TECH-M3 — Queue Lag, Backpressure, and Useful Autoscaling

**Question:** Why is worker CPU alone a poor signal for the health of an asynchronous queue?

**Answer:** CPU describes current resource use, but queue lag describes whether the system is keeping its promise to finish accepted work on time. Measure both backlog depth and age of the oldest ready item; then bound admission and scale from processing demand, not merely host utilization.

**What problem does it solve?** It detects a silently growing backlog before users discover hours-old emails, reports, payments, or index updates.

**Before this concept:** Producers accepted unlimited work and operators watched only worker CPU.

❌ **Wrong/before example:**

```csharp
app.MapPost("/exports", (ExportRequest request) =>
{
    unboundedQueue.Enqueue(request);
    return Results.Accepted(); // accepted even when completion will take days
});
```

✅ **After/correct example:**

```csharp
public sealed record QueueHealth(
    long ReadyCount,
    TimeSpan OldestReadyAge,
    double ArrivalRatePerSecond,
    double CompletionRatePerSecond);

app.MapPost("/exports", async (ExportRequest request, IExportQueue queue, CancellationToken ct) =>
{
    QueueHealth health = await queue.Measure(ct);
    bool cannotMeetPromise =
        health.OldestReadyAge > TimeSpan.FromMinutes(10) ||
        (health.ReadyCount > 5_000 && health.ArrivalRatePerSecond >= health.CompletionRatePerSecond);

    if (cannotMeetPromise)
        return Results.Problem(statusCode: 503, title: "Export capacity is temporarily full");

    var job = await queue.EnqueueDurably(request, ct);
    return Results.Accepted($"/exports/{job.Id}", new { job.Id });
});
```

**How it works now:** Admission stops promising work the system cannot finish. Autoscaling uses arrival rate, service time, backlog age, and maximum concurrency. A durable job record lets the client observe pending, running, succeeded, or failed state.

**Trade-offs and when not to use it:** More workers do not help when the database, provider quota, or partition count is the bottleneck. Excessive scale-out can make the dependency fail faster. Some workloads need priority queues rather than one global lag target.

**Production checks:** Alert on oldest-item age and time-to-drain, cap attempts and concurrency, separate ready/retry/dead-letter counts, make handlers idempotent, and test overload plus dependency slowdown.

**Try it:** Given 100 jobs/second arriving and each worker completing 8 jobs/second, calculate the minimum workers and the extra headroom required after one worker fails.

---

## TECH-M4 — A PostgreSQL Work Queue with `SKIP LOCKED`

**Question:** How can several workers claim database-backed jobs without processing the same row concurrently?

**Answer:** Claim a small ordered batch inside a transaction using `FOR UPDATE SKIP LOCKED`, record a lease owner and expiry, then commit before doing long work. Completion updates must verify the owner or lease token.

**What problem does it solve?** It provides a durable queue for modest workloads without a separate broker while allowing multiple consumers to avoid waiting on rows another consumer already claimed.

**Before this concept:** Workers selected pending rows first and updated them later, so two workers saw the same work.

❌ **Wrong/before example:**

```sql
SELECT id, payload FROM jobs
WHERE status = 'pending'
ORDER BY created_at
LIMIT 20;

-- Another worker can select the same rows before this update runs.
UPDATE jobs SET status = 'processing' WHERE id = ANY(@ids);
```

✅ **After/correct example:**

```sql
BEGIN;

WITH claimable AS (
    SELECT id
    FROM jobs
    WHERE (status = 'pending' AND available_at <= now())
       OR (status = 'processing' AND lease_until < now())
    ORDER BY COALESCE(lease_until, available_at), id
    FOR UPDATE SKIP LOCKED
    LIMIT 20
)
UPDATE jobs AS job
SET status = 'processing',
    lease_owner = @worker_id,
    lease_until = now() + interval '30 seconds',
    attempts = attempts + 1
FROM claimable
WHERE job.id = claimable.id
RETURNING job.id, job.payload, job.lease_owner, job.lease_until;

COMMIT;
```

After processing, acknowledge conditionally:

```sql
UPDATE jobs
SET status = 'completed', completed_at = now()
WHERE id = @id
  AND status = 'processing'
  AND lease_owner = @worker_id;
```

**How it works now:** Row locks make claiming atomic, `SKIP LOCKED` lets other workers claim different rows, and the short transaction ends before expensive processing. An expired lease makes abandoned work recoverable. Idempotency still protects against a worker completing an effect and crashing before acknowledgement.

**Trade-offs and when not to use it:** `SKIP LOCKED` deliberately gives an inconsistent view and is suitable for queue-like access, not ordinary business queries. A dedicated broker is usually better for very high throughput, long retention, cross-region delivery, or many independent consumer groups.

**Production checks:** Add partial indexes for pending availability and expired processing leases, keep claim batches small, use database time for leases, cap attempts, move poison jobs aside, renew long leases safely, monitor oldest age, and vacuum/archive completed rows.

**Try it:** Run two transactions simultaneously and prove they receive disjoint job IDs. Kill one worker after claiming and verify its jobs become claimable after lease expiry.

Reference: PostgreSQL documents that [`SKIP LOCKED` can avoid contention for multiple consumers of a queue-like table](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE).

---

## TECH-M5 — LSM Storage Engines: WAL, Memtable, SSTables, and Compaction

**Question:** How does a log-structured merge-tree (LSM-tree) turn many random writes into efficient sequential storage work?

**Answer:** It records the write in a write-ahead log (WAL), updates a sorted in-memory memtable, flushes full immutable memtables into sorted-string table (SSTable) files, and later compacts files to remove overwritten or deleted versions.

**What problem does it solve?** It makes write-heavy key-value workloads efficient on storage where sequential appends and batch rewrites are cheaper than frequent in-place random updates.

**Before this concept:** Every update searched for an on-disk record and rewrote it in place.

❌ **Wrong/before example:**

```text
for each write:
    seek to the old key on disk
    overwrite a variable-sized record
    acknowledge before durable metadata is safe

Crash result: torn records and ambiguous recovery.
Workload result: many small random writes.
```

✅ **After/correct example:**

```text
write(key, value):
    append (sequence, key, value, checksum) to WAL
    fsync according to the promised durability level
    insert the newest version into the sorted memtable
    acknowledge

when memtable is full:
    freeze it as immutable
    flush its sorted entries to a new SSTable
    publish the SSTable atomically in the manifest
    retire the covered WAL only after the SSTable is durable

read(key):
    check mutable and immutable memtables
    use Bloom filters and indexes to skip impossible SSTables
    return the newest visible sequence

background compaction:
    merge overlapping SSTables
    discard shadowed versions and eligible tombstones
```

**How it works now:** The WAL enables crash recovery, the memtable makes recent writes searchable, immutable SSTables simplify concurrent reads, and compaction restores read/space efficiency. Sequence numbers decide which version is newest.

**Trade-offs and when not to use it:** LSM engines trade write efficiency for compaction work, read amplification, write amplification, temporary disk usage, and delayed space reclamation. A B-tree may be better for read-heavy workloads requiring predictable point/range reads and frequent in-place updates.

**Production checks:** Monitor WAL sync latency, immutable-memtable backlog, flush rate, compaction debt, read/write/space amplification, Bloom-filter usefulness, disk headroom, checksum failures, and recovery time after an unclean stop.

**Try it:** Trace one key through three updates, one flush, and one compaction. Mark every copy of the key and the moment each old version becomes safe to discard.

Reference: the RocksDB project describes its [memtable, WAL, SSTable, checksum, and compaction architecture](https://github.com/facebook/rocksdb/wiki/RocksDB-Overview).

---

## TECH-M6 — End-to-End Checksums for Object and File Integrity

**Question:** Why is an HTTP success response or object-store ETag not enough proof that a large file is correct end to end?

**Answer:** A success response confirms the request completed according to one boundary. End-to-end integrity requires a checksum computed over the intended bytes, validated during upload, stored with the object, and checked again when the object is read or copied.

**What problem does it solve?** It detects corruption or truncation introduced by clients, proxies, multipart assembly, storage, replication, downloads, or application bugs.

**Before this concept:** The application trusted status codes and file size.

❌ **Wrong/before example:**

```csharp
await objectStore.Upload("video/42", stream, ct);
db.Files.Add(new FileRecord("video/42", stream.Length));
// A matching length does not prove the bytes are identical.
```

✅ **After/correct example:**

```csharp
await using var source = File.OpenRead(path);
byte[] expected = await SHA256.HashDataAsync(source, ct);
source.Position = 0;

await objectStore.Upload(
    key: "video/42",
    content: source,
    checksumAlgorithm: "SHA256",
    checksum: Convert.ToBase64String(expected),
    cancellationToken: ct);

FileMetadata stored = await objectStore.Head("video/42", ct);
if (!CryptographicOperations.FixedTimeEquals(
        expected,
        Convert.FromBase64String(stored.Checksum)))
{
    throw new InvalidDataException("Stored object checksum does not match the source.");
}
```

**How it works now:** The producer defines the expected digest, the storage boundary validates received bytes, metadata keeps the digest with the object, and later readers can verify the content they actually received. Multipart uploads validate parts and, where supported, the complete object.

**Trade-offs and when not to use it:** Hashing consumes CPU and requires streaming the bytes, but integrity-sensitive files justify it. A plain checksum detects accidental corruption; it does not prove who produced the data. Use an authenticated signature or message authentication code when attackers may alter both content and checksum.

**Production checks:** Choose and version the algorithm, validate multipart semantics, store checksum metadata durably, verify restores and cross-region copies, quarantine mismatches, alert on integrity failures, and never log sensitive file contents.

**Try it:** Flip one byte after upload in a test double and prove that download verification rejects the object even though its length is unchanged.

Reference: Amazon S3’s official guide explains [upload, download, multipart, and stored-object checksum validation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html).

---

## TECH-M7 — Search Index Synchronization, Ranking, and Evaluation

**Question:** What turns a text index into a reliable search product rather than a faster `LIKE '%term%'` query?

**Answer:** A reliable search system has a durable change pipeline, idempotent versioned indexing, query understanding, candidate retrieval, ranking, measurable relevance, and a rebuild strategy that does not interrupt serving.

**What problem does it solve?** It keeps search results fresh and explainable while letting ranking improve without corrupting the source-of-truth database.

**Before this concept:** The request wrote the database and search engine independently, then ranked only by exact text occurrence.

❌ **Wrong/before example:**

```csharp
await db.Products.AddAsync(product, ct);
await db.SaveChangesAsync(ct);
await search.Index(product, ct); // failure leaves the product permanently missing
```

✅ **After/correct example:**

```text
database transaction:
    save Product(version=41)
    save ProductChanged(productId, version=41) to outbox

indexer:
    read outbox/change stream
    transform source fields into index document
    upsert only when incoming version >= indexed version
    checkpoint after the index acknowledges the update

query path:
    normalize/tokenize query
    retrieve candidates from posting lists
    rank with BM25 plus bounded product signals
    apply authorization/availability filters
    return result and record anonymous evaluation signals

rebuild:
    write a new versioned index
    replay changes after the snapshot
    compare document counts and sampled results
    atomically switch the read alias
```

**How it works now:** The database remains authoritative, the outbox or change stream prevents lost updates, document versions make retries and reordering safe, and an alias swap makes rebuilds reversible. Offline judgments measure precision, recall, mean reciprocal rank, or normalized discounted cumulative gain; online tests measure user outcomes and guardrails.

**Trade-offs and when not to use it:** Search introduces eventual consistency, another data model, relevance tuning, storage, and operational work. Database full-text search may be enough for small datasets and simple requirements. Business signals can improve ranking but may create feedback loops or unfair exposure.

**Production checks:** Monitor indexing lag, rejected documents, version conflicts, zero-result rate, p95/p99 query latency, relevance metrics by query class, authorization filtering, schema compatibility, rebuild duration, and rollback readiness.

**Try it:** Delete the search index and rebuild it while writes continue. Prove no committed product is missing after the alias switch and compare ten judged queries before and after.

Reference: Apache Lucene documents [BM25 scoring](https://lucene.apache.org/core/7_3_0/core/org/apache/lucene/search/similarities/BM25Similarity.html) and [near-real-time index visibility](https://cwiki.apache.org/confluence/spaces/LUCENEJAVA/pages/120735094/NearRealtimeSearch).

---

## TECH-M8 — Geospatial Candidate Indexing and Exact Containment

**Question:** Why should nearby search or geofencing usually use both a spatial index and an exact geometry check?

**Answer:** A grid or tree index quickly returns a small candidate set, while an exact distance or point-in-polygon operation removes false positives and handles the real product boundary.

**What problem does it solve?** It avoids scanning every location while preventing coarse cells or latitude/longitude boxes from becoming the final correctness rule.

**Before this concept:** The application compared latitude and longitude degrees as if they represented a fixed distance everywhere.

❌ **Wrong/before example:**

```sql
SELECT * FROM drivers
WHERE latitude  BETWEEN @lat - 0.1 AND @lat + 0.1
  AND longitude BETWEEN @lng - 0.1 AND @lng + 0.1;
-- Returns a rectangle, changes physical width by latitude, and has no exact radius check.
```

✅ **After/correct example:**

```text
write path:
    validate coordinate order and coordinate reference system
    compute an H3/S2/geohash cell at the chosen resolution
    store the original point plus the cell identifier

nearby query:
    compute cells covering the search radius
    fetch candidates whose cell is in that small set
    calculate exact spherical distance
    keep distance <= requested radius
    sort by exact distance

geofence query:
    use cells covering the polygon to find candidates
    apply exact ST_Covers/ST_Contains using the original geometry
```

```sql
SELECT driver_id,
       ST_Distance(location, @origin) AS distance_meters
FROM drivers
WHERE h3_cell = ANY(@candidate_cells)
  AND ST_DWithin(location, @origin, @radius_meters)
ORDER BY distance_meters
LIMIT 50;
```

In this example, `location` and `@origin` use the PostGIS `geography` type with SRID 4326, so the distance argument and result are in meters.

**How it works now:** The coarse index reduces I/O, and the exact predicate owns correctness. Resolution is a tunable candidate-size trade-off rather than a hidden product rule. Original coordinates remain available for exact calculations and future reindexing.

**Trade-offs and when not to use it:** Very fine cells enlarge index and covering sets; coarse cells return more false positives. Cell membership based on a centroid can miss or include border cases depending on the covering algorithm, so safety-critical geofences require exact geometry and explicit boundary semantics.

**Production checks:** Standardize longitude/latitude order and coordinate reference system, handle the antimeridian and poles, define `contains` versus `covers` at boundaries, validate polygons, protect location privacy, and test points just inside/outside edges and holes.

**Try it:** Test a point on a polygon edge, one inside a hole, and two locations across the antimeridian. State the expected result before running the query.

Reference: H3’s official documentation covers [point-to-cell indexing](https://h3geo.org/docs/quickstart/) and [polygon-to-cell region functions](https://h3geo.org/docs/api/regions/).
