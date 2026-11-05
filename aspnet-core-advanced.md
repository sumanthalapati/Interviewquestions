# ASP.NET Core Advanced Topics

Complete guide to advanced patterns and technologies: Entity Framework Core, SignalR real-time, task scheduling, observability, and deployment.

---

## Table of Contents
1. [Entity Framework Core](#ef-core)
2. [Performance & Caching](#performance)
3. [SignalR (Real-Time)](#signalr)
4. [Background Jobs & Scheduling](#background-jobs)
5. [Event-Driven Architecture](#events)
6. [Logging & Observability](#observability)
7. [Building & Deploying](#deployment)
8. [Applied Advanced ASP.NET Core](#aspx-mastery)

---

<a id="ef-core"></a>
## Entity Framework Core

### What is EF Core?

**ORM (Object-Relational Mapping)**: Maps database tables to C# classes

```csharp
// Database table
CREATE TABLE Users (
    Id INT PRIMARY KEY,
    Name NVARCHAR(100),
    Email NVARCHAR(100)
);

// C# class (entity)
public class User
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string Email { get; set; }
}

// Query using LINQ
var user = dbContext.Users
    .Where(u => u.Email == "alice@example.com")
    .FirstOrDefault();

// EF Core translates to SQL:
// SELECT * FROM Users WHERE Email = 'alice@example.com'
```

### DbContext

```csharp
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    
    // Map tables
    public DbSet<User> Users { get; set; }
    public DbSet<Post> Posts { get; set; }
    public DbSet<Comment> Comments { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Configure relationships
        modelBuilder.Entity<Post>()
            .HasMany(p => p.Comments)
            .WithOne(c => c.Post)
            .HasForeignKey(c => c.PostId);
        
        // Configure constraints
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();
        
        base.OnModelCreating(modelBuilder);
    }
}

// Register in Program.cs
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"))
);
```

### Relationships

```csharp
// One-to-Many: User has many Posts
public class User
{
    public int Id { get; set; }
    public string Name { get; set; }
    
    // Navigation property
    public ICollection<Post> Posts { get; set; }
}

public class Post
{
    public int Id { get; set; }
    public string Title { get; set; }
    public int UserId { get; set; }  // Foreign key
    
    // Navigation property
    public User User { get; set; }
}

// Query with relationship
var user = dbContext.Users
    .Include(u => u.Posts)  // Eager load posts
    .FirstOrDefault(u => u.Id == 1);

// Access related data
foreach (var post in user.Posts)
{
    Console.WriteLine(post.Title);
}
```

### Change Tracking & SaveChanges

```csharp
public async Task<User> UpdateUserAsync(int id, UpdateUserRequest request)
{
    // Retrieve user (tracked by context)
    var user = await dbContext.Users.FindAsync(id);
    
    // Modify properties
    user.Name = request.Name;
    user.Email = request.Email;
    
    // SaveChanges detects changes, generates UPDATE query
    // UPDATE Users SET Name = @Name, Email = @Email WHERE Id = @Id
    await dbContext.SaveChangesAsync();
    
    return user;
}
```

### Migrations

```bash
# Create migration
dotnet ef migrations add InitialCreate

# Apply migration (runs Up() method)
dotnet ef database update

# Rollback migration (runs Down() method)
dotnet ef database update PreviousMigration

# Generate SQL script
dotnet ef migrations script
```

**Migration File**
```csharp
public partial class AddUserTable : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Users",
            columns: table => new
            {
                Id = table.Column<int>(nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Name = table.Column<string>(maxLength: 100, nullable: false),
                Email = table.Column<string>(maxLength: 100, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Users", x => x.Id);
            });
    }
    
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Users");
    }
}
```

### Common Pitfalls

**N+1 Query Problem**
```csharp
// ❌ N+1 queries: 1 for users, 1 per user for posts
var users = dbContext.Users.ToList();  // 1 query
foreach (var user in users)
{
    var posts = user.Posts.ToList();   // N queries (one per user)
}

// ✅ Fix: Eager load
var users = dbContext.Users
    .Include(u => u.Posts)
    .ToList();  // 1 query with join
```

**Lazy Loading Issues**
```csharp
// ❌ Detached entity (outside DbContext)
public UserDto GetUser(int id)
{
    var user = dbContext.Users.FirstOrDefault(u => u.Id == id);
    dbContext.SaveChanges();  // Context disposed here
    
    return new UserDto { /* map user */ };
}  // User object still needs Posts loaded, but context gone

// ✅ Fix: Project to DTO
public UserDto GetUser(int id)
{
    return dbContext.Users
        .Where(u => u.Id == id)
        .Select(u => new UserDto
        {
            Id = u.Id,
            Name = u.Name,
            PostCount = u.Posts.Count
        })
        .FirstOrDefault();
}
```

---

<a id="performance"></a>
## Performance & Caching

### Query Optimization

```csharp
// ❌ Slow: IEnumerable (client-side filtering)
var users = dbContext.Users
    .ToList()  // Fetch all users from database
    .Where(u => u.Email.Contains("@gmail.com"))  // Filter in memory
    .Take(10)
    .ToList();

// ✅ Fast: IQueryable (database-side filtering)
var users = dbContext.Users
    .Where(u => u.Email.Contains("@gmail.com"))  // Filtered in database
    .Take(10)
    .ToList();  // Only fetch 10
```

### Async Operations

```csharp
// Always use async for database operations
public async Task<List<UserDto>> GetUsersAsync()
{
    var users = await dbContext.Users
        .AsNoTracking()  // Don't track (faster for reads)
        .Select(u => new UserDto { Id = u.Id, Name = u.Name })
        .ToListAsync();
    
    return users;
}
```

### Caching with EF Core

```csharp
public class UserService
{
    private readonly AppDbContext _dbContext;
    private readonly IMemoryCache _cache;
    
    public async Task<UserDto> GetUserAsync(int id)
    {
        var cacheKey = $"user_{id}";
        
        if (_cache.TryGetValue(cacheKey, out UserDto cachedUser))
            return cachedUser;
        
        // Not cached, fetch from database
        var user = await _dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == id);
        
        // Cache for 10 minutes
        _cache.Set(cacheKey, user, TimeSpan.FromMinutes(10));
        return user;
    }
}
```

---

<a id="signalr"></a>
## SignalR (Real-Time)

### What is SignalR?

**Framework for real-time bidirectional communication (Server ↔ Client)**

```
WebSocket (preferred) / SSE / Long Polling
         ↓
SignalR (abstraction over transport)
         ↓
Server Push (send without request)
```

### Hub (Server-Side)

```csharp
public class ChatHub : Hub
{
    public async Task SendMessage(string user, string message)
    {
        // Broadcast to all connected clients
        await Clients.All.SendAsync("ReceiveMessage", user, message);
    }
    
    public async Task SendMessageToUser(string userId, string message)
    {
        // Send to specific user
        await Clients.User(userId).SendAsync("ReceiveMessage", message);
    }
    
    public async Task JoinGroup(string groupName)
    {
        // Add current connection to group
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
        
        // Notify group
        await Clients.Group(groupName).SendAsync("UserJoined", Context.User.Identity.Name);
    }
    
    public override async Task OnConnectedAsync()
    {
        await base.OnConnectedAsync();
        // User connected
    }
    
    public override async Task OnDisconnectedAsync(Exception exception)
    {
        await base.OnDisconnectedAsync(exception);
        // User disconnected
    }
}

// Register in Program.cs
builder.Services.AddSignalR();

app.MapHub<ChatHub>("/chathub");
```

### Client-Side (JavaScript)

```javascript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .withAutomaticReconnect()
    .build();

// Handle server messages
connection.on("ReceiveMessage", (user, message) => {
    const div = document.createElement("div");
    div.textContent = `${user}: ${message}`;
    document.getElementById("messagesList").appendChild(div);
});

// Send message to server
document.getElementById("sendButton").addEventListener("click", async () => {
    const message = document.getElementById("messageInput").value;
    await connection.invoke("SendMessage", "alice", message);
});

// Start connection
connection.start();
```

### Broadcasting Scenarios

```csharp
// Send to all except caller
await Clients.AllExcept(Context.ConnectionId).SendAsync(...);

// Send to group
await Clients.Group("group_name").SendAsync(...);

// Send to specific user
await Clients.User(userId).SendAsync(...);

// Send to caller only
await Clients.Caller.SendAsync(...);
```

---

<a id="background-jobs"></a>
## Background Jobs & Scheduling

### Hangfire (Job Queue)

```csharp
// Program.cs
builder.Services.AddHangfire(configuration =>
{
    configuration.UseSqlServerStorage(builder.Configuration.GetConnectionString("DefaultConnection"));
});

builder.Services.AddHangfireServer();

app.UseHangfireDashboard();  // UI at /hangfire

// Enqueue job
BackgroundJob.Enqueue(() => Console.WriteLine("Hello!"));

// Schedule job
BackgroundJob.Schedule(
    () => SendEmailAsync("user@example.com"),
    TimeSpan.FromMinutes(5)
);

// Recurring job
RecurringJob.AddOrUpdate(
    "send-daily-report",
    () => SendReportAsync(),
    Cron.Daily(9, 0)
);
```

### Service with Scheduled Tasks

```csharp
public class NotificationService
{
    public async Task SendEmailAsync(string email, string subject, string body)
    {
        // Send email asynchronously
        await _smtpClient.SendAsync(new MailMessage
        {
            To = { email },
            Subject = subject,
            Body = body
        });
    }
    
    public async Task SendDailyReportAsync()
    {
        var report = await GenerateReportAsync();
        await SendEmailAsync("admin@example.com", "Daily Report", report);
    }
}

// Register
builder.Services.AddScoped<NotificationService>();

// Use Hangfire to schedule
RecurringJob.AddOrUpdate<NotificationService>(
    "daily-report",
    x => x.SendDailyReportAsync(),
    Cron.Daily(9, 0)
);
```

---

<a id="events"></a>
## Event-Driven Architecture

### Domain Events

```csharp
// Event class
public class UserCreatedEvent : IDomainEvent
{
    public int UserId { get; set; }
    public string Email { get; set; }
    public DateTime CreatedAt { get; set; }
}

// Entity publishes event
public class User
{
    public int Id { get; set; }
    public string Email { get; set; }
    
    // Domain events list
    public List<IDomainEvent> DomainEvents { get; set; } = new();
    
    public static User Create(string email)
    {
        var user = new User { Email = email };
        user.DomainEvents.Add(new UserCreatedEvent { UserId = user.Id, Email = email });
        return user;
    }
}

// Handler (execute when event published)
public class UserCreatedEventHandler : INotificationHandler<UserCreatedEvent>
{
    private readonly IEmailService _emailService;
    
    public async Task Handle(UserCreatedEvent notification, CancellationToken cancellationToken)
    {
        // Send welcome email
        await _emailService.SendWelcomeEmailAsync(notification.Email);
    }
}

// Service publishes event
public class UserService
{
    private readonly AppDbContext _dbContext;
    private readonly IMediator _mediator;
    
    public async Task CreateUserAsync(CreateUserRequest request)
    {
        var user = User.Create(request.Email);
        _dbContext.Users.Add(user);
        
        await _dbContext.SaveChangesAsync();
        
        // Publish domain events
        foreach (var @event in user.DomainEvents)
        {
            await _mediator.Publish(@event);
        }
    }
}
```

---

<a id="observability"></a>
## Logging & Observability

### Structured Logging

```csharp
public class UserService
{
    private readonly ILogger<UserService> _logger;
    
    public async Task<User> GetUserAsync(int id)
    {
        _logger.LogInformation("Getting user with ID {UserId}", id);
        
        var user = await _repository.GetUserAsync(id);
        
        if (user == null)
        {
            _logger.LogWarning("User with ID {UserId} not found", id);
            return null;
        }
        
        _logger.LogInformation("User {UserId} retrieved successfully", id);
        return user;
    }
}

// Output (searchable):
// Getting user with ID 123
// User 123 retrieved successfully
// Can search by UserId = 123
```

### OpenTelemetry (Observability)

```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddSqlClientInstrumentation()
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://localhost:4317");
            });
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter();
    });

// Automatic tracing of:
// - HTTP requests
// - Database queries
// - External API calls
// - Metrics (request count, duration, errors)
```

---

<a id="deployment"></a>
## Building & Deploying

### Docker

```dockerfile
# Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copy and restore
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o out

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/out .

ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### GitHub Actions CI/CD

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '8.0.x'
    
    - name: Restore dependencies
      run: dotnet restore
    
    - name: Build
      run: dotnet build --configuration Release
    
    - name: Test
      run: dotnet test --configuration Release
    
    - name: Publish
      run: dotnet publish -c Release -o publish
    
    - name: Deploy to Azure
      run: |
        az webapp deployment source config-zip \
          --resource-group mygroup \
          --name myapp \
          --src-path publish.zip
```

### appsettings by Environment

```
appsettings.json (base settings)
appsettings.Development.json (dev overrides)
appsettings.Production.json (prod overrides)

// Program.cs loads based on ASPNETCORE_ENVIRONMENT
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/error");
}
```

---

**Key Takeaway**: Master EF Core for data access, SignalR for real-time features, background jobs for async work, and observability for production readiness.

---

<a id="aspx-mastery"></a>
# Applied Advanced ASP.NET Core

These walkthroughs cover work that outlives a request, real-time reconnect behavior, useful telemetry, and safe orchestration during startup and shutdown.

References: [hosted services](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services), [SignalR groups](https://learn.microsoft.com/en-us/aspnet/core/signalr/groups), and [health checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks).

## ASPX-M1 — Queue Background Work with Backpressure and Fresh Scopes

**Question:** Why is `Task.Run` inside a controller unsafe for important background work?

**Answer:** The task is not owned by the host, may capture request-scoped services that are disposed when the response ends, has no durable retry, and can grow without a capacity limit. A bounded queue and hosted worker give the process explicit ownership and backpressure.

**What problem does it solve?** It prevents lost fire-and-forget work, disposed `DbContext` access, unbounded memory growth, and shutdown that abandons in-flight jobs silently.

**Before this concept:**

❌ **Wrong/before example:**

```csharp
[HttpPost("reports")]
public IActionResult CreateReport(CreateReport request)
{
    _ = Task.Run(async () =>
    {
        db.Reports.Add(await generator.Build(request)); // captures scoped db
        await db.SaveChangesAsync();
    });

    return Accepted();
}
```

✅ **After/correct example:**

```csharp
public sealed record ReportJob(Guid JobId, Guid TenantId, CreateReport Request);

public sealed class ReportJobQueue
{
    private readonly Channel<ReportJob> channel = Channel.CreateBounded<ReportJob>(
        new BoundedChannelOptions(500)
        {
            FullMode = BoundedChannelFullMode.Wait,
            SingleReader = true,
            SingleWriter = false
        });

    public bool TryEnqueue(ReportJob job) => channel.Writer.TryWrite(job);
    public IAsyncEnumerable<ReportJob> ReadAll(CancellationToken ct) =>
        channel.Reader.ReadAllAsync(ct);
}

public sealed class ReportWorker(
    ReportJobQueue queue,
    IServiceScopeFactory scopeFactory,
    ILogger<ReportWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var job in queue.ReadAll(stoppingToken))
        {
            try
            {
                await using var scope = scopeFactory.CreateAsyncScope();
                var processor = scope.ServiceProvider.GetRequiredService<ReportProcessor>();
                await processor.Process(job, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Report job {JobId} failed", job.JobId);
            }
        }
    }
}

builder.Services.AddSingleton<ReportJobQueue>();
builder.Services.AddScoped<ReportProcessor>();
builder.Services.AddHostedService<ReportWorker>();
```

```csharp
app.MapPost("/reports", (CreateReport request, ReportJobQueue queue, ClaimsPrincipal user) =>
{
    var job = new ReportJob(Guid.NewGuid(), user.GetRequiredTenantId(), request);
    return queue.TryEnqueue(job)
        ? Results.Accepted($"/reports/{job.JobId}", new { job.JobId })
        : Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
});
```

**How it works now:** The bounded channel limits memory and exposes overload. The host starts and stops the worker. Each job creates a fresh DI scope, so `DbContext` and other scoped services are valid only for that unit of work.

**Trade-offs and when not to use it:** An in-memory queue loses queued jobs when the process crashes and cannot coordinate several replicas. Use a durable broker/database queue when work must survive restarts or scale across instances. With `Wait`, `TryWrite` returns `false` when the bounded queue is full, so this API rejects immediately; an alternative producer can call `WriteAsync` when it is safe to wait for capacity.

**Production checks:** Persist job status, make processing idempotent, define retry and poison-job behavior, monitor queue depth/oldest age, and ensure shutdown time allows safe checkpointing.

**Try it:** Fill the queue to capacity, restart the process during a job, and document exactly which work is accepted, rejected, completed, or lost.

---

## ASPX-M2 — Treat SignalR as Live Delivery, Not Durable History

**Question:** How should a SignalR client recover messages and group membership after reconnecting?

**Answer:** Store important events durably with a sequence number. SignalR delivers the live notification; after reconnect, the client reauthorizes and rejoins groups, then requests events after its last confirmed sequence.

**What problem does it solve?** It prevents silent gaps caused by transient connections, server restarts, mobile network changes, or group membership that is not preserved across a new connection.

**Before this concept:** The server broadcasts an important update only through a hub and assumes connected clients receive it exactly once.

❌ **Wrong/before example:**

```csharp
await hub.Clients.Group($"order:{order.Id}")
    .SendAsync("OrderChanged", order.Status, ct);
// No durable event: disconnected clients can never recover this transition.
```

✅ **After/correct example:**

```csharp
var notification = OrderNotification.Create(
    order.TenantId, order.Id, order.NextSequence(), "status-changed", order.Status);

db.OrderNotifications.Add(notification);
await db.SaveChangesAsync(ct); // durable history first

await hub.Clients.Group($"order:{order.Id}").SendAsync(
    "OrderChanged",
    new { notification.Sequence, notification.Type, notification.Payload },
    ct);
```

```csharp
[Authorize]
public sealed class OrdersHub(
    IOrderReader orders,
    IAuthorizationService authorization) : Hub
{
    public async Task JoinOrder(Guid orderId)
    {
        var tenantId = Context.User!.GetRequiredTenantId();
        var order = await orders.Find(tenantId, orderId, Context.ConnectionAborted)
            ?? throw new HubException("Order not found");

        var result = await authorization.AuthorizeAsync(
            Context.User, order, new ViewOrderRequirement());
        if (!result.Succeeded) throw new HubException("Forbidden");

        await Groups.AddToGroupAsync(Context.ConnectionId, $"order:{orderId}");
    }
}
```

```typescript
connection.onreconnected(async () => {
  await connection.invoke('JoinOrder', orderId);
  const missed = await api.getNotifications(orderId, lastSequence);
  for (const event of missed) applyInSequence(event);
});
```

**How it works now:** The database is the recoverable source. SignalR reduces latency for connected clients. Reconnect creates a new transport context, repeats authorization/group joining, and fills sequence gaps through an ordinary API.

**Trade-offs and when not to use it:** Presence and typing indicators may be safely ephemeral and need no durable history. Durable event streams require retention, pagination, deduplication, and an ordering scope such as one order or conversation.

**Production checks:** Never treat a group as an authorization boundary, remove/revalidate access when permissions change, test out-of-order/duplicate events, and use a scale-out service/backplane when several app instances host connections.

**Try it:** Disconnect a client, publish three updates, reconnect it to a different server instance, and prove it converges without duplicating effects.

---

## ASPX-M3 — Correlate Logs, Traces, and Metrics

**Question:** What telemetry should one order request produce?

**Answer:** Emit a trace for causality and latency, structured logs for discrete diagnostic facts, and low-cardinality metrics for aggregate health. Share correlation context automatically and avoid identifiers or error messages as metric dimensions.

**What problem does it solve?** Operators can move from “latency is high” to the responsible dependency and then to the relevant structured events without searching unrelated text logs.

**Before this concept:**

❌ **Wrong/before example:**

```csharp
logger.LogInformation("Starting order " + order.Id + " for " + customer.Email);
logger.LogInformation("Finished");
// No duration, trace relationship, outcome, or safe aggregation.
```

✅ **After/correct example:**

```csharp
public static class OrderTelemetry
{
    public static readonly ActivitySource ActivitySource = new("Store.Orders");
    public static readonly Meter Meter = new("Store.Orders");
    public static readonly Counter<long> Completed = Meter.CreateCounter<long>("orders.completed");
    public static readonly Histogram<double> Duration =
        Meter.CreateHistogram<double>("orders.create.duration", "ms");
}

public async Task<Result<OrderId>> Place(CreateOrder command, CancellationToken ct)
{
    using var activity = OrderTelemetry.ActivitySource.StartActivity("orders.place");
    activity?.SetTag("order.channel", command.Channel); // bounded vocabulary
    var started = Stopwatch.GetTimestamp();

    try
    {
        var result = await handler.Handle(command, ct);
        var outcome = result.IsSuccess ? "success" : "rejected";
        OrderTelemetry.Completed.Add(1,
            new KeyValuePair<string, object?>("outcome", outcome));
        activity?.SetTag("order.outcome", outcome);
        return result;
    }
    catch (Exception exception)
    {
        activity?.SetStatus(ActivityStatusCode.Error, exception.GetType().Name);
        logger.LogError(exception, "Order placement failed; TraceId={TraceId}",
            Activity.Current?.TraceId.ToString());
        throw;
    }
    finally
    {
        OrderTelemetry.Duration.Record(Stopwatch.GetElapsedTime(started).TotalMilliseconds);
    }
}
```

**How it works now:** Distributed tracing relates inbound requests, database calls, and outbound calls. Logs attach to the active trace. Metrics answer rate, error, and duration questions without storing one time series per customer or order.

**Trade-offs and when not to use it:** Recording every payload or span is expensive and unsafe. Sample high-volume traces, keep audit logs separate from diagnostic logs, and use exemplars/correlation to connect aggregates to traces.

**Production checks:** Redact personal/payment data, cap tag vocabulary, define service-level indicators from metrics, propagate trace context through messages, and alert on symptoms rather than individual exceptions.

**Try it:** Follow one request from gateway to database and background consumer using one trace ID, then answer which dependency consumed most latency.

---

## ASPX-M4 — Separate Liveness, Readiness, and Graceful Shutdown

**Question:** Why should a database outage normally fail readiness but not liveness?

**Answer:** Liveness asks whether the process is stuck and should be restarted. Readiness asks whether it can currently receive traffic. Restarting every healthy process during a shared database outage creates churn without repairing the dependency.

**What problem does it solve?** Orchestrators stop routing traffic to unready instances without turning a dependency incident into a restart storm, and rolling deployments wait until new instances are actually usable.

**Before this concept:** One `/health` endpoint checks every dependency and is used for both probes.

❌ **Wrong/before example:**

```csharp
app.MapGet("/health", async (AppDbContext db) =>
    await db.Database.CanConnectAsync()
        ? Results.Ok()
        : Results.StatusCode(500));
// The orchestrator restarts a healthy process whenever the shared DB is unavailable.
```

✅ **After/correct example:**

```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddDbContextCheck<AppDbContext>("database", tags: ["ready"]);

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live")
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

`AddDbContextCheck<TContext>` is provided by the `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` package; use the package version that matches the application target framework.

```csharp
public sealed class SubscriptionWorker : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var message in subscription.ReadAll(stoppingToken))
        {
            await ProcessIdempotently(message, stoppingToken);
            await subscription.Acknowledge(message, stoppingToken);
        }
    }
}
```

**How it works now:** The liveness probe verifies the process can answer. Readiness includes traffic-critical dependencies. During shutdown, the host cancels workers; they stop taking new work, finish or checkpoint safely, and exit before the orchestrator’s grace period ends.

**Trade-offs and when not to use it:** Deep readiness checks can overload dependencies if probed too often. A service that can operate in a degraded mode may remain ready while advertising dependency health through metrics instead.

**Production checks:** Protect detailed health output, set probe timeouts/thresholds, align host shutdown timeout with the orchestrator grace period, stop accepting traffic before termination, verify health-check package versions match the target framework, and test rolling deployment plus forced kill.

**Try it:** Disable the database and verify readiness fails while liveness stays healthy; then send termination and confirm the worker stops without acknowledging unfinished work.
