# 🌐 ASP.NET MVC Interview Questions — Complete Guide

> **50+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [MVC Pattern & Routing](#1-mvc-pattern--routing)
2. [Controllers & Actions](#2-controllers--actions)
3. [Model Binding & Validation](#3-model-binding--validation)
4. [Filters](#4-filters)
5. [Dependency Injection](#5-dependency-injection)
6. [Middleware](#6-middleware)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [Views & Razor](#8-views--razor)
9. [Performance & Caching](#9-performance--caching)
10. [Error Handling & Testing](#10-error-handling--testing)

---

# 1. MVC Pattern & Routing

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/overview
> 📚 Routing: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing

---

## 1.1 Routing — Conventional vs Attribute

### Q1. What are the two routing styles in ASP.NET Core and when do you use each?

**Answer:**
Conventional routing is defined in `Program.cs` via templates like `{controller}/{action}/{id?}`. Attribute routing uses `[Route]`, `[HttpGet]`, etc. on controllers/actions. Attribute routing is preferred for APIs — it's explicit and co-located with the code. Conventional routing is common in MVC apps with Razor views.

❌ **Wrong — mixing conventional routes in an API project, ambiguous URLs:**
```csharp
// Program.cs — conventional routing on a Web API
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
// API URLs become /Products/GetById/5 — not RESTful, not explicit
```

✅ **Correct — attribute routing on API controllers:**
```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase {
    [HttpGet("{id:int}")]               // GET api/products/5
    public async Task<IActionResult> GetById(int id) { ... }

    [HttpPost]                          // POST api/products
    public async Task<IActionResult> Create([FromBody] CreateProductDto dto) { ... }

    [HttpDelete("{id:int}")]            // DELETE api/products/5
    public async Task<IActionResult> Delete(int id) { ... }
}
```

---

## 1.2 Route Constraints

### Q2. How do route constraints prevent invalid requests from reaching your controller?

**Answer:**
Route constraints (`{id:int}`, `{slug:alpha}`, `{date:datetime}`) validate route values before the action is invoked, returning 404 automatically for invalid formats rather than requiring manual checks in the action.

❌ **Wrong — no constraint, manual validation inside the action:**
```csharp
[HttpGet("{id}")]
public IActionResult Get(string id) {
    if (!int.TryParse(id, out int numericId))
        return BadRequest("ID must be an integer");
    // Unnecessary — the route should enforce this
    ...
}
```

✅ **Correct — constraint enforced at routing level:**
```csharp
[HttpGet("{id:int:min(1)}")]   // must be int AND >= 1
public async Task<IActionResult> Get(int id) {
    var product = await _service.GetByIdAsync(id);
    return product is null ? NotFound() : Ok(product);
}
```

---

# 2. Controllers & Actions

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/actions
> 📚 ApiController: https://learn.microsoft.com/en-us/aspnet/core/web-api/

---

## 2.1 [ApiController] Attribute

### Q3. What does `[ApiController]` do and why should you use it?

**Answer:**
`[ApiController]` enables: automatic 400 responses when ModelState is invalid, binding source inference, Problem Details error format (RFC 7807), and requires attribute routing. Removes boilerplate validation checks from every action.

❌ **Wrong — manually checking ModelState in every action without [ApiController]:**
```csharp
[Controller]
public class ProductsController : ControllerBase {
    [HttpPost]
    public IActionResult Create([FromBody] CreateProductDto dto) {
        if (!ModelState.IsValid)         // repeated in EVERY action
            return BadRequest(ModelState);
        // logic...
    }
}
```

✅ **Correct — [ApiController] handles validation automatically:**
```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase {
    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create([FromBody] CreateProductDto dto) {
        // If dto fails validation, 400 is returned automatically — no manual check needed
        var product = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }
}
```

---

## 2.2 ActionResult<T>

### Q4. What is `ActionResult<T>` and why is it preferred over `IActionResult` for APIs?

**Answer:**
`ActionResult<T>` allows returning either a typed result `T` (for 200 OK) or any `IActionResult` (for 404, 400, etc.). It enables OpenAPI/Swagger to infer the response schema automatically, which `IActionResult` alone cannot.

❌ **Wrong — `IActionResult` loses response type information for OpenAPI:**
```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id) {
    var product = await _service.GetByIdAsync(id);
    return product is null ? NotFound() : Ok(product);
    // Swagger shows response as 'any' — no schema generated
}
```

✅ **Correct — `ActionResult<T>` provides both flexibility and schema:**
```csharp
[HttpGet("{id:int}")]
[ProducesResponseType<ProductDto>(StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<ActionResult<ProductDto>> GetById(int id) {
    var product = await _service.GetByIdAsync(id);
    return product is null ? NotFound() : product; // implicit Ok() wrapping
}
```

---

# 3. Model Binding & Validation

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding
> 📚 Validation: https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation

---

## 3.1 Model Validation with Data Annotations

### Q5. How do you validate request models in ASP.NET Core?

**Answer:**
Use Data Annotations on the DTO class. The framework validates and populates `ModelState`. With `[ApiController]`, invalid models return 400 automatically. For complex rules, use `IValidatableObject` or FluentValidation.

❌ **Wrong — no validation on DTO, validating manually in the action:**
```csharp
[HttpPost]
public IActionResult Create([FromBody] CreateProductDto dto) {
    if (string.IsNullOrEmpty(dto.Name)) return BadRequest("Name required");
    if (dto.Price <= 0) return BadRequest("Price must be positive");
    // Duplicated validation logic, not reusable
}
```

✅ **Correct — validation attributes on the DTO, automatic enforcement:**
```csharp
public class CreateProductDto {
    [Required]
    [MaxLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
    public string Name { get; set; } = string.Empty;

    [Range(0.01, 99999.99, ErrorMessage = "Price must be between 0.01 and 99,999.99")]
    public decimal Price { get; set; }

    [Url]
    public string? ImageUrl { get; set; }
}

[HttpPost]
public async Task<ActionResult<ProductDto>> Create([FromBody] CreateProductDto dto) {
    // [ApiController] returns 400 automatically if dto is invalid
    var product = await _service.CreateAsync(dto);
    return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
}
```

---

# 4. Filters

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters

---

## 4.1 Action Filters for Cross-Cutting Concerns

### Q6. How do you implement a reusable action filter for logging or timing?

**Answer:**
Implement `IActionFilter` (or `IAsyncActionFilter`) and register globally or per controller. Filters run as part of the MVC pipeline and have access to `ActionExecutingContext` / `ActionExecutedContext`.

❌ **Wrong — manual timing code in every action method:**
```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id) {
    var sw = Stopwatch.StartNew();
    try {
        var result = await _service.GetByIdAsync(id);
        return result is null ? NotFound() : Ok(result);
    } finally {
        _logger.LogInformation("GetById took {ms}ms", sw.ElapsedMilliseconds);
        // copied to every action — maintenance nightmare
    }
}
```

✅ **Correct — reusable action filter registered globally:**
```csharp
public class TimingFilter : IAsyncActionFilter {
    private readonly ILogger<TimingFilter> _logger;
    public TimingFilter(ILogger<TimingFilter> logger) => _logger = logger;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next) {
        var sw = Stopwatch.StartNew();
        await next();
        _logger.LogInformation("{Action} took {ms}ms",
            context.ActionDescriptor.DisplayName, sw.ElapsedMilliseconds);
    }
}

// Program.cs — applied to all controllers:
builder.Services.AddControllers(options => options.Filters.Add<TimingFilter>());
builder.Services.AddScoped<TimingFilter>();
```

---

# 5. Dependency Injection

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection

---

## 5.1 Service Lifetimes

### Q7. What are the three DI lifetimes and what happens if you misuse them?

**Answer:**
Transient = new instance per injection. Scoped = one per HTTP request. Singleton = one for the application. Injecting a Scoped service into a Singleton is a "captive dependency" — the singleton holds a stale request-scoped object. ASP.NET Core detects this in development.

❌ **Wrong — scoped DbContext injected into singleton (captive dependency):**
```csharp
// DbContext is Scoped — registered once per request
builder.Services.AddDbContext<AppDbContext>(options => ...);

// BAD: Singleton captures the first-request DbContext forever
builder.Services.AddSingleton<IProductCache>(sp => {
    var db = sp.GetRequiredService<AppDbContext>(); // captured scoped service
    return new ProductCache(db);
});
```

✅ **Correct — use IServiceScopeFactory in singletons to create scopes on demand:**
```csharp
builder.Services.AddSingleton<IProductCache>(sp => {
    var scopeFactory = sp.GetRequiredService<IServiceScopeFactory>();
    return new ProductCache(scopeFactory); // creates a new scope when needed
});

public class ProductCache : IProductCache {
    private readonly IServiceScopeFactory _scopeFactory;
    public ProductCache(IServiceScopeFactory sf) => _scopeFactory = sf;

    public async Task<Product?> GetAsync(int id) {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return await db.Products.FindAsync(id);
    }
}
```

---

# 6. Middleware

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/

---

## 6.1 Middleware Order

### Q8. Why does middleware order in ASP.NET Core matter?

**Answer:**
Middleware executes in registration order on the way in, and in reverse order on the way out. Exception handling must come early to catch errors from later middleware. Authentication before authorization. Static files before routing to short-circuit expensive pipeline for static assets.

❌ **Wrong — authorization before authentication (user is never authenticated):**
```csharp
app.UseRouting();
app.UseAuthorization();    // runs before authentication — always sees unauthenticated user
app.UseAuthentication();   // too late
app.MapControllers();
```

✅ **Correct — proper middleware order:**
```csharp
app.UseExceptionHandler("/error");   // catch errors from everything below
app.UseHttpsRedirection();
app.UseStaticFiles();                // short-circuit before routing
app.UseRouting();
app.UseAuthentication();             // who are you?
app.UseAuthorization();              // what can you do?
app.MapControllers();
```

---

## 6.2 Custom Middleware

### Q9. How do you write and register custom middleware?

**Answer:**
Implement a class with `InvokeAsync(HttpContext context)` and a `RequestDelegate _next` constructor parameter. Call `await _next(context)` to pass to the next component.

❌ **Wrong — modifying the response after `_next` has already written to it:**
```csharp
public async Task InvokeAsync(HttpContext context) {
    await _next(context);
    context.Response.Headers["X-Custom"] = "value"; // may fail — headers already sent
    context.Response.StatusCode = 200;               // invalid after body is written
}
```

✅ **Correct — set headers before calling next:**
```csharp
public class SecurityHeadersMiddleware {
    private readonly RequestDelegate _next;
    public SecurityHeadersMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context) {
        context.Response.OnStarting(() => {
            context.Response.Headers["X-Content-Type-Options"] = "nosniff";
            context.Response.Headers["X-Frame-Options"] = "DENY";
            return Task.CompletedTask;
        });
        await _next(context);
    }
}

app.UseMiddleware<SecurityHeadersMiddleware>();
```

---

# 7. Authentication & Authorization

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/security/authentication/
> 📚 JWT: https://learn.microsoft.com/en-us/aspnet/core/security/authentication/jwt-authn

---

## 7.1 JWT Authentication

### Q10. How do you configure JWT Bearer authentication in ASP.NET Core?

**Answer:**
Register the JWT bearer scheme in `Program.cs` with `TokenValidationParameters`. Always validate issuer, audience, lifetime, and signing key. Store the key in configuration — never hardcode it.

❌ **Wrong — disabling validation, accepting any token:**
```csharp
options.TokenValidationParameters = new TokenValidationParameters {
    ValidateIssuer = false,      // anyone can forge issuer
    ValidateAudience = false,    // wrong audience accepted
    ValidateLifetime = false,    // expired tokens accepted
    ValidateIssuerSigningKey = false // unsigned tokens accepted!
};
```

✅ **Correct — full validation with key from configuration:**
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = config["Jwt:Issuer"],
            ValidAudience = config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(config["Jwt:Key"]!)),
            ClockSkew = TimeSpan.FromSeconds(30) // tight tolerance
        };
    });
```

---

## 7.2 Policy-Based Authorization

### Q11. How does policy-based authorization work in ASP.NET Core?

**Answer:**
Define requirements and handlers. Policies compose multiple requirements. More flexible than role-based auth — supports resource-based decisions, custom claim checks, and async external lookups.

❌ **Wrong — role-based checks scattered in action code, business logic in controller:**
```csharp
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(int id) {
    if (!User.IsInRole("Admin") && !User.IsInRole("Manager"))
        return Forbid();
    // Duplicated in every action that needs this check
}
```

✅ **Correct — policy defined once, applied via attribute:**
```csharp
// Program.cs
builder.Services.AddAuthorization(options => {
    options.AddPolicy("CanManageProducts", policy =>
        policy.RequireAssertion(ctx =>
            ctx.User.IsInRole("Admin") || ctx.User.IsInRole("Manager")));
});

// Controller:
[HttpDelete("{id:int}")]
[Authorize(Policy = "CanManageProducts")]
public async Task<IActionResult> Delete(int id) {
    await _service.DeleteAsync(id);
    return NoContent();
}
```

---

# 8. Views & Razor

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/views/razor
> 📚 Tag Helpers: https://learn.microsoft.com/en-us/aspnet/core/mvc/views/tag-helpers/intro

---

## 8.1 Tag Helpers vs HTML Helpers

### Q12. What is the difference between Tag Helpers and HTML Helpers?

**Answer:**
Tag Helpers look like HTML attributes — they're processed server-side but blend into the markup naturally. HTML Helpers are C# method calls (`@Html.ActionLink(...)`). Tag Helpers are strongly typed, support IntelliSense, and are easier for designers to read.

❌ **Wrong — HTML Helpers, verbose and C#-centric in markup:**
```html
@Html.BeginForm("Create", "Products", FormMethod.Post)
    @Html.LabelFor(m => m.Name)
    @Html.TextBoxFor(m => m.Name, new { @class = "form-control" })
    @Html.ValidationMessageFor(m => m.Name)
    <button type="submit">Save</button>
@Html.EndForm()
```

✅ **Correct — Tag Helpers, clean HTML-like syntax:**
```html
<form asp-action="Create" asp-controller="Products" method="post">
    <label asp-for="Name"></label>
    <input asp-for="Name" class="form-control" />
    <span asp-validation-for="Name" class="text-danger"></span>
    <button type="submit">Save</button>
</form>
```

---

## 8.2 View Components vs Partial Views

### Q13. When should you use a View Component instead of a Partial View?

**Answer:**
Use View Components when the rendered content requires service calls or business logic (cart summary, notification badge). They have their own async Invoke method and are independent mini-controllers. Partial Views are for simple template reuse with data passed from the parent view.

❌ **Wrong — putting service calls inside a Partial View via ViewData (tight coupling, not testable):**
```csharp
// In main controller action — pushing unrelated data for partial
ViewData["CartCount"] = await _cartService.GetCountAsync(userId);
return View();
```
```html
@* Partial view depends on ViewData set by parent controller *@
<span>Cart: @ViewData["CartCount"]</span>
```

✅ **Correct — View Component handles its own data fetching:**
```csharp
public class CartSummaryViewComponent : ViewComponent {
    private readonly ICartService _cartService;
    public CartSummaryViewComponent(ICartService cartService) => _cartService = cartService;

    public async Task<IViewComponentResult> InvokeAsync() {
        var count = await _cartService.GetCountAsync(UserClaimsPrincipal);
        return View(count);
    }
}
```
```html
@* In any view, independently: *@
@await Component.InvokeAsync("CartSummary")
```

---

# 9. Performance & Caching

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/performance/caching/overview
> 📚 Output caching: https://learn.microsoft.com/en-us/aspnet/core/performance/caching/output

---

## 9.1 Output Caching vs Response Caching

### Q14. What is the difference between Output Caching and Response Caching?

**Answer:**
Response Caching (`[ResponseCache]`) relies on HTTP cache headers — the browser or a CDN does the caching. Output Caching (`.NET 7+`) is server-side — the server stores and reserializes the response. Output Caching supports tag-based invalidation and works regardless of client cache settings.

❌ **Wrong — Response Caching on an authenticated endpoint (caches per-user responses globally):**
```csharp
[HttpGet("my-orders")]
[ResponseCache(Duration = 60)]  // caches first user's orders for everyone — security issue
[Authorize]
public async Task<IActionResult> GetMyOrders() { ... }
```

✅ **Correct — Output Caching with a cache key that varies by user:**
```csharp
// Program.cs
builder.Services.AddOutputCache();
app.UseOutputCache();

// Endpoint:
[HttpGet("products")]
[OutputCache(Duration = 60, VaryByQueryKeys = ["category", "page"])]
public async Task<IActionResult> GetProducts([FromQuery] string? category, int page = 1) {
    var products = await _service.GetPagedAsync(category, page);
    return Ok(products);
}
```

---

# 10. Error Handling & Testing

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling
> 📚 Integration testing: https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests

---

## 10.1 Problem Details for APIs

### Q15. How do you return consistent error responses in a Web API?

**Answer:**
Use Problem Details (RFC 7807) via `AddProblemDetails()`. Returns JSON with `type`, `title`, `status`, `detail`. In .NET 8+, implement `IExceptionHandler` for full control over error responses.

❌ **Wrong — inconsistent ad-hoc error objects across controllers:**
```csharp
return BadRequest(new { error = "Name is required" });    // controller A
return NotFound(new { message = "Not found", id = id });  // controller B — different shape!
return StatusCode(500, "Something went wrong");            // controller C — plain string
```

✅ **Correct — unified Problem Details via IExceptionHandler:**
```csharp
// Program.cs
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
app.UseExceptionHandler();

public class GlobalExceptionHandler : IExceptionHandler {
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct) {
        var (status, title) = ex switch {
            NotFoundException => (404, "Resource not found"),
            ValidationException => (400, "Validation failed"),
            _ => (500, "An unexpected error occurred")
        };
        await ctx.Response.WriteAsJsonAsync(new ProblemDetails {
            Status = status, Title = title, Detail = ex.Message
        }, ct);
        return true;
    }
}
```

---

## 10.2 Integration Testing with WebApplicationFactory

### Q16. How do you write integration tests for ASP.NET Core controllers?

**Answer:**
`WebApplicationFactory<TProgram>` spins up the full pipeline in-memory. Override `ConfigureWebHost` to swap real services (like DbContext) for test doubles. Tests exercise real routing, middleware, and serialization.

❌ **Wrong — unit testing the controller directly, misses middleware, routing, and serialization:**
```csharp
[Fact]
public async Task GetProduct_ReturnsOk() {
    var controller = new ProductsController(new MockProductService());
    var result = await controller.GetById(1);
    Assert.IsType<OkObjectResult>(result);
    // Doesn't test routing, auth middleware, JSON serialization, filters, etc.
}
```

✅ **Correct — full integration test with in-memory database:**
```csharp
public class ProductsApiTests : IClassFixture<WebApplicationFactory<Program>> {
    private readonly HttpClient _client;

    public ProductsApiTests(WebApplicationFactory<Program> factory) {
        _client = factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => {
                services.RemoveAll<AppDbContext>();
                services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("TestDb"));
            })).CreateClient();
    }

    [Fact]
    public async Task GetProducts_ReturnsOkWithList() {
        var response = await _client.GetAsync("/api/products");
        response.EnsureSuccessStatusCode();
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        Assert.NotNull(products);
    }
}
```
