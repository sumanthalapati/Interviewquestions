# Companies System Design - Real-World Case Studies

Quick reference guide for how major tech companies scaled their systems. Each section includes definitions, Q&A, architecture patterns, pros/cons, and usage guidelines.

---

## Table of Contents
1. [Amazon (AWS S3, Lambda, DynamoDB)](#amazon)
2. [Apple (AirTags, Apple Pay)](#apple)
3. [Meta/Facebook (Live Video, Cache Consistency)](#meta)
4. [Netflix (Microservices, Chaos Engineering)](#netflix)
5. [Google (Search, Cloud, Spanner)](#google)
6. [LinkedIn (Scalability, Protocol Buffers)](#linkedin)
7. [Uber (ETA, Nearby Drivers, Payments)](#uber)
8. [Twitter/X (Timeline, Real-time)](#twitter)
9. [YouTube (Scale, MySQL)](#youtube)
10. [Disney+ Hotstar (Live Events, Emojis)](#disney)

---

## Amazon {#amazon}

### Definition
Amazon Web Services (AWS) pioneer distributed systems at scale. Key services: S3 (object storage), Lambda (serverless), DynamoDB (NoSQL), EC2 (compute).

### Q&A

**Q: How does Amazon S3 achieve 99.999999999% durability?**
- A: Uses replication across multiple availability zones, checksums, redundant storage, and continuous verification. Data stored on multiple disks and servers geographically.

**Q: How does Lambda scale without managing servers?**
- A: Auto-scales based on invocations. Containers pre-warmed, event-driven, stateless execution. Charged per execution millisecond.

**Q: How does DynamoDB maintain consistency at scale?**
- A: Distributed hash tables, eventual consistency by default, strong consistency optional. Replicates across zones for durability.

### Why This Approach
- **S3**: Durability through redundancy beats encryption alone. Geographic distribution survives datacenter failures.
- **Lambda**: Serverless removes operational burden, reduces costs for variable workloads.
- **DynamoDB**: Horizontal scaling via sharding beats vertical scaling. Eventual consistency trades freshness for availability (CAP theorem).

### Pros & Cons

**S3 Pros**: 11 nines durability, infinitely scalable, cheap per GB, versioning support.
**S3 Cons**: Higher latency than local disks, eventual consistency edge cases, limited query capabilities.

**Lambda Pros**: Auto-scale, pay-per-use, no server ops, fast deployment.
**Lambda Cons**: Cold starts (100-300ms), timeout limits (15 min), harder debugging, vendor lock-in.

**DynamoDB Pros**: Infinite scale, single-digit ms latency, built-in replication.
**DynamoDB Cons**: Expensive at large scale, schema inflexible, eventual consistency by default, limited querying.

### Right vs Wrong Usage

**✅ Right**: Use S3 for immutable blobs (images, videos, archives). Lambda for event processing, webhooks. DynamoDB for sessions, real-time counts.

**❌ Wrong**: Don't use S3 for databases (use RDS). Don't use Lambda for heavy compute (>15 min). Don't use DynamoDB for complex transactions.

**Alternative**: S3 → RDS if relational. Lambda → EC2 if long-running. DynamoDB → PostgreSQL if ACID needed.

---

## Apple {#apple}

### Definition
Apple's ecosystem balances privacy, security, and real-time coordination across billions of devices. Key: AirTags (tracking), Apple Pay (payments).

### Q&A

**Q: How do AirTags work without GPS?**
- A: Bluetooth LE broadcasts UUID. Other Apple devices relay location to iCloud. Uses Bluetooth direction (UWB chip) for final positioning. Works even if AirTag offline.

**Q: How does Apple Pay handle 41M transactions/day securely?**
- A: Tokenization (card number replaced with token). Secure enclave on device signs. Multi-factor (Face ID / Touch ID). Rate limiting, fraud detection, encryption.

### Why This Approach
- **AirTags**: Crowdsourced location = no power drain. Privacy: location encrypted, Apple can't see it.
- **Apple Pay**: Tokenization prevents card theft. On-device signing prevents interception.

### Pros & Cons

**AirTags Pros**: Works worldwide without subscription, privacy-first, low battery drain, UWB accurate to 6 inches.
**AirTags Cons**: Requires Apple ecosystem, limited to ~100m range, can be used for stalking (Apple added alerts), precision only with U1+ chips.

**Apple Pay Pros**: Faster than cards (2-3 sec), fraud protection, privacy, one-tap payments.
**Apple Pay Cons**: Requires Apple device, retailer support, regional limitations, NFC required.

### Right vs Wrong Usage

**✅ Right**: AirTags for personal items (keys, wallets). Apple Pay for POS, transit.

**❌ Wrong**: Don't rely on AirTags for time-critical tracking. Don't assume Apple Pay works everywhere.

**Alternative**: GPS trackers (Tile) for non-Apple. Cards/contactless for universal acceptance.

---

## Meta/Facebook {#meta}

### Definition
Meta scales live features to billions. Key: Live Video (1B+ users), Cache Consistency (99.99999999%), CDN delivery.

### Q&A

**Q: How does Facebook deliver live video to 1 billion viewers with <2 second latency?**
- A: Edge CDNs near users, ABR (adaptive bitrate), P2P assist (users relay), HTTP-based DASH protocol. Multi-bitrate encoding. Regions cache hot videos.

**Q: How does Meta achieve 99.99999999% cache consistency?**
- A: Invalidation cascade (L1→L2→L3), consistency hashing, leases (temporary TTL), read-through caches. Checksum verification.

**Q: How does Hotstar deliver 5 billion emojis real-time?**
- A: WebSockets + sharding by user. Message batching (100ms), delta compression. Emoji counts cached, updated via pubsub.

### Why This Approach
- **CDN**: Network latency dominates. Local replication beats optimization.
- **Cache consistency**: Perfect consistency too expensive. Leases (soft TTL) strike balance.
- **Pubsub**: Broadcasting faster than polling. Sharding prevents bottlenecks.

### Pros & Cons

**Live Video Pros**: Low latency, adaptive quality, scales to billions, fault-tolerant.
**Live Video Cons**: Complex infra, requires edge presence, HLS/DASH overhead, buffering during spikes.

**Cache Consistency Pros**: Near-real-time without full refresh, write-through cheaper than full rebuild.
**Cache Consistency Cons**: Eventual consistency creates stale reads, invalidation cascade can fail.

### Right vs Wrong Usage

**✅ Right**: Use CDN for static content. Cache for hot reads (feeds, profiles). Pubsub for live updates.

**❌ Wrong**: Don't cache user-specific data at edge (privacy). Don't rely on cache for critical consistency (banking).

**Alternative**: Database → Faster DB (Redis). Cache → Write-through DB. Pubsub → HTTP polling if latency tolerant.

---

## Netflix {#netflix}

### Definition
Netflix scaled to 200M+ users via microservices, chaos engineering, and resilience patterns. Broke monolith into service-oriented architecture.

### Q&A

**Q: Why did Netflix move from monolith to microservices?**
- A: Monolith bottleneck: one deploy breaks everything. Microservices = independent scale, deploy, teams. Service Oriented Architecture (SOA).

**Q: How does Netflix survive service failures (chaos engineering)?**
- A: Intentionally fails services in prod (Chaos Monkey). Tests recovery. Forces redundancy, timeouts, circuit breakers.

**Q: How does Netflix handle encoder scaling?**
- A: Asynchronous encoder jobs via SQS-like queues. Encodes multiple bitrates in parallel. Scales to encode 100+ videos/day.

### Why This Approach
- **Microservices**: Loose coupling = faster innovation. Team autonomy = velocity.
- **Chaos**: Bugs found in chaos > bugs found in prod outage. Resilience is feature, not afterthought.

### Pros & Cons

**Microservices Pros**: Independent scale, fast deploys, team ownership, technology flexibility.
**Microservices Cons**: Distributed systems complexity (latency, consistency), operational overhead, network calls > local calls.

**Chaos Engineering Pros**: Finds bugs early, builds resilience culture, prevents catastrophic failures.
**Chaos Engineering Cons**: Scary to run in prod, requires mature monitoring, can cause real outages if badly tuned.

### Right vs Wrong Usage

**✅ Right**: Microservices for 50+ engineers, multiple teams. Chaos for services with SLAs. Circuit breakers for all external calls.

**❌ Wrong**: Microservices for <5 engineers (overhead > benefit). Chaos without alerting (can cascade). No timeouts (hanging requests).

**Alternative**: Monolith → Move to microservices at 30+ engineers. Chaos → Synthetic tests if prod chaos too risky. Queues → Database if tight consistency needed.

---

## Google {#google}

### Definition
Google scales search, cloud, and databases to trillions of queries. Key: Spanner (ACID + distributed), Search (crawl + index + rank), Colossus (FS).

### Q&A

**Q: How does Google Search rank pages in milliseconds?**
- A: Pre-indexed on billions of docs. PageRank pre-computed. Sharded inverted index. Query hits relevant shards only. Results merged ranked.

**Q: How does Spanner maintain ACID across continents?**
- A: Paxos consensus, atomic clocks (True Time API), synchronous replication. Waits for majority quorum before commit.

**Q: How does Google Cloud scale to 100M+ users?**
- A: Multi-region deployment. Global load balancer. Sharded data per region. Consistent hashing. Circuit breakers for cascading failures.

### Why This Approach
- **Search**: Pre-computation amortizes cost. Sharding parallelizes queries.
- **Spanner**: Atomic clocks eliminate uncertainty. Synchronous replication beats eventual consistency for banking.
- **Cloud**: Multi-region = resilience. Sharding = unlimited scale.

### Pros & Cons

**Search Pros**: Sub-second results on trillions of docs, filters, spelling correction, relevance ranking.
**Search Cons**: Massive infra, constant crawling, index updates delayed (hours).

**Spanner Pros**: ACID + distributed (best of both), strong consistency, high availability, planet-scale.
**Spanner Cons**: Expensive, 10ms+ latency due to replication, not suitable for small-scale.

### Right vs Wrong Usage

**✅ Right**: Search for public web indexing. Spanner for financial transactions. Global LB for worldwide users.

**❌ Wrong**: Don't use Spanner for caches (overkill cost). Don't index real-time data (stale). Don't use single region for critical services.

**Alternative**: Search → Elasticsearch for smaller scale. Spanner → PostgreSQL for single-region. Multi-region → Active-passive failover if cost matters.

---

## LinkedIn {#linkedin}

### Definition
LinkedIn scales to 930M users through MySQL sharding, protocol buffers, and cache architecture. Optimized for social network queries.

### Q&A

**Q: How does LinkedIn shard MySQL to handle 930M users?**
- A: Shard by user ID (consistent hash). 1000s of shards across clusters. Each shard ~1M users. Query hits one shard, avoids full table scan.

**Q: How did LinkedIn reduce latency 60% with Protocol Buffers?**
- A: Protocol Buffers (serialization format) 3-10x smaller than JSON. Binary format = faster parsing. Reduced bandwidth, CPU, latency.

**Q: How does LinkedIn generate feeds at scale?**
- A: Fan-out on write: for each follower, append update to their feed cache. On read, return cached feed. Compromise: write-heavy for followers, fast reads.

### Why This Approach
- **Sharding**: Scales horizontally. Hot shards → split further. Consistent hash minimizes reshuffling.
- **Protobuf**: Smaller payload = less latency. Binary = faster decode than JSON parsing.
- **Feed**: Pre-computed feeds = instant delivery. Cache hit rate >95%.

### Pros & Cons

**MySQL Sharding Pros**: Unlimited horizontal scale, strong consistency, SQL support.
**MySQL Sharding Cons**: Operational complexity (shard management), cross-shard joins slow, resharding pain.

**Protocol Buffers Pros**: 3-10x compression vs JSON, backward compatible, schema evolution.
**Protocol Buffers Cons**: Not human-readable, steeper learning curve, fewer lang libraries than JSON.

**Feed Fans-out-on-write Pros**: Fast reads (O(1) lookup), instant updates, cache-friendly.
**Feed Fans-out-on-write Cons**: Expensive writes (followers * cost), storage bloat for high-follower users.

### Right vs Wrong Usage

**✅ Right**: Shard databases at 10B+ rows. Protobuf for high-volume APIs. Fan-out for <100k follower users.

**❌ Wrong**: Don't shard prematurely (overhead > benefit). Don't use Protobuf for external APIs (privacy concerns). Don't fan-out for influencers (100M followers).

**Alternative**: MySQL → NoSQL if eventual consistency OK. Protobuf → JSON if human-readable needed. Fan-out → Fan-in on read for high-followers.

---

## Uber {#uber}

### Definition
Uber coordinates 100M+ rides via ETA calculation, driver matching, and payment processing at massive scale. Optimized for real-time geo operations.

### Q&A

**Q: How does Uber compute ETA for 500K requests/second?**
- A: Pre-cached road graphs (maps). Dijkstra/A* on sharded map tiles. Historical traffic patterns (ML). Results cached, updated every 30 sec.

**Q: How does Uber find nearby drivers at 1M requests/second?**
- A: Geo-sharding (QuadTree, Geohash). Each shard holds drivers in region. Request hits shard, returns nearby drivers sorted by distance + rating.

**Q: How does Uber payment system handle 30M transactions/day?**
- A: Idempotent APIs (payment ID dedupes). Async settlement (reduces latency). Rate limiting. Fraud detection (ML). Eventual consistency (settle next day).

### Why This Approach
- **ETA**: Pre-cached graphs beat real-time compute. Historical data beats no context.
- **Matching**: Geo-sharding parallelizes. Sorting by distance + rating = UX quality.
- **Payments**: Idempotent APIs prevent double-charge. Async beats sync (faster, cheaper).

### Pros & Cons

**ETA Pros**: Sub-second response, 85%+ accuracy, scales to millions, accounts for traffic.
**ETA Cons**: Updates delayed (30s), doesn't predict congestion ahead, sensitive to data quality.

**Nearby Drivers Pros**: O(log n) lookup, handles millions, scales geographically.
**Nearby Drivers Cons**: Stale location data (driver moves faster than update), expensive to store/query millions of geo points.

**Idempotent Payments Pros**: No double-charge, networks can retry, simpler recovery.
**Idempotent Payments Cons**: Client must track request IDs, storage overhead, reconciliation complexity.

### Right vs Wrong Usage

**✅ Right**: Cache ETA results. Geo-shard for location queries. Idempotent APIs for payments.

**❌ Wrong**: Don't compute ETA in real-time (latency). Don't trust single driver location (can be stale). Don't use synchronous payments (bottleneck).

**Alternative**: ETA → Static maps if accuracy OK. Geo-sharding → Global hash if geo-specificity not critical. Idempotent → Transactions if strong consistency critical.

---

## Twitter/X {#twitter}

### Definition
Twitter scales to 500M+ users tweeting, retweeting, liking in real-time. Key: Timeline generation, distributed systems reliability.

### Q&A

**Q: How does Twitter generate timelines for 500M users?**
- A: Fan-out on write. For each tweet, append to followers' timelines (cache). On read, return cached timeline. Updates within 100ms.

**Q: How does Twitter handle the Thundering Herd problem?**
- A: Cache stampede when cache expires. Solution: Use probabilistic early expiration (XFetch), lock mechanism (single thread refreshes), or secondary cache.

**Q: How does Twitter scale to 500 tweets/second (average)?**
- A: Sharding by tweet ID and user ID. Multiple datacenters. Async replication. Read-heavy (1000:1), so cache layers critical.

### Why This Approach
- **Timeline**: Pre-computed beats real-time joins. Cache = speed.
- **Stampede prevention**: Locks cheap vs thundering herd outage.
- **Sharding**: Parallelizes writes and reads.

### Pros & Cons

**Timeline Fan-out Pros**: Instant reads, personalized, cache-friendly.
**Timeline Fan-out Cons**: Write amplification (followers * cost), storage per follower, hard to update (edits require cascade).

**Cache Stampede Prevention Pros**: Prevents outages, fair distribution.
**Cache Stampede Prevention Cons**: Complex logic, requires careful tuning, may delay updates.

### Right vs Wrong Usage

**✅ Right**: Fan-out for users with <100k followers. Cache stampede prevention for popular items. Sharding for high-volume writes.

**❌ Wrong**: Don't fan-out for celebrities (storage bloat). Don't ignore cache stampede (learn hard way). Don't shard without consistent hash.

**Alternative**: Timeline → Pull from DB if write volume low. Stampede → Accept brief slowdown if rare. Sharding → Vertical scale if small data.

---

## YouTube {#youtube}

### Definition
YouTube supports 2.49B users watching 1B+ hours/day. Key: MySQL scale (Vitess), distributed encoding, CDN delivery.

### Q&A

**Q: How does YouTube support 2.49B users with MySQL?**
- A: Vitess middleware (transparent sharding). Resharding without downtime. Thousands of MySQL instances. Hot shards split automatically.

**Q: How does YouTube encode videos at scale?**
- A: Asynchronous job queue. Multiple encodes (360p, 720p, 1080p, 4K) in parallel. Sharded across 1000s of machines. Codec selection based on device.

**Q: How does YouTube deliver videos globally?**
- A: Geographically distributed CDN (GCP regions). Caches videos at edges. Smart routing to nearest datacenter. Fallback to origin.

### Why This Approach
- **Vitess**: Transparent sharding = scale MySQL. Resharding = grow without downtime.
- **Async encoding**: Parallelism = throughput. Multiple bitrates = adaptive streaming.
- **CDN**: Edge caching = low latency. Smart routing = resilience.

### Pros & Cons

**Vitess Pros**: MySQL scale without app changes, resharding transparent, strong consistency.
**Vitess Cons**: Operational complexity, distributed transaction overhead, learning curve.

**Async Encoding Pros**: Parallelism, flexible bitrates, decouples upload from delivery.
**Async Encoding Cons**: Delayed availability (hours), storage overhead (multiple bitrates).

**CDN Pros**: Global low latency, reduces origin load, handles spikes.
**CDN Cons**: Cache invalidation, stale content possible, cost at scale.

### Right vs Wrong Usage

**✅ Right**: Vitess for MySQL at 10B+ rows. Async encoding for video platform. CDN for global content.

**❌ Wrong**: Don't use Vitess for small databases (overhead). Don't encode synchronously (blocks upload). Don't skip CDN for global service.

**Alternative**: Vitess → NoSQL if eventual consistency OK. Async → Sync for images (fast encode). CDN → Origin only if users local.

---

## Disney+ Hotstar {#disney}

### Definition
Disney+ Hotstar handled 25M concurrent users during cricket matches. Key: Real-time events, massive scale, emoji streaming.

### Q&A

**Q: How did Hotstar scale to 25M concurrent users?**
- A: Sharded by region. Each shard handles 5M users. Independent scaling per region. Pre-warming before big events. Rate limiting for traffic.

**Q: How did Hotstar deliver 5B emojis real-time?**
- A: Emoji counts cached. Updates via WebSocket sharded by room. Batches updates (100ms). Compresses deltas. Falls back to HTTP if WebSocket fails.

**Q: How did Hotstar handle 1.3M requests/second during peak?**
- A: Horizontal scaling (add instances), request sharding, load shedding (reject extra traffic), graceful degradation (reduce features).

### Why This Approach
- **Sharding**: Limits failure domain. 1 shard failure = 5M impact, not 25M.
- **WebSocket**: Low latency updates. Sharding prevents bottleneck.
- **Load shedding**: Better to serve 100% of users at reduced quality than crash everyone.

### Pros & Cons

**Regional Sharding Pros**: Resilience, independent scale, reduced latency.
**Regional Sharding Cons**: Cross-region queries complex, inconsistency possible, operational overhead.

**WebSocket Emoji Pros**: Real-time, low latency, scales to millions.
**WebSocket Emoji Cons**: Stateful connections, harder to scale horizontally, mobile battery drain.

**Load Shedding Pros**: Graceful degradation, prevents cascade failures.
**Load Shedding Cons**: Some users denied, UX degradation, complex to implement fair prioritization.

### Right vs Wrong Usage

**✅ Right**: Shard large live events by region. Use WebSocket for real-time features. Implement load shedding before you need it.

**❌ Wrong**: Don't assume single region scales to 25M (it doesn't). Don't ignore battery impact of WebSocket. Don't implement load shedding reactively.

**Alternative**: Regional → Global LB if simpler. WebSocket → HTTP polling if battery critical. Load shedding → Over-provision if budget allows.

---

## Summary Table

| Company | Problem | Solution | Trade-off |
|---------|---------|----------|-----------|
| Amazon | Durability | Replication across zones | Latency |
| Apple | Privacy | On-device signing | Dependency on Apple ecosystem |
| Meta | Live at scale | CDN + Pubsub | Eventual consistency |
| Netflix | Monolith bottleneck | Microservices | Distributed systems complexity |
| Google | Global scale | Sharding + Spanner | High cost, complexity |
| LinkedIn | 930M users | MySQL sharding | Operational overhead |
| Uber | Real-time geo | Geo-sharding + caching | Stale data possible |
| Twitter | Timeline speed | Fan-out on write | Write amplification |
| YouTube | Scale with MySQL | Vitess middleware | Learning curve |
| Hotstar | 25M concurrent | Regional sharding | Cross-region complexity |

---

**Key Takeaway**: Every company trades one constraint for another. Perfect consistency, unlimited scale, and zero latency impossible. Choose your tradeoff wisely.
