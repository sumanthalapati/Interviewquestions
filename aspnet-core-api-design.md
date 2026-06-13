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

---

## REST Fundamentals {#rest}

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

## API Versioning {#versioning}

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

## Validation & Error Handling {#validation}

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

## Authentication & Authorization {#auth}

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

## API Documentation (Swagger) {#swagger}

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

## Rate Limiting {#rate-limiting}

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

## Caching {#caching}

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

## Data Mapping {#mapping}

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
