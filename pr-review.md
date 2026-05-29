# 🔍 PR / Code Review Interview Questions — Complete Guide

> **40+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Code Review Fundamentals](#1-code-review-fundamentals)
2. [Security Review](#2-security-review)
3. [Performance Review](#3-performance-review)
4. [Code Quality & SOLID](#4-code-quality--solid)
5. [Exception Handling](#5-exception-handling)
6. [Test Quality Review](#6-test-quality-review)
7. [Architecture & Design Review](#7-architecture--design-review)
8. [PR Process & Culture](#8-pr-process--culture)

---

# 1. Code Review Fundamentals

> 📚 Reference: https://google.github.io/eng-practices/review/
> 📚 Best practices: https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests

---

## 1.1 What to Look For in a PR

### Q1. What do you look for when reviewing a pull request?

**Answer:**
A thorough review covers correctness (does it do what it says), security (injection, auth, secrets), performance (N+1, blocking async), maintainability (readability, size, duplication), test coverage (new paths covered, meaningful assertions), and API design consistency. Prioritize blockers over style nits.

❌ **Wrong — reviewing only for style and typos, missing correctness and security:**
```
Review comment: "Line 42: missing space after comma"
Review comment: "Variable name could be more descriptive"
Review comment: "LGTM 👍"
// Missed: endpoint had no [Authorize], SQL was string-concatenated, no tests added
```

✅ **Correct — structured review covering all layers:**
```
🔒 BLOCKER: Line 67 — raw string interpolation in SQL query. Use parameterized query.
🔒 BLOCKER: /api/admin/delete has no [Authorize] attribute — anyone can call it.
⚡ PERF: Line 102 — loading all users then filtering in memory. Add .Where() before .ToList().
🧪 TEST: No tests added for the new error path on line 89.
💡 SUGGESTION: Extract lines 45–60 into a private method for readability.
✅ Nice use of the Result pattern here — clean error handling.
```

---

## 1.2 Giving Constructive Feedback

### Q2. How do you phrase code review feedback constructively?

**Answer:**
Critique the code, not the person. Label comment severity (blocker/suggestion/nit). Explain *why* not just *what*. Ask questions when unsure of intent. Acknowledge good decisions. Avoid subjective demands without justification.

❌ **Wrong — attacking tone, no explanation, no actionable guidance:**
```
"This is wrong."
"Why would you do it this way?"
"This code is a mess."
"Just use a dictionary."
```

✅ **Correct — collaborative, explains reasoning, offers a path forward:**
```
"💡 Suggestion: This loop calls GetUserAsync() on each iteration, resulting in N+1 database 
queries. Consider fetching all users upfront and looking them up from a dictionary — 
reduces N queries to 1. Happy to share an example if helpful."

"❓ Question: I noticed this throws ArgumentException when the list is empty. Is that 
intentional? The calling code doesn't seem to handle it — could be a silent bug."
```

---

# 2. Security Review

> 📚 Reference: https://owasp.org/www-project-top-ten/
> 📚 .NET security: https://learn.microsoft.com/en-us/aspnet/core/security/

---

## 2.1 SQL Injection

### Q3. How do you identify SQL injection risk in a C# code review?

**Answer:**
Look for string interpolation or concatenation in database calls. Any user-supplied value that is embedded directly into a SQL string is a vulnerability. All queries must use parameters — either via ORM LINQ queries or parameterized raw SQL.

❌ **Wrong — user input interpolated directly into SQL:**
```csharp
public User? GetByEmail(string email) {
    var query = $"SELECT * FROM Users WHERE Email = '{email}'";
    // Attacker sends: email = "' OR '1'='1" → returns all users
    // Attacker sends: email = "'; DROP TABLE Users;--" → destroys the table
    return _connection.QueryFirstOrDefault<User>(query);
}
```

✅ **Correct — parameterized query, input never touches SQL string:**
```csharp
// Option 1: Dapper parameterized query
public User? GetByEmail(string email) =>
    _connection.QueryFirstOrDefault<User>(
        "SELECT * FROM Users WHERE Email = @email",
        new { email });

// Option 2: EF Core LINQ (always parameterized)
public async Task<User?> GetByEmailAsync(string email) =>
    await _db.Users.FirstOrDefaultAsync(u => u.Email == email);
```

---

## 2.2 Missing Authorization

### Q4. How do you spot missing authorization in a .NET code review?

**Answer:**
Check that every non-public endpoint has `[Authorize]` or an explicit `[AllowAnonymous]`. Look for authorization logic done after data retrieval (exposes existence). Check that ownership/resource-level checks are present for user-specific data.

❌ **Wrong — no [Authorize], anyone can call admin endpoints:**
```csharp
[ApiController]
[Route("api/admin")]
public class AdminController : ControllerBase {  // no [Authorize] on controller

    [HttpDelete("users/{id}")]  // no [Authorize] on action either
    public async Task<IActionResult> DeleteUser(int id) {
        await _userService.DeleteAsync(id);
        return NoContent();
    }
}
```

✅ **Correct — controller-level auth + role check + resource-level ownership:**
```csharp
[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]           // controller-level — all actions require Admin
public class AdminController : ControllerBase {

    [HttpDelete("users/{id:int}")]
    public async Task<IActionResult> DeleteUser(int id) {
        var user = await _userService.GetByIdAsync(id);
        if (user is null) return NotFound();
        await _userService.DeleteAsync(id);
        return NoContent();
    }
}
```

---

## 2.3 Hardcoded Secrets

### Q5. What are the risks of hardcoded credentials and how do you flag them in a PR?

**Answer:**
Hardcoded secrets are committed to git history permanently — even if removed later, they exist in every clone and the git log. Flag any literal API key, password, connection string, or token appearing in source code.

❌ **Wrong — secrets hardcoded in source:**
```csharp
public class EmailService {
    private const string ApiKey = "SG.aBcD1234xYzApiKey";  // SendGrid key in source
    private const string SmtpPassword = "MyP@ssword123";
}

// appsettings.json checked in:
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=prod.db.internal;Password=ProdP@ss!"
  }
}
```

✅ **Correct — secrets from environment/Key Vault, no literals in source:**
```csharp
public class EmailService {
    private readonly string _apiKey;
    public EmailService(IConfiguration config) {
        _apiKey = config["SendGrid:ApiKey"]  // from environment variable or Key Vault
            ?? throw new InvalidOperationException("SendGrid:ApiKey not configured");
    }
}

// appsettings.json (safe to commit — no secrets):
{
  "SendGrid": {
    "ApiKey": ""  // populated via env var SENDGRID__APIKEY or Azure Key Vault
  }
}
```

---

# 3. Performance Review

> 📚 Reference: https://learn.microsoft.com/en-us/ef/core/performance/
> 📚 Async: https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/async-scenarios

---

## 3.1 N+1 Query Problem

### Q6. How do you identify an N+1 query problem in a code review?

**Answer:**
Look for a loop containing a database call. Each iteration fires a separate query — N orders produce N+1 queries total. Fix with `Include()` in EF Core (eager loading) or a single batch query.

❌ **Wrong — query inside a loop, N+1 queries:**
```csharp
public async Task<List<OrderSummary>> GetOrderSummariesAsync() {
    var orders = await _db.Orders.ToListAsync();  // Query 1: loads all orders
    var summaries = new List<OrderSummary>();

    foreach (var order in orders) {
        var customer = await _db.Customers.FindAsync(order.CustomerId);  // Query per order!
        summaries.Add(new OrderSummary(order, customer!.Name));
    }
    return summaries;  // 1 + N queries total
}
```

✅ **Correct — eager load with Include(), single query:**
```csharp
public async Task<List<OrderSummary>> GetOrderSummariesAsync() {
    return await _db.Orders
        .Include(o => o.Customer)        // JOIN in single query
        .Select(o => new OrderSummary {
            OrderId = o.Id,
            CustomerName = o.Customer!.Name,
            Total = o.Total
        })
        .ToListAsync();
}
```

---

## 3.2 Async/Await Anti-Patterns

### Q7. What async/await anti-patterns do you look for in a PR?

**Answer:**
`.Result` and `.Wait()` block a thread synchronously in an async context — can cause deadlocks in ASP.NET Core. `async void` makes exceptions uncatchable. Not passing `CancellationToken` downstream wastes resources on cancelled requests.

❌ **Wrong — blocking on async code (.Result / .Wait()), async void:**
```csharp
// Blocking — can cause deadlocks, wastes thread pool thread
public IActionResult GetProducts() {
    var products = _service.GetAllAsync().Result;  // .Result blocks
    return Ok(products);
}

// async void — exceptions crash the process
public async void ProcessOrderAsync(int id) {
    await _service.ProcessAsync(id);
}

// CancellationToken ignored — request cancelled but work continues
public async Task<List<Product>> GetAsync(CancellationToken ct) {
    return await _db.Products.ToListAsync(); // ct not passed
}
```

✅ **Correct — proper async, CancellationToken propagated:**
```csharp
[HttpGet]
public async Task<IActionResult> GetProducts(CancellationToken ct) {
    var products = await _service.GetAllAsync(ct);  // await, not .Result
    return Ok(products);
}

// Background work: use IHostedService or BackgroundService, not async void
public async Task ProcessOrderAsync(int id, CancellationToken ct) {
    await _service.ProcessAsync(id, ct);  // returns Task, ct propagated
}
```

---

# 4. Code Quality & SOLID

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles
> 📚 SOLID: https://www.digitalocean.com/community/conceptual-articles/s-o-l-i-d-the-first-five-principles-of-object-oriented-design

---

## 4.1 Single Responsibility Principle

### Q8. How do you identify SRP violations in a code review?

**Answer:**
A class or method is doing too many things if it handles both business logic and I/O, or if its name requires "and" to describe what it does. Controllers should not contain business logic; services should not contain HTTP concerns.

❌ **Wrong — controller action doing business logic, validation, data access, and email sending:**
```csharp
[HttpPost]
public async Task<IActionResult> RegisterUser([FromBody] RegisterDto dto) {
    // Validation
    if (string.IsNullOrEmpty(dto.Email)) return BadRequest();

    // Business logic
    if (await _db.Users.AnyAsync(u => u.Email == dto.Email))
        return Conflict("Email already exists");

    // Data access
    var user = new User { Email = dto.Email, PasswordHash = Hash(dto.Password) };
    _db.Users.Add(user);
    await _db.SaveChangesAsync();

    // Email sending
    await _emailService.SendWelcomeEmailAsync(dto.Email);
    return Ok();
    // Controller knows too much — untestable, hard to change
}
```

✅ **Correct — controller delegates to a service; service has one job:**
```csharp
[HttpPost]
public async Task<IActionResult> RegisterUser([FromBody] RegisterDto dto) {
    var result = await _userService.RegisterAsync(dto); // controller just orchestrates
    return result.IsSuccess ? Ok() : Conflict(result.Error);
}

// UserService has SRP — handles registration logic only
public class UserService {
    public async Task<Result> RegisterAsync(RegisterDto dto) {
        if (await _repo.ExistsByEmailAsync(dto.Email))
            return Result.Fail("Email already exists");
        var user = User.Create(dto.Email, dto.Password);
        await _repo.AddAsync(user);
        await _emailService.SendWelcomeEmailAsync(dto.Email);
        return Result.Ok();
    }
}
```

---

## 4.2 Open/Closed Principle

### Q9. How do you spot an OCP violation in a code review?

**Answer:**
A giant `switch` or `if-else` chain on a type/enum that must be modified every time a new type is added violates OCP. Replace with polymorphism or a strategy/factory pattern — new types extend without modifying existing code.

❌ **Wrong — adding a new payment method requires editing existing switch:**
```csharp
public decimal CalculateFee(string paymentType, decimal amount) {
    return paymentType switch {
        "CreditCard" => amount * 0.03m,
        "PayPal"     => amount * 0.025m,
        "BankTransfer" => 0.50m,
        // Every new payment type requires editing this method
        _ => throw new NotSupportedException(paymentType)
    };
}
```

✅ **Correct — strategy pattern, new payment types added without touching existing code:**
```csharp
public interface IPaymentFeeStrategy {
    string PaymentType { get; }
    decimal Calculate(decimal amount);
}

public class CreditCardFeeStrategy : IPaymentFeeStrategy {
    public string PaymentType => "CreditCard";
    public decimal Calculate(decimal amount) => amount * 0.03m;
}

// Register all strategies via DI; new types are just new classes
public class FeeCalculator(IEnumerable<IPaymentFeeStrategy> strategies) {
    private readonly Dictionary<string, IPaymentFeeStrategy> _map =
        strategies.ToDictionary(s => s.PaymentType);

    public decimal Calculate(string paymentType, decimal amount) =>
        _map.TryGetValue(paymentType, out var strategy)
            ? strategy.Calculate(amount)
            : throw new NotSupportedException(paymentType);
}
```

---

# 5. Exception Handling

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/standard/exceptions/best-practices-for-exceptions

---

## 5.1 Swallowing Exceptions

### Q10. What is wrong with catching and swallowing exceptions?

**Answer:**
An empty or logging-only catch block hides bugs, makes debugging impossible, and leaves the application in an undefined state. Always handle exceptions meaningfully — rethrow, return a Result, or log and terminate.

❌ **Wrong — silently swallowing all exceptions:**
```csharp
public async Task<User?> GetUserAsync(int id) {
    try {
        return await _db.Users.FindAsync(id);
    }
    catch (Exception ex) {
        // Silent swallow — caller gets null with no idea why
        // Could be: DB down, network timeout, invalid query — all look the same
        return null;
    }
}
```

✅ **Correct — catch specific exceptions, let unexpected ones propagate:**
```csharp
public async Task<User?> GetUserAsync(int id) {
    try {
        return await _db.Users.FindAsync(id);
    }
    catch (OperationCanceledException) {
        throw; // request was cancelled — let it propagate naturally
    }
    catch (DbUpdateException ex) {
        _logger.LogError(ex, "Database error fetching user {UserId}", id);
        throw; // rethrow to let global handler return 500
    }
    // No catch-all — unexpected exceptions propagate and surface as bugs
}
```

---

## 5.2 Rethrowing Correctly

### Q11. What is the difference between `throw` and `throw ex` and why does it matter?

**Answer:**
`throw ex` resets the stack trace — the original call site is lost, making debugging very difficult. `throw` (bare) preserves the original stack trace. Always use bare `throw` when rethrowing.

❌ **Wrong — `throw ex` destroys the stack trace:**
```csharp
try {
    await _service.ProcessAsync(id);
}
catch (Exception ex) {
    _logger.LogError(ex, "Error in ProcessAsync");
    throw ex;  // stack trace now points to this line, not the actual error origin
}
```

✅ **Correct — bare `throw` preserves full stack trace:**
```csharp
try {
    await _service.ProcessAsync(id);
}
catch (Exception ex) {
    _logger.LogError(ex, "Error processing {Id}", id);
    throw;  // original stack trace preserved — debuggable
}
```

---

# 6. Test Quality Review

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/core/testing/
> 📚 xUnit: https://xunit.net/docs/getting-started/netcore/cmdline

---

## 6.1 Meaningful Assertions

### Q12. What makes a unit test meaningful vs superficial?

**Answer:**
A meaningful test asserts behavior — actual output, state change, or observable effect. Superficial tests only verify mocks were called without checking outcomes, giving false confidence.

❌ **Wrong — test only verifies the mock was called, not the actual outcome:**
```csharp
[Fact]
public async Task CreateOrder_CallsRepository() {
    var mockRepo = new Mock<IOrderRepository>();
    var service = new OrderService(mockRepo.Object);

    await service.CreateAsync(new CreateOrderDto { ProductId = 1, Qty = 2 });

    // Only verifies the method was called — not what was saved, not the result
    mockRepo.Verify(r => r.AddAsync(It.IsAny<Order>()), Times.Once);
}
```

✅ **Correct — asserts the actual saved entity and returned result:**
```csharp
[Fact]
public async Task CreateOrder_SavesCorrectOrderAndReturnsId() {
    Order? savedOrder = null;
    var mockRepo = new Mock<IOrderRepository>();
    mockRepo.Setup(r => r.AddAsync(It.IsAny<Order>()))
        .Callback<Order>(o => savedOrder = o)
        .ReturnsAsync(42);

    var service = new OrderService(mockRepo.Object);
    var result = await service.CreateAsync(new CreateOrderDto { ProductId = 1, Qty = 2 });

    Assert.Equal(42, result.Id);
    Assert.NotNull(savedOrder);
    Assert.Equal(1, savedOrder!.ProductId);
    Assert.Equal(2, savedOrder.Quantity);
}
```

---

# 7. Architecture & Design Review

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/
> 📚 Clean architecture: https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures

---

## 7.1 Business Logic in Controllers

### Q13. What do you say when a PR has 200 lines of business logic in a controller action?

**Answer:**
The action violates SRP, is untestable (you can't unit test a controller that does everything), and makes the code hard to reuse. Comment non-blockingly if the PR is otherwise correct, file a follow-up tech debt ticket, and suggest the specific refactor.

❌ **Wrong — 200-line controller action mixing data access, calculations, and emails:**
```csharp
[HttpPost("checkout")]
public async Task<IActionResult> Checkout([FromBody] CheckoutDto dto) {
    // 50 lines of discount calculation logic
    // 40 lines of inventory checking with direct DbContext calls
    // 30 lines of payment processing
    // 30 lines of email template building and sending
    // 50 lines of order confirmation logic
    // Untestable, not reusable, impossible to maintain
}
```

✅ **Correct — controller delegates to a focused service:**
```csharp
[HttpPost("checkout")]
public async Task<ActionResult<OrderConfirmationDto>> Checkout(
    [FromBody] CheckoutDto dto, CancellationToken ct) {

    var result = await _checkoutService.ProcessAsync(dto, ct);
    return result.IsSuccess
        ? Ok(result.Value)
        : BadRequest(result.Error);
}
// CheckoutService can be unit-tested in isolation with mocked dependencies
```

---

# 8. PR Process & Culture

> 📚 Reference: https://google.github.io/eng-practices/review/reviewer/
> 📚 Azure DevOps PR: https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests

---

## 8.1 PR Description Quality

### Q14. What should a good PR description contain?

**Answer:**
A PR description should explain *what* changed and *why* (not just what files — git diff shows that), link to the issue/ticket, describe how to test it, note risks and deployment considerations (migrations, feature flags, config changes), and include screenshots for UI changes.

❌ **Wrong — PR description provides no context:**
```
Title: "Fix bug"
Description: "Fixed it."
```

✅ **Correct — PR description gives full context:**
```
## Summary
Fixes the N+1 query causing 3-second response times on /api/orders endpoint (Issue #432).
Replaced lazy-loaded customer fetching with a single JOIN query using EF Core Include().

## Changes
- OrderRepository: added .Include(o => o.Customer) to GetOrdersAsync
- Added integration test covering the join scenario

## How to Test
1. Call GET /api/orders with 50+ orders
2. Check response time < 200ms (was ~3s before)
3. Verify customer names appear in response

## Deployment Notes
No migrations required. No feature flag needed.

## Before / After
Before: ~3200ms average | After: ~180ms average
```

---

## 8.2 Handling Review Disagreements

### Q15. How do you handle a disagreement in a code review without blocking the PR?

**Answer:**
Distinguish opinion from standard. If a team standard exists, reference it. If not, avoid blocking on preferences — suggest creating the standard separately. Use "disagree and commit" to unblock the team, then follow up. Reserve blockers for genuine correctness, security, or agreed-upon violations.

❌ **Wrong — blocking PR merge over a stylistic preference with no team standard:**
```
BLOCKER: This should use a for loop instead of LINQ. I personally find LINQ harder to read.
[PR sits unmerged for 3 days over personal preference]
```

✅ **Correct — non-blocking comment, separates preference from blocker:**
```
💡 Nit (non-blocking): I find for loops more readable than LINQ chains for this case — 
personal preference and either is fine. If the team wants to standardize on one style, 
happy to start a discussion in the engineering channel.

LGTM otherwise — approving.
```
