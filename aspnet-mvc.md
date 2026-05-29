# ASP.NET MVC Interview Questions

## MVC Pattern & Architecture

**Q1: What is the MVC pattern and how does ASP.NET Core implement it?**

MVC (Model-View-Controller) separates an application into three concerns:
- **Model**: Represents data and business logic.
- **View**: Renders the UI (Razor templates in ASP.NET).
- **Controller**: Handles HTTP requests, coordinates between Model and View, returns responses.

In ASP.NET Core MVC, incoming requests are routed to a controller action. The action interacts with services/models, then returns an `IActionResult` — which could be a `ViewResult`, `JsonResult`, `RedirectResult`, etc. The framework uses dependency injection, middleware, and filters extensively.

**Q2: What is the difference between ASP.NET MVC and ASP.NET Core MVC?**

ASP.NET MVC (5 and earlier) runs only on Windows with the full .NET Framework and IIS. ASP.NET Core MVC is cross-platform, runs on .NET Core/.NET 5+, has a unified framework for MVC and Web API, uses a built-in DI container, features a modular middleware pipeline, and is significantly faster. Core MVC also merges Web API into the same framework — `[ApiController]` and `[Controller]` are in the same namespace.

**Q3: How does routing work in ASP.NET Core MVC?**

ASP.NET Core supports two routing styles:
- **Conventional routing**: Defined in `Program.cs` via `app.MapControllerRoute()`. URL templates like `{controller}/{action}/{id?}` map to controller/action pairs.
- **Attribute routing**: Decorating controllers and actions with `[Route]`, `[HttpGet]`, `[HttpPost]`, etc. Gives fine-grained control over URL structure.

Attribute routing takes precedence and is preferred for APIs. Route parameters can have constraints: `[Route("products/{id:int:min(1)}")]`.

---

## Controllers & Actions

**Q4: What is the difference between `IActionResult` and specific result types like `OkObjectResult`?**

`IActionResult` is the interface all action results implement — it decouples the action method from the specific HTTP response. Returning `IActionResult` lets you return different response types based on conditions (e.g., `Ok()`, `NotFound()`, `BadRequest()`). Returning a concrete type like `OkObjectResult` directly is fine but less flexible. For Web APIs, `ActionResult<T>` combines both — it enables OpenAPI schema generation while still allowing multiple return types.

**Q5: What does `[ApiController]` attribute do?**

`[ApiController]` enables a set of conventions for API controllers:
- Automatic HTTP 400 response when `ModelState.IsValid` is false (no manual check needed).
- Binding source inference: `[FromBody]` for complex types, `[FromRoute]` for route data, `[FromQuery]` for query strings.
- Problem Details responses (RFC 7807) for error responses.
- Requires attribute routing (conventional routing not allowed).

**Q6: What is model binding in ASP.NET Core MVC?**

Model binding automatically maps HTTP request data (route values, query strings, form data, JSON body) to action method parameters. The framework tries each binding source in order. You can be explicit with attributes: `[FromBody]`, `[FromRoute]`, `[FromQuery]`, `[FromHeader]`, `[FromForm]`, `[FromServices]`. Custom model binders can be registered for non-standard types.

**Q7: What is model validation and how does it work?**

Model validation uses Data Annotation attributes (`[Required]`, `[Range]`, `[MaxLength]`, `[EmailAddress]`, etc.) or `IValidatableObject` for complex rules. After binding, the framework populates `ModelState`. You check `ModelState.IsValid` in MVC controllers; with `[ApiController]` this check is automatic. FluentValidation is a popular alternative that keeps validation rules separate from the model class.

```csharp
public class CreateProductDto {
    [Required]
    [MaxLength(100)]
    public string Name { get; set; }

    [Range(0.01, 10000)]
    public decimal Price { get; set; }
}
```

---

## Filters

**Q8: What are ASP.NET Core MVC filters and what are the different types?**

Filters run code at specific stages in the request processing pipeline. Types and their order of execution:
1. **Authorization filters** (`IAuthorizationFilter`): Run first, before any other filter. Short-circuit if unauthorized.
2. **Resource filters** (`IResourceFilter`): Run before model binding — useful for caching.
3. **Action filters** (`IActionFilter`): Run before and after the action method — used for logging, validation.
4. **Exception filters** (`IExceptionFilter`): Handle unhandled exceptions thrown by actions or other filters.
5. **Result filters** (`IResultFilter`): Run before and after the action result is executed.

**Q9: How do you implement a custom action filter?**

```csharp
public class LogActionFilter : IActionFilter {
    private readonly ILogger<LogActionFilter> _logger;

    public LogActionFilter(ILogger<LogActionFilter> logger) {
        _logger = logger;
    }

    public void OnActionExecuting(ActionExecutingContext context) {
        _logger.LogInformation("Executing {Action}", context.ActionDescriptor.DisplayName);
    }

    public void OnActionExecuted(ActionExecutedContext context) {
        _logger.LogInformation("Executed {Action}", context.ActionDescriptor.DisplayName);
    }
}

// Register globally
builder.Services.AddControllersWithViews(options => {
    options.Filters.Add<LogActionFilter>();
});
// Or per controller/action via attribute
```

---

## Dependency Injection

**Q10: How does ASP.NET Core's built-in DI work?**

Services are registered in `Program.cs` using `builder.Services`. The three lifetimes are:
- **Transient** (`AddTransient`): New instance for every injection — good for lightweight, stateless services.
- **Scoped** (`AddScoped`): One instance per HTTP request — most services (DbContext, repositories).
- **Singleton** (`AddSingleton`): One instance for the application lifetime — configuration, caches.

Controllers are instantiated per request, so constructor injection works naturally.

**Q11: What happens if you inject a scoped service into a singleton?**

This is called a "captive dependency" and is a bug. The singleton will hold a reference to a scoped instance that was created for one request, and reuse it for all future requests — leading to stale data and concurrency issues. ASP.NET Core detects this at development time and throws an `InvalidOperationException` when scope validation is enabled (default in development).

---

## Middleware

**Q12: What is middleware in ASP.NET Core and how does the pipeline work?**

Middleware is a series of components assembled into a pipeline. Each component can process the request, pass it to the next component, and process the response on the way back. Registered in `Program.cs` via `app.Use*()` methods. Order matters — authentication before authorization, static files before routing, etc.

```csharp
app.UseExceptionHandler("/Error");    // Early — catches errors from below
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();              // After routing
app.UseAuthorization();               // After authentication
app.MapControllers();
```

**Q13: How do you write a custom middleware?**

```csharp
public class RequestTimingMiddleware {
    private readonly RequestDelegate _next;

    public RequestTimingMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context) {
        var sw = Stopwatch.StartNew();
        await _next(context);
        sw.Stop();
        context.Response.Headers["X-Response-Time"] = $"{sw.ElapsedMilliseconds}ms";
    }
}

// Register
app.UseMiddleware<RequestTimingMiddleware>();
```

---

## Authentication & Authorization

**Q14: What is the difference between authentication and authorization in ASP.NET Core?**

Authentication establishes *who* the user is — validates credentials and creates a `ClaimsPrincipal`. Authorization determines *what* the user can do — evaluates the claims/roles against policies. Middleware order: `UseAuthentication()` must come before `UseAuthorization()`.

**Q15: What are the authorization approaches in ASP.NET Core?**

- **Role-based**: `[Authorize(Roles = "Admin")]` — simple but coarse.
- **Claims-based**: Checks for specific claims in the user's identity.
- **Policy-based**: Flexible — define requirements and handlers. `[Authorize(Policy = "MinimumAge")]`. Policies can combine multiple requirements with custom logic.
- **Resource-based**: Pass the resource to `IAuthorizationService.AuthorizeAsync()` for per-object authorization (e.g., "can this user edit this specific document?").

**Q16: How do you implement JWT authentication in ASP.NET Core?**

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });
```

---

## Views & Razor

**Q17: What is Razor and what are Tag Helpers?**

Razor is a templating syntax that mixes C# with HTML using `@` prefix. Tag Helpers are server-side components that look like HTML attributes or elements — they process on the server and render HTML. Examples: `asp-action`, `asp-controller` on `<a>` tags; `asp-for` on `<input>` tags for model binding; `<form asp-action="...">`. They're strongly typed and provide IntelliSense, unlike HTML helpers.

**Q18: What is the difference between `ViewData`, `ViewBag`, and `TempData`?**

- **ViewData**: `Dictionary<string, object>` — persists only for the current request's view.
- **ViewBag**: Dynamic wrapper over ViewData — same lifetime, just syntactic sugar.
- **TempData**: Survives one redirect (stored in session or cookie) — used for post-redirect-get pattern to show success/error messages after a redirect.

**Q19: What are Partial Views and View Components?**

Partial Views are reusable Razor template fragments rendered synchronously. View Components are more powerful — they have their own logic (like mini controllers) and can be async. Use View Components when the rendered content requires service calls or business logic (e.g., a cart summary widget, notification badge). They're invoked via `@await Component.InvokeAsync("CartSummary")`.

---

## Performance & Caching

**Q20: What caching options are available in ASP.NET Core MVC?**

- **Response Caching**: Cache entire HTTP responses via `[ResponseCache]` attribute or `app.UseResponseCaching()`.
- **Output Caching** (.NET 7+): More powerful replacement for response caching with tag-based invalidation.
- **In-memory cache** (`IMemoryCache`): Cache objects in process memory — fast but not shared across instances.
- **Distributed cache** (`IDistributedCache`): Backed by Redis, SQL Server, or Azure Cache — works in multi-server deployments.
- **Hybrid Cache** (.NET 9): Combines in-memory and distributed cache with stampede protection.

**Q21: How do you handle concurrency issues with `IMemoryCache`?**

Use `GetOrCreateAsync` with a lock or `Lazy<Task>` wrapper to prevent cache stampede (multiple threads simultaneously computing the same value on cache miss). In .NET 9, `HybridCache.GetOrCreateAsync` handles stampede protection automatically.

---

## Error Handling

**Q22: What are the options for global exception handling in ASP.NET Core MVC?**

- **Exception Handler Middleware**: `app.UseExceptionHandler("/Error")` — redirects to an error page.
- **Exception Filter**: Implement `IExceptionFilter` or extend `ExceptionFilterAttribute` — catches exceptions from MVC actions.
- **Problem Details**: Configure `builder.Services.AddProblemDetails()` for RFC 7807-compliant error responses for APIs.
- **.NET 8 IExceptionHandler**: Implement `IExceptionHandler` interface and register with `AddExceptionHandler<T>()` — cleaner than middleware for structured error handling.

---

## Minimal APIs vs MVC

**Q23: When would you choose Minimal APIs over MVC controllers?**

Minimal APIs (introduced in .NET 6) are better for microservices and simple CRUD APIs — less ceremony, faster startup, and slightly better performance. MVC controllers are better when you need filters, complex routing, views, model binding customization, or when the team is already familiar with the MVC conventions. In practice many apps use both — Minimal APIs for simple endpoints, MVC for complex features.

---

## Testing

**Q24: How do you unit test an ASP.NET Core MVC controller?**

Instantiate the controller directly, mock dependencies via interfaces using Moq or NSubstitute, call the action method, and assert on the returned `IActionResult`. No web server needed.

```csharp
[Fact]
public async Task GetProduct_ReturnsNotFound_WhenMissing() {
    var mockService = new Mock<IProductService>();
    mockService.Setup(s => s.GetByIdAsync(99)).ReturnsAsync((Product?)null);

    var controller = new ProductsController(mockService.Object);
    var result = await controller.GetProduct(99);

    Assert.IsType<NotFoundResult>(result);
}
```

**Q25: What is `WebApplicationFactory` and how is it used for integration testing?**

`WebApplicationFactory<TProgram>` spins up the full ASP.NET Core pipeline in-memory for tests — no listening port needed. You get a `HttpClient` that sends requests through the real middleware stack. Override `ConfigureWebHost` to swap out services (e.g., replace the real database with an in-memory one).

```csharp
public class ProductsApiTests : IClassFixture<WebApplicationFactory<Program>> {
    private readonly HttpClient _client;

    public ProductsApiTests(WebApplicationFactory<Program> factory) {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_ReturnsOk() {
        var response = await _client.GetAsync("/api/products");
        response.EnsureSuccessStatusCode();
    }
}
```
