# Backend Design Patterns - Interview Guide

> A practical, beginner-friendly guide to backend patterns using C# and ASP.NET Core. Every topic is self-contained: **mental model → problem solved → before code → after code → deep walkthrough → trade-offs → practice exercise**.

**Related guides:** [Dependency Injection](dependency-injection.md) explains how these implementations are composed. [Distributed Systems Patterns](distributed-systems-patterns.md) covers patterns used after work crosses process or service boundaries.

---

## Table of Contents

1. [Service Layer](#bdp-1-service-layer-pattern)
2. [Repository](#bdp-2-repository-pattern)
3. [Unit of Work](#bdp-3-unit-of-work-pattern)
4. [Specification](#bdp-4-specification-pattern)
5. [CQRS](#bdp-5-cqrs-pattern)
6. [Mediator](#bdp-6-mediator-pattern)
7. [Strategy](#bdp-7-strategy-pattern)
8. [Factory](#bdp-8-factory-pattern)
9. [Adapter / Anti-Corruption Layer](#bdp-9-adapter-and-anti-corruption-layer-pattern)
10. [Decorator](#bdp-10-decorator-pattern)
11. [Chain of Responsibility / Middleware](#bdp-11-chain-of-responsibility-and-middleware-pattern)
12. [Domain Events](#bdp-12-domain-event-pattern)
13. [Result](#bdp-13-result-pattern)
14. [Cache-Aside](#bdp-14-cache-aside-pattern)
15. [Background Worker](#bdp-15-background-worker-pattern)
16. [Backend for Frontend](#bdp-16-backend-for-frontend-bff-pattern)

---

## BDP-1. Service Layer Pattern

**Question:** What is the Service Layer pattern, and why should controllers not contain business workflows?

**Answer:** A service layer exposes application use cases such as `PlaceOrder` or `RedeemGiftCard`. Controllers translate HTTP into a command, call the use case, and translate the result back into HTTP.

**What problem does this concept solve?** It keeps transport concerns separate from business coordination and makes the same use case callable from HTTP, a queue, or a scheduled job.

**Before this concept:** Controllers validated business rules, queried EF Core, called payment APIs, sent email, and chose HTTP responses in one method.

❌ **Wrong example:**

```csharp
[HttpPost]
public async Task<IActionResult> Create(OrderRequest request)
{
    var product = await _db.Products.FindAsync(request.ProductId);
    if (product!.Stock < request.Quantity) return BadRequest("No stock");
    product.Stock -= request.Quantity;
    var order = new Order { ProductId = product.Id, Quantity = request.Quantity };
    _db.Orders.Add(order);
    await _db.SaveChangesAsync();
    await _email.SendOrderCreated(order.Id);
    return Ok(order);
}
```

✅ **Correct example:**

```csharp
[HttpPost]
public async Task<IActionResult> Create(
    OrderRequest request, CancellationToken cancellationToken)
{
    var result = await _orders.PlaceAsync(
        new PlaceOrder(request.ProductId, request.Quantity), cancellationToken);
    return result.IsSuccess
        ? CreatedAtAction(nameof(Get), new { id = result.Value!.Id }, result.Value)
        : Problem(statusCode: result.Error!.Status, detail: result.Error.Message);
}

public sealed class OrderService
{
    public async Task<Result<OrderDto>> PlaceAsync(
        PlaceOrder command, CancellationToken cancellationToken)
    {
        // Coordinate domain rules, persistence, and an outbox event here.
    }
}
```

**How it works after this pattern:** The controller owns HTTP; the service owns the use case. Tests exercise ordering behavior without constructing MVC infrastructure.

**When to use it:** Use it when an endpoint coordinates meaningful business behavior. Do not create a pass-through service that merely renames every repository method.

### Deep walkthrough — Service Layer: place an order

**Scenario:** `POST /orders` must validate stock, calculate the price, save the order, and arrange a confirmation.

#### Before the pattern: the controller is the use case

1. MVC binds the request.
2. The controller queries inventory and pricing tables directly.
3. It constructs and saves the order.
4. It sends email and chooses an HTTP response.

This works for the first endpoint, but the same order workflow cannot be safely reused by a queue consumer or an administrator tool. A unit test must build HTTP objects, and a developer can accidentally skip a business step in the second controller.

```csharp
[HttpPost]
public async Task<IActionResult> Place(PlaceOrderRequest request)
{
    var product = await db.Products.FindAsync(request.ProductId);
    if (product is null || product.Stock < request.Quantity)
        return BadRequest("Insufficient stock");

    var order = new Order(CurrentUser.Id, product.Id,
        request.Quantity, product.Price * request.Quantity);
    db.Orders.Add(order);
    product.Stock -= request.Quantity;
    await db.SaveChangesAsync();
    await email.SendOrderConfirmation(order.Id);
    return CreatedAtAction(nameof(Get), new { order.Id }, order);
}
```

#### After the pattern: transport delegates to an application use case

```csharp
public sealed class PlaceOrderService(IOrderRepository orders,
    IInventory inventory, IUnitOfWork unitOfWork)
{
    public async Task<Result<OrderId>> Execute(PlaceOrder command, CancellationToken ct)
    {
        var reservation = await inventory.TryReserve(
            command.ProductId, command.Quantity, ct);
        if (!reservation.Succeeded)
            return Result.Fail<OrderId>("inventory.insufficient");

        var order = Order.Create(command.CustomerId, reservation);
        orders.Add(order);
        await unitOfWork.CommitAsync(ct);
        return Result.Ok(order.Id);
    }
}
```

The controller now maps HTTP input/output only. A queue handler can call the same service, while the use case can be tested with fake ports. Notice that email is not necessarily sent inside the transaction; a domain event plus outbox can arrange it reliably.

**What changed:** ownership became explicit. HTTP owns protocol details; the application service owns workflow order; domain objects own invariants; infrastructure owns persistence and providers.

**Try it:** add a `PlaceOrderFromQuote` endpoint. If it can reuse the service without copying stock and pricing rules, the boundary is helping.

---

## BDP-2. Repository Pattern

**Question:** What is the Repository pattern, and should every EF Core entity have a generic repository?

**Answer:** A repository exposes domain-focused persistence operations while hiding data-access details. EF Core's `DbSet` already behaves like a repository, so add a custom repository only when it creates a useful domain boundary.

**What problem does this concept solve?** It prevents application logic from depending on query technology and centralizes important aggregate-loading rules.

**Before this concept:** Business code repeated includes, tenant filters, and active-record conditions throughout the application.

❌ **Wrong example:**

```csharp
public interface IRepository<T>
{
    IQueryable<T> GetAll();
    Task Add(T entity);
    void Update(T entity);
    void Delete(T entity);
}
// IQueryable leaks EF details and the interface adds no domain meaning.
```

✅ **Correct example:**

```csharp
public interface IOrderRepository
{
    Task<Order?> GetForUpdateAsync(
        TenantId tenantId, OrderId orderId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Order>> FindUnpaidAsync(
        TenantId tenantId, DateTimeOffset olderThan, CancellationToken cancellationToken);
    void Add(Order order);
}

public sealed class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetForUpdateAsync(
        TenantId tenantId, OrderId orderId, CancellationToken cancellationToken) =>
        db.Orders.Include(x => x.Lines)
            .SingleOrDefaultAsync(
                x => x.TenantId == tenantId && x.Id == orderId, cancellationToken);
}
```

**How it works after this pattern:** Use cases ask domain questions such as “find unpaid orders,” while the repository consistently applies tenant and aggregate rules.

**When to use it:** Use it for aggregates or when persistence may vary. Query-only screens can often use optimized projections directly from `DbContext`.

### Deep walkthrough — Repository: load an order aggregate

**Scenario:** several workflows need an order with lines, payments, and the correct tenant restriction.

#### Before the pattern

Every caller writes its own Entity Framework query. One includes payments, another forgets the tenant filter, and a third accidentally loads a cancelled order. The problem is not merely duplicated syntax; it is duplicated knowledge about what constitutes a valid `Order` aggregate.

```csharp
var order = await db.Orders
    .Include(x => x.Lines)
    .FirstOrDefaultAsync(x => x.Id == id); // tenant restriction missing
```

#### After the pattern

```csharp
public Task<Order?> GetForUpdate(OrderId id, TenantId tenantId, CancellationToken ct) =>
    db.Orders
      .Include(x => x.Lines)
      .Include(x => x.Payments)
      .SingleOrDefaultAsync(x => x.Id == id && x.TenantId == tenantId, ct);
```

Callers request an aggregate through a domain-oriented operation. The repository guarantees the loading and isolation rules. For reporting, do not force every read through aggregate repositories: project a DTO directly so a dashboard does not load an entire object graph.

**What changed:** query technology and aggregate-loading policy moved behind a stable boundary. The trade-off is another abstraction, so create meaningful methods such as `GetForUpdate`; avoid a generic repository that merely reproduces `DbSet`.

**Try it:** write tests showing that an order from tenant B can never be returned to tenant A.

---

## BDP-3. Unit of Work Pattern

**Question:** What does Unit of Work solve, and how does EF Core implement it?

**Answer:** Unit of Work tracks several changes and commits them as one transaction. An EF Core `DbContext` already provides change tracking and `SaveChanges` as a unit of work.

**What problem does this concept solve?** It prevents a use case from partially committing related database changes.

**Before this concept:** Each repository saved immediately. Creating an order could commit even if inventory or the outbox write later failed.

❌ **Wrong example:**

```csharp
await _orders.AddAndSaveAsync(order);       // committed
await _inventory.ReserveAndSaveAsync(...); // failure: order remains
await _events.AddAndSaveAsync(...);
```

✅ **Correct example:**

```csharp
await using var transaction = await db.Database.BeginTransactionAsync(ct);
try
{
    db.Orders.Add(order);
    inventory.Reserve(order.Lines);
    db.OutboxMessages.Add(OutboxMessage.From(new OrderPlaced(order.Id)));
    await db.SaveChangesAsync(ct);
    await transaction.CommitAsync(ct);
}
catch
{
    await transaction.RollbackAsync(ct);
    throw;
}
```

**How it works after this pattern:** Order, local inventory, and outbox state commit together or all roll back. External services process the outbox after commit.

**When to use it:** Use one unit of work for one local consistency boundary. Do not hold database transactions open while calling remote APIs.

### Deep walkthrough — Unit of Work: commit order and outbox together

**Scenario:** placing an order must save the order, reduce local inventory, and store an event for later publication.

#### Before the pattern

Each repository calls `SaveChanges`. If order save succeeds and the outbox save fails, the order exists but downstream services never hear about it. Calling a payment API inside a database transaction is also unsafe: the remote service cannot participate in the local rollback and the lock remains open during network delay.

```text
Save order ✓ -> Save inventory ✓ -> process crashes -> Save outbox never runs
```

#### After the pattern

The application stages all local changes in one persistence context and calls `CommitAsync` once. The database either commits order, inventory, and outbox rows together or commits none. A separate relay publishes the outbox message after the transaction.

```csharp
orders.Add(order);
inventory.Apply(reservation);
outbox.Add(OutboxMessage.From(new OrderPlaced(order.Id)));
await unitOfWork.CommitAsync(ct); // one local transaction
```

**What changed:** local atomicity is guaranteed, but remote atomicity is not pretended. The outbox bridges the transaction and messaging boundary. Keep the transaction short and do not wait for email, Kafka, or payment providers while locks are held.

**Try it:** force an exception before `CommitAsync` and verify that none of the three rows is stored; then crash the relay and verify it can publish later.

---

## BDP-4. Specification Pattern

**Question:** How does the Specification pattern keep complex business queries reusable?

**Answer:** A specification represents selection criteria, includes, ordering, and sometimes business predicates as a named object.

**What problem does this concept solve?** It stops query rules from being copied across controllers, jobs, and services.

**Before this concept:** “Active premium customer” had different filters in billing, reporting, and notification code.

❌ **Wrong example:**

```csharp
var customers = await db.Customers
    .Where(x => x.Status == 1 && x.Plan == "P" && x.DeletedAt == null)
    .ToListAsync(); // magic values copied elsewhere
```

✅ **Correct example:**

```csharp
public sealed class ActivePremiumCustomers : Specification<Customer>
{
    public ActivePremiumCustomers(TenantId tenantId)
    {
        Query.Where(x => x.TenantId == tenantId)
             .Where(x => x.Status == CustomerStatus.Active)
             .Where(x => x.Plan == SubscriptionPlan.Premium)
             .OrderBy(x => x.Name);
    }
}

var customers = await repository.ListAsync(
    new ActivePremiumCustomers(tenantId), cancellationToken);
```

**How it works after this pattern:** The rule has one name, one implementation, and focused tests. Callers reuse it without copying query syntax.

**When to use it:** Use it for repeated or composable query rules. A unique two-clause query usually does not need a specification class.

### Deep walkthrough — Specification: define “customers needing renewal” once

**Scenario:** billing, notifications, and support all need active premium customers whose plans expire within seven days.

#### Before the pattern

Each feature copies a filter. Over time one checks UTC, another includes suspended customers, and another uses a different date boundary. The business phrase has three accidental meanings.

#### After the pattern

```csharp
public sealed class NeedsRenewalSpec : Specification<Customer>
{
    public NeedsRenewalSpec(DateTimeOffset now) =>
        Criteria = c => c.Status == CustomerStatus.Active &&
                        c.Plan == Plan.Premium &&
                        c.ExpiresAt >= now &&
                        c.ExpiresAt < now.AddDays(7);
}
```

The rule has a name and focused boundary tests. Repositories can translate the expression to SQL, and other specifications can compose it with tenant or region rules.

**What changed:** the repeated *policy* became reusable, not merely the SQL. Do not create a class for every one-off filter; the pattern pays for itself when a rule is important, reused, or composed.

**Try it:** test customers expiring exactly at `now`, exactly at seven days, and in a suspended state.

---

## BDP-5. CQRS Pattern

**Question:** What is CQRS, and does it require separate databases?

**Answer:** Command Query Responsibility Segregation separates state-changing operations from read models. It can begin with separate classes over one database; separate stores are optional.

**What problem does this concept solve?** Writes need invariant protection, while reads often need denormalized, fast, screen-specific projections.

**Before this concept:** One large service returned entities for every screen and also accepted updates, accumulating conditional logic and over-fetching.

❌ **Wrong example:**

```csharp
public class BookingService
{
    public Task<List<Booking>> GetEverything();
    public Task SaveEverything(Booking booking);
}
```

✅ **Correct example:**

```csharp
public sealed record ConfirmBooking(Guid BookingId) : ICommand<Result>;
public sealed record GetBookingSummary(Guid BookingId) : IQuery<BookingSummaryDto>;

public sealed class ConfirmBookingHandler(AppDbContext db)
{
    public async Task<Result> Handle(ConfirmBooking command, CancellationToken ct)
    {
        var booking = await db.Bookings.FindAsync([command.BookingId], ct);
        return booking!.Confirm().Bind(() => db.SaveChangesAsync(ct));
    }
}
```

**How it works after this pattern:** Command handlers protect behavior; query handlers return optimized DTOs. They may share one database until scale or ownership justifies separate projections.

**When to use it:** Use it when read and write concerns differ meaningfully. Avoid doubling types for simple CRUD with no distinct behavior.

### Deep walkthrough — CQRS: update an order and display a dashboard

**Scenario:** order writes need strong validation, while a dashboard needs customer, order, and payment data in one fast shape.

#### Before the pattern

One `OrderService` returns entities for every screen and also performs updates. The dashboard over-fetches object graphs, while write methods accumulate boolean flags to decide which validation applies.

#### After the pattern

`ApproveOrderCommandHandler` loads the aggregate, checks its transition, and commits. `GetOrderDashboardQueryHandler` selects only the required fields into `OrderDashboardDto`. At first, both can use the same database; CQRS does not require two databases or events.

```text
Command -> behavior-rich aggregate -> transactional write model
Query   -> direct projection       -> screen-specific DTO
```

**What changed:** read optimization no longer weakens write invariants. The cost is more request/handler types and, with separate stores, eventual consistency. Add that cost only when reads and writes truly differ.

**Try it:** measure the SQL and payload for the entity-based dashboard and for a projected DTO.

---

## BDP-6. Mediator Pattern

**Question:** What does a mediator add between controllers and handlers?

**Answer:** A mediator dispatches a request to its handler and allows shared pipeline behaviors such as validation, logging, authorization, and transactions.

**What problem does this concept solve?** It prevents controllers and use cases from directly depending on many handlers or cross-cutting services.

**Before this concept:** Every controller repeated validation, authorization, logging, and transaction boilerplate.

❌ **Wrong example:**

```csharp
public OrdersController(
    CreateOrderHandler create,
    CancelOrderHandler cancel,
    OrderValidator validator,
    IAudit audit,
    AppDbContext db) { /* dependency growth */ }
```

✅ **Correct example:**

```csharp
[HttpPost]
public Task<Result<OrderDto>> Create(CreateOrder command, CancellationToken ct) =>
    mediator.Send(command, ct);

public sealed class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var failures = validators.SelectMany(v => v.Validate(request).Errors).ToList();
        if (failures.Count != 0) throw new ValidationException(failures);
        return await next();
    }
}
```

**How it works after this pattern:** Controllers send requests; one handler owns each use case; ordered pipeline behaviors apply shared policies consistently.

**When to use it:** Use it when request handlers and pipelines simplify a growing application. Do not hide ordinary method calls behind a mediator without a real decoupling benefit.

### Deep walkthrough — Mediator: apply a validation and transaction pipeline

**Scenario:** twenty use cases need validation, authorization, tracing, and transactions.

#### Before the pattern

Every controller calls the four services in a slightly different order. One validates after starting a transaction; another forgets authorization. Cross-cutting behavior is convention rather than enforced composition.

#### After the pattern

The controller sends `ApproveOrderCommand`. The mediator resolves one handler and passes it through ordered behaviors:

```text
Controller -> Trace -> Authorize -> Validate -> Transaction -> Handler
```

The handler contains only use-case logic. Read-only requests can skip the transaction behavior through metadata or separate pipeline configuration.

**What changed:** shared request policy is centralized and consistently ordered. The downside is indirection: debugging requires understanding the pipeline. Use clear handler names, structured tracing, and avoid turning ordinary internal method calls into mediator requests.

**Try it:** create a behavior that rejects an invalid command and prove that the handler and transaction never run.

---

## BDP-7. Strategy Pattern

**Question:** How does Strategy replace backend business-rule condition chains?

**Answer:** Strategy defines interchangeable implementations behind one interface and selects one based on runtime context.

**What problem does this concept solve?** It lets algorithms change independently and makes new variants additive.

**Before this concept:** Payment, pricing, or notification code grew a switch statement for every provider or customer type.

❌ **Wrong example:**

```csharp
if (provider == "Stripe") { /* Stripe logic */ }
else if (provider == "PayPal") { /* PayPal logic */ }
else if (provider == "Razorpay") { /* Razorpay logic */ }
```

✅ **Correct example:**

```csharp
public interface IPaymentStrategy
{
    string Provider { get; }
    Task<PaymentResult> ChargeAsync(Payment payment, CancellationToken ct);
}

public sealed class PaymentRouter(IEnumerable<IPaymentStrategy> strategies)
{
    public Task<PaymentResult> ChargeAsync(Payment payment, CancellationToken ct) =>
        strategies.Single(x => x.Provider == payment.Provider)
                  .ChargeAsync(payment, ct);
}
```

**How it works after this pattern:** The router selects a provider through a stable contract. Each provider handles its own mapping, retries, and tests.

**When to use it:** Use it for independently changing algorithms. Keep a simple conditional when variants are few, stable, and trivial.

### Deep walkthrough — Strategy: support multiple payment providers

**Scenario:** choose Stripe, Adyen, or a test provider according to tenant configuration.

#### Before the pattern

A single method contains a growing `switch`. Provider-specific request mapping, error handling, and retries leak into every branch. Adding a provider means editing stable code and retesting unrelated providers.

#### After the pattern

Each `IPaymentStrategy` implements `Charge`. A selector resolves the tenant's configured strategy, and each implementation owns its provider mapping and tests.

```text
Checkout -> PaymentStrategySelector -> StripeStrategy
                                    -> AdyenStrategy
                                    -> SandboxStrategy
```

**What changed:** adding a provider is additive and algorithms can vary independently. Selection policy remains separate from execution. If there are only two trivial, stable branches, a conditional may still be clearer.

**Try it:** add a provider that supports authorization but not capture, and decide whether the common interface needs capabilities or separate contracts.

---

## BDP-8. Factory Pattern

**Question:** When should backend code use a factory?

**Answer:** A factory centralizes object creation when constructing the object requires validation, provider selection, dependencies, or business rules.

**What problem does this concept solve?** It stops creation rules from being duplicated and prevents callers from depending on concrete types.

**Before this concept:** Controllers constructed provider clients and domain objects with slightly different defaults.

❌ **Wrong example:**

```csharp
var card = new GiftCard {
    Id = Guid.NewGuid(), Balance = request.Amount, Status = 1
}; // invariants can be skipped anywhere
```

✅ **Correct example:**

```csharp
public static class GiftCardFactory
{
    public static Result<GiftCard> Issue(Money amount, DateOnly expiresOn)
    {
        if (amount.Value <= 0) return Result.Fail<GiftCard>("Amount must be positive");
        if (expiresOn <= DateOnly.FromDateTime(DateTime.UtcNow))
            return Result.Fail<GiftCard>("Expiry must be in the future");
        return Result.Ok(new GiftCard(GiftCardId.New(), amount, expiresOn));
    }
}
```

**How it works after this pattern:** Every gift card begins in a valid state through one named creation path.

**When to use it:** Use it when creation has policy. Direct constructors remain clearer for simple data objects.

### Deep walkthrough — Factory: create valid gift cards

**Scenario:** every gift card requires a secure code, currency, expiry policy, audit identity, and positive starting value.

#### Before the pattern

Controllers call constructors directly and choose their own defaults. One forgets expiry; another generates a short predictable code. Objects can enter the system in an invalid or inconsistent state.

#### After the pattern

A factory receives the policy services and exposes an intention-revealing operation such as `IssuePromotionalCard`. It validates input, generates the code, calculates expiry, and returns a fully valid aggregate.

```csharp
var card = giftCardFactory.IssuePromotionalCard(
    tenantId, Money.Usd(50), issuedBy, clock.UtcNow);
```

**What changed:** creation policy has one testable home. A factory is not a reason to hide simple constructors; use it when construction has rules, variants, async lookup, or dependencies.

**Try it:** add a non-expiring customer-refund card without putting another boolean flag into the factory method.

---

## BDP-9. Adapter and Anti-Corruption Layer Pattern

**Question:** How does an Adapter protect a backend domain from third-party APIs?

**Answer:** An adapter translates an external contract into an internal interface and model. An anti-corruption layer may combine several adapters and rules to prevent external terminology from entering the domain.

**What problem does this concept solve?** It contains provider-specific fields, errors, versions, and semantics.

**Before this concept:** Shopify, Calendar, or payment DTOs flowed directly into domain services, so provider changes affected the entire application.

❌ **Wrong example:**

```csharp
public async Task BookAsync(GoogleCalendarEvent googleEvent)
{
    order.GoogleStatus = googleEvent.Status; // provider model becomes domain model
}
```

✅ **Correct example:**

```csharp
public interface ICalendarGateway
{
    Task<ExternalAppointmentId> CreateAsync(
        Appointment appointment, CancellationToken ct);
}

public sealed class GoogleCalendarAdapter(GoogleCalendarClient client)
    : ICalendarGateway
{
    public async Task<ExternalAppointmentId> CreateAsync(
        Appointment appointment, CancellationToken ct)
    {
        var request = GoogleMapper.ToEvent(appointment);
        var response = await client.InsertAsync(request, ct);
        return new ExternalAppointmentId(response.Id);
    }
}
```

**How it works after this pattern:** The domain speaks in appointments. Only the adapter knows Google fields, tokens, and error codes.

**When to use it:** Use it at external or legacy boundaries. Do not add mapping layers between identical internal models without purpose.

### Deep walkthrough — Adapter/ACL: integrate an external calendar

**Scenario:** the domain schedules appointments while Google and Microsoft expose different event models.

#### Before the pattern

Provider DTOs travel through domain services. Business code checks Google status strings and Microsoft time-zone formats. A provider API revision causes changes throughout the application.

#### After the pattern

The domain depends on `ICalendarGateway.CreateAppointment(Appointment)`. Google and Microsoft adapters translate the domain request, normalize errors, and return domain-level results.

```text
Domain Appointment -> ICalendarGateway -> GoogleCalendarAdapter -> Google DTO
                                        -> MsGraphAdapter       -> Graph DTO
```

**What changed:** external language is quarantined at the boundary. Translation code is deliberate and contract-tested. Do not expose provider error codes as domain decisions; map them to concepts such as conflict, unavailable, or unauthorized while retaining raw details in logs.

**Try it:** simulate Google changing a field name and verify that only the adapter and its contract test change.

---

## BDP-10. Decorator Pattern

**Question:** How does Decorator add behavior without modifying a backend service?

**Answer:** A decorator implements the same interface, wraps another implementation, and adds behavior before or after delegation.

**What problem does this concept solve?** It composes logging, caching, metrics, validation, or authorization without mixing those concerns into core logic.

**Before this concept:** Every query service manually copied cache and metrics code.

❌ **Wrong example:**

```csharp
public async Task<Product> Get(Guid id)
{
    _logger.LogInformation("Get {Id}", id);
    // cache, timer, database, error mapping all mixed here
}
```

✅ **Correct example:**

```csharp
public sealed class CachedProductReader(
    IProductReader inner, IDistributedCache cache) : IProductReader
{
    public async Task<ProductDto?> GetAsync(Guid id, CancellationToken ct)
    {
        var key = $"product:{id}";
        var cached = await cache.GetStringAsync(key, ct);
        if (cached is not null) return JsonSerializer.Deserialize<ProductDto>(cached);
        var product = await inner.GetAsync(id, ct);
        if (product is not null)
            await cache.SetStringAsync(key, JsonSerializer.Serialize(product), ct);
        return product;
    }
}
```

**How it works after this pattern:** The core reader reads products; decorators independently add cache, metrics, or resilience in an explicit order.

**When to use it:** Use it for orthogonal behavior around a stable interface. Middleware or mediator behaviors may be simpler for request-wide concerns.

### Deep walkthrough — Decorator: cache and measure product reads

**Scenario:** a product reader needs caching and latency metrics without changing its database query.

#### Before the pattern

The reader performs cache lookup, deserialization, metrics, logging, and SQL in one method. Testing the query requires constructing every cross-cutting dependency, and another reader copies the same ceremony.

#### After the pattern

```text
Caller -> MetricsDecorator -> CacheDecorator -> SqlProductReader
```

Each decorator implements the same interface and delegates. Ordering is meaningful: metrics outside the cache measures user-visible latency; inside it measures database latency only.

**What changed:** the core service has one job and wrappers are independently composable. Too many decorators can obscure the call stack, so document registration order and prefer middleware when the concern applies to all HTTP requests.

**Try it:** swap decorator order and predict which cache hits appear in the database-latency metric.

---

## BDP-11. Chain of Responsibility and Middleware Pattern

**Question:** How does ASP.NET Core middleware implement Chain of Responsibility?

**Answer:** Each middleware handles a request, short-circuits it, or passes it to the next handler in an ordered chain.

**What problem does this concept solve?** It applies request-wide concerns once instead of repeating them in every endpoint.

**Before this concept:** Controllers manually performed correlation, exception mapping, authentication checks, and response logging.

❌ **Wrong example:**

```csharp
try { /* endpoint */ }
catch (Exception ex) { return StatusCode(500, ex.ToString()); } // leaks details
```

✅ **Correct example:**

```csharp
app.UseExceptionHandler();
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

public async Task InvokeAsync(HttpContext context, RequestDelegate next)
{
    context.TraceIdentifier = context.Request.Headers["X-Correlation-ID"]
        .FirstOrDefault() ?? Guid.NewGuid().ToString("N");
    await next(context);
}
```

**How it works after this pattern:** Requests pass through one predictable pipeline. Ordering is visible and each middleware has one responsibility.

**When to use it:** Use it for transport-wide concerns. Domain rules and entity authorization belong closer to the use case.

### Deep walkthrough — Middleware/Chain of Responsibility: handle every HTTP request

**Scenario:** every request needs correlation, exception mapping, authentication, and response timing.

#### Before the pattern

Controllers repeat `try/catch`, start timers, and add response headers. Endpoints created later often omit one concern, and exception responses vary.

#### After the pattern

```text
Request -> Correlation -> Exception Mapping -> Authentication -> Routing
Response <- Correlation <- Exception Mapping <- Authentication <- Endpoint
```

Each middleware can act before and after `next()`, short-circuit, or translate failures. Order is part of behavior: exception middleware must wrap components whose errors it handles; authentication must run before authorization.

**What changed:** transport-wide policy is applied once. Domain authorization still belongs in the use case because middleware cannot decide whether this user may edit this particular order.

**Try it:** deliberately put authorization before authentication, observe the result, then write a pipeline-order integration test.

---

## BDP-12. Domain Event Pattern

**Question:** What is a domain event, and how is it different from an integration event?

**Answer:** A domain event records that something meaningful happened inside a domain boundary. An integration event is the stable external message published for other boundaries.

**What problem does this concept solve?** It separates the aggregate's primary operation from secondary reactions while preserving domain language.

**Before this concept:** The aggregate or application service directly called email, analytics, loyalty, and audit services.

❌ **Wrong example:**

```csharp
public void Confirm()
{
    Status = BookingStatus.Confirmed;
    _email.Send(...);      // domain entity performs I/O
    _analytics.Track(...);
}
```

✅ **Correct example:**

```csharp
public Result Confirm()
{
    if (Status != BookingStatus.Pending) return Result.Fail("Invalid state");
    Status = BookingStatus.Confirmed;
    Raise(new BookingConfirmed(Id, CustomerId));
    return Result.Ok();
}

public sealed class BookingConfirmedHandler
{
    public Task Handle(BookingConfirmed domainEvent, CancellationToken ct)
    {
        // Create an outbox integration event after the local transaction succeeds.
    }
}
```

**How it works after this pattern:** Confirmation changes aggregate state and records a fact. Handlers perform local reactions or translate it into a durable integration event.

**When to use it:** Use events for meaningful secondary reactions. Direct method calls are clearer when behavior must be immediate and part of one invariant.

### Deep walkthrough — Domain Event: react to an order confirmation

**Scenario:** confirming an order should update loyalty points, create an audit record, and eventually send a notification.

#### Before the pattern

`Order.Confirm` or its service directly calls three unrelated services. Adding analytics modifies the confirmation workflow, and a notification outage can block the primary state transition.

#### After the pattern

The aggregate changes its own state and records `OrderConfirmed`. In-process handlers update local transactional state. An outbox converts external reactions into durable integration events after commit.

```text
Order.Confirm -> record OrderConfirmed
Commit order + event/outbox
Handlers -> loyalty/audit locally; relay -> notification externally
```

**What changed:** a business fact can have new reactions without making the aggregate know them. Events introduce ordering, duplication, and observability concerns; keep direct calls when a reaction is part of the same immediate invariant.

**Try it:** decide whether reserving stock is part of `Confirm` or a reaction. Explain what must happen if it fails.

---

## BDP-13. Result Pattern

**Question:** Why return a Result instead of throwing exceptions for expected business outcomes?

**Answer:** A Result represents success or a known failure explicitly. Exceptions remain for unexpected failures.

**What problem does this concept solve?** It makes validation, conflict, and not-found outcomes visible in method contracts and avoids expensive exception-driven control flow.

**Before this concept:** Services returned `null`, booleans, or threw generic exceptions, leaving callers unable to distinguish failures safely.

❌ **Wrong example:**

```csharp
if (giftCard.Balance < amount)
    throw new Exception("Bad");
```

✅ **Correct example:**

```csharp
public Result Redeem(Money amount)
{
    if (Status != GiftCardStatus.Active)
        return Result.Fail(Error.Conflict("gift_card_inactive", "Gift card is not active"));
    if (Balance < amount)
        return Result.Fail(Error.Validation("insufficient_balance", "Insufficient balance"));
    Balance -= amount;
    return Result.Ok();
}
```

**How it works after this pattern:** The application maps known error codes to consistent HTTP responses. Unexpected database or network failures still use exception handling and observability.

**When to use it:** Use it for expected outcomes callers can handle. Do not wrap every programming bug in a success/failure object.

### Deep walkthrough — Result: represent an expected rejection

**Scenario:** redeeming a gift card can legitimately fail because it is expired, empty, or belongs to another tenant.

#### Before the pattern

The service returns `false`, `null`, or throws `Exception("failed")`. The controller cannot safely choose between 404, 409, and 422, and logs are filled with stack traces for expected decisions.

#### After the pattern

```csharp
return card switch
{
    null => Result.Fail<Receipt>("giftcard.not_found"),
    { IsExpired: true } => Result.Fail<Receipt>("giftcard.expired"),
    _ => Result.Ok(card.Redeem(amount))
};
```

The controller maps known codes to a stable error contract. Unexpected bugs, broken database connections, and invariant violations still throw and go through centralized exception handling.

**What changed:** expected outcomes are visible in the method contract and exhaustively tested. Avoid meaningless `Result<Result<T>>` layers or converting programmer errors into recoverable business failures.

**Try it:** define the HTTP status and client-facing message for each failure without leaking internal exception text.

---

## BDP-14. Cache-Aside Pattern

**Question:** How does cache-aside work in a backend API?

**Answer:** The application checks cache, loads from the source on a miss, and populates cache for later requests. The database remains authoritative.

**What problem does this concept solve?** It reduces latency and database load for frequently read, slowly changing data.

**Before this concept:** Every request repeated the same expensive query.

❌ **Wrong example:**

```csharp
await cache.SetStringAsync($"product:{id}", json); // no TTL
// UpdateProduct never invalidates or versions this key.
```

✅ **Correct example:**

```csharp
public async Task<ProductDto?> GetAsync(Guid id, CancellationToken ct)
{
    var key = $"product:v2:{id}";
    var value = await cache.GetStringAsync(key, ct);
    if (value is not null) return JsonSerializer.Deserialize<ProductDto>(value);

    var product = await db.Products.Where(x => x.Id == id)
        .Select(ProductDto.Projection).SingleOrDefaultAsync(ct);
    if (product is not null)
        await cache.SetStringAsync(key, JsonSerializer.Serialize(product),
            new DistributedCacheEntryOptions {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
            }, ct);
    return product;
}
```

**How it works after this pattern:** Hot reads avoid the database, keys are versioned or invalidated after writes, and TTL bounds staleness.

**When to use it:** Use it when repeated reads justify complexity. Do not cache highly volatile data without a clear correctness model.

### Deep walkthrough — Cache-Aside: read a product catalogue

**Scenario:** product details are read thousands of times and updated occasionally.

#### Before the pattern

Every request executes the same query and serialization. During a promotion, database connections become the limit even though most responses are identical.

#### After the pattern

1. Read `product:{id}:v2` from cache.
2. On a miss, query the source of truth.
3. Store the serialized DTO with a bounded TTL and jitter.
4. On update, commit the database first, then invalidate or version the cache entry.

Use single-flight protection so one expired hot key does not trigger hundreds of identical queries. Decide explicitly whether a brief stale read is acceptable.

**What changed:** common reads trade some freshness and operational complexity for lower latency and database load. Never make the cache the only copy of business data.

**Try it:** test cache miss, hit, stale value, database failure, and simultaneous expiry.

---

## BDP-15. Background Worker Pattern

**Question:** When should an API move work to a background worker?

**Answer:** Persist the user's intent, enqueue durable work, return an operation identifier, and let a worker perform slow or retryable processing.

**What problem does this concept solve?** It prevents slow email, export, media, or provider work from occupying request resources or failing when a client disconnects.

**Before this concept:** The HTTP request stayed open for minutes and lost all progress if the process restarted.

❌ **Wrong example:**

```csharp
_ = Task.Run(() => GenerateReport(request)); // not durable; lost on restart
return Accepted();
```

✅ **Correct example:**

```csharp
[HttpPost("reports")]
public async Task<IActionResult> CreateReport(CreateReport request, CancellationToken ct)
{
    var operation = ReportOperation.Pending(request);
    db.ReportOperations.Add(operation);
    db.OutboxMessages.Add(OutboxMessage.From(new ReportRequested(operation.Id)));
    await db.SaveChangesAsync(ct);
    return AcceptedAtAction(nameof(GetStatus), new { id = operation.Id });
}
```

**How it works after this pattern:** The request returns quickly with durable status. An idempotent worker processes the job, checkpoints progress, and exposes success or failure for polling or notification.

**When to use it:** Use it for durable asynchronous work. Keep fast validation and operations needed for the immediate response synchronous.

### Deep walkthrough — Background Worker: generate a large report

**Scenario:** report generation takes two minutes and may need three retries.

#### Before the pattern

The HTTP connection remains open while the report is built. A proxy timeout makes the user see failure even when work continues, and an application restart loses progress. Retrying the request may start a duplicate report.

#### After the pattern

The API validates the request, creates a durable operation and outbox/queue message, and returns `202 Accepted` with a status URL. An idempotent worker claims the job, heartbeats or checkpoints, stores the result, and records a terminal status.

```text
POST /reports -> 202 + operationId
Worker -> Pending -> Running -> Succeeded/Failed
GET /reports/{operationId} -> progress and download link
```

**What changed:** request lifetime and work lifetime are separated. You now need retry policy, poison-job handling, cancellation, progress, and retention—but the work survives disconnects and restarts.

**Try it:** stop the worker halfway through and prove another worker resumes without producing two final files.

---

## BDP-16. Backend for Frontend (BFF) Pattern

**Question:** What is the BFF pattern, and when should web and mobile clients have different backends?

**Answer:** A BFF is a client-specific backend that aggregates and shapes downstream capabilities for one user experience.

**What problem does this concept solve?** It avoids forcing every client to orchestrate many services or accept a one-size-fits-none API.

**Before this concept:** The Angular app made ten calls, joined data in the browser, duplicated authorization assumptions, and exposed internal service topology.

❌ **Wrong example:**

```text
Browser -> Customer Service
        -> Booking Service
        -> Payment Service
        -> Offers Service
        -> Permissions Service
```

✅ **Correct example:**

```text
Angular -> Web BFF -> Customer, Booking, Payment, Offers services
Mobile  -> Mobile BFF -> smaller payloads and mobile-specific workflow
```

```csharp
[HttpGet("dashboard")]
public async Task<DashboardDto> GetDashboard(CancellationToken ct)
{
    var bookingTask = bookings.GetUpcomingAsync(CurrentUser.Id, ct);
    var offerTask = offers.GetForUserAsync(CurrentUser.Id, ct);
    await Task.WhenAll(bookingTask, offerTask);
    return new DashboardDto(await bookingTask, await offerTask);
}
```

**How it works after this pattern:** The client makes one experience-focused call, internal services remain hidden, and web/mobile payloads evolve independently.

**When to use it:** Use it when clients have meaningfully different orchestration needs. Do not duplicate domain logic or turn the BFF into a new monolith.

### Deep walkthrough — BFF: build a web dashboard

**Scenario:** the web page needs bookings, offers, permissions, and payment summary; mobile needs only the next booking and compact actions.

#### Before the pattern

Each client knows internal service addresses and makes many calls. It joins partial results, duplicates authorization assumptions, and displays inconsistent states when one call finishes later. A service split forces releases of every client.

#### After the pattern

The Web BFF calls downstream capabilities concurrently, applies experience-specific composition, and returns one stable dashboard DTO. The Mobile BFF returns a smaller contract and can use a different cache policy. Domain rules stay in domain services rather than being copied into either BFF.

```text
Web -> Web BFF ------> Booking / Offers / Payments / Permissions
Mobile -> Mobile BFF -> Booking / Permissions
```

**What changed:** orchestration and payload shaping moved from devices to an owned server boundary. Watch for duplicated logic, cascading latency, and a BFF that grows into a second monolith. Use deadlines and partial-response rules for downstream calls.

**Try it:** define which dashboard sections are essential, which may be stale, and what the BFF returns when the offers service times out.

---

## Backend Pattern Selection Cheat Sheet

| Problem | First pattern to consider |
|---|---|
| Controllers contain business workflows | Service Layer |
| Repeated aggregate query rules | Repository / Specification |
| Several local writes must commit together | Unit of Work |
| Read and write models differ | CQRS |
| Many request handlers need the same pipeline | Mediator |
| Runtime algorithm/provider varies | Strategy |
| Creation has rules | Factory |
| Third-party schema leaks inward | Adapter / Anti-Corruption Layer |
| Cross-cutting behavior wraps a service | Decorator |
| Ordered request-wide handlers | Middleware / Chain of Responsibility |
| Secondary reactions follow a domain fact | Domain Events |
| Expected business failures need explicit handling | Result |
| Repeated expensive reads | Cache-Aside |
| Slow durable work | Background Worker |
| Clients need different aggregation | BFF |

---
