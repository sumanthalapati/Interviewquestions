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
