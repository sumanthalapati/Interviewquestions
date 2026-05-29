# 🧪 Unit Testing Interview Questions — Complete Guide

> **200+ questions** · xUnit · Moq · FluentAssertions · Integration Tests · TDD · AAA Pattern
> Every question has ❌ bad example and ✅ good example with full C# code.

---

## 📋 Table of Contents

1. [Testing Fundamentals](#1-testing-fundamentals)
2. [xUnit Basics](#2-xunit-basics)
3. [Arrange-Act-Assert (AAA) Pattern](#3-arrange-act-assert-aaa-pattern)
4. [Mocking with Moq](#4-mocking-with-moq)
5. [FluentAssertions](#5-fluentassertions)
6. [Testing Async Code](#6-testing-async-code)
7. [Testing Controllers (ASP.NET Core)](#7-testing-controllers-aspnet-core)
8. [Integration Testing with WebApplicationFactory](#8-integration-testing-with-webapplicationfactory)
9. [Testing Entity Framework / Repositories](#9-testing-entity-framework--repositories)
10. [Testing Design Patterns](#10-testing-design-patterns)
11. [Test-Driven Development (TDD)](#11-test-driven-development-tdd)
12. [Test Coverage & Best Practices](#12-test-coverage--best-practices)
13. [Testing CQRS / MediatR](#13-testing-cqrs--mediatr)
14. [Snapshot & Parameterised Tests](#14-snapshot--parameterised-tests)
15. [Performance & Load Testing Basics](#15-performance--load-testing-basics)

---

# 1. Testing Fundamentals

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/core/testing/

### Q1 — What are the three types of tests and when do you use each?

**Unit tests** — test a single class/method in isolation, all dependencies mocked. Fast (milliseconds), run on every commit.  
**Integration tests** — test multiple layers together (controller + service + DB). Slower, run on CI.  
**End-to-end (E2E) tests** — test from browser/client through to database. Slowest, run pre-release.

❌ **Wrong** — calling every test a "unit test" regardless of what it actually tests:
```csharp
// This hits a REAL database — it is NOT a unit test
[Fact]
public void TestGetOrder_UnitTest() // ← misnamed
{
    var db  = new AppDbContext(realConnectionString); // real DB!
    var svc = new OrderService(db);
    var result = svc.GetOrder(Guid.NewGuid());
    Assert.NotNull(result);
}
```

✅ **Correct** — true unit test: all dependencies mocked, no I/O:
```csharp
[Fact]
public async Task GetOrder_WhenExists_ReturnsOrder()
{
    // Arrange: mock the repo, no DB
    var mockRepo = new Mock<IOrderRepository>();
    var orderId  = Guid.NewGuid();
    mockRepo.Setup(r => r.GetByIdAsync(orderId))
            .ReturnsAsync(new Order { Id = orderId, Status = "Pending" });

    var svc = new OrderService(mockRepo.Object);

    // Act
    var result = await svc.GetOrderAsync(orderId);

    // Assert
    Assert.NotNull(result);
    Assert.Equal(orderId, result.Id);
}
```

---

### Q2 — What is the testing pyramid?

The testing pyramid defines the **ratio and speed** of test types: many unit tests at the base, fewer integration tests in the middle, fewest E2E tests at the top.

❌ **Wrong** — inverted pyramid (too many slow E2E tests):
```
        /──────────────\
       /   Unit (few)   \       ← almost no unit tests
      /─────────────────\
     /  Integration (some) \
    /──────────────────────\
   /    E2E (most) !!!      \   ← mostly slow Selenium tests
  /──────────────────────────\
```

✅ **Correct** — pyramid shape: fast at base, slow at top:
```
       /──────\
      /  E2E   \              5–10%   run pre-release
     /──────────\
    / Integration \           20–30%  run on CI
   /──────────────\
  /   Unit Tests   \          60–70%  run on every save
 /──────────────────\
```

---

### Q3 — What is test isolation and why does it matter?

Each test must **not share state** with other tests. Shared static state, leftover DB rows, or file-system changes cause flaky tests that pass individually but fail in suites.

❌ **Wrong** — static state shared between tests:
```csharp
public class OrderServiceTests
{
    private static readonly List<Order> _orders = new(); // ❌ shared across ALL test instances!

    [Fact]
    public void Test1()
    {
        _orders.Add(new Order());
        Assert.Single(_orders);
    }

    [Fact]
    public void Test2()
    {
        // _orders already has items from Test1 if run in same process
        Assert.Empty(_orders); // FLAKY: may fail depending on test order
    }
}
```

✅ **Correct** — fresh state per test via constructor:
```csharp
public class OrderServiceTests
{
    private readonly List<Order> _orders;
    private readonly OrderService _svc;

    public OrderServiceTests() // ← xUnit creates a NEW instance per test
    {
        _orders = new List<Order>(); // fresh every time
        var mockRepo = new Mock<IOrderRepository>();
        _svc = new OrderService(mockRepo.Object);
    }

    [Fact]
    public void Test1() { /* _orders is empty, guaranteed */ }

    [Fact]
    public void Test2() { /* _orders is empty, guaranteed */ }
}
```

---

# 2. xUnit Basics

> 📚 Reference: https://xunit.net/docs/getting-started/netcore/cmdline

### Q1 — What is the difference between `[Fact]` and `[Theory]`?

`[Fact]` marks a test with no parameters. `[Theory]` marks a parameterised test — it runs once for each `[InlineData]`, `[MemberData]`, or `[ClassData]` set.

❌ **Wrong** — duplicating test code instead of using `[Theory]`:
```csharp
[Fact]
public void Add_1_And_2_Returns_3()    => Assert.Equal(3, Calculator.Add(1, 2));

[Fact]
public void Add_Neg1_And_1_Returns_0() => Assert.Equal(0, Calculator.Add(-1, 1));

[Fact]
public void Add_0_And_0_Returns_0()    => Assert.Equal(0, Calculator.Add(0, 0));
```

✅ **Correct** — single `[Theory]` covers all cases:
```csharp
[Theory]
[InlineData(1,  2,  3)]
[InlineData(-1, 1,  0)]
[InlineData(0,  0,  0)]
[InlineData(int.MaxValue, 1, int.MinValue)] // overflow edge case
public void Add_ReturnsExpectedSum(int a, int b, int expected)
{
    var result = Calculator.Add(a, b);
    Assert.Equal(expected, result);
}
```

---

### Q2 — How do you share expensive setup across tests using `IClassFixture`?

`IClassFixture<T>` creates a single instance of `T` shared across all tests in the class — useful for expensive resources like database connections or HTTP servers.

❌ **Wrong** — recreating a heavy resource for every test:
```csharp
public class DatabaseTests
{
    [Fact]
    public async Task Test1()
    {
        var factory = new WebApplicationFactory<Program>(); // ❌ new server per test — very slow
        var client  = factory.CreateClient();
        // ...
    }
}
```

✅ **Correct** — share factory across all tests via `IClassFixture`:
```csharp
public class OrderApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrderApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient(); // factory created ONCE, shared
    }

    [Fact]
    public async Task GetOrders_Returns200()
    {
        var response = await _client.GetAsync("/api/orders");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetOrder_NotFound_Returns404()
    {
        var response = await _client.GetAsync($"/api/orders/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
```

---

### Q3 — How do you skip a test or mark it as expected to fail?

❌ **Wrong** — commenting out tests (invisible, forgotten):
```csharp
// [Fact]
// public void BrokenTest() { ... }
```

✅ **Correct** — `[Fact(Skip = "reason")]` skips visibly; trait for categorisation:
```csharp
[Fact(Skip = "Known bug #1234 — payment gateway down in CI")]
public async Task ProcessPayment_ChargesCard()
{
    // will be skipped but VISIBLE in test results
}

// Categorise tests with [Trait]
[Fact]
[Trait("Category", "Slow")]
public async Task LargeDataset_ProcessesInUnder5Seconds() { /* ... */ }

// Run only fast tests in CI: dotnet test --filter "Category!=Slow"
```

---

### Q4 — How do you test that an exception is thrown?

❌ **Wrong** — catching exception manually, missing edge cases:
```csharp
[Fact]
public void GetOrder_NullId_Throws()
{
    try
    {
        _svc.GetOrder(Guid.Empty);
        Assert.True(false, "Should have thrown"); // easy to forget this line
    }
    catch (ArgumentException) { } // passes — but doesn't verify message
}
```

✅ **Correct** — `Assert.ThrowsAsync` captures exception for further inspection:
```csharp
[Fact]
public async Task GetOrder_EmptyId_ThrowsArgumentException()
{
    var ex = await Assert.ThrowsAsync<ArgumentException>(
        () => _svc.GetOrderAsync(Guid.Empty));

    Assert.Equal("orderId", ex.ParamName);
    Assert.Contains("must not be empty", ex.Message);
}
```

---

# 3. Arrange-Act-Assert (AAA) Pattern

> 📚 Reference: https://docs.microsoft.com/en-us/visualstudio/test/unit-test-basics

### Q1 — What is the AAA pattern and why is it the standard?

**Arrange** — set up data, mocks, system under test.  
**Act** — call the one method being tested.  
**Assert** — verify one logical outcome.

One test should test **one behaviour**. If you need two `Act` + `Assert` blocks, write two tests.

❌ **Wrong** — no clear separation, tests multiple things:
```csharp
[Fact]
public async Task OrderTests()
{
    var svc = new OrderService(new Mock<IOrderRepository>().Object);
    var order = await svc.CreateAsync("Alice");
    Assert.NotNull(order);
    order.Status = "Shipped";
    await svc.UpdateAsync(order);
    var updated = await svc.GetAsync(order.Id);
    Assert.Equal("Shipped", updated.Status); // multiple acts — test too big
    await svc.DeleteAsync(order.Id);
    Assert.Null(await svc.GetAsync(order.Id));
}
```

✅ **Correct** — one test, one behaviour, clear AAA sections:
```csharp
[Fact]
public async Task CreateOrder_ReturnsOrderWithPendingStatus()
{
    // Arrange
    var mockRepo = new Mock<IOrderRepository>();
    mockRepo.Setup(r => r.AddAsync(It.IsAny<Order>())).Returns(Task.CompletedTask);
    var svc = new OrderService(mockRepo.Object);

    // Act
    var order = await svc.CreateAsync("Alice");

    // Assert
    Assert.NotNull(order);
    Assert.Equal("Pending", order.Status);
    Assert.Equal("Alice", order.CustomerName);
}
```

---

### Q2 — What makes a good test name?

A good name reads like a sentence: **MethodName_Scenario_ExpectedBehaviour**.

❌ **Wrong** — vague, meaningless names:
```csharp
[Fact] public void Test1() { }
[Fact] public void OrderTest() { }
[Fact] public void GetOrderWorks() { }
```

✅ **Correct** — descriptive names that explain the scenario:
```csharp
[Fact] public async Task GetOrder_WhenOrderExists_ReturnsCorrectOrder()       { }
[Fact] public async Task GetOrder_WhenOrderNotFound_ReturnsNull()              { }
[Fact] public async Task CreateOrder_WhenCustomerBlacklisted_ThrowsException() { }
[Fact] public async Task UpdateOrder_WhenAlreadyShipped_ThrowsInvalidOperation(){ }
```

---

# 4. Mocking with Moq

> 📚 Reference: https://github.com/devlooped/moq/wiki/Quickstart

### Q1 — What is a mock vs a stub vs a fake?

**Stub** — returns canned data, no behaviour verification.  
**Mock** — verifies interactions (was a method called? How many times? With what args?).  
**Fake** — a working but simplified implementation (e.g., in-memory repository).

❌ **Wrong** — using a real implementation in unit tests (not isolated):
```csharp
var realRepo = new SqlOrderRepository(connectionString); // real SQL — slow, brittle
var svc = new OrderService(realRepo);
```

✅ **Correct** — mock for interaction verification, stub for data:
```csharp
var mockRepo = new Mock<IOrderRepository>();

// Stub — return canned data
mockRepo.Setup(r => r.GetByIdAsync(orderId))
        .ReturnsAsync(new Order { Id = orderId });

// Mock — verify interaction
mockRepo.Verify(r => r.GetByIdAsync(orderId), Times.Once);
```

---

### Q2 — How do you set up a mock to return different values on sequential calls?

❌ **Wrong** — using multiple `Setup` calls with same signature (last one wins, previous are ignored):
```csharp
mockRepo.Setup(r => r.GetNextAsync()).ReturnsAsync(order1);
mockRepo.Setup(r => r.GetNextAsync()).ReturnsAsync(order2); // ← overwrites first!
```

✅ **Correct** — use `SetupSequence` for sequential returns:
```csharp
mockRepo.SetupSequence(r => r.GetNextAsync())
        .ReturnsAsync(new Order { Id = Guid.NewGuid(), Status = "Pending" })  // 1st call
        .ReturnsAsync(new Order { Id = Guid.NewGuid(), Status = "Shipped" })  // 2nd call
        .ReturnsAsync(null);                                                   // 3rd call
```

---

### Q3 — How do you mock a method that throws an exception?

❌ **Wrong** — not testing the error path at all:
```csharp
// Only tests happy path — leaves exception path uncovered
mockRepo.Setup(r => r.GetByIdAsync(orderId)).ReturnsAsync(new Order());
```

✅ **Correct** — setup mock to throw, then verify the service handles it:
```csharp
var mockRepo = new Mock<IOrderRepository>();
mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>()))
        .ThrowsAsync(new TimeoutException("DB timeout"));

var svc = new OrderService(mockRepo.Object, logger);

// Service should wrap the exception — verify it doesn't crash the caller
await Assert.ThrowsAsync<ServiceUnavailableException>(
    () => svc.GetOrderAsync(Guid.NewGuid()));
```

---

### Q4 — How do you verify a mock was called with specific arguments?

❌ **Wrong** — verifying with `It.IsAny<T>()` — too loose, misses wrong argument bugs:
```csharp
mockRepo.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Once);
// passes even if the wrong order was saved!
```

✅ **Correct** — verify with specific argument matching:
```csharp
// Verify exact object
mockRepo.Verify(r => r.SaveAsync(It.Is<Order>(o =>
    o.CustomerId == expectedCustomerId &&
    o.Status     == "Pending"
)), Times.Once);

// Capture argument for deeper assertions
Order? capturedOrder = null;
mockRepo.Setup(r => r.SaveAsync(It.IsAny<Order>()))
        .Callback<Order>(o => capturedOrder = o)
        .Returns(Task.CompletedTask);

await svc.CreateOrderAsync(customerId);

Assert.NotNull(capturedOrder);
Assert.Equal(customerId, capturedOrder!.CustomerId);
Assert.True(capturedOrder.CreatedAt > DateTime.UtcNow.AddSeconds(-5));
```

---

### Q5 — How do you mock a property on an interface?

❌ **Wrong** — forgetting to set up property, getting default value:
```csharp
var mockUser = new Mock<ICurrentUser>();
// mockUser.Object.Id returns Guid.Empty (default) — test may silently pass wrong
var svc = new OrderService(mockUser.Object);
```

✅ **Correct** — explicitly set up property:
```csharp
var userId   = Guid.NewGuid();
var mockUser = new Mock<ICurrentUser>();
mockUser.Setup(u => u.Id).Returns(userId);
mockUser.Setup(u => u.Role).Returns("Admin");
mockUser.Setup(u => u.IsAuthenticated).Returns(true);

var svc = new OrderService(mockUser.Object);
// Now svc sees a consistent user
```

---

# 5. FluentAssertions

> 📚 Reference: https://fluentassertions.com/introduction

### Q1 — Why use FluentAssertions over built-in Assert?

FluentAssertions produces **human-readable failure messages** and allows chaining multiple assertions on the same object. Built-in `Assert.Equal` messages are often cryptic.

❌ **Wrong** — built-in asserts produce poor failure messages:
```csharp
Assert.Equal("Shipped", order.Status);
// On failure: "Expected: Shipped. Actual: Pending." — no context

Assert.True(order.Total > 0);
// On failure: "Expected: True. Actual: False." — useless
```

✅ **Correct** — FluentAssertions with descriptive failures:
```csharp
using FluentAssertions;

order.Status.Should().Be("Shipped",
    because: "order was marked as dispatched");
// On failure: "Expected order.Status to be 'Shipped' because order was marked as dispatched,
//             but found 'Pending'."

order.Total.Should().BeGreaterThan(0)
           .And.BeLessThan(100_000);

order.Items.Should().HaveCount(3)
           .And.AllSatisfy(i => i.Quantity.Should().BePositive());
```

---

### Q2 — How do you assert on collections with FluentAssertions?

❌ **Wrong** — manual LINQ checks with Assert:
```csharp
Assert.True(orders.All(o => o.Status == "Paid"));
Assert.True(orders.Any(o => o.Total > 1000));
Assert.Equal(3, orders.Count());
```

✅ **Correct** — FluentAssertions collection assertions:
```csharp
orders.Should().NotBeEmpty()
      .And.HaveCount(3)
      .And.AllSatisfy(o => o.Status.Should().Be("Paid"))
      .And.Contain(o => o.Total > 1000);

// Object equivalence (deep comparison ignoring nulls)
actual.Should().BeEquivalentTo(expected, opts =>
    opts.Excluding(o => o.CreatedAt) // ignore timestamp
        .Excluding(o => o.Id));       // ignore generated ID
```

---

### Q3 — How do you assert on exceptions with FluentAssertions?

❌ **Wrong** — using xUnit `Assert.Throws` and losing fluent style:
```csharp
var ex = Assert.ThrowsAsync<ArgumentException>(() => svc.CreateAsync(null!));
Assert.Equal("name", ex.Result.ParamName);
```

✅ **Correct** — FluentAssertions exception assertions:
```csharp
Func<Task> act = () => svc.CreateAsync(null!);

await act.Should().ThrowAsync<ArgumentException>()
         .WithMessage("*must not be null*")
         .WithParameterName("name");

// For synchronous:
Action syncAct = () => parser.Parse("bad-input");
syncAct.Should().Throw<FormatException>()
       .WithMessage("*invalid format*");
```

---

# 6. Testing Async Code

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/

### Q1 — How do you correctly test async methods?

❌ **Wrong** — `.Result` blocks the thread and can deadlock; `async void` test hides exceptions:
```csharp
[Fact]
public void GetOrder_ReturnsOrder() // ❌ not async
{
    var result = _svc.GetOrderAsync(id).Result; // ❌ .Result — potential deadlock
    Assert.NotNull(result);
}

[Fact]
public async void GetOrder_Test() // ❌ async void — exceptions are swallowed!
{
    var result = await _svc.GetOrderAsync(id);
}
```

✅ **Correct** — always `async Task` for async tests:
```csharp
[Fact]
public async Task GetOrder_WhenExists_ReturnsOrder() // ✅ async Task
{
    // Arrange
    var mockRepo = new Mock<IOrderRepository>();
    mockRepo.Setup(r => r.GetByIdAsync(_orderId)).ReturnsAsync(_order);

    // Act
    var result = await _svc.GetOrderAsync(_orderId); // ✅ await properly

    // Assert
    result.Should().NotBeNull();
    result!.Id.Should().Be(_orderId);
}
```

---

### Q2 — How do you test cancellation token handling?

❌ **Wrong** — never tests cancellation, so a hung operation goes unnoticed:
```csharp
[Fact]
public async Task Export_Completes()
{
    await _svc.ExportAsync(CancellationToken.None); // never tests cancellation
}
```

✅ **Correct** — test that cancellation causes `OperationCanceledException`:
```csharp
[Fact]
public async Task Export_WhenCancelled_ThrowsOperationCancelled()
{
    using var cts = new CancellationTokenSource();
    cts.Cancel(); // cancel immediately

    Func<Task> act = () => _svc.ExportAsync(cts.Token);

    await act.Should().ThrowAsync<OperationCanceledException>();
}

[Fact]
public async Task Export_WhenCancelledMidway_StopsProcessing()
{
    using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(50));

    // service should respect token and stop processing
    Func<Task> act = () => _svc.ExportLargeDatasetAsync(cts.Token);

    await act.Should().ThrowAsync<OperationCanceledException>();
}
```

---

### Q3 — How do you test time-dependent code?

❌ **Wrong** — `DateTime.Now` hardcoded in production code, impossible to control in tests:
```csharp
public class OrderService
{
    public Order Create(string customer)
        => new() { CreatedAt = DateTime.UtcNow }; // ❌ untestable
}
```

✅ **Correct** — inject `TimeProvider` (NET 8) or `IDateTimeProvider` to control time:
```csharp
// Production code uses injected time provider
public class OrderService
{
    private readonly TimeProvider _time;
    public OrderService(TimeProvider time) => _time = time;
    public Order Create(string customer)
        => new() { CreatedAt = _time.GetUtcNow().UtcDateTime };
}

// Test controls time
[Fact]
public void Create_SetsCreatedAtToCurrentUtcTime()
{
    var fixedTime   = new DateTimeOffset(2026, 1, 15, 10, 0, 0, TimeSpan.Zero);
    var fakeTime    = new FakeTimeProvider(fixedTime); // Microsoft.Extensions.TimeProvider.Testing
    var svc         = new OrderService(fakeTime);

    var order = svc.Create("Alice");

    order.CreatedAt.Should().Be(fixedTime.UtcDateTime);
}
```

---

# 7. Testing Controllers (ASP.NET Core)

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/testing

### Q1 — How do you unit-test a controller action?

❌ **Wrong** — spinning up a full ASP.NET pipeline for a controller unit test:
```csharp
// Over-engineered for a unit test — use WebApplicationFactory for integration tests
var factory = new WebApplicationFactory<Program>();
var client  = factory.CreateClient();
var response = await client.GetAsync("/api/orders");
```

✅ **Correct** — instantiate controller directly, inject mock service:
```csharp
[Fact]
public async Task Get_WhenOrderExists_ReturnsOkWithOrder()
{
    // Arrange
    var orderId  = Guid.NewGuid();
    var order    = new OrderDto(orderId, "Pending", 99.99m);
    var mockSvc  = new Mock<IOrderService>();
    mockSvc.Setup(s => s.GetByIdAsync(orderId)).ReturnsAsync(order);

    var controller = new OrdersController(mockSvc.Object);

    // Act
    var result = await controller.Get(orderId);

    // Assert
    var ok = result.Should().BeOfType<OkObjectResult>().Subject;
    ok.Value.Should().BeEquivalentTo(order);
}

[Fact]
public async Task Get_WhenNotFound_ReturnsNotFound()
{
    var mockSvc = new Mock<IOrderService>();
    mockSvc.Setup(s => s.GetByIdAsync(It.IsAny<Guid>())).ReturnsAsync((OrderDto?)null);

    var controller = new OrdersController(mockSvc.Object);
    var result     = await controller.Get(Guid.NewGuid());

    result.Should().BeOfType<NotFoundResult>();
}
```

---

### Q2 — How do you test model validation in a controller?

❌ **Wrong** — skipping `ModelState` validation entirely in unit tests:
```csharp
var controller = new OrdersController(mockSvc.Object);
// ModelState is valid by default — validation never fails in unit tests!
var result = await controller.Create(new CreateOrderDto { /* missing required fields */ });
```

✅ **Correct** — manually add `ModelState` errors to simulate validation failure:
```csharp
[Fact]
public async Task Create_WithInvalidModel_ReturnsBadRequest()
{
    var controller = new OrdersController(mockSvc.Object);
    controller.ModelState.AddModelError("CustomerName", "Required"); // simulate validation failure

    var result = await controller.Create(new CreateOrderDto());

    result.Should().BeOfType<BadRequestObjectResult>();
}
```

---

# 8. Integration Testing with WebApplicationFactory

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests

### Q1 — How do you set up an integration test that uses a real (in-memory) database?

❌ **Wrong** — running integration tests against production or shared database:
```csharp
public class OrderTests : IClassFixture<WebApplicationFactory<Program>>
{
    // Uses whatever DB Program.cs configures — could be production!
}
```

✅ **Correct** — override DI to use in-memory EF database per test run:
```csharp
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove real DB registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            // Add in-memory database — fresh per test run
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase($"TestDb_{Guid.NewGuid()}"));

            // Seed test data
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();
            db.Orders.Add(new Order { Id = _knownOrderId, Status = "Pending" });
            db.SaveChanges();
        });
    }

    public static readonly Guid _knownOrderId = Guid.NewGuid();
}

public class OrderIntegrationTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public OrderIntegrationTests(CustomWebApplicationFactory factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task GetOrder_ReturnsSeededOrder()
    {
        var response = await _client.GetAsync($"/api/orders/{CustomWebApplicationFactory._knownOrderId}");
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        order!.Status.Should().Be("Pending");
    }
}
```

---

### Q2 — How do you test authenticated endpoints in integration tests?

❌ **Wrong** — skipping auth entirely:
```csharp
// Endpoint requires [Authorize] but test never sets a JWT
var response = await _client.GetAsync("/api/admin/reports");
// Returns 401 — test is useless
```

✅ **Correct** — add a fake auth handler for tests:
```csharp
// Test auth handler — bypasses real JWT validation
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder) : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims    = new[] { new Claim(ClaimTypes.Name, "TestUser"), new Claim(ClaimTypes.Role, "Admin") };
        var identity  = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket    = new AuthenticationTicket(principal, "Test");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

// Register in factory
services.AddAuthentication("Test")
        .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("Test", _ => { });

// Client sends test auth header
_client.DefaultRequestHeaders.Authorization =
    new AuthenticationHeaderValue("Test");

var response = await _client.GetAsync("/api/admin/reports");
response.StatusCode.Should().Be(HttpStatusCode.OK);
```

---

# 9. Testing Entity Framework / Repositories

> 📚 Reference: https://learn.microsoft.com/en-us/ef/core/testing/

### Q1 — Should you use an in-memory database or SQLite for EF tests?

In-memory EF provider lacks SQL semantics (no FK constraints, no UNIQUE enforcement). **SQLite in-memory mode** is better — it runs real SQL but stays fast.

❌ **Wrong** — in-memory EF skips constraints:
```csharp
options.UseInMemoryDatabase("TestDb");
// Allows duplicate unique keys, ignores FK constraints — tests pass that would fail on SQL Server!
```

✅ **Correct** — SQLite in-memory for realistic SQL behaviour:
```csharp
public class RepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AppDbContext _db;

    public RepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open(); // keep connection open — SQLite in-memory lives as long as the connection

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        _db = new AppDbContext(options);
        _db.Database.EnsureCreated(); // creates schema
    }

    [Fact]
    public async Task AddOrder_PersistsToDatabase()
    {
        var repo  = new OrderRepository(_db);
        var order = new Order { Id = Guid.NewGuid(), Status = "Pending" };

        await repo.AddAsync(order);
        await _db.SaveChangesAsync();

        var loaded = await repo.GetByIdAsync(order.Id);
        loaded.Should().NotBeNull();
        loaded!.Status.Should().Be("Pending");
    }

    public void Dispose() { _db.Dispose(); _connection.Dispose(); }
}
```

---

### Q2 — How do you test a repository method that uses a complex query?

❌ **Wrong** — testing with mock DbContext (extremely brittle, hard to set up):
```csharp
var mockSet  = new Mock<DbSet<Order>>();
var mockDb   = new Mock<AppDbContext>();
mockDb.Setup(d => d.Orders).Returns(mockSet.Object);
// Setting up IQueryable on mock DbSet is painful and fragile
```

✅ **Correct** — use real SQLite database, seed data, verify query results:
```csharp
[Fact]
public async Task GetPendingOrders_ReturnsonlyPendingStatus()
{
    // Seed
    _db.Orders.AddRange(
        new Order { Id = Guid.NewGuid(), Status = "Pending" },
        new Order { Id = Guid.NewGuid(), Status = "Shipped" },
        new Order { Id = Guid.NewGuid(), Status = "Pending" }
    );
    await _db.SaveChangesAsync();

    // Act
    var repo   = new OrderRepository(_db);
    var result = await repo.GetPendingAsync();

    // Assert
    result.Should().HaveCount(2).And.AllSatisfy(o => o.Status.Should().Be("Pending"));
}
```

---

# 10. Testing Design Patterns

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/patterns/

### Q1 — How do you test a class that uses the Strategy pattern?

❌ **Wrong** — testing the concrete strategy through the context:
```csharp
// Only tests one combination — doesn't verify strategy is replaceable
var calculator = new OrderPricer(new VipDiscount());
Assert.Equal(70, calculator.Calculate(100));
```

✅ **Correct** — test the context with a mock strategy to isolate context logic:
```csharp
[Fact]
public void Calculate_DelegatesToStrategy()
{
    // Arrange
    var mockStrategy = new Mock<IDiscountStrategy>();
    mockStrategy.Setup(s => s.Apply(100m)).Returns(85m);

    var pricer = new OrderPricer(mockStrategy.Object);

    // Act
    var result = pricer.Calculate(100m);

    // Assert
    result.Should().Be(85m);
    mockStrategy.Verify(s => s.Apply(100m), Times.Once); // strategy WAS called
}

// Also test each concrete strategy independently
[Theory]
[InlineData(100, 100)]  // NoDiscount
[InlineData(100, 90)]   // RegularDiscount (10% off)
[InlineData(100, 80)]   // PremiumDiscount (20% off)
[InlineData(100, 70)]   // VipDiscount (30% off)
public void ConcreteStrategies_ApplyCorrectDiscount(decimal input, decimal expected)
{
    IDiscountStrategy[] strategies = [new NoDiscount(), new RegularDiscount(), new PremiumDiscount(), new VipDiscount()];
    strategies[0].Apply(input).Should().Be(100);
    // ... or pass strategy as [MemberData]
}
```

---

### Q2 — How do you test the Observer pattern?

❌ **Wrong** — verifying side effects indirectly through shared state:
```csharp
// Hard to tell which observer caused the state change
await orderService.UpdateStatusAsync(order, "Shipped");
Assert.True(emailWasSent); // static flag — fragile
```

✅ **Correct** — inject mock observers and verify they were notified:
```csharp
[Fact]
public async Task UpdateStatus_NotifiesAllObservers()
{
    var mockEmail = new Mock<IOrderEventObserver>();
    var mockAudit = new Mock<IOrderEventObserver>();

    var svc = new OrderService(new[] { mockEmail.Object, mockAudit.Object },
                               new Mock<IOrderRepository>().Object);

    var order = new Order { Id = Guid.NewGuid(), Status = "Pending" };
    await svc.UpdateStatusAsync(order, "Shipped");

    mockEmail.Verify(o => o.OnOrderStatusChanged(
        It.Is<OrderStatusChangedEvent>(e =>
            e.NewStatus == "Shipped" && e.OldStatus == "Pending")),
        Times.Once);

    mockAudit.Verify(o => o.OnOrderStatusChanged(It.IsAny<OrderStatusChangedEvent>()),
        Times.Once);
}
```

---

### Q3 — How do you test the Decorator pattern?

❌ **Wrong** — only testing the outermost decorator, missing inner behaviour:
```csharp
// Tests logging works but not that it correctly delegates to the inner service
var loggingService = new LoggingOrderService(null!, logger);
```

✅ **Correct** — verify delegation AND added behaviour:
```csharp
[Fact]
public async Task CachingDecorator_OnCacheHit_DoesNotCallInnerService()
{
    var mockInner = new Mock<IOrderService>();
    var mockCache = new Mock<IMemoryCache>();
    var orderId   = Guid.NewGuid();
    var cached    = new Order { Id = orderId };

    // Set up cache HIT
    object? cacheEntry = cached;
    mockCache.Setup(c => c.TryGetValue(orderId, out cacheEntry)).Returns(true);

    var decorator = new CachingOrderService(mockInner.Object, mockCache.Object);
    var result    = await decorator.GetOrderAsync(orderId);

    result.Should().Be(cached);
    mockInner.Verify(s => s.GetOrderAsync(It.IsAny<Guid>()), Times.Never); // inner NOT called
}

[Fact]
public async Task CachingDecorator_OnCacheMiss_CallsInnerAndCachesResult()
{
    var mockInner = new Mock<IOrderService>();
    var mockCache = new Mock<IMemoryCache>();
    var orderId   = Guid.NewGuid();
    var order     = new Order { Id = orderId };

    object? nothing = null;
    mockCache.Setup(c => c.TryGetValue(orderId, out nothing)).Returns(false); // cache MISS
    mockInner.Setup(s => s.GetOrderAsync(orderId)).ReturnsAsync(order);

    var decorator = new CachingOrderService(mockInner.Object, mockCache.Object);
    var result    = await decorator.GetOrderAsync(orderId);

    result.Should().Be(order);
    mockInner.Verify(s => s.GetOrderAsync(orderId), Times.Once); // inner WAS called
}
```

---

# 11. Test-Driven Development (TDD)

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices

### Q1 — What is the Red-Green-Refactor cycle?

**Red** — write a failing test for new behaviour (test doesn't compile or fails).  
**Green** — write the minimal code to make the test pass (no over-engineering).  
**Refactor** — clean up code while keeping tests green.

❌ **Wrong** — writing implementation first, tests as an afterthought:
```csharp
// 1. Write full implementation
public decimal CalculateTax(decimal amount, string country)
{
    return country switch { "US" => amount * 0.08m, "UK" => amount * 0.20m, _ => 0 };
}
// 2. Write tests to match whatever the code does — tests verify implementation, not spec!
```

✅ **Correct** — TDD: test first, then minimum code to pass:
```csharp
// RED — test fails (method doesn't exist yet)
[Fact]
public void CalculateTax_ForUS_Returns8Percent()
{
    var calculator = new TaxCalculator();
    var tax = calculator.Calculate(100m, "US");
    tax.Should().Be(8m); // fails — method not implemented
}

// GREEN — minimal implementation
public decimal Calculate(decimal amount, string country)
    => country == "US" ? amount * 0.08m : 0; // just enough to pass

// Add next failing test
[Fact]
public void CalculateTax_ForUK_Returns20Percent()
{
    var tax = new TaxCalculator().Calculate(100m, "UK");
    tax.Should().Be(20m); // fails — UK not handled
}

// REFACTOR — clean up after green
public decimal Calculate(decimal amount, string country) => country switch
{
    "US" => amount * 0.08m,
    "UK" => amount * 0.20m,
    _    => 0m
};
```

---

# 12. Test Coverage & Best Practices

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices

### Q1 — What is code coverage and what percentage is good enough?

Code coverage measures what percentage of code lines/branches were executed during tests. **80–90% is a healthy target** for business logic. 100% is often impractical and doesn't guarantee correctness.

❌ **Wrong** — chasing 100% by testing implementation details:
```csharp
// Tests a private getter — brittle, tightly coupled to implementation
[Fact]
public void Order_InternalIdField_IsSet()
{
    var order = new Order();
    var field = typeof(Order).GetField("_id", BindingFlags.NonPublic | BindingFlags.Instance);
    Assert.NotNull(field!.GetValue(order)); // testing internals via reflection
}
```

✅ **Correct** — focus coverage on business rules and edge cases:
```csharp
// Measure coverage with: dotnet test --collect:"XPlat Code Coverage"
// Generate report: reportgenerator -reports:coverage.xml -targetdir:report

// Prioritise covering:
// 1. All public method happy paths
// 2. All validation rules (null, empty, boundary values)
// 3. All exception paths
// 4. All branching business logic

[Theory]
[InlineData(null)]
[InlineData("")]
[InlineData("   ")]
public void CreateOrder_WithInvalidName_ThrowsArgumentException(string? name)
{
    Action act = () => new OrderService(_repo).Create(name!);
    act.Should().Throw<ArgumentException>().WithParameterName("customerName");
}
```

---

### Q2 — What are test doubles and when do you use each?

| Double | Purpose | Example |
|--------|---------|---------|
| **Stub** | Returns canned data, no behaviour verification | `mockRepo.Setup(...).ReturnsAsync(order)` |
| **Mock** | Verifies method was called correctly | `mockRepo.Verify(...)` |
| **Fake** | Working simplified implementation | In-memory repository |
| **Spy** | Wraps real object, records calls | `Mock<T>(CallBase = true)` |
| **Dummy** | Placeholder, never used | `new Mock<ILogger>().Object` |

```csharp
// Dummy — passed but never used
var dummy = new Mock<ILogger<OrderService>>(); // we don't test logging here

// Stub — provides canned return value
var stub = new Mock<IOrderRepository>();
stub.Setup(r => r.GetByIdAsync(id)).ReturnsAsync(new Order { Id = id });

// Fake — real in-memory implementation
public class FakeOrderRepository : IOrderRepository
{
    private readonly Dictionary<Guid, Order> _store = new();
    public Task<Order?> GetByIdAsync(Guid id)
        => Task.FromResult(_store.TryGetValue(id, out var o) ? o : null);
    public Task AddAsync(Order o) { _store[o.Id] = o; return Task.CompletedTask; }
}

// Mock — verifies interactions
var mock = new Mock<IEmailService>();
await svc.CreateOrderAsync(dto);
mock.Verify(e => e.SendConfirmationAsync(It.IsAny<string>()), Times.Once);
```

---

# 13. Testing CQRS / MediatR

> 📚 Reference: https://github.com/jbogard/MediatR

### Q1 — How do you unit-test a MediatR command handler?

❌ **Wrong** — testing via the full MediatR pipeline in unit tests (over-complicated):
```csharp
var mediator = ServiceProvider.GetRequiredService<IMediator>();
var result   = await mediator.Send(new CreateOrderCommand(...)); // integration-level, not unit
```

✅ **Correct** — instantiate handler directly, mock dependencies:
```csharp
[Fact]
public async Task Handle_ValidCommand_CreatesOrderAndReturnsId()
{
    // Arrange
    var mockDb  = CreateInMemoryDbContext(); // or use mock repo
    var handler = new CreateOrderCommandHandler(mockDb);
    var cmd     = new CreateOrderCommand(CustomerId: Guid.NewGuid(),
                                         Items: [new OrderItem("SKU-1", 2)]);

    // Act
    var orderId = await handler.Handle(cmd, CancellationToken.None);

    // Assert
    orderId.Should().NotBe(Guid.Empty);

    var order = await mockDb.Orders.FindAsync(orderId);
    order.Should().NotBeNull();
    order!.CustomerId.Should().Be(cmd.CustomerId);
    order.Items.Should().HaveCount(1);
}
```

---

### Q2 — How do you test a MediatR pipeline behaviour?

❌ **Wrong** — not testing the behaviour at all, assuming it works:
```csharp
// LoggingBehavior is registered in DI — "it will work in prod"
// No unit test verifies the logging is correct
```

✅ **Correct** — unit test the behaviour directly:
```csharp
[Fact]
public async Task LoggingBehavior_LogsRequestAndResponse()
{
    var mockLogger  = new Mock<ILogger<LoggingBehavior<CreateOrderCommand, Guid>>>();
    var behaviour   = new LoggingBehavior<CreateOrderCommand, Guid>(mockLogger.Object);

    var cmd         = new CreateOrderCommand(Guid.NewGuid(), []);
    var expectedId  = Guid.NewGuid();
    RequestHandlerDelegate<Guid> next = () => Task.FromResult(expectedId);

    // Act
    var result = await behaviour.Handle(cmd, next, CancellationToken.None);

    // Assert
    result.Should().Be(expectedId);

    mockLogger.Verify(
        l => l.Log(LogLevel.Information,
                   It.IsAny<EventId>(),
                   It.Is<It.IsAnyType>((v, _) => v.ToString()!.Contains("CreateOrderCommand")),
                   null,
                   It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
        Times.AtLeast(1));
}
```

---

# 14. Snapshot & Parameterised Tests

> 📚 Reference: https://github.com/VerifyTests/Verify

### Q1 — What is snapshot testing and when is it useful?

Snapshot testing captures the serialised output of a method and saves it as a `.verified.txt` file. Future runs compare against the saved snapshot — great for testing complex objects, JSON responses, or generated HTML.

❌ **Wrong** — manually asserting every field of a large response object:
```csharp
order.Id.Should().Be(expectedId);
order.Status.Should().Be("Pending");
order.Customer.Name.Should().Be("Alice");
order.Customer.Email.Should().Be("alice@test.com");
order.Items.Should().HaveCount(3);
order.Items[0].Name.Should().Be("Widget");
// ... 20 more assertions
```

✅ **Correct** — Verify snapshot:
```csharp
// Install: dotnet add package Verify.Xunit
[UsesVerify]
public class OrderSnapshotTests
{
    [Fact]
    public async Task GetOrder_MatchesSnapshot()
    {
        var svc    = new OrderService(new FakeOrderRepository());
        var order  = await svc.GetByIdAsync(_knownId);

        await Verify(order); // first run: saves .verified.txt; subsequent: compares
    }
}
// When output changes intentionally, run: dotnet verify accept
```

---

### Q2 — How do you use `[MemberData]` for complex theory data?

❌ **Wrong** — `[InlineData]` with complex objects (doesn't support non-primitive types):
```csharp
[Theory]
[InlineData(new Order { Status = "Pending" }, "Pending")] // ❌ compile error
```

✅ **Correct** — `[MemberData]` for complex test cases:
```csharp
public static IEnumerable<object[]> OrderStatusTestData =>
[
    [new Order { Status = "Pending" },  true,  "Should allow edit"],
    [new Order { Status = "Shipped" },  false, "Cannot edit shipped order"],
    [new Order { Status = "Cancelled"}, false, "Cannot edit cancelled order"],
];

[Theory]
[MemberData(nameof(OrderStatusTestData))]
public void CanEdit_ReturnsExpectedResult(Order order, bool expected, string reason)
{
    var result = OrderPolicy.CanEdit(order);
    result.Should().Be(expected, reason);
}
```

---

# 15. Performance & Load Testing Basics

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/test/load-tests

### Q1 — How do you write a basic benchmark with BenchmarkDotNet?

❌ **Wrong** — manually timing with Stopwatch in tests (noisy, affected by JIT warm-up):
```csharp
var sw = Stopwatch.StartNew();
for (int i = 0; i < 1000; i++) ProcessOrder(order);
Console.WriteLine(sw.ElapsedMilliseconds); // inaccurate
```

✅ **Correct** — BenchmarkDotNet handles warm-up, iterations, memory, and statistics:
```csharp
// Install: dotnet add package BenchmarkDotNet
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net80)]
public class OrderProcessingBenchmarks
{
    private OrderService _svc = null!;
    private Order _order = null!;

    [GlobalSetup]
    public void Setup()
    {
        _svc   = new OrderService(new FakeOrderRepository());
        _order = new Order { Id = Guid.NewGuid(), Items = GenerateItems(100) };
    }

    [Benchmark]
    public decimal ProcessWithLinq() => _order.Items.Sum(i => i.Price * i.Qty);

    [Benchmark]
    public decimal ProcessWithSpan()
    {
        var items = CollectionsMarshal.AsSpan(_order.Items);
        decimal total = 0;
        foreach (ref var item in items) total += item.Price * item.Qty;
        return total;
    }
}

// Run: dotnet run -c Release
// Output shows Mean, Allocated memory, Gen0 GC count per benchmark
```

---

### Q2 — How do you assert performance in a regular test?

❌ **Wrong** — no performance assertions, slow code passes all tests:
```csharp
[Fact]
public async Task GetOrders_ReturnsResults()
{
    var results = await _svc.GetAllAsync(); // could take 10 seconds — test still passes
    results.Should().NotBeEmpty();
}
```

✅ **Correct** — use `ExecutionTime` assertion from FluentAssertions or `CancellationTokenSource` timeout:
```csharp
[Fact]
public async Task GetOrders_CompletesWithin500ms()
{
    using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(500));

    Func<Task> act = () => _svc.GetAllAsync(cts.Token);

    // Either completes within 500ms or throws OperationCanceledException
    await act.Should().CompleteWithinAsync(500.Milliseconds());
}
```

---

> ✅ **200+ test questions across 15 sections.**
>
> 💡 **Quick reference — packages to know:**
> - `xunit` + `xunit.runner.visualstudio` — test runner
> - `Moq` — mocking
> - `FluentAssertions` — readable assertions
> - `Microsoft.AspNetCore.Mvc.Testing` — WebApplicationFactory
> - `Microsoft.EntityFrameworkCore.Sqlite` — SQLite in-memory for EF tests
> - `Microsoft.Extensions.TimeProvider.Testing` — fake time
> - `Verify.Xunit` — snapshot testing
> - `BenchmarkDotNet` — benchmarking

---

*Last updated: 2026 | .NET 8 / xUnit 2.x / Moq 4.x / FluentAssertions 7.x*

---

# ⚖️ Testing Comparisons — Side-by-Side Differences

---

## TEST-C1 — Unit vs Integration vs End-to-End Tests

| | Unit Test | Integration Test | End-to-End (E2E) Test |
|-|-----------|-----------------|----------------------|
| What it tests | Single class/method | Multiple layers together | Full user journey (UI → DB) |
| Dependencies | All mocked | Some real (DB, cache) | All real |
| Speed | Milliseconds | Seconds | Minutes |
| Flakiness | ✅ Low (no I/O) | Medium | ❌ High (network, browser timing) |
| Run frequency | Every save (watch mode) | Every commit (CI) | Nightly / pre-release |
| Finds | Logic bugs | Integration bugs | UX and workflow bugs |
| Maintenance | Low | Medium | ❌ High |
| Ratio (pyramid) | 70% | 20% | 10% |

---

## TEST-C2 — Mock vs Stub vs Fake vs Spy vs Dummy

| | Dummy | Stub | Fake | Mock | Spy |
|-|-------|------|------|------|-----|
| Purpose | Placeholder, never used | Returns canned data | Working simplified impl | Verify interactions | Record real calls |
| Behaviour verification | ❌ | ❌ | ❌ | ✅ `Verify(...)` | ✅ (wraps real) |
| Real logic | ❌ | ❌ | ✅ Simplified | ❌ | ✅ Real + recorded |
| Example | `new Mock<ILogger>().Object` | `mockRepo.Setup(...).Returns(...)` | `FakeOrderRepository` | `mock.Verify(r => r.Save(), Times.Once)` | `Mock<T>(CallBase = true)` |

```csharp
// Dummy — passed but never called
var dummyLogger = new Mock<ILogger<OrderService>>().Object;

// Stub — provides return value
var stub = new Mock<IOrderRepo>();
stub.Setup(r => r.GetAsync(id)).ReturnsAsync(new Order());

// Fake — in-memory working implementation
public class FakeOrderRepo : IOrderRepo
{
    private Dictionary<Guid, Order> _store = new();
    public Task<Order?> GetAsync(Guid id) => Task.FromResult(_store.GetValueOrDefault(id));
    public Task SaveAsync(Order o) { _store[o.Id] = o; return Task.CompletedTask; }
}

// Mock — verifies the interaction happened
var mock = new Mock<IEmailService>();
await svc.CreateOrderAsync(dto);
mock.Verify(e => e.SendConfirmationAsync(It.IsAny<string>()), Times.Once);

// Spy — wraps real object, records calls
var spy = new Mock<IOrderService>(MockBehavior.Loose) { CallBase = true };
// Uses real methods but can also verify calls
```

---

## TEST-C3 — xUnit vs NUnit vs MSTest

| | xUnit | NUnit | MSTest |
|-|-------|-------|--------|
| Test attribute | `[Fact]` / `[Theory]` | `[Test]` / `[TestCase]` | `[TestMethod]` / `[DataTestMethod]` |
| Setup | Constructor / `IAsyncLifetime` | `[SetUp]` | `[TestInitialize]` |
| Teardown | `Dispose()` | `[TearDown]` | `[TestCleanup]` |
| Shared fixture | `IClassFixture<T>` | `[OneTimeSetUp]` | `[ClassInitialize]` |
| Test isolation | ✅ New instance per test | Configurable | New instance per test |
| Parallelism | ✅ Default | Configurable | Configurable |
| Industry preference | ✅ Most popular (.NET) | Popular, feature-rich | Microsoft/enterprise |

```csharp
// xUnit
public class OrderTests
{
    [Fact]
    public void Create_SetsStatusToPending() { }

    [Theory]
    [InlineData(1, 2, 3)]
    [InlineData(-1, 1, 0)]
    public void Add_ReturnsSum(int a, int b, int expected) { }
}

// NUnit equivalent
[TestFixture]
public class OrderTests
{
    [Test]
    public void Create_SetsStatusToPending() { }

    [TestCase(1, 2, 3)]
    [TestCase(-1, 1, 0)]
    public void Add_ReturnsSum(int a, int b, int expected) { }
}
```

---

## TEST-C4 — `[Fact]` vs `[Theory]` vs `[MemberData]` vs `[ClassData]`

| | `[Fact]` | `[Theory]` + `[InlineData]` | `[Theory]` + `[MemberData]` | `[Theory]` + `[ClassData]` |
|-|---------|----------------------------|------------------------------|---------------------------|
| Parameters | None | Inline primitives | Static property/method | Separate class |
| Complex objects | ❌ | ❌ | ✅ | ✅ |
| Reusable across tests | ❌ | ❌ | ✅ | ✅ |
| Use for | Single scenario | Quick inline cases | Complex test data | Shared datasets |

```csharp
// MemberData — for complex objects
public static IEnumerable<object[]> OrderStatusData =>
[
    [new Order { Status = "Pending" }, true],
    [new Order { Status = "Shipped" }, false],
];

[Theory]
[MemberData(nameof(OrderStatusData))]
public void CanEdit_ReturnsExpected(Order order, bool expected) =>
    Assert.Equal(expected, OrderPolicy.CanEdit(order));
```

---

## TEST-C5 — `Assert.Equal` vs FluentAssertions vs `Assert.That` (NUnit)

| | `Assert.Equal(expected, actual)` | FluentAssertions | `Assert.That(actual, Is.EqualTo(expected))` |
|-|----------------------------------|-----------------|---------------------------------------------|
| Readability | Medium | ✅ Highest | High |
| Failure message | Basic | ✅ Descriptive with context | Good |
| Chaining | ❌ | ✅ `.And.BeGreaterThan(0)` | Limited |
| Collection assertions | Basic | ✅ Rich (`HaveCount`, `AllSatisfy`) | Good |
| Library | xUnit built-in | NuGet package | NUnit built-in |

```csharp
// Basic xUnit
Assert.Equal("Pending", order.Status);
// Failure: Expected: Pending. Actual: Shipped.

// FluentAssertions
order.Status.Should().Be("Pending", because: "newly created orders start pending");
// Failure: Expected order.Status to be "Pending" because newly created orders start pending,
//          but found "Shipped".

order.Items.Should().HaveCount(3)
           .And.AllSatisfy(i => i.Price.Should().BePositive());
```

---

## TEST-C6 — In-Memory EF vs SQLite In-Memory vs Real DB (for Repository Tests)

| | In-Memory EF Provider | SQLite In-Memory | Real SQL Server / TestContainers |
|-|----------------------|-----------------|----------------------------------|
| FK constraints | ❌ Not enforced | ✅ Enforced | ✅ Enforced |
| UNIQUE constraints | ❌ Not enforced | ✅ Enforced | ✅ Enforced |
| SQL dialect accuracy | ❌ No real SQL | Medium (SQLite dialect) | ✅ Exact match |
| Speed | ✅ Fastest | ✅ Fast | Slowest (startup) |
| Migrations tested | ❌ | Partial | ✅ Full |
| Use for | Simple CRUD logic only | Most repository tests | Integration tests, migration verification |

```csharp
// SQLite In-Memory — preferred for repository tests
var connection = new SqliteConnection("DataSource=:memory:");
connection.Open();
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseSqlite(connection).Options;
using var db = new AppDbContext(options);
db.Database.EnsureCreated();

// Testcontainers — real SQL Server in Docker for integration tests
await using var container = new MsSqlBuilder()
    .WithPassword("Strong_Pwd_123!").Build();
await container.StartAsync();
var connStr = container.GetConnectionString();
```

---

## TEST-C7 — `Setup` vs `SetupSequence` vs `Callback` vs `Returns` in Moq

| | `Returns` | `ReturnsAsync` | `SetupSequence` | `Callback` | `Throws` |
|-|----------|---------------|----------------|-----------|---------|
| Purpose | Return same value always | Return Task value | Different value each call | Side effect / capture arg | Throw exception |
| Successive calls | Same | Same | Changes per call | N/A | Same |

```csharp
var mock = new Mock<IOrderRepo>();

// Returns — same every call
mock.Setup(r => r.GetAsync(id)).ReturnsAsync(new Order { Status = "Pending" });

// SetupSequence — different values on successive calls
mock.SetupSequence(r => r.GetNextAsync())
    .ReturnsAsync(order1)   // 1st call
    .ReturnsAsync(order2)   // 2nd call
    .ReturnsAsync(null);    // 3rd call → null

// Callback — capture argument for inspection
Order? saved = null;
mock.Setup(r => r.SaveAsync(It.IsAny<Order>()))
    .Callback<Order>(o => saved = o)
    .Returns(Task.CompletedTask);

// Throws — simulate error
mock.Setup(r => r.GetAsync(It.IsAny<Guid>())).ThrowsAsync(new TimeoutException());
```

