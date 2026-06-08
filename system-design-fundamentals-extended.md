# System Design Fundamentals - Extended Guide

Comprehensive reference for fundamental concepts, calculations, and deep dives into core system design principles.

---

## Table of Contents
1. [Back of the Envelope Calculations](#envelope)
2. [Network Troubleshooting](#network-troubleshooting)
3. [System Design Interview Cheat Sheet](#cheatsheet)
4. [The Computer Science Stack Explained](#cs-stack)
5. [Storage & I/O Performance](#storage)
6. [Concurrency vs Parallelism](#concurrency)
7. [System Design Metrics & SLAs](#metrics)
8. [Common Estimation Problems](#estimation)
9. [Capacity Planning](#capacity)
10. [Performance Optimization Checklist](#performance)

---

## Back of the Envelope Calculations {#envelope}

### Core Numbers (Memorize These)

**Latencies (1 CPU cycle = ~0.3 nanoseconds)**
```
L1 cache reference:           0.5 ns
L2 cache reference:           7 ns
Main memory reference:        100 ns
SSD random read:             150 µs (microseconds)
Disk random read:             10 ms (milliseconds)
Network packet (local):        1 µs
Network packet (internet):    100 ms
```

**Practical Rule of Thumb**
```
1 microsecond = 1000 nanoseconds
1 millisecond = 1000 microseconds = 1 million nanoseconds
1 second = 1000 milliseconds
```

**Powers of 2 (Critical for Storage)**
```
2^10 = 1 KB (Kilobyte)
2^20 = 1 MB (Megabyte)
2^30 = 1 GB (Gigabyte)
2^40 = 1 TB (Terabyte)
2^50 = 1 PB (Petabyte)
2^60 = 1 EB (Exabyte)
```

### Practical Calculations

**Example 1: YouTube Upload at Scale**
```
Problem: Design system for 1B users, 500 hours of video uploaded/day.
How much storage needed per year?

500 hours/day × 365 days = 182,500 hours/year

Average bitrate for HD video: 5 Mbps
1 hour = 3600 seconds
1 hour video = 5 Mbps × 3600 sec = 18,000 Mb = 2.25 GB

182,500 hours × 2.25 GB/hour = 410,625 TB ≈ 400 PB/year

Reality: YouTube uses H.265 (compression), multiple quality levels
Practical: Store 2-3 copies (replication) = 1.2 EB/year storage cost
```

**Example 2: Twitter Tweet Rate**
```
Problem: 500M users tweet on average once per day (not all active daily).
DAU = 300M (Daily Active Users)
What's the QPS (Queries Per Second)?

300M tweets/day ÷ 86,400 seconds = 3,472 tweets/second

Traffic isn't uniform. Peak during business hours = 5-10x baseline
Peak: 35,000 tweets/second

Peak reads (timeline): 100x writes = 3.5M reads/second
Assume 80% cache hit rate → 700K DB hits/second
```

**Example 3: Database Size Estimation**
```
Problem: Chat app with 1M users, average 100 messages per user per day.
Store 1 year of messages.

1M users × 100 messages/day × 365 days = 36.5B messages/year

Average message size: 200 bytes (text) + 50 bytes (metadata) = 250 bytes

36.5B messages × 250 bytes = 9.125 TB ≈ 10 TB/year

Index overhead: ~30% = 3 TB
Total: 13 TB/year

After 5 years: 65 TB (fits on single machine, but replicate for resilience)
```

**Example 4: Bandwidth Calculation**
```
Problem: Photo sharing app. 1M DAU, each user uploads 5 photos/day.
Average photo size: 5 MB.
Bandwidth needed?

1M × 5 photos × 5 MB = 25 PB/day = 25 × 10^15 bytes/day

Per second: 25 × 10^15 bytes ÷ 86,400 sec = 290 TB/second = 2.3 Pbps

Wow! Need massive infrastructure.
Reality: Use CDN, compression (5 MB → 1 MB after optimization) = 460 Tbps

Gigabit connection = 125 MB/second = 0.000125 Tbps
So 460 Tbps ÷ 0.000125 = 3.68M Gbps lines needed
1 Gbps link costs ~$1000/month, so 3.68B$/month infrastructure cost
(Reality: Negotiated rates, much lower)
```

### Estimation Framework (LASER Method)

**L - Look at requirements** (scale, features, constraints)
**A - Ask clarifying questions** (growth rate, retention, regions)
**S - Sanity check** (does number make sense?)
**E - Estimate** (bottom-up or top-down)
**R - Record** (write down assumptions)

### Example LASER

```
Design Instagram at 1B users

L - Requirements: Photos, feed, likes, follows
A - Questions:
  - Active users daily? 300M (30% DAU)
  - Average posts per user? 1/week = 50M posts/week = 7M/day
  - Ratio reads:writes? Photos viewed 100x more than posted
  - Storage needed? Posts + photos + metadata
  - Peak traffic? 5-10x baseline during peak hours

S - Sanity check:
  7M posts/day = 81 posts/second (seems reasonable)
  100x reads = 8,100 reads/second (Instagram easily handles)
  Photo size 2 MB × 7M posts = 14 TB/day (manageable)

E - Estimate:
  - Database size: 7M posts/day × 365 days × 2 MB = 5 PB
  - With replication: 15 PB
  - Bandwidth: 8,100 reads/sec × 0.5 MB per read = 4 Gbps (reasonable)

R - Record assumptions:
  - 300M DAU
  - 50 posts/second peak (81 average)
  - 2 MB avg photo
```

---

## Network Troubleshooting {#network-troubleshooting}

### What Happens When You Type a URL

```
1. Browser checks DNS cache (often 300 sec TTL)
2. If not cached → queries DNS resolver (usually ISP)
3. DNS resolver queries root nameserver → TLD (.com) → authoritative NS
4. Gets IP address (e.g., 1.2.3.4)
5. Browser initiates TCP connection (3-way handshake)
   - SYN → Server
   - SYN-ACK ← Server
   - ACK → Server
   (100-300ms latency typical)
6. TLS handshake (if HTTPS)
   - ClientHello, ServerHello, Certificate exchange
   - (additional 100-200ms)
7. HTTP request sent
8. Server responds
9. Browser renders HTML (if plain), or downloads resources (CSS, JS, images)
10. Page interactive (or waits for JavaScript)
```

### DNS Deep Dive

**How DNS Works**
```
User query: "What IP is google.com?"

Root Nameserver (13 servers worldwide)
  ↓ "Ask the .com TLD server"
  
.com TLD Nameserver
  ↓ "Ask google.com's authoritative nameserver"
  
google.com Authoritative Nameserver
  ↓ "google.com is 142.250.185.46"

Returns to recursive resolver (ISP)
  → Cached for TTL (usually 300 seconds)
  → Returns to client
```

**Why DNS Cache Stale?**
- Client cache (browser, OS) = 300 sec TTL
- ISP recursive resolver = 300+ sec TTL
- Total = can be stale for 10+ minutes
- If server dies, traffic still sent to dead IP for minutes

**DNS Load Balancing Fails**
```
Problem: Simple DNS load balancing
DNS returns multiple IPs (round-robin)

Client 1 → IP 1 (server healthy)
Client 2 → IP 2 (server down!)

But client 2 cached DNS result.
If server 2 dies, client 2 sends traffic to dead IP
until DNS cache expires (5+ minutes).

Solution: Application-level load balancer (NGINX, HAProxy)
or cloud LB (AWS ELB, Azure LB)
```

### Network Performance Issues

**High Latency**
```
Diagnosis:
1. Is it network? (ping remote)
2. Is it application? (check logs, metrics)
3. Is it database? (check slow query log)
4. Is it third-party API? (check API latency)

Solutions:
- Caching (reduce queries)
- CDN (serve from edge)
- Connection pooling (reuse TCP connections)
- Compression (gzip responses)
- HTTP/2 or HTTP/3 (multiplexing)
- Parallel requests (if independent)
```

**Packet Loss**
```
Symptoms: Random timeouts, slow downloads, connection drops
Causes:
- Congested network
- Faulty hardware (bad NIC, switch)
- WiFi interference
- ISP issues

Diagnosis:
- ping -c 100 host (check % packet loss)
- traceroute host (see which hop loses packets)
- mtr host (continuous monitoring)

Solutions:
- Retry with exponential backoff
- Use TCP (reliable) not UDP
- Reduce packet size
- Add redundant paths (multi-homing)
```

**Bandwidth Bottleneck**
```
Symptoms: Throughput < available bandwidth
Causes:
- Large payloads
- Many small requests (overhead)
- Inefficient protocol

Diagnosis:
- iperf (measure actual bandwidth)
- Network monitor (see total bytes/sec)
- Wireshark (packet-level analysis)

Solutions:
- Compression (gzip: 70% reduction typical)
- Smaller images (responsive, thumbnails)
- Batch requests (combine into single call)
- HTTP/2 (multiplexing)
- Protobuf (smaller than JSON)
```

### Troubleshooting Framework

**Can't access website?**
```
1. Check DNS (nslookup google.com)
2. Check IP connectivity (ping 8.8.8.8)
3. Check firewall (telnet google.com 443)
4. Check service (curl https://google.com)
5. Check certificate (openssl s_client -connect google.com:443)
```

**Slow website?**
```
1. Client-side (DevTools → Network tab)
   - CSS, JS, images large?
   - Many requests?
   - Waterfall chart (what's blocking what?)
2. Network (traceroute, ping)
   - High latency?
   - Packet loss?
3. Server-side (server logs, metrics)
   - CPU high?
   - Memory full?
   - Slow queries?
4. Database
   - Slow queries (EXPLAIN ANALYZE)
   - Missing indexes?
   - Too many connections?
```

---

## System Design Interview Cheat Sheet {#cheatsheet}

### Architecture Patterns Quick Reference

```
CRUD Application (Pastebin, URL Shortener)
[Client] → [API] → [Database] → [Cache]

Social Network (Facebook, Twitter)
[Client] → [API] → [Feed Service] → [Cache]
                 → [Graph DB] (relationships)

Real-time (Chat, Live Comments)
[Client] ←→ [WebSocket Gateway] ←→ [Message Queue]
                                  ←→ [Broadcast Service]

Video Streaming (YouTube, Netflix)
[Client] → [API] → [Metadata Service]
                 → [CDN] ← [Video Storage]
                 → [Recommendation Engine]

E-commerce (Amazon, eBay)
[Client] → [API Gateway] → [Product Service]
                        → [Cart Service]
                        → [Order Service]
                        → [Payment Service]
                        → [Notification Service]
```

### Quick Database Selection

| Use Case | Database | Why |
|----------|----------|-----|
| Relational (user, orders) | PostgreSQL, MySQL | ACID, JOINs |
| Key-value (sessions, cache) | Redis, Memcached | Fast, simple |
| Documents (user profiles) | MongoDB, Firebase | Flexible schema |
| Time-series (metrics) | InfluxDB, Prometheus | Compression, downsampling |
| Full-text search | Elasticsearch, Solr | Inverted index |
| Graph (relationships) | Neo4j | Fast relationship queries |
| Geospatial | PostGIS, MongoDB Geo | Geo-indexed queries |
| Vector (embeddings) | Pinecone, Weaviate | Semantic search |

### Latency Budget (Target: 100ms end-to-end)

```
Client (browser) rendering: 10ms
Network roundtrip: 30-50ms
API server processing: 20-30ms
Database query: 10-20ms
Cache lookup: 1-5ms

Total: ~80-120ms (acceptable)

If slow query (1s), entire chain > 1s (unacceptable)
```

### QPS to Instances Conversion

```
1 instance ≈ 1,000 QPS (average)
Peak = 5-10x average

If 100,000 QPS peak:
100,000 ÷ 1,000 = 100 instances minimum
Add 50% buffer = 150 instances
```

### Storage Calculation Quick Formula

```
Storage = (DAU) × (avg operations/user) × (data/operation) × (1 year)

Example: Chat app
Storage = 100M DAU × 100 messages/day × 250 bytes/message × 365
        = 100M × 100 × 250 × 365 bytes
        = 912.5 PB (huge! this is why deletion/archival needed)

More realistic: Keep only 90 days of messages
Storage = 100M × 100 × 250 × 90 = 225 PB (still large, shard across clusters)
```

---

## The Computer Science Stack Explained {#cs-stack}

### The Seven Layers (Bottom to Top)

**1. Hardware (Physical)**
```
CPUs, Memory (RAM), Disks, Network cards
- Latency: CPU registers (nanoseconds) → RAM (100ns) → Disk (10ms)
- Throughput: Limited by disk I/O, network bandwidth
```

**2. Operating System**
```
Linux, Windows, macOS
- Process management (multitasking)
- Memory management (virtual memory)
- File system (organizing data on disk)
- Networking stack (TCP/IP)
```

**3. Databases**
```
SQL (PostgreSQL), NoSQL (MongoDB), KV (Redis)
- Persistently store data
- Query optimization (indexes)
- Transactions (ACID)
- Replication (resilience)
```

**4. Application Layer**
```
Your code (microservices, APIs)
- Business logic
- Request/response handling
- Caching
- Logging
```

**5. Messaging & Streaming**
```
Kafka, RabbitMQ, AWS SQS
- Asynchronous communication
- Decoupling (producer → queue → consumer)
- Event streaming
```

**6. Monitoring & Observability**
```
Prometheus, DataDog, New Relic
- Metrics (CPU, memory, latency)
- Logs (structured, searchable)
- Traces (request flow)
```

**7. Infrastructure & DevOps**
```
Kubernetes, Terraform, Docker
- Containerization (reproducible)
- Orchestration (auto-scaling, failover)
- Infrastructure as code
- CI/CD pipelines
```

### Request Flow Through Stack

```
User clicks "Like" on Instagram photo

1. [Client Browser] sends HTTP POST /like
2. [Network] TCP connection to Instagram API
3. [Load Balancer] routes to least-loaded server
4. [Application] receives request, validates user
5. [Cache] checks if photo already cached (is? return count)
6. [Database] increments like count, stores in Postgres
7. [Replication] sends to secondary DB (resilience)
8. [Message Queue] publishes "photo_liked" event
9. [Notification Worker] consumes event, sends notification
10. [Application] returns response to client
11. [Network] sends response
12. [Client Browser] updates UI (renders new like count)
```

---

## Storage & I/O Performance {#storage}

### Storage Hierarchy (Speed vs Cost)

```
L1 Cache (32 KB)          0.5ns       $$$$$$ (per byte)
L2 Cache (256 KB)         7ns         $$$$$
L3 Cache (8 MB)           70ns        $$$$
RAM (16-512 GB)           100ns       $$$
SSD (1 TB)                150µs       $$
HDD (10 TB)               10ms        $
Network (distant DC)      100ms       $
```

### Database I/O Patterns

**Random I/O** (seek + read)
```
HDD: 10ms per seek + read time
SSD: 150µs (100x faster than HDD)
RAM: 100ns (100,000x faster than SSD)

Example: Finding a row in 1M row table
- Index on disk: ~10 random I/Os = 100ms
- Index in RAM: ~10 L3 cache lookups = 700ns
Difference: 140,000x faster
```

**Sequential I/O** (scan)
```
HDD: Fast sequential (100+ MB/sec)
SSD: Even faster (500+ MB/sec)
RAM: Fastest (10+ GB/sec)

Lesson: Full table scan slow on disk (10 rows/sec with random access)
         but fast with index (1000 rows/sec jump directly)
```

**Write Amplification**
```
Problem: Writing 1 KB data causes 4 KB disk write (SSD internal)

Level 0 (in-memory): 1 KB write
Level 1 (disk): ~4 KB actual write (page size)
Level 2 (compaction): Multiple rewrites (LSM tree)

LSM Tree (log-structured merge, used in RocksDB, Cassandra):
Write: 1 KB → 4 KB page → 1000x during compaction

Tradeoff: Fast writes, slow reads (need to check multiple levels)
```

### Caching Strategy by Access Pattern

**Hot Data (accessed frequently)**
```
Cache in Redis (in-memory)
Hit rate target: 90%+
Eviction: LRU (least recently used)
Example: User profiles, popular posts
```

**Warm Data (accessed sometimes)**
```
Cache in SSD layer
Hit rate: 50-80%
Eviction: Time-based (TTL)
Example: User feed (cached for 5 min)
```

**Cold Data (rarely accessed)**
```
Archive to S3, cold storage
Retrieval time: Hours acceptable
Cost: Lowest
Example: Old messages, deleted posts
```

---

## Concurrency vs Parallelism {#concurrency}

### Core Difference

**Concurrency**: Multiple tasks making progress (interleaved). One CPU core, switching between tasks.
```
Task A: ████░░░░░░ (run for 10ms)
Task B: ░░░░████░░ (runs while A waits for I/O)
Task C: ░░░░░░░░██ (runs while B waits)

Result: All three progress, single CPU
```

**Parallelism**: Multiple tasks running simultaneously. Multiple CPU cores.
```
CPU 1: ████████████ Task A (10ms)
CPU 2: ████████████ Task B (10ms)
CPU 3: ████████████ Task C (10ms)

Result: All three run simultaneously
```

### When to Use Each

**Concurrency**
```
I/O-bound applications (web servers, databases)
- Thousands of users making requests
- Each request waits for I/O (network, disk)
- While one waits, serve another
- Single thread handles many connections

Example: Node.js event loop
```

**Parallelism**
```
CPU-bound applications (video encoding, ML training)
- Heavy computation
- Multiple cores work on same task
- Speedup ≈ number of cores

Example: Python multiprocessing for parallel encoding
```

### Concurrency Models

**Threads** (shared memory)
```
Pros: Share data easily, simpler communication
Cons: Race conditions, deadlocks, hard to debug

Use: CPU-bound (limited benefit due to GIL in Python)
```

**Async/Await** (non-blocking)
```
Pros: Single thread, efficient, no GIL
Cons: Callback hell (without async/await), complex debugging

Use: I/O-bound (1000s of concurrent connections)
```

**Message Passing** (isolated processes)
```
Pros: No shared memory, safe, debuggable
Cons: Slower (process overhead), communication latency

Use: Distributed systems (across machines)
```

### Real-World Example: Web Server Handling 1000 Concurrent Users

**Threads Approach**
```
1000 users = 1000 threads
Each thread ~1 MB memory
Total: 1 GB RAM just for threads!
Plus switching overhead (context switch = expensive)
Result: Can't scale (maybe max 10k users)
```

**Async Approach (Node.js)**
```
1000 users = 1 event loop + 1000 connections
Each connection ~10 KB
Total: 10 MB RAM
Event loop handles one user waiting for DB → switches to next user
Result: Scales to millions
```

---

## System Design Metrics & SLAs {#metrics}

### SLO, SLA, SLI (Critical Definitions)

**SLI (Service Level Indicator)**: Actual measurement
```
Example: 99.5% of requests respond in < 500ms
```

**SLO (Service Level Objective)**: Target
```
Example: We aim for 99.9% uptime
```

**SLA (Service Level Agreement)**: Contract
```
Example: AWS guarantees 99.99% uptime, or refunds credits
```

### Common Metrics

**Availability**
```
Definition: (Successful requests) / (Total requests)
Formula: (Uptime - Downtime) / Uptime

99% availability   = 9 hours downtime/year (acceptable for SaaS)
99.9% availability = 43 minutes downtime/year (production systems)
99.99% availability= 4 minutes downtime/year (critical systems)
99.999% availability=26 seconds downtime/year (banks, AWS)
```

**Latency (Response Time)**
```
p50 (median): 50% of requests faster than this
p95: 95% of requests faster than this (focus point for users)
p99: 99% of requests faster than this (tail latency)

Example: "p95 latency < 500ms"
Means: 95% of users see response in < 500ms
       5% see > 500ms (frustrating)
```

**Throughput (QPS)**
```
Requests per second handled
Sustained QPS: Average load
Peak QPS: Busiest minute (5-10x average typical)

Example: 1000 QPS sustained, 5000 QPS peak
Capacity planning: Must handle peak without crashing
```

**Error Rate**
```
(Failed requests) / (Total requests)

Target: < 0.1% (99.9% success rate)
High error rate indicates bugs, overload, or external issues
```

---

## Common Estimation Problems {#estimation}

### Problem 1: Estimate Facebook Storage

```
Requirements:
- 3B users, 1B DAU
- Users upload average 10 photos/year
- Average photo: 2 MB

Calculation:
1B DAU × 10 photos/year = 10B photos/year
10B photos × 2 MB = 20 PB/year

After 5 years: 100 PB
With replication (3x): 300 PB
Plus videos (100x more storage): 30,000 PB = 30 EB

Reality: Facebook stores Exabytes (need massive datacenters)
```

### Problem 2: Estimate Twitter QPS

```
Requirements:
- 500M users, 300M DAU
- Users tweet on average 1/day (not all active)
- Peak traffic 5x average

Calculation:
300M tweets/day = 300M / 86,400 sec = 3,472 tweets/second
Peak: 17,361 tweets/second

Reads (timeline): 100x writes = 1.7M reads/second peak
```

### Problem 3: Estimate YouTube Bandwidth

```
Requirements:
- 2.5B users, 1B watch videos/day
- Average video: 50 minutes
- Average bitrate: 3 Mbps (accounts for different qualities)

Calculation:
1B videos/day × 50 min × 60 sec × 3 Mbps = 9 × 10^18 bits/day
= 1.125 × 10^18 bytes/day = 1.125 EB/day

Per second: 1.125 EB / 86,400 = 13 PB/second = 104 Pbps

Reality: Massive infrastructure needed (CDN, multiple datacenters)
```

---

## Capacity Planning {#capacity}

### Growth Estimation

**Moore's Law** (doubling every 2 years)
```
If current: 1 PB storage, 1000 QPS
In 2 years: Need 2 PB storage, 2000 QPS
In 5 years: Need 6 PB storage, 6000 QPS

Plan infrastructure ahead (not just for now)
```

### Resource Allocation

**Rule of Thumb**
```
Plan capacity for 3x current peak
- Handles growth smoothly
- Handles unexpected spikes
- Allows time to scale before hitting limits

If current peak: 1000 QPS
Plan for: 3000 QPS

Costs increase linearly, but avoids emergency scaling
```

### Cost Estimation

**AWS Example: 1M QPS API**

```
Compute (EC2 instances)
- 1 instance = 1,000 QPS
- Need 1,000 instances
- Cost: $0.10/hour per instance
- Monthly: 1,000 × 24 × 30 × $0.10 = $72,000

Database (RDS)
- Storage: 10 TB at $0.23/GB = $2,300/month
- I/O: 1M queries/day, estimate $1,000/month
- Total: $3,300/month

Cache (ElastiCache Redis)
- 100 GB at $0.017/GB/hour = $122/month

Data Transfer
- Out: 1M QPS × 1 KB = 1 TB/sec = 86 TB/day
- Cost: $0.02/GB = 86 × 1000 × $0.02 = $1,720/month

Total: $72,000 + $3,300 + $122 + $1,720 ≈ $77,000/month

Reality check: $1M/year for 1M QPS reasonable for enterprise
```

---

## Performance Optimization Checklist {#performance}

### Before Optimization
- [ ] Measure (don't guess). Use profilers, benchmarks
- [ ] Find bottleneck (80/20 rule: 20% of code causes 80% slowness)
- [ ] Understand tradeoffs (faster ≠ simpler, cheaper, more reliable)

### Quick Wins
- [ ] Enable HTTP compression (gzip 70% reduction)
- [ ] Add caching (Redis, memcached)
- [ ] Optimize queries (indexes, EXPLAIN ANALYZE)
- [ ] Use CDN for static assets
- [ ] Connection pooling (reuse database connections)
- [ ] Batch operations (combine small requests)
- [ ] Async operations (don't wait for slow tasks)
- [ ] Database query optimization (avoid N+1)

### Advanced
- [ ] Database sharding (for 10B+ rows)
- [ ] Replica read (spread reads across replicas)
- [ ] Materialized views (pre-compute aggregations)
- [ ] Search indexing (Elasticsearch for full-text)
- [ ] Message queues (decouple slow operations)
- [ ] Microservices (independent scaling)
- [ ] GraphQL (avoid over-fetching)
- [ ] Protocol buffers (smaller payload than JSON)

### Monitoring Checklist
- [ ] Response time (p50, p95, p99)
- [ ] Throughput (QPS, errors/sec)
- [ ] Resource usage (CPU, memory, disk)
- [ ] Database metrics (slow queries, connections)
- [ ] Cache hit rate (target > 80%)
- [ ] Error rates (< 0.1%)

---

**Key Takeaway**: Master these fundamentals. Back-of-the-envelope calculations, network understanding, and metrics awareness separate great engineers from average ones.
