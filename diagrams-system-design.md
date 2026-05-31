# 🎨 Visual Diagrams — System Design

> Sequence diagrams, architecture flows, and decision trees for every major system design.

---

## 📋 Table of Contents

1. [URL Shortener — End-to-End Flow](#1-url-shortener--end-to-end-flow)
2. [Notification System Architecture](#2-notification-system-architecture)
3. [Rate Limiter — Token Bucket Flow](#3-rate-limiter--token-bucket-flow)
4. [File Upload — Chunked Presigned Flow](#4-file-upload--chunked-presigned-flow)
5. [Payment System — Idempotency Flow](#5-payment-system--idempotency-flow)
6. [Chat System — WebSocket Architecture](#6-chat-system--websocket-architecture)
7. [Saga Pattern — Choreography vs Orchestration](#7-saga-pattern--choreography-vs-orchestration)
8. [Dead Letter Queue (DLQ) Lifecycle](#8-dead-letter-queue-dlq-lifecycle)
9. [Retry + Exponential Backoff](#9-retry--exponential-backoff)
10. [Large File Import — Production Flow](#10-large-file-import--production-flow)
11. [Idempotency Key Pattern](#11-idempotency-key-pattern)
12. [System Design Selection Guide](#12-system-design-selection-guide)

---

## 1. URL Shortener — End-to-End Flow

```mermaid
flowchart LR
    subgraph WriteFlow["✍️ Write — Shorten URL"]
        CW([Client]) -->|POST /shorten\n{longUrl}| API_W[API Service]
        API_W --> IDG[ID Generator\nSnowflake / Auto-increment]
        IDG --> B62[Base62 Encoder\n123456 → 'aB3xZ9']
        B62 --> DB_W[("PostgreSQL\ncode → long_url")]
        B62 --> CACHE_W[("Redis Cache\nWarm after write")]
        DB_W --> API_W
        API_W -->|{ shortUrl: 'short.ly/aB3xZ9' }| CW
    end

    subgraph ReadFlow["📖 Read — Redirect"]
        CR([Client]) -->|GET /aB3xZ9| CDN2[CDN Edge\nCache popular codes]
        CDN2 -->|miss| LB[Load Balancer]
        LB --> API_R[API Service]
        API_R --> CACHE_R[("Redis\nO(1) lookup")]
        CACHE_R -->|hit| REDIR["301/302 Redirect"]
        CACHE_R -->|miss| DB_R[("PostgreSQL\nRead Replica")]
        DB_R --> CACHE_R
        DB_R --> REDIR
        REDIR --> CR
    end

    style CDN2 fill:#1565C0,color:#fff
    style CACHE_R fill:#FF9800,color:#fff
    style REDIR fill:#2e7d32,color:#fff
```

```mermaid
flowchart TD
    subgraph Base62["Base62 Encoding — Why?"]
        CHARS["Chars: a-z A-Z 0-9 = 62 symbols"]
        FORMULA["Code length 6: 62⁶ = 56 billion unique codes"]
        EXAMPLE["ID: 1,000,000\n÷62 = 16129 rem 16 → 'q'\n÷62 = 260 rem 9 → '9'\n... → 'aB3xZ9'"]
        ADV["✅ No collision check needed (ID is unique)\n✅ Shorter than UUID\n✅ URL-safe characters"]
    end
```

---

## 2. Notification System Architecture

```mermaid
flowchart TD
    subgraph Triggers["📡 Event Triggers"]
        OS4[Order Service] & AUTH[Auth Service] & BILL[Billing Service]
    end

    NS[Notification Service\nValidate preferences\nRender template\nRoute to channel]

    subgraph Queues["📬 Per-Channel Queues"]
        EQ[Email Queue]
        SMSQ[SMS Queue]
        PQ[Push Queue]
    end

    subgraph Workers["⚙️ Channel Workers"]
        EW[Email Worker] --> SG[SendGrid]
        SW[SMS Worker] --> TW[Twilio]
        PW[Push Worker] --> FCM[FCM / APNs]
    end

    DLQ2[Dead Letter Queue\n🚨 Alert on failures]
    DB5[("Notifications DB\nstatus tracking")]
    PREFS[("User Preferences\nopt-out per channel")]

    Triggers --> NS
    NS --> PREFS
    PREFS -->|enabled| NS
    PREFS -->|opted out| DROP[🗑️ Drop silently]
    NS --> EQ & SMSQ & PQ
    EQ --> EW
    SMSQ --> SW
    PQ --> PW
    EW & SW & PW -->|failure × maxRetries| DLQ2
    EW & SW & PW --> DB5

    style NS fill:#1565C0,color:#fff
    style DLQ2 fill:#c62828,color:#fff
    style DROP fill:#757575,color:#fff
```

```mermaid
sequenceDiagram
    participant OS5 as Order Service
    participant NS2 as Notification Service
    participant Q as Message Queue
    participant EW2 as Email Worker
    participant SG2 as SendGrid

    OS5->>NS2: OrderShipped event
    NS2->>NS2: Check user prefs (email enabled?)
    NS2->>NS2: Render template with order data
    NS2->>Q: Enqueue email job { to, subject, body }

    loop Worker polls queue
        Q-->>EW2: Dequeue email job
        EW2->>SG2: POST /mail/send\nIdempotency-Key: notif:{id}
        alt SendGrid success
            SG2-->>EW2: 202 Accepted
            EW2->>Q: ACK message
            EW2->>NS2: UPDATE status = sent
        else SendGrid failure
            SG2-->>EW2: 500 / timeout
            EW2->>Q: NACK (retry)
            note over EW2,Q: Retry with backoff
        end
    end
```

---

## 3. Rate Limiter — Token Bucket Flow

```mermaid
flowchart TD
    REQ2([Incoming Request]) --> EXTRACT[Extract Partition Key\nuserId / IP / API key]
    EXTRACT --> REDIS2[("Redis\nToken Bucket per key")]
    REDIS2 --> REFILL2[Calculate refill:\nelapsed × tokensPerSec]
    REFILL2 --> CHECK2{Tokens ≥ 1?}
    CHECK2 -->|Yes| CONSUME2[Consume 1 token\nAtomic Lua script]
    CHECK2 -->|No| DENY2["❌ 429 Too Many Requests\nRetry-After: 1\nX-RateLimit-Remaining: 0"]
    CONSUME2 --> ALLOW2["✅ Allow request\nX-RateLimit-Remaining: n\nX-RateLimit-Reset: epoch"]
    ALLOW2 --> NEXT[Next Middleware\n→ Controller]

    style DENY2 fill:#c62828,color:#fff
    style ALLOW2 fill:#2e7d32,color:#fff
    style REDIS2 fill:#FF9800,color:#fff
```

```mermaid
flowchart LR
    subgraph Algorithms["Rate Limiting Algorithms Compared"]
        FW["Fixed Window\nSimple — reset every N seconds\n⚠️ Edge burst: 2× limit at boundary"]
        SW2["Sliding Window Log\nPrecise — store each request timestamp\n⚠️ High memory: O(requests)"]
        SWC["Sliding Window Counter\nBalance — approx using two windows\n✅ Low memory, good precision"]
        TB["Token Bucket ✅ RECOMMENDED\nBurst allowed up to bucket size\nSmooth sustained rate\nLow memory: O(1) per key"]
        LB2["Leaky Bucket\nFixed output rate\nQueue absorbs burst\nGood for smoothing spikes"]
    end

    style TB fill:#1b5e20,color:#fff
    style FW fill:#757575,color:#fff
```

---

## 4. File Upload — Chunked Presigned Flow

```mermaid
sequenceDiagram
    participant C2 as Client (Browser)
    participant API3 as Upload API
    participant BLOB as Azure Blob / S3
    participant Q2 as Job Queue
    participant WRK as Background Worker

    C2->>API3: POST /uploads/initiate\n{ fileName, fileSizeBytes }
    API3->>API3: Generate uploadId\nCalculate chunks (5MB each)
    API3->>BLOB: Generate N presigned PUT URLs
    BLOB-->>API3: presignedUrls[]
    API3-->>C2: { uploadId, presignedUrls[] }

    note over C2: Upload chunks IN PARALLEL directly to Blob

    par Chunk 1
        C2->>BLOB: PUT presignedUrls[0] (chunk 1)
        BLOB-->>C2: 200 ETag: "abc"
    and Chunk 2
        C2->>BLOB: PUT presignedUrls[1] (chunk 2)
        BLOB-->>C2: 200 ETag: "def"
    and Chunk 3
        C2->>BLOB: PUT presignedUrls[2] (chunk 3)
        BLOB-->>C2: 200 ETag: "ghi"
    end

    C2->>API3: POST /uploads/{uploadId}/complete\n{ etags[] }
    API3->>BLOB: CommitBlockList (assemble chunks)
    BLOB-->>API3: Final URL
    API3->>Q2: Enqueue post-processing\n{ fileId, type: "scan+thumbnail" }
    API3-->>C2: 200 { fileId, downloadUrl }

    par Background Processing
        Q2-->>WRK: Virus scan
        Q2-->>WRK: Thumbnail generation
        Q2-->>WRK: CDN invalidation
    end
```

---

## 5. Payment System — Idempotency Flow

```mermaid
sequenceDiagram
    participant C3 as Client
    participant PS2 as Payment Service
    participant LOCK as Distributed Lock\n(Redis)
    participant IDEM as Idempotency Store\n(DB / Redis)
    participant STRIPE as Stripe / Provider
    participant DB6 as Payments DB

    C3->>PS2: POST /payments\nIdempotency-Key: "key-abc"\n{ amount, card }

    PS2->>IDEM: GET key-abc
    alt Already processed
        IDEM-->>PS2: Cached result
        PS2-->>C3: 200 Same response (replay)
        note over C3,PS2: ✅ Safe retry — no duplicate charge
    else First time
        PS2->>LOCK: ACQUIRE lock on "key-abc"
        LOCK-->>PS2: Lock acquired ✅
        PS2->>DB6: INSERT payment { status: processing }
        DB6-->>PS2: Saved

        PS2->>STRIPE: POST /charges { amount, source }
        alt Stripe success
            STRIPE-->>PS2: { chargeId, status: succeeded }
            PS2->>DB6: UPDATE status = succeeded
            PS2->>IDEM: STORE key-abc → { 201, body }
            PS2->>LOCK: RELEASE lock
            PS2-->>C3: 201 Created { paymentId }
        else Stripe failure
            STRIPE-->>PS2: error
            PS2->>DB6: UPDATE status = failed
            PS2->>LOCK: RELEASE lock
            PS2-->>C3: 402 Payment Required
        end
    end
```

---

## 6. Chat System — WebSocket Architecture

```mermaid
flowchart TD
    subgraph Clients["📱 Clients"]
        CA([Alice Browser]) & CB([Bob Mobile])
    end

    subgraph WSLayer["🔌 WebSocket Layer"]
        WS1[WS Server 1\nAlice connected] & WS2[WS Server 2\nBob connected]
    end

    subgraph Presence["👁️ Presence Service"]
        REDIS3[("Redis\npresence:{userId} → serverId\nTTL: 5min\nHeartbeat refreshes")]
    end

    subgraph Persistence["💾 Persistence"]
        CASS[("Cassandra\nmessages table\nPARTITION BY conversation_id\nCLUSTER BY message_id DESC")]
    end

    PUBSUB["Redis Pub/Sub\nFan-out to correct WS server"]

    CA -->|WS connection| WS1
    CB -->|WS connection| WS2
    WS1 <--> REDIS3
    WS2 <--> REDIS3
    WS1 -->|save message| CASS
    WS1 -->|PUBLISH conv:123| PUBSUB
    PUBSUB -->|SUBSCRIBE conv:123| WS2
    WS2 -->|push to Bob| CB

    style REDIS3 fill:#FF9800,color:#fff
    style CASS fill:#1565C0,color:#fff
    style PUBSUB fill:#880E4F,color:#fff
```

```mermaid
sequenceDiagram
    participant A as Alice (Server 1)
    participant R as Redis Pub/Sub
    participant B as Bob (Server 2)
    participant C5 as Cassandra

    A->>C5: INSERT message { convId, text, senderId }
    A->>R: PUBLISH channel:conv-123 { message }
    R->>B: DELIVER to Server 2 (Bob is here)
    B->>B: Bob connected? ✅
    B-->>B: Push via WebSocket
    note over B: Bob sees message instantly

    note over A,B: If Bob offline:
    A->>B: FCM/APNs push notification
    note over B: Bob gets push, opens app
    B->>C5: LOAD last 50 messages (from Cassandra)
```

---

## 7. Saga Pattern — Choreography vs Orchestration

```mermaid
flowchart LR
    subgraph Choreo["🎭 Choreography — Services Emit Events"]
        OS6[Order Service\nOrderPlaced →] --> EV1A[Event Bus]
        EV1A --> PAY1[Payment Service\nCharges card\n→ PaymentProcessed]
        PAY1 --> EV2A[Event Bus]
        EV2A --> INV1[Inventory Service\nReserves stock\n→ StockReserved]
        INV1 --> EV3A[Event Bus]
        EV3A --> SHIP1[Shipping Service\nSchedules delivery]

        FAIL1["❌ Stock Unavailable\n→ StockFailed event\nPayment Service listens\n→ RefundPayment\n→ PaymentRefunded\n→ Order cancelled"]
    end

    subgraph Orch["🎯 Orchestration — Central Coordinator"]
        SAGA[Saga Orchestrator\nMaintains state machine]
        SAGA -->|1. ProcessPayment| PAY2[Payment Service]
        PAY2 -->|PaymentOK| SAGA
        SAGA -->|2. ReserveStock| INV2[Inventory Service]
        INV2 -->|StockOK| SAGA
        SAGA -->|3. ScheduleShipping| SHIP2[Shipping Service]
        SHIP2 -->|ShipOK| SAGA
        SAGA -->|OrderConfirmed| DONE[✅ Complete]

        FAIL2["❌ StockFailed\nOrchestrator sees it\n→ COMPENSATE: RefundPayment\n→ COMPENSATE: CancelOrder\n✅ Clear rollback logic"]
    end

    style Choreo fill:#1a237e,color:#fff
    style Orch fill:#1b5e20,color:#fff
    style SAGA fill:#FF6F00,color:#fff
```

---

## 8. Dead Letter Queue (DLQ) Lifecycle

```mermaid
flowchart TD
    PROD([Producer]) -->|Publish| Q[Main Queue\nAzure Service Bus\nRabbitMQ / Kafka]
    Q -->|Deliver| CON[Consumer]
    CON --> PROC{Process\nsuccessfully?}
    PROC -->|Yes| ACK[✅ ACK / Complete\nMessage deleted]
    PROC -->|No — transient error| RETRY{DeliveryCount\n< MaxRetries?}
    RETRY -->|Yes| BACK[⏳ Abandon\nExponential backoff\nBack to queue]
    BACK --> Q
    RETRY -->|No — max retries| DLQ3[💀 Dead Letter Queue\nMessage moved here\n+ DeadLetterReason]
    PROC -->|Permanent error| DLQ3

    DLQ3 --> ALERT[🚨 Alert fires\nPagerDuty / Slack]
    ALERT --> REVIEW[Engineer reviews\nFixes bug or data]
    REVIEW --> REPLAY[♻️ Replay DLQ\nRe-enqueue messages]
    REPLAY --> Q

    style DLQ3 fill:#c62828,color:#fff
    style ACK fill:#2e7d32,color:#fff
    style ALERT fill:#FF6F00,color:#fff
    style REPLAY fill:#1565C0,color:#fff
```

---

## 9. Retry + Exponential Backoff

```mermaid
sequenceDiagram
    participant SVC2 as Service A
    participant DS as Downstream B (failing)

    SVC2->>DS: Request #1
    DS-->>SVC2: ❌ 503 Service Unavailable

    note over SVC2: Attempt 1 failed. Wait 250ms + jitter (~312ms)

    SVC2->>DS: Retry #2
    DS-->>SVC2: ❌ 503 Service Unavailable

    note over SVC2: Attempt 2 failed. Wait 500ms + jitter (~437ms)

    SVC2->>DS: Retry #3
    DS-->>SVC2: ❌ 503 Service Unavailable

    note over SVC2: Attempt 3 failed. Wait 1000ms + jitter (~875ms)

    note over SVC2,DS: Circuit breaker — failure rate > 50%\nCircuit OPENS for 30s

    SVC2->>DS: Any request during OPEN
    note over SVC2: ⚡ Fail fast — no request sent\nProtects downstream from thundering herd

    note over SVC2,DS: After 30s — HALF-OPEN test
    SVC2->>DS: Test request
    DS-->>SVC2: ✅ 200 OK

    note over SVC2: Circuit CLOSES — normal operation
```

```mermaid
flowchart LR
    subgraph Backoff["Exponential Backoff + Jitter"]
        A1["Attempt 1 failed\nWait: 250ms ± jitter"]
        A2["Attempt 2 failed\nWait: 500ms ± jitter"]
        A3["Attempt 3 failed\nWait: 1000ms ± jitter"]
        A4["Attempt 4 failed\nWait: 2000ms ± jitter"]
        A5["Attempt 5 failed\n→ Throw final exception\nLog + alert"]
    end

    A1 --> A2 --> A3 --> A4 --> A5

    JITTER["⚠️ Why Jitter?\n100 instances all retry at 1000ms\n→ Thundering herd on downstream\n\n✅ Jitter adds ±25% random delay\n→ Requests spread over time\n→ Downstream survives"]

    style JITTER fill:#FF6F00,color:#fff
    style A5 fill:#c62828,color:#fff
```

---

## 10. Large File Import — Production Flow

```mermaid
sequenceDiagram
    participant U as User (Browser)
    participant API4 as Import API
    participant BLOB2 as Blob Storage
    participant Q3 as Job Queue
    participant WRK2 as Import Worker
    participant DB7 as Database

    U->>API4: POST /imports\nContent-Type: multipart/form-data\nFile: 100k rows Excel

    API4->>BLOB2: Upload raw file
    BLOB2-->>API4: blobUrl

    API4->>DB7: INSERT import_job {\nstatus: queued\nblobUrl }

    API4->>Q3: Enqueue ProcessImportCommand { jobId }
    API4-->>U: 202 Accepted { jobId }\nLocation: /imports/{jobId}

    note over U: UI polls /imports/{jobId} every 2s

    Q3-->>WRK2: Dequeue job
    WRK2->>DB7: UPDATE status = processing
    WRK2->>BLOB2: Stream Excel rows (lazy, no full load)

    loop Chunks of 500 rows
        WRK2->>WRK2: Validate + transform batch
        WRK2->>DB7: BulkInsert 500 rows (single SQL)
        WRK2->>DB7: UPDATE processed_rows += 500
    end

    WRK2->>BLOB2: Upload failures.csv (if any)
    WRK2->>DB7: UPDATE status = completed\nfailed_rows, failure_report_url

    U->>API4: GET /imports/{jobId}
    API4-->>U: { status: completed, processed: 99800\nfailed: 200, reportUrl }
```

---

## 11. Idempotency Key Pattern

```mermaid
flowchart TD
    C6([Client]) -->|POST /payments\nIdempotency-Key: uuid-123| MW[Idempotency Middleware]

    MW --> CHECK3{Key exists\nin store?}

    CHECK3 -->|Yes — replay| CACHE3[("Redis / DB\nKey → Response")]
    CACHE3 --> REPLAY2["Return SAME response\nas original request\n✅ No second charge"]
    REPLAY2 --> C6

    CHECK3 -->|No — first time| LOCK2["Acquire lock on key\nPrevents concurrent race"]
    LOCK2 --> DOUBLE{"Double-check\nafter lock"}
    DOUBLE -->|Found| CACHE3
    DOUBLE -->|Still not found| EXEC[Execute business logic\nCharge card / create order]
    EXEC --> STORE["Store result:\nKey → { status, body }\nTTL: 24h"]
    STORE --> LOCK2R[Release lock]
    LOCK2R --> RESP[Return response] --> C6

    style REPLAY2 fill:#2e7d32,color:#fff
    style LOCK2 fill:#FF9800,color:#fff
    style CACHE3 fill:#1565C0,color:#fff
```

---

## 12. System Design Selection Guide

```mermaid
flowchart TD
    START2([What system to design?])

    Q1b{Real-time\ncommunication?}
    Q2b{Huge write\nthroughput?}
    Q3b{Content\ndelivery\nglobal?}
    Q4b{Search /\nfull-text?}
    Q5b{Financial\ntransactions?}
    Q6b{Large file\nprocessing?}

    CHAT2["💬 Chat / Collaboration\nWebSocket + Redis Pub/Sub\nCassandra for messages\nFCM for offline push"]
    STREAM2["📊 Event Streaming\nKafka partitioned by key\nConsumer groups per service\nCompacted topics for state"]
    CDN3["🌍 CDN + Media\nBlob Storage + CDN edge\nPresigned URLs\nContent-hash filenames"]
    SEARCH2["🔍 Search Engine\nElasticsearch / Azure Cognitive\nInverted index\nTF-IDF scoring"]
    PAY2["💳 Payment System\nIdempotency keys\nStripe/tokenisation\nEvent-driven reconciliation"]
    UPLOAD2["📁 File Upload\nChunked presigned URLs\nBackground processing\nVirus scan + thumbnail async"]

    START2 --> Q1b
    Q1b -->|Yes| CHAT2
    Q1b -->|No| Q2b
    Q2b -->|Yes| STREAM2
    Q2b -->|No| Q3b
    Q3b -->|Yes| CDN3
    Q3b -->|No| Q4b
    Q4b -->|Yes| SEARCH2
    Q4b -->|No| Q5b
    Q5b -->|Yes| PAY2
    Q5b -->|No| Q6b
    Q6b -->|Yes| UPLOAD2

    style CHAT2 fill:#1a237e,color:#fff
    style STREAM2 fill:#FF6F00,color:#fff
    style CDN3 fill:#1565C0,color:#fff
    style SEARCH2 fill:#4A148C,color:#fff
    style PAY2 fill:#880E4F,color:#fff
    style UPLOAD2 fill:#006064,color:#fff
```

EOF
echo "Done diagrams-system-design.md"