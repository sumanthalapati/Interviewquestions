# ☁️ Cloud + DevOps Interview Guide

> Docker · Kubernetes · CI/CD · Deployment strategies · Observability · Feature flags
> Every concept includes diagram + code + tradeoff analysis.

---

## 📋 Table of Contents

1. [Docker Basics](#1-docker-basics)
2. [Kubernetes Basics](#2-kubernetes-basics)
3. [CI/CD Pipelines](#3-cicd-pipelines)
4. [Blue-Green Deployment](#4-blue-green-deployment)
5. [Rolling Deployment](#5-rolling-deployment)
6. [Horizontal Scaling](#6-horizontal-scaling)
7. [Load Balancing](#7-load-balancing)
8. [CDN (Content Delivery Network)](#8-cdn-content-delivery-network)
9. [Reverse Proxy](#9-reverse-proxy)
10. [Observability — Metrics, Logs, Traces](#10-observability--metrics-logs-traces)
11. [Prometheus & Grafana](#11-prometheus--grafana)
12. [Health Checks](#12-health-checks)
13. [Feature Flags](#13-feature-flags)

---

## 1. Docker Basics

> 📚 Reference: https://docs.docker.com/

### What is Docker and why does it solve "works on my machine"?

Docker packages your app + its **exact dependencies + OS libraries** into an image. The image runs identically on any machine with Docker — dev laptop, CI server, production.

```
Without Docker:
  Dev: "It works on my Windows 11 with .NET 8.0.5"
  Prod: "It crashes on Ubuntu with .NET 8.0.1"
  → library version mismatch

With Docker:
  Dev builds image → image contains .NET 8.0.5 + app + all deps
  Prod runs same image → identical environment
```

### Multi-Stage Dockerfile (.NET)

❌ **Wrong** — single stage: ships SDK + source code in production image (~900 MB):
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /app
COPY . .
RUN dotnet build
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

✅ **Correct** — multi-stage: build with SDK, ship only runtime (~200 MB):
```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# Stage 2: Runtime — only the runtime image, no SDK
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080

# Security: run as non-root
RUN adduser --disabled-password --gecos "" appuser
USER appuser

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### Key Docker Commands
```bash
docker build -t myapp:1.0 .          # build image
docker run -p 8080:8080 myapp:1.0    # run container
docker ps                             # list running containers
docker logs <container-id>           # view logs
docker exec -it <id> /bin/bash       # shell into container
docker compose up -d                 # run multi-container stack
docker image prune                   # clean unused images
```

### Docker Image Lifecycle

```mermaid
flowchart LR
    A[Write Dockerfile] --> B[docker build]
    B --> C[Image\nlocal]
    C --> D[docker push]
    D --> E[Registry\nACR / Docker Hub]
    E --> F[docker pull]
    F --> G[docker run]
    G --> H[Container\nrunning]

    style A fill:#4CAF50,color:#fff
    style E fill:#2196F3,color:#fff
    style H fill:#FF9800,color:#fff
```

### Docker Compose (local dev)
```yaml
# docker-compose.yml
version: '3.9'
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      - ConnectionStrings__Default=Server=db;Database=myapp;User=sa;Password=Pass@word1;
    depends_on:
      db:
        condition: service_healthy

  db:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      SA_PASSWORD: "Pass@word1"
      ACCEPT_EULA: "Y"
    healthcheck:
      test: /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Pass@word1" -Q "SELECT 1"
      interval: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
```

---

## 2. Kubernetes Basics

> 📚 Reference: https://kubernetes.io/docs/

### Core Objects
```
Cluster
  └── Nodes (VMs / physical machines)
        └── Pods (1+ containers, share network/storage)
              └── Containers (your Docker image)

Deployment  → declares desired state: "run 3 replicas of myapp:1.0"
Service     → stable DNS name + load balancing across pods
ConfigMap   → non-secret config (env vars, files)
Secret      → sensitive config (passwords, API keys) — base64 encoded
Ingress     → HTTP routing rules (path /api → service A, /web → service B)
HPA         → Horizontal Pod Autoscaler — scale pods based on CPU/memory
```

### Deployment YAML
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
spec:
  replicas: 3                           # run 3 pods
  selector:
    matchLabels:
      app: order-api
  template:
    metadata:
      labels:
        app: order-api
    spec:
      containers:
      - name: order-api
        image: myregistry.azurecr.io/order-api:1.5.0
        ports:
        - containerPort: 8080
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: Production
        - name: ConnectionStrings__Default
          valueFrom:
            secretKeyRef:              # pull from Secret, not hardcoded
              name: db-secret
              key: connection-string
        resources:
          requests:
            cpu: "250m"                # 0.25 CPU
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        readinessProbe:                # pod ready to receive traffic?
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:                 # pod alive? restart if fails
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: order-api-svc
spec:
  selector:
    app: order-api
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-api
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70         # scale out when avg CPU > 70%
```

### Kubernetes Architecture

```mermaid
flowchart TD
    subgraph CP["Control Plane"]
        API[API Server] --> ETCD[etcd\ncluster state]
        API --> SCHED[Scheduler\nassigns pods to nodes]
        API --> CM[Controller Manager\ndesired vs actual state]
    end

    subgraph W1["Worker Node 1"]
        KL1[kubelet] --> POD1[Pod\nContainer A]
        KP1[kube-proxy\nnetwork rules]
    end

    subgraph W2["Worker Node 2"]
        KL2[kubelet] --> POD2[Pod\nContainer B]
        KP2[kube-proxy]
    end

    CP -->|schedule & manage| W1
    CP -->|schedule & manage| W2

    style CP fill:#1565C0,color:#fff
    style W1 fill:#2E7D32,color:#fff
    style W2 fill:#2E7D32,color:#fff
```

### K8s Pod Scheduling and Traffic Flow

```mermaid
flowchart LR
    DEP[Deployment\ndeclares desired state] --> RS[ReplicaSet\nmaintains N replicas]
    RS --> P1[Pod 1]
    RS --> P2[Pod 2]
    RS --> P3[Pod 3]
    SVC[Service\nstable DNS + LB] --> P1
    SVC --> P2
    SVC --> P3
    ING[Ingress\nHTTP routing rules] --> SVC
    EXT[External Traffic\nbrowser / API client] --> ING

    style DEP fill:#4CAF50,color:#fff
    style SVC fill:#2196F3,color:#fff
    style ING fill:#FF9800,color:#fff
    style EXT fill:#9C27B0,color:#fff
```

### Tradeoffs: Docker Compose vs Kubernetes
| | Docker Compose | Kubernetes |
|-|---------------|------------|
| Learning curve | Low | High |
| Auto-healing | ❌ No | ✅ Yes — restarts failed pods |
| Auto-scaling | ❌ Manual | ✅ HPA |
| Rolling updates | Manual | ✅ Built-in |
| Service discovery | Basic | ✅ Full DNS |
| Use when | Local dev, small projects | Production, scale-out |

---

## 3. CI/CD Pipelines

> 📚 Reference: https://learn.microsoft.com/en-us/azure/devops/pipelines/

### Pipeline Stages
```
Code Push
    │
    ▼
[ CI — Continuous Integration ]
    ├─ Restore packages
    ├─ Build (dotnet build)
    ├─ Unit tests (dotnet test)
    ├─ Code coverage check (>80%)
    ├─ Static analysis (SonarQube, CodeQL)
    ├─ Security scan (OWASP dependency check)
    └─ Build Docker image + push to registry
    │
    ▼ (only if CI passes)
[ CD — Deploy to Staging ]
    ├─ Apply K8s manifests (kubectl apply)
    ├─ Run DB migrations
    ├─ Run smoke tests
    └─ Run integration tests
    │
    ▼ (manual approval gate)
[ CD — Deploy to Production ]
    ├─ Blue-green or rolling deploy
    ├─ Health check validation
    └─ Alert if failure → auto-rollback
```

### CI/CD Pipeline Flow

```mermaid
flowchart LR
    CC[Code commit\ngit push] --> BUILD[Build\ndotnet build]
    BUILD --> UT[Unit tests\ndotnet test]
    UT --> DB[Docker build\ndocker build]
    DB --> PI[Push image\nto registry]
    PI --> DS[Deploy to staging]
    DS --> IT[Integration tests]
    IT --> DP[Deploy to prod\nmanual gate]

    style CC fill:#4CAF50,color:#fff
    style DP fill:#FF9800,color:#fff
```

### Azure Pipelines YAML
```yaml
trigger:
  branches:
    include: [main, release/*]

variables:
  imageTag: $(Build.BuildId)
  registry: myregistry.azurecr.io

stages:
- stage: CI
  jobs:
  - job: BuildAndTest
    pool:
      vmImage: ubuntu-latest
    steps:
    - task: UseDotNet@2
      inputs:
        version: '8.x'

    - script: dotnet restore
      displayName: Restore

    - script: dotnet build --no-restore -c Release
      displayName: Build

    - script: dotnet test --no-build --collect:"XPlat Code Coverage"
      displayName: Test

    - task: PublishCodeCoverageResults@1
      inputs:
        codeCoverageTool: Cobertura
        summaryFileLocation: '**/coverage.cobertura.xml'

    - task: Docker@2
      displayName: Build & Push Image
      inputs:
        command: buildAndPush
        repository: order-api
        tags: $(imageTag)

- stage: DeployStaging
  dependsOn: CI
  condition: succeeded()
  jobs:
  - deployment: Staging
    environment: staging
    strategy:
      runOnce:
        deploy:
          steps:
          - script: |
              sed -i "s|IMAGE_TAG|$(imageTag)|g" k8s/deployment.yaml
              kubectl apply -f k8s/deployment.yaml
              kubectl rollout status deployment/order-api --timeout=5m

- stage: DeployProd
  dependsOn: DeployStaging
  condition: succeeded()
  jobs:
  - deployment: Production
    environment: production   # requires manual approval in Azure DevOps
    strategy:
      runOnce:
        deploy:
          steps:
          - script: kubectl set image deployment/order-api order-api=$(registry)/order-api:$(imageTag)
```

---

## 4. Blue-Green Deployment

### How It Works
```
[ Load Balancer ]
      │
      ├──► Blue (v1.4 — LIVE, receiving 100% traffic)
      └──► Green (v1.5 — idle, being deployed to)

Steps:
1. Deploy v1.5 to Green environment
2. Run smoke tests against Green
3. Flip load balancer → Green receives 100% traffic
4. Blue becomes idle (instant rollback: flip back to Blue)
5. After confidence: decommission/reuse Blue for next release

[ Load Balancer ]
      │
      └──► Green (v1.5 — now LIVE, receiving 100% traffic)
      └──► Blue (v1.4 — standby for rollback)
```

### Kubernetes Blue-Green
```yaml
# Blue deployment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api-blue
  labels:
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels: { app: order-api, version: blue }
  template:
    metadata:
      labels: { app: order-api, version: blue }
    spec:
      containers:
      - name: order-api
        image: order-api:1.4.0
---
# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api-green
spec:
  replicas: 3
  selector:
    matchLabels: { app: order-api, version: green }
  template:
    metadata:
      labels: { app: order-api, version: green }
    spec:
      containers:
      - name: order-api
        image: order-api:1.5.0
---
# Service — switch by changing selector
apiVersion: v1
kind: Service
metadata:
  name: order-api-svc
spec:
  selector:
    app: order-api
    version: blue     # ← change to "green" to flip traffic instantly
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# Flip traffic to green (instant, zero-downtime)
kubectl patch service order-api-svc -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback instantly
kubectl patch service order-api-svc -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Tradeoffs vs Rolling Deployment
| | Blue-Green | Rolling |
|-|-----------|---------|
| Rollback speed | Instant (flip LB) | Slow (roll back each pod) |
| Resource cost | 2x (both envs live) | 1x + extra pods during update |
| Downtime | Zero | Zero |
| DB migrations | Hard (both versions run simultaneously) | Hard |
| Use when | Instant rollback critical | Resource-constrained |

---

## 5. Rolling Deployment

### How It Works
```
Before: [v1][v1][v1][v1] (4 pods)

Step 1: [v2][v1][v1][v1]   (1 new pod, 3 old)
Step 2: [v2][v2][v1][v1]   (2 new, 2 old)
Step 3: [v2][v2][v2][v1]   (3 new, 1 old)
Step 4: [v2][v2][v2][v2]   (all new)

maxSurge=1 means at most 1 extra pod during update
maxUnavailable=0 means never reduce below 4 running pods
```

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # allow 1 extra pod during update
      maxUnavailable: 0  # never go below desired count
```

### Canary Release (Percentage Traffic Split)
```yaml
# Send 10% traffic to canary, 90% to stable
# stable: 9 replicas, canary: 1 replica → ~10% canary traffic
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api-canary
spec:
  replicas: 1          # 1 out of 10 total pods = 10% traffic
  template:
    metadata:
      labels: { app: order-api }   # same label = same service routes to it
    spec:
      containers:
      - image: order-api:1.5.0-canary
```

---

## 6. Horizontal Scaling

```
Low traffic:                  High traffic:
[App][App]                    [App][App][App][App][App][App]
   └─ DB                            └─ DB (read replicas added)

Horizontal = more instances of same service (stateless)
Vertical   = bigger machine (CPU/RAM) — has a ceiling
```

### Making Services Stateless (Required for Horizontal Scaling)

❌ **Wrong** — session stored in server memory (can't scale):
```csharp
// Session stored in server RAM — request must hit SAME server
HttpContext.Session.SetString("cart", JsonSerializer.Serialize(cart));
```

✅ **Correct** — session stored in Redis (any server can serve any request):
```csharp
// Redis-backed distributed session
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = "redis:6379");
builder.Services.AddSession(o =>
{
    o.IdleTimeout = TimeSpan.FromMinutes(30);
    o.Cookie.HttpOnly = true;
    o.Cookie.IsEssential = true;
});
// Now any of 10 app servers can serve the request
```

---

## 7. Load Balancing

### Algorithms
```
Round Robin:
  Request 1 → Server A
  Request 2 → Server B
  Request 3 → Server C
  Request 4 → Server A (repeat)
  Simple, even distribution, ignores server load

Least Connections:
  New request → server with fewest active connections
  Better for variable request duration (some requests slow, some fast)

IP Hash (Sticky Sessions):
  hash(clientIP) % N → always same server
  Needed if server holds session state (avoid if using Redis)

Weighted Round Robin:
  Server A weight=3, Server B weight=1
  3 requests to A, 1 to B → sends more traffic to powerful servers
```

### Layer 4 vs Layer 7 Load Balancer
| | L4 (TCP/UDP) | L7 (HTTP) |
|-|-------------|-----------|
| Routing based on | IP + Port | URL, Headers, Cookies |
| SSL termination | ❌ No | ✅ Yes |
| Content-based routing | ❌ No | ✅ /api → backend, /static → CDN |
| Azure equivalent | Azure Load Balancer | Application Gateway |
| Speed | Faster | Slightly slower (HTTP parsing) |

---

## 8. CDN (Content Delivery Network)

### How It Works
```
Without CDN:
  User in Mumbai ──────────────────► Origin Server in US East
                    (~200ms round trip)

With CDN:
  User in Mumbai ──► CDN Edge (Mumbai) ──► cache HIT → serve immediately (~5ms)
                                        ──► cache MISS → fetch from US East, cache it
```

### What to Cache on CDN
```
✅ Cache (static, rarely changes):
   - JavaScript bundles (cache-busting via content hash in filename)
   - CSS, fonts, images
   - API responses that are public + cacheable (product catalog, pricing)
   - HTML for SSG pages

❌ Don't cache (dynamic, user-specific):
   - Authenticated API responses
   - Shopping cart
   - User profile data
   - Payment pages
```

### Cache-Control Headers
```csharp
// Static assets — cache forever (filename includes content hash: app.a1b2c3.js)
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
    }
});

// API responses — cache at CDN, revalidate
[HttpGet("products")]
public IActionResult GetProducts()
{
    Response.Headers.CacheControl = "public, max-age=300, s-maxage=600";
    // s-maxage: CDN caches for 10 min; browser caches for 5 min
    return Ok(_productService.GetAll());
}

// Private data — never cache at CDN
[HttpGet("cart")]
[Authorize]
public IActionResult GetCart()
{
    Response.Headers.CacheControl = "private, no-store";
    return Ok(_cartService.Get(UserId));
}
```

---

## 9. Reverse Proxy

### What Is It?
A reverse proxy sits in front of backend servers. Clients talk to the proxy; the proxy forwards to backends. Used for SSL termination, load balancing, caching, and request routing.

```
Client ──► [ Reverse Proxy (nginx / YARP) ]
                  │
                  ├──► /api/orders  → Order Service :8001
                  ├──► /api/payments → Payment Service :8002
                  ├──► /            → Angular SPA    :4200
                  └──► /static      → CDN / Blob Storage
```

### YARP (Yet Another Reverse Proxy) — .NET
```csharp
// Program.cs
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

app.MapReverseProxy();
```

```json
// appsettings.json
{
  "ReverseProxy": {
    "Routes": {
      "orders-route": {
        "ClusterId": "orders-cluster",
        "Match": { "Path": "/api/orders/{**catch-all}" }
      },
      "payments-route": {
        "ClusterId": "payments-cluster",
        "Match": { "Path": "/api/payments/{**catch-all}" }
      }
    },
    "Clusters": {
      "orders-cluster": {
        "Destinations": {
          "orders1": { "Address": "http://order-service:8001/" },
          "orders2": { "Address": "http://order-service-2:8001/" }
        },
        "LoadBalancingPolicy": "LeastRequests"
      }
    }
  }
}
```

---

## 10. Observability — Metrics, Logs, Traces

### The Three Pillars

| Pillar | Answers | Tool | .NET Package |
|--------|---------|------|--------------|
| **Logs** | What happened and when? | Seq, ELK, Splunk | Serilog, ILogger |
| **Metrics** | How many? How fast? | Prometheus + Grafana | OpenTelemetry, prometheus-net |
| **Traces** | Where is it slow? | Jaeger, Zipkin, Azure Monitor | OpenTelemetry |

### Structured Logging with Serilog
```csharp
// ❌ String interpolation — can't query by field
_log.LogInformation($"Order {orderId} created for customer {customerId}");
// Stored as: "Order abc123 created for customer xyz789"
// Can't query: "show all orders for customer xyz789"

// ✅ Structured logging — fields queryable
_log.LogInformation("Order {OrderId} created for customer {CustomerId}",
    orderId, customerId);
// Stored as: { "OrderId": "abc123", "CustomerId": "xyz789", "message": "..." }
// Can query: SELECT * WHERE CustomerId = 'xyz789'

// Serilog setup
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Service", "OrderService")
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.Seq("http://seq:5341")
    .WriteTo.ApplicationInsights(TelemetryConfiguration.Active,
                                 TelemetryConverter.Traces)
    .CreateLogger();
```

### Metrics — Custom Counters
```csharp
// OpenTelemetry metrics
var meter = new Meter("OrderService");
var ordersCreated  = meter.CreateCounter<long>("orders.created",
    unit: "{orders}", description: "Total orders created");
var orderDuration  = meter.CreateHistogram<double>("orders.processing.duration",
    unit: "ms", description: "Order processing time");

public async Task<Order> CreateOrderAsync(CreateOrderCommand cmd)
{
    var sw = Stopwatch.StartNew();
    try
    {
        var order = await _repo.CreateAsync(cmd);
        ordersCreated.Add(1, new TagList { { "status", "success" } });
        return order;
    }
    catch
    {
        ordersCreated.Add(1, new TagList { { "status", "error" } });
        throw;
    }
    finally
    {
        orderDuration.Record(sw.ElapsedMilliseconds,
            new TagList { { "endpoint", "create" } });
    }
}
```

---

## 11. Prometheus & Grafana

### Architecture
```
App (.NET)  →  /metrics endpoint  →  Prometheus (scrapes every 15s)  →  Grafana (dashboards)
                                       │
                                       └─ Alertmanager → PagerDuty / Slack
```

### Expose Metrics in .NET
```csharp
// Install: dotnet add package prometheus-net.AspNetCore
app.UseHttpMetrics();          // auto-instruments HTTP requests: duration, status code, path
app.MapMetrics();              // exposes /metrics endpoint for Prometheus to scrape

// Prometheus scrape config (prometheus.yml)
// scrape_configs:
//   - job_name: order-api
//     static_configs:
//       - targets: ['order-api:8080']
//     metrics_path: /metrics
//     scrape_interval: 15s
```

### Key Metrics to Monitor
```
# Golden Signals (Google SRE)
rate(http_requests_total[5m])          # Traffic — requests per second
rate(http_requests_total{code=~"5.."}[5m]) / rate(http_requests_total[5m])  # Error rate
histogram_quantile(0.99, http_request_duration_seconds_bucket)  # Latency P99
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes  # Saturation
```

---

## 12. Health Checks

### Liveness vs Readiness vs Startup

| Check | Fails means | K8s action |
|-------|------------|------------|
| **Liveness** | App is deadlocked / crashed | Restart the pod |
| **Readiness** | App not ready for traffic (warming up, DB migration running) | Remove from load balancer (don't restart) |
| **Startup** | App still initialising (slow start) | Wait longer before checking liveness |

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddCheck("self",    () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddSqlServer(connectionString,    name: "database", tags: ["ready"])
    .AddRedis(redisConnectionString,   name: "cache",    tags: ["ready"])
    .AddUrlGroup(new Uri("https://api.stripe.com/"), name: "stripe", tags: ["ready"]);

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live"),   // only "self" check
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),  // DB + cache + external deps
});
```

```json
// Healthy response
{
  "status": "Healthy",
  "totalDuration": "00:00:00.0152",
  "entries": {
    "database": { "status": "Healthy", "duration": "00:00:00.0120" },
    "cache":    { "status": "Healthy", "duration": "00:00:00.0020" },
    "stripe":   { "status": "Healthy", "duration": "00:00:00.0012" }
  }
}
```

---

## 13. Feature Flags

### Why Use Feature Flags?

```
Without flags:
  Merge to main = ship to ALL users immediately
  → Risky: can't test with real users before full rollout
  → Slow: wait for full release cycle for each feature

With flags:
  Code is deployed but feature is OFF by default
  ✅ Turn on for 1% of users → monitor metrics
  ✅ Turn on for 10% → 50% → 100% (gradual rollout)
  ✅ Turn off instantly if something goes wrong (kill switch)
  ✅ A/B test: 50% see old UI, 50% see new UI
```

### Azure App Configuration + Feature Manager
```csharp
// Installation
// dotnet add package Microsoft.FeatureManagement.AspNetCore

// Program.cs
builder.Configuration.AddAzureAppConfiguration(options =>
    options.Connect(connectionString)
           .UseFeatureFlags(ff => ff.CacheExpirationInterval = TimeSpan.FromSeconds(30)));

builder.Services.AddFeatureManagement();

// Controller — check flag
public class OrdersController : ControllerBase
{
    private readonly IFeatureManager _features;

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderDto dto)
    {
        if (await _features.IsEnabledAsync("NewOrderFlow"))
            return await _newOrderService.CreateAsync(dto);   // new code path
        else
            return await _oldOrderService.CreateAsync(dto);   // old code path
    }
}

// Filter by user percentage (gradual rollout)
// appsettings.json:
{
  "FeatureManagement": {
    "NewOrderFlow": {
      "EnabledFor": [
        {
          "Name": "Percentage",
          "Parameters": { "Value": 10 }   // 10% of requests see new flow
        }
      ]
    }
  }
}
```

### Flag vs Code Branch Tradeoffs
| Approach | Feature Flag | Long-lived Branch |
|----------|-------------|-------------------|
| Merge conflicts | None (all merge to main) | Many (diverges over time) |
| Rollback | Instant (toggle off) | Hours (revert + redeploy) |
| Testing in prod | ✅ Yes (specific users) | ❌ No |
| Code cleanliness | ❌ Flag debt must be cleaned | ❌ Merge debt |
| Best practice | **Trunk-based development** + flags | Only for major rewrites |

---

> ✅ **13 cloud and DevOps topics** with full diagrams and .NET code.
>
> 💡 **Key tradeoffs to memorise:**
> - Blue-green vs rolling: **blue-green = instant rollback, 2x cost; rolling = gradual, 1x cost**
> - L4 vs L7 LB: **L7 when you need URL-based routing or SSL termination**
> - Feature flags vs branches: **flags always win for production deployments**
> - Liveness vs readiness: **liveness = restart; readiness = remove from LB** — never confuse these

---

## 14. Azure Hosting Platform Selection

---

### Q: How do you choose between App Service, Container Apps, and AKS in Azure?

**Answer:**
Pick the simplest platform that meets scaling and operational needs. App Service is the quickest path for web apps and APIs with no container expertise required. Container Apps balances flexibility with low operational overhead — it handles Kubernetes internals for you and supports scale-to-zero natively. AKS is for teams ready to own Kubernetes complexity: custom networking, advanced scheduling, and cluster-level control.

| | App Service | Container Apps | AKS |
|-|-------------|----------------|-----|
| Ops overhead | Low | Low–Medium | High |
| Scale-to-zero | ❌ (consumption plan only) | ✅ | ✅ (KEDA) |
| Custom networking | Limited | ✅ | ✅ Full |
| Multi-container pods | ❌ | ✅ | ✅ |
| When to use | REST API, simple web app | Event-driven workloads, microservices | Teams owning full K8s lifecycle |

> **Why this matters:** Picking the wrong hosting platform creates operational overhead that doesn't match team capability. An AKS cluster maintained by a team of three without Kubernetes expertise becomes a reliability risk, not an asset.

**💡 Production Example:**
For a team of three running a straightforward REST API, App Service was chosen — deployed in minutes with zero container knowledge. When a separate event-processing workload needed scale-to-zero, Container Apps was introduced for that service alone. AKS was only considered when another team needed custom CNI networking and pod security policies.

```mermaid
flowchart TD
    Q1{Does the team own\nKubernetes operations?} -- No --> Q2{Need scale-to-zero\nor event-driven scaling?}
    Q1 -- Yes --> AKS[AKS\nFull Kubernetes control]
    Q2 -- Yes --> CA[Container Apps\nManaged KEDA + Dapr]
    Q2 -- No --> AS[App Service\nSimplest path, built-in scaling]

    style AKS fill:#1565C0,color:#fff
    style CA fill:#2E7D32,color:#fff
    style AS fill:#FF9800,color:#fff
```

---

### Q: Walk me through your first 30 days hardening a new cloud environment.

**Answer:**
Establish identity boundaries, network segmentation, secret handling, baseline monitoring, and backup policies in that order. Identity first — everything else depends on who can do what. Network segmentation second — limits blast radius. Secrets and monitoring follow so you can see what is happening. Backups last to establish recovery baseline before any workloads go live.

```
Day 1–7:   Identity — AAD with MFA + conditional access, RBAC with least privilege
Day 8–14:  Network — VNet, NSGs per tier, private endpoints, no public DB exposure
Day 15–21: Secrets — Key Vault, managed identity for all apps, zero connection strings
Day 22–28: Monitoring — Diagnostic settings → Log Analytics, alerts on key events
Day 29–30: Backup — Backup policy per data tier, first restore drill scheduled
```

> **Why this matters:** Cloud environments that aren't hardened from the start accumulate security exposure that's expensive and disruptive to fix retroactively.

**💡 Production Example:**
On a new Azure subscription for a fintech client: Azure AD with conditional access, VNet with NSGs isolating app and data tiers, Key Vault with managed identity, and diagnostic settings to Log Analytics all configured on day 1. On day 3, a review of NSG flow logs caught an overly permissive inbound rule allowing 0.0.0.0/0 on port 1433 — caught before any data landed in the database.

---

### Q: How do you manage secrets in your application from local dev to production?

**Answer:**
Local development uses user secrets or `.env` files excluded from source control. CI/CD uses the platform's encrypted secret store (GitHub Actions encrypted secrets, Azure DevOps variable groups linked to Key Vault). Production uses Key Vault with managed identity — no credentials in config files or environment variables. The same `IConfiguration` abstraction keeps application code identical across environments.

```csharp
// ❌ Hardcoded in appsettings.json — committed to Git
{
  "ConnectionStrings": {
    "Default": "Server=prod-sql;Password=MyP@ssword;"
  }
}

// ✅ Locally: dotnet user-secrets
// dotnet user-secrets set "ConnectionStrings:Default" "Server=local;..."

// ✅ Production: Key Vault via managed identity
builder.Configuration.AddAzureKeyVault(
    new Uri("https://myvault.vault.azure.net/"),
    new DefaultAzureCredential());  // uses managed identity in Azure, dev creds locally
```

> **Why this matters:** Secrets scattered across config files and environment variables create security incidents and painful rotation processes. A single committed password can expose every environment.

**💡 Production Example:**
Locally, developers used `dotnet user-secrets`. In CI, secrets came from GitHub Actions encrypted secrets. In production, the API pulled from Azure Key Vault via managed identity. The same `IConfiguration` abstraction meant zero code changes between environments. When a rotation was needed, updating Key Vault was the only step required — no redeploys, no config changes.

---

### Q: What are managed identities and how do they work?

**Answer:**
Managed identities let Azure resources authenticate to other Azure services without any embedded credentials. Azure AD issues a token to the resource (VM, App Service, Container App) at runtime. The application calls `DefaultAzureCredential` which automatically uses the managed identity token in Azure environments and falls back to developer credentials locally. System-assigned identities are tied to the resource lifecycle; user-assigned identities can be shared across multiple resources.

```csharp
// Before: connection string with embedded password
"Server=tcp:myserver.database.windows.net;Authentication=SQL Password;Password=secret;"

// After: managed identity — no password anywhere
var credential = new DefaultAzureCredential();
var token = await credential.GetTokenAsync(
    new TokenRequestContext(new[] { "https://database.windows.net/.default" }));

// For Azure SDK clients — credential is passed directly
var blobClient = new BlobServiceClient(
    new Uri("https://mystorage.blob.core.windows.net"),
    new DefaultAzureCredential());
```

> **Why this matters:** Managed identities eliminate the most common class of credential-related incidents — hardcoded passwords, rotated credentials breaking apps, secrets in Git history.

**💡 Production Example:**
Migrating from connection strings with embedded credentials to managed identity for Azure SQL and Service Bus eliminated 12 stored secrets across three environments. The entire secret rotation process disappeared — Azure handles token issuance and expiry automatically.

---

### Q: How do you design reliable background job execution with transient failures?

**Answer:**
Use idempotent handlers, durable queues with visibility timeout, bounded retries with exponential backoff, and dead-letter workflows with alerting. The key principle: any job must be safe to execute twice with the same outcome. Retry handles transient errors; dead-letter queues capture persistent failures for human review.

```csharp
// ✅ Idempotent handler with outbox-style deduplication
public async Task ProcessOrderAsync(string messageId, Guid orderId)
{
    // Check idempotency key — skip if already processed
    if (await _processedStore.ExistsAsync(messageId)) return;

    await _orderService.FulfillAsync(orderId);

    // Mark as processed only after successful completion
    await _processedStore.AddAsync(messageId, expiry: TimeSpan.FromDays(7));
}

// Azure Service Bus retry policy
var options = new ServiceBusClientOptions
{
    RetryOptions = new ServiceBusRetryOptions
    {
        Mode = ServiceBusRetryMode.Exponential,
        MaxRetries = 3,
        Delay = TimeSpan.FromSeconds(2),
        MaxDelay = TimeSpan.FromSeconds(30)
    }
};
```

> **Why this matters:** Background jobs that fail silently or don't recover from transient errors cause data loss or stuck workflows — often without any visible error.

**💡 Production Example:**
An email-sending background job failed silently when the SMTP provider had transient outages. Messages were lost with no visibility. Moved to Azure Service Bus queue with 3 retries and exponential backoff, dead-lettered persistent failures, and added an alert on dead-letter queue depth. The next outage was visible in under two minutes and all messages were replayed after recovery.

---

### Q: How do you design for multi-region availability without doubling complexity?

**Answer:**
Start with active-passive, not active-active. Active-passive (primary + standby in a second region) provides disaster recovery without the distributed-write complexity of active-active. Use Azure Traffic Manager or Front Door for DNS failover. Database replication (geo-replication for Azure SQL, read replicas for Cosmos DB) handles data redundancy. Only move to active-active when RTO/RPO requirements demand it and the team can handle split-brain scenarios.

```
Active-Passive (DR focus):
  Primary region handles all traffic
  Secondary region has warm standby
  Traffic Manager monitors health → fails over DNS in < 60s
  RTO: ~5-10 minutes | RPO: minutes (async replication lag)

Active-Active (HA focus):
  Both regions handle traffic
  Front Door routes by latency
  Write conflicts require resolution strategy
  RTO: seconds | RPO: near-zero
  Cost: ~2x + significant complexity
```

> **Why this matters:** Teams that jump straight to active-active often underestimate distributed write complexity. A well-designed active-passive architecture recovers from most failure scenarios at a fraction of the operational cost.

**💡 Production Example:**
An e-commerce platform targeted 99.9% SLA. Active-passive was implemented with Azure SQL geo-replication (East US primary, West US secondary) and Traffic Manager health-based failover. During a zone outage in East US, Traffic Manager rerouted DNS within 45 seconds. Active-active was never needed — the 99.95% uptime requirement was met with the simpler approach.

---

### Q: How do you set SLOs and error budgets for a .NET service?

**Answer:**
Define user-centric reliability metrics (success rate, latency percentiles), agree on an acceptable error rate (the SLO), and calculate the monthly error budget from that SLO. Track budget burn rate — if a deployment burns too much budget too fast, pause further releases until the budget recovers. This creates a principled mechanism to balance reliability investment against feature velocity.

```
SLO: 99.95% success rate for checkout API
Monthly error budget: 0.05% × 43,200 minutes = ~21.6 minutes of downtime/failures

Budget burn rate tracking:
  Normal: 0.01% burn/day → budget lasts months
  Incident: 0.5% burn in 1 hour → 40% of monthly budget consumed → release freeze
  
Alert thresholds:
  5× burn rate for 1h  → warning
  14× burn rate for 5m → page
```

> **Why this matters:** Without defined SLOs and error budgets, teams have no principled way to balance reliability investment against feature delivery. Arguments become subjective; error budgets make them mathematical.

**💡 Production Example:**
SLO of 99.95% success rate and p99 latency under 500ms for the checkout API. A deployment that caused a latency regression burned 40% of the monthly error budget in one day. The error budget policy automatically paused further deployments to that service until the budget recovered. The team fixed the regression and resumed — no manual governance needed.

---

### Q: Walk me through cost optimization steps that do not compromise reliability.

**Answer:**
Right-size compute first (easiest wins), then schedule non-critical workloads, then optimize storage tiers, then remove idle resources. Always protect production redundancy — never remove a standby instance or replicated region to save costs. Measure before cutting: use Azure Cost Analysis and Advisor recommendations to identify waste.

```
Step 1: Right-size — Advisor shows "CPU < 5% for 14 days" → downsize
Step 2: Schedule — dev/test auto-shutdown at 7pm, restart at 8am
Step 3: Storage tiers — blobs not accessed in 30d → Cool tier; 90d → Archive
Step 4: Remove idle — unattached disks, unused public IPs, orphaned snapshots
Step 5: Reserved instances — commit 1yr for stable production workloads (-40% cost)

Never cut:
  ❌ Removing standby slots (rollback requires them)
  ❌ Reducing backup retention below RTO/RPO requirements
  ❌ Eliminating redundancy in critical data paths
```

> **Why this matters:** Cloud costs grow with usage unless actively managed. Unchecked environments often run at 2–3× the necessary cost with no reliability benefit.

**💡 Production Example:**
Dev/test environments running 24/7 on premium SKUs were costing as much as production. Scheduling auto-shutdown, downsizing to burstable B-series VMs, and moving cold storage to Cool tier saved 35% monthly — roughly $2,400/month. Production redundancy was not touched.

---

### Q: What is your strategy for backups, restore drills, and data recovery confidence?

**Answer:**
Backups are useless if restore has never been tested. Schedule automated restore drills to an isolated environment, verify integrity with row counts and checksums, and track actual recovery time against your RTO. A backup that can't be restored in time is not a backup — it's a false sense of security.

```
Backup strategy:
  SQL: Azure automated backups (full weekly, diff daily, log every 5-15min)
  Blob storage: soft delete + versioning + cross-region redundancy
  Key Vault: backup on change events via Event Grid

Restore drill cadence:
  Monthly: restore last backup to isolated environment
  Verify: row count, checksum, application smoke test
  Measure: actual RTO vs target RTO
  Document: findings, any permission gaps, process improvements
```

> **Why this matters:** Untested backups provide false confidence. The worst time to discover your restore process doesn't work is during an actual data loss incident.

**💡 Production Example:**
After a database corruption incident, automated backups had never been tested for restore. Monthly restore drills to an isolated environment with row count and checksum verification were implemented. The first drill revealed a missing `db_datareader` permission on the restore target. The second drill completed in 14 minutes — within the 20-minute RTO.

---

### Q: What cloud architecture tradeoff did you regret, and what did you change?

**Answer:**
Describe the decision, why it seemed reasonable at the time, the operational pain it caused, and the corrective move. The best answers show architectural judgment — understanding that decisions made under time pressure accumulate as operational debt.

> **Why this matters:** Architecture decisions made under time pressure often turn into long-term operational pain. Interviewers use this question to assess whether you reflect, learn, and improve rather than repeat patterns.

**💡 Production Example:**
Azure Functions were chosen for an order processing pipeline expecting simple event handling. The serverless model seemed ideal for the initial workload. As business logic grew — multi-step orchestration, 10-minute processing windows, stateful workflows — cold starts and execution time limits caused cascading failures under load. Migrated to Container Apps with KEDA scaling triggered by Service Bus queue depth. Processing time became predictable, cold starts disappeared, and the team could debug locally with Docker Compose. The lesson: serverless is excellent for stateless, short-lived, event-triggered tasks. Complex orchestration needs a persistent runtime.

---

*Last updated: 2026 | .NET 8 / Kubernetes 1.29 / Docker 25*

---

# ⚖️ Cloud & DevOps Comparisons — Side-by-Side Differences

---

## CD-C1 — Docker Container vs Virtual Machine

| | Docker Container | Virtual Machine |
|-|----------------|----------------|
| Isolation | Process-level (shared OS kernel) | Full OS isolation (hypervisor) |
| Size | MBs (layers, shared base) | GBs (full OS per VM) |
| Startup time | Seconds | Minutes |
| Performance | Near-native | ~5–10% overhead |
| Security boundary | Weaker (shared kernel) | Stronger (separate kernel) |
| Use for | App packaging, microservices, CI | Full OS isolation, legacy apps, compliance |

```
Container: App → Container Runtime → Host OS Kernel
VM:        App → Guest OS → Hypervisor → Host OS

Docker shares the host kernel — a Linux container on a Linux host
Windows containers on Windows host do the same
"Docker on Mac/Windows" = runs a lightweight Linux VM first, then containers inside it
```

---

## CD-C2 — Blue-Green vs Canary vs Rolling Deployment

| | Blue-Green | Canary | Rolling |
|-|-----------|--------|---------|
| Traffic split | 0% / 100% instant flip | Gradual % (1% → 10% → 100%) | Pod-by-pod replacement |
| Rollback | ✅ Instant (flip back) | ✅ Fast (reduce canary %) | Slow (roll back each pod) |
| Resource cost | 2x (both envs live) | 1x + small canary | 1x + extra pods during update |
| Risk exposure | All users at once after flip | Small % first | Growing % as pods update |
| Best for | Instant rollback, critical releases | Validate with real traffic first | Resource-constrained clusters |

```
Blue-Green:  [v1 100%] → flip → [v2 100%]          instant, all-or-nothing
Canary:      [v1 99% + v2 1%] → [v1 90% + v2 10%] → [v2 100%]
Rolling:     [v1 v1 v1 v1] → [v2 v1 v1 v1] → [v2 v2 v1 v1] → [v2 v2 v2 v2]
```

---

## CD-C3 — Kubernetes Liveness vs Readiness vs Startup Probes

| | Liveness Probe | Readiness Probe | Startup Probe |
|-|---------------|----------------|---------------|
| Question | "Is the app alive?" | "Is it ready for traffic?" | "Has the app finished starting?" |
| Fails → K8s does | Restart the pod | Remove from Service (no traffic) | Keep checking; don't kill yet |
| Use for | Deadlock detection | Warm-up, dependency check | Slow-starting apps (JVM, heavy init) |
| Failure is serious | ✅ Pod restarted | ❌ Pod not killed, just isolated | ❌ Pod not killed, just waiting |

```yaml
livenessProbe:    # restart if app is stuck/deadlocked
  httpGet: { path: /health/live, port: 8080 }
  initialDelaySeconds: 15
  periodSeconds: 20

readinessProbe:   # remove from LB if not ready (DB migration running, warming up)
  httpGet: { path: /health/ready, port: 8080 }
  initialDelaySeconds: 5
  periodSeconds: 10

startupProbe:     # give slow apps more time before liveness kicks in
  httpGet: { path: /health/live, port: 8080 }
  failureThreshold: 30   # 30 × 10s = 5 minutes to start
  periodSeconds: 10
```

---

## CD-C4 — Horizontal Pod Autoscaler vs Vertical Pod Autoscaler vs KEDA

| | HPA | VPA | KEDA |
|-|-----|-----|------|
| Scales | Number of pods | CPU/memory per pod | Pods based on external metrics |
| Trigger | CPU/memory utilisation | Observed resource usage | Queue depth, Kafka lag, custom metrics |
| Live adjustments | ✅ | ❌ (needs pod restart) | ✅ |
| Use for | Stateless services under load | Right-sizing containers | Event-driven workloads |

```yaml
# HPA — scale pods when CPU > 70%
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }

# KEDA — scale based on Azure Service Bus queue depth
triggers:
- type: azure-servicebus
  metadata:
    queueName: orders
    messageCount: "5"   # scale up when > 5 messages per pod
```

---

## CD-C5 — Layer 4 vs Layer 7 Load Balancer

| | L4 (Transport Layer) | L7 (Application Layer) |
|-|---------------------|----------------------|
| Routes based on | IP + TCP/UDP port | HTTP URL, headers, cookies |
| SSL termination | ❌ Pass-through | ✅ Yes |
| Content-based routing | ❌ | ✅ `/api` → backend, `/static` → CDN |
| Sticky sessions | IP hash only | ✅ Cookie-based |
| Performance | ✅ Faster (less parsing) | Slightly slower |
| Azure equivalent | Azure Load Balancer | Application Gateway / Front Door |
| Nginx role | Stream module | HTTP module (default) |

---

## CD-C6 — CI vs CD (Continuous Delivery vs Continuous Deployment)

| | Continuous Integration (CI) | Continuous Delivery (CD) | Continuous Deployment |
|-|----------------------------|--------------------------|-----------------------|
| What | Auto build + test on every push | Auto deploy to staging; manual prod approval | Auto deploy to production on every green build |
| Human approval | N/A | ✅ Required for prod | ❌ Fully automated |
| Risk | None | Low | Higher (needs excellent test coverage) |
| Use for | All teams | Most teams | High-maturity orgs |

```
CI:   Push → Build → Test → ✅ Green
CD:   CI → Deploy Staging → Auto tests → [Approval Gate] → Deploy Prod
Continuous Deployment: CI → Deploy Staging → Auto tests → Deploy Prod (no gate)
```

---

## CD-C7 — Metrics vs Logs vs Traces (Observability Pillars)

| | Metrics | Logs | Traces |
|-|---------|------|--------|
| Data type | Numeric time-series | Discrete text events | Request journey spans |
| Cardinality | Low (aggregated) | High (per event) | Medium (per request) |
| Storage cost | ✅ Low | ❌ High | Medium |
| Real-time alerting | ✅ Yes (Prometheus alerts) | Possible (log-based alerts) | Not typical |
| Answers | "How many? How fast? Error rate?" | "What happened and when?" | "Where is the bottleneck?" |
| Tools | Prometheus, Datadog metrics | Seq, ELK, Splunk | Jaeger, Zipkin, Azure Monitor |
| .NET package | `System.Diagnostics.Metrics` | `ILogger<T>` / Serilog | `System.Diagnostics.Activity` |

```csharp
// All three in one request handler
public async Task<Order> CreateOrderAsync(CreateOrderCommand cmd)
{
    using var activity = _activitySource.StartActivity("CreateOrder"); // TRACE
    _log.LogInformation("Creating order for {CustomerId}", cmd.CustomerId); // LOG
    var sw = Stopwatch.StartNew();

    var order = await _repo.CreateAsync(cmd);

    _ordersCreated.Add(1);                      // METRIC — counter
    _orderDuration.Record(sw.ElapsedMilliseconds); // METRIC — histogram
    return order;
}
```

---

### Terraform Workflow

```mermaid
flowchart LR
    HCL[Write HCL\n.tf files] --> INIT[terraform init\ndownload providers]
    INIT --> PLAN[terraform plan\npreview changes]
    PLAN --> REV{Review\nchanges}
    REV -->|approved| APPLY[terraform apply\nprovision infra]
    REV -->|rejected| HCL
    APPLY --> INFRA[Infrastructure\ncreated / updated]

    style HCL fill:#4CAF50,color:#fff
    style REV fill:#FF9800,color:#fff
    style INFRA fill:#2196F3,color:#fff
```

## CD-C8 — Infrastructure as Code: Terraform vs Bicep vs ARM vs Pulumi

| | ARM Templates | Bicep | Terraform | Pulumi |
|-|-------------|-------|-----------|--------|
| Language | JSON (verbose) | Bicep DSL (concise) | HCL | TypeScript/Python/C# |
| Azure-native | ✅ | ✅ (compiles to ARM) | ✅ (via provider) | ✅ (via provider) |
| Multi-cloud | ❌ | ❌ | ✅ | ✅ |
| State management | Azure | Azure | Terraform state file | Pulumi Cloud / file |
| Learning curve | High | Medium | Medium | Low (familiar language) |
| Use for | Azure-only, simple | Azure-only, readable | Multi-cloud, mature IaC | Code-first, multi-cloud |


---

# 📊 Cloud & DevOps Flow Diagrams — Visual Reference

---

## CD-D1 — CI/CD Pipeline Stages

```mermaid
flowchart LR
    DEV([👨‍💻 Developer\npushes code]) --> GIT[Git Repository\nmain branch]

    subgraph CI["CI — Continuous Integration"]
        GIT --> BUILD[dotnet build]
        BUILD --> TEST[dotnet test\nunit + integration]
        TEST --> COVER[Code Coverage\n> 80% required]
        COVER --> SCAN[Security Scan\nOWASP / Snyk]
        SCAN --> DOCKER[Docker Build\n& Push to ACR]
    end

    subgraph CD_STAGING["CD — Staging"]
        DOCKER --> DEPLOY_S[kubectl apply\nStaging]
        DEPLOY_S --> SMOKE[Smoke Tests]
        SMOKE --> INT[Integration Tests]
    end

    subgraph CD_PROD["CD — Production (Manual Gate)"]
        INT --> APPROVAL{👤 Manual\nApproval}
        APPROVAL -->|Approved| DEPLOY_P[Rolling Deploy\nProduction]
        DEPLOY_P --> HEALTH[Health Check\nValidation]
        HEALTH -->|Fail| ROLLBACK[Auto Rollback]
    end

    style DEV fill:#4CAF50,color:#fff
    style APPROVAL fill:#FF9800,color:#fff
    style ROLLBACK fill:#f44336,color:#fff
```

---

## CD-D2 — Blue-Green Deployment

```mermaid
flowchart TD
    LB[Load Balancer] -->|100% traffic| BLUE[🔵 Blue Environment\nv1.4 — LIVE]
    LB -.->|0% traffic| GREEN[🟢 Green Environment\nv1.5 — Idle]

    subgraph Deploy["Deployment Steps"]
        D1[1. Deploy v1.5 to Green] --> D2[2. Run smoke tests\non Green]
        D2 --> D3{Tests pass?}
        D3 -->|YES| D4[3. Switch LB to Green\nInstant cutover]
        D3 -->|NO| D5[Fix and redeploy]
        D4 --> D6[4. Blue = standby\nInstant rollback available]
    end

    style BLUE fill:#2196F3,color:#fff
    style GREEN fill:#4CAF50,color:#fff
    style LB fill:#FF9800,color:#fff
    style D5 fill:#f44336,color:#fff
```

---

## CD-D3 — Kubernetes Pod Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending : kubectl apply

    Pending --> Running : Image pulled\nContainer started
    Pending --> Failed : Image pull error\nOOM

    Running --> Running : Liveness probe ✅
    Running --> Succeeded : Job completed
    Running --> Failed : Liveness probe ❌\nOOM

    Failed --> Pending : Restart policy\n(Always / OnFailure)
    Succeeded --> [*]

    note right of Running
        Readiness probe controls
        whether pod receives traffic
        from Service (load balancer)
    end note
```

---

## CD-D4 — Liveness vs Readiness vs Startup Probes

```mermaid
flowchart TD
    subgraph Probes["Kubernetes Health Probes"]
        SP[Startup Probe\n/health/start\nApp initialising?] -->|PASS| LP
        SP -->|FAIL repeatedly| RESTART1[🔄 Restart pod]

        LP[Liveness Probe\n/health/live\nApp alive?] -->|PASS| RP[Readiness Probe\n/health/ready\nApp ready for traffic?]
        LP -->|FAIL| RESTART2[🔄 Restart pod]

        RP -->|PASS| TRAFFIC[✅ Pod added to\nService endpoints\nreceives traffic]
        RP -->|FAIL| REMOVE[⛔ Pod removed from\nService endpoints\nNO traffic — no restart]
    end

    style RESTART1 fill:#f44336,color:#fff
    style RESTART2 fill:#f44336,color:#fff
    style TRAFFIC fill:#4CAF50,color:#fff
    style REMOVE fill:#FF9800,color:#fff
```

---

## CD-D5 — Observability: Three Pillars

```mermaid
flowchart LR
    APP[.NET Application] -->|structured logs\nSerilog| LOGS[📋 Logs\nSeq / ELK / Splunk]
    APP -->|counters histograms\nOpenTelemetry| METRICS[📊 Metrics\nPrometheus → Grafana]
    APP -->|trace spans\nOpenTelemetry| TRACES[🔍 Traces\nJaeger / Azure Monitor]

    LOGS --> Q1["What happened?\nWhen? What error?"]
    METRICS --> Q2["How many req/sec?\nP99 latency?\nError rate?"]
    TRACES --> Q3["Which service\nis slow?\nWhere did it fail?"]

    METRICS -->|alert rules| ALERT[🚨 Alertmanager\nPagerDuty / Slack]

    style APP fill:#4CAF50,color:#fff
    style ALERT fill:#f44336,color:#fff
```

---

## CD-D6 — Docker Multi-Stage Build

```mermaid
flowchart LR
    subgraph Stage1["Stage 1: Build (SDK ~900MB)"]
        SDK[FROM dotnet/sdk:8.0] --> RESTORE[dotnet restore]
        RESTORE --> BUILD[dotnet build]
        BUILD --> PUBLISH[dotnet publish\n/app/publish]
    end

    subgraph Stage2["Stage 2: Runtime (~200MB)"]
        RT[FROM dotnet/aspnet:8.0] --> COPY[COPY --from=build\n/app/publish .]
        COPY --> USER[USER appuser\nnon-root]
        USER --> RUN[ENTRYPOINT dotnet MyApp.dll]
    end

    Stage1 -->|only /app/publish copied| Stage2
    RUN --> IMAGE[🐳 Final Image\n~200MB\nNo SDK · No source]

    style SDK fill:#2196F3,color:#fff
    style IMAGE fill:#4CAF50,color:#fff
```

---

## CD-D7 — Feature Flag Rollout Strategy

```mermaid
flowchart TD
    DEV[Deploy code with feature OFF] --> T1{Internal\ntesting}
    T1 -->|Pass| T2[Enable for 1% users]
    T2 --> M1{Monitor metrics\nerror rate · latency}
    M1 -->|Issue detected| OFF[🚨 Toggle OFF instantly\nKill switch]
    M1 -->|Healthy| T3[Enable for 10%]
    T3 --> M2{Monitor}
    M2 -->|Healthy| T4[Enable for 50%]
    T4 --> M3{Monitor}
    M3 -->|Healthy| FULL[✅ Enable for 100%\nFull rollout]
    FULL --> CLEAN[Clean up flag code\nRemove feature flag]

    style OFF fill:#f44336,color:#fff
    style FULL fill:#4CAF50,color:#fff
```

