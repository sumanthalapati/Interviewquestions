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

---

## ASP.NET Core Basics {#basics}

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

## Project Types & Templates {#project-types}

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

## Application Host & Startup {#host}

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

## Controllers vs Minimal APIs {#controllers-minimal}

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

## Middleware Pipeline {#middleware}

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

## Filters & Attributes {#filters}

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

## Dependency Injection {#di}

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

## Best Practices {#best-practices}

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
