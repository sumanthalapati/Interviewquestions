# System Design Interview Guide

Complete framework for acing system design interviews. Covers interview strategies, frameworks, common questions, and preparation tips.

---

## Table of Contents
1. [Interview Framework](#framework)
2. [Behavioral Interview Guide](#behavioral)
3. [Mobile System Design](#mobile)
4. [Common Interview Questions](#common)
5. [Design Patterns](#patterns)
6. [Scaling Strategies](#scaling)
7. [Trade-offs Cheatsheet](#tradeoffs)
8. [Resume Tips](#resume)
9. [Interview Do's & Don'ts](#dos-donts)
10. [Post-Interview](#post-interview)

---

## Interview Framework {#framework}

### 5-Minute Breakdown

**Minute 0-1: Clarify Requirements**
- Ask what scale (1M users? 1B?)
- What region (global? single datacenter?)
- What features (MVP only, or advanced?)
- What's the bottleneck (latency, throughput, cost)?

**Minute 1-3: High-Level Design**
- Draw boxes (client, LB, servers, DB, cache, CDN)
- Dataflow (how data moves through system)
- Database choice (SQL? NoSQL?)
- Key components (APIs, services, databases)

**Minute 3-4: Deep Dive (pick one)**
- Database: sharding, replication, indexing
- Caching: cache layers, invalidation, TTL
- Real-time: WebSocket, messaging, events
- Scale: load balancing, horizontal scaling

**Minute 4-5: Discussion**
- Trade-offs (consistency vs availability?)
- Costs (AWS bill estimation?)
- Failure scenarios (what breaks and how to handle?)
- Alternative approaches (why choose this over that?)

### High-Level Design Template

```
[Clients (Web, Mobile)]
         ↓
[API Gateway / Load Balancer]
         ↓
[Web Servers (Stateless)]
    ↙  ↓  ↘
[Cache] [DB] [Queue]
         ↓
[Async Workers]
         ↓
[S3 / CDN for static]
```

### Key Questions to Ask

1. **Scale**: DAU (Daily Active Users), QPS (Queries Per Second), storage size
2. **Region**: Single datacenter or global?
3. **Features**: MVP or advanced (real-time, recommendations)?
4. **Consistency**: Strong or eventual?
5. **Cost**: Budget constraints?

---

## Behavioral Interview Guide {#behavioral}

### Common Behavioral Questions

**"Tell me about a time you faced a difficult technical problem."**
- Structure: Situation → Challenge → Action → Result (STAR)
- Example: "At Company X, we had slow search (1s latency). I investigated and found N+1 queries. Added caching (Redis), reduced to 100ms. Improved UX, reduced server load 50%."

**"Describe a time you disagreed with a teammate."**
- Structure: Situation → Communication → Resolution → Outcome
- Example: "Engineer A wanted monolith, Engineer B wanted microservices. I facilitated discussion, presented trade-offs with data. We compromised: microservices for new features, monolith for existing."

**"How do you approach learning new technologies?"**
- Answer: Build project, read docs, experiments, teach others. Example: "Learned Kubernetes by deploying app to EKS, debugging issues, wrote blog post."

**"Tell me about a time you led a project."**
- Focus on impact, decision-making, team coordination. Example: "Led migration from MongoDB to PostgreSQL. Coordinated with team, scheduled migration, monitored rollback plan. Zero downtime, 30% query speed improvement."

**"What was a mistake you made?"**
- Be honest. Explain what you learned. Example: "Skipped performance testing. Deployed to prod, had slow query. Learned to always test scale. Now I benchmark before deploy."

### STAR Method

**S - Situation**: Set the scene (company, project, challenge)
**T - Task**: What was the problem?
**A - Action**: What did you do specifically?
**R - Result**: What was the outcome? (quantify if possible)

### Tips

- Prepare 3-5 stories covering: leadership, conflict, learning, failure, scale
- Quantify results (30% faster, saved $50k, reduced latency from 1s to 100ms)
- Keep stories to 2 minutes
- Relate stories to job role

---

## Mobile System Design {#mobile}

### Unique Challenges

**Offline-First**: Sync when reconnected. Local cache, eventual consistency.

**Battery**: Minimize requests, avoid polling, use push notifications instead.

**Network**: Unreliable connection (LTE, WiFi dropout). Retry logic, timeout handling.

**Storage**: Limited disk space. Aggressive caching policies. Compression.

**CPU**: Limited processor. Offload heavy computation to server.

### Design Patterns

**Request Batching**: Combine multiple requests into single API call. Reduce request overhead.

**Incremental Sync**: Download only changed data. Timestamps, checksums.

**Progressive Loading**: Show cached data, update with fresh data. Skeleton screens.

**Compression**: Gzip responses. Protobuf instead of JSON.

**Pagination**: Don't load all data. Load on scroll (infinite scroll).

### Example: Chat App

```
[Mobile Client]
   ↓ (messages queued locally)
[Sync Service] (batch + retry)
   ↓
[API Server]
   ↓
[Message Queue]
   ↓
[Database]
```

Local persistence: Messages stored on device. On send → added to queue. Network → synced to server. Conflict (user offline) → merge changes on reconnect.

### Q&A

**Q: How to handle offline-first synchronization?**
- A: Store in local DB (SQLite, Realm). When online → sync to server. Track version numbers (timestamp, vector clock). Conflict resolution: server wins, or merge.

**Q: How to minimize battery drain?**
- A: Batch requests (don't make 100 small requests). Use push notifications (don't poll). Reduce network radio on time. Compress responses.

**Q: How to handle slow network?**
- A: Progressive loading (skeleton screens). Show cached data. Request timeout + retry. Smaller payloads (compression, smaller images).

### Right vs Wrong Usage

**✅ Right**: Offline caching for documents (Google Docs offline). Incremental sync for feed. Compression for slow networks.

**❌ Wrong**: Don't assume network always available. Don't poll for real-time (battery drain). Don't send uncompressed large payloads. Don't ignore local persistence failures.

---

## Common Interview Questions {#common}

### Tier 1 (Easy, 20 minutes)

**1. URL Shortener (Bit.ly)**
```
Requirements:
- Convert long URL to short code
- 1M new URLs/day
- 100M hits/day

High-level:
[URL] → [Hash/Generator] → [Unique 6-char code] → [Redirect API]
[API Server] → [Database] → [Cache]

Key: Unique short codes (collision handling), redirect performance
```

**2. Pastebin**
```
Requirements:
- Paste code snippets, share via link
- 1M pastes/day
- 10M reads/day

High-level:
[Paste Editor] → [API] → [Database] (store content)
[Cache] (hot pastes)
[CDN] (static assets)

Key: Content storage (large blobs), read-heavy caching, URL shortening
```

### Tier 2 (Medium, 30 minutes)

**3. Design Tiny URL**
```
Requirements: (same as URL Shortener but deeper)

Issues to dive into:
- How to generate unique short codes (random, hash, counter)?
- Collision handling
- Database sharding (1B+ mappings)
- Cache strategy (redirect is read-heavy)
- Traffic spikes (trending URL)
```

**4. Design Uber**
```
Requirements:
- Find nearby drivers
- Match riders to drivers
- Calculate ETA
- Payment processing

High-level:
[Mobile Client] → [API] → [Location Service] (geo-sharding) → [Driver Service]
[Matching Service] (ML model)
[ETA Service] (precomputed graph)
[Payment Service] (idempotent)

Key: Real-time geo, matching algorithm, payment idempotency
```

### Tier 3 (Hard, 45+ minutes)

**5. Design Netflix**
```
Requirements:
- 200M users, 1B hours watched/day
- Video encoding, encoding, recommendation, viewing
- Regional CDNs

High-level:
[Web] → [API] → [Video Service] (CDN delivery)
[Recommendation Engine] (ML, personalization)
[Analytics] (what users watch)
[Encoding Pipeline] (asynchronous)

Key: CDN strategy, recommendation, video encoding at scale
```

**6. Design Facebook**
```
Requirements:
- 3B users, 5M posts/day, real-time feed
- Followers (1-10M per user)
- Live video streaming

High-level:
[Post] → [Feed Service] (fan-out to followers)
[Cache Layer] (pre-computed feeds)
[Real-time] (WebSocket for notifications)
[Live Video] (CDN, RTMP, HLS)

Key: Feed generation (fan-out on write), cache invalidation, real-time at scale
```

---

## Design Patterns {#patterns}

### Caching Patterns

**Cache-Aside (Lazy Loading)**
```
1. Check cache
2. If miss → load from DB
3. Store in cache
```
Best for: general queries

**Write-Through**
```
1. Write to cache AND database
2. Return
```
Best for: consistency critical

**Write-Behind**
```
1. Write to cache
2. Async write to DB
3. Return immediately
```
Best for: high throughput

### Data Patterns

**Denormalization**: Duplicate data across tables for faster reads. Cost: consistency on updates.

**Sharding**: Split data by key (user_id % 1000). Scale: unlimited horizontal. Cost: complex queries.

**Replication**: Copy data across servers. Read scaling. Cost: consistency, storage.

**Partitioning**: Split by date/range. Cost: uneven distribution.

### Architectural Patterns

**Microservices**: Independent services, deploy separately. Cost: distributed systems complexity.

**Monolith**: Single codebase. Simpler, limited scale.

**Event-Driven**: Services communicate via events (queue, pub/sub). Loose coupling, async.

---

## Scaling Strategies {#scaling}

### Vertical Scaling
- Add CPU, RAM to single server
- Cost: 2x CPU = 2x cost
- Limit: physics (can only add so much)
- Use: Database, caching layer

### Horizontal Scaling
- Add more servers
- Cost: 2x servers = 2x cost (but easier)
- Limit: None
- Use: Stateless services (web servers, APIs)

### Database Scaling

**Replication**: Master-slave (reads from slave, writes to master)
```
[Master] ← writes
  ↓ (replication)
[Slave] ← reads
```
Cost: Consistency (slave lags)

**Sharding**: Split by key (hash, range)
```
[User 1-1M] → [Shard 1]
[User 1M-2M] → [Shard 2]
```
Cost: Complex queries (cross-shard joins)

### Caching Scaling

**Multi-layer caching**:
```
[L1 - App memory] (fastest, small)
    ↓ miss
[L2 - Redis] (medium speed, medium size)
    ↓ miss
[L3 - Database] (slowest, largest)
```

### API Scaling

**Rate limiting**: Limit requests per second. Prevents abuse, protects infrastructure.

**Load balancing**: Distribute traffic across servers. Avoid single server bottleneck.

**CDN**: Cache static content at edge. Reduces latency globally.

---

## Trade-offs Cheatsheet {#tradeoffs}

### Consistency vs Availability

| Scenario | Choice | Why |
|----------|--------|-----|
| Banking | Strong consistency | Can't lose money |
| Social media | Eventual consistency | Can tolerate stale feed |
| Real-time analytics | Causal consistency | Events have order |

### Latency vs Consistency

| Scenario | Choice | Why |
|----------|--------|-----|
| Web server | < 100ms | User UX |
| Batch analytics | Hours OK | Accuracy over speed |
| Real-time | < 1s | Live experience |

### Cost vs Performance

| Scenario | Choice | Why |
|----------|--------|-----|
| Startup | Vertical scale | Simpler initially |
| Scale-up | Horizontal scale | Cost-effective growth |
| Critical | Premium hardware | Can't afford downtime |

### Storage vs Computation

| Scenario | Choice | Why |
|----------|--------|-----|
| Analytics | Store everything | Recomputation expensive |
| Real-time | Compute on-the-fly | Storage expensive at scale |

---

## Resume Tips {#resume}

### What to Include

**Quantifiable Metrics**
- "Reduced latency from 1s to 100ms" (not just "optimized")
- "Scaled to 10M users" (not just "handled growth")
- "Cut costs 30%" (not just "cost optimization")

**Technical Specifics**
- Tech stack: "Node.js, PostgreSQL, Redis, AWS"
- Patterns: "implemented microservices, sharding, caching"
- Scale: "1M QPS, 100 billion records, 99.99% uptime"

**Impact**
- Business impact: "revenue increased, user retention improved"
- Technical impact: "reduced incidents 50%, improved performance"

### Example Bullet Points

❌ Bad: "Worked on backend system"
✅ Good: "Designed and deployed horizontally-scaled microservices on Kubernetes, reducing latency 60% and handling 10x growth (1M → 10M QPS) with zero downtime migrations"

❌ Bad: "Optimized database queries"
✅ Good: "Optimized N+1 queries via strategic indexing and caching, reducing p99 latency from 5s to 200ms for feed service (100M users)"

❌ Bad: "Implemented caching"
✅ Good: "Implemented multi-layer caching (Redis) with TTL-based invalidation, reducing DB load 70% and improving feed generation latency from 2s to 100ms"

---

## Interview Do's & Don'ts {#dos-donts}

### DO's ✅

- **Ask clarifying questions** (scale, region, consistency requirements)
- **Think out loud** (explain your reasoning as you design)
- **Draw diagrams** (pictures > words)
- **Discuss trade-offs** ("If we choose X, we sacrifice Y")
- **Mention monitoring** (how will we know if it works?)
- **Suggest improvements** ("At scale, we might shard the database")
- **Walk through example** (trace a user request end-to-end)

### DON'Ts ❌

- **Jump to solution** (clarify first)
- **Stay silent** (communicate constantly)
- **Over-engineer** (start simple, scale as needed)
- **Ignore failure scenarios** ("What if DB goes down?")
- **Forget about cost** ("What's the AWS bill?")
- **Pick wrong tool** ("SQL for unstructured data?")
- **Assume infinite resources** (mention constraints)

### Common Mistakes

1. **Not clarifying requirements**: Assume scale, region, features wrong
2. **Monolithic design**: Avoid sharding, replication from start
3. **Ignoring CAP theorem**: Promise impossible guarantees (all three)
4. **Forgetting about ops**: No monitoring, alerting, graceful degradation
5. **Complex design upfront**: Over-engineer initially

### Saving a Bad Interview

- Stuck? Admit it: "I'm thinking about this. Let me approach differently."
- Interviewer skeptical? Ask: "What would concern you about this approach?"
- Running out of time? Summarize: "At scale, we'd shard by user_id, replicate for resilience, cache hot data."

---

## Post-Interview {#post-interview}

### Immediately After

- Thank interviewer
- Ask about next steps
- Send follow-up email within 24 hours

### If You Bomb

- Don't get discouraged (even good engineers struggle)
- Ask for feedback (specific weak areas)
- Study those weak areas
- Try again (different company or re-interview)

### If You Ace It

- Prepare for next round (behavioral, coding)
- Learn from successful approach
- Help others (teach designs)

### Follow-up Email

```
Subject: Thank you for the System Design Interview

Hi [Name],

Thank you for taking the time to interview me today about designing [system]. I enjoyed discussing the trade-offs between [specific tradeoff] and how we'd handle [specific challenge].

I'd love to continue the conversation about [specific topic from interview]. If you have any questions or need clarification on my design, please let me know.

Best,
[Your Name]
```

---

## Quick Reference: Interview Checklist

### Before Interview
- [ ] Understand scale (users, QPS, storage)
- [ ] Know common patterns (caching, sharding, replication)
- [ ] Practice explaining trade-offs
- [ ] Have 3-5 real examples from work
- [ ] Know basic algorithms (hashing, sorting)

### During Interview
- [ ] Ask clarifying questions (don't assume)
- [ ] Start with high-level design
- [ ] Draw diagrams (client → LB → servers → DB → cache)
- [ ] Discuss one component deeply (cache, DB, real-time)
- [ ] Address failure scenarios
- [ ] Think out loud (interviewer wants to see your thinking)
- [ ] Suggest improvements (shard at scale, replicate for resilience)

### Common High-Level Components
```
[User] → [CDN/Static]
         [API Gateway / Load Balancer]
         [Stateless Servers]
         [Cache (Redis)]
         [Database (SQL/NoSQL)]
         [Message Queue]
         [Async Workers]
         [Search (Elasticsearch)]
         [Analytics (Snowflake)]
```

### Top 10 Interview Questions (by frequency)
1. Design URL Shortener
2. Design Chat System / Messenger
3. Design Social Media Feed (Twitter, Instagram)
4. Design YouTube / Video Streaming
5. Design Uber (Ride Sharing)
6. Design Grocery Delivery (Instacart)
7. Design Cache System (Memcached)
8. Design Rate Limiter
9. Design Search Engine
10. Design Payment System

---

**Key Takeaway**: System design interviews test your ability to think at scale. Start simple, ask questions, explain trade-offs, and think out loud. It's a conversation, not a test.
