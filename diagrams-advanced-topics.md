# 🎨 Visual Diagrams — Advanced Topics

> Mermaid diagrams for every advanced concept. Renders on GitHub, VS Code (Markdown Preview Enhanced), GitLab, Obsidian.

---

## 📋 Table of Contents

1. [Kafka Architecture & Partitioning](#1-kafka-architecture--partitioning)
2. [Kafka Consumer Groups & Rebalancing](#2-kafka-consumer-groups--rebalancing)
3. [Consistent Hashing Ring](#3-consistent-hashing-ring)
4. [Bloom Filter Bit Array](#4-bloom-filter-bit-array)
5. [Event Sourcing vs Traditional State Store](#5-event-sourcing-vs-traditional-state-store)
6. [CQRS — Command vs Query Split](#6-cqrs--command-vs-query-split)
7. [WebSocket vs SSE vs Long Polling](#7-websocket-vs-sse-vs-long-polling)
8. [Redis Data Structure Decision Tree](#8-redis-data-structure-decision-tree)
9. [CAP Theorem — Venn Diagram](#9-cap-theorem--venn-diagram)
10. [Distributed Tracing — Span Tree](#10-distributed-tracing--span-tree)
11. [Message Delivery Guarantees](#11-message-delivery-guarantees)
12. [CDN Request Flow](#12-cdn-request-flow)

---

## 1. Kafka Architecture & Partitioning

```mermaid
flowchart TD
    subgraph Producers["📤 Producers"]
        P1[Order Service]
        P2[Payment Service]
    end

    subgraph KafkaCluster["🟠 Kafka Cluster"]
        subgraph Topic["Topic: orders — 3 Partitions"]
            PAR0["Partition 0\ncustomerId hash % 3 = 0\n[msg0][msg3][msg6]"]
            PAR1["Partition 1\ncustomerId hash % 3 = 1\n[msg1][msg4][msg7]"]
            PAR2["Partition 2\ncustomerId hash % 3 = 2\n[msg2][msg5][msg8]"]
        end
        ZK[ZooKeeper / KRaft\nLeader election\nMetadata]
    end

    subgraph CG1["👥 Consumer Group: payment-service"]
        C1[Consumer 1\n← Partition 0]
        C2[Consumer 2\n← Partition 1]
        C3[Consumer 3\n← Partition 2]
    end

    subgraph CG2["👥 Consumer Group: analytics-service"]
        C4[Consumer 4\n← ALL partitions]
    end

    P1 -->|key=customerId| PAR0 & PAR1 & PAR2
    P2 -->|key=customerId| PAR0 & PAR1 & PAR2
    PAR0 --> C1
    PAR1 --> C2
    PAR2 --> C3
    PAR0 & PAR1 & PAR2 --> C4

    style KafkaCluster fill:#FF6F00,color:#000
    style CG1 fill:#1a237e,color:#fff
    style CG2 fill:#1b5e20,color:#fff
```

---

## 2. Kafka Consumer Groups & Rebalancing

```mermaid
sequenceDiagram
    participant P0 as Partition 0
    participant P1 as Partition 1
    participant P2 as Partition 2
    participant C1 as Consumer 1
    participant C2 as Consumer 2
    participant C3 as Consumer 3 (crashes)

    note over C1,C3: Initial Assignment
    P0-->>C1: assigned
    P1-->>C2: assigned
    P2-->>C3: assigned

    C3->>C3: 💥 Crashes

    note over C1,C2: Rebalance Triggered — all consumption pauses
    P0-->>C1: re-assigned ✅
    P1-->>C2: re-assigned ✅
    P2-->>C1: re-assigned (C2 or C1) ✅

    note over C1,C2: Consumption resumes from last committed offset
```

```mermaid
flowchart LR
    subgraph Rule["⚡ Parallelism Rule"]
        R1["6 partitions + 6 consumers\n→ 1 partition each\n✅ Maximum parallelism"]
        R2["6 partitions + 3 consumers\n→ 2 partitions each\n✅ Still works"]
        R3["6 partitions + 8 consumers\n→ 2 consumers IDLE\n⚠️ Wasted resources"]
    end
```

---

## 3. Consistent Hashing Ring

```mermaid
flowchart TD
    subgraph Ring["Hash Ring — 0 to 2³²"]
        direction LR
        SA["Server A\nposition: 10"]
        SB["Server B\nposition: 80"]
        SC["Server C\nposition: 200"]

        K1["Key: 'user:123'\nhash=15\n→ clockwise → Server B"]
        K2["Key: 'order:456'\nhash=90\n→ clockwise → Server C"]
        K3["Key: 'session:789'\nhash=220\n→ wrap around → Server A"]
    end

    AddServer["➕ Add Server D at position 50\nOnly keys between A(10) and D(50)\nare remapped — ~25% of keys\n\n✅ Old approach: ALL keys remapped\n✅ Consistent hashing: 1/N remapped"]

    style SA fill:#1565C0,color:#fff
    style SB fill:#2e7d32,color:#fff
    style SC fill:#880E4F,color:#fff
    style AddServer fill:#FF6F00,color:#fff
```

```mermaid
flowchart LR
    subgraph VNodes["Virtual Nodes (150 per server)"]
        VA1["A-vnode-1\npos: 5"]
        VB1["B-vnode-1\npos: 15"]
        VA2["A-vnode-2\npos: 40"]
        VC1["C-vnode-1\npos: 60"]
        VB2["B-vnode-2\npos: 90"]
        VC2["C-vnode-2\npos: 130"]
        VA3["A-vnode-3\npos: 170"]
    end
    Benefit["✅ Each server handles ~33% of ring\n✅ Even load distribution\n✅ Adding server: only 1/N+1 remapped\n✅ Removing server: graceful redistribution"]
    style Benefit fill:#1b5e20,color:#fff
```

---

## 4. Bloom Filter Bit Array

```mermaid
flowchart TD
    subgraph BF["Bloom Filter — Bit Array of size 10"]
        B0["[0]"] & B1["[1]"] & B2["[2]"] & B3["[3]"] & B4["[4]"]
        B5["[5]"] & B6["[6]"] & B7["[7]"] & B8["[8]"] & B9["[9]"]
    end

    ADD["ADD 'apple':\nhash1('apple') = 2 → bit[2]=1\nhash2('apple') = 5 → bit[5]=1\nhash3('apple') = 9 → bit[9]=1"]

    CHK1["CHECK 'apple':\nbit[2]=1 ✅ bit[5]=1 ✅ bit[9]=1 ✅\n→ 'Probably YES'"]

    CHK2["CHECK 'mango':\nhash1=2 → bit[2]=1 ✅\nhash2=7 → bit[7]=0 ❌\n→ 'Definitely NO' — not in set"]

    ADD --> BF
    BF --> CHK1
    BF --> CHK2

    NOTE["⚠️ False Positives POSSIBLE\n❌ False Negatives NEVER\n\nUse: cache stampede prevention\nUsername availability check\nMalicious URL detection"]

    style CHK1 fill:#F57F17,color:#fff
    style CHK2 fill:#1b5e20,color:#fff
    style NOTE fill:#1565C0,color:#fff
```

---

## 5. Event Sourcing vs Traditional State Store

```mermaid
flowchart LR
    subgraph Traditional["📦 Traditional — Store Current State"]
        DB1[("orders table\nid=123\nstatus=Shipped\ntotal=99.99\n❌ Cannot answer:\n'What was status 3 days ago?'")]
        Op1[UPDATE orders\nSET status='Shipped'\nWHERE id=123] --> DB1
    end

    subgraph EventSourced["📜 Event Sourcing — Store Events"]
        EV1["1. OrderCreated {total:99.99}"]
        EV2["2. PaymentReceived {txn:'abc'}"]
        EV3["3. ItemShipped {track:'UPS123'}"]
        EV4["4. OrderDelivered {}"]
        STATE["Current state =\nReplay events 1→4\n\n✅ Full audit trail FREE\n✅ Time-travel queries\n✅ Replay for debug"]
        EV1 --> EV2 --> EV3 --> EV4 --> STATE
    end

    style Traditional fill:#c62828,color:#fff
    style EventSourced fill:#1b5e20,color:#fff
```

```mermaid
flowchart TD
    CMD[Business Command\norder.Ship trackingNo] --> RAISE
    RAISE[RaiseEvent\nOrderShippedEvent] --> APPLY
    APPLY[Apply — update in-memory state\nStatus = Shipped] --> QUEUE
    QUEUE[Add to UncommittedEvents] --> SAVE
    SAVE[Save to Event Store\nAppend-only] --> PUB
    PUB[Publish integration events\nfor read model sync]

    LOAD["Load Aggregate\nRehydrate from event history\n↓\nforeach event: Apply(event)"]

    SNAP["Snapshot every 100 events\n{ state, version: 100 }\nLoad: snapshot + events since\nMax 100 events to replay"]
```

---

## 6. CQRS — Command vs Query Split

```mermaid
flowchart TD
    CLIENT([API Client])

    subgraph WriteModel["✍️ Write Model — Commands"]
        CMD2[CreateOrderCommand]
        VB2[Validation\nBusiness Rules]
        DOM[Domain Model\nOrder Aggregate\nFull validation\nChange tracking]
        WDB[("Write DB\nSQL Server\nNormalised OLTP")]
        EVTBUS[Event Bus\nPublish integration events]
    end

    subgraph ReadModel["📖 Read Model — Queries"]
        QRY2[GetOrdersQuery]
        PROJ[Query Handler\nAsNoTracking\nFlat projections\nNo business rules]
        RDB[("Read DB\nSame DB or Replica\nor Redis / Elasticsearch\nDenormalised OLAP")]
    end

    subgraph Sync["🔄 Sync Write → Read"]
        HANDLER[Event Handler\nUpdates read model\nwhen write model changes]
    end

    CLIENT -->|POST /orders| CMD2 --> VB2 --> DOM --> WDB
    WDB --> EVTBUS --> HANDLER --> RDB
    CLIENT -->|GET /orders| QRY2 --> PROJ --> RDB

    style WriteModel fill:#1a237e,color:#fff
    style ReadModel fill:#1b5e20,color:#fff
    style Sync fill:#4A148C,color:#fff
```

---

## 7. WebSocket vs SSE vs Long Polling

```mermaid
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(200, 230, 200)
        note over C,S: ✅ WebSocket — Bidirectional
        C->>S: HTTP Upgrade → WebSocket
        S-->>C: 101 Switching Protocols
        C->>S: send message (any time)
        S-->>C: push message (any time)
        note over C,S: Persistent — both sides push freely
    end

    rect rgb(200, 200, 240)
        note over C,S: ✅ SSE (Server-Sent Events) — Server Push Only
        C->>S: GET /events (Accept: text/event-stream)
        S-->>C: data: {...}\n\n  (push 1)
        S-->>C: data: {...}\n\n  (push 2)
        note over C,S: One-way — server pushes, client reads
    end

    rect rgb(240, 220, 200)
        note over C,S: ⚠️ Long Polling — Simulated Push
        C->>S: GET /events (holds connection open)
        note over S: Wait for new event...
        S-->>C: 200 Event data (when ready)
        C->>S: GET /events (immediately reconnects)
        note over C,S: High overhead — new request each time
    end
```

```mermaid
flowchart LR
    subgraph Choose["Choose Your Transport"]
        Q1{Bidirectional\ncommunication?}
        Q2{Server pushes only?}
        Q3{Simple / proxy-friendly?}

        WS["✅ WebSocket\nChat, games, collab edit\nReal-time bidirectional"]
        SSE2["✅ SSE\nNotifications, feeds\nOrder status updates"]
        LP["⚠️ Long Polling\nLegacy fallback only"]

        Q1 -->|Yes| WS
        Q1 -->|No| Q2
        Q2 -->|Yes| Q3
        Q3 -->|Yes| SSE2
        Q3 -->|No| WS
        Q2 -->|No| LP
    end

    style WS fill:#1565C0,color:#fff
    style SSE2 fill:#2e7d32,color:#fff
    style LP fill:#757575,color:#fff
```

---

## 8. Redis Data Structure Decision Tree

```mermaid
flowchart TD
    START([What do I need to store?])

    Q1{Single value\nor counter?}
    Q2{Object with\nmultiple fields?}
    Q3{Ordered by score\nor rank?}
    Q4{Unique members\nonly?}
    Q5{Ordered list\nor queue?}
    Q6{Time-series\nor event stream?}
    Q7{Approximate count\nof unique items?}
    Q8{Per-user boolean\nflags compact?}

    STR["STRING\nGET/SET/INCR\nCache, sessions\nrate limit counters"]
    HASH["HASH\nHGET/HSET\nUser profile\n{ name, age, email }"]
    ZSET["SORTED SET\nZADD/ZRANGE\nLeaderboards\nScheduled jobs"]
    SET["SET\nSADD/SISMEMBER\nOnline users\nUnique tags"]
    LIST["LIST\nLPUSH/RPOP\nSimple queue\nActivity feed"]
    STREAM["STREAM\nXADD/XREAD\nEvent log\nKafka-lite"]
    HLL["HYPERLOGLOG\nPFADD/PFCOUNT\nUnique visitors\n~1% error, 12KB max"]
    BIT["BITMAP\nSETBIT/BITCOUNT\nDaily active users\n1 bit per user"]

    START --> Q1
    Q1 -->|Yes| STR
    Q1 -->|No| Q2
    Q2 -->|Yes| HASH
    Q2 -->|No| Q3
    Q3 -->|Yes| ZSET
    Q3 -->|No| Q4
    Q4 -->|Yes| SET
    Q4 -->|No| Q5
    Q5 -->|Yes| LIST
    Q5 -->|No| Q6
    Q6 -->|Yes| STREAM
    Q6 -->|No| Q7
    Q7 -->|Yes| HLL
    Q7 -->|No| Q8
    Q8 -->|Yes| BIT

    style STR fill:#1565C0,color:#fff
    style HASH fill:#2e7d32,color:#fff
    style ZSET fill:#880E4F,color:#fff
    style SET fill:#4A148C,color:#fff
    style LIST fill:#006064,color:#fff
    style STREAM fill:#FF6F00,color:#fff
    style HLL fill:#37474F,color:#fff
    style BIT fill:#BF360C,color:#fff
```

---

## 9. CAP Theorem — Venn Diagram

```mermaid
flowchart TD
    subgraph CAP["CAP Theorem — Network Partitions Always Happen"]
        direction LR

        subgraph CP["CP — Consistency + Partition\n🔵 ZooKeeper, HBase, MongoDB (strong)"]
            CP1["During partition:\nRefuse writes on minority side\n→ Stay consistent\n→ Sacrifice availability"]
        end

        subgraph AP["AP — Availability + Partition\n🟢 Cassandra, DynamoDB, CouchDB"]
            AP1["During partition:\nBoth sides accept writes\n→ Stay available\n→ Reconcile on recovery"]
        end

        subgraph CA["CA — Consistency + Availability\n❌ Impossible in distributed systems"]
            CA1["Only possible on single node\n(no partition to tolerate)\nTraditional RDBMS\non one machine only"]
        end
    end

    PACELC["📌 PACELC Extension\nEven when no Partition (Else):\nChoose Latency vs Consistency\n\nDynamoDB: EL (low latency, eventual)\nPostgreSQL: EC (consistent, slower reads)"]

    style CP fill:#1a237e,color:#fff
    style AP fill:#1b5e20,color:#fff
    style CA fill:#757575,color:#fff
    style PACELC fill:#FF6F00,color:#fff
```

---

## 10. Distributed Tracing — Span Tree

```mermaid
flowchart TD
    subgraph Trace["Trace ID: abc123 — Total: 250ms"]
        direction TB
        ROOT["API Gateway\nSpanId: span1, Parent: null\n0ms → 250ms"]
        OS3["Order Service\nSpanId: span2, Parent: span1\n5ms → 200ms"]
        PS3["Payment Service\nSpanId: span3, Parent: span2\n10ms → 150ms"]
        FS["Fraud Service\nSpanId: span4, Parent: span3\n20ms → 80ms ⚠️ SLOW"]
        IS3["Inventory Service\nSpanId: span5, Parent: span2\n155ms → 190ms"]
        DB4[("Database\nSpanId: span6, Parent: span5\n160ms → 185ms")]
    end

    ROOT --> OS3
    OS3 --> PS3
    PS3 --> FS
    OS3 --> IS3
    IS3 --> DB4

    NOTE2["🔍 Bottleneck found:\nFraud Service takes 60ms\nInvestigate → add caching"]

    style ROOT fill:#1565C0,color:#fff
    style FS fill:#c62828,color:#fff
    style NOTE2 fill:#FF6F00,color:#fff
```

```mermaid
flowchart LR
    subgraph OTel["OpenTelemetry Pipeline"]
        APP[.NET App\nActivity.StartActivity] --> COL
        COL[OTel Collector\nreceive → process → export]
        COL --> JAE[Jaeger\nTrace UI]
        COL --> AZM[Azure Monitor\nApplication Insights]
        COL --> PROM2[Prometheus\nMetrics]
    end

    HEADER["traceparent header propagated:\n00-abc123-span1-01\nPassed between services automatically\nvia HttpClient instrumentation"]

    style COL fill:#FF6F00,color:#fff
```

---

## 11. Message Delivery Guarantees

```mermaid
flowchart TD
    subgraph Semantics["Message Delivery Semantics"]
        AMO["At-Most-Once\n🔥 Fire and forget\nMessage may be lost\n✅ Fastest\n❌ Data loss possible\nUse: metrics, logs (loss OK)"]
        ALO["At-Least-Once\n♻️ Retry until ACK\nMessage may duplicate\n✅ No data loss\n⚠️ Consumer must be idempotent\nUse: ✅ Most systems"]
        EO["Exactly-Once\n🎯 One and only one\n❌ Slowest (2-phase commit)\n✅ No loss, no duplicate\n⚠️ Kafka transactions only\nUse: Financial, payments"]
    end

    subgraph Fix["Making ALO Safe"]
        IDEM["Idempotent Consumer\n1. Check EventId in processed_events table\n2. If found → skip (return early)\n3. If not found → process + record\nAll in one transaction\n✅ ALO + idempotency = effectively Exactly-Once"]
    end

    ALO --> Fix

    style AMO fill:#757575,color:#fff
    style ALO fill:#1565C0,color:#fff
    style EO fill:#880E4F,color:#fff
    style IDEM fill:#1b5e20,color:#fff
```

---

## 12. CDN Request Flow

```mermaid
sequenceDiagram
    participant U as User (Mumbai)
    participant E as CDN Edge (Mumbai)
    participant S as CDN Shield (Singapore)
    participant O as Origin Server (US East)

    U->>E: GET /images/logo.png

    alt Cache HIT at Edge (~3ms)
        E-->>U: 200 logo.png (from edge cache)
        note over E: ⚡ 3ms — fastest path
    else Cache MISS at Edge
        E->>S: Forward request
        alt Cache HIT at Shield (~20ms)
            S-->>E: 200 logo.png
            E-->>U: 200 logo.png (cache at edge now)
            note over S: ⚡ 20ms — shield hit
        else Cache MISS at Shield
            S->>O: Forward to origin (~200ms)
            O-->>S: 200 logo.png
            note over S: Cache at shield
            S-->>E: 200 logo.png
            note over E: Cache at edge
            E-->>U: 200 logo.png
            note over O: 🐢 200ms — origin miss
        end
    end
```

```mermaid
flowchart LR
    subgraph CacheHeaders["Cache-Control Header Strategy"]
        STATIC["Static Assets\n/app.a1b2c3.js\nCache-Control: public, max-age=31536000, immutable\n✅ Cache forever (content-hash in filename)\n✅ No invalidation needed — new filename = new file"]
        API2["Public API\n/api/products\nCache-Control: public, max-age=60, s-maxage=300\n✅ Browser: 1min · CDN: 5min"]
        PRIV["Private/Authenticated\n/api/cart\nCache-Control: private, no-store\n❌ Never cache at CDN"]
        STALE["Stale-While-Revalidate\nCache-Control: max-age=60, stale-while-revalidate=600\n✅ Serve stale immediately\n✅ Revalidate in background\n✅ No user waits"]
    end

    style STATIC fill:#1b5e20,color:#fff
    style API2 fill:#1565C0,color:#fff
    style PRIV fill:#c62828,color:#fff
    style STALE fill:#880E4F,color:#fff
```

EOF
echo "Done diagrams-advanced-topics.md"