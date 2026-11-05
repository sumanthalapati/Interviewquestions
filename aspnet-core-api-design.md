# ASP.NET Core API Design & Architecture

Complete guide to designing robust, maintainable APIs with .NET including REST, versioning, validation, security, and reliability patterns.

---

## Table of Contents
1. [REST Fundamentals](#rest)
2. [API Versioning](#versioning)
3. [Validation & Error Handling](#validation)
4. [Authentication & Authorization](#auth)
5. [API Documentation (Swagger)](#swagger)
6. [Rate Limiting](#rate-limiting)
7. [Caching](#caching)
8. [Data Mapping](#mapping)
9. [Applied API Mastery](#aspa-mastery)

---

<a id="rest"></a>
## REST Fundamentals

### REST Principles

**Resource-Based URLs**
```
❌ Bad (verb-based):
GET /getUser
POST /createUser
DELETE /removeUser

✅ Good (resource-based):
GET /users/{id}
POST /users
DELETE /users/{id}
```

**HTTP Methods**
```
GET     - Retrieve (safe, idempotent)
POST    - Create new resource
PUT     - Replace entire resource (idempotent)
PATCH   - Partial update
DELETE  - Remove (idempotent)
HEAD    - Like GET, but no body
OPTIONS - Describe communication options

Idempotent: Same request multiple times = same result
- GET /users/1 (called 10x = same result)
- PUT /users/1 {update} (called 10x = same state)
- DELETE /users/1 (called 10x = resource deleted, subsequent calls 404)

NOT idempotent:
- POST /users (called 10x = 10 users created)
```

**HTTP Status Codes**
```
1xx: Informational (100 Continue)
2xx: Success
  - 200 OK (GET, PUT, DELETE successful)
  - 201 Created (POST successful, return created resource)
  - 204 No Content (DELETE successful, no body)
  - 206 Partial Content (large response, return part)

3xx: Redirection
  - 301 Moved Permanently
  - 302 Found (temporary redirect)
  - 304 Not Modified (cache valid, use local copy)

4xx: Client Error
  - 400 Bad Request (invalid input)
  - 401 Unauthorized (not authenticated)
  - 403 Forbidden (authenticated, but no permission)
  - 404 Not Found
  - 409 Conflict (resource state conflict)
  - 422 Unprocessable Entity (validation failed)
  - 429 Too Many Requests (rate limited)

5xx: Server Error
  - 500 Internal Server Error
  - 503 Service Unavailable
```

### REST API Example

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
    
    // GET /api/users - List all (with pagination)
    [HttpGet]
    [ProducesResponseType(typeof(PaginatedList<UserDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUsers(int pageNumber = 1, int pageSize = 10)
    {
        var users = await _userService.GetUsersAsync(pageNumber, pageSize);
        return Ok(users);
    }
    
    // GET /api/users/{id} - Get by ID
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUser(int id)
    {
        var user = await _userService.GetUserAsync(id);
        if (user == null)
            return NotFound();
        return Ok(user);
    }
    
    // POST /api/users - Create new
    [HttpPost]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateUser(CreateUserRequest request)
    {
        var user = await _userService.CreateUserAsync(request);
        return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
    }
    
    // PUT /api/users/{id} - Update entire resource
    [HttpPut("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateUser(int id, UpdateUserRequest request)
    {
        var success = await _userService.UpdateUserAsync(id, request);
        if (!success)
            return NotFound();
        return NoContent();
    }
    
    // PATCH /api/users/{id} - Partial update
    [HttpPatch("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> PatchUser(int id, JsonPatchDocument<UpdateUserRequest> patchDoc)
    {
        var user = await _userService.GetUserAsync(id);
        if (user == null)
            return NotFound();
        
        var updateRequest = new UpdateUserRequest { /* map from user */ };
        patchDoc.ApplyTo(updateRequest);
        
        await _userService.UpdateUserAsync(id, updateRequest);
        return NoContent();
    }
    
    // DELETE /api/users/{id} - Delete
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteUser(int id)
    {
        var success = await _userService.DeleteUserAsync(id);
        if (!success)
            return NotFound();
        return NoContent();
    }
}
```

---

<a id="versioning"></a>
## API Versioning

### URL Versioning

```csharp
// /api/v1/users
// /api/v2/users (breaking change)

[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
public class UsersController : ControllerBase
{
    [HttpGet]
    [MapToApiVersion("1.0")]
    public IActionResult GetUsersV1()
    {
        // Old version: return simple data
        return Ok(new { id = 1, name = "Alice" });
    }
    
    [HttpGet]
    [MapToApiVersion("2.0")]
    public IActionResult GetUsersV2()
    {
        // New version: more fields, different structure
        return Ok(new { id = 1, name = "Alice", email = "alice@example.com", role = "Admin" });
    }
}
```

**Pros**: Clear, explicit versioning
**Cons**: Duplicated code, ugly URLs

### Header Versioning

```
GET /api/users
Header: API-Version: 1.0

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    [HttpGet]
    [ApiVersion("1.0")]
    public IActionResult GetUsersV1() { ... }
    
    [HttpGet]
    [ApiVersion("2.0")]
    public IActionResult GetUsersV2() { ... }
}
```

**Pros**: Clean URLs
**Cons**: Less discoverable (header hidden)

### Query Parameter Versioning

```
GET /api/users?version=1.0

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    [HttpGet]
    [ApiVersion("1.0")]
    public IActionResult GetUsersV1() { ... }
    
    [HttpGet]
    [ApiVersion("2.0")]
    public IActionResult GetUsersV2() { ... }
}
```

### Deprecation Strategy

```csharp
[Deprecated("Use v2 instead")]
[HttpGet]
[MapToApiVersion("1.0")]
public IActionResult GetUsersV1()
{
    Response.Headers.Add("Deprecation", "true");
    Response.Headers.Add("Sunset", "Sun, 31 Dec 2024 23:59:59 GMT");
    
    return Ok(new { /* v1 data */ });
}

// Client sees headers, knows to upgrade
// Sunset: deadline for removing this version
```

---

<a id="validation"></a>
## Validation & Error Handling

### Model Validation

```csharp
public class CreateUserRequest
{
    [Required]
    [StringLength(100, MinimumLength = 2)]
    public string Name { get; set; }
    
    [Required]
    [EmailAddress]
    public string Email { get; set; }
    
    [Range(18, 120)]
    public int Age { get; set; }
    
    [Phone]
    public string Phone { get; set; }
    
    [CustomValidation(typeof(CreateUserRequest), nameof(ValidateName))]
    public string Username { get; set; }
}

public static ValidationResult ValidateName(string username, ValidationContext context)
{
    if (username.Contains(" "))
        return new ValidationResult("Username cannot contain spaces");
    return ValidationResult.Success;
}

[HttpPost]
public IActionResult CreateUser(CreateUserRequest request)
{
    // ASP.NET Core validates automatically (if invalid, returns 400)
    if (!ModelState.IsValid)
        return BadRequest(ModelState);
    
    // Valid - continue
    var user = _userService.CreateUser(request);
    return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
}
```

### FluentValidation (Better Alternative)

```csharp
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .Length(2, 100);
        
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress();
        
        RuleFor(x => x.Age)
            .InclusiveBetween(18, 120);
        
        RuleFor(x => x.Username)
            .NotEmpty()
            .Must(x => !x.Contains(" "))
            .WithMessage("Username cannot contain spaces")
            .Must(x => !UsernameExists(x))
            .WithMessage("Username already taken");
    }
    
    private bool UsernameExists(string username)
    {
        // Check if username exists in database
        return false;
    }
}

// Register in Program.cs
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddValidatorsFromAssemblyContaining<CreateUserRequestValidator>();
```

### Global Error Handler

```csharp
public class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;
    
    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
    {
        _logger = logger;
    }
    
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, 
        Exception exception, 
        CancellationToken cancellationToken)
    {
        _logger.LogError(exception, "An unhandled exception occurred");
        
        var response = new
        {
            error = exception.GetType().Name,
            message = exception.Message,
            traceId = httpContext.TraceIdentifier
        };
        
        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await httpContext.Response.WriteAsJsonAsync(response, cancellationToken);
        
        return true;
    }
}

// Register in Program.cs
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
app.UseExceptionHandler();
```

---

<a id="auth"></a>
## Authentication & Authorization

### JWT (JSON Web Token)

```csharp
public class AuthController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly IUserService _userService;
    
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var user = await _userService.ValidateCredentialsAsync(request.Email, request.Password);
        if (user == null)
            return Unauthorized("Invalid credentials");
        
        // Generate JWT
        var token = GenerateJwt(user);
        return Ok(new { token });
    }
    
    private string GenerateJwt(UserDto user)
    {
        var key = Encoding.ASCII.GetBytes(_configuration["Jwt:Secret"]);
        
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role)
            }),
            Expires = DateTime.UtcNow.AddHours(24),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };
        
        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}

// Configure JWT in Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.ASCII.GetBytes(_configuration["Jwt:Secret"])),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true
        };
    });

app.UseAuthentication();
app.UseAuthorization();
```

### Role-Based Authorization

```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]  // Requires authentication
public class AdminController : ControllerBase
{
    [Authorize(Roles = "Admin")]  // Only Admin role
    [HttpDelete("users/{id}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        await _userService.DeleteUserAsync(id);
        return NoContent();
    }
    
    [Authorize(Roles = "Admin,Moderator")]  // Either Admin or Moderator
    [HttpPost("ban-user/{id}")]
    public async Task<IActionResult> BanUser(int id)
    {
        await _userService.BanUserAsync(id);
        return NoContent();
    }
}
```

---

<a id="swagger"></a>
## API Documentation (Swagger)

```csharp
// Program.cs
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "User API",
        Version = "v1",
        Description = "API for managing users",
        Contact = new OpenApiContact
        {
            Name = "Support",
            Email = "support@example.com"
        }
    });
    
    // Include XML comments
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    options.IncludeXmlComments(xmlPath);
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "User API V1");
});
```

### XML Documentation

```csharp
/// <summary>
/// Get a user by ID
/// </summary>
/// <param name="id">The user ID</param>
/// <returns>The user details</returns>
/// <response code="200">Returns the user</response>
/// <response code="404">User not found</response>
[HttpGet("{id}")]
[ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<IActionResult> GetUser(int id)
{
    var user = await _userService.GetUserAsync(id);
    return user == null ? NotFound() : Ok(user);
}
```

---

<a id="rate-limiting"></a>
## Rate Limiting

```csharp
// Program.cs
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter(policyName: "fixed", configure: options =>
    {
        options.PermitLimit = 100;
        options.Window = TimeSpan.FromMinutes(1);
    });
    
    options.AddSlidingWindowLimiter(policyName: "sliding", configure: options =>
    {
        options.PermitLimit = 50;
        options.Window = TimeSpan.FromMinutes(1);
        options.SegmentsPerWindow = 2;
    });
});

app.UseRateLimiter();

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    [HttpGet]
    [RequireRateLimitPolicy("fixed")]
    public IActionResult GetUsers()
    {
        return Ok();
    }
}
```

---

<a id="caching"></a>
## Caching

```csharp
public class UserService : IUserService
{
    private readonly IMemoryCache _cache;
    private readonly IUserRepository _repository;
    
    public UserService(IMemoryCache cache, IUserRepository repository)
    {
        _cache = cache;
        _repository = repository;
    }
    
    public async Task<UserDto> GetUserAsync(int id)
    {
        var cacheKey = $"user_{id}";
        
        // Try get from cache
        if (_cache.TryGetValue(cacheKey, out UserDto cachedUser))
            return cachedUser;
        
        // Not in cache, fetch from database
        var user = await _repository.GetUserAsync(id);
        
        // Store in cache (10 minutes)
        var cacheOptions = new MemoryCacheEntryOptions()
            .SetAbsoluteExpiration(TimeSpan.FromMinutes(10));
        
        _cache.Set(cacheKey, user, cacheOptions);
        return user;
    }
    
    public async Task<UserDto> UpdateUserAsync(int id, UpdateUserRequest request)
    {
        var user = await _repository.UpdateUserAsync(id, request);
        
        // Invalidate cache
        _cache.Remove($"user_{id}");
        
        return user;
    }
}
```

---

<a id="mapping"></a>
## Data Mapping

### AutoMapper

```csharp
public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<User, UserDto>().ReverseMap();
        CreateMap<CreateUserRequest, User>();
        CreateMap<UpdateUserRequest, User>();
    }
}

// Register in Program.cs
builder.Services.AddAutoMapper(typeof(MappingProfile));

// Use in controller
[HttpGet("{id}")]
public async Task<IActionResult> GetUser(int id)
{
    var user = await _repository.GetUserAsync(id);
    var userDto = _mapper.Map<UserDto>(user);
    return Ok(userDto);
}
```

---

**Key Takeaway**: Design RESTful APIs with clear principles. Validate input, handle errors consistently, version thoughtfully, and document thoroughly.

---

<a id="aspa-mastery"></a>
# Applied API Mastery

These walkthroughs focus on API contracts that remain correct during failures, retries, concurrent updates, authorization decisions, and large datasets.

References: [ASP.NET Core API error handling](https://learn.microsoft.com/en-us/aspnet/core/web-api/handle-errors) and [resource-based authorization](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/resource-based).

## ASPA-M1 — Return One Stable Problem Details Contract

**Question:** How should an API translate exceptions and validation failures into client-safe responses?

**Answer:** Map known failure categories to stable HTTP status codes and machine-readable problem types at one boundary. Return safe details plus a correlation identifier; log the full exception internally.

**What problem does it solve?** Clients stop parsing arbitrary strings, controllers stop repeating `try/catch`, and stack traces or database details do not leak into public responses.

**Before this concept:** Every endpoint invents an error shape and catches `Exception` locally.

❌ **Wrong/before example:**

```csharp
try
{
    return Ok(await service.PlaceOrder(request));
}
catch (Exception ex)
{
    return StatusCode(500, new { error = ex.ToString() }); // leaks internals
}
```

✅ **After/correct example:**

```csharp
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ApiExceptionHandler>();

app.UseExceptionHandler();
```

```csharp
public sealed class ApiExceptionHandler(
    IProblemDetailsService problemDetails,
    ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context, Exception exception, CancellationToken ct)
    {
        var (status, type, title) = exception switch
        {
            DomainValidationException =>
                (StatusCodes.Status400BadRequest, "validation_failed", "Validation failed"),
            ResourceNotFoundException =>
                (StatusCodes.Status404NotFound, "resource_not_found", "Resource not found"),
            DomainConflictException =>
                (StatusCodes.Status409Conflict, "domain_conflict", "The request conflicts with current state"),
            _ =>
                (StatusCodes.Status500InternalServerError, "unexpected_error", "Unexpected server error")
        };

        logger.LogError(exception,
            "Request failed with {ProblemType}; TraceId={TraceId}", type, context.TraceIdentifier);

        context.Response.StatusCode = status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Type = $"https://api.example.com/problems/{type}",
                Title = title,
                Extensions = { ["traceId"] = context.TraceIdentifier }
            }
        });
    }
}
```

**How it works now:** Unhandled exceptions reach one early exception handler. Known domain failures become stable public contracts; unexpected failures become a generic 500. Logs retain diagnostic detail linked by `traceId`.

**Trade-offs and when not to use it:** Do not use exceptions for ordinary branching such as “search returned no rows.” Return an explicit result when rejection is expected. Problem Details standardizes shape, not your domain taxonomy; document stable type identifiers and fields.

**Production checks:** Never expose stack traces, SQL, secrets, or personal data. Test content type and schema for every status code, keep problem types backward compatible, and sample repeated expected failures separately from unexpected exceptions.

**Try it:** Trigger validation, not-found, conflict, and unexpected failures and verify all four responses share the same envelope and correlation field.

---

## ASPA-M2 — Authorize the Loaded Resource, Not Only the Route

**Question:** Why is `[Authorize]` insufficient when users may edit only their own tenant’s orders?

**Answer:** Authentication proves identity and route-level policy proves broad capability. Resource authorization evaluates the actual loaded order, requested operation, tenant, ownership, and current claims before mutation.

**What problem does it solve?** It prevents insecure direct object reference attacks where an authorized user changes an ID in the URL to access another user’s resource.

**Before this concept:** Any authenticated user can edit any order whose identifier they can guess.

❌ **Wrong/before example:**

```csharp
[Authorize]
[HttpPut("orders/{id:guid}")]
public async Task<IActionResult> Update(Guid id, UpdateOrder request)
{
    var order = await db.Orders.FindAsync(id);
    order!.ChangeAddress(request.Address);
    await db.SaveChangesAsync();
    return NoContent();
}
```

✅ **After/correct example:**

```csharp
public sealed record EditOrderRequirement : IAuthorizationRequirement;

public sealed class EditOrderHandler
    : AuthorizationHandler<EditOrderRequirement, Order>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        EditOrderRequirement requirement,
        Order order)
    {
        var subject = context.User.FindFirstValue("sub");
        if (subject == order.CustomerSubject || context.User.HasClaim("permission", "orders.manage"))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

```csharp
[Authorize]
[HttpPut("orders/{id:guid}")]
public async Task<IActionResult> Update(
    Guid id, UpdateOrder request, CancellationToken ct)
{
    var tenantId = User.GetRequiredTenantId();
    var order = await db.Orders.SingleOrDefaultAsync(
        x => x.TenantId == tenantId && x.Id == id, ct);
    if (order is null) return NotFound();

    var decision = await authorization.AuthorizeAsync(
        User, order, new EditOrderRequirement());
    if (!decision.Succeeded) return Forbid();

    order.ChangeAddress(request.Address);
    await db.SaveChangesAsync(ct);
    return NoContent();
}
```

**How it works now:** Tenant filtering prevents cross-tenant retrieval and avoids revealing whether another tenant’s ID exists. The handler then evaluates ownership or delegated permission against the real resource before the command executes.

**Trade-offs and when not to use it:** A simple endpoint-wide requirement is enough when every authorized caller can access every resource. Resource checks require loading enough metadata to decide; avoid loading a huge object graph merely for authorization.

**Production checks:** Deny by default, test tenant A against tenant B, re-evaluate long-lived permissions, audit sensitive operations, and apply the same rules to background jobs and message consumers—not only controllers.

**Try it:** Write integration tests for anonymous, wrong-tenant, same-tenant non-owner, owner, and delegated administrator requests.

---

## ASPA-M3 — Make Retried Create Requests Idempotent

**Question:** How can a client safely retry `POST /orders` after a timeout without creating two orders?

**Answer:** Require an idempotency key, scope it to tenant and operation, bind it to a request hash, and store the final response atomically with the created state. The same key and payload returns the original result; the same key with a different payload is rejected.

**What problem does it solve?** It handles the ambiguous outcome where the server committed successfully but the response was lost before the client received it.

**Before this concept:**

❌ **Wrong/before example:**

```csharp
app.MapPost("/orders", async (CreateOrder request, AppDbContext db, CancellationToken ct) =>
{
    var order = Order.Create(request);
    db.Orders.Add(order);
    await db.SaveChangesAsync(ct);
    return Results.Created($"/orders/{order.Id}", new { order.Id });
});
```

✅ **After/correct example:**

```csharp
app.MapPost("/orders", async (
    HttpRequest http,
    CreateOrder request,
    AppDbContext db,
    CancellationToken ct) =>
{
    var key = http.Headers["Idempotency-Key"].SingleOrDefault();
    if (string.IsNullOrWhiteSpace(key))
        return Results.BadRequest(new { code = "idempotency_key_required" });

    var tenantId = http.HttpContext.User.GetRequiredTenantId();
    var requestHash = RequestHasher.Sha256(request);

    var existing = await db.IdempotencyRecords.SingleOrDefaultAsync(
        x => x.TenantId == tenantId && x.Operation == "create-order" && x.Key == key, ct);

    if (existing is not null)
        return existing.RequestHash == requestHash
            ? Results.Content(existing.ResponseBody, "application/json", statusCode: existing.StatusCode)
            : Results.Conflict(new { code = "idempotency_key_reused" });

    await using var transaction = await db.Database.BeginTransactionAsync(ct);
    var order = Order.Create(tenantId, request);
    var body = JsonSerializer.Serialize(new { order.Id });

    db.Orders.Add(order);
    db.IdempotencyRecords.Add(new IdempotencyRecord(
        tenantId, "create-order", key, requestHash,
        StatusCodes.Status201Created, body));

    try
    {
        await db.SaveChangesAsync(ct); // unique index: tenant + operation + key
        await transaction.CommitAsync(ct);
        return Results.Content(body, "application/json", statusCode: StatusCodes.Status201Created);
    }
    catch (DbUpdateException exception)
    {
        await transaction.RollbackAsync(ct);
        if (!IdempotencyRace.IsUniqueKeyConflict(exception)) throw;

        db.ChangeTracker.Clear();
        var winner = await IdempotencyRace.LoadWinner(db, tenantId, "create-order", key, ct);
        return winner.RequestHash == requestHash
            ? Results.Content(winner.ResponseBody, "application/json", statusCode: winner.StatusCode)
            : Results.Conflict(new { code = "idempotency_key_reused" });
    }
});
```

**How it works now:** The unique database constraint chooses one winner under concurrent retries. The committed response is replayable, and request-hash comparison prevents accidental use of the same key for different commands.

**Trade-offs and when not to use it:** Records require retention and cleanup. For an external payment, forward a stable idempotency key to the provider and use an outbox/state machine; a local transaction cannot atomically control a remote API.

**Production checks:** Limit key length, scope keys by principal/tenant and operation, hash a canonical request representation, redact bodies, define expiry, and test two simultaneous identical requests.

**Try it:** Send ten concurrent requests with the same key and assert one order exists and every successful response contains the same order ID.

---

## ASPA-M4 — Use Stable Cursor Pagination for Changing Data

**Question:** Why can offset pagination skip or duplicate records while rows are inserted?

**Answer:** Offset counts positions in a changing result set. Cursor pagination resumes after a stable ordered key, usually a unique tie-breaker combined with the business sort column.

**What problem does it solve?** It keeps page traversal stable and avoids scanning/discarding an ever-growing number of preceding rows.

**Before this concept:**

❌ **Wrong/before example:**

```csharp
var orders = await db.Orders
    .OrderByDescending(x => x.CreatedAt)
    .Skip(page * 100)
    .Take(100)
    .ToListAsync(ct);
```

If a newer order arrives between page requests, every later offset shifts.

✅ **After/correct example:**

```csharp
public sealed record OrderCursor(DateTimeOffset CreatedAt, long Sequence);
public sealed record OrderPageRow(
    Guid Id, DateTimeOffset CreatedAt, long Sequence, OrderStatus Status, decimal Total);

app.MapGet("/orders", async (
    string? after, int? limit, AppDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
{
    var size = Math.Clamp(limit ?? 50, 1, 100);
    var cursor = after is null ? null : CursorCodec.Decode<OrderCursor>(after);
    var tenantId = user.GetRequiredTenantId();

    var query = db.Orders.AsNoTracking().Where(x => x.TenantId == tenantId);
    if (cursor is not null)
    {
        query = query.Where(x =>
            x.CreatedAt < cursor.CreatedAt ||
            (x.CreatedAt == cursor.CreatedAt && x.Sequence < cursor.Sequence));
    }

    var rows = await query
        .OrderByDescending(x => x.CreatedAt)
        .ThenByDescending(x => x.Sequence)
        .Select(x => new OrderPageRow(x.Id, x.CreatedAt, x.Sequence, x.Status, x.Total))
        .Take(size + 1)
        .ToListAsync(ct);

    var hasMore = rows.Count > size;
    var pageRows = rows.Take(size).ToList();
    var items = pageRows.Select(x =>
        new OrderSummary(x.Id, x.CreatedAt, x.Status, x.Total)).ToList();
    var next = hasMore
        ? CursorCodec.Encode(new OrderCursor(pageRows[^1].CreatedAt, pageRows[^1].Sequence))
        : null;

    return Results.Ok(new { items, next });
});
```

**How it works now:** The pair `(CreatedAt, Sequence)` defines a unique total order. `Sequence` is an immutable, unique, monotonically increasing value assigned when the order is created. The next query continues strictly after the last returned pair, and `size + 1` detects another page without a separate count query.

**Trade-offs and when not to use it:** Cursors do not provide direct “jump to page 47.” Offset pagination is acceptable for small, stable administrative lists. Encode and sign opaque cursors when clients must not alter filters or sort values.

**Production checks:** Create a matching composite index, include filters in the cursor contract, cap page size, define behavior for deleted rows, and test equal timestamps plus concurrent inserts.

**Try it:** Insert a new first row between page one and page two and compare offset results with cursor results.
