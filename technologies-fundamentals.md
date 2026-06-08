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

---

## API Design & Patterns {#api-design}

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

## Caching Strategies {#caching}

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

## Load Balancing {#load-balancing}

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

## Database Patterns {#databases}

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

## Message Queues & Event Systems {#messaging}

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

## Search & Indexing {#search}

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

## Consistency Patterns {#consistency}

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

## Distributed Systems Concepts {#distributed}

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

## Network & Protocol Concepts {#network}

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

## Resilience Patterns {#resilience}

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
