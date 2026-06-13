# Real-Time & Collaborative Systems Design

Deep dive into real-time systems and collaborative editing. Covers Stock Exchange, Google Docs, Real-time Leaderboard, and related patterns.

---

## Table of Contents
1. [Stock Exchange Architecture](#stock-exchange)
2. [Google Docs Collaborative Editing](#google-docs)
3. [Real-Time Leaderboard](#leaderboard)
4. [Collaborative Editing Patterns](#collab-patterns)
5. [Real-Time Architecture](#realtime-arch)
6. [Consistency in Real-Time Systems](#realtime-consistency)
7. [Case Studies & Trade-offs](#case-studies)

---

## Stock Exchange Architecture {#stock-exchange}

### Problem Statement

Stock exchange must:
- Handle millions of orders per second
- Execute trades in microseconds (faster = better prices)
- Maintain strict ordering (fairness: first-in-first-out)
- Prevent double-execution (consistency critical)
- Handle failures without data loss

### Architecture Overview

```
[Traders (brokers)] → [Order Router] → [Order Book] → [Matching Engine]
                                            ↓
                                   [Settlement]
                                   [Ledger]
```

### Key Components

**Order Router**
```
Purpose: Receive orders from thousands of brokers

Requirements:
- Ultra-low latency (< 1ms per order)
- High throughput (1M orders/second)
- Never drop orders

Implementation:
- Hardware acceleration (FPGAs, custom ASICs)
- Direct connections (fixed TCP, not HTTP)
- Multiple parallel feeds (redundancy)
- Serialization: Binary, not JSON (smaller, faster)

Example latency budget:
- Network transit: 100µs
- Parsing: 10µs
- Router processing: 100µs
- Total: 210µs (sub-millisecond)
```

**Order Book**
```
Maintains current orders waiting to execute:
- Buy side: Orders to buy at various prices
- Sell side: Orders to sell at various prices

Structure (efficient):
- Tree structure (price-ordered, fast lookups)
- Each price level: Queue of orders (FIFO)

Example:
Buy Orders          Sell Orders
$100: [O1, O2, O3]  $101: [O4]
$99:  [O5]          $102: [O6, O7]
$98:  [O8]

Matching rule: Buy at $100 meets Sell at $101
No match (buy price < sell price)
If new sell comes at $100, executes against buy orders
```

**Matching Engine**
```
Purpose: Match buy and sell orders

Algorithm:
1. New order arrives
2. Check if it matches existing orders on opposite side
3. Execute trades (highest buyer price vs lowest seller price)
4. Update ledger

Example matching:
New order: Sell 100 shares at $99
Current buy orders:
  - $100: Buy 50 shares (EXECUTE 50)
  - $99: Buy 30 shares (EXECUTE 30)
  - $98: Buy 20 shares (no match, price too low)

Result: 80 shares executed, 20 shares remain on sell order book at $99
```

**Ledger (Settlement)**
```
Records all trades (immutable, authoritative)

Entry:
{
  trade_id: 12345,
  buyer: "Broker A",
  seller: "Broker B",
  symbol: "AAPL",
  quantity: 50,
  price: $100,
  timestamp: 2024-01-15 09:30:15.123456,
  status: "settled"
}

Requirements:
- Immutable (can't change once recorded)
- Atomic (partial settlement not allowed)
- Versioned (can't lose history)
- Replicated (backup copies)

Implementation:
- Event log (append-only)
- Replication (2-phase commit to backup)
- Checkpoints (snapshots for recovery)
```

### Handling High Concurrency

**Sequential Matching**
```
Problem: Two orders arrive simultaneously
- Order A: Buy 100 at $100
- Order B: Sell 100 at $99

Both see same order book state. If both execute, double-execution!

Solution: Single-threaded matching engine
- All orders serialized (one at a time)
- Maintains fairness (FIFO)
- Eliminates race conditions

Cost: Throughput bottleneck (single CPU core limited)

Throughput limits:
- Single core: ~1M orders/sec (modern CPUs)
- 10 cores: 10M orders/sec (sharded)
- Problem: Latency (orders must wait in queue)

Solution: Sharding
- Shard by symbol (AAPL orders to shard 1, TSLA to shard 2)
- Each shard single-threaded (preserves fairness)
- Parallel processing (10 shards = 10x throughput)
```

**Disruptor Pattern (High-Performance Queue)**
```
Traditional queue: Thread-safe but slow (locks, context switches)

Disruptor (LMAX exchange open-source):
- Ring buffer (fixed size, pre-allocated memory)
- Single writer (one thread adds orders)
- Single reader (one thread matches orders)
- Lock-free (atomic operations, no mutex)

Latency: 1-5 microseconds (vs 100-1000µs for traditional queue)

Implementation:
```
Order -> [Ring Buffer] -> Disruptor -> Matching -> Ledger
         (producer)      (consumer)
```

### Failure Scenarios

**Node Crash**
```
Matching engine crashes mid-trade

Recovery:
1. Detect crash (health check timeout)
2. Promote backup matching engine (hot standby)
3. Read last checkpoint from ledger
4. Replay orders since checkpoint
5. Resume matching

Time to recover: Milliseconds (acceptable, markets brief halt)
```

**Network Partition**
```
Problem: Order reaches matching engine but not ledger

Solution: 2-phase commit
1. Matching engine: "About to execute trade 12345"
2. Ledger: "OK to proceed" (acknowledged)
3. Matching engine: "Executing trade 12345"
4. Ledger: "Trade committed"

If step 2 fails: Abort (don't execute)
If step 4 fails: Ledger already has it (replayed on recovery)
```

### Q&A

**Q: Why is ultra-low latency important in stock trading?**
- A: Faster order execution = better prices. If your trade executes 1ms faster, you get better fills (microsecond advantage). At scale (100M trades/day), that's millions in saved costs.

**Q: How do exchanges handle flash crashes?**
- A: Circuit breakers (halt trading if large swing). Rollback unsafe trades. Replay audit log. Manual intervention by exchanges.

**Q: Can retail traders compete with high-frequency traders?**
- A: No. HFT firms have:
  - Direct connections (< 1ms latency)
  - Custom hardware (microsecond latency)
  - Colocation (servers in same datacenter as exchange)
  - Retail: Browser-based (hundreds of ms latency)
  Retail 100ms behind (HFT arbitrages this gap).

---

## Google Docs Collaborative Editing {#google-docs}

### Problem Statement

Google Docs must support:
- Multiple users editing simultaneously
- Changes visible to all users in real-time (< 1 second)
- No data loss (even with network partitions)
- Conflict resolution (two users edit same sentence)
- Works offline (changes sync when online)

### Challenge: Operational Transformation (OT) vs CRDT

**Operational Transformation (Google's approach)**
```
Idea: Track operations (insert, delete, format)
      Apply transformations to handle conflicts

Example:
User A: Inserts "Hello" at position 0
User B: Inserts "Hi" at position 0

Naive result: "HiHello" or "HelloHi" (depends on order)

OT solution:
- Track both operations with IDs (A1, B1)
- When order known (A1 before B1):
  - A1: Insert "Hello" at 0 → "Hello"
  - B1: Insert "Hi" at 0 → "HiHello" (position adjusted: 0 → 5)
  
Final: "HiHello" (deterministic, both clients converge)

Pros: Simpler (fewer states to track)
Cons: Complex transformation rules, version vectors needed
```

**CRDT (Conflict-free Replicated Data Type)**
```
Idea: Assign unique ID to each character
      Merge changes without coordination

Example:
User A: Insert "H" (id: A1), Insert "i" (id: A2)
User B: Insert "H" (id: B1), Insert "i" (id: B2)

Characters have unique IDs (by user + sequence):
- A1: "H", B1: "H", A2: "i", B2: "i"

Merge rule: Sort by (user_id, sequence)
Result: "HiHi" (users see each other's chars, no conflicts)

Pros: Simple merge, deterministic, offline-friendly
Cons: More state (track all chars ever), overhead

Google Docs likely uses hybrid: OT + some CRDT ideas
```

### Google Docs Architecture

```
[Client] → [local buffer] → [network] → [Server] → [Ledger]
   ↓
[Offline DB (IndexedDB)]
```

### Real-Time Sync Process

**Write Flow**
```
1. User types "Hello"
2. Generate operation: Insert("Hello", position=0)
3. Store locally (IndexedDB) - immediate response
4. Show text immediately (optimistic update)
5. Send to server (asynchronously)
6. Server acknowledges (receives operation)
7. If conflict: Reconcile (OT transformation)
8. Broadcast to other users
9. Other users apply (with OT transformation)
```

**Latency Breakdown**
```
User types → Local update (< 1ms)
          → Network to server (50-100ms)
          → Server processing (10ms)
          → Broadcast to others (50-100ms)
          → Client receives (50-100ms)
          → Apply transformation (10ms)
          → Show on screen (16ms, next frame)

Total: ~200-300ms for full round-trip
But user sees local text immediately (< 1ms), so feels instant
```

### Conflict Resolution Example

```
Document initially: "Hello world"

User A: Deletes "Hello " (at position 0, length 6)
        After: "world"

User B: Inserts "Beautiful " (at position 6)
        After: "Hello Beautiful world"

Orders unknown. Server receives A then B.

Processing:
1. Apply A: "Hello world" → "world" (delete 0-6)
2. Apply B: But position 6 doesn't exist anymore!
   
OT transformation:
- B's insert position = 6, A's delete affected 0-6
- Adjust B's position: 6 - 6 = 0
- Result: Insert "Beautiful " at 0 → "Beautiful world"

Final result: "Beautiful world"

Both users converge to same document (deterministic, no manual merge)
```

### Offline Support

**Offline Edits**
```
User goes offline (no network)
- Changes stored locally
- Can continue editing
- All edits applied locally (version = local_version++)

User comes online
- Sync queue: All offline edits
- Send to server with version numbers
- Server merges with changes from other users
- Client receives merged result
```

### Q&A

**Q: How does Google Docs handle simultaneous edits without locking?**
- A: Operational Transformation. Each operation has unique ID (client ID + sequence). Server applies in order, transforms operations to handle conflicts. Clients converge to same result.

**Q: Can Google Docs lose data?**
- A: Unlikely. Changes stored locally immediately (IndexedDB). Sent to server asynchronously. Multiple replicas on server. Even if network fails, local copy exists.

**Q: Why does Google Docs feel responsive even though latency > 100ms?**
- A: Optimistic updates. Text applied locally immediately, then synced to server. User sees their edits instantly. Latency only visible if conflict (which is rare).

---

## Real-Time Leaderboard {#leaderboard}

### Problem Statement

Gaming leaderboard must:
- Update in real-time (scores visible within 1 second)
- Handle millions of score submissions
- Rank efficiently (top 100, top 1000)
- Minimize latency (players want instant feedback)

### Architecture

```
[Game Client] → [Score Update API] → [Cache (Redis)] → [Database]
                                           ↓
                                   [Broadcast (WebSocket)]
                                           ↓
                                   [Leaderboard Subscribers]
```

### Scoring & Ranking

**Simple Approach: Database**
```
SELECT * FROM scores ORDER BY score DESC LIMIT 100

Problem: Query slow (full table scan, sorting 1B+ records)
         Multiple queries per second (each game session)

Latency: 1-5 seconds (unacceptable)
```

**Optimized: Redis Sorted Set**
```
Redis data structure: Sorted Set (ordered by score)

Operation:
ZADD leaderboard [score] [player_id]
ZREVRANGE leaderboard 0 99  (top 100)

Latency: < 10ms (in-memory)

Accuracy:
- Always up-to-date
- Sorted automatically
- No background jobs needed

Cost:
- Memory: 1M players * 100 bytes = 100 MB (reasonable)
```

### Real-Time Broadcasting

**WebSocket Flow**
```
1. Player scores 1000 points
2. Client sends: {player_id: "alice", score: 10000}
3. Server processes:
   - ZADD leaderboard 10000 alice
   - New rank = ZREVRANK leaderboard alice (maybe rank 50)
4. Check if rank changed (was 75, now 50):
   - Yes, notify subscribers
5. Broadcast to all connected clients:
   - {player_id: "alice", old_rank: 75, new_rank: 50, score: 10000}
6. Clients receive, update display
   - Re-render leaderboard
   - Show animation (rank improvement)
```

### Optimizing for Scale

**Problem: 1M concurrent players**
```
If each player has WebSocket connection:
- Memory: 1M * 10KB per connection = 10 GB
- Latency: Broadcasting to 1M clients = latency (message queued)

Solution: Hierarchical broadcasts
- Only notify clients viewing leaderboard
- Cache: Top 100 leaderboard, recompute every 100ms
- Pub/Sub sharding: Shard leaderboard by region/game
```

**Smart Updates**
```
Problem: Player score changes constantly (every second)
Broadcasting every change = too much traffic

Solution: Batch updates
- Update Redis immediately (for accuracy)
- Broadcast every 1-5 seconds (for efficiency)
- Include only significant changes (rank > 1000, don't notify)

Example:
- Alice goes from rank 10000 → 9990: Don't broadcast (too frequent)
- Bob goes from rank 100 → 50: Broadcast (significant improvement)
```

### Database Persistence

**Async Write-Behind**
```
Redis is volatile (data loss if crash)
Database is persistent (slow, but safe)

Architecture:
1. Update Redis immediately (fast, for real-time)
2. Queue write to database (async, 100ms later)
3. Database write completes (persistent)

If Redis crash before step 3:
- Data loss (player score reset)
- Solution: Redis snapshot every 60 seconds (acceptable for games)
- Or: Redis replication (backup instance)
```

### Interview Questions

**Q: Design leaderboard for 100M players, 10M concurrent.**
Answer should cover:
- Redis sorted set (fast ranking)
- WebSocket for real-time (low latency)
- Pub/Sub sharding (scale to 10M)
- Persistence (database backup)
- Analytics (top 1000, regional leaderboards)

**Q: How to prevent cheating?**
- Validate score on server (don't trust client)
- Check for impossible scores (faster than world record)
- Anomaly detection (sudden rank jump)
- Audit log (track all score changes)

---

## Collaborative Editing Patterns {#collab-patterns}

### CRDT Deep Dive

**List CRDT (for text)**
```
Each character has unique ID: (user_id, sequence)

Example: User A types "Hi"
- H: (A, 1)
- i: (A, 2)

User B types "Lo" (simultaneously)
- L: (B, 1)
- o: (B, 2)

Merge: Sort by (user_id, sequence)
(A, 1) < (A, 2) < (B, 1) < (B, 2)
Result: "HiLo" (deterministic, both clients converge)

Benefits:
- No coordination needed (works offline)
- Deterministic merge (same order always)
- No conflicts (each character unique)

Cost:
- Memory overhead (metadata per character)
- Complexity (understanding CRDT hard)
```

**Vector Clocks for Causality**
```
Track: If operation A caused operation B?

Example:
User A: Inserts "H" at 0 → VC: [A:1, B:0]
User B: Sees A's change, inserts "i" at 1 → VC: [A:1, B:1]

Result: B's edit depends on A's (causal order)

If concurrent (neither depends on other):
User A: Insert "H" → VC: [A:1, B:0]
User B: Insert "L" → VC: [A:0, B:1]

Neither happened before the other (concurrent), so merge needed

CRDT + vector clocks = track causality + merge conflicts
```

### OT Complexity

**Transformation Properties**
```
Transform(operation1, operation2) must satisfy:

Property: If you have two operations A and B:
- Apply A then B = Apply B then Transform(A, B)
- Results identical (order independent)

Example:
A = Insert "H" at 0
B = Insert "L" at 2

Apply A then B:
- "H" + insert "L" at 2 = "H_L" (L at position 2, but only 1 char)
- Adjusted: Insert "L" at 1 = "HL"

Apply B then Transform(A, B):
- "L" + Transform(A, B) = ?
- Transform: A was 0, B at 2, adjust A to 1 = Insert "H" at 1
- Insert "H" at 1 = "HL"

Both approaches: "HL" (transformation property holds)
```

### Tombstone Deletion

**Problem: Deletion breaks position tracking**
```
Document: "Hello"
User A: Delete "l" at position 2
User B: Insert "!" at position 3

If A deletes first:
- "Helo" (one 'l' gone)
- B inserts at 3: "Helo!" (position 3 = after 'o')

If B inserts first:
- "Hello!" 
- A deletes at 2: "Helo!" (position 2 = first 'l')

Both converge: "Helo!" (correct)

Without tombstone deletion:
- Hard to track positions (what is "position 2" after deletion?)

With tombstone:
- Mark character as deleted (don't remove)
- Position still valid (count deleted too)
- Users see deleted as invisible (but position preserved)
```

---

## Real-Time Architecture {#realtime-arch}

### Latency Tiers

**Tier 1: < 100ms (Real-time)**
```
Examples: Chat messages, live edits, gaming
Technology: WebSocket, direct connection
Implementation: Server push, no polling

Pros: Truly real-time, low latency
Cons: Stateful (must maintain connection), resource-intensive
```

**Tier 2: 100-1000ms (Near Real-Time)**
```
Examples: Social feeds, leaderboards, notifications
Technology: HTTP long-polling, Server-sent Events
Implementation: Batch updates, eventual consistency

Pros: Works with HTTP, easier scaling
Cons: Batch delays, network overhead
```

**Tier 3: > 1 second (Eventual Consistency)**
```
Examples: Email, notifications, analytics
Technology: Message queue, cron jobs
Implementation: Async processing, no real-time requirement

Pros: Scalable, fault-tolerant, cheap
Cons: Stale data, delays acceptable
```

### Scaling Real-Time

**Single Server Bottleneck**
```
Problem: WebSocket connections memory-intensive
- 1M connections = 1GB RAM (minimum)
- Single server = 10K-100K connections max
- Need 10+ servers for 1M users

Solution: Horizontal scaling with load balancing

Architecture:
[Client 1] ─┐
[Client 2] ─┼─ [Load Balancer] ─┬─ [Server 1: 100K connections]
[Client 3] ─┘                   ├─ [Server 2: 100K connections]
...                             └─ [Server 3: 100K connections]
```

**Message Propagation**
```
Problem: User A on Server 1, User B on Server 2
         A sends message to B

Solution: Message bus (Redis pub/sub)

Flow:
1. A connects to Server 1 (WebSocket)
2. B connects to Server 2 (WebSocket)
3. A sends message: Server 1 publishes to Redis
4. Redis broadcasts to all servers
5. Server 2 receives, sends to B (WebSocket)
6. B sees message in real-time

Latency: < 50ms (network + Redis)
```

### Stateful vs Stateless

**Stateful Servers (Sticky Sessions)**
```
Pro: Low latency (WebSocket always to same server)
Con: Rebalancing hard (if server crashes, lose connections)
Con: Scaling difficult (must track which users on which server)

Use: Small scale (< 1M users)
```

**Stateless Servers (Message Bus)**
```
Pro: Easy scaling (users can move between servers)
Pro: Resilient (if server crashes, reconnect to another)
Con: Higher latency (message bus overhead)

Use: Large scale (1M+ users)
```

---

## Consistency in Real-Time Systems {#realtime-consistency}

### Strong Consistency

**Definition**: All clients see same data at same time

**Implementation: Synchronous Replication**
```
Server writes to primary + backup simultaneously
Only acknowledge when both confirm

Pros: No stale reads
Cons: Slower (must wait for slowest replica)
      Network partition: Can't proceed (wait for backup)

Use: Financial (banking, trading)
```

### Eventual Consistency

**Definition**: All clients eventually see same data (after time)

**Implementation: Asynchronous Replication**
```
Server writes to primary
Asynchronously replicates to backup

Pros: Fast (don't wait for backup)
Cons: Brief period where backup stale
      Network partition: Primary diverges from backup

Use: Social media (feeds, posts, comments)
```

### Causal Consistency

**Definition**: If A caused B, all clients see A before B

**Implementation: Version Vectors**
```
Each update has version vector
Track dependencies

Example:
Post 1: [A:1, B:0]
Reply 1: [A:1, B:1]

Reply 1 depends on Post 1 (both have [A:1])
Client seeing Post 1 at [A:1, B:0] won't see Reply 1 yet
Client seeing Reply 1 at [A:1, B:1] sees Post 1 first

Causal order preserved
```

---

**Key Takeaway**: Real-time systems require fundamentally different architecture than batch systems. Trade consistency for latency, synchronization for scalability, and optimize for network realities (partitions, latency).
