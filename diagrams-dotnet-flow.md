# 🎨 Visual Diagrams — .NET Code Flows & Architecture

> Mermaid diagrams for every major flow. Renders on GitHub, VS Code (Markdown Preview Enhanced), GitLab, and Obsidian.

---

## 📋 Table of Contents

1. [ASP.NET Core Request Pipeline](#1-aspnet-core-request-pipeline)
2. [Middleware Execution Chain](#2-middleware-execution-chain)
3. [Dependency Injection Lifecycle](#3-dependency-injection-lifecycle)
4. [Async/Await Execution Model](#4-asyncawait-execution-model)
5. [EF Core Query Flow](#5-ef-core-query-flow)
6. [JWT Authentication Flow](#6-jwt-authentication-flow)
7. [CQRS + MediatR Flow](#7-cqrs--mediatr-flow)
8. [Repository + Unit of Work](#8-repository--unit-of-work)
9. [Design Patterns — Decorator Chain](#9-design-patterns--decorator-chain)
10. [Design Patterns — State Machine (ATM)](#10-design-patterns--state-machine-atm)
11. [Design Patterns — Saga Orchestration](#11-design-patterns--saga-orchestration)
12. [Retry + Circuit Breaker](#12-retry--circuit-breaker)
13. [Outbox Pattern](#13-outbox-pattern)
14. [Rate Limiter Flow (Token Bucket)](#14-rate-limiter-flow-token-bucket)

---

## 1. ASP.NET Core Request Pipeline

```mermaid
flowchart TD
    Client([🌐 Client Browser / Mobile])
    Kestrel[Kestrel / IIS\nTCP · TLS termination]
    MW1[ExceptionHandler\nHSTS Middleware]
    MW2[HttpsRedirection\nStaticFiles]
    MW3[Routing\nResolves endpoint]
    MW4[CORS Middleware]
    MW5[Authentication\nSets HttpContext.User]
    MW6[Authorization\nChecks policies]
    MW7[RateLimiter]
    Controller[Controller / Minimal API\nModel Bind → Validate → Action]
    Service[Service Layer\nBusiness Logic]
    DB[(SQL Server\nDatabase)]
    JSON[JSON Serialization\nHTTP Response]

    Client -->|HTTP Request| Kestrel
    Kestrel --> MW1
    MW1 --> MW2
    MW2 --> MW3
    MW3 --> MW4
    MW4 --> MW5
    MW5 --> MW6
    MW6 --> MW7
    MW7 --> Controller
    Controller --> Service
    Service --> DB
    DB --> Service
    Service --> Controller
    Controller --> JSON
    JSON -->|HTTP Response| Client

    style Client fill:#4CAF50,color:#fff
    style DB fill:#2196F3,color:#fff
    style MW5 fill:#FF9800,color:#fff
    style MW6 fill:#FF5722,color:#fff
```

---

## 2. Middleware Execution Chain

```mermaid
sequenceDiagram
    participant C as Client
    participant M1 as TimingMiddleware
    participant M2 as AuthMiddleware
    participant M3 as RateLimitMiddleware
    participant EP as Endpoint / Controller

    C->>M1: HTTP Request
    note over M1: ⏱ Start stopwatch
    M1->>M2: await next(ctx)
    note over M2: 🔑 Validate JWT → set User
    M2->>M3: await next(ctx)
    note over M3: 🚦 Check rate limit
    alt Rate limit OK
        M3->>EP: await next(ctx)
        EP-->>M3: 200 OK + Body
        M3-->>M2: Response
        M2-->>M1: Response
        note over M1: ⏱ Log duration
        M1-->>C: 200 OK
    else Rate limit exceeded
        M3-->>C: 429 Too Many Requests
        note over M3: ⛔ Short-circuit — next() never called
    end
```

---

## 3. Dependency Injection Lifecycle

```mermaid
flowchart LR
    subgraph AppLifetime["🔵 App Lifetime (Singleton)"]
        S1[IAppCache\nRedisCache]
        S2[IHttpClientFactory]
        S3[ILogger]
    end

    subgraph RequestScope["🟡 Request Scope (Scoped)"]
        SC1[AppDbContext]
        SC2[IOrderService]
        SC3[ICurrentUser]
    end

    subgraph PerInjection["🟢 Per Injection (Transient)"]
        T1[IEmailBuilder]
        T2[Validator]
    end

    HTTP[HTTP Request\nArrives] --> RequestScope
    RequestScope --> AppLifetime
    RequestScope --> PerInjection

    EndReq[Request Ends\n🗑 Scoped Disposed] --> RequestScope

    style AppLifetime fill:#1565C0,color:#fff
    style RequestScope fill:#F57F17,color:#fff
    style PerInjection fill:#2E7D32,color:#fff
```

```mermaid
flowchart TD
    A[App Start] --> B[Create Singleton\nonce — lives forever]
    B --> R1[Request 1 arrives]
    R1 --> C[Create Scope]
    C --> D[Create Scoped services\none per request]
    D --> E[Create Transient\nnew every injection]
    E --> F[Process request]
    F --> G[Request ends\nDispose Scoped + Transient]
    G --> R2[Request 2 arrives\nSingleton REUSED]
    R2 --> C2[New Scope]
    C2 --> D2[New Scoped instances]
```

---

## 4. Async/Await Execution Model

```mermaid
sequenceDiagram
    participant T1 as Thread T1
    participant IO1 as Database I/O
    participant TP as Thread Pool
    participant T2 as Thread T2
    participant IO2 as SMTP I/O
    participant T3 as Thread T3

    T1->>IO1: await db.FindAsync(id)
    note over T1: T1 RELEASED back to pool
    IO1-->>TP: I/O completes → schedule continuation
    TP->>T2: Resume on T2 (may differ from T1)
    T2->>IO2: await emailService.SendAsync()
    note over T2: T2 RELEASED back to pool
    IO2-->>TP: SMTP completes → schedule continuation
    TP->>T3: Resume on T3
    T3-->>T3: return Ok(result) → response written
```

---

## 5. EF Core Query Flow

```mermaid
flowchart TD
    LINQ["LINQ Expression\n_db.Orders.Where(o => o.Status == 'Paid').Include(o => o.Customer)"]
    ET[Expression Tree\nBuilt in memory\nNO SQL yet]
    Provider[EF Core LINQ Provider\nTranslates expression → SQL AST]
    SQL["SQL Generated\nSELECT o.*, c.*\nFROM Orders o\nJOIN Customers c ON o.CustomerId = c.Id\nWHERE o.Status = 'Paid'"]
    Conn[DbConnection.OpenAsync\nPool connection]
    Exec[DbCommand.ExecuteReaderAsync\nSQL sent to DB server]
    Map[DataReader maps rows\n→ entity objects]
    CT[Change Tracker / Identity Map\nEntities tracked if default]
    Result[C# entity objects\nreturned to caller]

    ToList[".ToListAsync() called\n⚡ SQL executes HERE"] --> Conn

    LINQ --> ET --> Provider --> SQL --> ToList
    Conn --> Exec --> Map --> CT --> Result

    style ToList fill:#FF5722,color:#fff
    style SQL fill:#1565C0,color:#fff
```

```mermaid
flowchart LR
    subgraph SaveChanges["SaveChanges() Path"]
        CT2[Change Tracker\nDetects Modified/Added/Deleted]
        Gen[SQL Generator\nINSERT / UPDATE / DELETE]
        TX[Transaction\nimplicit or explicit]
        DB2[(Database)]
    end

    Modify[order.Status = 'Shipped'\nor db.Orders.Add newOrder] --> CT2
    CT2 --> Gen --> TX --> DB2
    DB2 --> |rowcount| TX
```

---

## 6. JWT Authentication Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as API Server
    participant DB as Database
    participant JWT as JWT Handler

    C->>API: POST /auth/login {username, password}
    API->>DB: Validate credentials
    DB-->>API: User found ✅
    API->>JWT: Build claims (sub, email, role, exp)
    JWT-->>API: Sign with HMAC-SHA256 / RS256
    API-->>C: 200 { token: "eyJhbGci..." }

    note over C: Stores token

    C->>API: GET /api/orders\nAuthorization: Bearer eyJhbGci...
    API->>JWT: UseAuthentication() middleware
    JWT->>JWT: Validate signature ✅\nValidate exp ✅\nValidate iss/aud ✅
    JWT-->>API: Set HttpContext.User (ClaimsPrincipal)
    API->>API: UseAuthorization()\n[Authorize(Roles="Admin")] check
    alt Authorized
        API-->>C: 200 [ orders... ]
    else Forbidden
        API-->>C: 403 Forbidden
    end
```

---

## 7. CQRS + MediatR Flow

```mermaid
flowchart TD
    subgraph WriteStack["✍️ Command Stack"]
        CMD[CreateOrderCommand\nIRequest&lt;Guid&gt;]
        LB1[LoggingBehavior\nIPipelineBehavior]
        VB[ValidationBehavior\nFluentValidation]
        CH[CreateOrderCommandHandler\nIRequestHandler]
        WDB[(Write DB\nSQL Server\nNormalised)]
    end

    subgraph ReadStack["📖 Query Stack"]
        QRY[GetOrdersQuery\nIRequest&lt;PagedResult&gt;]
        LB2[LoggingBehavior]
        QH[GetOrdersQueryHandler\nAsNoTracking + Projection]
        RDB[(Read DB\nSame or Replica\nDenormalised view)]
    end

    Controller[API Controller\nThin — only dispatches]
    MED{IMediator\n.Send}

    Controller --> MED
    MED --> CMD --> LB1 --> VB --> CH --> WDB
    MED --> QRY --> LB2 --> QH --> RDB

    style WriteStack fill:#1a237e,color:#fff
    style ReadStack fill:#1b5e20,color:#fff
    style MED fill:#FF6F00,color:#fff
```

---

## 8. Repository + Unit of Work

```mermaid
flowchart TD
    SVC[Service Layer]
    UOW[Unit of Work\nShared DbContext]
    OR[OrderRepository\nIOrderRepository]
    CR[CustomerRepository\nIRepository&lt;Customer&gt;]
    IR[InventoryRepository]
    CTX[(AppDbContext\nChange Tracker)]
    DB[(SQL Server)]

    SVC --> UOW
    UOW --> OR & CR & IR
    OR --> CTX
    CR --> CTX
    IR --> CTX
    UOW -->|CommitAsync\nSingle SaveChanges| CTX
    CTX -->|One Transaction\nINSERT + UPDATE + DELETE| DB
```

---

## 9. Design Patterns — Decorator Chain

```mermaid
flowchart LR
    Client([Client])
    LD["LoggingDecorator\nLogs before + after"]
    CD["CachingDecorator\nCheck cache → miss?"]
    RS["Real OrderService\nQueries database"]
    DB[(Database)]
    Cache[(Redis Cache)]

    Client -->|GetOrderAsync| LD
    LD -->|delegate| CD
    CD -->|cache miss| RS
    RS --> DB
    DB --> RS
    RS --> CD
    CD -->|store in cache| Cache
    CD --> LD
    LD --> Client

    style Client fill:#4CAF50,color:#fff
    style Cache fill:#FF9800,color:#fff
    style DB fill:#2196F3,color:#fff
```

---

## 10. Design Patterns — State Machine (ATM)

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> HasCard : insertCard()
    HasCard --> Idle : ejectCard()
    HasCard --> HasCard : enterPin() [WRONG PIN]
    HasCard --> Authenticated : enterPin() [CORRECT PIN]
    Authenticated --> Dispensing : selectAmount()
    Authenticated --> Idle : cancel()
    Dispensing --> Idle : dispense() ✅ card ejected
    Dispensing --> Idle : cancel()

    note right of Authenticated
        User has 3 PIN attempts
        before card retained
    end note
```

---

## 11. Design Patterns — Saga Orchestration

```mermaid
sequenceDiagram
    participant O as Order Service
    participant Saga as Saga Orchestrator
    participant P as Payment Service
    participant I as Inventory Service
    participant S as Shipping Service

    O->>Saga: OrderPlaced event
    Saga->>P: ProcessPaymentCommand
    alt Payment Success
        P-->>Saga: PaymentProcessed ✅
        Saga->>I: ReserveInventoryCommand
        alt Stock Available
            I-->>Saga: InventoryReserved ✅
            Saga->>S: ScheduleShippingCommand
            S-->>Saga: ShippingScheduled ✅
            Saga->>O: OrderConfirmed ✅
        else Out of Stock
            I-->>Saga: InventoryUnavailable ❌
            Saga->>P: RefundPaymentCommand 💰
            Saga->>O: OrderCancelled ❌
        end
    else Payment Failed
        P-->>Saga: PaymentFailed ❌
        Saga->>O: OrderCancelled ❌
    end
```

---

## 12. Retry + Circuit Breaker

```mermaid
flowchart TD
    REQ[API Request]
    CB{Circuit\nBreaker\nState?}
    OPEN[OPEN ❌\nFail fast immediately]
    HALFOPEN[HALF-OPEN 🟡\nAllow one test request]
    CLOSED[CLOSED ✅\nNormal operation]

    REQ --> CB
    CB -->|OPEN| OPEN
    CB -->|HALF-OPEN| HALFOPEN
    CB -->|CLOSED| CLOSED

    CLOSED --> Call[Call Downstream]
    Call --> Success{Success?}
    Success -->|Yes| OK[Return result\nReset failure count]
    Success -->|No| Retry{Retry count\n< max?}
    Retry -->|Yes| Backoff[Exponential backoff\n+ jitter]
    Backoff --> Call
    Retry -->|No| OPEN2[Open Circuit\n30s break]

    HALFOPEN --> Test[Test request]
    Test -->|Success| CLOSED2[Close circuit ✅]
    Test -->|Failure| OPEN3[Reopen circuit ❌]

    style OPEN fill:#c62828,color:#fff
    style HALFOPEN fill:#F57F17,color:#fff
    style CLOSED fill:#2e7d32,color:#fff
    style OPEN2 fill:#c62828,color:#fff
```

---

## 13. Outbox Pattern

```mermaid
sequenceDiagram
    participant SVC as Service
    participant DB as Database
    participant OUT as Outbox Table
    participant PUB as Outbox Publisher\n(BackgroundService)
    participant BUS as Message Bus\n(Kafka / Service Bus)
    participant CON as Consumer Service

    SVC->>DB: BEGIN TRANSACTION
    SVC->>DB: INSERT order (business data)
    SVC->>OUT: INSERT OutboxMessage (event payload)
    DB-->>SVC: COMMIT (both atomic ✅)

    loop Every 5 seconds
        PUB->>OUT: SELECT unprocessed messages
        OUT-->>PUB: [ messages ]
        PUB->>BUS: Publish each message
        BUS-->>PUB: ACK
        PUB->>OUT: UPDATE ProcessedAt = NOW()
    end

    BUS->>CON: Deliver message
    CON->>CON: Process idempotently\n(check EventId already processed)
```

---

## 14. Rate Limiter Flow (Token Bucket)

```mermaid
flowchart TD
    REQ[Incoming Request]
    KEY[Extract key\nuserId or IP]
    REDIS[(Redis\nToken Bucket)]
    CHECK{Tokens\navailable?}
    CONSUME[Consume 1 token\nRefill based on time elapsed]
    ALLOW[✅ Allow\nProcess request]
    DENY[❌ Deny\n429 Too Many Requests\nRetry-After header]
    REFILL[Refill tokens\nbased on elapsed time\nsince last request]

    REQ --> KEY --> REDIS
    REDIS --> REFILL --> CHECK
    CHECK -->|Tokens ≥ 1| CONSUME --> ALLOW
    CHECK -->|Tokens = 0| DENY

    style ALLOW fill:#2e7d32,color:#fff
    style DENY fill:#c62828,color:#fff
    style REDIS fill:#FF9800,color:#fff
```

---

# 🎨 Visual Diagrams — High Level Design

---

## HLD-D1 — Load Balancer Architecture

```mermaid
flowchart TD
    C1([Client]) & C2([Client]) & C3([Client])
    LB[Load Balancer\nRound Robin / Least Connections]
    A1[App Server 1] & A2[App Server 2] & A3[App Server 3]
    CACHE[(Redis Cache\nShared)]
    PRI[(Primary DB\nWrite)]
    REP1[(Read Replica 1)] & REP2[(Read Replica 2)]

    C1 & C2 & C3 --> LB
    LB --> A1 & A2 & A3
    A1 & A2 & A3 --> CACHE
    A1 & A2 & A3 -->|Writes| PRI
    A1 & A2 & A3 -->|Reads| REP1 & REP2
    PRI -->|Async replication| REP1 & REP2

    style LB fill:#1565C0,color:#fff
    style CACHE fill:#FF9800,color:#fff
    style PRI fill:#880E4F,color:#fff
```

---

## HLD-D2 — Microservices Communication

```mermaid
flowchart LR
    API[API Gateway\nYARP / Kong]
    OS[Order Service]
    PS[Payment Service]
    IS[Inventory Service]
    NS[Notification Service]
    KAFKA{{"Kafka\nEvent Bus"}}
    DB1[(Order DB)] & DB2[(Payment DB)] & DB3[(Inventory DB)]

    Client([Client]) --> API
    API -->|REST| OS
    API -->|REST| PS

    OS -->|Sync REST| PS
    OS --> KAFKA
    PS --> KAFKA
    IS --> KAFKA

    KAFKA -->|OrderPlaced| IS
    KAFKA -->|OrderPlaced\nPaymentProcessed| NS

    OS --> DB1
    PS --> DB2
    IS --> DB3

    style KAFKA fill:#FF6F00,color:#fff
    style API fill:#1565C0,color:#fff
```

---

## HLD-D3 — Caching Layers

```mermaid
flowchart LR
    User([User Request])
    CDN["CDN Edge\nCloudflare / Azure CDN\nstatic assets, public API"]
    APPCACHE["In-Process Cache\nIMemoryCache\n~1ms"]
    REDIS["Distributed Cache\nRedis\n~2ms"]
    DB[(Database\n~10-50ms)]

    User --> CDN
    CDN -->|miss| APPCACHE
    APPCACHE -->|miss| REDIS
    REDIS -->|miss| DB
    DB --> REDIS
    REDIS --> APPCACHE
    APPCACHE --> User

    CDN -->|hit ⚡| User
    APPCACHE -->|hit ⚡| User
    REDIS -->|hit ⚡| User

    style CDN fill:#1565C0,color:#fff
    style REDIS fill:#FF9800,color:#fff
    style DB fill:#4CAF50,color:#fff
```

---

## HLD-D4 — CAP Theorem

```mermaid
flowchart TD
    subgraph CAP["CAP Theorem — Pick 2 of 3"]
        direction TB
        C[Consistency\nEvery read = latest write]
        A[Availability\nEvery request gets a response]
        P[Partition Tolerance\nWorks despite network split]
    end

    CP["CP Systems\n✅ ZooKeeper\n✅ HBase\n✅ MongoDB strong"]
    AP["AP Systems\n✅ Cassandra\n✅ DynamoDB\n✅ CouchDB"]
    CA["CA Systems\n❌ Impossible in\ndistributed systems\n(single-node RDBMS only)"]

    C & P --> CP
    A & P --> AP
    C & A --> CA

    style C fill:#1565C0,color:#fff
    style A fill:#2e7d32,color:#fff
    style P fill:#880E4F,color:#fff
    style CP fill:#1a237e,color:#fff
    style AP fill:#1b5e20,color:#fff
    style CA fill:#757575,color:#fff
```

---

## HLD-D5 — SQL vs NoSQL Decision Tree

```mermaid
flowchart TD
    START([New Data Store Needed])
    Q1{Need ACID\ntransactions?}
    Q2{Schema\nflexible /\nchanges often?}
    Q3{Time-series\nor event log?}
    Q4{Key-value\nor session?}
    Q5{Full-text\nsearch?}
    Q6{Horizontal\nscale > 1TB?}

    SQL["✅ SQL\nPostgreSQL / SQL Server\nOrders, Users, Finance"]
    MONGO["✅ MongoDB\nFlexible docs\nProduct catalog, CMS"]
    CASSANDRA["✅ Cassandra\nTime-series, IoT\nWrite-heavy, distributed"]
    REDIS["✅ Redis\nSessions, cache\nReal-time counters"]
    ELASTIC["✅ Elasticsearch\nLogs, search\nFull-text queries"]
    EITHER["Either works\nSQL with read replicas\nOR NoSQL sharded"]

    START --> Q1
    Q1 -->|Yes| SQL
    Q1 -->|No| Q2
    Q2 -->|Yes| MONGO
    Q2 -->|No| Q3
    Q3 -->|Yes| CASSANDRA
    Q3 -->|No| Q4
    Q4 -->|Yes| REDIS
    Q4 -->|No| Q5
    Q5 -->|Yes| ELASTIC
    Q5 -->|No| Q6
    Q6 -->|Yes| EITHER
    Q6 -->|No| SQL

    style SQL fill:#1565C0,color:#fff
    style MONGO fill:#2e7d32,color:#fff
    style CASSANDRA fill:#4A148C,color:#fff
    style REDIS fill:#FF6F00,color:#fff
    style ELASTIC fill:#006064,color:#fff
```

---

## HLD-D6 — Event-Driven Architecture

```mermaid
flowchart LR
    subgraph Producers["📤 Event Producers"]
        OS2[Order Service]
        PS2[Payment Service]
        IS2[Inventory Service]
    end

    subgraph Broker["🔀 Message Broker\nKafka / Azure Service Bus"]
        T1[Topic: orders]
        T2[Topic: payments]
        T3[Topic: inventory]
    end

    subgraph Consumers["📥 Event Consumers"]
        NS2[Notification Service]
        AN[Analytics Service]
        AU[Audit Service]
        WH[Webhook Service]
    end

    OS2 --> T1
    PS2 --> T2
    IS2 --> T3

    T1 --> NS2 & AN & AU
    T2 --> NS2 & AN & AU & WH
    T3 --> AN & AU

    style Broker fill:#FF6F00,color:#fff
    style Producers fill:#1a237e,color:#fff
    style Consumers fill:#1b5e20,color:#fff
```

---

## HLD-D7 — Blue-Green Deployment

```mermaid
flowchart TD
    LB2[Load Balancer]

    subgraph Blue["🔵 Blue — v1.4 LIVE"]
        B1[Pod 1\nv1.4]
        B2[Pod 2\nv1.4]
        B3[Pod 3\nv1.4]
    end

    subgraph Green["🟢 Green — v1.5 STAGING"]
        G1[Pod 1\nv1.5]
        G2[Pod 2\nv1.5]
        G3[Pod 3\nv1.5]
    end

    DB3[(Shared Database)]

    LB2 -->|100% traffic| Blue
    LB2 -.->|0% traffic\nsmoke tests only| Green
    Blue --> DB3
    Green --> DB3

    FLIP[🔄 Flip Traffic\nkubectl patch service]
    FLIP -.->|"After tests pass:\n100% → Green"| LB2

    style Blue fill:#1565C0,color:#fff
    style Green fill:#2e7d32,color:#fff
    style FLIP fill:#FF6F00,color:#fff
```

---

## HLD-D8 — Testing Pyramid

```mermaid
flowchart TD
    subgraph Pyramid["Testing Pyramid"]
        E2E["🔺 E2E Tests\n5–10%\nSlowest · Most expensive\nSelenium, Playwright\nRun: pre-release"]
        INT["🔷 Integration Tests\n20–30%\nMedium speed\nWebApplicationFactory\nRun: every CI build"]
        UNIT["🟦 Unit Tests\n60–70%\nFastest · Cheapest\nxUnit + Moq\nRun: every save"]
    end

    UNIT --> INT --> E2E

    style E2E fill:#c62828,color:#fff
    style INT fill:#F57F17,color:#fff
    style UNIT fill:#1565C0,color:#fff
```

EOF
echo "Done diagrams-dotnet-flow.md"