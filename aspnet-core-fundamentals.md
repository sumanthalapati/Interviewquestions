# ASP.NET Core Fundamentals Complete Guide

Comprehensive guide to ASP.NET Core essentials covering architecture, project types, middleware, controllers, and filtering.

---

## Table of Contents
1. [ASP.NET Core Basics](#basics)
2. [Project Types & Templates](#project-types)
3. [Application Host & Startup](#host)
4. [Controllers vs Minimal APIs](#controllers-minimal)
5. [Middleware Pipeline](#middleware)
6. [Filters & Attributes](#filters)
7. [Dependency Injection](#di)
8. [Best Practices](#best-practices)
9. [Applied ASP.NET Core Fundamentals](#aspf-mastery)

---

<a id="basics"></a>
## ASP.NET Core Basics

### What is ASP.NET Core?

**Definition**: Free, open-source, cross-platform web framework for building web apps and APIs.

**Key Features**
```
- Cross-platform (Windows, Linux, macOS)
- High performance (ranked #1 TechEmpower benchmarks)
- Open source (.NET Foundation)
- Unified platform (web + console + mobile via MAUI)
- Modern async-first architecture
- Built-in dependency injection
```

### .NET vs .NET Framework vs .NET Core

```
.NET Framework (Legacy, Windows only)
- End of support (2026)
- Windows-only deployment
- Monolithic

.NET Core (Modern)
- Cross-platform
- Lightweight, modular
- Regular updates (2+ years)
- Current: .NET 8 (LTS), 9 (latest)

.NET Standard
- Shared API surface
- Allows code reuse between .NET Framework and .NET Core
- Being phased out (everyone uses .NET now)
```

### Request-Response Flow

```
1. Request arrives (HTTP)
2. Kestrel (web server) receives
3. Middleware pipeline processes
4. Route matching
5. Controller/Handler executes
6. Response generated
7. Sent back to client
```

---

<a id="project-types"></a>
## Project Types & Templates

### ASP.NET Core Web API

**Purpose**: Build RESTful APIs (JSON-based)

```
dotnet new webapi -n MyApi

Creates:
- Controllers/ folder
- Program.cs (setup)
- appsettings.json (config)
- Properties/launchSettings.json (run settings)
```

**Typical Structure**
```
MyApi/
├── Controllers/
│   └── UsersController.cs
├── Models/
│   └── User.cs
├── Services/
│   └── UserService.cs
├── Program.cs (DI setup, middleware)
├── appsettings.json
└── Properties/
    └── launchSettings.json
```

**Program.cs Example**
```csharp
var builder = WebApplication.CreateBuilder(args);

// Add services (DI)
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddControllers();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

### ASP.NET Core Web App (MVC)

**Purpose**: Build server-side rendered web apps

```
dotnet new mvc -n MyApp

Adds:
- Views/ folder (HTML + Razor)
- wwwroot/ (CSS, JS, images)
- Model-View-Controller architecture
```

**Difference: Web API vs Web App**

| Web API | Web App |
|---------|---------|
| Returns JSON | Returns HTML |
| RESTful | Traditional routing |
| For mobile/SPAs | For browsers |
| Stateless | Can use sessions |

### Blazor (C# in Browser)

```
dotnet new blazorserver -n MyBlazor

Benefits:
- Write UI in C# (not JavaScript)
- Full stack C#
- Reuse libraries
- Type-safe

Tradeoff: Higher bandwidth (WebSocket constant connection)
```

### Worker Service

```
dotnet new worker -n MyWorker

Purpose: Background services, console apps
Example: Process queue jobs, scheduled tasks
```

---

<a id="host"></a>
## Application Host & Startup

### IHost vs IWebHost

**Modern (.NET 6+): IHost via WebApplication**
```csharp
var builder = WebApplication.CreateBuilder(args);

// builder = WebApplicationBuilder
// builder.Services = IServiceCollection (DI)
// builder.Configuration = IConfiguration (config)

var app = builder.Build();  // Returns WebApplication (IHost + router)

app.MapControllers();
app.Run();
```

**Old (Pre-.NET 6): IWebHost via WebHost.CreateDefaultBuilder**
```csharp
// Still works, but deprecated
var host = WebHost
    .CreateDefaultBuilder(args)
    .UseStartup<Startup>()
    .Build();

host.Run();
```

### Startup vs Program.cs

**Modern Approach (Recommended)**
```csharp
// Program.cs (no Startup class needed)
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.PropertyNamingPolicy = null);

var app = builder.Build();

app.Use(async (context, next) =>
{
    // Custom middleware
    await next.Invoke();
});

app.MapControllers();
app.Run();
```

**Why Modern is Better**
```
- Simpler (all in one file)
- No need for IStartup interface
- Easier to understand
- Top-level statements (C# 9+)
```

### Configuration Sources

**Hierarchy (bottom to top wins)**
```
1. appsettings.json (base)
2. appsettings.{Environment}.json (override)
3. Environment variables (override)
4. Command-line arguments (override)

Example:
appsettings.json: {"LogLevel": "Info"}
appsettings.Development.json: {"LogLevel": "Debug"}

Development: LogLevel = Debug (override)
Production: LogLevel = Info (base)
```

**Accessing Configuration**
```csharp
var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

// Option 1: Direct access
string dbConnection = config["ConnectionStrings:Default"];

// Option 2: IOptions<T> pattern (recommended)
builder.Services.Configure<DatabaseSettings>(config.GetSection("Database"));

// In controller:
public class UserController
{
    private readonly IOptions<DatabaseSettings> _dbSettings;
    
    public UserController(IOptions<DatabaseSettings> dbSettings)
    {
        _dbSettings = dbSettings;
    }
}
```

---

<a id="controllers-minimal"></a>
## Controllers vs Minimal APIs

### Controllers (Traditional)

```csharp
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    
    public UsersController(IUserService userService)
    {
        _userService = userService;
    }
    
    [HttpGet("{id}")]
    public async Task<ActionResult<UserDto>> GetUser(int id)
    {
        var user = await _userService.GetUserAsync(id);
        if (user == null)
            return NotFound();
        return Ok(user);
    }
    
    [HttpPost]
    public async Task<ActionResult<UserDto>> CreateUser(CreateUserRequest request)
    {
        var user = await _userService.CreateUserAsync(request);
        return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
    }
}
```

**Pros**: Convention-based, familiar, attribute-driven

**Cons**: More boilerplate, ControllerBase class overhead

### Minimal APIs (.NET 6+)

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddScoped<IUserService, UserService>();

var app = builder.Build();

// Cleaner, less boilerplate
app.MapGet("/api/users/{id}", GetUser)
    .WithName("GetUser")
    .WithOpenApi();

app.MapPost("/api/users", CreateUser)
    .WithName("CreateUser")
    .WithOpenApi();

app.Run();

// Handler functions (instead of methods in class)
async Task<IResult> GetUser(int id, IUserService userService)
{
    var user = await userService.GetUserAsync(id);
    return user == null ? Results.NotFound() : Results.Ok(user);
}

async Task<IResult> CreateUser(CreateUserRequest request, IUserService userService)
{
    var user = await userService.CreateUserAsync(request);
    return Results.Created($"/api/users/{user.Id}", user);
}
```

**Pros**: Less boilerplate, modern, flexible

**Cons**: Less discoverable (functions scattered), new pattern

### When to Use

**Controllers**: Large projects with many endpoints, team familiar with MVC pattern

**Minimal APIs**: Small projects, quick APIs, modern greenfield projects

**Hybrid**: Map both in same app (controllers for complex, minimal for simple endpoints)

---

<a id="middleware"></a>
## Middleware Pipeline

### What is Middleware?

**Definition**: Component that handles requests/responses, can pass to next middleware or short-circuit.

```
Request flow:
[Incoming HTTP Request]
      ↓
[Middleware 1] → Can modify request or short-circuit
      ↓
[Middleware 2] → Can modify request
      ↓
[Middleware 3] → Can add response headers
      ↓
[Route Handler / Controller]
      ↓
[Middleware 3] → Response flowing back
      ↓
[Middleware 2] → Response flowing back
      ↓
[Middleware 1] → Response flowing back
      ↓
[HTTP Response]
```

### Built-in Middleware

```csharp
app.UseRouting();           // Route matching
app.UseAuthentication();    // Authentication
app.UseAuthorization();     // Authorization
app.UseHttpsRedirection();  // HTTP → HTTPS
app.UseCors();              // Cross-Origin
app.UseMiddleware<CustomMiddleware>();  // Custom
app.MapControllers();       // Route handler mapping
```

**Order Matters** (higher up = runs earlier on request)

```csharp
var app = builder.Build();

// Order 1: Redirect HTTP to HTTPS (first, on all requests)
app.UseHttpsRedirection();

// Order 2: Log request
app.UseMiddleware<RequestLoggingMiddleware>();

// Order 3: Authenticate
app.UseAuthentication();

// Order 4: Authorize
app.UseAuthorization();

// Order 5: Route to endpoint
app.MapControllers();

// Order 6: Error handling (last, if other middleware fails)
app.UseExceptionHandler("/error");
```

### Custom Middleware

```csharp
// Inline middleware (for simple logic)
app.Use(async (context, next) =>
{
    // Before request
    context.Items["StartTime"] = DateTime.Now;
    
    // Call next middleware
    await next.Invoke();
    
    // After response
    var elapsed = DateTime.Now - (DateTime)context.Items["StartTime"];
    context.Response.Headers.Add("X-Response-Time", elapsed.ToString());
});

// Class-based middleware (for complex logic)
public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;
    
    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }
    
    public async Task InvokeAsync(HttpContext context)
    {
        _logger.LogInformation($"Request: {context.Request.Method} {context.Request.Path}");
        
        await _next(context);
        
        _logger.LogInformation($"Response: {context.Response.StatusCode}");
    }
}

// Register in Program.cs
app.UseMiddleware<RequestLoggingMiddleware>();
```

---

<a id="filters"></a>
## Filters & Attributes

### Types of Filters

**Authorization Filters** (Run first, authorize request)
```csharp
[Authorize]  // Built-in: User must be authenticated
[Authorize(Roles = "Admin")]  // User must be Admin

public class ApiKeyAuthFilter : IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var apiKey = context.HttpContext.Request.Headers["X-API-Key"];
        if (string.IsNullOrEmpty(apiKey))
        {
            context.Result = new UnauthorizedResult();
        }
    }
}

[ServiceFilter(typeof(ApiKeyAuthFilter))]
[HttpGet("secure")]
public IActionResult GetSecure() => Ok("Protected");
```

**Resource Filters** (Run after auth, before model binding)
```csharp
public class CacheResourceFilter : IResourceFilter
{
    public void OnResourceExecuting(ResourceExecutingContext context)
    {
        // Before model binding - good for caching
        var cacheKey = context.HttpContext.Request.Path;
        // Check cache, return cached result if exists
    }
    
    public void OnResourceExecuted(ResourceExecutedContext context)
    {
        // After execution - good for storing in cache
    }
}
```

**Action Filters** (Run before/after action)
```csharp
public class ValidateModelAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.ModelState.IsValid)
        {
            context.Result = new BadRequestObjectResult(context.ModelState);
        }
    }
}

[ValidateModel]
[HttpPost("users")]
public async Task<IActionResult> CreateUser(CreateUserRequest request)
{
    // Model already validated by filter
    var user = await _userService.CreateUserAsync(request);
    return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
}
```

**Exception Filters** (Handle exceptions)
```csharp
public class GlobalExceptionFilter : IExceptionFilter
{
    private readonly ILogger<GlobalExceptionFilter> _logger;
    
    public GlobalExceptionFilter(ILogger<GlobalExceptionFilter> logger)
    {
        _logger = logger;
    }
    
    public void OnException(ExceptionContext context)
    {
        _logger.LogError(context.Exception, "Unhandled exception");
        
        context.Result = new ObjectResult(new
        {
            error = "An unexpected error occurred",
            message = context.Exception.Message
        })
        {
            StatusCode = StatusCodes.Status500InternalServerError
        };
        
        context.ExceptionHandled = true;
    }
}

// Register in Program.cs
builder.Services.AddControllers(options =>
{
    options.Filters.Add<GlobalExceptionFilter>();
});
```

**Result Filters** (Run after action, before response sent)
```csharp
public class LogResultFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        // Before response
        if (context.Result is ObjectResult objectResult)
        {
            // Wrap response
        }
    }
    
    public void OnResultExecuted(ResultExecutedContext context)
    {
        // After response sent
    }
}
```

### Filter Execution Order

```
Authorization Filters
↓
Resource Filters (OnResourceExecuting)
↓
Action Filters (OnActionExecuting)
↓
Model Binding
↓
Action Filters (OnActionExecuted)
↓
Result Filters (OnResultExecuting)
↓
Result execution
↓
Result Filters (OnResultExecuted)
↓
Resource Filters (OnResourceExecuted)
↓
Response sent
```

---

<a id="di"></a>
## Dependency Injection

### Registering Services

```csharp
var builder = WebApplication.CreateBuilder(args);

// Transient: New instance every time
builder.Services.AddTransient<IUserService, UserService>();

// Scoped: New instance per HTTP request (recommended for most)
builder.Services.AddScoped<IUserRepository, UserRepository>();

// Singleton: Single instance for lifetime of app
builder.Services.AddSingleton<ICache, MemoryCache>();

// Factory pattern (create instance manually)
builder.Services.AddScoped<IEmailService>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    return new EmailService(config["Smtp:Host"], config["Smtp:Port"]);
});
```

**Lifetimes Explained**
```
Transient:
- Every injection = new instance
- Example: Stateless services
- Memory: High (many instances)
- Use: Guards, mappers

Scoped:
- Per HTTP request = same instance
- Example: DbContext (entity tracking)
- Memory: Balanced
- Use: Most business logic

Singleton:
- App lifetime = one instance
- Example: Configuration, IMemoryCache
- Memory: Low (one instance)
- Caution: Thread-safe required
```

### Injecting Dependencies

```csharp
public class UserController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ILogger<UserController> _logger;
    
    // Constructor injection (recommended)
    public UserController(IUserService userService, ILogger<UserController> logger)
    {
        _userService = userService;
        _logger = logger;
    }
    
    [HttpGet("{id}")]
    public async Task<IActionResult> GetUser(int id)
    {
        var user = await _userService.GetUserAsync(id);
        return Ok(user);
    }
}

// Minimal API injection (function parameters)
app.MapGet("/users/{id}", 
    async (int id, IUserService userService) =>
    {
        var user = await userService.GetUserAsync(id);
        return user == null ? Results.NotFound() : Results.Ok(user);
    });
```

### Service Locator Pattern (Anti-pattern)

```csharp
// ❌ Don't do this (makes testing hard, hidden dependencies)
public class BadService
{
    public void DoSomething()
    {
        var service = ServiceLocator.Current.GetService<IUserService>();
        service.GetUser(1);
    }
}

// ✅ Do this instead (explicit dependencies)
public class GoodService
{
    private readonly IUserService _userService;
    
    public GoodService(IUserService userService)
    {
        _userService = userService;
    }
    
    public void DoSomething()
    {
        _userService.GetUser(1);
    }
}
```

---

<a id="best-practices"></a>
## Best Practices

### Naming Conventions

```csharp
// Controllers
UserController (singular + "Controller" suffix)
ProductController

// Methods
GetUser (verb + noun)
CreateUser
UpdateUser
DeleteUser

// Properties
UserId (camelCase for private, PascalCase for public)
```

### Response Models

```csharp
// ❌ Returning entity directly (exposes internal structure)
public IActionResult GetUser(int id)
{
    var user = _repository.GetUser(id);
    return Ok(user);  // Returns all fields, including passwords!
}

// ✅ Return DTO (data transfer object)
public class UserDto
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string Email { get; set; }
    // Password NOT included
}

public IActionResult GetUser(int id)
{
    var user = _repository.GetUser(id);
    var dto = new UserDto { Id = user.Id, Name = user.Name, Email = user.Email };
    return Ok(dto);
}
```

### Error Handling

```csharp
// ✅ Consistent error response
[ExceptionFilter]
public class GlobalExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        var response = new
        {
            error = "Internal Server Error",
            details = context.Exception.Message,
            traceId = context.HttpContext.TraceIdentifier
        };
        
        context.Result = new ObjectResult(response)
        {
            StatusCode = StatusCodes.Status500InternalServerError
        };
    }
}
```

### Status Codes

```csharp
// 2xx: Success
200 OK - Successful GET/PUT
201 Created - Successful POST (new resource)
204 No Content - Successful DELETE

// 4xx: Client error
400 Bad Request - Invalid input
401 Unauthorized - Not authenticated
403 Forbidden - Authenticated but no permission
404 Not Found - Resource doesn't exist
409 Conflict - Request conflicts with state

// 5xx: Server error
500 Internal Server Error - Unhandled exception
503 Service Unavailable - Server down

public IActionResult CreateUser(CreateUserRequest request)
{
    if (request == null)
        return BadRequest("Request cannot be null");
    
    if (UserExists(request.Email))
        return Conflict("Email already in use");
    
    var user = _userService.CreateUser(request);
    return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
}
```

### Async/Await

```csharp
// ✅ Always async for I/O operations
public async Task<IActionResult> GetUser(int id)
{
    var user = await _repository.GetUserAsync(id);
    return Ok(user);
}

// ❌ Don't block on async
public IActionResult GetUser(int id)
{
    var user = _repository.GetUserAsync(id).Result;  // Deadlock risk!
    return Ok(user);
}
```

---

**Key Takeaway**: ASP.NET Core is powerful and flexible. Master the fundamentals (middleware, DI, filters), choose your pattern (controllers vs minimal), and follow conventions for maintainability.

---

<a id="aspf-mastery"></a>
# Applied ASP.NET Core Fundamentals

These walkthroughs connect hosting fundamentals to the production failures caused by incorrect middleware order, dependency lifetimes, abandoned requests, and invalid configuration.

References: [Middleware ordering](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/), [request cancellation](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/use-http-context#requestaborted), and [the options pattern](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options).

## ASPF-M1 — Build the Middleware Pipeline in Dependency Order

**Question:** Why does middleware order affect security and behavior?

**Answer:** Requests execute middleware in registration order and responses unwind in reverse order. A middleware can only use state established earlier, and a terminal middleware can prevent everything after it from running.

**What problem does it solve?** Correct ordering ensures exceptions are caught, routing metadata exists before endpoint-specific policies, authentication establishes the principal before authorization, and endpoints execute only after cross-cutting policies.

**Before this concept:** Middleware is added in a convenient-looking order without considering dependencies.

❌ **Wrong/before example:**

```csharp
app.UseAuthorization();     // no authenticated principal yet
app.MapControllers();      // endpoints become terminal
app.UseAuthentication();   // too late for mapped endpoints
app.UseExceptionHandler(); // cannot catch earlier failures
```

✅ **After/correct example:**

```csharp
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler();
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors("trusted-clients");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();
```

**How it works now:** Error handling surrounds downstream work. Routing identifies the endpoint, CORS applies before authorization responses are returned, authentication constructs `HttpContext.User`, authorization evaluates endpoint requirements, and the selected endpoint runs last.

**Trade-offs and when not to use it:** The exact order depends on the application. Static files placed early are efficient but public unless protected by a different design. Compression and caching order changes what representation is cached. Document intentional deviations next to the pipeline.

**Production checks:** Test anonymous, forbidden, CORS preflight, rate-limited, and exception responses. Verify security headers on failures as well as successes, and add an integration test that would fail if authentication/authorization order is reversed.

**Try it:** Move authentication after authorization in a test application, call a protected endpoint, and trace which middleware sees an authenticated principal.

---

## ASPF-M2 — Match Dependency Lifetime to Ownership

**Question:** What happens when a singleton captures a scoped dependency such as `DbContext`?

**Answer:** The singleton outlives the request scope that created the scoped object. It may retain disposed state, share a non-thread-safe context across requests, and mix request-specific data between users.

**What problem does it solve?** Correct lifetimes align creation, sharing, and disposal with ownership: transient for short independent objects, scoped for one request/unit of work, and singleton only for thread-safe application-wide services.

**Before this concept:** A “manager” is made singleton for performance even though it depends on request-scoped persistence.

❌ **Wrong/before example:**

```csharp
builder.Services.AddDbContext<AppDbContext>();          // scoped
builder.Services.AddSingleton<OrderManager>();          // captures scoped DbContext

public sealed class OrderManager(AppDbContext db)
{
    public Task<Order?> Find(Guid id, CancellationToken ct) =>
        db.Orders.FindAsync([id], ct).AsTask();
}
```

✅ **After/correct example:**

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddSingleton<ISystemClock, SystemClock>(); // stateless/thread-safe

public sealed class OrderService(AppDbContext db, ISystemClock clock)
{
    public async Task<Order?> Find(Guid tenantId, Guid id, CancellationToken ct) =>
        await db.Orders.SingleOrDefaultAsync(
            x => x.TenantId == tenantId && x.Id == id, ct);
}
```

**How it works now:** Each request receives one context and one order service. They share one unit of work and are disposed together. The singleton clock holds no request or mutable tenant state.

**Trade-offs and when not to use it:** Do not make every service scoped automatically. Stateless formatters and expensive thread-safe clients can be singleton; typed `HttpClient` instances are created through the factory. A very large constructor graph signals design coupling, not a reason to inject `IServiceProvider`.

**Production checks:** Enable scope validation, avoid storing `HttpContext`, user claims, or tenant IDs in singletons, and create an explicit scope when singleton background infrastructure must execute scoped application work.

**Try it:** Write two parallel request tests and prove no mutable per-user value is stored in a singleton service.

---

## ASPF-M3 — Propagate Request Cancellation

**Question:** Why should endpoint cancellation flow into database and HTTP calls?

**Answer:** ASP.NET Core binds a `CancellationToken` parameter to the request-aborted signal. Passing it through allows expensive I/O to stop when the client disconnects, an upstream deadline expires, or the server begins shutting down.

**What problem does it solve?** It prevents abandoned requests from continuing to consume database connections, outbound sockets, CPU, and queue capacity after nobody can use the response.

**Before this concept:** The endpoint accepts cancellation but lower layers ignore it.

❌ **Wrong/before example:**

```csharp
app.MapGet("/reports/{id:guid}", async (Guid id, ReportService reports) =>
{
    var report = await reports.Build(id); // request cancellation is lost
    return Results.Ok(report);
});

public Task<Report> Build(Guid id) =>
    db.Reports.SingleAsync(x => x.Id == id); // no token
```

✅ **After/correct example:**

```csharp
app.MapGet("/reports/{id:guid}", async (
    Guid id, ReportService reports, CancellationToken ct) =>
{
    var report = await reports.Build(id, ct);
    return report is null ? Results.NotFound() : Results.Ok(report);
});

public sealed class ReportService(AppDbContext db, HttpClient pricing)
{
    public async Task<ReportDto?> Build(Guid id, CancellationToken ct)
    {
        var report = await db.Reports
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new ReportDto(x.Id, x.Total))
            .SingleOrDefaultAsync(ct);

        if (report is null) return null;
        var rates = await pricing.GetFromJsonAsync<Rates>("/rates", ct)
            ?? throw new InvalidOperationException("Pricing returned an empty response.");
        return report with { ConvertedTotal = report.Total * rates.Usd };
    }
}
```

**How it works now:** Request cancellation reaches EF Core and `HttpClient`. Cooperative operations throw `OperationCanceledException`; the framework stops producing a response for a disconnected client instead of treating cancellation as an application failure.

**Trade-offs and when not to use it:** Do not cancel a durable operation merely because the client disconnected after it was accepted. For payments or queued jobs, commit an idempotent command and let its lifecycle continue independently. Cancellation is cooperative, not a transaction rollback mechanism.

**Production checks:** Combine request cancellation with explicit outbound timeouts, distinguish cancellation from faults in telemetry, and test a disconnected client against a deliberately slow dependency.

**Try it:** Cancel a request while EF Core is waiting and confirm the connection returns to the pool promptly.

---

## ASPF-M4 — Bind and Validate Configuration at Startup

**Question:** Why is reading configuration strings throughout business code risky?

**Answer:** Raw string lookups are untyped, easy to misspell, and often fail only when a rarely used path executes. Bind related settings to a focused options type and validate required values and ranges during startup.

**What problem does it solve?** Invalid configuration prevents the instance from becoming ready instead of causing delayed null errors, insecure defaults, or partially working deployments.

**Before this concept:**

❌ **Wrong/before example:**

```csharp
public sealed class ReceiptSender(IConfiguration configuration)
{
    public Task Send(Receipt receipt) => smtp.SendAsync(
        configuration["Smtp:Host"] ?? "localhost",
        int.Parse(configuration["Smtp:Port"] ?? "25"),
        receipt);
}
```

✅ **After/correct example:**

```csharp
public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    [Required, MinLength(3)]
    public required string Host { get; init; }

    [Range(1, 65535)]
    public int Port { get; init; }

    [Required]
    public required string CredentialReference { get; init; }
}

builder.Services.AddOptions<SmtpOptions>()
    .Bind(builder.Configuration.GetRequiredSection(SmtpOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

public sealed class ReceiptSender(IOptions<SmtpOptions> options)
{
    private readonly SmtpOptions settings = options.Value;

    public Task Send(Receipt receipt, CancellationToken ct) =>
        smtp.SendAsync(settings.Host, settings.Port, receipt, ct);
}
```

**How it works now:** Configuration providers populate one typed object. Startup validation fails the instance before it receives traffic when required settings are absent or invalid. Consumers depend only on the settings they use.

**Trade-offs and when not to use it:** `IOptions<T>` is stable for the application lifetime, `IOptionsSnapshot<T>` is scoped and refreshed per request, and `IOptionsMonitor<T>` observes changes. Runtime reload is useful only when consumers can safely handle invalid or partially applied changes.

**Production checks:** Store secrets in an approved secret provider, not source-controlled JSON; log option names but never secret values; validate in deployment tests; and decide whether configuration changes require restart or coordinated reload.

**Try it:** Remove `Smtp:Host`, start the application, and verify deployment fails before the readiness probe succeeds.
