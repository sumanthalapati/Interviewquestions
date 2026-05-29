# 🔌 API Design Interview Guide

> REST best practices · Idempotency · Versioning · HATEOAS · OpenAPI · Error standards · Tradeoffs

---

## 📋 Table of Contents

1. [REST Best Practices](#1-rest-best-practices)
2. [Idempotent APIs](#2-idempotent-apis)
3. [API Versioning](#3-api-versioning)
4. [Pagination Strategies](#4-pagination-strategies)
5. [Error Response Standards](#5-error-response-standards)
6. [HATEOAS Basics](#6-hateoas-basics)
7. [OpenAPI / Swagger](#7-openapi--swagger)
8. [API Security Best Practices](#8-api-security-best-practices)
9. [Rate Limiting & Throttling](#9-rate-limiting--throttling)
10. [Tradeoffs — Key Decisions](#10-tradeoffs--key-decisions)

---

## 1. REST Best Practices

> 📚 Reference: https://restfulapi.net/

### Resource Naming — Nouns, Not Verbs

❌ **Wrong** — verbs in URLs:
```
GET  /getOrders
POST /createOrder
POST /deleteOrder/123
GET  /getUserById?id=456
```

✅ **Correct** — nouns (resources), HTTP method is the verb:
```
GET    /orders              → list orders
POST   /orders              → create order
GET    /orders/{id}         → get order by ID
PUT    /orders/{id}         → replace order
PATCH  /orders/{id}         → partial update
DELETE /orders/{id}         → delete order

GET    /orders/{id}/items   → get items for a specific order (nested resource)
POST   /orders/{id}/ship    → exception: action that doesn't map to CRUD (use noun phrase)
```

### HTTP Methods Correctly Applied
```csharp
[ApiController]
[Route("api/v1/orders")]
public class OrdersController : ControllerBase
{
    [HttpGet]                          // GET /orders?status=pending&page=1
    public Task<IActionResult> List([FromQuery] OrderFilter filter) { }

    [HttpGet("{id:guid}")]             // GET /orders/abc123
    public Task<IActionResult> Get(Guid id) { }

    [HttpPost]                         // POST /orders
    public Task<IActionResult> Create([FromBody] CreateOrderDto dto) { }

    [HttpPut("{id:guid}")]             // PUT /orders/abc123 (full replace)
    public Task<IActionResult> Replace(Guid id, [FromBody] OrderDto dto) { }

    [HttpPatch("{id:guid}")]           // PATCH /orders/abc123 (partial update)
    public Task<IActionResult> Update(Guid id, [FromBody] JsonPatchDocument<OrderDto> patch) { }

    [HttpDelete("{id:guid}")]          // DELETE /orders/abc123
    public Task<IActionResult> Delete(Guid id) { }

    [HttpPost("{id:guid}/ship")]       // POST /orders/abc123/ship (action)
    public Task<IActionResult> Ship(Guid id) { }
}
```

### Response Codes — Use Them Correctly
```csharp
// ✅ 201 Created with Location header
[HttpPost]
public async Task<IActionResult> Create(CreateOrderDto dto)
{
    var id = await _svc.CreateAsync(dto);
    return CreatedAtAction(                // 201 + Location: /api/orders/{id}
        nameof(Get), new { id }, new { id });
}

// ✅ 204 No Content for delete/update with no response body
[HttpDelete("{id:guid}")]
public async Task<IActionResult> Delete(Guid id)
{
    await _svc.DeleteAsync(id);
    return NoContent();  // 204
}

// ✅ 202 Accepted for async operations
[HttpPost("import")]
public IActionResult Import(IFormFile file)
{
    var jobId = _queue.Enqueue(file);
    return Accepted(new { jobId, statusUrl = $"/api/jobs/{jobId}" }); // 202
}
```

---

## 2. Idempotent APIs

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Glossary/Idempotent

### What Is Idempotency?
An operation is **idempotent** if calling it multiple times has the same effect as calling it once. Critical for network reliability — if you don't know if a request succeeded, safe to retry idempotent ones.

| Method | Idempotent? | Safe? | Notes |
|--------|-------------|-------|-------|
| GET | ✅ Yes | ✅ Yes | No side effects |
| DELETE | ✅ Yes | ❌ No | Delete twice = still deleted |
| PUT | ✅ Yes | ❌ No | Replace twice = same result |
| POST | ❌ No | ❌ No | Create twice = two records |
| PATCH | ❌ No (usually) | ❌ No | `SET name="Alice"` is idempotent; `INCREMENT count` is not |

### Making POST Idempotent with Idempotency Keys
```csharp
// Client sends: POST /payments
// Header: Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
// If network fails → client retries with SAME key → server returns SAME response

[HttpPost]
public async Task<IActionResult> Create(
    [FromBody] CreatePaymentDto dto,
    [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
{
    if (idempotencyKey is not null)
    {
        // Check cache for existing result
        var cached = await _idempotencyStore.GetAsync(idempotencyKey);
        if (cached is not null)
            return new ContentResult
            {
                StatusCode  = cached.StatusCode,
                Content     = cached.Body,
                ContentType = "application/json"
            };
    }

    var result = await _paymentService.CreateAsync(dto);

    if (idempotencyKey is not null)
        await _idempotencyStore.SetAsync(idempotencyKey, result, ttl: TimeSpan.FromHours(24));

    return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
}
```

---

## 3. API Versioning

### Four Strategies Compared

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| **URL path** | `/api/v1/orders` | Obvious, easy to test in browser | Version in URL (REST purists object) |
| **Query string** | `/api/orders?api-version=1.0` | Non-breaking for clients | Can be ignored, less visible |
| **Header** | `Api-Version: 1.0` | Clean URLs | Harder to test in browser |
| **Media type** | `Accept: application/vnd.myapi.v1+json` | Most REST-correct | Complex, rarely used |

**Recommendation:** URL path (`/api/v1/`) — most visible, easiest to understand, easiest to route.

### Implementation with Microsoft.AspNetCore.Mvc.Versioning
```csharp
// Program.cs
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion           = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions           = true;  // adds Api-Supported-Versions header
    options.ApiVersionReader            = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),           // /api/v1/
        new HeaderApiVersionReader("Api-Version"),  // also accept header
        new QueryStringApiVersionReader("api-version") // also accept query string
    );
});

builder.Services.AddVersionedApiExplorer(options =>
{
    options.GroupNameFormat           = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});

// V1 Controller
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersV1Controller : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { version = "v1", orders = _v1Service.GetAll() });
}

// V2 Controller — new format, new fields
[ApiController]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersV2Controller : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { version = "v2", data = _v2Service.GetAll(), total = 42 });
}
```

### Deprecation Strategy
```csharp
// Mark old version as deprecated — still works, but clients are warned
[ApiVersion("1.0", Deprecated = true)]
[ApiController]
public class OrdersV1Controller : ControllerBase
{
    // Response header automatically added:
    // Sunset: Sat, 31 Dec 2026 23:59:59 GMT  (when it will stop working)
    // Deprecation: true
}
```

### Non-Breaking vs Breaking Changes
```
✅ Non-breaking (add to same version):
  - Add optional request fields
  - Add new response fields
  - Add new endpoints
  - Relax validation (accept more)

❌ Breaking (requires new version):
  - Remove or rename fields
  - Change field types
  - Change status codes
  - Change URL structure
  - Tighten validation (reject previously valid input)
  - Change authentication requirements
```

---

## 4. Pagination Strategies

### Offset vs Cursor Pagination

| | Offset (`?page=2&size=20`) | Cursor (`?after=eyJpZCI6MTAwfQ`) |
|-|---------------------------|----------------------------------|
| Implementation | Simple | Moderate |
| Performance | ❌ O(n) — DB scans all skipped rows | ✅ O(log n) — uses index |
| Real-time data | ❌ Skipped/duplicate items if data changes | ✅ Stable |
| Random access | ✅ Jump to any page | ❌ Forward/backward only |
| Use when | Small datasets, admin UIs | Large datasets, feeds, timelines |

```csharp
// Offset pagination — simple, avoid for > 10k rows
[HttpGet]
public async Task<IActionResult> List([FromQuery] int page = 1, [FromQuery] int size = 20)
{
    if (size > 100) size = 100; // cap page size

    var total  = await _db.Orders.CountAsync();
    var orders = await _db.Orders
        .OrderBy(o => o.CreatedAt)
        .Skip((page - 1) * size)    // ← OFFSET: scans all prior rows
        .Take(size)
        .AsNoTracking()
        .ToListAsync();

    return Ok(new
    {
        data  = orders,
        total,
        page,
        size,
        pages = (int)Math.Ceiling((double)total / size),
        links = new
        {
            next = page * size < total ? $"/api/orders?page={page + 1}&size={size}" : null,
            prev = page > 1            ? $"/api/orders?page={page - 1}&size={size}" : null
        }
    });
}

// Cursor pagination — for large datasets and feeds
[HttpGet]
public async Task<IActionResult> ListCursor([FromQuery] string? after = null, [FromQuery] int size = 20)
{
    Guid? cursorId = after is null ? null
        : Guid.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(after)));

    var query = _db.Orders
        .OrderBy(o => o.Id);

    if (cursorId.HasValue)
        query = (IOrderedQueryable<Order>)query.Where(o => o.Id > cursorId); // keyset pagination

    var orders  = await query.Take(size + 1).AsNoTracking().ToListAsync(); // +1 to detect hasMore
    var hasMore = orders.Count > size;
    if (hasMore) orders = orders.Take(size).ToList();

    var nextCursor = hasMore
        ? Convert.ToBase64String(Encoding.UTF8.GetBytes(orders.Last().Id.ToString()))
        : null;

    return Ok(new { data = orders, nextCursor, hasMore });
}
```

---

## 5. Error Response Standards

### Problem Details (RFC 7807) — The Standard
```json
// Standard error response — machine-readable + human-readable
{
  "type":     "https://myapi.com/errors/validation-failed",  // URI identifying error type
  "title":    "One or more validation errors occurred",
  "status":   400,
  "detail":   "The request body failed validation",
  "instance": "/api/orders/00000000-0000-0000-0000-000000000000",
  "traceId":  "00-abc123def456-00",    // link to distributed trace
  "errors": {                          // extension: field-level errors
    "customerName": ["Name is required", "Name must be at most 100 characters"],
    "total":        ["Total must be greater than 0"]
  }
}
```

### Implementation
```csharp
// Program.cs — configure Problem Details
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

// Custom exception → consistent ProblemDetails
public class GlobalExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        var (status, type, title) = ex switch
        {
            ValidationException v => (400, "validation-failed", "Validation Failed"),
            NotFoundException   n => (404, "not-found",         "Resource Not Found"),
            ConflictException   c => (409, "conflict",          "Conflict"),
            UnauthorizedException => (401, "unauthorized",      "Unauthorized"),
            ForbiddenException    => (403, "forbidden",         "Forbidden"),
            _                     => (500, "internal-error",    "Internal Server Error")
        };

        ctx.Response.StatusCode = status;
        await ctx.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Type     = $"https://myapi.com/errors/{type}",
            Title    = title,
            Status   = status,
            Detail   = ex is not InternalException ? ex.Message : "An error occurred",
            Instance = ctx.Request.Path,
            Extensions =
            {
                ["traceId"] = Activity.Current?.Id,
                ["errors"]  = ex is ValidationException ve ? ve.Errors : null
            }
        }, ct);

        return true;
    }
}
```

### Never Return Raw Exception Messages in Production
```csharp
// ❌ Wrong — exposes stack trace, internal paths, DB table names
{
  "error": "SqlException: Invalid column name 'custmer_id'. at ... at System.Data.SqlClient..."
}

// ✅ Correct — safe, actionable
{
  "type":   "https://myapi.com/errors/internal-error",
  "title":  "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred. Please contact support with traceId: abc123"
}
// The traceId lets support find the full exception in logs
```

---

## 6. HATEOAS Basics

> 📚 Reference: https://restfulapi.net/hateoas/

### What Is HATEOAS?
Hypermedia As The Engine Of Application State — API responses include **links** to available actions. Clients discover what they can do next from the response, rather than hardcoding URLs.

```json
// Without HATEOAS — client must know all URLs upfront
{ "id": "abc123", "status": "pending", "total": 99.99 }

// With HATEOAS — response tells client what actions are available
{
  "id":     "abc123",
  "status": "pending",
  "total":  99.99,
  "_links": {
    "self":   { "href": "/api/orders/abc123",        "method": "GET" },
    "pay":    { "href": "/api/orders/abc123/pay",    "method": "POST" },
    "cancel": { "href": "/api/orders/abc123/cancel", "method": "POST" },
    "items":  { "href": "/api/orders/abc123/items",  "method": "GET" }
  }
}

// After payment:
{
  "id":     "abc123",
  "status": "paid",
  "_links": {
    "self":   { "href": "/api/orders/abc123" },
    "ship":   { "href": "/api/orders/abc123/ship",   "method": "POST" },
    "refund": { "href": "/api/orders/abc123/refund", "method": "POST" }
    // "pay" and "cancel" no longer present — order already paid
  }
}
```

```csharp
// Simple HATEOAS response builder
public record Link(string Href, string Method = "GET", string Rel = "self");

public async Task<IActionResult> Get(Guid id)
{
    var order = await _svc.GetAsync(id) ?? throw new NotFoundException();

    var links = new List<Link> { new($"/api/orders/{id}") };

    if (order.Status == "Pending")
    {
        links.Add(new($"/api/orders/{id}/pay",    "POST", "pay"));
        links.Add(new($"/api/orders/{id}/cancel", "POST", "cancel"));
    }
    if (order.Status == "Paid")
        links.Add(new($"/api/orders/{id}/ship", "POST", "ship"));

    return Ok(new { order, _links = links });
}
```

**HATEOAS tradeoff:** Adds complexity and response size. In practice, most REST APIs don't implement full HATEOAS — they include basic pagination links and action links for state machine transitions. Know the concept; implement selectively.

---

## 7. OpenAPI / Swagger

> 📚 Reference: https://swagger.io/docs/

### Setup in .NET
```csharp
// Program.cs
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title       = "Orders API",
        Version     = "v1",
        Description = "Manage customer orders",
        Contact     = new OpenApiContact { Name = "Support", Email = "api@mycompany.com" }
    });

    // Add JWT auth to Swagger UI
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name         = "Authorization",
        Type         = SecuritySchemeType.Http,
        Scheme       = "bearer",
        BearerFormat = "JWT",
        In           = ParameterLocation.Header,
        Description  = "Enter: Bearer {your-token}"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
        }] = []
    });

    // Include XML comments from code
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, xmlFile));
});

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Orders API V1");
    // Only expose in dev:
    // if (app.Environment.IsDevelopment()) app.UseSwaggerUI();
});
```

### Document Endpoints Properly
```csharp
/// <summary>
/// Creates a new order for the authenticated customer.
/// </summary>
/// <param name="dto">Order creation details</param>
/// <returns>The created order with assigned ID</returns>
/// <response code="201">Order created successfully</response>
/// <response code="400">Validation failed — check errors array</response>
/// <response code="401">Not authenticated</response>
[HttpPost]
[ProducesResponseType(typeof(OrderDto), StatusCodes.Status201Created)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status401Unauthorized)]
[Produces("application/json")]
public async Task<IActionResult> Create([FromBody] CreateOrderDto dto) { }
```

---

## 8. API Security Best Practices

```csharp
// 1. Always validate and sanitise input
public record CreateOrderDto(
    [Required][MaxLength(100)] string CustomerName,
    [Required][MinLength(1)]   List<OrderItemDto> Items,
    [Range(0.01, 1_000_000)]   decimal Total
);

// 2. Never expose internal IDs where possible — use public-facing IDs
// Bad: /orders/1, /orders/2 → exposes how many orders you have (enumeration attack)
// Good: /orders/a1b2c3d4-... (UUID) → not enumerable

// 3. Scope queries to authenticated user
var order = await _db.Orders
    .Where(o => o.Id == id && o.UserId == CurrentUserId) // BOLA prevention
    .FirstOrDefaultAsync();

// 4. Log security events
_log.LogWarning("Unauthorized access attempt: user {UserId} requested order {OrderId} (not their order)",
    CurrentUserId, id);

// 5. Rate limit sensitive endpoints
[EnableRateLimiting("AuthLimiter")] // 5 attempts per minute
[HttpPost("auth/login")]
public Task<IActionResult> Login(LoginDto dto) { }

// 6. Validate content type
app.UseWhen(ctx => ctx.Request.Method == "POST" || ctx.Request.Method == "PUT",
    branch => branch.Use(async (ctx, next) =>
    {
        if (!ctx.Request.HasJsonContentType())
        {
            ctx.Response.StatusCode = 415; // Unsupported Media Type
            return;
        }
        await next();
    }));
```

---

## 9. Rate Limiting & Throttling

```csharp
// .NET 7+ built-in rate limiting
builder.Services.AddRateLimiter(options =>
{
    // Per-user token bucket (authenticated users)
    options.AddPolicy("ApiLimiter", context =>
        RateLimitPartition.GetTokenBucketLimiter(
            partitionKey: context.User.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "anon",
            factory: _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit         = 100,
                ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                TokensPerPeriod    = 10,   // 10 req/sec sustained, burst up to 100
                QueueLimit         = 0     // no queuing — fail fast
            }));

    // Stricter limit for auth endpoints
    options.AddPolicy("AuthLimiter", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "anon",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window      = TimeSpan.FromMinutes(1)
            }));

    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            ctx.HttpContext.Response.Headers["Retry-After"] = retryAfter.TotalSeconds.ToString();
        await ctx.HttpContext.Response.WriteAsJsonAsync(
            new { error = "Rate limit exceeded. Please retry later." }, ct);
    };
});

// Apply globally
app.UseRateLimiter();

// Or per-controller
[EnableRateLimiting("ApiLimiter")]
[ApiController]
public class OrdersController : ControllerBase { }
```

---

## 10. Tradeoffs — Key Decisions

### REST vs GraphQL vs gRPC

| | REST | GraphQL | gRPC |
|-|------|---------|------|
| Data fetching | Fixed response shape | Client specifies exact fields | Fixed (proto contract) |
| Over/under fetching | Common | ✅ Solved | ✅ Solved (but less flexible) |
| Caching | ✅ HTTP caching works naturally | ❌ Single POST endpoint | ❌ HTTP/2, no standard caching |
| Browser support | ✅ Universal | ✅ Universal | ❌ Needs grpc-web proxy |
| Type safety | ❌ Manual | Partial | ✅ Strong (proto) |
| Performance | Medium | Medium | ✅ Highest (binary, HTTP/2) |
| Use when | Public APIs, simple CRUD | Complex queries, BFF | Internal microservices |

### When to Use Each Pagination Strategy
```
Offset pagination:
✅ Admin dashboards, small datasets (< 10k rows)
✅ When users need to jump to page 50
❌ Large datasets — performance degrades with OFFSET

Cursor pagination:
✅ Social feeds, activity streams, large datasets
✅ Real-time data (no skipped/duplicate items)
❌ Can't jump to arbitrary pages

Key insight: Most public-facing feeds (Twitter, Instagram, Facebook)
use cursor pagination. Most internal admin tables use offset.
```

### Synchronous vs Asynchronous API Responses
```
Sync (return result immediately):
✅ Simple operations < 500ms
✅ User expects immediate result
Example: GET, simple POST

Async (202 Accepted + polling):
✅ Long operations (> 3s)
✅ File processing, report generation, bulk operations
Example: POST /import → 202 { jobId } → GET /jobs/{jobId}

Webhooks (server pushes result):
✅ When client can receive HTTP calls
✅ When polling is wasteful
Example: Stripe payment events, GitHub webhooks
```

---

> ✅ **10 API design topics** with full .NET code and tradeoff analysis.
>
> 💡 **Key interview answers:**
> - Why cursor over offset? **Performance (keyset vs OFFSET) + no skipped rows with real-time data**
> - Why RFC 7807? **Machine-readable error types + field-level validation errors + traceId for support**
> - Breaking change handling? **New version for breaking changes; never modify existing version's contract**
> - Idempotency key TTL? **24 hours is standard — client retries within that window; after that, new key**

---

*Last updated: 2026 | .NET 8 / ASP.NET Core 8*
