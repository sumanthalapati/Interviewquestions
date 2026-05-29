# 🏗️ Low Level Design (LLD) Interview Questions — Complete Guide

> **50+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [SOLID Principles](#1-solid-principles)
2. [Design Patterns — Creational](#2-design-patterns--creational)
3. [Design Patterns — Structural](#3-design-patterns--structural)
4. [Design Patterns — Behavioral](#4-design-patterns--behavioral)
5. [Class Design & OOP](#5-class-design--oop)
6. [Concurrency & Thread Safety](#6-concurrency--thread-safety)
7. [Common LLD Problems](#7-common-lld-problems)

---

# 1. SOLID Principles

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles
> 📚 Deep dive: https://www.digitalocean.com/community/conceptual-articles/s-o-l-i-d-the-first-five-principles-of-object-oriented-design

---

## 1.1 Single Responsibility Principle (SRP)

### Q1. What is SRP and how do you apply it in a .NET class?

**Answer:**
A class should have only one reason to change — one responsibility. If a class handles data access, business logic, AND email sending, any change to any concern requires modifying the class. Split into focused classes: repository for data, service for logic, notifier for communication.

❌ **Wrong — one class does everything: data access, logic, and notification:**
```csharp
public class UserManager {
    private readonly string _connectionString;

    public void Register(string email, string password) {
        // Data access
        using var conn = new SqlConnection(_connectionString);
        conn.Execute("INSERT INTO Users (Email, PasswordHash) VALUES (@e, @p)",
            new { e = email, p = BCrypt.HashPassword(password) });

        // Business logic
        if (!email.Contains("@")) throw new ArgumentException("Invalid email");

        // Email sending
        var smtp = new SmtpClient("smtp.example.com");
        smtp.Send("noreply@app.com", email, "Welcome!", "Thanks for registering.");
    }
}
```

✅ **Correct — three focused classes, each with one reason to change:**
```csharp
public class UserRepository {
    public void Save(User user) { /* only data access */ }
}

public class UserService {
    private readonly UserRepository _repo;
    private readonly IEmailService _email;

    public void Register(string email, string password) {
        if (!IsValidEmail(email)) throw new ArgumentException("Invalid email");
        var user = new User(email, BCrypt.HashPassword(password));
        _repo.Save(user);
        _email.SendWelcome(email);
    }
}

public class EmailService : IEmailService {
    public void SendWelcome(string email) { /* only email logic */ }
}
```

---

## 1.2 Open/Closed Principle (OCP)

### Q2. What is OCP and how does it guide extensible class design?

**Answer:**
Classes should be open for extension but closed for modification. New behavior should be added by adding new code (new classes/implementations), not editing existing tested code. Strategy pattern and polymorphism are the primary tools.

❌ **Wrong — adding a new discount type requires editing existing code:**
```csharp
public class DiscountCalculator {
    public decimal Calculate(string customerType, decimal price) {
        if (customerType == "VIP") return price * 0.8m;
        if (customerType == "Student") return price * 0.9m;
        // Every new customer type = edit this method
        return price;
    }
}
```

✅ **Correct — new discount types extend without touching existing code:**
```csharp
public interface IDiscountStrategy {
    decimal Apply(decimal price);
}

public class VipDiscount : IDiscountStrategy {
    public decimal Apply(decimal price) => price * 0.8m;
}

public class StudentDiscount : IDiscountStrategy {
    public decimal Apply(decimal price) => price * 0.9m;
}

public class DiscountCalculator {
    private readonly IDiscountStrategy _strategy;
    public DiscountCalculator(IDiscountStrategy strategy) => _strategy = strategy;
    public decimal Calculate(decimal price) => _strategy.Apply(price);
}
// New customer type = new class implementing IDiscountStrategy, zero changes elsewhere
```

---

## 1.3 Liskov Substitution Principle (LSP)

### Q3. What is LSP and what does violating it look like?

**Answer:**
Subtypes must be substitutable for their base types without breaking the program. A subclass that throws `NotImplementedException` for an inherited method, or that weakens post-conditions, violates LSP.

❌ **Wrong — Square breaks the Rectangle contract (width/height independence):**
```csharp
public class Rectangle {
    public virtual int Width { get; set; }
    public virtual int Height { get; set; }
    public int Area() => Width * Height;
}

public class Square : Rectangle {
    public override int Width { set { base.Width = base.Height = value; } }  // breaks contract
    public override int Height { set { base.Width = base.Height = value; } }
}

// Caller breaks:
Rectangle r = new Square();
r.Width = 4;
r.Height = 5;
Console.WriteLine(r.Area()); // Expected 20, gets 25 — LSP violated
```

✅ **Correct — use a common abstraction instead of inheritance:**
```csharp
public interface IShape {
    int Area();
}

public class Rectangle : IShape {
    public int Width { get; set; }
    public int Height { get; set; }
    public int Area() => Width * Height;
}

public class Square : IShape {
    public int Side { get; set; }
    public int Area() => Side * Side;
}
// Both honor their own contract — no substitution confusion
```

---

## 1.4 Interface Segregation Principle (ISP)

### Q4. How does ISP guide interface design?

**Answer:**
Clients should not depend on methods they don't use. A fat interface forces implementors to define methods that don't apply to them (usually with `throw new NotImplementedException()`). Split into focused interfaces.

❌ **Wrong — fat interface forces irrelevant implementations:**
```csharp
public interface IWorker {
    void Work();
    void Eat();   // robots don't eat
    void Sleep(); // robots don't sleep
}

public class Robot : IWorker {
    public void Work() { /* real work */ }
    public void Eat() => throw new NotImplementedException();   // forced
    public void Sleep() => throw new NotImplementedException(); // forced
}
```

✅ **Correct — segregated interfaces, implementors pick what applies:**
```csharp
public interface IWorkable  { void Work(); }
public interface IFeedable  { void Eat(); }
public interface ISleepable { void Sleep(); }

public class Human : IWorkable, IFeedable, ISleepable {
    public void Work() { }
    public void Eat() { }
    public void Sleep() { }
}

public class Robot : IWorkable {
    public void Work() { } // only implements what it needs
}
```

---

## 1.5 Dependency Inversion Principle (DIP)

### Q5. What is DIP and how does it enable testability?

**Answer:**
High-level modules should not depend on low-level modules — both should depend on abstractions. Concretely: depend on interfaces, not concrete classes. This allows substituting implementations (mocks for tests, different providers for different environments).

❌ **Wrong — high-level service hardcodes a concrete low-level dependency:**
```csharp
public class OrderService {
    private readonly SqlOrderRepository _repo = new SqlOrderRepository(); // concrete dependency

    public void PlaceOrder(Order order) {
        _repo.Save(order);
        // Can't test OrderService without a real SQL database
        // Can't swap to a different repository without editing OrderService
    }
}
```

✅ **Correct — depend on interface, inject via constructor:**
```csharp
public interface IOrderRepository {
    void Save(Order order);
}

public class OrderService {
    private readonly IOrderRepository _repo;

    public OrderService(IOrderRepository repo) => _repo = repo; // injected

    public void PlaceOrder(Order order) => _repo.Save(order);
    // Unit tests inject a mock IOrderRepository — no SQL required
    // Production registers SqlOrderRepository; tests register MockOrderRepository
}
```

---

# 2. Design Patterns — Creational

> 📚 Reference: https://refactoring.guru/design-patterns/creational-patterns
> 📚 .NET examples: https://dotnettutorials.net/course/dot-net-design-patterns/

---

## 2.1 Singleton Pattern

### Q6. How do you implement a thread-safe Singleton in C#?

**Answer:**
Use `Lazy<T>` for thread-safe lazy initialization without explicit locking. Alternatively, rely on .NET's DI container with `AddSingleton` — the container manages lifecycle. Avoid static mutable singletons — they're untestable and cause hidden global state.

❌ **Wrong — non-thread-safe singleton, double-checked locking done incorrectly:**
```csharp
public class ConfigManager {
    private static ConfigManager? _instance;

    public static ConfigManager Instance {
        get {
            if (_instance == null)
                _instance = new ConfigManager(); // race condition!
            return _instance;
        }
    }
}
```

✅ **Correct — thread-safe with Lazy<T>:**
```csharp
public class ConfigManager {
    private static readonly Lazy<ConfigManager> _lazy =
        new(() => new ConfigManager(), LazyThreadSafetyMode.ExecutionAndPublication);

    public static ConfigManager Instance => _lazy.Value;

    private ConfigManager() { /* load config */ }
}

// Even better in ASP.NET Core: just use DI
builder.Services.AddSingleton<IConfigManager, ConfigManager>();
```

---

## 2.2 Factory Method Pattern

### Q7. When do you use a Factory Method and how is it implemented?

**Answer:**
Use a Factory Method when object creation logic is complex, when the exact type to create depends on runtime data, or when you want to decouple creators from products. The factory method is a virtual/abstract method overridden by subclasses or a static factory method on the class.

❌ **Wrong — caller directly instantiates concrete types based on a condition (fragile, violates OCP):**
```csharp
public ILogger CreateLogger(string type) {
    if (type == "file") return new FileLogger();
    if (type == "db")   return new DatabaseLogger();
    if (type == "console") return new ConsoleLogger();
    throw new ArgumentException("Unknown logger type");
    // Adding a new logger type requires editing this method
}
```

✅ **Correct — factory method with registration:**
```csharp
public interface ILoggerFactory {
    ILogger Create();
}

public class FileLoggerFactory : ILoggerFactory {
    public ILogger Create() => new FileLogger("app.log");
}

public class DatabaseLoggerFactory : ILoggerFactory {
    public ILogger Create() => new DatabaseLogger(connectionString);
}

// Register in DI or a factory registry:
var factories = new Dictionary<string, ILoggerFactory> {
    ["file"]    = new FileLoggerFactory(),
    ["db"]      = new DatabaseLoggerFactory()
};
ILogger logger = factories["file"].Create();
```

---

## 2.3 Builder Pattern

### Q8. When should you use the Builder pattern?

**Answer:**
Use Builder when an object has many optional parameters (avoids telescoping constructors or large parameter objects), or when construction involves multiple steps that must happen in sequence.

❌ **Wrong — telescoping constructors, hard to read call sites:**
```csharp
public class HttpRequest {
    public HttpRequest(string url, string method, Dictionary<string,string> headers,
        string? body, int timeout, bool followRedirects, bool verifySsl) { ... }
}

// Call site is unreadable:
var req = new HttpRequest("https://api.example.com", "POST", headers, body, 30, true, false);
```

✅ **Correct — fluent builder, readable and extensible:**
```csharp
public class HttpRequestBuilder {
    private string _url = "";
    private string _method = "GET";
    private readonly Dictionary<string, string> _headers = new();
    private string? _body;
    private int _timeout = 30;

    public HttpRequestBuilder WithUrl(string url) { _url = url; return this; }
    public HttpRequestBuilder WithMethod(string method) { _method = method; return this; }
    public HttpRequestBuilder WithHeader(string key, string value) { _headers[key] = value; return this; }
    public HttpRequestBuilder WithBody(string body) { _body = body; return this; }
    public HttpRequestBuilder WithTimeout(int seconds) { _timeout = seconds; return this; }

    public HttpRequest Build() => new(_url, _method, _headers, _body, _timeout);
}

var request = new HttpRequestBuilder()
    .WithUrl("https://api.example.com")
    .WithMethod("POST")
    .WithHeader("Authorization", "Bearer token")
    .WithBody("""{"key":"value"}""")
    .Build();
```

---

# 3. Design Patterns — Structural

> 📚 Reference: https://refactoring.guru/design-patterns/structural-patterns

---

## 3.1 Decorator Pattern

### Q9. How does the Decorator pattern enable behavior extension without inheritance?

**Answer:**
A Decorator wraps an object implementing the same interface, adding behavior before/after delegating to the wrapped object. Compose multiple decorators. Used in ASP.NET Core middleware, logging wrappers, caching layers.

❌ **Wrong — subclassing for every combination of behaviors (class explosion):**
```csharp
public class LoggingEmailService : EmailService { /* adds logging */ }
public class RetryEmailService : EmailService { /* adds retry */ }
public class LoggingRetryEmailService : RetryEmailService { /* both? another class */ }
// N behaviors = 2^N classes
```

✅ **Correct — compose decorators independently:**
```csharp
public interface IEmailService { Task SendAsync(string to, string subject, string body); }

public class LoggingEmailDecorator : IEmailService {
    private readonly IEmailService _inner;
    private readonly ILogger _logger;
    public LoggingEmailDecorator(IEmailService inner, ILogger<LoggingEmailDecorator> logger) {
        _inner = inner; _logger = logger;
    }
    public async Task SendAsync(string to, string subject, string body) {
        _logger.LogInformation("Sending email to {To}", to);
        await _inner.SendAsync(to, subject, body);
    }
}

public class RetryEmailDecorator : IEmailService {
    private readonly IEmailService _inner;
    public RetryEmailDecorator(IEmailService inner) => _inner = inner;
    public async Task SendAsync(string to, string subject, string body) {
        for (int i = 0; i < 3; i++) {
            try { await _inner.SendAsync(to, subject, body); return; }
            catch { if (i == 2) throw; await Task.Delay(1000); }
        }
    }
}

// Compose:
IEmailService service = new RetryEmailDecorator(
    new LoggingEmailDecorator(new SmtpEmailService(), logger));
```

---

## 3.2 Repository Pattern

### Q10. How does the Repository pattern separate data access from business logic?

**Answer:**
The Repository abstracts persistence behind an interface. Business logic works against the interface and is completely unaware of EF Core, SQL, or any storage technology. Enables in-memory repositories for testing.

❌ **Wrong — business logic has direct EF Core dependency, untestable:**
```csharp
public class OrderService {
    private readonly AppDbContext _db; // direct EF Core dependency

    public async Task<Order?> GetActiveOrderAsync(int userId) {
        return await _db.Orders
            .Where(o => o.UserId == userId && o.Status == "Active")
            .FirstOrDefaultAsync(); // can't unit test without a real database
    }
}
```

✅ **Correct — business logic depends on an interface, testable with mocks:**
```csharp
public interface IOrderRepository {
    Task<Order?> GetActiveOrderAsync(int userId);
    Task AddAsync(Order order);
}

public class EfOrderRepository : IOrderRepository {
    private readonly AppDbContext _db;
    public EfOrderRepository(AppDbContext db) => _db = db;

    public Task<Order?> GetActiveOrderAsync(int userId) =>
        _db.Orders.FirstOrDefaultAsync(o => o.UserId == userId && o.Status == "Active");

    public async Task AddAsync(Order order) {
        _db.Orders.Add(order);
        await _db.SaveChangesAsync();
    }
}

public class OrderService {
    private readonly IOrderRepository _repo; // depends on interface only
    public OrderService(IOrderRepository repo) => _repo = repo;

    public Task<Order?> GetActiveOrderAsync(int userId) =>
        _repo.GetActiveOrderAsync(userId); // fully testable with mock repo
}
```

---

# 4. Design Patterns — Behavioral

> 📚 Reference: https://refactoring.guru/design-patterns/behavioral-patterns

---

## 4.1 Observer Pattern

### Q11. How does the Observer pattern decouple event producers from consumers?

**Answer:**
Observers register with a subject/publisher. When the subject changes state, it notifies all registered observers. Decouples the source of events from the handlers. In .NET: `event` keyword, `IObservable<T>`/`IObserver<T>`, or MediatR for domain events.

❌ **Wrong — tight coupling, order service directly calls every downstream service:**
```csharp
public class OrderService {
    private readonly EmailService _email;
    private readonly InventoryService _inventory;
    private readonly AnalyticsService _analytics;

    public void PlaceOrder(Order order) {
        // business logic
        _email.SendConfirmation(order);      // tightly coupled
        _inventory.Reduce(order.Items);     // tightly coupled
        _analytics.TrackPurchase(order);    // tightly coupled
        // Adding another downstream = edit OrderService
    }
}
```

✅ **Correct — event-driven with MediatR, each handler is independent:**
```csharp
public record OrderPlacedEvent(Order Order) : INotification;

public class OrderService {
    private readonly IMediator _mediator;
    public OrderService(IMediator mediator) => _mediator = mediator;

    public async Task PlaceOrderAsync(Order order) {
        // business logic
        await _mediator.Publish(new OrderPlacedEvent(order));
        // OrderService knows nothing about email, inventory, or analytics
    }
}

public class SendConfirmationEmailHandler : INotificationHandler<OrderPlacedEvent> {
    public Task Handle(OrderPlacedEvent e, CancellationToken ct) =>
        _emailService.SendConfirmationAsync(e.Order);
}
// New downstream = new handler class, zero changes to OrderService
```

---

## 4.2 Strategy Pattern

### Q12. When do you use the Strategy pattern?

**Answer:**
Strategy defines a family of interchangeable algorithms behind a common interface. Use when an algorithm needs to vary independently from the client, or when you have multiple conditional branches selecting between behaviors.

❌ **Wrong — algorithm selection via if/else in the client, mixed concerns:**
```csharp
public decimal CalculateShipping(string carrier, decimal weight) {
    if (carrier == "FedEx") return weight * 2.5m + 5m;
    if (carrier == "UPS")   return weight * 2.0m + 7m;
    if (carrier == "USPS")  return weight * 1.5m + 3m;
    throw new ArgumentException("Unknown carrier");
}
```

✅ **Correct — strategy per carrier, select at runtime:**
```csharp
public interface IShippingStrategy {
    decimal Calculate(decimal weight);
}

public class FedExShipping : IShippingStrategy {
    public decimal Calculate(decimal weight) => weight * 2.5m + 5m;
}
public class UpsShipping : IShippingStrategy {
    public decimal Calculate(decimal weight) => weight * 2.0m + 7m;
}

public class ShippingCalculator {
    private readonly Dictionary<string, IShippingStrategy> _strategies;

    public ShippingCalculator(IEnumerable<IShippingStrategy> strategies) =>
        _strategies = strategies.ToDictionary(s => s.GetType().Name.Replace("Shipping", ""));

    public decimal Calculate(string carrier, decimal weight) =>
        _strategies.TryGetValue(carrier, out var strategy)
            ? strategy.Calculate(weight)
            : throw new ArgumentException($"Unknown carrier: {carrier}");
}
```

---

# 5. Class Design & OOP

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/

---

## 5.1 Inheritance vs Composition

### Q13. When do you prefer composition over inheritance?

**Answer:**
Prefer composition when you want to reuse behavior without establishing an "is-a" relationship, when the behavior might need to change at runtime, or when the inheritance hierarchy would become deep and rigid. "Favor composition over inheritance" (GoF).

❌ **Wrong — deep inheritance to share logging behavior:**
```csharp
public abstract class LoggingBase {
    protected void Log(string msg) => Console.WriteLine(msg);
}
public class OrderService : LoggingBase { }
public class UserService : LoggingBase { }
// OrderService "is-a" LoggingBase? No — it just happens to log
```

✅ **Correct — inject ILogger as a dependency (composition):**
```csharp
public class OrderService {
    private readonly ILogger<OrderService> _logger; // composed in, not inherited

    public OrderService(ILogger<OrderService> logger) => _logger = logger;

    public void Process(Order order) {
        _logger.LogInformation("Processing order {Id}", order.Id);
    }
}
```

---

# 6. Concurrency & Thread Safety

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/
> 📚 Threading: https://learn.microsoft.com/en-us/dotnet/standard/threading/

---

## 6.1 Thread-Safe Collections

### Q14. How do you safely share mutable state across threads in .NET?

**Answer:**
Use `ConcurrentDictionary<K,V>`, `ConcurrentQueue<T>`, or `Interlocked` for lock-free operations. For complex multi-step mutations, use `lock` with a private object. Avoid locking on `this` or on public objects.

❌ **Wrong — `Dictionary<K,V>` shared across threads without synchronization:**
```csharp
private static Dictionary<int, User> _cache = new(); // not thread-safe

public void AddUser(User user) {
    _cache[user.Id] = user; // concurrent writes → data corruption / exception
}
```

✅ **Correct — `ConcurrentDictionary` for thread-safe access:**
```csharp
private static ConcurrentDictionary<int, User> _cache = new();

public void AddUser(User user) {
    _cache[user.Id] = user; // atomic, thread-safe
}

public User GetOrAdd(int id, Func<int, User> factory) =>
    _cache.GetOrAdd(id, factory); // atomic get-or-create
```

---

# 7. Common LLD Problems

> 📚 Reference: https://github.com/prasadgujar/low-level-design-primer

---

## 7.1 Design a Parking Lot

### Q15. How do you design a Parking Lot system at the class level?

**Answer:**
Key classes: `ParkingLot` (entry point), `ParkingFloor`, `ParkingSpot` (with type: compact/large/handicapped), `Vehicle` (Car/Truck/Motorcycle), `Ticket`, `PaymentProcessor`. Apply SRP — each class has one job. Use strategy for pricing.

❌ **Wrong — God class that handles everything:**
```csharp
public class ParkingLot {
    public void ParkVehicle(string type, string plate) { /* all logic here */ }
    public void CalculateAndProcessPayment(string plate) { /* pricing + payment here */ }
    public void FindAvailableSpot(string vehicleType) { /* search logic here */ }
    // 500-line class, impossible to extend or test
}
```

✅ **Correct — each class has a focused responsibility:**
```csharp
public enum SpotType { Compact, Large, Handicapped }
public enum VehicleType { Car, Truck, Motorcycle }

public class ParkingSpot {
    public int Id { get; }
    public SpotType Type { get; }
    public bool IsOccupied { get; private set; }
    public void Occupy() => IsOccupied = true;
    public void Vacate() => IsOccupied = false;
}

public class Ticket {
    public string VehiclePlate { get; }
    public ParkingSpot Spot { get; }
    public DateTime EntryTime { get; } = DateTime.UtcNow;
    public DateTime? ExitTime { get; set; }
}

public interface IPricingStrategy { decimal Calculate(TimeSpan duration); }

public class HourlyPricing : IPricingStrategy {
    private readonly decimal _ratePerHour;
    public HourlyPricing(decimal rate) => _ratePerHour = rate;
    public decimal Calculate(TimeSpan duration) =>
        Math.Ceiling((decimal)duration.TotalHours) * _ratePerHour;
}

public class ParkingLot {
    private readonly List<ParkingSpot> _spots;
    private readonly Dictionary<string, Ticket> _activeTickets = new();
    private readonly IPricingStrategy _pricing;

    public Ticket? Park(Vehicle vehicle) {
        var spot = _spots.FirstOrDefault(s => !s.IsOccupied && s.Type == MapToSpotType(vehicle.Type));
        if (spot is null) return null;
        spot.Occupy();
        var ticket = new Ticket(vehicle.Plate, spot);
        _activeTickets[vehicle.Plate] = ticket;
        return ticket;
    }

    public decimal Exit(string plate) {
        var ticket = _activeTickets[plate];
        ticket.ExitTime = DateTime.UtcNow;
        ticket.Spot.Vacate();
        _activeTickets.Remove(plate);
        return _pricing.Calculate(ticket.ExitTime.Value - ticket.EntryTime);
    }
}
```

---

## 7.2 Design a Rate Limiter

### Q16. How do you design a Token Bucket rate limiter?

**Answer:**
Token Bucket: a bucket holds up to `capacity` tokens, refills at a fixed rate. Each request consumes a token. If the bucket is empty, reject the request. Thread-safe with `SemaphoreSlim` or `Interlocked`.

❌ **Wrong — simple counter that doesn't reset properly, not thread-safe:**
```csharp
public class RateLimiter {
    private int _requestCount = 0;
    private readonly int _limit;

    public bool Allow() {
        _requestCount++; // not atomic!
        return _requestCount <= _limit; // never resets!
    }
}
```

✅ **Correct — Token Bucket with thread-safe atomic operations:**
```csharp
public class TokenBucketRateLimiter {
    private readonly int _capacity;
    private readonly double _refillRatePerSecond;
    private double _tokens;
    private DateTime _lastRefill = DateTime.UtcNow;
    private readonly object _lock = new();

    public TokenBucketRateLimiter(int capacity, double refillRatePerSecond) {
        _capacity = capacity;
        _refillRatePerSecond = refillRatePerSecond;
        _tokens = capacity;
    }

    public bool TryAcquire() {
        lock (_lock) {
            Refill();
            if (_tokens < 1) return false;
            _tokens -= 1;
            return true;
        }
    }

    private void Refill() {
        var now = DateTime.UtcNow;
        double elapsed = (now - _lastRefill).TotalSeconds;
        _tokens = Math.Min(_capacity, _tokens + elapsed * _refillRatePerSecond);
        _lastRefill = now;
    }
}
```

---

# 8. Design Patterns — Structural (Extended)

> 📚 Reference: https://refactoring.guru/design-patterns/structural-patterns

---

## 8.1 Adapter Pattern

### Q17. When do you use the Adapter pattern and how do you implement it?

**Answer:**
Adapter bridges an incompatible interface to the one your code expects — like a plug adapter. Use it when integrating a third-party library or legacy code whose interface you can't change. The adapter wraps the adaptee and translates calls.

❌ **Wrong — directly coupling business logic to a third-party SDK's interface:**
```csharp
public class PaymentService {
    // Directly calls Stripe SDK — if you ever switch to PayPal, rewrite everything
    public void Charge(decimal amount) {
        var stripe = new StripeClient("sk_test_...");
        var options = new ChargeCreateOptions { Amount = (long)(amount * 100), Currency = "usd" };
        new ChargeService(stripe).Create(options);
    }
}
```

✅ **Correct — adapter wraps the third-party SDK behind your own interface:**
```csharp
public interface IPaymentGateway {
    Task<PaymentResult> ChargeAsync(decimal amount, string currency, string token);
}

// Adapter: wraps Stripe behind IPaymentGateway
public class StripePaymentAdapter : IPaymentGateway {
    private readonly ChargeService _chargeService;
    public StripePaymentAdapter(StripeClient client) => _chargeService = new ChargeService(client);

    public async Task<PaymentResult> ChargeAsync(decimal amount, string currency, string token) {
        var charge = await _chargeService.CreateAsync(new ChargeCreateOptions {
            Amount = (long)(amount * 100), Currency = currency, Source = token
        });
        return new PaymentResult(charge.Id, charge.Status == "succeeded");
    }
}

// PayPal tomorrow? Add PayPalPaymentAdapter : IPaymentGateway — zero changes to PaymentService
```

---

## 8.2 Facade Pattern

### Q18. What is the Facade pattern and what problem does it solve?

**Answer:**
A Facade provides a single simplified interface over a complex subsystem of many classes. The caller doesn't need to know how the subsystem works — the facade coordinates the parts. Used in service layers, SDKs, and domain orchestrators.

❌ **Wrong — client wires together multiple subsystem classes directly (tight coupling, duplicated orchestration):**
```csharp
// In every controller action that processes an order:
var inventory = new InventoryService();
inventory.Reserve(order.Items);
var payment = new PaymentGateway();
payment.Charge(order.Total, order.PaymentToken);
var shipping = new ShippingService();
shipping.CreateShipment(order);
var email = new EmailService();
email.SendOrderConfirmation(order);
// This 4-step sequence duplicated everywhere it's needed
```

✅ **Correct — Facade coordinates the subsystem, clients call one method:**
```csharp
public class OrderFacade {
    private readonly IInventoryService _inventory;
    private readonly IPaymentGateway _payment;
    private readonly IShippingService _shipping;
    private readonly IEmailService _email;

    public OrderFacade(IInventoryService inv, IPaymentGateway pay,
                       IShippingService ship, IEmailService email) {
        _inventory = inv; _payment = pay; _shipping = ship; _email = email;
    }

    public async Task<OrderResult> PlaceOrderAsync(Order order) {
        await _inventory.ReserveAsync(order.Items);
        var payment = await _payment.ChargeAsync(order.Total, order.PaymentToken);
        var shipment = await _shipping.CreateShipmentAsync(order);
        await _email.SendConfirmationAsync(order, shipment.TrackingNumber);
        return new OrderResult(payment.TransactionId, shipment.TrackingNumber);
    }
}
// Controller just calls: await _orderFacade.PlaceOrderAsync(order);
```

---

## 8.3 Proxy Pattern

### Q19. What are the types of Proxy and when do you use each?

**Answer:**
A Proxy controls access to another object. Three common types: Virtual Proxy (lazy initialization — create expensive object only when needed), Protection Proxy (access control), Remote Proxy (local representative for a remote service). In .NET, `DispatchProxy` and source generators enable compile-time proxies.

❌ **Wrong — eagerly loading a heavy resource even when it may never be used:**
```csharp
public class ReportService {
    private readonly HeavyReportGenerator _generator = new HeavyReportGenerator();
    // Loads 500MB of historical data in constructor — always, even if no report is needed today
}
```

✅ **Correct — Virtual Proxy with lazy initialization:**
```csharp
public interface IReportGenerator { Report Generate(DateTime from, DateTime to); }

public class LazyReportProxy : IReportGenerator {
    private HeavyReportGenerator? _real;
    private readonly object _lock = new();

    public Report Generate(DateTime from, DateTime to) {
        if (_real == null) {
            lock (_lock) {
                _real ??= new HeavyReportGenerator(); // load only when first needed
            }
        }
        return _real.Generate(from, to);
    }
}
```

---

## 8.4 Abstract Factory Pattern

### Q20. How does Abstract Factory differ from Factory Method?

**Answer:**
Factory Method creates one product via a virtual method; subclasses decide the concrete type. Abstract Factory creates a *family* of related products through an interface with multiple factory methods. Use it when products must be used together and you want to enforce compatibility.

❌ **Wrong — mixing UI components from different themes (incompatible family):**
```csharp
var button = new WindowsButton();   // Windows
var textBox = new MacTextBox();     // Mac — inconsistent UI family!
var dialog = new LinuxDialog();     // Linux — visual chaos
```

✅ **Correct — Abstract Factory enforces a consistent family:**
```csharp
public interface IUIFactory {
    IButton CreateButton();
    ITextBox CreateTextBox();
    IDialog CreateDialog();
}

public class WindowsUIFactory : IUIFactory {
    public IButton  CreateButton()  => new WindowsButton();
    public ITextBox CreateTextBox() => new WindowsTextBox();
    public IDialog  CreateDialog()  => new WindowsDialog();
}

public class MacUIFactory : IUIFactory {
    public IButton  CreateButton()  => new MacButton();
    public ITextBox CreateTextBox() => new MacTextBox();
    public IDialog  CreateDialog()  => new MacDialog();
}

public class Application {
    private readonly IUIFactory _factory;
    public Application(IUIFactory factory) => _factory = factory;

    public void BuildUI() {
        var button  = _factory.CreateButton();   // always compatible family
        var textBox = _factory.CreateTextBox();
        var dialog  = _factory.CreateDialog();
    }
}
```

---

# 9. Design Patterns — Behavioral (Extended)

> 📚 Reference: https://refactoring.guru/design-patterns/behavioral-patterns

---

## 9.1 Command Pattern

### Q21. What is the Command pattern and when is it useful?

**Answer:**
A Command encapsulates a request as an object, decoupling sender from receiver. Enables undo/redo, queuing, logging, and macro commands. Each command implements an `Execute()` (and optionally `Undo()`) method.

❌ **Wrong — action logic hardcoded in the invoker (editor directly manipulates text):**
```csharp
public class TextEditor {
    public string Text = "";
    public void Bold()   { Text = $"<b>{Text}</b>"; }
    public void Italic() { Text = $"<i>{Text}</i>"; }
    // Undo is impossible — no history of what was done
}
```

✅ **Correct — commands with undo support:**
```csharp
public interface ICommand { void Execute(); void Undo(); }

public class BoldCommand : ICommand {
    private readonly TextEditor _editor;
    private string _previousText = "";
    public BoldCommand(TextEditor e) => _editor = e;
    public void Execute() { _previousText = _editor.Text; _editor.Text = $"<b>{_editor.Text}</b>"; }
    public void Undo()    { _editor.Text = _previousText; }
}

public class CommandHistory {
    private readonly Stack<ICommand> _history = new();
    public void Execute(ICommand cmd) { cmd.Execute(); _history.Push(cmd); }
    public void Undo() { if (_history.Count > 0) _history.Pop().Undo(); }
}
```

---

## 9.2 Chain of Responsibility

### Q22. What is the Chain of Responsibility pattern? Give a real-world .NET example.

**Answer:**
Each handler in a chain either processes a request or passes it to the next handler. Decouples request senders from receivers. ASP.NET Core middleware is a classic CoR implementation.

❌ **Wrong — all validation logic in one monolithic method, impossible to extend:**
```csharp
public ValidationResult Validate(Order order) {
    if (order.Items.Count == 0) return ValidationResult.Fail("No items");
    if (order.Total <= 0) return ValidationResult.Fail("Invalid total");
    if (!_inventory.IsAvailable(order)) return ValidationResult.Fail("Out of stock");
    if (!_fraud.IsLegitimate(order)) return ValidationResult.Fail("Fraud detected");
    if (!_payment.CanCharge(order)) return ValidationResult.Fail("Payment declined");
    return ValidationResult.Ok();
    // Adding a new check means editing this method
}
```

✅ **Correct — chain of independent handlers:**
```csharp
public abstract class OrderHandler {
    private OrderHandler? _next;
    public OrderHandler SetNext(OrderHandler next) { _next = next; return next; }
    public virtual ValidationResult Handle(Order order) =>
        _next?.Handle(order) ?? ValidationResult.Ok();
}

public class EmptyCartHandler : OrderHandler {
    public override ValidationResult Handle(Order order) =>
        order.Items.Count == 0 ? ValidationResult.Fail("No items") : base.Handle(order);
}
public class InventoryHandler : OrderHandler {
    public override ValidationResult Handle(Order order) =>
        !_inventory.IsAvailable(order) ? ValidationResult.Fail("Out of stock") : base.Handle(order);
}
public class FraudHandler : OrderHandler {
    public override ValidationResult Handle(Order order) =>
        !_fraud.IsLegitimate(order) ? ValidationResult.Fail("Fraud detected") : base.Handle(order);
}

// Wire the chain:
var chain = new EmptyCartHandler();
chain.SetNext(new InventoryHandler()).SetNext(new FraudHandler());
var result = chain.Handle(order);
```

---

## 9.3 State Pattern

### Q23. How does the State pattern eliminate complex state-based conditionals?

**Answer:**
Each state is a class implementing a common interface. The context delegates behavior to the current state object. Transitioning = swapping the state object. Eliminates giant if/switch chains that check state.

❌ **Wrong — switch on an enum in every method, grows forever:**
```csharp
public void Process(Order order) {
    switch (order.Status) {
        case OrderStatus.New:      HandleNew(order); break;
        case OrderStatus.Paid:     HandlePaid(order); break;
        case OrderStatus.Shipped:  HandleShipped(order); break;
        case OrderStatus.Returned: HandleReturn(order); break;
        // Every new status = edit every switch in the codebase
    }
}
```

✅ **Correct — each state handles its own behavior and transitions:**
```csharp
public interface IOrderState {
    void Pay(OrderContext ctx);
    void Ship(OrderContext ctx);
    void Return(OrderContext ctx);
}

public class NewOrderState : IOrderState {
    public void Pay(OrderContext ctx)    { ctx.SetState(new PaidOrderState()); }
    public void Ship(OrderContext ctx)   => throw new InvalidOperationException("Pay first");
    public void Return(OrderContext ctx) => throw new InvalidOperationException("Nothing to return");
}

public class PaidOrderState : IOrderState {
    public void Pay(OrderContext ctx)    => throw new InvalidOperationException("Already paid");
    public void Ship(OrderContext ctx)   { ctx.SetState(new ShippedOrderState()); }
    public void Return(OrderContext ctx) { ctx.SetState(new RefundedOrderState()); }
}

public class OrderContext {
    private IOrderState _state = new NewOrderState();
    public void SetState(IOrderState s) => _state = s;
    public void Pay()    => _state.Pay(this);
    public void Ship()   => _state.Ship(this);
    public void Return() => _state.Return(this);
}
```

---

## 9.4 Template Method Pattern

### Q24. What is the Template Method pattern and when do you use it?

**Answer:**
Define the skeleton of an algorithm in a base class with abstract or virtual steps. Subclasses override specific steps without changing the overall structure. Use when multiple classes share the same algorithm flow but differ in specific steps.

❌ **Wrong — duplicating the report-generation flow in every subclass:**
```csharp
public class PdfReporter {
    public void Generate() {
        var data = FetchData();     // same
        var processed = Process(data); // same
        // ... PDF-specific rendering
        SaveToFile("report.pdf");   // same
    }
}
public class ExcelReporter {
    public void Generate() {
        var data = FetchData();     // duplicated
        var processed = Process(data); // duplicated
        // ... Excel-specific rendering
        SaveToFile("report.xlsx");  // duplicated
    }
}
```

✅ **Correct — base class owns the skeleton, subclasses fill in format-specific steps:**
```csharp
public abstract class ReportGenerator {
    // Template method — the fixed skeleton
    public void Generate() {
        var data = FetchData();
        var processed = ProcessData(data);
        var content = RenderContent(processed);  // abstract step
        var filename = GetFileName();            // abstract step
        SaveToFile(content, filename);
    }

    protected abstract byte[] RenderContent(ProcessedData data);
    protected abstract string GetFileName();

    private RawData FetchData() { /* shared DB query */ return new(); }
    private ProcessedData ProcessData(RawData d) { /* shared logic */ return new(); }
    private void SaveToFile(byte[] content, string name) { File.WriteAllBytes(name, content); }
}

public class PdfReportGenerator : ReportGenerator {
    protected override byte[] RenderContent(ProcessedData d) => PdfRenderer.Render(d);
    protected override string GetFileName() => $"report_{DateTime.Now:yyyyMMdd}.pdf";
}

public class ExcelReportGenerator : ReportGenerator {
    protected override byte[] RenderContent(ProcessedData d) => ExcelRenderer.Render(d);
    protected override string GetFileName() => $"report_{DateTime.Now:yyyyMMdd}.xlsx";
}
```

---

# 10. LLD Design Problems (Extended)

> 📚 Reference: https://github.com/prasadgujar/low-level-design-primer

---

## 10.1 Design an ATM Machine

### Q25. Design an ATM system at the class level.

**Answer:**
Key classes: `ATM` (entry point, state machine), `Card`, `Account`, `Transaction`, `CashDispenser`, `ReceiptPrinter`. State pattern for ATM states (idle, card inserted, PIN entered, transaction in progress). Command pattern for transaction types.

❌ **Wrong — monolithic ATM class with all logic and state in if/else chains:**
```csharp
public class ATM {
    string _state = "idle";
    public void InsertCard(Card c) { if (_state == "idle") _state = "card_inserted"; }
    public void EnterPin(int pin)  { if (_state == "card_inserted") { /* inline auth */ _state = "authenticated"; } }
    public void Withdraw(decimal amount) { if (_state == "authenticated") { /* inline cash logic */ } }
    // One class doing auth, dispensing cash, printing receipts, state management
}
```

✅ **Correct — separated responsibilities with state pattern:**
```csharp
// States
public interface IATMState {
    void InsertCard(ATMContext ctx, Card card);
    void EnterPin(ATMContext ctx, int pin);
    void SelectTransaction(ATMContext ctx, ITransaction tx);
    void EjectCard(ATMContext ctx);
}

public class IdleState : IATMState {
    public void InsertCard(ATMContext ctx, Card card) {
        ctx.CurrentCard = card;
        ctx.SetState(new CardInsertedState());
    }
    public void EnterPin(ATMContext ctx, int pin)         => ctx.DisplayMessage("Please insert card first");
    public void SelectTransaction(ATMContext ctx, ITransaction tx) => ctx.DisplayMessage("Please insert card first");
    public void EjectCard(ATMContext ctx)                 => ctx.DisplayMessage("No card inserted");
}

// Transactions (Command pattern)
public interface ITransaction { TransactionResult Execute(Account account); }

public class WithdrawTransaction : ITransaction {
    private readonly decimal _amount;
    private readonly CashDispenser _dispenser;
    public WithdrawTransaction(decimal amount, CashDispenser dispenser) {
        _amount = amount; _dispenser = dispenser;
    }
    public TransactionResult Execute(Account account) {
        if (account.Balance < _amount) return TransactionResult.Fail("Insufficient funds");
        account.Debit(_amount);
        _dispenser.Dispense(_amount);
        return TransactionResult.Success();
    }
}

// Components
public class CashDispenser {
    private decimal _cashAvailable;
    public void Dispense(decimal amount) {
        if (_cashAvailable < amount) throw new InvalidOperationException("ATM out of cash");
        _cashAvailable -= amount;
        Console.WriteLine($"Dispensing ${amount}");
    }
}

public class ATMContext {
    public Card? CurrentCard { get; set; }
    public Account? AuthenticatedAccount { get; set; }
    private IATMState _state = new IdleState();
    public void SetState(IATMState s) => _state = s;
    public void DisplayMessage(string msg) => Console.WriteLine(msg);
    public void InsertCard(Card c)        => _state.InsertCard(this, c);
    public void EnterPin(int pin)         => _state.EnterPin(this, pin);
    public void SelectTransaction(ITransaction tx) => _state.SelectTransaction(this, tx);
}
```

---

## 10.2 Design a Vending Machine

### Q26. Design a Vending Machine at the class level.

**Answer:**
Key classes: `VendingMachine` (state machine), `Product`, `Inventory`, `Coin`/`Payment`, states (Idle, HasMoney, Dispensing). State pattern transitions on coin insert, product select, and dispense.

❌ **Wrong — boolean flags and if-chains manage state, spaghetti logic:**
```csharp
public class VendingMachine {
    bool _hasMoney, _productSelected;
    decimal _insertedAmount;
    public void InsertCoin(decimal c) { if (!_hasMoney) { _insertedAmount += c; _hasMoney = true; } }
    public void SelectProduct(string id) { if (_hasMoney) _productSelected = true; }
    public void Dispense() { if (_hasMoney && _productSelected) { /* dispense */ _hasMoney = _productSelected = false; } }
}
```

✅ **Correct — state pattern with clean transitions:**
```csharp
public interface IVendingState {
    void InsertMoney(VendingContext ctx, decimal amount);
    void SelectProduct(VendingContext ctx, string productId);
    void Dispense(VendingContext ctx);
    void ReturnChange(VendingContext ctx);
}

public class IdleState : IVendingState {
    public void InsertMoney(VendingContext ctx, decimal amount) {
        ctx.InsertedAmount += amount;
        ctx.Display($"Inserted: ${ctx.InsertedAmount}");
        ctx.SetState(new HasMoneyState());
    }
    public void SelectProduct(VendingContext ctx, string id) => ctx.Display("Please insert money first");
    public void Dispense(VendingContext ctx)                 => ctx.Display("Please insert money first");
    public void ReturnChange(VendingContext ctx)             => ctx.Display("No money to return");
}

public class HasMoneyState : IVendingState {
    public void InsertMoney(VendingContext ctx, decimal amount) { ctx.InsertedAmount += amount; ctx.Display($"Total: ${ctx.InsertedAmount}"); }
    public void SelectProduct(VendingContext ctx, string productId) {
        var product = ctx.Inventory.GetProduct(productId);
        if (product == null)                        { ctx.Display("Product not found"); return; }
        if (ctx.InsertedAmount < product.Price)     { ctx.Display($"Need ${product.Price - ctx.InsertedAmount} more"); return; }
        if (!ctx.Inventory.IsAvailable(productId))  { ctx.Display("Out of stock"); return; }
        ctx.SelectedProduct = product;
        ctx.SetState(new DispensingState());
        ctx.Dispense();
    }
    public void Dispense(VendingContext ctx)     => ctx.Display("Please select a product first");
    public void ReturnChange(VendingContext ctx) { ctx.Display($"Returning ${ctx.InsertedAmount}"); ctx.InsertedAmount = 0; ctx.SetState(new IdleState()); }
}

public class DispensingState : IVendingState {
    public void InsertMoney(VendingContext ctx, decimal a) => ctx.Display("Dispensing, please wait");
    public void SelectProduct(VendingContext ctx, string id) => ctx.Display("Dispensing, please wait");
    public void Dispense(VendingContext ctx) {
        ctx.Inventory.Dispense(ctx.SelectedProduct!.Id);
        decimal change = ctx.InsertedAmount - ctx.SelectedProduct.Price;
        ctx.InsertedAmount = 0;
        if (change > 0) ctx.Display($"Change: ${change}");
        ctx.SetState(new IdleState());
    }
    public void ReturnChange(VendingContext ctx) => ctx.Display("Dispensing in progress");
}

public class VendingContext {
    public decimal InsertedAmount { get; set; }
    public Product? SelectedProduct { get; set; }
    public Inventory Inventory { get; }
    private IVendingState _state = new IdleState();
    public VendingContext(Inventory inv) => Inventory = inv;
    public void SetState(IVendingState s) => _state = s;
    public void Display(string msg)       => Console.WriteLine(msg);
    public void InsertMoney(decimal a)    => _state.InsertMoney(this, a);
    public void SelectProduct(string id)  => _state.SelectProduct(this, id);
    public void Dispense()                => _state.Dispense(this);
    public void ReturnChange()            => _state.ReturnChange(this);
}
```

---

## 10.3 Design an Elevator System

### Q27. Design an elevator system for a multi-floor building.

**Answer:**
Key classes: `ElevatorSystem`, `Elevator`, `ElevatorRequest`, `Scheduler` (dispatching algorithm). State per elevator: Idle, MovingUp, MovingDown, DoorsOpen. Scheduler selects the best elevator for each request.

❌ **Wrong — single elevator, no scheduler, requests handled in arrival order:**
```csharp
public class Elevator {
    Queue<int> _requests = new();
    public void Request(int floor) { _requests.Enqueue(floor); }
    public void Run() { while(_requests.Count > 0) MoveTo(_requests.Dequeue()); }
    // No optimization, no multi-elevator support, ignores direction preference
}
```

✅ **Correct — multi-elevator system with SCAN (elevator algorithm) scheduling:**
```csharp
public enum Direction { Up, Down, Idle }
public enum ElevatorState { Idle, Moving, DoorsOpen }

public class Elevator {
    public int Id { get; }
    public int CurrentFloor { get; private set; }
    public Direction Direction { get; private set; } = Direction.Idle;
    public ElevatorState State { get; private set; } = ElevatorState.Idle;
    private readonly SortedSet<int> _upQueue   = new();
    private readonly SortedSet<int> _downQueue = new(Comparer<int>.Create((a,b) => b-a));

    public Elevator(int id, int startFloor) { Id = id; CurrentFloor = startFloor; }

    public void AddRequest(int floor) {
        if (floor >= CurrentFloor) _upQueue.Add(floor);
        else _downQueue.Add(floor);
    }

    public async Task RunAsync(CancellationToken ct) {
        while (!ct.IsCancellationRequested) {
            if (_upQueue.Count > 0) {
                Direction = Direction.Up;
                foreach (int floor in _upQueue.ToList()) {
                    await MoveToAsync(floor);
                    _upQueue.Remove(floor);
                }
            } else if (_downQueue.Count > 0) {
                Direction = Direction.Down;
                foreach (int floor in _downQueue.ToList()) {
                    await MoveToAsync(floor);
                    _downQueue.Remove(floor);
                }
            } else {
                Direction = Direction.Idle;
                State = ElevatorState.Idle;
                await Task.Delay(200, ct);
            }
        }
    }

    private async Task MoveToAsync(int floor) {
        State = ElevatorState.Moving;
        while (CurrentFloor != floor) {
            CurrentFloor += CurrentFloor < floor ? 1 : -1;
            await Task.Delay(500); // simulate movement
        }
        State = ElevatorState.DoorsOpen;
        await Task.Delay(2000); // doors open
        State = ElevatorState.Moving;
    }
}

public class ElevatorScheduler {
    private readonly List<Elevator> _elevators;

    public ElevatorScheduler(int numElevators, int floors) {
        _elevators = Enumerable.Range(0, numElevators)
            .Select(i => new Elevator(i, 0)).ToList();
    }

    // SCAN: pick the elevator closest to the requested floor that's already moving in the right direction, else idle
    public void RequestElevator(int floor, Direction dir) {
        var best = _elevators
            .Where(e => e.Direction == dir || e.Direction == Direction.Idle)
            .OrderBy(e => Math.Abs(e.CurrentFloor - floor))
            .FirstOrDefault()
            ?? _elevators.OrderBy(e => Math.Abs(e.CurrentFloor - floor)).First();

        best.AddRequest(floor);
    }
}
```

---

## 10.4 Design an Online Shopping Cart

### Q28. Design an online shopping cart and checkout system.

**Answer:**
Key classes: `Cart`, `CartItem`, `Product`, `PricingEngine` (discounts, coupons), `CheckoutService`, `Order`, `PaymentProcessor`, `InventoryService`. Use Strategy for pricing/discount rules. Observer for cart change events.

❌ **Wrong — Cart class calculates pricing, applies discounts, processes payment, and updates inventory:**
```csharp
public class Cart {
    public decimal Checkout(string couponCode, string paymentToken) {
        decimal total = Items.Sum(i => i.Price * i.Qty);
        if (couponCode == "SAVE10") total *= 0.9m;    // hardcoded discount
        _db.Execute("UPDATE inventory ...");            // direct DB in domain object
        _stripe.Charge(total, paymentToken);           // payment in domain object
        return total;
    }
}
```

✅ **Correct — each concern is separated:**
```csharp
public class Cart {
    public Guid Id { get; } = Guid.NewGuid();
    public Guid UserId { get; }
    private readonly List<CartItem> _items = new();
    public IReadOnlyList<CartItem> Items => _items.AsReadOnly();

    public void AddItem(Product product, int qty) {
        var existing = _items.FirstOrDefault(i => i.ProductId == product.Id);
        if (existing != null) existing.IncreaseQty(qty);
        else _items.Add(new CartItem(product.Id, product.Name, product.Price, qty));
    }
    public void RemoveItem(Guid productId) => _items.RemoveAll(i => i.ProductId == productId);
    public decimal Subtotal() => _items.Sum(i => i.Price * i.Qty);
}

public class PricingEngine {
    private readonly IEnumerable<IDiscountStrategy> _strategies;
    public PricingEngine(IEnumerable<IDiscountStrategy> strategies) => _strategies = strategies;

    public PricingSummary Calculate(Cart cart, string? couponCode) {
        decimal subtotal = cart.Subtotal();
        decimal discount = _strategies
            .Where(s => s.IsApplicable(cart, couponCode))
            .Sum(s => s.CalculateDiscount(cart));
        decimal tax = (subtotal - discount) * 0.08m;
        return new PricingSummary(subtotal, discount, tax, subtotal - discount + tax);
    }
}

public class CheckoutService {
    private readonly IInventoryService _inventory;
    private readonly IPaymentGateway _payment;
    private readonly IOrderRepository _orders;
    private readonly PricingEngine _pricing;

    public async Task<Order> CheckoutAsync(Cart cart, string? coupon, string paymentToken) {
        var summary = _pricing.Calculate(cart, coupon);
        await _inventory.ReserveAsync(cart.Items);          // reserve before charging
        var paymentResult = await _payment.ChargeAsync(summary.Total, paymentToken);
        if (!paymentResult.Success) {
            await _inventory.ReleaseAsync(cart.Items);       // rollback reservation
            throw new PaymentFailedException(paymentResult.Error);
        }
        var order = Order.Create(cart, summary, paymentResult.TransactionId);
        await _orders.AddAsync(order);
        return order;
    }
}
```

---

## 10.5 Design a Chess Game

### Q29. Design a chess game at the class level.

**Answer:**
Key classes: `Board`, `Piece` (abstract, subclasses per piece type), `Square`, `Player`, `Game`, `Move`. Use polymorphism for piece move validation. Observer for check/checkmate detection.

❌ **Wrong — giant switch statement for piece movement in one class:**
```csharp
public bool IsValidMove(string pieceType, int fromRow, int fromCol, int toRow, int toCol) {
    switch (pieceType) {
        case "Pawn":   /* pawn rules */ break;
        case "Rook":   /* rook rules */ break;
        case "Knight": /* knight rules */ break;
        // All piece logic in one place — 300 line method
    }
}
```

✅ **Correct — each piece knows its own movement rules:**
```csharp
public enum Color { White, Black }
public record Square(int Row, int Col) {
    public bool IsValid => Row >= 0 && Row < 8 && Col >= 0 && Col < 8;
}

public abstract class Piece {
    public Color Color { get; }
    public Square Position { get; set; }
    protected Piece(Color color, Square pos) { Color = color; Position = pos; }

    public abstract IEnumerable<Square> GetValidMoves(Board board);

    public bool CanMoveTo(Square target, Board board) =>
        GetValidMoves(board).Contains(target);
}

public class Rook : Piece {
    public Rook(Color color, Square pos) : base(color, pos) { }

    public override IEnumerable<Square> GetValidMoves(Board board) {
        var moves = new List<Square>();
        int[][] directions = { new[]{1,0}, new[]{-1,0}, new[]{0,1}, new[]{0,-1} };
        foreach (var dir in directions) {
            int r = Position.Row + dir[0], c = Position.Col + dir[1];
            while (new Square(r, c).IsValid) {
                var sq = new Square(r, c);
                var occupant = board.GetPiece(sq);
                if (occupant == null)  { moves.Add(sq); }             // empty square
                else { if (occupant.Color != Color) moves.Add(sq);    // capture
                       break; }                                        // blocked
                r += dir[0]; c += dir[1];
            }
        }
        return moves;
    }
}

public class Knight : Piece {
    public Knight(Color color, Square pos) : base(color, pos) { }
    public override IEnumerable<Square> GetValidMoves(Board board) {
        int[][] offsets = { new[]{2,1},{2,-1},{-2,1},{-2,-1},{1,2},{1,-2},{-1,2},{-1,-2} };
        return offsets
            .Select(o => new Square(Position.Row + o[0], Position.Col + o[1]))
            .Where(s => s.IsValid && (board.GetPiece(s)?.Color != Color));
    }
}

public class Board {
    private readonly Piece?[,] _grid = new Piece?[8, 8];

    public Piece? GetPiece(Square sq) => _grid[sq.Row, sq.Col];
    public void SetPiece(Piece? piece, Square sq) {
        _grid[sq.Row, sq.Col] = piece;
        if (piece != null) piece.Position = sq;
    }
    public void MovePiece(Square from, Square to) {
        var piece = GetPiece(from) ?? throw new InvalidOperationException("No piece at source");
        SetPiece(null, from);
        SetPiece(piece, to);
    }
}

public class Game {
    public Board Board { get; } = new();
    public Player[] Players { get; }
    private int _turnIndex = 0;
    public Player CurrentPlayer => Players[_turnIndex % 2];

    public Game(Player white, Player black) => Players = new[] { white, black };

    public MoveResult MakeMove(Square from, Square to) {
        var piece = Board.GetPiece(from);
        if (piece == null || piece.Color != CurrentPlayer.Color)
            return MoveResult.Invalid("Not your piece");
        if (!piece.CanMoveTo(to, Board))
            return MoveResult.Invalid("Illegal move for this piece");

        Board.MovePiece(from, to);
        _turnIndex++;
        return IsInCheck(CurrentPlayer.Color)
            ? MoveResult.Check()
            : MoveResult.Success();
    }

    private bool IsInCheck(Color color) {
        var king = FindKing(color);
        var opponent = color == Color.White ? Color.Black : Color.White;
        return Board.AllPieces(opponent).Any(p => p.CanMoveTo(king.Position, Board));
    }

    private King FindKing(Color color) =>
        Board.AllPieces(color).OfType<King>().First();
}
```

---

# 11. LLD Design Problems — Splitwise & BookMyShow

---

## 11.1 Design Splitwise (Expense Splitting)

> **SOLID applied:** SRP (Expense, Settlement, User each own their logic) · OCP (new split strategies via Strategy) · DIP (services depend on interfaces)

### Requirements
- Add expense with equal/unequal/percentage split
- Track who owes whom
- Settle a debt
- Show balance summary per user
- Support groups

### Class Diagram
```
User
  ├── Id, Name, Email
  └── GetBalance() → Dictionary<User, decimal>

Group
  ├── Id, Name
  ├── Members: List<User>
  ├── Expenses: List<Expense>
  └── AddExpense(Expense)

Expense
  ├── Id, Description, Amount, PaidBy, CreatedAt
  ├── Splits: List<Split>
  └── SplitStrategy: ISplitStrategy

ISplitStrategy
  ├── EqualSplitStrategy
  ├── ExactSplitStrategy
  └── PercentageSplitStrategy

Split
  ├── User, Amount
  └── (owes Amount to PaidBy)

BalanceSheet (service)
  ├── GetUserBalance(userId) → Dictionary<User, decimal>
  └── SimplifyDebts(groupId) → List<Settlement>
```

### Core Implementation
```csharp
// STEP 1: Split Strategies (Strategy Pattern + OCP)
public interface ISplitStrategy
{
    List<Split> CalculateSplits(decimal totalAmount, List<User> participants, decimal[]? customAmounts = null);
}

public class EqualSplitStrategy : ISplitStrategy
{
    public List<Split> CalculateSplits(decimal total, List<User> participants, decimal[]? _ = null)
    {
        var perPerson = Math.Round(total / participants.Count, 2);
        var splits    = participants.Select(u => new Split(u, perPerson)).ToList();

        // Fix rounding: last person absorbs remainder
        var diff = total - splits.Sum(s => s.Amount);
        splits[^1] = splits[^1] with { Amount = splits[^1].Amount + diff };
        return splits;
    }
}

public class PercentageSplitStrategy : ISplitStrategy
{
    public List<Split> CalculateSplits(decimal total, List<User> participants, decimal[]? percentages)
    {
        if (percentages is null || percentages.Length != participants.Count)
            throw new ArgumentException("Percentages count must match participants count");
        if (percentages.Sum() != 100)
            throw new ArgumentException("Percentages must sum to 100");

        return participants.Zip(percentages)
            .Select(pair => new Split(pair.First, Math.Round(total * pair.Second / 100, 2)))
            .ToList();
    }
}

public class ExactSplitStrategy : ISplitStrategy
{
    public List<Split> CalculateSplits(decimal total, List<User> participants, decimal[]? exactAmounts)
    {
        if (exactAmounts is null || exactAmounts.Sum() != total)
            throw new ArgumentException("Exact amounts must sum to total");
        return participants.Zip(exactAmounts)
            .Select(pair => new Split(pair.First, pair.Second))
            .ToList();
    }
}

// STEP 2: Domain models
public record User(Guid Id, string Name, string Email);
public record Split(User User, decimal Amount);

public class Expense
{
    public Guid             Id          { get; init; } = Guid.NewGuid();
    public string           Description { get; init; } = "";
    public decimal          Amount      { get; init; }
    public User             PaidBy      { get; init; } = null!;
    public List<Split>      Splits      { get; init; } = [];
    public DateTimeOffset   CreatedAt   { get; init; } = DateTimeOffset.UtcNow;
}

public class Group
{
    public Guid          Id       { get; init; } = Guid.NewGuid();
    public string        Name     { get; init; } = "";
    public List<User>    Members  { get; }       = [];
    public List<Expense> Expenses { get; }       = [];

    public Expense AddExpense(
        string description, decimal amount, User paidBy,
        ISplitStrategy strategy, List<User>? participants = null,
        decimal[]? customAmounts = null)
    {
        var among  = participants ?? Members;
        var splits = strategy.CalculateSplits(amount, among, customAmounts);

        var expense = new Expense
        {
            Description = description,
            Amount      = amount,
            PaidBy      = paidBy,
            Splits      = splits
        };

        Expenses.Add(expense);
        return expense;
    }
}

// STEP 3: Balance calculation (SRP)
public class BalanceService
{
    // Returns: positive = owed TO this user; negative = this user OWES
    public Dictionary<Guid, decimal> GetUserBalance(Group group, User user)
    {
        var balances = new Dictionary<Guid, decimal>();

        foreach (var expense in group.Expenses)
        {
            foreach (var split in expense.Splits)
            {
                if (split.User.Id == expense.PaidBy.Id) continue; // payer doesn't owe themselves

                if (expense.PaidBy.Id == user.Id)
                {
                    // user paid → others owe user
                    balances.TryAdd(split.User.Id, 0);
                    balances[split.User.Id] += split.Amount;
                }
                else if (split.User.Id == user.Id)
                {
                    // user is split participant → user owes payer
                    balances.TryAdd(expense.PaidBy.Id, 0);
                    balances[expense.PaidBy.Id] -= split.Amount;
                }
            }
        }

        return balances;
    }

    // Simplify debts: minimize transactions using greedy net balance approach
    public List<(User From, User To, decimal Amount)> SimplifyDebts(Group group)
    {
        // Calculate net balance per user
        var net = new Dictionary<Guid, decimal>();
        foreach (var member in group.Members) net[member.Id] = 0;

        foreach (var expense in group.Expenses)
            foreach (var split in expense.Splits.Where(s => s.User.Id != expense.PaidBy.Id))
            {
                net[expense.PaidBy.Id] += split.Amount;  // payer gains
                net[split.User.Id]     -= split.Amount;  // participant owes
            }

        // Greedy: match biggest creditor with biggest debtor
        var creditors = net.Where(kv => kv.Value > 0).OrderByDescending(kv => kv.Value).ToList();
        var debtors   = net.Where(kv => kv.Value < 0).OrderBy(kv => kv.Value).ToList();
        var userMap   = group.Members.ToDictionary(u => u.Id);
        var result    = new List<(User, User, decimal)>();

        int i = 0, j = 0;
        while (i < creditors.Count && j < debtors.Count)
        {
            var cred = creditors[i];
            var debt = debtors[j];
            var amt  = Math.Min(cred.Value, -debt.Value);

            result.Add((userMap[debt.Key], userMap[cred.Key], amt));

            creditors[i] = new KeyValuePair<Guid, decimal>(cred.Key, cred.Value - amt);
            debtors[j]   = new KeyValuePair<Guid, decimal>(debt.Key, debt.Value + amt);

            if (creditors[i].Value == 0) i++;
            if (debtors[j].Value == 0) j++;
        }

        return result;
    }
}

// STEP 4: Usage
var alice = new User(Guid.NewGuid(), "Alice", "alice@test.com");
var bob   = new User(Guid.NewGuid(), "Bob",   "bob@test.com");
var carol = new User(Guid.NewGuid(), "Carol", "carol@test.com");

var group = new Group { Name = "Trip to Goa" };
group.Members.AddRange([alice, bob, carol]);

// Alice pays 3000 split equally among 3
group.AddExpense("Hotel", 3000, alice, new EqualSplitStrategy());

// Bob pays 600 split by percentage 50/30/20
group.AddExpense("Dinner", 600, bob, new PercentageSplitStrategy(),
    customAmounts: [50, 30, 20]);

var svc       = new BalanceService();
var debts     = svc.SimplifyDebts(group);
foreach (var (from, to, amt) in debts)
    Console.WriteLine($"{from.Name} owes {to.Name}: ₹{amt:F2}");
```

### Extensibility Discussion
```
Adding new split type (e.g., share-based split where different members have different weights):
✅ Create ShareSplitStrategy : ISplitStrategy — zero changes to existing code (OCP)

Adding multi-currency:
✅ Expense gets Currency property; BalanceService converts using ICurrencyConverter

Adding settlement tracking:
✅ New Settlement entity, SettlementService — no changes to existing expense logic (SRP)
```

---

## 11.2 Design BookMyShow (Ticket Booking)

> **SOLID applied:** SRP (Seat, Show, Booking each own their logic) · LSP (OnlineSeat, VIPSeat substitutable for Seat) · DIP (BookingService depends on ISeatRepository)

### Requirements
- Browse movies, shows, theatres
- View available seats
- Book 1–6 seats per transaction
- Hold seats for 10 minutes during payment
- Prevent double booking (concurrent users)
- Different seat categories (Regular, Premium, VIP)

### Class Diagram
```
Movie
  ├── Id, Title, Duration, Genre, Rating
  └── Shows: List<Show>

Theatre
  ├── Id, Name, Location
  └── Screens: List<Screen>

Screen
  ├── Id, Name, TotalSeats
  └── Seats: List<Seat>

Show
  ├── Id, Movie, Screen, StartTime, Date
  ├── ShowSeats: List<ShowSeat>
  └── GetAvailableSeats() → List<ShowSeat>

ShowSeat
  ├── Id, Seat, Show, Category, Price
  ├── Status: Available | Held | Booked
  ├── HeldBy: userId (nullable)
  ├── HeldUntil: DateTime (nullable)
  └── IsAvailable() → bool

Seat
  ├── Id, Row, Number
  └── (physical seat in screen)

Booking
  ├── Id, User, Show, Seats, TotalAmount
  ├── Status: Pending | Confirmed | Cancelled
  └── Payment: Payment

SeatHoldService
  └── HoldSeatsAsync(showId, seatIds, userId) → HoldResult

BookingService
  ├── HoldSeats()
  ├── ConfirmBooking()
  └── CancelBooking()
```

### Core Implementation
```csharp
// STEP 1: Domain entities
public enum SeatStatus { Available, Held, Booked }
public enum SeatCategory { Regular, Premium, VIP }

public class ShowSeat
{
    public Guid         Id         { get; init; } = Guid.NewGuid();
    public Guid         ShowId     { get; init; }
    public int          Row        { get; init; }
    public int          Number     { get; init; }
    public SeatCategory Category   { get; set; }
    public decimal      Price      { get; set; }
    public SeatStatus   Status     { get; set; } = SeatStatus.Available;
    public Guid?        HeldByUser { get; set; }
    public DateTime?    HeldUntil  { get; set; }

    public bool IsAvailable() =>
        Status == SeatStatus.Available ||
        (Status == SeatStatus.Held && HeldUntil < DateTime.UtcNow); // expired hold

    public void Hold(Guid userId, TimeSpan duration)
    {
        if (!IsAvailable()) throw new SeatNotAvailableException($"Seat {Row}{Number} is not available");
        Status     = SeatStatus.Held;
        HeldByUser = userId;
        HeldUntil  = DateTime.UtcNow.Add(duration);
    }

    public void Book()
    {
        if (Status != SeatStatus.Held) throw new InvalidOperationException("Seat must be held before booking");
        Status     = SeatStatus.Booked;
        HeldByUser = null;
        HeldUntil  = null;
    }

    public void Release()
    {
        Status     = SeatStatus.Available;
        HeldByUser = null;
        HeldUntil  = null;
    }
}

// STEP 2: Booking service with concurrency control
public class BookingService
{
    private readonly AppDbContext _db;
    private readonly IPaymentService _paymentService;
    private readonly IDistributedLockFactory _lockFactory;

    public async Task<HoldResult> HoldSeatsAsync(
        Guid showId, List<Guid> seatIds, Guid userId)
    {
        if (seatIds.Count is < 1 or > 6)
            throw new ArgumentException("Must select 1–6 seats");

        // Acquire distributed lock per show — prevents race conditions
        await using var @lock = await _lockFactory.CreateLockAsync(
            $"show-booking:{showId}",
            expiry: TimeSpan.FromSeconds(10));

        if (!@lock.IsAcquired)
            throw new ServiceUnavailableException("Booking system busy, please retry");

        await using var tx = await _db.Database.BeginTransactionAsync(
            IsolationLevel.Serializable); // strongest isolation

        var seats = await _db.ShowSeats
            .Where(s => s.ShowId == showId && seatIds.Contains(s.Id))
            .ToListAsync();

        // Validate all seats available
        var unavailable = seats.Where(s => !s.IsAvailable()).ToList();
        if (unavailable.Any())
            throw new SeatsUnavailableException(unavailable.Select(s => $"{s.Row}{s.Number}").ToList());

        // Hold all seats atomically
        foreach (var seat in seats)
            seat.Hold(userId, TimeSpan.FromMinutes(10));

        // Create pending booking
        var booking = new Booking
        {
            Id          = Guid.NewGuid(),
            UserId      = userId,
            ShowId      = showId,
            SeatIds     = seatIds,
            TotalAmount = seats.Sum(s => s.Price),
            Status      = BookingStatus.Pending,
            ExpiresAt   = DateTime.UtcNow.AddMinutes(10)
        };
        _db.Bookings.Add(booking);
        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        return new HoldResult(booking.Id, booking.TotalAmount, booking.ExpiresAt);
    }

    public async Task<BookingConfirmation> ConfirmBookingAsync(
        Guid bookingId, PaymentDetails payment)
    {
        await using var tx = await _db.Database.BeginTransactionAsync();

        var booking = await _db.Bookings
            .Include(b => b.ShowSeats)
            .FirstOrDefaultAsync(b => b.Id == bookingId)
            ?? throw new NotFoundException("Booking not found");

        if (booking.Status != BookingStatus.Pending)
            throw new InvalidOperationException("Booking is no longer pending");

        if (booking.ExpiresAt < DateTime.UtcNow)
        {
            // Hold expired — release seats
            foreach (var seat in booking.ShowSeats) seat.Release();
            booking.Status = BookingStatus.Expired;
            await _db.SaveChangesAsync();
            await tx.CommitAsync();
            throw new BookingExpiredException("Seat hold expired. Please rebook.");
        }

        // Process payment
        var paymentResult = await _paymentService.ChargeAsync(
            booking.TotalAmount, payment, idempotencyKey: $"booking:{bookingId}");

        // Confirm seats
        foreach (var seat in booking.ShowSeats) seat.Book();

        booking.Status    = BookingStatus.Confirmed;
        booking.PaymentId = paymentResult.TransactionId;

        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        return new BookingConfirmation(
            bookingId, booking.ShowSeats.Select(s => $"{s.Row}{s.Number}").ToList(),
            booking.TotalAmount, paymentResult.TransactionId);
    }

    // Background job: release expired holds every minute
    public async Task ReleaseExpiredHoldsAsync()
    {
        var expiredSeats = await _db.ShowSeats
            .Where(s => s.Status == SeatStatus.Held && s.HeldUntil < DateTime.UtcNow)
            .ToListAsync();

        foreach (var seat in expiredSeats) seat.Release();

        var expiredBookings = await _db.Bookings
            .Where(b => b.Status == BookingStatus.Pending && b.ExpiresAt < DateTime.UtcNow)
            .ToListAsync();

        foreach (var b in expiredBookings) b.Status = BookingStatus.Expired;

        await _db.SaveChangesAsync();
    }
}

// STEP 3: Pricing strategy (Strategy Pattern)
public interface IPricingStrategy
{
    decimal CalculatePrice(SeatCategory category, Show show);
}

public class PeakHourPricingStrategy : IPricingStrategy
{
    private static readonly Dictionary<SeatCategory, decimal> BasePrices = new()
    {
        [SeatCategory.Regular] = 200m,
        [SeatCategory.Premium] = 350m,
        [SeatCategory.VIP]     = 600m
    };

    public decimal CalculatePrice(SeatCategory category, Show show)
    {
        var base_price = BasePrices[category];
        var isPeakHour = show.StartTime.Hour is >= 18 and <= 22;
        var isWeekend  = show.Date.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday;
        var multiplier = (isPeakHour ? 1.3m : 1.0m) * (isWeekend ? 1.2m : 1.0m);
        return Math.Round(base_price * multiplier, 0);
    }
}
```

### Extensibility Discussion
```
Add new seat type (ReclineSeat):
✅ Add ReclineSeat to SeatCategory enum + update pricing strategy — no booking logic changes (OCP)

Add group booking discount:
✅ New DiscountStrategy interface: GroupDiscountStrategy, PromoCodeStrategy
   BookingService.ConfirmBooking applies strategy before charging (SRP)

Add waitlist for sold-out shows:
✅ New WaitlistEntry entity + WaitlistService
   When a booking is cancelled, WaitlistService notified via event (Observer)
   Zero changes to BookingService (OCP)

Concurrent booking prevention:
✅ Distributed lock (Redis RedLock) per show during seat selection window
   OR: Optimistic concurrency on ShowSeat.RowVersion
```

---
