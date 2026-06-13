# Social Platforms, Messaging & Infrastructure

Complete guide to designing large-scale social and messaging platforms, plus critical infrastructure components.

---

## Table of Contents
1. [WhatsApp Architecture](#whatsapp)
2. [Slack Architecture](#slack)
3. [Reddit Architecture](#reddit)
4. [Tinder Architecture](#tinder)
5. [Bluesky (Decentralized Social)](#bluesky)
6. [Nginx & Load Balancing](#nginx)
7. [Comparison & Trade-offs](#comparison)

---

## WhatsApp Architecture {#whatsapp}

### Problem Statement

WhatsApp handles:
- 100 billion messages/day (1.2M messages/second peak)
- 2B+ users globally
- End-to-end encryption (E2E)
- Real-time delivery (< 2 seconds)
- Group chats (up to 256 members)
- Offline delivery (store when offline, deliver when online)

### Architecture Overview

```
[Mobile App] ←WebSocket→ [Connection Server] ←→ [Message Queue (Kafka)]
  ↓                              ↓
[Local SQLite DB]        [Message Store (Cassandra)]
[Encryption (Signal)]           ↓
                        [Delivery Workers] → [Recipients]
```

### Key Technologies

**End-to-End Encryption (E2E)**
```
Problem: WhatsApp servers must NOT see message content
         Users trust only their devices

Solution: Signal Protocol (industry standard)

Keys:
- Device key pair (private: phone only, public: shared)
- Session key pair (per conversation, rotated)
- Prekeys (created locally, uploaded encrypted)

Message flow:
1. User A: Encrypt with B's public key + session key
2. Encrypt with A's private key (sign)
3. Send encrypted blob to server (server can't decrypt)
4. Server stores encrypted blob
5. User B: Receives blob, decrypts with B's private key
6. Verifies signature with A's public key
7. Reads message in plaintext (only on B's device)

Security: Even if server hacked, messages safe (encrypted)
```

**Connection Management (Erlang)**
```
WhatsApp uses Erlang (telecom-grade reliability)

Pros:
- Lightweight processes (millions per server)
- Hot code reloading (update without restart)
- Distributed (natural clustering)
- Fault-tolerant (kill process, restart)

Challenges:
- Not many engineers know Erlang
- Scaling requires careful design (state management)
- Monitoring harder (distributed system)
```

**Message Store (Cassandra)**
```
Why not MySQL?
- MySQL: Single-region (latency for global users)
- Cassandra: Multi-region (each region has replicas)

Architecture:
- Partition key: User ID (all user's messages in one partition)
- Sort key: Message ID / Timestamp (ordered by time)
- Replication: 3 copies (RF=3)
- Availability: Any 2 of 3 up = available

Query:
SELECT * FROM messages
WHERE user_id = 'alice' AND message_id >= last_fetched
ORDER BY message_id DESC LIMIT 100

Returns: Last 100 messages (fast, ordered)
```

### Message Delivery

**Offline Message Handling**
```
User A sends message to User B (B offline)

Process:
1. Server receives message from A
2. Encrypts with B's public key
3. Tries to deliver (B not connected)
4. Stores in Cassandra (message queue)
5. B comes online (WebSocket connects)
6. Server checks for queued messages
7. Sends all queued messages
8. B decrypts, shows in UI
9. B sends receipt (ACK)
10. Server deletes from queue

Delivery guarantee: At least once (duplicate prevention via message ID)
```

**Read Receipts**
```
Single checkmark: Message sent
Double checkmark: Message delivered
Blue checkmark: Message read

Sends back to sender:
- Delivery receipt: Server confirms B received
- Read receipt: B confirms opened + read timestamp

Latency: < 1 second (real-time)
Privacy: User can disable read receipts
```

### Scaling to Billions

**Connection Scaling**
```
1 server: 1M concurrent connections (modern hardware)
100M concurrent users: Need 100+ servers

Architecture:
[Load Balancer] 
    ├─ [Server 1]: Users 1-1M
    ├─ [Server 2]: Users 1M-2M
    └─ [Server 100]: Users 99M-100M

Each user sticks to one server (sticky session)
If server dies: Reconnect to different server
```

**Message Delivery Scaling**
```
1 million messages/second

Queue: Kafka (publish-subscribe)
- Topic per region (region-us, region-eu, region-in)
- Partition per user (user-alice, user-bob)
- Consumer group: delivery workers

Workers:
- 1000 workers consuming from Kafka
- Each worker handles 1000 messages/sec
- Parallel delivery (scale with load)
```

---

## Slack Architecture {#slack}

### Problem Statement

Slack must handle:
- 1B+ messages/day
- 20M+ concurrent users
- Full-text search (find any message)
- Channels (organized conversations)
- Real-time reactions (emoji reactions)
- File sharing
- Integrations (webhooks, bots)

### Architecture Overview

```
[Web Client / Mobile] ←WebSocket→ [Connection Server]
                                         ↓
                                 [Message Service]
                                   ↓    ↓
                        [Message DB] [Search Index]
                                   ↓
                        [Cache (Redis)]
```

### Channel Model

**Channels vs Direct Messages**
```
Channel: Public or private conversation (many users)
- All members see same history
- Searchable across organization
- Organized by topic

DM: Private message (1-on-1 or group)
- Only participants see
- Searchable personal history
- Less organized, more casual

Storage:
- Channels: Shared (one copy)
- DMs: Duplicated (one per user)
  Why: If delete, don't affect other user's history
```

### Full-Text Search

**Problem: 1B messages, need instant search**
```
SELECT * FROM messages WHERE content LIKE '%keyword%'

Problem: Full table scan, slow, unscalable

Solution: Elasticsearch (full-text search engine)

Process:
1. Message arrives
2. Store in message DB (Cassandra)
3. Index in Elasticsearch (async, 100ms latency)
4. User searches
5. Query Elasticsearch (< 100ms)
6. Return matching messages

Why not use DB indexes?
- DB indexes for numeric/string search
- Full-text search needs tokenization, stemming, etc.
- Elasticsearch built for this use case
```

**Inverted Index**
```
Document:
Message 1: "I love pizza"
Message 2: "Pizza is great"

Inverted Index:
"love" → [Message 1]
"pizza" → [Message 1, Message 2]
"is" → [Message 2]
"great" → [Message 2]

Search "pizza":
Return Message 1, Message 2 (instant)
```

### Real-Time Reactions

**Emoji Reaction Architecture**
```
Problem: User reacts to message with emoji
         Reaction should appear instantly to all viewers

Flow:
1. User clicks 👍 on message 123
2. Client sends: {message_id: 123, emoji: "👍", user: alice}
3. Server stores reaction
4. Publish to WebSocket: "reaction added"
5. All users viewing message 123 see reaction appear

Storage:
{
  message_id: 123,
  reactions: {
    "👍": [alice, bob, charlie],
    "❤️": [diana],
    "🔥": [eve]
  }
}

Counting: O(1) per emoji (just array length)
```

### Integrations & Webhooks

**Webhook Model**
```
External service sends data to Slack

Example: GitHub integration
- Code pushed → GitHub webhook → Slack
- "alice pushed to main: fixed bug #123"

URL: https://hooks.slack.com/services/T123/B456/xyz

POST to URL:
{
  "text": "alice pushed to main"
}

Slack receives, posts to channel

Challenges:
- Delivery reliability (if Slack down?)
- Rate limiting (prevent abuse)
- Authentication (verify webhook source)
```

---

## Reddit Architecture {#reddit}

### Problem Statement

Reddit handles:
- 1B+ comments/month
- Hot/trending ranking (content relevance)
- Voting system (upvote/downvote)
- Subreddits (communities)
- Comment trees (hierarchical)
- Real-time vote counts

### Vote System

**Voting Dynamics**
```
Problem: Post gets 1000 upvotes/minute during viral spike
         Vote count must update in real-time

Naive approach:
UPDATE posts SET upvotes = upvotes + 1 WHERE id = 123

Problem: Thundering herd (1000 requests/sec hit same row, lock contention)

Solution: Batch + Cache

Process:
1. Vote arrives
2. Increment in cache (Redis): INCR post:123:upvotes
3. User sees +1 vote immediately (from cache)
4. Background job: Every 10 seconds, read cache, update DB
5. Reset cache to 0

Accuracy: Eventually consistent (votes match DB after 10 sec)
Performance: No DB lock contention
```

**Downvote Weight**
```
Initially: +1 or -1 equally

Problem: Brigading (many users downvote to suppress)
         Low-quality comments buried (but votes visible)

Solution: Controversial post
- If voted 60% up, 40% down = "controversial"
- Sort: Hot, Controversial, New, Top (user chooses)

Ranking algorithm:
Score = (upvotes - downvotes) * time_decay
Hot = trending (recent upvotes + decay)
Controversial = close to 50/50
```

### Ranking Algorithm

**Hot/Trending Ranking**
```
Problem: 1000 new posts/minute, show "hottest" first

Solution: Ranking algorithm (Hacker News formula)

Score = (P - 1) / (T + 2)^1.8

Where:
P = number of upvotes + 1 (offset)
T = hours since submission

Example:
Post A: 100 upvotes, 1 hour old = (100-1)/(1+2)^1.8 = 99/5.196 = 19.04
Post B: 50 upvotes, 0.1 hour old = (50-1)/(0.1+2)^1.8 = 49/2.07 = 23.67

Post B ranks higher (newer, momentum)

As time passes:
Post B: 3 hours old = (50-1)/(3+2)^1.8 = 49/17.78 = 2.75 (drops)

Post A dominates (older, but more upvotes)
```

### Comment Trees

**Hierarchical Structure**
```
Post
├─ Comment 1 (100 upvotes)
│  ├─ Reply 1.1 (50 upvotes)
│  │  └─ Reply 1.1.1 (10 upvotes)
│  └─ Reply 1.2 (5 upvotes)
├─ Comment 2 (20 upvotes)
└─ Comment 3 (5 upvotes)

Storage:
{
  id: "c1",
  text: "Comment 1",
  parent: "post123",
  upvotes: 100,
  children: ["c1_1", "c1_2"],
  collapsed: false
}

Rendering:
- Show top 10 comments (by score)
- Lazy load children (only when expanded)
- Collapse downvoted comments (< -5 votes)
```

---

## Tinder Architecture {#tinder}

### Problem Statement

Tinder handles:
- Real-time location (users move frequently)
- Matching (find compatible users nearby)
- Like/Dislike (quick swipes)
- Messages (match -> chat)
- Real-time notifications

### Matching Algorithm

**Geo-Spatial Matching**
```
Problem: Find all users within 5 miles radius
         Database: 5M active users
         Naive: Distance calculation to all 5M (slow)

Solution: Geo-hashing (divide world into grid)

Grid:
[U1 in grid A] → Swipe
Query: Users in grid A and neighbors (B, C, D, E)
Result: ~1000 potential matches (instead of 5M)

GeoHash:
- 38.7749°N, 122.4194°W → "9q8yy" (each char = finer precision)
- Search within same GeoHash (proximity)
- EZ to index and query

Database:
CREATE INDEX location_index ON users(geohash)

SELECT * FROM users 
WHERE geohash LIKE '9q8%' AND age BETWEEN 20 AND 35
ORDER BY match_score DESC
LIMIT 10
```

**Matching Score**
```
Score = (age_compat + interests_compat + location_compat) / 3

Age compatibility: 
- If same age ±5 years: 100%
- Otherwise: lower score

Interests compatibility:
- Shared interests: +10 points each
- Example: Both like "hiking" → +10

Location compatibility:
- Within 5 miles: 100%
- 5-10 miles: 50%
- > 10 miles: 0%

Result: Sort by score (highest compatibility first)
```

### Swiping System

**Like/Dislike Handling**
```
User swipes right (like) on profile 123

Process:
1. Send like to server (user_id=456, target_id=123)
2. Server stores like
3. Check if target also liked user_id (mutual like = MATCH!)
4. If match:
   - Create conversation
   - Notify both users
   - Enable messaging
5. If no match yet:
   - Just store like
   - Notify target (optional, privacy-based)

Storage:
likes table:
{
  user_id: 456,
  target_id: 123,
  timestamp: 2024-01-15 10:30:00,
  matched: true/false
}
```

### Real-Time Notifications

**WebSocket for Matches**
```
User swiping on one device sees matches on another instantly

Architecture:
[Device 1: Swiping] → Server → [Redis Pub/Sub] → [Device 2: Messaging]

Process:
1. Swipe happens on Device 1
2. Server detects match
3. Publishes to Redis channel: "user:456:matches"
4. Device 2 subscribed to channel receives notification
5. Shows "New match!" and updates UI
6. Both devices can start messaging
```

---

## Bluesky (Decentralized Social) {#bluesky}

### Problem Statement

Bluesky (Twitter alternative) uses decentralized architecture:
- No single company controls data
- Users own their identity (portable username)
- Open protocol (anyone can build client)
- Federation (like email: @bluesky.social, @custom.com)

### Architecture

```
Traditional (Twitter):
[User App] ← ← → [Twitter Servers] → [Storage]
            Only Twitter controls data

Decentralized (Bluesky):
[User App] ← → [User's PDS (Personal Data Server)]
            ← → [Indexing Service (search, feed)]
            ← → [Relay (communication hub)]
```

### Personal Data Servers (PDS)

**User Ownership**
```
User alice@custom.com runs PDS on her server:
- Stores all her posts
- Stores her graph (followers, following)
- Can leave anytime (export data, switch to different PDS)
- Different PDS: alice@bluesky.social

Portability:
- Alice starts on bluesky.social (Bluesky's PDS)
- Migrates to alice@custom.com (self-hosted)
- Followers/posts follow (identity is portable)

How?
- Identity: alice@custom.com (DNS-based)
- Data location: Custom.com/pds (known from DNS)
- Clients resolve: "alice@custom.com" → fetch from custom.com
```

### Federation & Relays

**Relay (Message Broker)**
```
Problem: Direct P2P communication unreliable
         Servers go down, NAT issues, firewalls

Solution: Relay (optional, helps with discovery)

Flow:
1. alice@custom.com posts
2. Sends to Relay (Bluesky runs public relay)
3. Relay broadcasts to other PDS servers
4. bob@bluesky.social's PDS subscribes to relay
5. Bob's PDS receives post
6. Bob's app fetches from alice's PDS (or relay cache)

Optional: PDS can ignore relay, find each other directly
```

### Open Protocol (AT Protocol)

**Anyone Can Build Clients**
```
Example clients:
- Bluesky app (official)
- Third-party apps (Threads-like, Twitter-like, etc.)
- All connect same backend

Benefits:
- User chooses preferred UX
- Prevents lock-in (not dependent on one app)
- Encourages innovation (anyone can innovate)

Trade-off:
- Fragmentation (different UX = user experience varies)
- Complex protocol (must be well-defined)
- Moderation challenges (multiple clients, one policy)
```

### Challenges vs Traditional

**Decentralization Complexity**
```
Traditional: Simple (all traffic through Twitter servers)
Decentralized: Complex (PDS communication, federation, relays)

Problems:
- Spam (no central authority, hard to moderate)
- Consistency (if two PDS disagree, who's right?)
- Discovery (find interesting content across federated network)
- Trust (how do you verify signatures from unknown PDS?)

Solutions:
- Reputation systems (rate PDSes)
- Consensus protocols (majority agree)
- Indexing service (crawl federated network)
- Digital signatures (verify authenticity)
```

---

## Nginx & Load Balancing {#nginx}

### What is Nginx?

**Definition**: Reverse proxy and web server

```
Traditional architecture:
[Client] ← → [App Server] ← → [Database]

Nginx architecture:
[Client] ← → [Nginx] ← → [App Server 1]
              ├─ → [App Server 2]
              └─ → [App Server 3]
```

### Load Balancing Algorithms (in Nginx)

**Round Robin**
```
nginx.conf:
upstream backend {
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}

Behavior:
Request 1 → backend1
Request 2 → backend2
Request 3 → backend3
Request 4 → backend1 (cycle)

Pros: Simple, fair distribution
Cons: Ignores server health/capacity
```

**Least Connections**
```
upstream backend {
    least_conn;
    server backend1.example.com;
    server backend2.example.com;
}

Behavior:
- Track active connections per server
- Route to server with fewest connections

Use: Long-lived connections (WebSocket, persistent)
```

**IP Hash**
```
upstream backend {
    ip_hash;
    server backend1.example.com;
    server backend2.example.com;
}

Behavior:
- Hash client IP
- Always route to same server

Use: Session persistence (client state)
Problem: If server dies, user's hash points to different server (session lost)
```

**Weighted Round Robin**
```
upstream backend {
    server backend1.example.com weight=5;
    server backend2.example.com weight=2;
    server backend3.example.com weight=1;
}

Behavior:
- backend1 gets 5/8 traffic (62.5%)
- backend2 gets 2/8 traffic (25%)
- backend3 gets 1/8 traffic (12.5%)

Use: Heterogeneous servers (different capacities)
```

### Health Checks

**Passive Health Checks**
```
If server returns 5xx or timeout, mark as down
Don't send new requests to down server

nginx.conf:
upstream backend {
    server backend1.example.com max_fails=3 fail_timeout=30s;
}

Behavior:
- After 3 failed requests, mark as down
- Wait 30 seconds
- Try again (recovery check)
```

**Active Health Checks (Nginx Plus)**
```
Periodically ping server (HTTP request)

Check: GET /health → 200 OK = healthy

Pros: Proactive detection (detect failures before traffic hits)
Cons: Requires application health endpoint
```

### Caching Layer

**Nginx as Cache**
```
nginx.conf:
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m;

server {
    location / {
        proxy_cache my_cache;
        proxy_cache_valid 200 1h;
        proxy_pass http://backend;
    }
}

Behavior:
1. Request comes in
2. Check Nginx cache (in-memory, fast)
3. If hit: Return cached response (no backend call)
4. If miss: Forward to backend, cache response
5. Next request: Serve from cache

Savings: Reduce backend load 50-80% (typical)
```

### SSL Termination

**Problem: SSL encryption expensive (CPU intensive)**
```
[Client] ← HTTPS → [Nginx] ← HTTP → [Backend]
          (encrypted)        (plaintext, internal)

Nginx decrypts (terminates TLS)
Forwards plaintext to backend
Saves backend from SSL overhead

Security: OK (internal network trusted)
```

### Rate Limiting

**Nginx Rate Limiting**
```
nginx.conf:
limit_req_zone $binary_remote_addr zone=limitzone:10m rate=10r/s;

server {
    location /api {
        limit_req zone=limitzone burst=20;
        proxy_pass http://backend;
    }
}

Behavior:
- 10 requests per second per IP
- Burst up to 20 (temporary spike)
- Return 429 Too Many Requests if exceeded

Use: Prevent abuse, DDoS mitigation
```

---

## Comparison & Trade-offs {#comparison}

| Platform | Scale | Real-time | Consistency | Key Tech |
|----------|-------|-----------|-------------|----------|
| WhatsApp | 100B msgs/day | < 2s | E2E Encryption | Erlang, Cassandra, Kafka |
| Slack | 1B msgs/day | < 1s | Eventual | WebSocket, Elasticsearch, Cassandra |
| Reddit | 1B comments/month | Eventual | Vote eventual consistency | Cassandra, Redis, Ranking algo |
| Tinder | Real-time matching | < 1s | Geo-proximity eventual | GeoHash, Redis, WebSocket |
| Bluesky | Decentralized | < 2s | PDS controlled | AT Protocol, Relay, Federation |
| Nginx | - | - | Proxy layer | Load balancing, caching, SSL |

---

**Key Takeaway**: Each platform made different trade-offs. WhatsApp prioritized encryption (security > speed). Slack prioritized search (features). Reddit prioritized ranking (content quality). Tinder prioritized location (matching). Bluesky prioritized decentralization (control). Choose based on your requirements.
