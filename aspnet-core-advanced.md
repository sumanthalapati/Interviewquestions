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

---

## Entity Framework Core {#ef-core}

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

## Performance & Caching {#performance}

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

## SignalR (Real-Time) {#signalr}

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

## Background Jobs & Scheduling {#background-jobs}

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

## Event-Driven Architecture {#events}

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

## Logging & Observability {#observability}

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

## Building & Deploying {#deployment}

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
