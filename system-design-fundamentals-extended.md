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
11. [25 Essential System Design Interview Questions](#essential-25)

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

---

## 25 Essential System Design Interview Questions {#essential-25}

> Based on the curriculum in [Nikki Siapno's 25 System Design Concepts post](https://www.linkedin.com/posts/nikkisiapno_i-wrote-25-articles-for-25-system-design-activity-7425807821218439169-fF7U). These are original interview questions, answers, and examples organized to match this guide. The source list repeats “database types”; question 18 turns that repetition into a hands-on selection exercise.

### How to Read This Section

Each question moves from simple to technical:

1. **In simple words** explains the idea without jargon.
2. **Everyday analogy** connects it to something familiar.
3. **Answer** gives the interview-ready explanation.
4. **Example** shows how it appears in a real application.
5. **Watch for**, **trade-off**, or **follow-up** explains common mistakes.

You do not need to memorize product names. Focus on the problem each concept solves and the reason you would choose it.

### Mini Glossary

| Term | Plain-English meaning |
|---|---|
| Client | The browser, mobile app, or program making a request |
| Server | A program that receives requests and returns results |
| API | A documented way for programs to communicate |
| Database | Durable storage for application data |
| Cache | Faster temporary storage for frequently used data |
| Latency | How long one operation takes |
| Throughput | How many operations a system handles in a period |
| Instance | One running copy of an application or service |
| Node | One machine or process participating in a system |
| Stateful | Remembers data between requests |
| Stateless | Does not depend on local memory from an earlier request |
| p99 latency | 99% of requests are faster than this value |
| TTL | Time to live—the time before stored data expires |
| SLO | A measurable reliability or performance target |
| Idempotent | Repeating an operation has the same effect as doing it once |

### Q1. When should you use JWTs instead of server-side sessions?

**In simple words:** Both approaches help a website remember who you are after login. A session gives your browser a random reference number while the server keeps the details. A JWT carries signed user details inside the token itself.

**Everyday analogy:** A session ID is a coat-check ticket—the counter keeps your coat and the ticket points to it. A JWT is more like a signed event pass that contains your name and access level, so different entrances can verify it.

**What problem does this concept solve?** JWTs let several services verify short-lived identity claims without a central session lookup on every request.

**Before this concept:** In a distributed system, every service called the authentication database to resolve the same session, adding latency and a shared dependency.

❌ **Wrong example:** Decode a JWT payload and trust `role: admin` without validating its signature, issuer, audience, and expiry.

✅ **After applying the concept:** The identity service signs a short-lived token, and each approved service validates the complete token using rotated verification keys.

**How it works now:** Authentication checks can scale independently, while refresh tokens or server-side revocation state handle longer-lived access. Sessions remain a valid alternative when immediate centralized control matters more.

**Answer:** Use a JWT when independently deployed services must verify short-lived claims without calling a central session store on every request. Prefer an opaque session ID when immediate revocation, small cookies, and centralized control matter more than stateless verification.

**Example:** An API gateway validates a 10-minute access token signed by the identity service. A rotating refresh token is stored securely and checked against server-side state. Downstream services validate `issuer`, `audience`, `expiry`, and signature—not merely decode the token.

**Watch for:** JWT payloads are encoded, not encrypted. Key rotation needs a `kid` and published verification keys. Logout is not instant unless tokens are short-lived or checked against revocation state.

#### Practical walkthrough — Sessions and JWTs: revoke an employee's access

##### Before choosing deliberately

An application uses long-lived JWTs for every login because they are easy to validate at the edge. An employee is removed at 10:00, but their token remains valid until 18:00 on every service that accepts the signature. Immediate revocation is difficult without adding a shared deny-list, which starts to resemble server-side session state.

##### After choosing by requirement

Use a server-side session for browser-first applications needing immediate logout/revocation, central device/session management, and small cookies. Use short-lived signed access tokens when many services/gateways must validate independently; pair them with rotating refresh tokens and define revocation/compromise behavior. A hybrid is common: a browser session at the edge, short-lived tokens internally.

**What changed:** the design is based on revocation, scale, and attack surface—not “JWT vs session” fashion. Store only opaque session IDs in cookies, secure them with `HttpOnly`, `Secure`, and appropriate `SameSite`, and protect state-changing requests from CSRF.

**Practice:** write the exact sequence for “user changes password on device A; all other devices must be logged out within 60 seconds.”

---

### Q2. How do you make a non-idempotent API safe to retry?

**In simple words:** If a user clicks “Pay” twice or a mobile app retries after losing its connection, the system must not create two payments.

**Everyday analogy:** A cashier writes the order number on the receipt. Seeing the same order number again means “show the original result,” not “charge again.”

**What problem does this concept solve?** It makes network retries safe when the client cannot tell whether the first request completed.

**Before this concept:** Every repeated `POST` created a new order or charge, so a timeout followed by retry could duplicate a real-world side effect.

❌ **Wrong example:** Check for an existing payment and then insert in two separate operations; concurrent requests can both pass the check.

✅ **After applying the concept:** Atomically claim a caller-scoped idempotency key under a unique constraint and persist the request hash and result.

**How it works now:** The first request performs the operation; duplicates return its stored outcome, and a different payload under the same key is rejected.

**Answer:** Require a client-generated idempotency key, scope it to the authenticated caller and operation, and atomically store the request hash plus response. Reusing the key with a different payload must fail.

**Example:** `POST /payments` claims `(merchant_id, idempotency_key)` under a unique constraint, creates one payment, and records its response. A timeout followed by a retry returns the original result rather than charging twice.

**Follow-up:** Database deduplication protects only the local service. External side effects also need a stable operation ID, an idempotent provider, or reconciliation.

#### Practical walkthrough — Idempotency: a client retries `POST /payments`

##### Before the pattern

The client times out after sending a charge. It retries the same POST. The first request may have succeeded, but the server cannot distinguish the retry, so the customer is charged twice.

##### After the pattern

The client generates an idempotency key once per intended payment. The API stores a record keyed by `(customer, idempotencyKey)` with a request fingerprint and final/in-progress result. A duplicate with the same fingerprint returns the original response; the same key with different content is rejected. The payment gateway receives a compatible idempotency key too.

```text
Request A -> record Pending(key) -> charge -> save Success(response)
Retry A   -> same key/fingerprint -> return saved response
Different request + same key -> reject conflict
```

**What changed:** retries become safe for a named business operation. TTL/retention must outlive likely retries and dispute windows; a unique database constraint prevents racing duplicate requests.

**Practice:** crash after the gateway confirms but before your response. Explain how the retry obtains the correct result.

---

### Q3. Which rate-limiting algorithm should an API use?

**In simple words:** Rate limiting controls how often someone may use an API so one user, bot, or broken program cannot overload it.

**Everyday analogy:** A nightclub allows only a certain number of people through the door. A small waiting area may absorb a short rush, but entry slows when the club is full.

**What problem does this concept solve?** It protects limited capacity, enforces fair usage, and contains abusive or faulty clients.

**Before this concept:** The API accepted unlimited requests until threads, connections, or a downstream provider became saturated for everyone.

❌ **Wrong example:** Apply one global counter to all customers, block legitimate tenants together, and return generic `500` errors when the limit is reached.

✅ **After applying the concept:** Choose an algorithm and scope based on the business rule—for example, a per-tenant token bucket with a controlled burst allowance.

**How it works now:** Excess calls fail quickly with `429` and retry guidance, while available capacity remains protected for other callers.

**Answer:** Choose based on burst policy and accuracy:

| Algorithm | Strength | Weakness | Good fit |
|---|---|---|---|
| Fixed window | Simple and cheap | Boundary bursts | Coarse quotas |
| Sliding log | Exact | High memory | Low-volume sensitive APIs |
| Sliding counter | Good approximation | More state | General API quotas |
| Token bucket | Allows controlled bursts | Requires refill state | Public APIs |
| Leaky bucket | Smooth output rate | Delays bursts | Protecting a steady downstream |

**Example:** Give each customer a token bucket of 100 requests/second with a burst capacity of 200. Return `429`, `Retry-After`, and remaining-quota headers when empty.

#### Practical walkthrough — Rate limiter: accept a marketing spike without collapsing

##### Before choosing an algorithm

All API requests share one fixed 100-requests/minute counter. It permits a burst of 100 at the minute boundary, unfairly blocks a premium customer behind a bot, and gives login and catalogue reads the same protection.

##### After choosing by traffic semantics

Use token bucket when a bounded burst is acceptable; sliding window/log when precision matters; leaky bucket/queue when smoothing outgoing work; concurrency limits when in-flight cost matters. Key limits by an authenticated tenant/user/API key, not a spoofable header. Apply a global cap as a final safety valve and separate limits for high-cost routes.

**What changed:** the limit represents capacity and fairness policy. A `429` occurs early rather than after saturation; include retry guidance and observe allowed/rejected requests by key class.

**Practice:** choose limits for anonymous login, authenticated search, report export, and payment creation, then explain why each differs.

---

### Q4. What makes a system observable rather than merely monitored?

**In simple words:** Monitoring tells you that something known is wrong. Observability gives you enough clues to investigate new problems and understand why they happened.

**Everyday analogy:** A car's warning light is monitoring. The speed, temperature, engine data, and maintenance history available to a mechanic provide observability.

**What problem does this concept solve?** It helps engineers explain unexpected production behavior instead of detecting only failures anticipated in advance.

**Before this concept:** Teams knew CPU was high or requests were failing but could not connect a user request to the responsible deployment, service, or query.

❌ **Wrong example:** Log unstructured messages everywhere, include sensitive payloads, create no correlation IDs, and alert on every individual error.

✅ **After applying the concept:** Correlate SLO metrics, structured logs, traces, and deployment events using consistent service and request identifiers.

**How it works now:** An alert identifies user impact, a trace narrows the slow path, and focused logs explain the cause without exposing confidential data.

**Answer:** Monitoring checks known failure conditions; observability lets engineers investigate failures they did not predict. Build around correlated metrics, structured logs, distributed traces, and change/deployment events.

**Example:** A checkout SLO measures successful requests under 500 ms. An alert fires on error-budget burn, a trace identifies payment-provider latency, and logs can be joined by trace ID without recording card data.

**Strong interview signal:** Define what question each signal answers. More telemetry is not automatically better; control cardinality, sampling, retention, and sensitive fields.

#### Practical walkthrough — Observability: diagnose a slow checkout

##### Before the concept

The service has CPU and request-count dashboards. A user reports that checkout sometimes takes 12 seconds. Engineers can see “latency is high” but cannot tell whether it is the database, payment provider, queue, or one tenant.

##### After the concept

Every request has a correlation/trace ID. Distributed traces show spans for validation, SQL, payment, and publishing. Metrics quantify latency distributions, errors, saturation, and business outcomes; structured logs carry useful dimensions and link to the trace.

```text
Symptom -> metric alerts p99 checkout latency
Trace   -> payment span consumed 10.8s
Logs    -> provider timeout and tenant/payment-method dimensions
```

**What changed:** telemetry answers unknown questions without a new deployment. Avoid high-cardinality labels such as raw user IDs in metrics; sample traces/logs thoughtfully while retaining errors and slow paths.

**Practice:** define the RED/USE metrics and a trace span tree for checkout, including an async outbox handoff.

---

### Q5. When should a monolith be split into microservices?

**In simple words:** A monolith keeps many features in one deployable application. Microservices split selected business areas into separately deployed applications. Smaller services are not automatically better.

**Everyday analogy:** One restaurant kitchen is simple to coordinate. Separate bakery, grill, and delivery kitchens help only when their workloads and teams are independent enough to justify extra coordination.

**What problem does this concept solve?** A well-chosen service boundary enables independent ownership, deployment, scaling, or compliance for a business capability.

**Before this concept:** One deployment unit forced unrelated teams and workloads to release and scale together, even when one capability changed or consumed resources independently.

❌ **Wrong example:** Split every database table into a service and make one user request perform a long chain of synchronous network calls.

✅ **After applying the concept:** Extract a stable business capability with clear ownership, API contracts, operational responsibility, and data boundaries.

**How it works now:** That capability can deploy and scale independently, while the team explicitly manages latency, partial failure, contracts, and eventual consistency.

**Answer:** Split when a stable business boundary needs independent ownership, deployment, scaling, availability, or compliance. Do not split only because the codebase is large.

**Example:** Extract media processing from a modular monolith because it has GPU-heavy scaling and asynchronous failure behavior. Keep tightly coupled order rules together until their transaction boundary and ownership are clear.

**Trade-off:** Microservices exchange in-process calls and transactions for network latency, partial failures, versioned contracts, data ownership, observability, and operational cost.

#### Practical walkthrough — Monolith to microservices: release billing independently

##### Before a justified split

A modular monolith has a shared database but clean modules. A team splits each table into a service because “microservices scale.” Now one user action needs five network calls, local transactions become sagas, local development slows, and there is no clear ownership gain.

##### After choosing a boundary

Keep the modular monolith while it supports independent teams and deployment needs. Split only where bounded context, ownership, release cadence, scale/security isolation, or reliability demands are compelling. Extract one vertical capability behind an API/event contract, give it data ownership, and measure the result before the next split.

**What changed:** a network boundary is introduced to solve a proven organizational/technical problem, not to copy a topology. Distributed failure handling, tracing, contracts, and on-call ownership become mandatory costs.

**Practice:** name one module that could be extracted, its owned data, callers, failure mode, and rollback strategy; if any are vague, keep it in-process.

---

### Q6. What should a production CI/CD pipeline guarantee?

**In simple words:** CI/CD is an automated path that checks code, packages it, and safely releases it. Its purpose is to make releases repeatable and catch problems before every user receives them.

**Everyday analogy:** A factory line inspects the same product at several stages, labels exactly which batch it came from, and tests a small sample before shipping everywhere.

**What problem does this concept solve?** It makes every build and deployment repeatable, traceable, testable, and safely reversible.

**Before this concept:** Engineers built artifacts on personal machines, copied files manually, and discovered configuration differences only after production failed.

❌ **Wrong example:** Rebuild separately in each environment, deploy directly to every production instance, and improvise rollback after an error.

✅ **After applying the concept:** Build one immutable artifact, run automated gates, promote the same artifact, canary it, verify SLOs, and use a tested rollback path.

**How it works now:** The team knows exactly what version is running, releases are consistent, and failures stop promotion or automatically restore the last safe version.

**Answer:** A pipeline should produce one immutable, traceable artifact; test it in progressively realistic environments; scan dependencies and configuration; deploy safely; verify health; and support fast rollback or roll-forward.

**Example flow:**
```text
Commit -> build once -> unit/static/security tests -> integration tests
       -> signed artifact -> canary deployment -> SLO verification -> rollout
```

**Failure policy:** Stop promotion on failed quality gates. A database migration must be backward compatible during mixed-version deployment. Rollback criteria should be defined before release.

#### Practical walkthrough — CI/CD: prevent a broken payment deployment

##### Before the pipeline

A developer builds locally, manually copies an artifact, and deploys directly to production. Environment-specific code differs, tests are optional, and rollback depends on remembering previous files.

##### After the pipeline

One immutable build artifact passes through repeatable stages: lint/unit tests, dependency/security scans, integration/contract tests, deployment to a production-like environment, migration checks, staged rollout, health/SLI verification, and automated/manual rollback gates.

```text
Commit -> build once -> test -> scan -> stage -> canary -> observe -> promote/rollback
```

**What changed:** deployment becomes a controlled, observable process rather than a unique event. Keep secrets out of artifacts/logs, make database changes backward compatible, and ensure a rollback is safe with the current schema.

**Practice:** add a new non-null column to a busy table and describe expand, backfill, switch, and contract steps.

---

### Q7. How do ACID and BASE differ, and can one system use both?

**In simple words:** Some data must be correct immediately, while other data may take a few seconds to catch up. ACID focuses on safe transactions; BASE accepts temporary differences so a distributed system can remain responsive.

**Everyday analogy:** A bank balance must not spend the same money twice. A social-media like count can briefly show 100 on one screen and 101 on another, then become consistent later.

**What problem does this concept solve?** It gives designers language for deciding where immediate transactional correctness is essential and where temporary inconsistency is acceptable.

**Before this concept:** Teams applied one consistency choice everywhere—either creating unnecessary bottlenecks or weakening critical business invariants.

❌ **Wrong example:** Use eventual consistency for gift-card redemption without concurrency protection because “availability is more important.”

✅ **After applying the concept:** Protect money and unique reservations with ACID transactions while updating search, analytics, and counters asynchronously.

**How it works now:** Each boundary has an explicit invariant and staleness allowance instead of a vague system-wide label.

**Answer:** ACID describes transaction guarantees; BASE describes systems that remain available by allowing temporarily inconsistent state that converges. They are not mutually exclusive database product categories.

**Example:** Checkout uses an ACID transaction to create an order and outbox event. Search consumes the event asynchronously and is eventually consistent. The order boundary is strict; discovery is BASE-like.

**Decision rule:** State the invariant first. Money, unique reservations, and permissions often need stronger consistency than feeds, counters, recommendations, or search indexes.

#### Practical walkthrough — ACID and BASE: reserve the last hotel room and update search

##### Before separating consistency needs

One team puts inventory, booking confirmation, search index, analytics, and email in one transaction. The transaction is slow and cannot cover remote systems. Another team makes everything asynchronous, allowing two users to book the last room.

##### After selecting a consistency boundary

Use ACID transactions for the local invariant: one room inventory reservation cannot be oversold. Publish changes through an outbox; search, analytics, and email update asynchronously and may be briefly stale. Reconciliation detects/repairs lag or missed projections.

**What changed:** strong consistency protects the money/inventory rule; eventual consistency serves derived views. BASE is not “no correctness”—it requires idempotency, compensation, reconciliation, and clear user messaging.

**Practice:** label every write in booking flow as strongly consistent, eventually consistent, or compensatable, and defend the label.

---

### Q8. What is Change Data Capture, and when is it better than dual writes?

**In simple words:** Change Data Capture (CDC) watches committed database changes and sends them to other systems. This is safer than asking application code to save data and separately send a message, because it might succeed at one and fail at the other.

**Everyday analogy:** Instead of asking a cashier to update both the register and a separate notebook, CDC reads the register's official receipt tape and forwards every completed sale.

**What problem does this concept solve?** It reliably propagates committed database changes without an unsafe gap between saving data and publishing an event.

**Before this concept:** Application code updated the database and then published a message. A crash between those calls left the database and downstream systems inconsistent.

❌ **Wrong example:** `SaveChanges(); await broker.Publish(event);` and assume both operations succeed or fail together.

✅ **After applying the concept:** Write business data and an outbox record in one transaction, then use CDC to stream committed outbox entries.

**How it works now:** No committed change is silently lost, while idempotent consumers safely handle possible duplicate delivery and replay.

**Answer:** CDC streams committed database changes from a transaction log. It avoids asking application code to update a database and publish an event as two unrelated operations.

**Example:** An order transaction writes the order and an outbox row. A CDC connector publishes the outbox record to Kafka; search, analytics, and notifications consume it independently.

**Failure considerations:** Preserve partition ordering where required, make consumers idempotent, retain enough history for replay, version event schemas, and monitor replication lag. CDC does not eliminate duplicate delivery.

#### Practical walkthrough — Change Data Capture: publish database changes safely

##### Before CDC

An order service saves an order then separately publishes `OrderPlaced`. A crash between the two loses an event; publishing first may create an event for a rolled-back order. Polling updated rows adds load and can miss/duplicate changes without care.

##### After CDC/outbox

Capture committed database log changes or write an outbox row in the same transaction. A connector/relay streams those committed records to consumers, which remain idempotent. Downstream systems build projections from a durable ordered change stream.

**What changed:** the source database becomes the authoritative record of committed change. CDC does not transmit business intent automatically—schema changes, deletes, backfills, ordering, and PII governance need explicit treatment. Use an outbox when you need a business event schema rather than raw table changes.

**Practice:** explain how an `UPDATE` to `Orders` becomes an event without exposing internal columns or sending the same change twice.

---

### Q9. How do you choose among major database types?

**In simple words:** Different databases are optimized for different ways of saving and finding data. Choose by what the application must do, not by which database is popular.

**Everyday analogy:** A filing cabinet, phone book, map, and photo album all store information, but each organizes it for a different kind of lookup.

**What problem does this concept solve?** It aligns storage structure and guarantees with the application's actual reads, writes, relationships, and consistency needs.

**Before this concept:** Teams chose one familiar or fashionable database first and forced every access pattern into it.

❌ **Wrong example:** Store relational orders, full-text product search, images, and analytics aggregates in one document collection simply to use one technology.

✅ **After applying the concept:** Start from queries and invariants, choose a primary source of truth, and add specialized projections only when their value justifies operations.

**How it works now:** Each store handles a suitable workload, and ownership, synchronization, replay, and failure behavior remain explicit.

**Answer:** Start with access patterns and invariants:

| Need | Likely starting point |
|---|---|
| Transactions and flexible queries | Relational database |
| Key lookup at huge scale | Key-value store |
| Variable aggregate-shaped records | Document database |
| Relationship traversal | Graph database |
| Metrics ordered by time | Time-series database |
| Full-text relevance | Search engine |
| Similarity search | Vector index/database |

**Example:** Product truth lives in PostgreSQL, searchable projections in Elasticsearch, images in object storage, and hot product summaries in Redis. Polyglot persistence is useful only when the operational cost is justified.

#### Practical walkthrough — Database types: store a marketplace correctly

##### Before choosing by workload

All data goes into one relational table: products with changing attributes, carts, full-text search, time-series clicks, and money transfers. Either the schema becomes sparse and slow or application code rebuilds features the database already offers.

##### After choosing by access pattern

Use a relational database for orders/payments and transactional joins; document storage for flexible product attributes; Redis for bounded cache/session/rate-limit state; a search engine for text/facets; analytics/columnar storage for events; object storage for images/files. Each store has a source-of-truth/derived-data role.

**What changed:** data model follows query, consistency, latency, volume, and operational skill—not a product label. Adding databases increases operational and consistency cost, so start with fewer stores where possible.

**Practice:** for each store, write its primary key, most frequent read, write rate, retention, consistency requirement, and recovery plan.

---

### Q10. Which quality attributes drive a system design?

**In simple words:** Quality attributes describe how well a system must work: how fast, reliable, secure, affordable, and easy to change it should be.

**Everyday analogy:** Designing an ambulance emphasizes speed and reliability; designing a family car may emphasize price and fuel efficiency. Neither vehicle can maximize every quality at once.

**What problem does this concept solve?** It converts vague expectations into measurable priorities that guide architecture trade-offs.

**Before this concept:** Requirements said “fast, scalable, and reliable,” so design decisions could not be evaluated objectively.

❌ **Wrong example:** Promise zero latency, 100% availability, perfect consistency, unlimited scale, and minimum cost at the same time.

✅ **After applying the concept:** Define targets such as p99 latency, availability, durability, recovery time, security, and cost, then rank their importance.

**How it works now:** Caching, replication, storage, and deployment choices can be justified against agreed targets and tested in production.

**Answer:** Common attributes are latency, throughput, availability, durability, consistency, security, privacy, scalability, maintainability, operability, and cost. They must be measurable and prioritized because they conflict.

**Example:** “Fast and reliable” becomes: p99 reads below 200 ms, 99.99% monthly availability, recovery point below five minutes, and recovery time below 30 minutes.

**Interview technique:** Identify two or three dominant attributes and show how they determine storage, replication, caching, and failure decisions.

#### Practical walkthrough — Quality attributes: turn “fast and reliable” into design constraints

##### Before the concept

Requirements say “make uploads fast, secure, and highly available.” Teams choose components without targets, then cannot decide whether direct object storage, synchronous malware scan, or two regions is warranted.

##### After the concept

Turn qualities into measurable scenarios: “99% of 50 MB uploads obtain a signed URL under 300 ms,” “no file is downloadable until scanned,” “RPO is under five minutes,” “one zone failure does not exceed 0.1% errors.” These scenarios drive trade-offs and capacity design.

**What changed:** non-functional wishes become testable architecture decisions. Prioritize because low latency, strong consistency, low cost, and global availability may conflict.

**Practice:** write one measurable scenario each for performance, availability, security, scalability, operability, and cost for a feature you know.

---

### Q11. What is the difference between health checks and heartbeats?

**In simple words:** A health check asks, “Can you do your job right now?” A heartbeat says, “I am still here.”

**Everyday analogy:** A teacher calling a student's name checks presence. Asking the student to solve a problem checks whether they are ready to participate.

**What problem does this concept solve?** It distinguishes “the process exists” from “the process can safely perform its assigned role.”

**Before this concept:** Traffic continued reaching instances that were running but unable to serve, while over-aggressive checks restarted healthy processes during a dependency outage.

❌ **Wrong example:** Make liveness depend on every database and provider; one provider failure causes all application instances to restart together.

✅ **After applying the concept:** Use narrow liveness, traffic-focused readiness, and expiring heartbeats or leases for distributed workers.

**How it works now:** Dead processes restart, unready instances leave load balancing, and abandoned work can be reassigned without creating a restart cascade.

**Answer:** A health check is an observer asking whether a component can serve a particular purpose. A heartbeat is a component periodically announcing that it is alive or renewing a lease.

**Example:** Kubernetes liveness restarts a deadlocked process; readiness removes an instance from traffic while it warms its cache. A worker heartbeat renews a 30-second lease so abandoned jobs can be reassigned.

**Pitfall:** A health endpoint that synchronously checks every dependency can cause cascading removal. Liveness should usually verify the process itself; readiness should reflect whether it can safely accept traffic.

#### Practical walkthrough — Health checks and heartbeats: remove a dead worker safely

##### Before the concept

A load balancer sends traffic to any process with an open port. A process is alive but cannot connect to its database; requests fail. A worker crashes silently, and no scheduler knows it stopped making progress.

##### After the concept

Use liveness checks to decide whether a process needs restart; readiness checks to decide whether it may receive traffic; startup checks for slow initialization; and heartbeats/lease renewals to show a worker is actively alive/progressing. Keep readiness dependencies intentional—checking every optional provider can take down healthy core traffic.

**What changed:** “process exists” is separated from “can safely serve this work.” Heartbeats should be time-bounded and monitored for missing sequence/progress, not just received timestamps.

**Practice:** define liveness, readiness, and heartbeat behavior for an API plus an asynchronous report worker.

---

### Q12. Compare an API gateway, load balancer, and reverse proxy.

**In simple words:** All three sit in front of servers, but their main jobs differ. A load balancer spreads traffic, a reverse proxy represents servers, and an API gateway applies rules specifically to APIs.

**Everyday analogy:** At a hospital, reception is the reverse proxy, a coordinator sends patients to less-busy doctors like a load balancer, and an insurance desk enforces identity and policy rules like an API gateway.

**What problem does this concept solve?** It assigns routing, traffic distribution, and API policy to clear infrastructure responsibilities.

**Before this concept:** Each service implemented TLS, authentication, quotas, routing, and public exposure differently.

❌ **Wrong example:** Put complete business workflows in one gateway and make it a stateful bottleneck required for every internal action.

✅ **After applying the concept:** Use load balancing for healthy-instance selection, a reverse proxy for traffic mediation, and an API gateway for consistent edge policies.

**How it works now:** Services focus on domain logic, while shared transport policies are enforced consistently without hiding business ownership.

**Answer:** A load balancer distributes work across healthy instances. A reverse proxy fronts origin servers and may terminate TLS, route, cache, or rewrite traffic. An API gateway is an API-focused reverse proxy that commonly adds authentication, quotas, transformations, analytics, and developer policies.

**Example:** A global L4 balancer selects a region, an L7 gateway validates OAuth and routes `/orders`, and a service-mesh proxy handles service-to-service mTLS and retries.

**Pitfall:** Putting business workflows in the gateway turns it into a coupled bottleneck. Keep policy at the edge and domain rules in services.

#### Practical walkthrough — Gateway, load balancer, reverse proxy: route an API request

##### Before distinguishing roles

One “gateway” is asked to terminate TLS, balance pods, validate tokens, aggregate responses, transform APIs, and own business authorization. It grows into a fragile global bottleneck.

##### After assigning roles

A reverse proxy terminates TLS and forwards HTTP; a load balancer selects a healthy instance; an API gateway applies shared external API policy such as auth, rate limits, request shaping, and client routing. Platforms often combine pieces, but their responsibilities remain distinct.

**What changed:** cross-cutting edge concerns are centralized without moving domain authorization and business orchestration out of services. Make the data plane resilient even if the control plane is temporarily unreachable.

**Practice:** trace a mobile request through CDN, WAF, gateway, load balancer, BFF, and service; state which layer owns each responsibility.

---

### Q13. What happens during an HTTPS connection?

**In simple words:** HTTPS lets a client confirm that it reached the correct server and creates an encrypted connection so outsiders cannot easily read or change the traffic.

**Everyday analogy:** Two people first verify identity documents, agree on a secret code without announcing it publicly, and then use that code for their conversation.

**What problem does this concept solve?** HTTPS protects data from network eavesdropping and tampering while authenticating the server endpoint.

**Before this concept:** Credentials and responses crossed networks in readable form, and attackers could impersonate servers or modify traffic.

❌ **Wrong example:** Disable certificate validation to “fix” a TLS error or send secrets over HTTP inside an otherwise secure application.

✅ **After applying the concept:** Validate trusted certificates, negotiate modern TLS, rotate keys automatically, and use mTLS where service identity is required.

**How it works now:** Transport is confidential and integrity-protected, while application authentication and authorization still make independent access decisions.

**Answer:** DNS resolves the host, a transport connection is established, and the TLS handshake negotiates algorithms, validates the server certificate, performs key agreement, and derives symmetric session keys. HTTP data is then encrypted and integrity-protected.

**Example:** TLS terminates at an edge proxy, which forwards to services using mTLS. Certificate automation rotates both public and internal certificates before expiry. TLS 1.3 resumption reduces repeat-connection latency.

**Interview follow-up:** Encryption in transit does not authorize a caller. HTTPS, authentication, authorization, request validation, and encryption at rest address different threats.

#### Practical walkthrough — HTTPS: protect a login over an untrusted network

##### Before HTTPS

A login form posts credentials over plain HTTP, allowing a network observer to read or alter it. Or TLS is terminated carelessly and internal hops receive unprotected user data without a clear trust boundary.

##### After HTTPS/TLS

The client validates the server certificate and hostname, negotiates TLS, performs a key exchange, derives symmetric session keys, then encrypts and authenticates HTTP bytes. Session resumption reduces repeated handshake cost. HSTS helps clients prefer HTTPS after first trustworthy contact.

**What changed:** confidentiality and integrity cover traffic in transit, while authentication proves the endpoint identity. TLS does not replace input validation, authorization, secure cookie settings, or protection of keys/certificates.

**Practice:** explain why a valid certificate for `api.example.com` must still fail for `evil.example.net`, and where TLS is terminated in your design.

---

### Q14. How do load-balancing algorithms affect performance?

**In simple words:** When several servers can do the same job, a load balancer decides which server receives each request. The selection rule matters when servers or requests are not equal.

**Everyday analogy:** A supermarket may send shoppers to each checkout in turn, to the shortest line, or to a special checkout suited to a large order.

**What problem does this concept solve?** It distributes work so capacity is used efficiently and slow or overloaded instances do not dominate tail latency.

**Before this concept:** Clients targeted one known server or chose instances without health and load information, creating hotspots and single points of failure.

❌ **Wrong example:** Use round robin for long-lived WebSockets when one server may already hold far more active connections than another.

✅ **After applying the concept:** Match the algorithm to workload—least connections for sessions, weighted least requests for unequal capacity, or consistent hashing for affinity.

**How it works now:** Healthy instances receive an appropriate share of traffic, and the routing decision reflects real workload characteristics.

**Answer:**

- **Round robin:** good for similar stateless instances and uniform requests.
- **Weighted round robin:** accounts for different instance capacities.
- **Least connections/requests:** useful when request duration varies.
- **Latency-aware:** steers toward fast healthy backends but can oscillate.
- **Consistent hashing:** provides affinity for caches or stateful partitions.
- **Power of two choices:** samples two targets and selects the less loaded, giving strong results cheaply.

**Example:** A WebSocket gateway uses least connections within a region; an HTTP API uses weighted least requests; a distributed cache uses consistent hashing.

#### Practical walkthrough — Load balancing: prevent one slow node from receiving more traffic

##### Before choosing an algorithm

Round robin gives an equal number of requests to each instance. One instance handles expensive exports and has long active requests; it receives more traffic despite being busy, so latency becomes uneven.

##### After choosing from signals

Use least-connections/least-request for variable-duration work, weighted algorithms for unequal capacity, consistent hashing when session/cache affinity matters, and zone-aware routing for locality. Health checks remove bad nodes; outlier detection avoids repeatedly choosing a degraded one.

**What changed:** routing reacts to workload and capacity. Sticky sessions can create hot nodes and complicate failover; externalize session state unless affinity is essential.

**Practice:** compare round robin, least connections, and weighted least requests for a mix of 10 ms reads and 30-second exports.

---

### Q15. Which database-caching pattern should you choose?

**In simple words:** A cache keeps frequently requested data in faster storage so the database does less work. The difficult part is ensuring the cached copy does not stay wrong after the original changes.

**Everyday analogy:** A café places popular items at the counter instead of fetching them from storage for every customer. Labels and expiry times prevent stale food from being served.

**What problem does this concept solve?** It reduces database load and read latency while defining how cached data becomes fresh or expires.

**Before this concept:** Every request queried the source database, so popular data created repeated work and high latency.

❌ **Wrong example:** Cache forever under an incomplete key, never invalidate on writes, and let thousands of requests rebuild one expired hot item simultaneously.

✅ **After applying the concept:** Choose cache-aside, read-through, write-through, or write-behind deliberately and define TTL, versioning, invalidation, and stampede protection.

**How it works now:** Most reads use fast cached values, misses are controlled, and the accepted staleness window is explicit rather than accidental.

**Answer:** Cache-aside is a safe default for read-heavy data: read cache, fetch on miss, populate with TTL. Write-through updates cache and database together; write-behind improves write latency but risks data loss and complex recovery.

**Example:** Product details use cache-aside with versioned keys. A distributed lock or request coalescing prevents thousands of requests rebuilding an expired hot key. Negative results receive a short TTL to reduce repeated misses.

**Correctness:** Define the acceptable staleness window. Invalidate after a committed write, tolerate races with versions, and never treat cache as the source of truth unless it is designed as durable storage.

#### Practical walkthrough — Cache patterns: update a product price safely

##### Before choosing a pattern

The API writes the cache first then the database. If the database write fails, users see a price that never became true. Or it writes the database and forgets cache invalidation, serving an old price indefinitely.

##### After choosing by ownership

For common read-heavy data, use cache-aside: read cache, fetch source on miss, write cache with TTL, then invalidate/version after database commit. Use write-through only when synchronous cache/store coordination is worth it; use write-behind only with deliberate durability and loss semantics; use refresh-ahead for predictable hot keys.

**What changed:** cache behavior has a documented source of truth and stale-data bound. Cache invalidation is a protocol: test races, TTL expiry, stampede prevention, and what happens when cache is unavailable.

**Practice:** show the exact ordering for “admin updates product price” and define the longest permitted stale window.

---

### Q16. What should and should not be cached by a CDN?

**In simple words:** A Content Delivery Network (CDN) stores copies near users around the world. It is excellent for public files but dangerous for private or frequently changing responses unless cache rules are precise.

**Everyday analogy:** A company prints common brochures at local offices, but it does not distribute a customer's private bank statement to every office.

**What problem does this concept solve?** It serves public content near users and protects origins without mixing private responses or serving stale critical data.

**Before this concept:** Every image and static asset crossed regions from the origin, increasing latency, bandwidth cost, and origin load.

❌ **Wrong example:** Cache authenticated account pages publicly using a key that ignores the user, authorization header, locale, or query parameters.

✅ **After applying the concept:** Cache immutable public assets under versioned URLs and apply explicit private/no-store rules to personalized content.

**How it works now:** Edge nodes answer safe repeat requests quickly, while cache keys, purge rules, and authorization prevent data leakage.

**Answer:** Cache immutable public assets aggressively using content-hashed URLs. Cache dynamic responses only when their keys include every representation-changing dimension and privacy permits it.

**Example:** `/assets/app.a1b2.js` receives a one-year TTL. Public catalog pages use short edge caching with surrogate-key purges. Personalized account pages use `private, no-store`.

**Failure considerations:** Protect the origin from cache stampedes, serve stale content during bounded outages where safe, sign private media URLs, and test purge propagation. A high hit rate is useless if the cache key leaks one user's data to another.

#### Practical walkthrough — CDN: serve a personalized account page correctly

##### Before the concept

The CDN caches every GET URL, including `/account`. A shared edge response accidentally serves Alice’s account content to Bob. Or no assets are cached, so every global user downloads images from one origin.

##### After the concept

Cache public immutable static assets with content-hashed URLs and long TTLs; cache public safe HTML/API responses only with explicit cache keys and `Cache-Control`; keep personalized/authenticated responses private/no-store unless a carefully designed edge-key scheme exists. Use signed URLs/cookies for protected media and purge/version on change.

**What changed:** edge caches reduce origin latency/load while preserving data isolation. The cache key must include every response-varying dimension, or the response must not be shared.

**Practice:** classify logo image, public product page, product price API, user profile, and private invoice PDF as CDN-cacheable or not, including keys/TTL.

---

### Q17. How do you choose between REST, GraphQL, WebSocket, SSE, and asynchronous events?

**In simple words:** These are different communication styles. Choose based on whether communication is request/response, customizable data retrieval, a live two-way conversation, a one-way stream, or background work.

**Everyday analogy:** REST is ordering from a menu, GraphQL is building a custom meal, WebSocket is a phone call, SSE is a live radio broadcast, and a message queue is leaving a task in someone's inbox.

**What problem does this concept solve?** It matches communication behavior to request/response, customizable queries, live streams, bidirectional sessions, or decoupled background work.

**Before this concept:** One protocol was forced onto every interaction, producing polling for live data or tight synchronous coupling for slow work.

❌ **Wrong example:** Open a WebSocket for a once-per-day settings update or hold an HTTP request open while a multi-hour job completes.

✅ **After applying the concept:** Use a small set of protocols at clear boundaries—for example, REST for history, WebSocket for chat, and events for indexing.

**How it works now:** Each interaction has appropriate latency, reliability, compatibility, and operational behavior without unnecessary complexity.

**Answer:** Match the interaction:

| Protocol/style | Best fit |
|---|---|
| REST/HTTP | Resource-oriented public APIs and broad interoperability |
| GraphQL | Client-selected reads over connected product data |
| WebSocket | Bidirectional low-latency sessions |
| SSE | Server-to-client streams over HTTP |
| Queue/events | Decoupled background work and integration |

**Example:** A chat product uses REST for history, WebSocket for live messages, and Kafka events for indexing and notifications. One system can use multiple protocols at clear boundaries.

#### Practical walkthrough — Communication style: build chat plus order updates

##### Before choosing deliberately

A team uses REST polling for live chat, causing many empty requests and delayed messages. It uses WebSockets for an hourly order status update, adding persistent-connection complexity for no benefit. It uses synchronous REST to make five services react to an order.

##### After choosing by interaction

Use REST for resource-oriented request/response, GraphQL for client-shaped graphs with governance, WebSockets for bidirectional low-latency sessions, SSE for server-to-client streams, and asynchronous events/queues for decoupled durable reactions. One product can use several: REST to create order, WebSocket for live driver location, events for fulfillment.

**What changed:** protocol matches directionality, freshness, ownership, and failure handling. GraphQL does not remove N+1, authorization, caching, or complexity; real-time transports need reconnect/resume semantics.

**Practice:** design a chat message send, presence update, history load, notification, and analytics event using the appropriate mode.

---

### Q18. Select storage for an e-commerce product, cart, search, and analytics system.

**In simple words:** A large application does not have to force every kind of data into one storage technology. It can use a few carefully chosen stores while keeping one clear source of truth.

**Everyday analogy:** A shop uses shelves for products, a cash register for sales, a basket for each shopper, and accounting books for reports. Each serves a different purpose.

**What problem does this concept solve?** It separates transactional truth, temporary session state, search projection, media, and analytics according to their distinct access patterns.

**Before this concept:** One database attempted to handle transactions, fuzzy search, expiring carts, images, and analytical scans, so workloads interfered with one another.

❌ **Wrong example:** Add a new database for every feature with no declared source of truth, synchronization, or recovery path.

✅ **After applying the concept:** Keep authoritative commerce data relational, carts in an expiring key-value store, search in a projection, images in object storage, and analytics in a warehouse.

**How it works now:** Each workload uses an appropriate store, while events, replay, and reconciliation maintain understandable data flow.

**Example solution:** Keep authoritative products, prices, orders, and payments in a relational database. Store carts in a low-latency key-value store with expiry. Project catalog documents into a search engine. Send immutable business events to a warehouse or lakehouse for analytics. Store images in object storage behind a CDN.

**Why:** Each choice follows access patterns, consistency, lifetime, and query shape—not trend or scale alone.

**Follow-up:** Explain the source of truth, propagation path, expected lag, replay strategy, and behavior when a projection is unavailable.

#### Practical walkthrough — E-commerce storage: use a source and read model per need

##### Before the concept

Product catalogue, cart, search, orders, and click analytics share one normalized transactional database. Search facets scan tables, click queries affect order writes, and carts compete with long reporting queries.

##### After the concept

Orders/payments use relational transactions; product truth may be relational/document depending on attributes; carts use a fast key-value store with expiry plus durable recovery where needed; search is a derived index; analytics is append-only event/columnar storage. Changes flow through outbox/CDC to derived stores.

**What changed:** each workload gets a fit-for-purpose model, but only one source owns a fact. Search index and analytics are rebuildable; they are not allowed to become conflicting masters.

**Practice:** draw data flow for a product price change through source DB, cache, search index, and analytics without dual writes.

---

### Q19. When is gRPC a better choice than JSON/REST?

**In simple words:** gRPC is a fast, strongly defined way for programs to communicate, commonly inside one organization. REST with JSON is easier for people and many public clients to inspect and use.

**Everyday analogy:** gRPC is an efficient internal shorthand shared by trained staff. REST is a widely understood public form that more people can read without special tools.

**What problem does this concept solve?** It provides efficient, schema-first, generated communication and streaming for controlled service environments.

**Before this concept:** Internal services hand-maintained clients, parsed loosely defined JSON, and discovered breaking contract changes at runtime.

❌ **Wrong example:** Expose gRPC directly to every browser and third-party client without considering proxy support, debuggability, or compatibility.

✅ **After applying the concept:** Define protobuf contracts, generate clients, preserve field compatibility, and use deadlines and cancellation on internal calls.

**How it works now:** Services share typed contracts and efficient transport, while public boundaries can remain REST when accessibility matters more.

**Answer:** gRPC is strong for controlled service-to-service environments needing schema-first contracts, generated clients, efficient binary messages, deadlines, and streaming. REST remains attractive for public APIs, browser reach, human debuggability, and HTTP ecosystem compatibility.

**Example:** An internal inference service exposes bidirectional streaming over gRPC. The public developer API remains REST and translates at the boundary.

**Pitfalls:** Plan protobuf field evolution, propagate deadlines and cancellation, cap message sizes, configure load balancing for long-lived HTTP/2 connections, and avoid automatic retries for unsafe operations.

#### Practical walkthrough — gRPC vs REST: call an internal pricing service

##### Before choosing

An internal high-throughput service sends verbose JSON/HTTP calls with hand-written client contracts and weak streaming support. Or a public browser API uses gRPC directly and struggles with browser/proxy support and debugging ergonomics.

##### After choosing by boundary

Use gRPC for controlled internal service-to-service calls needing typed contracts, efficient binary messages, streaming, deadlines, and generated clients. Use REST/JSON for broad public/browser compatibility, simple resource APIs, caches, and human-readable integration. gRPC-Web may bridge browsers but is not identical to native gRPC.

**What changed:** wire protocol follows audience and operational needs. Both require versioning, auth, rate limits, observability, and failure/cancellation design.

**Practice:** create a protobuf evolution plan that adds an optional field without breaking old clients, then state how REST would version the same change.

---

### Q20. SQL or NoSQL: how should an interviewer answer?

**In simple words:** SQL databases are strong at relationships, flexible queries, and transactions. “NoSQL” covers several non-relational database types optimized for particular data shapes or scale patterns. Neither is universally faster or more scalable.

**Everyday analogy:** A spreadsheet-like register is useful when rows relate and rules matter. A wall of labeled storage boxes may make one known lookup extremely fast but is less flexible for unexpected questions.

**What problem does this concept solve?** It chooses storage based on invariants, relationships, query patterns, partitioning, and operational needs rather than labels.

**Before this concept:** Teams selected NoSQL because they expected scale or SQL because it was familiar, without testing the real access pattern.

❌ **Wrong example:** Claim that NoSQL has no schema and always scales, or that relational databases cannot shard or handle large workloads.

✅ **After applying the concept:** Start with required transactions and queries, identify a viable partition key, and choose the simplest database that meets measured constraints.

**How it works now:** The storage decision is evidence-based, and its consistency, scaling, and query limitations are acknowledged before implementation.

**Answer:** Reject the false binary. Ask about transactions, relationships, query flexibility, consistency, data volume, partition key, hot keys, and operational maturity.

**Example:** A reservation system starts with PostgreSQL because unique constraints and transactions protect inventory. A massive telemetry stream uses a wide-column store partitioned by device and time because queries are known and writes dominate.

**Strong answer:** Name the exact reason a relational database stops meeting requirements before introducing NoSQL. Many systems scale further with indexing, replicas, partitioning, and caching than candidates assume.

#### Practical walkthrough — SQL versus NoSQL: defend a database decision

##### Before the false binary

An interviewer asks SQL or NoSQL, and the answer is “NoSQL scales” or “SQL is safe.” The design ignores transaction rules, query patterns, index needs, and operational capability.

##### After a defensible decision

Start with data relationships, invariants, reads/writes, latency, volume, availability, and team skill. Choose relational SQL for orders/money/inventory with transactions and joins; document/key-value/wide-column stores for compatible access patterns and scale; search/analytics stores for their specific workloads. It is normal to use multiple systems, but each adds consistency and operations work.

**What changed:** database choice becomes evidence-based. SQL systems also scale; NoSQL systems also have constraints, indexes, and consistency trade-offs.

**Practice:** answer with a table of `entity -> access pattern -> invariant -> store -> why`, not a slogan.

---

### Q21. When should work go through a message queue?

**In simple words:** A message queue lets one part of a system leave work for another part to process later. It helps absorb traffic bursts and prevents users from waiting for slow background tasks.

**Everyday analogy:** A restaurant server places tickets on the kitchen rail. The server can help the next customer while cooks process tickets at a sustainable rate.

**What problem does this concept solve?** It decouples request handling from slower work, buffers bursts, and provides durable retry and ownership transfer.

**Before this concept:** User requests waited for email, reporting, or provider calls, and traffic spikes directly overloaded every downstream dependency.

❌ **Wrong example:** Enqueue a message before the business transaction commits, acknowledge it before side effects finish, and assume delivery occurs exactly once.

✅ **After applying the concept:** Commit an outbox record with business state, publish durably, and let idempotent consumers acknowledge only after successful processing.

**How it works now:** Users receive a fast durable acceptance, workers scale separately, bursts become queue depth, and failed work follows bounded retry and dead-letter policy.

**Answer:** Use a queue when producers should not wait for work completion, bursts must be buffered, consumers need independent scaling, or retries require durable ownership transfer.

**Example:** Checkout commits an order and outbox record, then returns. Workers consume the event to send email and reserve fulfillment capacity. A consumer acknowledges only after its durable side effect succeeds.

**Design checklist:** Define ordering scope, delivery guarantee, visibility timeout, retry classification, exponential backoff, dead-letter handling, idempotency, backpressure, retention, and replay.

#### Practical walkthrough — Message queue: move a report off the request path

##### Before the pattern

`POST /reports` generates a PDF synchronously. It consumes a web thread for minutes, fails when the caller disconnects, and crashes lose work. Or the request starts a fire-and-forget in-memory task that disappears on restart.

##### After the pattern

The API validates, stores durable job state, emits a message/outbox record, and returns `202` with a status URL. Workers consume independently, scale with backlog, retry safely, and send poison jobs to DLQ. Users see Pending/Running/Succeeded/Failed state.

**What changed:** request and work lifetimes separate. A queue is not a cure for any operation: immediate validation, synchronous authorization, and actions whose result is required now remain in the request path.

**Practice:** define the idempotency key, visibility timeout, retry schedule, user status response, and DLQ owner for an export job.

---

### Q22. How do services discover healthy instances?

**In simple words:** Application copies start, stop, move, and fail. Service discovery keeps track of where healthy copies are so callers do not use hard-coded machine addresses.

**Everyday analogy:** A current company directory tells you which support agent is working and how to reach them instead of relying on an old personal phone number.

**What problem does this concept solve?** It connects callers to current healthy instances despite deployments, failures, scaling, and address changes.

**Before this concept:** Services stored fixed IP addresses in configuration. Scaling required manual edits, and failed instances remained targeted.

❌ **Wrong example:** Query the discovery control plane for every request and provide no cached endpoints if that control plane is temporarily unavailable.

✅ **After applying the concept:** Instances register or appear through platform endpoints, health removes bad targets, and clients or proxies balance across a bounded-stale local view.

**How it works now:** The data plane continues using known healthy endpoints during brief control-plane issues and naturally follows instance changes.

**Answer:** With client-side discovery, the client queries a registry and load-balances. With server-side discovery, a proxy or platform selects the instance. DNS discovery is simple but constrained by caching and record-update behavior.

**Example:** Kubernetes services provide stable virtual addresses while endpoints track ready pods. A zone-aware proxy prefers local healthy instances and fails over only when capacity is insufficient.

**Failure considerations:** Registrations need leases or health checks, clients need bounded-stale caches, and the control plane must not be required for every data-plane request.

#### Practical walkthrough — Service discovery: replace hard-coded service IPs

##### Before the pattern

Checkout has a configuration list of payment-service IP addresses. Deployments change pods/VMs, stale addresses remain, and every client needs a release to learn new instances.

##### After the pattern

Instances register readiness/lease information with a registry/platform. Clients use a stable service DNS name, or a proxy/load balancer resolves healthy endpoints. Caches are bounded-stale so control-plane issues do not instantly break all data-plane requests.

**What changed:** membership becomes dynamic while clients use stable logical names. Discovery answers “where”; health checks/outlier detection answer “should I send traffic now?”

**Practice:** outline what happens when an instance starts, becomes ready, loses database access, crashes, and is replaced.

---

### Q23. How does pub/sub differ from a work queue?

**In simple words:** In a work queue, one available worker handles each task. In publish/subscribe, several interested groups each receive their own copy of an event.

**Everyday analogy:** A restaurant ticket is taken by one cook. A school announcement is delivered separately to teachers, students, transport staff, and parents.

**What problem does this concept solve?** It distinguishes distributing one unit of work from broadcasting one fact to several independent consumers.

**Before this concept:** Producers directly called every downstream service or placed events on one competing queue where only one interested system received them.

❌ **Wrong example:** Put `OrderPlaced` on a single work queue and expect inventory, analytics, notifications, and fraud services all to receive it.

✅ **After applying the concept:** Publish the event to a topic with one durable subscription per consumer purpose; scale workers inside each subscription.

**How it works now:** The producer remains independent, every interested capability receives the event, and each subscription manages its own lag, retry, and replay.

**Answer:** A work queue distributes each job to one worker in a competing consumer group. Pub/sub delivers each event to multiple independent subscriptions; each subscription may itself use a consumer group.

**Example:** `OrderPlaced` is published once. Inventory, fraud, analytics, and notification subscriptions each receive it. Notification has ten workers, but only one of those workers processes a given message for that subscription.

**Trade-off:** Pub/sub reduces producer coupling but makes schema governance, consumer lag, duplicate handling, replay, and event ownership essential.

#### Practical walkthrough — Pub/sub and work queue: react to an order

##### Before the concept

`OrderPlaced` goes to one queue. Inventory consumes it, so notification, fraud, and analytics never see it. Alternatively, the order service calls all four synchronously and becomes coupled to their availability.

##### After the concept

Publish `OrderPlaced` to a topic. Each business purpose owns a durable subscription; within a subscription, competing consumers scale processing of that one purpose.

```text
OrderPlaced topic -> Inventory subscription -> worker group
                  -> Fraud subscription -> worker group
                  -> Notification subscription -> worker group
```

**What changed:** one fact reaches independent consumers, each with its own retry/lag/replay. Commands such as `ReserveInventory` target a single responsible owner; events describe facts others may react to.

**Practice:** decide which consumers must complete before the customer sees confirmation and which may lag, then design their failure behavior.

---

### Q24. How should database connection pools be sized?

**In simple words:** Opening a database connection is expensive, so applications reuse a limited pool. Too few connections make requests wait; too many can overwhelm the database.

**Everyday analogy:** A warehouse owns a limited number of loading bays. Reusing them is efficient, but building more trucks than available bays only creates a traffic jam.

**What problem does this concept solve?** It reuses expensive connections while placing a hard concurrency boundary in front of the database.

**Before this concept:** Applications opened a new connection per operation or gave every instance a huge pool, causing connection churn or database exhaustion.

❌ **Wrong example:** Set every one of 100 application instances to a pool size of 100 when the database safely supports only 500 total connections.

✅ **After applying the concept:** Budget total database capacity across instances, use short acquisition timeouts, and apply backpressure before saturation.

**How it works now:** Connections are efficiently reused, overload appears as controlled queueing or rejection, and autoscaling cannot silently multiply past database limits.

**Answer:** A pool is a concurrency limit, not a performance knob to maximize. Bound total connections below database capacity and leave room for administration, migrations, replicas, and failover.

**Example:** If a database safely supports 300 application connections and 20 service instances run, a starting maximum might be near 10-12 per instance rather than 100. Load tests then measure queue time, query latency, CPU, locks, and timeouts.

**Failure handling:** Use short acquisition timeouts, release connections in `finally`, validate stale connections, avoid long transactions, and add backpressure. Autoscaling application instances without adjusting pool math can overwhelm the database.

#### Practical walkthrough — Connection pools: autoscale without crushing the database

##### Before the concept

Twenty app instances each allow 100 database connections because the default seemed safe. A scale-out creates 2,000 potential connections against a database that safely handles 300. CPU, context switching, locks, and latency spike; timeouts cascade.

##### After the concept

Budget connection capacity globally: reserve room for admin/failover, then divide an intentional pool size across instances. Use short acquisition timeouts, short transactions, backpressure, and load tests. Autoscaling must account for the downstream database, not only web CPU.

**What changed:** a pool becomes a concurrency boundary. More connections do not make a slow query faster; query/index efficiency and workload isolation often matter more.

**Practice:** calculate a starting pool size for 300 safe connections, 20 instances, and 60 reserved connections; explain what happens if instances scale to 40.

---

### Q25. Why use consistent hashing instead of `hash(key) % nodeCount`?

**In simple words:** Consistent hashing decides which server owns each key while avoiding a massive reshuffle when servers are added or removed.

**Everyday analogy:** Imagine assigning homes to nearby post offices on a circular map. Opening one new post office changes only the surrounding neighborhood instead of changing every home's assigned office.

**What problem does this concept solve?** It minimizes key movement when cache or storage nodes join and leave.

**Before this concept:** Modulo hashing remapped most keys whenever the node count changed, causing mass cache misses or expensive data movement.

❌ **Wrong example:** Use `hash(key) % servers.length`, add one server during peak traffic, and trigger nearly every cached key to move at once.

✅ **After applying the concept:** Place keys and virtual nodes on a ring or use rendezvous hashing so membership changes affect only a limited share of keys.

**How it works now:** Scaling or failure causes bounded redistribution, while replicas, failure domains, and hot-key controls handle concerns hashing alone does not solve.

**Answer:** Modulo hashing remaps most keys whenever the node count changes. Consistent hashing places nodes and keys on a ring; adding or removing a node moves mainly the neighboring ranges.

**Example:** A cache cluster assigns many virtual nodes to each physical server for even distribution. Replicas are placed on the next distinct failure-domain nodes, and weighted virtual-node counts reflect unequal capacity.

**Trade-off:** Consistent hashing reduces remapping but does not automatically solve hot keys, replication, membership consensus, or overloaded replacement nodes. Rendezvous hashing is often a simpler alternative with similar minimal-movement properties.

#### Practical walkthrough — Consistent hashing: add a cache node without a miss storm

##### Before the pattern

Cache ownership is `hash(key) % nodeCount`. Growing from four to five nodes remaps most keys, so caches miss together and the database receives a sudden herd of reads.

##### After the pattern

Place nodes and keys on a ring (or use rendezvous hashing). Each key chooses a nearby/highest-scoring node; adding a node moves only a bounded share. Virtual nodes/weights smooth uneven capacity; replicas use different failure domains.

**What changed:** membership changes preserve most assignments. Consistent hashing does not solve hot keys, membership truth, cache stampedes, or durability—pair it with replication, single-flight, and health-aware routing where needed.

**Practice:** map ten keys to three nodes, add one node, and count moved keys; then compare with modulo hashing.

---

### Rapid Self-Test

For every concept above, answer these five prompts:

1. What problem does it solve?
2. When should it not be used?
3. What fails first at 10× scale?
4. What state or invariant must remain correct during retries?
5. Which metric proves the design is working?

---
