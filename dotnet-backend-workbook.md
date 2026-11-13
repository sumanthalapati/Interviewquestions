# .NET and Backend Engineering Practice Workbook

This workbook turns the repository's C#, .NET, ASP.NET Core, Entity Framework, API, pattern, testing, and production material into deliberate practice. It is not a collection of one-line interview definitions. Every module asks you to predict behavior, repair a weak design, explain a trade-off, and produce evidence that the result works.

Use these source guides while checking your answers: [C#/.NET Core](readme.md), [ASP.NET Core Fundamentals](aspnet-core-fundamentals.md), [ASP.NET Core Advanced](aspnet-core-advanced.md), [ASP.NET Core API Design](aspnet-core-api-design.md), [ASP.NET MVC](aspnet-mvc.md), [Entity Framework](entity-framework.md), [Dependency Injection](dependency-injection.md), [Backend Design Patterns](backend-design-patterns.md), [Distributed Systems Patterns](distributed-systems-patterns.md), and [Unit Testing](unit-testing.md).

## How to Use This Workbook

For each module:

1. Answer without opening the key.
2. Predict the code's output or failure before running it.
3. State the invariant that must remain true.
4. Implement the correction and add a test that fails on the original code.
5. Inject at least one production failure such as timeout, cancellation, duplicate delivery, concurrency, or dependency outage.
6. Record what metric, trace, log, or assertion proves the corrected design works.

## Module Index

1. [C# Types, Nullability, Records, Exceptions, and Language Semantics](#module-1-c-types-nullability-records-exceptions-and-language-semantics)
2. [OOP, SOLID, Boundaries, and Design Patterns](#module-2-oop-solid-boundaries-and-design-patterns)
3. [Collections, Generics, LINQ, and Query Semantics](#module-3-collections-generics-linq-and-query-semantics)
4. [Async, Concurrency, Memory, and Garbage Collection](#module-4-async-concurrency-memory-and-garbage-collection)
5. [ASP.NET Core Pipeline, Configuration, and Dependency Injection](#module-5-aspnet-core-pipeline-configuration-and-dependency-injection)
6. [MVC, API Contracts, Authentication, Authorization, and Errors](#module-6-mvc-api-contracts-authentication-authorization-and-errors)
7. [Entity Framework Core and Data Access](#module-7-entity-framework-core-and-data-access)
8. [Backend and Distributed-System Patterns](#module-8-backend-and-distributed-system-patterns)
9. [Testing Strategy and Testable Design](#module-9-testing-strategy-and-testable-design)
10. [Performance, Observability, Reliability, and Operations](#module-10-performance-observability-reliability-and-operations)

---

## Module 1. C# Types, Nullability, Records, Exceptions, and Language Semantics

### Concept map

- Value types contain their value; reference-type variables hold a reference to an object.
- Boxing copies a value into an object; unboxing requires the correct underlying value type.
- Nullable reference annotations express a compile-time contract, not a runtime validation boundary.
- Records provide value-oriented equality by default; classes use reference identity unless equality is implemented.
- `record struct`, `readonly struct`, class, and record have different allocation, copying, mutation, and equality implications.
- Exceptions represent exceptional failure; expected validation and business outcomes need explicit result contracts.
- Pattern matching can make state handling exhaustive and visible, but guards and ordering affect behavior.

### Questions

1. Why can `object boxed = 5; long value = (long)boxed;` fail even though `int` converts to `long` normally? Write the safe version.
2. When should a domain value be a `readonly record struct`, a record class, or an ordinary class? Discuss copying, identity, null, mutation, and equality.
3. Nullable reference types are enabled and a parameter is declared `string name`. Can malformed JSON or reflection still produce `null`? Where must runtime validation occur?
4. Compare throwing an exception, returning `null`, returning `bool`, and returning a typed result for “customer credit is insufficient.”
5. What behavior changes when a mutable collection is stored inside a record and two equal records share that collection?
6. Write an exhaustive pattern match for an order in `Draft`, `Paid`, `Shipped`, or `Cancelled` state. Which transitions should be impossible?

### Wrong/before code

```csharp
public sealed record CreateUser(string Email, string DisplayName);

public async Task<User> CreateAsync(CreateUser request)
{
    // Nullable annotations are treated as runtime validation.
    var normalized = request.Email.Trim().ToLowerInvariant();

    try
    {
        if (await _repository.ExistsAsync(normalized))
            throw new Exception("Email exists");

        return await _repository.InsertAsync(new User(normalized, request.DisplayName));
    }
    catch
    {
        throw new Exception("Creation failed"); // destroys cause and expected/exception distinction
    }
}
```

### Corrected/after code

```csharp
public sealed record CreateUser(string? Email, string? DisplayName);

public abstract record CreateUserResult
{
    public sealed record Created(User User) : CreateUserResult;
    public sealed record Invalid(IReadOnlyDictionary<string, string[]> Errors)
        : CreateUserResult;
    public sealed record DuplicateEmail : CreateUserResult;
}

public async Task<CreateUserResult> CreateAsync(
    CreateUser request,
    CancellationToken cancellationToken)
{
    var errors = Validate(request);
    if (errors.Count > 0)
        return new CreateUserResult.Invalid(errors);

    // EmailAddress owns the product's documented normalization policy.
    // Do not assume lowercasing the complete address is universally correct.
    var email = EmailAddress.Create(request.Email!);
    var user = new User(email, request.DisplayName!.Trim());

    try
    {
        await _repository.InsertAsync(user, cancellationToken);
        return new CreateUserResult.Created(user);
    }
    catch (UniqueConstraintException) // adapter maps the named provider constraint
    {
        // Database uniqueness remains the race-safe final authority.
        return new CreateUserResult.DuplicateEmail();
    }
}
```

### Detailed answer key

1. Boxing stores an `Int32`. Unboxing is not a numeric conversion; `(long)boxed` asks the runtime to unbox an `Int64`, so it throws. Use `long value = (int)boxed;` or `Convert.ToInt64(boxed)` after validating the input type.
2. Use a small immutable `readonly record struct` for non-null value semantics when copying is cheap, such as a validated `Money` or `OrderId`. Use a record class for value-oriented equality with reference allocation, inheritance needs, or larger state. Use a class for entities with identity and lifecycle where two objects with equal current fields are not the same entity. Avoid large mutable structs because copying and mutation become surprising.
3. Yes. Annotations guide the compiler and tools; external input, serializers, reflection, old assemblies, and `null!` can violate them. Validate at the transport boundary, then construct a domain type whose invariants make invalid state difficult to represent.
4. Insufficient credit is normally an expected business rejection, so a typed result exposes the reason without exception-driven control flow. `null` loses why; `bool` loses details; an exception implies an exceptional failure and complicates metrics/retries. Unexpected database/network/programming failures should remain exceptions with their original stack/cause.
5. Record equality for a collection property normally compares the collection reference, not deep contents. Mutation can change the record's observable state after it is used as a key. Prefer immutable collections/value objects and define equality intentionally.
6. `Draft -> Paid/Cancelled`, `Paid -> Shipped/Cancelled` according to policy, and terminal `Shipped/Cancelled` states should reject invalid transitions. A switch expression with a default throwing an invariant exception makes unhandled future states visible.

```csharp
static OrderState Transition(OrderState current, OrderCommand command) =>
    (current, command) switch
    {
        (OrderState.Draft, OrderCommand.Pay)       => OrderState.Paid,
        (OrderState.Draft, OrderCommand.Cancel)    => OrderState.Cancelled,
        (OrderState.Paid, OrderCommand.Ship)       => OrderState.Shipped,
        (OrderState.Paid, OrderCommand.Cancel)     => OrderState.Cancelled,
        _ => throw new InvalidOperationException(
            $"Cannot apply {command} while order is {current}.")
    };
```

### Production and failure checks

- Validate external data before using nullability promises.
- Give identifiers such as email addresses an explicit normalization/equality policy. Preserve the original representation when required; do not blindly lowercase every local part.
- Ensure database uniqueness uses the same canonical value, tenant scope, and comparison/collation rules as application equality.
- Preserve original exceptions and stack traces; do not `throw ex` or wrap without the inner exception.
- Map expected typed failures to stable API error codes and unexpected failures to one sanitized problem response.
- Test culture-sensitive parsing/casing, overflow, default struct values, serialization, and equality/hash behavior.
- Never use mutable value objects as dictionary keys unless their hash-relevant state cannot change.

### Build/debug task

Implement `EmailAddress`, `Money`, and `OrderState` domain types. Add construction, JSON serialization, equality, dictionary-key, invalid-default, culture, and state-transition tests. Demonstrate one bug caused by a mutable record member and fix it with immutable state.

---

## Module 2. OOP, SOLID, Boundaries, and Design Patterns

### Concept map

- Encapsulation protects invariants; it is more than making fields private.
- Inheritance is substitutability, not code reuse. Composition is often safer.
- SOLID guides change boundaries; it is not a requirement for one interface per class.
- A pattern earns its complexity by solving a recurring force: variation, lifecycle, construction, cross-cutting behavior, or state transition.
- Dependency inversion means policy depends on application-shaped abstractions, with infrastructure selected at the composition root.
- Pattern names do not replace ownership, error, concurrency, and transaction decisions.

### Questions

1. Explain how a `Square : Rectangle` can violate Liskov substitution even when the code compiles.
2. When does an interface improve design, and when is it an unnecessary one-implementation layer?
3. Compare Strategy, Template Method, and a simple function/delegate for selecting a pricing rule.
4. Why is a repository that exposes `IQueryable<T>` often a leaky abstraction?
5. Where should decorators for caching, retries, metrics, or authorization be applied, and why does ordering matter?
6. Give an example where applying a design pattern makes the system worse than a direct implementation.

### Wrong/before code

```csharp
public sealed class CheckoutService
{
    public async Task Checkout(Order order)
    {
        var db = new SqlOrderRepository("prod-connection");
        var stripe = new StripeClient(Environment.GetEnvironmentVariable("STRIPE_KEY"));

        await stripe.ChargeAsync(order.CardToken, order.Total);
        await db.SaveAsync(order);
        await new SmtpClient().SendAsync(order.CustomerEmail, "Order received");
    }
}
```

The business class owns construction, secrets, provider details, transaction ambiguity, and three different failure lifecycles.

### Corrected/after code

```csharp
public interface IPaymentGateway
{
    Task<ChargeResult> ChargeAsync(
        PaymentRequest request,
        string idempotencyKey,
        CancellationToken cancellationToken);
}

public interface IPlaceOrder
{
    Task<PlaceOrderResult> ExecuteAsync(
        PlaceOrder command,
        CancellationToken cancellationToken);
}

public sealed class PlaceOrderHandler(
    IPaymentGateway payments,
    IOrderRepository orders,
    IUnitOfWork unitOfWork) : IPlaceOrder
{
    public async Task<PlaceOrderResult> ExecuteAsync(
        PlaceOrder command,
        CancellationToken cancellationToken)
    {
        var existing = await orders.FindByIdempotencyKeyAsync(
            command.IdempotencyKey, cancellationToken);
        if (existing is not null)
            return PlaceOrderResult.Replay(existing.Id);

        var charge = await payments.ChargeAsync(
            command.Payment,
            command.IdempotencyKey,
            cancellationToken);
        if (!charge.Accepted)
            return PlaceOrderResult.PaymentRejected(charge.Code);

        var order = Order.Place(command.CustomerId, command.Items, charge.Reference);
        orders.Add(order);
        unitOfWork.AddOutbox(new OrderPlaced(order.Id));
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return PlaceOrderResult.Created(order.Id);
    }
}
```

Infrastructure registration chooses concrete adapters and decorator order in one composition root.

This example deliberately exposes a remaining distributed boundary: a payment authorization/charge and a database commit are not one atomic transaction. A production workflow needs provider idempotency plus one of authorization-then-capture, compensation/refund, reconciliation, or a durable saga. The outbox solves database-state-to-message publication; it does not make an earlier payment call atomic with the database.

### Detailed answer key

1. If clients expect width and height setters to change independently, forcing them equal changes the base contract. A function that sets width and height and expects the requested area behaves incorrectly for `Square`. Model separate immutable shapes or depend on an area abstraction whose contract both satisfy.
2. An interface helps at a genuine boundary with alternative implementations, independent testing, plugin/provider variation, or dependency direction. It is noise when it merely mirrors a stable class and adds navigation without isolating change. Extract based on a consumer-shaped contract, not reflex.
3. Strategy is useful for stateful/configurable interchangeable policies selected at runtime. Template Method shares a fixed algorithm skeleton via inheritance but couples subclasses to a base lifecycle. A function/delegate is simpler for small stateless variation. Start with the smallest mechanism that preserves naming/testability.
4. `IQueryable` lets consumers compose provider-specific expressions, leaking translation, performance, and lifetime behavior outside the repository. Prefer application queries/specifications or return read models for meaningful use cases. Sometimes exposing the EF query in a data-access layer is honest—do not hide it behind a dishonest generic repository.
5. Apply cross-cutting decorators around an application port at the composition root. Ordering changes semantics: authorization before cache prevents data leakage; retry inside a timeout differs from timeout per attempt; metrics outside retry measures user latency while inner metrics measure attempts.
6. A factory hierarchy for one constructor, visitor for a stable two-type structure, or mediator for every local method call can increase indirection and obscure behavior. Patterns are justified by forces and change, not interview recognition.

### Production and failure checks

- Identify the owner of each invariant, transaction, external side effect, and retry.
- Test decorator ordering, lifetimes, and composition-root resolution.
- Keep domain/application code free from provider SDK construction and service location.
- Make expected business failures explicit and preserve unexpected exceptions.
- Review pattern cost: files, indirection, runtime allocation, debugging, and onboarding.

### Build/debug task

Refactor a tightly coupled checkout into domain, application, and infrastructure layers. Add a payment fake, repository contract test, outbox integration test, composition-root test, and failure matrix for decline, timeout, duplicate request, database failure after charge, and notification outage.

---

## Module 3. Collections, Generics, LINQ, and Query Semantics

### Concept map

- Choose a collection from access pattern, mutation, ordering, uniqueness, and concurrency—not habit.
- Generic constraints express capabilities and prevent invalid type use.
- `IEnumerable<T>` LINQ is in-process iteration; `IQueryable<T>` builds an expression for a provider.
- Many LINQ operators are deferred; multiple enumeration can repeat work or observe changed state.
- Materialization defines a boundary in time and memory.
- Equality/comparer choice controls dictionaries, sets, grouping, distinctness, and joins.

### Questions

1. Compare `List<T>`, `HashSet<T>`, `Dictionary<TKey,TValue>`, `Queue<T>`, `Stack<T>`, and `ConcurrentDictionary` for their intended operations and hidden costs.
2. Why can calling `Count()`, then iterating an `IEnumerable<T>` execute a database/network query twice?
3. What changes when a LINQ predicate moves from `IQueryable<T>` to `IEnumerable<T>`?
4. When should a generic method constrain `T` to `class`, `struct`, `notnull`, `new()`, an interface, or a base type?
5. Explain the difference between `Select` and `SelectMany`, and give a case where flattening loses required parent context.
6. Why can using a mutable object as a `Dictionary` key make the entry appear to disappear?

### Wrong/before code

```csharp
public async Task<IReadOnlyList<OrderDto>> GetOpenOrdersAsync()
{
    var orders = _db.Orders
        .Include(o => o.Items)
        .AsEnumerable() // switches to in-memory execution too early
        .Where(o => ExpensiveLocalRule(o) && o.Status == OrderStatus.Open)
        .OrderByDescending(o => o.CreatedAt)
        .Take(50)
        .Select(MapWithMoreDatabaseLookups)
        .ToList();

    return orders;
}
```

### Corrected/after code

```csharp
public Task<List<OrderDto>> GetOpenOrdersAsync(
    Guid tenantId,
    CancellationToken cancellationToken) =>
    _db.Orders
        .AsNoTracking()
        .Where(o => o.TenantId == tenantId && o.Status == OrderStatus.Open)
        .OrderByDescending(o => o.CreatedAt)
        .ThenByDescending(o => o.Id)
        .Select(o => new OrderDto(
            o.Id,
            o.CreatedAt,
            o.Items.Count,
            o.Items.Sum(i => i.Quantity * i.UnitPrice)))
        .Take(50)
        .ToListAsync(cancellationToken);
```

If `ExpensiveLocalRule` is truly required, first retrieve a bounded SQL-filtered candidate set and document that the final limit applies after the local rule.

### Detailed answer key

1. `List` gives indexed contiguous storage and cheap append but linear membership/removal. `HashSet` gives average constant-time uniqueness/membership but no index/order guarantee. `Dictionary` maps unique keys to values. Queue/stack encode FIFO/LIFO intent. Concurrent collections make selected operations thread-safe but compound workflows still need atomic APIs. Memory, hashing, resizing, comparer cost, and iteration behavior matter.
2. `IEnumerable` is a recipe until materialized. A database iterator, generator, or network-backed sequence can repeat its source each enumeration. Materialize once when you need a stable snapshot, or expose a collection/async stream contract that makes behavior clear.
3. `IQueryable` expression trees can be translated and executed remotely. `AsEnumerable` changes subsequent operators to .NET code, potentially transferring far more data and using different null/string/date semantics. Inspect generated SQL and place the boundary deliberately.
4. Constraints let the compiler expose valid operations and communicate intent. `notnull` is valuable for dictionary keys; interface/base constraints express behavior; `new()` is often a sign construction should be injected or delegated to a factory. Choose only constraints required by the algorithm.
5. `Select` maps one item to one result; `SelectMany` maps and flattens nested sequences. Flattening orders to items can lose order-level identity unless the projection carries it: `orders.SelectMany(o => o.Items, (o,i) => new { o.Id, Item=i })`.
6. A dictionary stores the hash bucket computed at insertion. If equality/hash fields mutate, lookup computes another bucket and cannot find the entry. Use immutable keys with stable, consistent equality/hash codes.

### Production and failure checks

- Review deferred execution and enumerate external/expensive sequences only intentionally.
- Inspect SQL/provider translation and keep filtering/projection server-side where appropriate.
- Bound materialization; avoid loading an entire table or unbounded stream.
- Use deterministic ordering with a unique tie-breaker before `Take`, paging, or cursors.
- Benchmark hot collection operations and custom comparers with representative sizes.
- For concurrency, use atomic collection operations such as `GetOrAdd` while remembering the value factory may run more than once.

### Build/debug task

Create a benchmark/test project that compares membership lookup in a list and hash set, demonstrates a mutable-key dictionary failure, proves multiple enumeration, inspects an EF query before/after `AsEnumerable`, and implements stable keyset pagination with a unique composite cursor.

---

## Module 4. Async, Concurrency, Memory, and Garbage Collection

### Concept map

- `async` improves scalability for waiting; it does not make CPU work faster.
- A `Task` represents completion, not necessarily a new thread.
- Cancellation is cooperative and must flow through every cancellable wait.
- Parallelism, concurrency, batching, and asynchronous I/O solve different problems.
- Shared mutable state needs an atomic operation or synchronization boundary.
- GC generations optimize common object lifetimes; allocation rate, retention, pinning, finalization, and the large-object heap affect pauses and memory.

### Questions

1. Why can `.Result` or `.Wait()` deadlock in a context-bound application and still harm ASP.NET Core when no synchronization-context deadlock occurs?
2. When should `Task.WhenAll`, `Parallel.ForEachAsync`, a bounded channel, or sequential processing be used?
3. Why is `ConcurrentDictionary<TKey,TValue>` insufficient for a multi-step read-modify-write sequence?
4. Explain thread-pool starvation, and distinguish it from a slow database.
5. What creates memory pressure even when GC eventually collects objects?
6. When are `Span<T>`, pooling, `ValueTask<T>`, and `IAsyncEnumerable<T>` useful, and what misuse makes each worse?

### Wrong/before code

```csharp
public async Task<IReadOnlyList<Result>> ProcessAsync(
    IEnumerable<Job> jobs,
    CancellationToken cancellationToken)
{
    // Starts every operation at once; ignores cancellation downstream.
    var tasks = jobs.Select(job => Task.Run(() =>
        _client.CallAsync(job, CancellationToken.None).Result));

    return await Task.WhenAll(tasks);
}
```

### Corrected/after code

```csharp
public async Task<IReadOnlyList<Result>> ProcessAsync(
    IReadOnlyList<Job> jobs,
    CancellationToken cancellationToken)
{
    var results = new Result[jobs.Count];

    await Parallel.ForEachAsync(
        Enumerable.Range(0, jobs.Count),
        new ParallelOptions
        {
            MaxDegreeOfParallelism = 8,
            CancellationToken = cancellationToken
        },
        async (index, ct) =>
        {
            results[index] = await _client.CallAsync(jobs[index], ct);
        });

    return results;
}
```

For sustained producer/consumer workloads, a bounded `Channel<Job>` with a fixed worker set usually expresses backpressure more clearly.

### Detailed answer key

1. Blocking waits can hold a context/thread needed by the continuation. ASP.NET Core normally lacks that classic context, but blocking still consumes a thread while I/O waits, causing starvation and tail latency. Keep the call path async and avoid wrapping naturally asynchronous I/O in `Task.Run`.
2. `WhenAll` fits a small known set of independent operations when fan-out is safely bounded. `Parallel.ForEachAsync` bounds a finite concurrent loop. A bounded channel fits sustained flow and backpressure. Sequential work is correct when ordering, one resource, rate limits, or transaction semantics require it.
3. Individual methods are thread-safe; `TryGetValue`, calculate, then assignment is not one atomic action. Use `AddOrUpdate`, locks, immutable snapshots, or another atomic ownership design. `GetOrAdd` factories may execute more than once, so side effects inside them are unsafe.
4. Starvation occurs when queued work cannot obtain pool threads because threads block or CPU work monopolizes them; queue length rises and unrelated operations delay. A slow DB shows dependency wait/latency. Traces, pool counters, CPU, and dependency spans distinguish them.
5. High allocation throughput increases GC work; promoted/retained objects enlarge heaps; large objects and pinning complicate compaction; finalizers delay reclamation; caches/leaks retain graphs. “Collectable eventually” is not the same as sustainable.
6. `Span` fits synchronous stack/scoped parsing and cannot cross async boundaries. Pooling helps expensive/high-rate buffers but requires clearing/return ownership. `ValueTask` helps measured frequently synchronous paths but has consumption constraints. Async streams fit incremental I/O, but consumers must cancel/dispose and producers must respect backpressure.

### Production and failure checks

- Propagate cancellation and deadlines; distinguish user cancellation from dependency timeout.
- Bound fan-out, queues, buffers, and retry concurrency.
- Track thread-pool queue/thread count, allocation rate, GC pause/time, heap sizes, LOH, and retained objects.
- Do not place irreversible side effects inside factories that may run multiple times.
- Test slow consumer, cancellation mid-operation, dependency timeout, partial completion, and shutdown drain.
- Profile before adding pooling or `ValueTask`; complexity without a hot allocation path is negative value.

### Build/debug task

Build a bounded background processor with `Channel<T>`, a configurable worker limit (start with eight only as a test hypothesis), graceful shutdown, cancellation, retry classification, and per-job idempotency. Load-test an unbounded implementation and the bounded implementation; compare memory, thread-pool queue, throughput, p99 latency, rejected/backpressured work, and shutdown correctness. Choose the final worker count from dependency capacity and measurements.

---

## Module 5. ASP.NET Core Pipeline, Configuration, and Dependency Injection

### Concept map

- Middleware order defines security, routing, exception, caching, and endpoint behavior.
- The DI container is a composition mechanism; application code should not locate services dynamically.
- Singleton, scoped, and transient lifetimes must match state and dependency graphs.
- Options bind configuration, but validation and reload semantics must be deliberate.
- Request cancellation is exposed through `HttpContext.RequestAborted` and endpoint tokens.
- Health, readiness, startup, and liveness answer different operational questions.

### Questions

1. Why should exception handling, forwarded headers, HTTPS, routing, authentication, authorization, rate limiting, caching, and endpoints be ordered intentionally?
2. What fails when a singleton captures a scoped `DbContext` or request-specific service?
3. Compare constructor injection, method injection, keyed services/factories, and service location.
4. When should `IOptions<T>`, `IOptionsSnapshot<T>`, and `IOptionsMonitor<T>` be used? What does reload not guarantee?
5. How should startup/readiness/liveness checks treat database or third-party outages?
6. Where do correlation IDs and distributed trace context enter and leave the pipeline?

### Wrong/before code

```csharp
builder.Services.AddSingleton<OrderService>();
builder.Services.AddDbContext<AppDbContext>();

public sealed class OrderService
{
    public OrderService(IServiceProvider services) => _services = services;

    public async Task<Order> Get(Guid id)
    {
        var db = _services.GetRequiredService<AppDbContext>();
        return await db.Orders.FindAsync(id)
            ?? throw new Exception("Not found");
    }
}
```

### Corrected/after code

```csharp
builder.Services
    .AddOptions<PaymentsOptions>()
    .BindConfiguration("Payments")
    .ValidateDataAnnotations()
    .Validate(o => Uri.TryCreate(o.BaseUrl, UriKind.Absolute, out _), "Invalid URL")
    .ValidateOnStart();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Orders")));
builder.Services.AddScoped<IOrderQueries, EfOrderQueries>();

public sealed class EfOrderQueries(AppDbContext db) : IOrderQueries
{
    public Task<OrderDto?> FindAsync(Guid id, CancellationToken cancellationToken) =>
        db.Orders.AsNoTracking()
            .Where(o => o.Id == id)
            .Select(o => new OrderDto(o.Id, o.Status, o.Total))
            .SingleOrDefaultAsync(cancellationToken);
}
```

### Detailed answer key

1. Exception handling must wrap downstream failures; forwarded headers must run before scheme/host decisions; authentication establishes identity before authorization; rate limiting/cache behavior may depend on route/user; endpoints terminate the pipeline. Exact order depends on the app, but accidental order can bypass policy or cache private data.
2. The scoped dependency may be resolved from the root, rejected by validation, reused across concurrent requests, or outlive/dispose incorrectly. A singleton can depend only on singleton-safe collaborators; use a scope factory only for infrastructure-owned work with an explicit scope per operation.
3. Constructor injection fits required stable collaborators. Method parameters fit request/runtime data or optional framework services. Keyed/factory selection fits true runtime implementation choice. Service location hides dependencies, moves failure to runtime, and should remain confined to composition/framework adapter code.
4. `IOptions` is singleton-style initial value; `Snapshot` recomputes per scope/request; `Monitor` supports change notifications/current value. Reload does not make every downstream client atomically switch, validate remote secrets, or make a partially applied multi-setting change safe.
5. Startup confirms initialization; readiness controls new traffic; liveness asks whether restart can help. Marking liveness unhealthy because a database is down can restart every healthy app instance and worsen an outage. Readiness/degraded status and dependency-specific alerts are safer.
6. Accept standards-based trace context at ingress, start/continue an activity, attach bounded business attributes, propagate context on outgoing calls/messages, and return correlation where appropriate. Do not invent IDs that break trace linkage or log secrets/high-cardinality payloads.

### Production and failure checks

- Enable scope/build validation and test that every endpoint graph resolves.
- Validate required configuration on startup without logging secrets.
- Test middleware ordering for unauthorized, exception, CORS, rate-limited, cached, and missing-route cases.
- Give background services explicit scopes and graceful stop behavior.
- Propagate cancellation and trace context through HTTP, database, and messaging clients.
- Separate liveness from readiness and rehearse dependency failure without restart storms.

### Build/debug task

Create a minimal API with validated options, scoped EF access, authentication/authorization, global problem-details handling, rate limiting, tracing, readiness/liveness endpoints, and a background worker with explicit scopes. Write integration tests that prove middleware ordering and lifetime validation.

---

## Module 6. MVC, API Contracts, Authentication, Authorization, and Errors

### Concept map

- HTTP method, status, headers, representation, and idempotency form an API contract.
- Authentication establishes identity; authorization evaluates permission for this resource/action.
- Resource ownership must be enforced in the query or policy, not inferred from a valid token.
- Validation, conflict, not-found, throttling, and unexpected failure need stable machine-readable errors.
- Offset, cursor, and keyset pagination serve different navigation and consistency needs.
- Versioning and compatibility include fields, enum values, behavior, errors, and event schemas.

### Questions

1. Design status/error contracts for create success, validation, duplicate idempotency key with different payload, missing resource, stale version, and overload.
2. Why does `[Authorize]` not prevent IDOR/BOLA when loading `/orders/{id}`?
3. Compare roles, claims, policies, and resource-based authorization.
4. When are `PUT`, `PATCH`, and `POST` idempotent or non-idempotent? How does an idempotency key help?
5. Why can offset pagination duplicate/skip records, and what does a composite keyset cursor contain?
6. What changes are backward-compatible for JSON clients, and why can adding an enum member still break them?

### Wrong/before code

```csharp
[Authorize]
[HttpGet("orders/{id:guid}")]
public async Task<IActionResult> Get(Guid id)
{
    var order = await _db.Orders.FindAsync(id);
    return order is null ? NotFound() : Ok(order); // any signed-in user can read it
}
```

### Corrected/after code

```csharp
[Authorize]
[HttpGet("orders/{id:guid}")]
public async Task<ActionResult<OrderDto>> Get(
    Guid id,
    CancellationToken cancellationToken)
{
    var userId = User.GetRequiredSubject();

    var order = await _db.Orders
        .AsNoTracking()
        .Where(o => o.Id == id && o.CustomerId == userId)
        .Select(o => new OrderDto(o.Id, o.Status, o.Total, o.Version))
        .SingleOrDefaultAsync(cancellationToken);

    // Avoid revealing another tenant/user's resource existence.
    return order is null ? NotFound() : Ok(order);
}
```

### Detailed answer key

1. A common design uses `201` plus location for created, `400/422` typed field errors for invalid input, `409` for idempotency-key reuse with a different request, `412 Precondition Failed` when an `If-Match`/ETag precondition is stale (or a documented `409` for a domain conflict), `404` for inaccessible/missing resources, and `429/503` with retry guidance for controlled overload. Exact choices matter less than documented stable semantics and no sensitive details.
2. `[Authorize]` verifies an authenticated principal/policy, not ownership of arbitrary `id`. Filter by tenant/owner in the query or use resource authorization after safe load. Test cross-tenant IDs explicitly.
3. Roles are coarse organizational groupings; claims are asserted facts; policies compose requirements; resource-based authorization evaluates principal + operation + concrete resource. Avoid putting rapidly changing permissions into long-lived tokens without revocation/version strategy.
4. `PUT` is intended to replace/set a resource idempotently; PATCH can be idempotent depending on operation; POST often creates/actions and is not naturally idempotent. A scoped key stores request fingerprint and final result atomically so retries replay and mismatched reuse conflicts.
5. Inserts/deletes shift row positions between requests, and deep offsets scan/discard earlier rows. A cursor contains the last ordered values including a unique tie-breaker, such as `(CreatedAt, Id)`, plus signed/encoded filter/sort/version context.
6. Ignoring unknown optional fields can make additions compatible, but strict clients, generated enums, validation, and exhaustive switches may break. Contract tests and tolerant-reader rules must be explicit; never reuse field meanings.

### Production and failure checks

- Threat-test every object identifier across users/tenants and enforce server-side authorization.
- Return one problem-details shape with stable codes, correlation, safe detail, and field errors.
- Store idempotency state and business mutation consistently; define in-progress/retry/expiry behavior.
- Sign/validate cursors and bind them to filters/sort/tenant.
- Cap request/page sizes, timeouts, and expensive query features.
- Maintain consumer/contract tests for compatibility and security regressions.

### Build/debug task

Build an order API with idempotent create, ownership-safe reads, optimistic update using ETag/version, keyset pagination, problem details, policy authorization, and rate limits. Add cross-tenant, retry-after-timeout, conflicting-key, concurrent-update, cursor-tamper, and unknown-enum contract tests.

---

## Module 7. Entity Framework Core and Data Access

### Concept map

- `DbContext` is a scoped unit of work/change tracker, not a singleton repository.
- DTO projection reduces data transfer; entity-returning read queries often use `AsNoTracking` to avoid unnecessary change tracking.
- Includes, split queries, explicit loading, and projections have different round-trip/cartesian behavior.
- Transactions protect database state, while an outbox connects commit to asynchronous publication.
- Optimistic concurrency detects conflicting writes; retry requires rereading and applying a merge policy.
- Indexes follow filters, joins, ordering, selectivity, and write cost—not entity property lists.

### Questions

1. Why is returning EF entities directly from an API risky even when serialization works?
2. Explain N+1, cartesian explosion, split queries, and projection. Which is best for a summary endpoint?
3. Why does `SaveChanges` not make a later message-broker publish atomic?
4. How should a `DbUpdateConcurrencyException` be handled for a user-edited record?
5. Compare tracked, no-tracking, and no-tracking-with-identity-resolution queries.
6. Why can adding `AsEnumerable` or a non-translatable method cause a large performance regression?

### Wrong/before code

```csharp
public async Task<IReadOnlyList<Order>> GetOrders(Guid customerId)
{
    var orders = await _db.Orders
        .Where(o => o.CustomerId == customerId)
        .ToListAsync();

    foreach (var order in orders)
        order.Items = await _db.OrderItems.Where(i => i.OrderId == order.Id).ToListAsync();

    return orders;
}
```

### Corrected/after code

```csharp
public Task<List<OrderSummary>> GetOrdersAsync(
    Guid customerId,
    int take,
    CancellationToken cancellationToken) =>
    _db.Orders
        .AsNoTracking()
        .Where(o => o.CustomerId == customerId)
        .OrderByDescending(o => o.CreatedAt)
        .ThenByDescending(o => o.Id)
        .Select(o => new OrderSummary(
            o.Id,
            o.CreatedAt,
            o.Status,
            o.Items.Count,
            o.Items.Sum(i => i.Quantity * i.UnitPrice)))
        .Take(take)
        .ToListAsync(cancellationToken);
```

### Detailed answer key

1. Entities expose persistence shape/navigation cycles, over-posting, lazy loading, internal fields, tracking/mutation, and accidental breaking changes. Project to request/response models and enforce invariants in domain/application code.
2. N+1 sends one query plus per-parent queries. Multiple collection includes can multiply rows. Split queries trade cartesian growth for more round trips/consistency considerations. A summary endpoint normally uses one server-side DTO projection with aggregates.
3. The database transaction cannot atomically commit a separate broker. Save domain state plus an outbox row in one DB transaction, then a retriable idempotent publisher sends and marks it. Consumers must handle duplicate delivery.
4. Catch at the application boundary, reload current values/version, then reject with conflict, show differences, or reapply a documented merge and retry with a bound. Blind retry can overwrite another user's change.
5. Tracking supports updates/identity map but consumes memory. For DTO-only projections EF normally does not track an entity instance, so projection is the important optimization; `AsNoTracking` matters most when returning entity instances or mixed projections containing them. Identity resolution avoids duplicate entity instances in one no-tracking result at extra cost. Measure and choose from behavior.
6. Provider translation stops, so remaining filters/ordering may execute in memory after transferring rows. Modern EF rejects many unsupported expressions, but an explicit boundary still changes semantics. Inspect generated SQL and query plans.

### Production and failure checks

- Log/inspect generated SQL without sensitive parameters; detect high query count and slow plans.
- Use cancellation, command timeouts, bounded result sets, and deterministic pagination.
- Keep transactions short and avoid remote calls while holding them.
- Test concurrency, transient failure, unique constraints, deadlocks, and outbox duplicate publication.
- Design indexes from real query predicates/order and monitor their write/storage cost.
- Rehearse migrations with backward-compatible rollout, large-table strategy, and rollback/forward-fix.

### Build/debug task

Implement an order write with optimistic concurrency and an outbox, plus a projected keyset-paged read. Add integration tests against a real database for unique races, two concurrent editors, rollback, publisher crash before/after send, duplicate consumer delivery, generated SQL shape, and index-supported query plan.

---

## Module 8. Backend and Distributed-System Patterns

### Concept map

- Idempotency controls repeated commands; deduplication does not mean exactly-once infrastructure.
- Retry, timeout, circuit breaker, bulkhead, rate limit, and load shedding solve different failure modes and must be ordered deliberately.
- Outbox/inbox connect local transactions to at-least-once messaging.
- Saga orchestration/choreography coordinate multi-service work with compensations, not distributed rollback magic.
- Cache-aside improves reads but introduces staleness, stampede, and invalidation ownership.
- CQRS/read models, event sourcing, and microservices are costly choices justified by explicit needs.

### Questions

1. Explain why a timeout leaves the caller uncertain and why immediate retry can duplicate a payment.
2. Compare retry, circuit breaker, bulkhead, rate limit, and load shedding using one overloaded dependency.
3. What invariant does an outbox protect, and what failures still produce duplicate messages?
4. When is a saga compensation not a true rollback?
5. Design cache-aside behavior for a hot product when the cache expires under load.
6. When should a modular monolith remain a monolith instead of becoming microservices?

### Wrong/before code

```csharp
public async Task PlaceAsync(Order order)
{
    await _db.SaveOrderAsync(order);
    await _bus.PublishAsync(new OrderPlaced(order.Id));
    // Crash between calls loses the event; retry may duplicate the order or message.
}
```

### Corrected/after code

```csharp
public async Task<PlaceResult> PlaceAsync(
    PlaceOrder command,
    CancellationToken cancellationToken)
{
    var requestHash = command.ComputeCanonicalRequestHash();

    await using var transaction = await _db.Database
        .BeginTransactionAsync(cancellationToken);

    var prior = await _db.ProcessedCommands.FindAsync(
        new object[] { command.IdempotencyKey }, cancellationToken);
    if (prior is not null)
    {
        if (!CryptographicOperations.FixedTimeEquals(
                prior.RequestHash,
                requestHash))
            return PlaceResult.IdempotencyConflict();

        return PlaceResult.Replay(prior.ResourceId);
    }

    var order = Order.Place(command.CustomerId, command.Items);
    _db.Orders.Add(order);
    _db.Outbox.Add(OutboxMessage.From(new OrderPlaced(order.Id)));
    _db.ProcessedCommands.Add(new(command.IdempotencyKey, requestHash, order.Id));

    try
    {
        // ProcessedCommands.IdempotencyKey has a named UNIQUE constraint.
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return PlaceResult.Created(order.Id);
    }
    catch (DbUpdateException exception)
        when (IsIdempotencyKeyConstraint(exception))
    {
        // A concurrent first attempt won. The failed transaction/context state
        // must not be reused as though its pending entities were committed.
        await transaction.RollbackAsync(cancellationToken);
        _db.ChangeTracker.Clear();

        var winner = await _db.ProcessedCommands
            .AsNoTracking()
            .SingleAsync(
                x => x.IdempotencyKey == command.IdempotencyKey,
                cancellationToken);

        return StringComparer.Ordinal.Equals(winner.RequestHash, requestHash)
            ? PlaceResult.Replay(winner.ResourceId)
            : PlaceResult.IdempotencyConflict();
    }
}
```

An outbox worker leases unpublished rows, publishes with a message ID, and marks success. A consumer inbox/idempotent effect handles redelivery.

### Detailed answer key

1. The caller cannot know whether the server committed before the response was lost. Retry with a stable, operation-scoped idempotency key and a canonical request fingerprint; the server atomically records the first result with the mutation, replays an identical request, and rejects mismatched reuse. A database unique constraint is the final authority for concurrent first attempts, and provider-side payment idempotency is also required.
2. Retry handles transient failure and consumes more load; timeout bounds waiting; circuit breaker stops likely-failing calls; bulkhead limits one dependency/workload's concurrency; rate limit controls admitted rate/fairness; load shedding rejects when capacity is exhausted. Combine from a shared latency/retry budget and measure attempts.
3. State change and intent-to-publish commit together. Publisher crash before marking sent causes redelivery; broker acknowledgement ambiguity also duplicates. Therefore message IDs and idempotent consumers remain required.
4. Sending a refund, releasing inventory, or cancelling a reservation is a new business action with its own failures and may not erase external observation or fees. Model states, deadlines, retries, manual repair, and semantic compensation.
5. Use bounded TTL with jitter, single-flight/request coalescing, stale-while-revalidate where acceptable, negative-cache caution, and a database capacity fallback. Hot-key replication/local cache may help. Track item age and origin load, not hit ratio alone.
6. Keep a modular monolith when one team/release/data transaction and scale profile fit, boundaries are still evolving, and operational overhead outweighs isolation. Split only for independently owned/deployed/scaled/reliability boundaries with measurable pain.

### Production and failure checks

- Give every external command/message a stable identity and define retention/reuse behavior.
- Back idempotency keys with a unique constraint and test simultaneous first attempts, fingerprint mismatch, in-progress state, expiry, and replay after a lost response.
- Bound attempts, elapsed time, concurrency, and total work; retries must respect deadlines and `Retry-After`.
- Test crash at every boundary: before/after DB commit, publish, broker ack, consumer effect, and inbox mark.
- Monitor outbox/inbox age, queue lag, attempts, poison messages, circuit state, shed/rejected load, and compensation backlog.
- Document weaker consistency and user-visible intermediate states.
- Keep a repair/reconciliation path for states automation cannot safely resolve.

### Build/debug task

Build a small order workflow with idempotent HTTP command, outbox publisher, duplicate-safe consumer, inventory/payment saga states, cache-aside product read with stampede protection, and resilience policies. Run a deterministic failure matrix covering every commit/ack boundary and prove final invariants.

---

## Module 9. Testing Strategy and Testable Design

### Concept map

- Test behavior at the cheapest boundary that can falsify the risk.
- Unit tests isolate policy; integration tests verify adapters/contracts; end-to-end tests prove a few critical journeys.
- Mocks verify collaboration but can encode implementation; fakes model controlled behavior; real dependencies catch translation/protocol differences.
- Deterministic time, randomness, IDs, concurrency, and retries make failures reproducible.
- Property, contract, mutation, load, resilience, and security tests reveal different defect classes.
- Coverage is evidence of execution, not proof of useful assertions.

### Questions

1. Which tests should verify a discount rule, EF translation, authentication middleware, broker redelivery, and full checkout?
2. Why is mocking `DbSet` or LINQ-to-Objects a weak substitute for a real database integration test?
3. How should time, random IDs, and retry delays be controlled without adding test-only branches to production behavior?
4. What makes a test flaky, and why is retrying the test an incomplete fix?
5. When are property-based and mutation testing more informative than more example tests?
6. How do consumer-driven contracts help and what can they not prove?

### Wrong/before code

```csharp
[Fact]
public async Task Places_order()
{
    var repository = new Mock<IOrderRepository>();
    var service = new OrderService(repository.Object, new Mock<IPayment>().Object);

    await service.PlaceAsync(new Order());

    repository.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Once);
}
```

This may pass when the order is invalid, payment failed, transaction/outbox is wrong, or observable behavior is broken.

### Corrected/after code

```csharp
[Fact]
public async Task Accepted_checkout_persists_order_and_outbox_atomically()
{
    await using var app = await TestApplication.StartAsync(database: RealTestDatabase.Create());
    app.Payments.Accept("payment-key-1", reference: "charge-42");

    var response = await app.Client.PostAsJsonAsync("/orders", new
    {
        idempotencyKey = "checkout-123",
        customerId = TestIds.Customer,
        items = new[] { new { productId = TestIds.Product, quantity = 2 } }
    });

    response.StatusCode.Should().Be(HttpStatusCode.Created);
    var order = await app.Database.SingleOrderAsync();
    var message = await app.Database.SingleOutboxAsync();
    message.AggregateId.Should().Be(order.Id);
}
```

The test host keeps the outbox publisher stopped while asserting the committed row; otherwise a real background publisher could legitimately race the assertion and make the test flaky.

### Detailed answer key

1. Discount rule: unit/property tests. EF translation/index behavior: real DB integration. Authentication/middleware: in-process HTTP integration. Broker redelivery: adapter/consumer integration with broker-compatible semantics. Checkout: a few E2E/vertical-slice tests plus focused failure integration tests.
2. LINQ providers differ in translation, null/collation/date semantics, constraints, transactions, concurrency, and performance. Use a real target database/container or high-fidelity environment for those claims.
3. Inject `TimeProvider`, an ID/random abstraction where behavior depends on it, and a delay/retry scheduler/policy that can be advanced or configured. Keep production semantics; tests control inputs and clocks.
4. Shared state, real time, nondeterministic scheduling, unbounded waits, order dependence, external instability, and incomplete cleanup cause flakiness. Quarantine/retry may reduce noise but root cause must be isolated and made observable.
5. Property tests explore broad input invariants; mutation tests reveal assertions that do not detect changed logic. They are valuable for parsers, money, state machines, algorithms, and critical policy.
6. Contracts verify provider/consumer message/HTTP compatibility for recorded expectations. They do not prove deployment, network, data correctness, authorization, performance, or end-to-end business behavior.

### Production and failure checks

- Name tests by behavior and make failure output explain the invariant.
- Keep unit tests fast and integration environments reproducible/isolated.
- Assert results/state, not every internal call, unless collaboration order is the contract.
- Test cancellation, timeout, duplicate, concurrency, partial failure, restart/replay, and migration compatibility.
- Track flaky tests and time-to-signal; never normalize rerun-until-green.
- Redact secrets/PII in fixtures and logs; test authorization with cross-tenant cases.

### Build/debug task

Create a test pyramid for the order workflow: policy unit/property tests, payment contract tests, real SQL integration, HTTP authorization/error tests, outbox/broker redelivery tests, one E2E journey, load smoke, and chaos cases. Introduce three bugs and prove the intended layer catches each.

---

## Module 10. Performance, Observability, Reliability, and Operations

### Concept map

- Performance is workload plus SLO; averages and microbenchmarks alone are insufficient.
- Measure latency distribution, throughput/goodput, errors, saturation, allocation, dependency time, and cost.
- Logs, metrics, and traces answer different questions and need correlation plus bounded cardinality.
- Reliability requires timeouts, backpressure, graceful shutdown, safe rollout, rollback, and capacity headroom.
- Profiling identifies CPU, allocation, lock, I/O, database, and network bottlenecks before optimization.
- Operational readiness includes ownership, dashboards, alerts, runbooks, recovery, and post-incident learning.

### Questions

1. A service averages 80 ms but p99 is 8 seconds. Why is average latency misleading, and what slices should be inspected?
2. Compare structured logs, metrics, distributed traces, profiles, and audit logs.
3. Why are user ID, request ID, raw URL, or exception message dangerous metric labels?
4. What is coordinated omission in load testing, and how do open-loop tests expose overload?
5. How should readiness, graceful drain, canary, rollback, and database migration interact during deployment?
6. Why can optimizing allocation or adding caching worsen correctness or tail latency?

### Wrong/before code

```csharp
app.MapGet("/report", async (
    AppDbContext db,
    ILogger<Program> logger,
    HttpContext http) =>
{
    var allRows = await db.Events.ToListAsync(http.RequestAborted);
    logger.LogInformation(
        $"Loaded {allRows.Count} events for {http.User.Identity?.Name}");
    return allRows.GroupBy(x => x.Category).Select(BuildReport);
});
```

This loads unbounded tracked rows, captures scoped state incorrectly, interpolates/logs personal data, has no cancellation/pagination/timeout, and mixes reporting with the request path.

### Corrected/after code

```csharp
app.MapPost("/reports", async (
    CreateReport request,
    IReportJobs jobs,
    HttpContext http,
    CancellationToken cancellationToken) =>
{
    // ASP.NET Core already creates a server Activity for the request.
    Activity.Current?.SetTag("report.type", request.Type);

    var idempotencyKey = http.Request.Headers["Idempotency-Key"].ToString();
    if (string.IsNullOrWhiteSpace(idempotencyKey))
        return Results.BadRequest(new { code = "idempotency_key_required" });

    var result = await jobs.EnqueueAsync(
        principalId: http.User.GetRequiredSubject(),
        idempotencyKey: idempotencyKey,
        request: request,
        cancellationToken: cancellationToken);

    return Results.Accepted($"/reports/{result.JobId}", new
    {
        result.JobId,
        status = "pending"
    });
});
```

The background path uses bounded workers, server-side aggregation, durable state, idempotency, progress, and expiry for generated artifacts.

### Detailed answer key

1. A small slow cohort can be hidden by many fast calls. Inspect endpoint, status/error, dependency, payload/row/token size, tenant/priority, instance/zone/version, cache hit, GC, and queue-time slices. Correlate traces rather than creating unbounded metric labels.
2. Logs explain discrete events with context; metrics show aggregate trends/SLOs; traces connect latency across components; profiles sample CPU/allocation/locks; audit logs are protected immutable records of sensitive actions. One does not replace the others.
3. They create unbounded cardinality, memory/cost/query problems, and data leakage. Use bounded route/error/category labels; put request-specific identifiers in sampled traces/logs with access/retention controls.
4. Closed-loop clients wait before sending again, reducing offered load when the server slows and hiding queueing. Open-loop arrival continues independently and reveals the saturation knee, rejections, and tail growth.
5. Deploy backward-compatible schema first, then mixed-version-safe code. New instances complete startup/warm-up before readiness. Canary with SLO/business gates. On drain stop admission and finish/cancel bounded work. Rollback must remain compatible with current schema/data or use forward fix.
6. Pools/caches retain memory and require ownership; caching can serve stale/private data and cause stampedes; micro-optimizations add complexity; batching raises queue latency. Measure end-to-end correctness, p99, memory, and cost after every change.

### Production and failure checks

- Define SLI/SLO and error-budget alerts; avoid alerting on every noisy resource metric.
- Load-test realistic distributions, bursts, failures, and retries to find safe headroom.
- Propagate trace/deadline/cancellation across HTTP, DB, messages, and background work.
- Profile CPU, allocation, locks, GC, SQL, and dependencies before changing code.
- Exercise rolling deploy, shutdown, dependency loss, overload, regional failover, backup restore, and rollback.
- Ensure dashboards and runbooks identify an owner and a concrete action.

### Build/debug task

Instrument and load-test one API. Add OpenTelemetry traces/metrics, structured safe logs, SLO dashboard, burn-rate alert, readiness/liveness, backpressure, graceful drain, and a canary plan. Diagnose one injected DB slowdown, thread-pool starvation, memory-retention bug, and retry storm using evidence rather than guesses.

---

## Cumulative .NET Backend Capstone

Build an order-and-fulfilment service that demonstrates the entire workbook:

1. Immutable domain values and explicit state transitions.
2. Application ports with infrastructure selected at the composition root.
3. Idempotent order API with ownership authorization and typed errors.
4. EF Core transaction, optimistic concurrency, outbox, and keyset read model.
5. Bounded background publisher/consumer with retries, inbox, DLQ, and graceful shutdown.
6. Cache-aside catalogue read with stampede protection and freshness policy.
7. Unit, property, contract, integration, authorization, concurrency, and failure tests.
8. Traces, metrics, logs, SLOs, load test, capacity result, deployment, rollback, and recovery note.

### Capstone review questions

1. Which invariant is protected by each transaction, unique constraint, concurrency token, and idempotency key?
2. Where can duplicates occur, and why is every resulting effect safe?
3. What happens if payment succeeds but the request times out before the response?
4. Which queues/pools are bounded, and what user-visible response occurs at capacity?
5. How is cross-tenant access prevented in reads, writes, caches, logs, and messages?
6. Which metrics prove correctness and recovery rather than merely activity?
7. Can the previous application version run after the migration? Can the current version roll back safely?
8. Which design element would you remove first if traffic and organizational needs remain small?

## Completion Standard

You have command of a topic when you can:

- explain the problem and mechanism without notes;
- predict the wrong implementation's failure;
- implement and test the corrected path;
- state trade-offs and a simpler alternative;
- inject timeout, cancellation, concurrency, duplicate, and dependency failure;
- use observable evidence to prove the invariant and operational behavior.

Finishing the reading is not completion. Keep the code, test output, benchmark, trace, and engineering note as evidence.
