# Mobile System Design - Complete Guide

Comprehensive guide for designing systems with mobile-specific constraints (offline support, battery, network, storage).

---

## Table of Contents
1. [Mobile Design Fundamentals](#fundamentals)
2. [Offline-First Architecture](#offline)
3. [Network Optimization](#network)
4. [Battery & Performance](#battery)
5. [Data Synchronization](#sync)
6. [Real-World Examples](#examples)
7. [Mobile vs Web Trade-offs](#tradeoffs)
8. [Interview Framework](#interview)

---

## Mobile Design Fundamentals {#fundamentals}

### Mobile Constraints vs Desktop

| Constraint | Mobile | Desktop | Impact |
|-----------|--------|---------|--------|
| Network | 4G/5G/WiFi (variable) | Broadband (stable) | Must handle variable latency |
| Storage | 16GB-512GB | 500GB-2TB | Cache aggressively |
| Memory | 2-8GB | 16GB+ | Minimize memory use |
| Battery | 15-30 hours max | Plugged in | Every network call drains battery |
| CPU | 4-8 cores (varied) | 8+ cores (powerful) | Offload to server |
| Data plan | Limited (5-20GB/month) | Unlimited | Every byte costs user money |
| Screen | 5-7 inches | 27+ inches | Responsiveness critical |

### Core Mobile Design Principles

**1. Assume Unreliable Network**
```
WiFi might cut out mid-request
Mobile data switches between 4G/3G
User goes into tunnel (no signal)

Design:
- Queue requests (retry when connection back)
- Timeout quickly (don't wait forever)
- Show loading state (user knows something happening)
- Fallback to cached data (show something > loading spinner)
```

**2. Battery is Precious**
```
Every API call = radio wake-up (50-100ms at full power)
Network radio is 2x-3x more power than CPU

Design:
- Batch requests (send 10 at once, not 10 separate calls)
- Push notifications instead of polling
- Disable background sync (if user can wait)
- Fetch only needed data (not everything)
```

**3. Users Expect Instant Response**
```
Desktop: < 1 second acceptable
Mobile: < 500ms expected, > 1s frustrating

Design:
- Optimistic updates (show result immediately, sync in background)
- Skeleton screens (show placeholder while loading)
- Cached first (show cached data, update with fresh)
```

**4. Storage is Limited but Sufficient**
```
Typical app: 50-500 MB
OS + system apps: 5-10 GB
User photos: 10-50 GB

Design:
- Cache only needed data (not entire database)
- Compression (photos 80% smaller with optimization)
- Cleanup (delete old messages, expired data)
```

---

## Offline-First Architecture {#offline}

### Definition

App continues working without network (or with intermittent network).

```
Traditional: Data flows server → client
             No server = no data = app useless

Offline-First: Data flows both directions
               Client has copy = works offline
               Server has copy = works when online
               Sync when connection available
```

### Architecture Patterns

**Pattern 1: Local-First Sync**
```
Write flow:
1. User types message
2. Write to local database (SQLite, Realm)
3. Show message immediately (optimistic update)
4. Queue write to server
5. When network available, send queued writes
6. Server confirms, remove from queue

Read flow:
1. App loads
2. Check local database first (instant, no network wait)
3. If data stale, fetch fresh from server
4. Update local database
5. Update UI with fresh data

Key: Local database is source of truth for offline, server for online
```

**Pattern 2: Event Sourcing**
```
Instead of storing final state, store all changes

Example: Chat message history
Traditional: messages = ["Hi", "Hello", "How are you?"]
Event sourcing:
  events = [
    {type: "message_sent", content: "Hi", timestamp: T1},
    {type: "message_sent", content: "Hello", timestamp: T2},
    {type: "message_edited", id: 1, content: "Hi there", timestamp: T3}
  ]

Replay events to get current state (messages = ["Hi there", "Hello", "How are you?"])

Benefits for offline:
- Send events to server, server replays
- Handles out-of-order delivery (events timestamped)
- Handles conflicts (last event wins, or merge)
```

**Pattern 3: CRDT (Conflict-Free Replicated Data Type)**
```
Algorithm that handles concurrent edits without conflict resolution

Example: Google Docs collaborative editing
User A edits character at position 5: "Hello"
User B edits character at position 3: "Hello"

Traditional (problematic):
- Both think they're at position 3
- Edits conflict, need to pick one (one lost)

CRDT (no conflicts):
- Each character has unique ID (user_id + sequence)
- A's char at pos 5: (user_A, seq_1) = "H"
- B's char at pos 3: (user_B, seq_2) = "e"
- Both edits merged: no conflict

Merge rule: Sort by (user_id, sequence)
Result: Both clients converge to same text without explicit merge

Complexity: Hard to implement, but no data loss or manual merge
```

### Sync Strategies

**Full Sync**
```
Problem: App offline for hours, has 1000 messages to sync
Solution: Upload entire local database

Process:
1. App detects network available
2. Dump local database to server
3. Server merges with its version
4. Client gets server's version back

Pros: Simple, handles any conflict
Cons: Slow (upload entire DB), traffic intensive, data loss risk (if both modify same record)
```

**Delta Sync**
```
Only sync changes since last sync

Example:
Last sync: T0, had messages [A, B, C]
Offline: Added message D
Sync: Send only D

Server merges:
- Server has [A, B, C, E] (added E while app offline)
- App has [A, B, C, D]
- Merged: [A, B, C, D, E]

Pros: Efficient (only changed data)
Cons: Must track changes, conflicts possible (both edited B)
```

**Timestamp-Based Sync**
```
Track last sync time, sync only changes after that time

Example:
Last sync: 5:00 PM
App offline: 5:00 PM - 6:00 PM
Sync at 6:00 PM:
- Fetch all changes from server since 5:00 PM
- Apply to local database
- Send all local changes since 5:00 PM

Handles:
- Order of events (by timestamp)
- Conflicting edits (use vector clocks)
```

### Conflict Resolution

**Last-Write-Wins (LWW)**
```
If both offline users edit same field, last write wins

Example:
Device A offline: Edited name to "Alice", timestamp T1
Device B offline: Edited name to "Bob", timestamp T2

On sync (T1 < T2):
Name = "Bob" (T2 is later)

Pros: Simple, no manual merge
Cons: Data loss (Alice's edit lost)
```

**Server Wins**
```
Server version always wins

Example:
Device A offline: Edited name to "Alice"
Server: Name is already "Bob"

On sync:
Name = "Bob" (server wins)

Pros: No inconsistency
Cons: User changes lost
```

**Merge**
```
Combine both changes

Example:
Device A offline: Added comment "Alice: Great idea"
Server: Added comment "Bob: I agree"

On sync:
Comments = [
  "Alice: Great idea",
  "Bob: I agree"
]

Pros: No data loss
Cons: Sometimes nonsensical (both edited same sentence)

When works: Adding new items (messages, todos)
When breaks: Editing existing item (who's version correct?)
```

---

## Network Optimization {#network}

### Request Batching

**Problem: Many Small Requests**
```
User scrolls feed, app loads 100 items
Traditional: 100 separate API calls
- 100 network overhead (100 TLS handshakes)
- 100 round-trips (latency adds up)
- Battery drain (radio on/off 100 times)

Solution: Batch
- Combine requests: GET /feed?items=100
- Single request, single round-trip
- Single radio activation
```

**Implementation**
```
Pattern: Queue requests, send in batch every 100ms

RequestQueue:
- addRequest(url, params)
- Schedule batch send (if not already scheduled)
- Wait 100ms for more requests to accumulate
- Send all in single payload

Example:
T0: Request("user/123")
T10: Request("user/456")
T50: Request("user/789")
T100: Batch send (all 3 together)

Result: 1 roundtrip + 3 requests, not 3 roundtrips
```

### Compression

**Gzip Compression**
```
Typical API response: 10 KB JSON
Gzipped: 2 KB (80% reduction)

Overhead: CPU to compress/decompress ~5ms
Benefit: Network faster (data transfer 80% faster)

For mobile: Always use gzip (battery + data benefit > CPU cost)

Implementation:
- Server: Add "Content-Encoding: gzip" header
- Client: Automatic (most frameworks handle)
```

**Image Optimization**
```
Typical photo: 5 MB RAW
Optimized:
- Resize to screen size (1080p max for most phones)
- JPEG compression (quality 75-80): 500 KB
- WebP format: 300 KB

Result: 95% smaller, perceptually similar

Implementation:
- CDN auto-resizes (AWS, Cloudflare)
- Server sends multiple sizes, client picks
- Client caches (don't refetch same image)
```

### Progressive Loading

**Skeleton Screen**
```
User opens feed

Traditional:
- Load feed (wait 2 seconds)
- Show content

Better:
- Show skeleton (placeholder)
- Load content in background
- Replace skeleton when ready

Code:
```
if (loading) return <SkeletonFeed /> // Instant
return <Feed data={data} /> // After load
```

Benefit: Feels instant, no white screen, user knows something loading
```

**Progressive Image Loading**
```
Show low-quality image immediately, upgrade to high-quality

Process:
1. Fetch thumbnail (10 KB, shows in 100ms)
2. Show low-quality image
3. Fetch full image (500 KB, shows in 2s)
4. Replace with high-quality

User sees image immediately (low-quality)
By time user interacts, high-quality usually loaded

Implementation:
- Server generates thumbnail (50x50 pixels)
- Embed thumbnail in JSON payload
- Load full image separately
```

---

## Battery & Performance {#battery}

### Battery Drain Analysis

**Radio States**
```
Mobile radio has 3 states:

1. Active (full power): ~500mW
   - Actively transferring data
   - Duration: Only during data transfer

2. Idle (low power): ~100mW
   - Radio still active, but no data
   - Duration: Time after last data before turning off

3. Sleep (minimal power): ~5mW
   - Radio off completely
   - Duration: Rest of time

Total cost of network call:
- Active time: 5s (transfer) × 500mW = 2500 mJ
- Idle time: 10s (radio staying on) × 100mW = 1000 mJ
- Total: 3500 mJ per call

Key insight: Idle time wastes battery!

Solution:
- Batch requests (one call instead of 10)
- Avoid frequent polling (use push instead)
```

### Reducing Battery Drain

**1. Push Notifications Instead of Polling**
```
Polling approach:
- Every 30 seconds, check server for new messages
- 120 checks per hour × 500 mJ idle = huge battery drain
- User might not get message for 30 seconds

Push approach:
- Server sends notification when message arrives
- Client radio wakes only for notification
- Battery drain minimal
- Message arrives instantly

Implementation:
- Server detects new message
- Sends push notification to client
- Client wakes, pulls message
```

**2. Background Sync**
```
User offline, makes changes
Traditional: Wait until next open

Background sync:
- App wakes up periodically (every hour)
- Syncs pending changes
- User data updated automatically

Tradeoff:
- Battery cost (periodic wake)
- Benefit: Data always fresh

Solution: User can disable (Settings → Background app refresh)
```

**3. Compression & Caching**
```
Compression reduces data:
- Network transfer faster
- Radio on for less time
- Battery saved

Caching avoids redundant calls:
- App opens, loads from cache (instant)
- Sync in background (when convenient)
- Next open even faster

Battery saved: Don't waste radio on duplicate requests
```

### Performance Metrics

**Mobile App Startup**
```
Cold start (app not in memory): 2-5 seconds
Warm start (app in memory): 500-1000ms

Target: < 2 seconds for user to interact

Breakdown:
- Process creation: 100ms
- Theme loading: 200ms
- Database open: 500ms
- Network call for data: 1000ms
- Render UI: 200ms
- Total: 2000ms

Optimization:
- Lazy load (don't load everything at startup)
- Cache (skip network call if cached)
- Async database (don't block on DB open)
```

**Frame Rate (Smoothness)**
```
Target: 60 FPS (16ms per frame)

If scrolling jank (drops to 30 FPS):
- Likely: Main thread blocked (database, network, computation)
- Solution: Move work to background thread

Measurement:
- Profile with Android Profiler, Instruments (iOS)
- Look for main thread blocking
- Move heavy work to background
```

---

## Data Synchronization {#sync}

### Sync Algorithm

**Two-Way Merge**
```
State before:
Server: [msg1, msg2, msg3]
Client: [msg1, msg2]

Client goes offline, adds msg4:
Client: [msg1, msg2, msg4]

Client comes online, syncs:
1. Send changes (msg4) to server
2. Receive server changes (msg3)
3. Merge: [msg1, msg2, msg3, msg4]

Result: Both have complete data
```

**Vector Clock for Causality**
```
Track: Who modified what when?

Example:
Device A: Adds msg4, vector_clock = [A:1, B:0]
Device B: Adds msg5, vector_clock = [A:0, B:1]

If conflict (both edit msg3):
Device A: Edits msg3, vector_clock = [A:2, B:0]
Device B: Edits msg3, vector_clock = [A:0, B:2]

Server detects: Both edited msg3 (no common ancestor)
→ Conflict! Show to user or merge automatically
```

### Handling Stale Data

**Problem: Device offline, server gets updated, device returns online**
```
Timeline:
T0: Device A in sync with server
    Both: Profile name = "Alice"

T0-T100: Device A offline
T50: Device B updates profile (on server): name = "Bob"

T100: Device A comes online
Device A: name = "Alice" (stale)
Server: name = "Bob" (current)

Solution:
- App detects stale data (server version newer)
- Show update notification to user
- Fetch fresh data
- Update local
```

**Version Numbers**
```
Track: Which version of data you have

Server: {name: "Bob", version: 2}
Client: {name: "Alice", version: 1}

Sync:
- Client says: "I have version 1"
- Server says: "You need version 2"
- Server sends update with version 2
- Client updates and stores version 2

Next sync:
- Client says: "I have version 2"
- Server says: "You're current"
- No data transfer
```

---

## Real-World Examples {#examples}

### Example 1: Gmail (Email Offline)

```
Requirements:
- Read offline (user might be on plane)
- Compose offline (save draft)
- Send offline (queue and send when online)

Architecture:
[Client (local DB)] ←sync→ [Server]

Local DB stores:
- Downloaded emails (last 7 days for offline)
- Draft emails (waiting to send)
- Sent emails (for local verification)

Sync process:
1. Download new emails (since last sync)
2. Upload drafts (mark as draft on server)
3. Upload sent (mark as sent on server)
4. Delete archived (if user archived offline)

Offline experience:
- User reads downloaded emails
- Composes new email (saved as draft)
- When online: Draft sent, becomes official email
- If user deletes draft: Deleted before send (still draft)
- If user sends: Email queued, sent when online
```

### Example 2: Google Maps (Navigation Offline)

```
Requirements:
- Route planning offline
- Maps offline (tile-based)
- Turn-by-turn navigation offline

Architecture:
[Tiles cache (100-500 MB per region)]
[Route engine (cached)]

Pre-download:
- Region map tiles (stored locally)
- Route graph (simplified for size)

Offline navigation:
- Use GPS (works without network)
- Match to cached tiles
- Use cached route graph for new routes
- Show current position, next turn

Online when network available:
- Update map tiles (if new regions)
- Improve routing (use real-time traffic)

Challenge:
- Map tiles large (500 MB = significant storage)
- Route graph needs compression
- Solution: Only download needed regions
```

### Example 3: Spotify (Music Offline)

```
Requirements:
- Download for offline listening
- Show cached playlists
- Download progress tracking

Architecture:
[Downloaded songs (storage)] [Cached metadata] [Queue]

Offline features:
- Play downloaded songs (full fidelity)
- Show playlists (cached metadata)
- No new recommendations (requires network)

Sync:
1. Download songs (to local storage)
2. Download playlist metadata
3. Track download progress
4. When online: Update recommendations, refresh metadata

Challenge:
- Each song 5-10 MB
- Playlist 30+ songs = 150-300 MB per playlist
- Solution: User selects playlists to download (not automatic)
- Cleanup: Delete oldest playlists if storage full
```

---

## Mobile vs Web Trade-offs {#tradeoffs}

### Design Decisions

| Aspect | Mobile | Web | Why Different |
|--------|--------|-----|--------------|
| **Data Sync** | Offline-first (local DB) | Server-first (REST) | Mobile unreliable network |
| **Updates** | Opt-in (user control) | Auto (background) | Mobile users control data usage |
| **Caching** | Aggressive (store everything) | Minimal (HTTP cache) | Mobile storage limited but crucial |
| **Images** | Multiple sizes, progressive | Single size, lazy load | Mobile varies screen size |
| **Latency** | < 500ms acceptable | < 1s acceptable | Mobile users expect less |
| **Requests** | Batch (fewer calls) | Individual (RESTful) | Mobile radio battery drain |
| **State** | Local DB | Session server-side | Mobile sessions unreliable |

### Common Pitfalls

**Pitfall 1: Assuming Always Connected**
```
❌ Bad design:
- No offline support
- No retry logic
- No caching

✅ Good design:
- Offline mode (show cached data)
- Automatic retry (exponential backoff)
- Aggressive caching
```

**Pitfall 2: Ignoring Battery**
```
❌ Bad design:
- Poll every 10 seconds
- Upload every change immediately
- No data compression

✅ Good design:
- Push notifications
- Batch uploads
- Compress all data
```

**Pitfall 3: Large Payloads**
```
❌ Bad design:
- Send full user object (100 KB) for every request
- No pagination (load all items)
- Uncompressed images (5 MB each)

✅ Good design:
- Send only needed fields
- Pagination (load 20 items, user scrolls for more)
- Compressed images (500 KB after optimization)
```

---

## Interview Framework {#interview}

### Example Question: Design Offline-First Chat

**Requirements**
```
- Users can send messages offline
- Messages sync when online
- Handle conflicts (both sent messages offline, now online)
- Minimize battery drain
```

**High-Level Design**
```
[Mobile App]
  ↓ Local DB (SQLite)
    [Messages table] [Sync queue] [Vector clocks]
  ↓ Network layer
[Server]
  ↓ Database
    [Canonical messages]
```

**Components**

1. **Local Database**
```
Messages:
- id (locally unique, changes on server)
- content
- timestamp
- local_id (for offline dedup)
- vector_clock [device_A:1, device_B:2]

Sync queue:
- action (add, edit, delete)
- object (message, user, etc.)
- payload
- retry_count
```

2. **Sync Engine**
```
On network available:
1. Pull server changes (changes since last_sync_timestamp)
2. Merge with local (conflict resolution via vector clock)
3. Push local changes (send sync queue)
4. Acknowledge (remove from queue)

Conflict resolution:
- Same message edited by both: Vector clock shows who's newer
- Both deleted: Deletion wins
- One edited, one deleted: Deletion wins
```

3. **Battery Optimization**
```
- No polling (use WebSocket push)
- Batch sends (accumulate 100ms)
- Compress payloads (gzip)
- Local-first (no network for reads)
```

### Evaluation Criteria

**Good Answer Includes:**
- [ ] Offline support (local database)
- [ ] Sync strategy (delta, timestamps, vector clocks)
- [ ] Conflict resolution (clear rules)
- [ ] Battery optimization (batching, push)
- [ ] Error handling (network failures, sync errors)
- [ ] Monitoring (sync success rate, latency)

**Great Answer Also Includes:**
- [ ] Trade-offs (eventual consistency acceptable?)
- [ ] Storage management (cleanup old messages)
- [ ] Data integrity (checksums, validation)
- [ ] User experience (show sync status, errors)

---

**Key Takeaway**: Mobile systems require fundamentally different architecture than web systems. Design for offline-first, battery-first, network-unreliable. Everything else flows from these constraints.
