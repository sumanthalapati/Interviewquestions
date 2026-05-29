# 🟢 Entry-Level Interview Questions — All Topics

> Basics every junior-to-mid developer must know before an interview.
> Each section covers the **"must-know" fundamentals** and **common gotchas**.

---

## 📋 Table of Contents

1. [C# Fundamentals](#1-c-fundamentals)
2. [OOP Concepts](#2-oop-concepts)
3. [ASP.NET Core / Web API](#3-aspnet-core--web-api)
4. [SQL Server Basics](#4-sql-server-basics)
5. [Entity Framework Basics](#5-entity-framework-basics)
6. [JavaScript Basics](#6-javascript-basics)
7. [TypeScript Basics](#7-typescript-basics)
8. [Angular Basics](#8-angular-basics)
9. [HTML & CSS Basics](#9-html--css-basics)
10. [Design Patterns Basics](#10-design-patterns-basics)
11. [DSA Basics](#11-dsa-basics)
12. [Azure / Cloud Basics](#12-azure--cloud-basics)
13. [Git & DevOps Basics](#13-git--devops-basics)
14. [Unit Testing Basics](#14-unit-testing-basics)
15. [HLD / System Design Basics](#15-hld--system-design-basics)
16. [LLD Basics](#16-lld-basics)
17. [AI in .NET Basics](#17-ai-in-net-basics)

---

# 1. C# Fundamentals

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/

### Q1 — What is the difference between `string` and `String`?

They are the same — `string` is a C# alias for `System.String`. Convention: use `string` in code, `String` when calling static methods.

```csharp
string name = "Alice";            // ✅ C# keyword alias
String.IsNullOrEmpty(name);       // ✅ accessing static method via type
int.Parse("42");                  // ✅ alias
Int32.MaxValue;                   // ✅ type name
```

---

### Q2 — What is the difference between `==` and `.Equals()` for strings?

For strings, both compare **value** (content). For reference types, `==` checks reference equality by default unless overridden. `string` overrides `==` to compare values.

```csharp
string a = "hello";
string b = "hel" + "lo";

Console.WriteLine(a == b);        // True  — value comparison (string overrides ==)
Console.WriteLine(a.Equals(b));   // True  — value comparison
Console.WriteLine(ReferenceEquals(a, b)); // may be True or False (interning)

object x = new object();
object y = new object();
Console.WriteLine(x == y);        // False — reference equality for object
```

---

### Q3 — What is `var` and when is it appropriate?

`var` is implicitly typed — the compiler infers the type. It does NOT mean dynamic. Use it when the type is obvious from the right-hand side; avoid it when it makes code less readable.

```csharp
var name      = "Alice";          // ✅ clearly a string
var orders    = new List<Order>(); // ✅ obvious from new()
var result    = GetData();        // ❌ unclear — what type does GetData() return?

// var with LINQ — always appropriate
var filtered = orders.Where(o => o.Total > 100).ToList();
```

---

### Q4 — What is the difference between `int`, `long`, `double`, and `decimal`?

| Type | Size | Use for |
|------|------|---------|
| `int` | 32-bit | General integers, loop counters |
| `long` | 64-bit | Large numbers (IDs, timestamps) |
| `double` | 64-bit float | Scientific calculations (rounding errors OK) |
| `decimal` | 128-bit | Money, financial calculations (precise) |

```csharp
int    counter = 42;
long   userId  = 9_876_543_210L;
double pi      = 3.14159;

decimal price  = 9.99m;          // ✅ always use decimal for money
double  price2 = 9.99;           // ❌ 0.1 + 0.2 = 0.30000000000000004 in floating point!
```

---

### Q5 — What is `null` and how do you guard against `NullReferenceException`?

`null` means "no value". Accessing a member on a null reference throws `NullReferenceException` — the most common runtime error.

```csharp
// ❌ Unsafe
string name = GetName(); // might return null
Console.WriteLine(name.Length); // NullReferenceException if null

// ✅ Null-conditional operator
Console.WriteLine(name?.Length);     // null if name is null
Console.WriteLine(name?.ToUpper() ?? "Unknown"); // null-coalescing fallback

// ✅ Null check
if (name is not null)
    Console.WriteLine(name.Length);
```

---

### Q6 — What is the difference between a `struct` and a `class`?

| | `class` | `struct` |
|-|---------|----------|
| Type | Reference (heap) | Value (stack) |
| Null | Can be null | Cannot (unless `Nullable<T>`) |
| Assignment | Copies reference | Copies entire value |
| Inheritance | Yes | No (except interfaces) |
| Use for | Complex objects, entities | Small value objects (Point, Color, Money) |

```csharp
struct Point { public int X; public int Y; }
class  Order { public Guid Id; public string Status = ""; }

var p1 = new Point { X = 1, Y = 2 };
var p2 = p1;       // COPY — p2 is independent
p2.X = 99;
Console.WriteLine(p1.X); // still 1

var o1 = new Order { Id = Guid.NewGuid() };
var o2 = o1;       // REFERENCE — o2 points to same object
o2.Status = "Shipped";
Console.WriteLine(o1.Status); // "Shipped" — same object!
```

---

### Q7 — What is `static` in C#?

`static` members belong to the **type**, not an instance. No `new` required, shared across all instances.

```csharp
public class MathHelper
{
    public static double Pi = 3.14159; // shared — one copy for all

    public static double CircleArea(double r) => Pi * r * r;
}

// Usage — no new() needed
double area = MathHelper.CircleArea(5);
```

---

### Q8 — What are access modifiers?

| Modifier | Visible to |
|----------|-----------|
| `public` | Everyone |
| `private` | Same class only |
| `protected` | Same class + subclasses |
| `internal` | Same assembly |
| `protected internal` | Same assembly OR subclass |
| `private protected` | Same class AND subclass in same assembly |

```csharp
public class BankAccount
{
    public string Owner { get; }          // anyone can read
    private decimal _balance;             // only this class
    protected void Log(string msg) { }    // this + subclasses
    internal void SyncWithCore() { }      // only within this .dll
}
```

---

### Q9 — What is the difference between `const` and `readonly`?

`const` — compile-time constant, value baked into IL. `readonly` — set at runtime (constructor or initializer), then immutable.

```csharp
public class Config
{
    public const string AppName = "MyApp";        // compile-time, cannot change
    public readonly string ConnectionString;      // set once in constructor

    public Config(string cs) => ConnectionString = cs;
}
```

---

### Q10 — What is boxing and unboxing?

**Boxing** wraps a value type in an `object` (heap allocation). **Unboxing** extracts it back. Avoid in hot paths — causes GC pressure.

```csharp
int num = 42;
object boxed   = num;      // boxing   — heap allocation
int   unboxed  = (int)boxed; // unboxing — cast required

// ❌ Avoid boxing in loops
var list = new ArrayList();
for (int i = 0; i < 10000; i++)
    list.Add(i); // each int boxed!

// ✅ Use generic collections — no boxing
var list2 = new List<int>();
for (int i = 0; i < 10000; i++)
    list2.Add(i); // no boxing
```

---

# 2. OOP Concepts

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/tutorials/oop

### Q1 — What are the four pillars of OOP?

**Encapsulation** — hide internal state, expose via methods/properties.  
**Inheritance** — derive new class from existing (reuse + extend).  
**Polymorphism** — same interface, different behaviour.  
**Abstraction** — expose only what is necessary.

```csharp
// Encapsulation
public class BankAccount
{
    private decimal _balance;
    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentException("Must be positive");
        _balance += amount;
    }
    public decimal GetBalance() => _balance;
}

// Inheritance + Polymorphism
public abstract class Shape      { public abstract double Area(); }
public class Circle  : Shape     { public double Radius; public override double Area() => Math.PI * Radius * Radius; }
public class Square  : Shape     { public double Side;   public override double Area() => Side * Side; }

Shape[] shapes = [new Circle { Radius = 5 }, new Square { Side = 4 }];
foreach (var s in shapes)
    Console.WriteLine(s.Area()); // polymorphic — correct Area() called each time
```

---

### Q2 — What is the difference between an `abstract class` and an `interface`?

| | Abstract Class | Interface |
|-|---------------|-----------|
| Multiple inheritance | No (single) | Yes (multiple) |
| State (fields) | Yes | No (only default impl) |
| Constructor | Yes | No |
| Use when | Shared base with common state/code | Define a contract, no shared state |

```csharp
// Abstract class — has shared implementation
public abstract class Animal
{
    public string Name { get; set; } = "";     // shared state
    public abstract void Speak();              // must override
    public void Breathe() => Console.WriteLine("Breathing"); // shared code
}

// Interface — pure contract
public interface ISwimmable  { void Swim(); }
public interface IFlyable    { void Fly();  }

public class Duck : Animal, ISwimmable, IFlyable
{
    public override void Speak()  => Console.WriteLine("Quack");
    public void Swim()            => Console.WriteLine("Swimming");
    public void Fly()             => Console.WriteLine("Flying");
}
```

---

### Q3 — What is method overloading vs overriding?

**Overloading** — same method name, different parameters (compile-time polymorphism).  
**Overriding** — subclass replaces base class virtual method (runtime polymorphism).

```csharp
// Overloading — same name, different signatures
public class Printer
{
    public void Print(string text)          => Console.WriteLine(text);
    public void Print(int number)           => Console.WriteLine(number);
    public void Print(string text, int copies) => /* ... */;
}

// Overriding — virtual + override
public class Logger
{
    public virtual void Log(string msg) => Console.WriteLine($"[Base] {msg}");
}
public class FileLogger : Logger
{
    public override void Log(string msg) => File.AppendAllText("log.txt", msg);
}
```

---

# 3. ASP.NET Core / Web API

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/

### Q1 — What is middleware and what order does it run in?

Middleware is a chain of components that process HTTP requests and responses. Order matters — registered first runs first on request (and last on response).

```csharp
app.UseExceptionHandler();  // 1st — catches all exceptions below it
app.UseHttpsRedirection();  // 2nd
app.UseRouting();           // 3rd — must be before Authentication
app.UseAuthentication();    // 4th — reads JWT/cookie → sets User
app.UseAuthorization();     // 5th — checks User has required claims/roles
app.MapControllers();       // 6th — endpoint runs here
```

---

### Q2 — What are the HTTP methods and when do you use each?

| Method | Purpose | Body? | Safe? | Idempotent? |
|--------|---------|-------|-------|-------------|
| GET | Read | No | ✅ | ✅ |
| POST | Create | Yes | ❌ | ❌ |
| PUT | Full Replace | Yes | ❌ | ✅ |
| PATCH | Partial Update | Yes | ❌ | ❌ |
| DELETE | Remove | No | ❌ | ✅ |

```csharp
[HttpGet("{id}")]    public Task<IActionResult> Get(Guid id)     { }
[HttpPost]          public Task<IActionResult> Create(OrderDto dto) { }
[HttpPut("{id}")]   public Task<IActionResult> Replace(Guid id, OrderDto dto) { }
[HttpPatch("{id}")] public Task<IActionResult> Update(Guid id, JsonPatchDocument patch) { }
[HttpDelete("{id}")] public Task<IActionResult> Delete(Guid id)  { }
```

---

### Q3 — What are common HTTP status codes?

| Code | Meaning | When |
|------|---------|------|
| 200 OK | Success with body | GET, successful operation |
| 201 Created | Resource created | POST with Location header |
| 204 No Content | Success, no body | DELETE, PUT with no return |
| 400 Bad Request | Invalid input | Validation failure |
| 401 Unauthorized | Not authenticated | Missing/invalid JWT |
| 403 Forbidden | Authenticated but not authorised | Wrong role |
| 404 Not Found | Resource doesn't exist | ID not in DB |
| 409 Conflict | State conflict | Duplicate, optimistic concurrency |
| 500 Internal Server Error | Unhandled exception | Bug |

```csharp
public async Task<IActionResult> Get(Guid id)
{
    var order = await _svc.GetAsync(id);
    return order is null ? NotFound() : Ok(order);
}

public async Task<IActionResult> Create(CreateOrderDto dto)
{
    var id = await _svc.CreateAsync(dto);
    return CreatedAtAction(nameof(Get), new { id }, new { id }); // 201
}
```

---

### Q4 — What is Dependency Injection (DI)?

DI is a technique where dependencies are **provided from outside** the class rather than created inside it. ASP.NET Core has a built-in DI container.

```csharp
// ❌ Without DI — tightly coupled, hard to test
public class OrderController
{
    private readonly OrderService _svc = new OrderService(new SqlRepo()); // hardcoded
}

// ✅ With DI — dependencies injected via constructor
public class OrderController : ControllerBase
{
    private readonly IOrderService _svc;
    public OrderController(IOrderService svc) => _svc = svc; // injected

    // Test can inject a mock IOrderService — easy to unit test
}

// Registration in Program.cs
builder.Services.AddScoped<IOrderService, OrderService>();
```

---

### Q5 — What is the difference between `[FromBody]`, `[FromQuery]`, `[FromRoute]`?

```csharp
// [FromRoute]  — from URL path: /api/orders/abc123
[HttpGet("{id}")]
public Task<IActionResult> Get([FromRoute] Guid id) { }

// [FromQuery] — from query string: /api/orders?status=Pending&page=2
[HttpGet]
public Task<IActionResult> Search([FromQuery] string status, [FromQuery] int page = 1) { }

// [FromBody]  — from request body (JSON)
[HttpPost]
public Task<IActionResult> Create([FromBody] CreateOrderDto dto) { }

// [FromHeader] — from HTTP header
[HttpGet]
public Task<IActionResult> Get([FromHeader(Name = "X-Tenant-Id")] string tenantId) { }
```

---

# 4. SQL Server Basics

> 📚 Reference: https://learn.microsoft.com/en-us/sql/sql-server/

### Q1 — What is the difference between `WHERE` and `HAVING`?

`WHERE` filters rows **before grouping**. `HAVING` filters groups **after** `GROUP BY`.

```sql
-- ❌ Wrong — can't use aggregate in WHERE
SELECT CustomerId, SUM(Total) AS TotalSpent
FROM Orders
WHERE SUM(Total) > 1000  -- ERROR!
GROUP BY CustomerId;

-- ✅ Correct — HAVING filters on aggregate
SELECT CustomerId, SUM(Total) AS TotalSpent
FROM Orders
GROUP BY CustomerId
HAVING SUM(Total) > 1000;
```

---

### Q2 — What is the difference between `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`?

```sql
-- INNER JOIN — only rows that match in BOTH tables
SELECT o.Id, c.Name
FROM Orders o
INNER JOIN Customers c ON o.CustomerId = c.Id;

-- LEFT JOIN — all rows from Orders, NULLs for unmatched Customers
SELECT o.Id, c.Name
FROM Orders o
LEFT JOIN Customers c ON o.CustomerId = c.Id;
-- Orders with no customer: c.Name = NULL

-- RIGHT JOIN — all rows from Customers (rarely used; rewrite as LEFT JOIN)
```

---

### Q3 — What is a primary key vs a foreign key vs a unique key?

- **Primary key** — uniquely identifies each row, cannot be NULL, one per table.
- **Foreign key** — references the primary key of another table, enforces referential integrity.
- **Unique key** — like PK but can have NULL, allows multiple unique columns per table.

```sql
CREATE TABLE Customers (
    Id       INT PRIMARY KEY,          -- PK: unique, not null
    Email    VARCHAR(100) UNIQUE,      -- unique but nullable
    Name     VARCHAR(100) NOT NULL
);

CREATE TABLE Orders (
    Id          INT PRIMARY KEY,
    CustomerId  INT NOT NULL,
    FOREIGN KEY (CustomerId) REFERENCES Customers(Id) -- FK
);
```

---

### Q4 — What does an index do?

An index is a data structure (B-tree) that speeds up `SELECT` queries by avoiding full table scans. Too many indexes slow down `INSERT`/`UPDATE`/`DELETE`.

```sql
-- Without index: full scan of 10 million rows
SELECT * FROM Orders WHERE CustomerId = 42;

-- With index: B-tree lookup — milliseconds
CREATE INDEX IX_Orders_CustomerId ON Orders(CustomerId);

-- When to add an index:
-- ✅ Columns frequently in WHERE, JOIN ON, ORDER BY
-- ❌ Small tables, columns with low cardinality (e.g., IsActive with only 2 values)
```

---

### Q5 — What is `NULL` in SQL and how do you check for it?

`NULL` means unknown/missing. `NULL = NULL` is `UNKNOWN` (not true), so you must use `IS NULL` / `IS NOT NULL`.

```sql
-- ❌ Wrong — NULL comparisons with = always evaluate to UNKNOWN
SELECT * FROM Orders WHERE DiscountCode = NULL;  -- returns nothing!

-- ✅ Correct
SELECT * FROM Orders WHERE DiscountCode IS NULL;
SELECT * FROM Orders WHERE DiscountCode IS NOT NULL;

-- COALESCE — return first non-null value
SELECT COALESCE(DiscountCode, 'NONE') AS Code FROM Orders;
```

---

# 5. Entity Framework Basics

> 📚 Reference: https://learn.microsoft.com/en-us/ef/core/

### Q1 — What is the difference between `Add`, `Update`, `Remove` in EF Core?

```csharp
// Add — marks entity as Added; INSERT on SaveChanges
_db.Orders.Add(new Order { Status = "Pending" });

// Update — marks entity (and all its properties) as Modified; UPDATE on SaveChanges
// Only needed for DISCONNECTED scenarios (entity came from outside the DbContext scope)
_db.Orders.Update(existingOrder);

// For CONNECTED scenarios (entity loaded by same DbContext), just change the property:
var order = await _db.Orders.FindAsync(id); // tracked
order!.Status = "Shipped";                  // change tracker detects this automatically
await _db.SaveChangesAsync();               // generates UPDATE — no .Update() needed

// Remove — marks as Deleted; DELETE on SaveChanges
_db.Orders.Remove(order);
await _db.SaveChangesAsync();
```

---

### Q2 — What is lazy loading vs eager loading vs explicit loading?

```csharp
// ❌ Lazy loading — N+1 query problem: 1 query for orders + N queries for customers
foreach (var order in _db.Orders.ToList())
    Console.WriteLine(order.Customer.Name); // extra query per order!

// ✅ Eager loading — single JOIN query
var orders = await _db.Orders
    .Include(o => o.Customer)
    .ToListAsync();

// Explicit loading — load related data on demand
var order = await _db.Orders.FindAsync(id);
await _db.Entry(order!).Reference(o => o.Customer).LoadAsync(); // one extra query, intentional
```

---

### Q3 — What is `AsNoTracking` and when should you use it?

`AsNoTracking()` disables change tracking for a query — faster, uses less memory. Use it for read-only queries where you don't need to update the entities.

```csharp
// ✅ Read-only list — no tracking needed
var orders = await _db.Orders
    .AsNoTracking()
    .Where(o => o.Status == "Pending")
    .ToListAsync();

// ❌ Don't use AsNoTracking if you plan to update
var order = await _db.Orders.AsNoTracking().FindAsync(id);
order!.Status = "Shipped";
await _db.SaveChangesAsync(); // ❌ change NOT detected — nothing saved!
```

---

# 6. JavaScript Basics

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript

### Q1 — What is the difference between `var`, `let`, and `const`?

```js
var   x = 1; // function-scoped, hoisted, can re-declare — avoid!
let   y = 2; // block-scoped, not hoisted
const z = 3; // block-scoped, not hoisted, cannot reassign (but object properties CAN change)

const user = { name: "Alice" };
user.name = "Bob";   // ✅ allowed — object itself not reassigned
user = {};           // ❌ TypeError — cannot reassign const
```

---

### Q2 — What is the difference between `==` and `===`?

`==` does **type coercion** (converts types before comparing). `===` checks both **value and type** — always prefer `===`.

```js
0  == "0"   // true  — string coerced to number
0  === "0"  // false — number !== string
null == undefined  // true
null === undefined // false
[] == false        // true  — coercion madness
[] === false       // false
```

---

### Q3 — What is a Promise and how does async/await work?

A Promise is an object representing eventual completion or failure of an async operation. `async/await` is syntactic sugar over Promises.

```js
// Promise
fetch("/api/orders")
  .then(res => res.json())
  .then(data => console.log(data))
  .catch(err => console.error(err));

// async/await — same thing, cleaner
async function loadOrders() {
  try {
    const res  = await fetch("/api/orders");
    const data = await res.json();
    console.log(data);
  } catch (err) {
    console.error(err);
  }
}
```

---

### Q4 — What is `this` in JavaScript?

`this` refers to the **object that called the function** — it changes based on call context.

```js
const obj = {
  name: "Alice",
  greet: function() { console.log(this.name); }  // this = obj
};
obj.greet(); // "Alice"

const greet = obj.greet;
greet();     // undefined — this = global/undefined in strict mode

// Arrow functions: this is lexically bound (captures surrounding this)
class Timer {
  start() {
    setTimeout(() => {
      console.log(this); // ✅ this = Timer instance (arrow captures it)
    }, 1000);
  }
}
```

---

### Q5 — What is `closure`?

A closure is a function that **remembers variables from its outer scope** even after the outer function has returned.

```js
function makeCounter() {
  let count = 0;                  // outer variable
  return function() {
    count++;                      // inner function closes over count
    return count;
  };
}

const counter = makeCounter();
console.log(counter()); // 1
console.log(counter()); // 2  — count persists in closure
console.log(counter()); // 3
```

---

# 7. TypeScript Basics

> 📚 Reference: https://www.typescriptlang.org/docs/

### Q1 — What is TypeScript and why use it over JavaScript?

TypeScript is a **typed superset of JavaScript** that compiles to plain JavaScript. Types catch bugs at compile time, improve IDE autocomplete, and make refactoring safer.

```ts
// JavaScript — bug caught at runtime
function add(a, b) { return a + b; }
add("1", 2); // "12" — string concatenation, silent bug

// TypeScript — bug caught at compile time
function add(a: number, b: number): number { return a + b; }
add("1", 2); // ❌ Compile error: Argument of type 'string' is not assignable to 'number'
```

---

### Q2 — What is the difference between `interface` and `type` in TypeScript?

Both define shapes, but `interface` is **extendable** and preferred for objects. `type` handles **unions, intersections, tuples**, and primitives.

```ts
interface User { name: string; email: string; }
interface Admin extends User { role: "admin"; } // can extend

type Status  = "active" | "inactive";           // union — only type can do this
type UserOrAdmin = User | Admin;                 // union of types
type Point   = [number, number];                 // tuple
```

---

### Q3 — What are generics and why are they useful?

Generics allow writing **reusable code that works with different types** while preserving type safety.

```ts
// Without generics — loses type info
function first(arr: any[]): any { return arr[0]; }
const x = first([1, 2, 3]);     // x is 'any' — no autocomplete

// With generics — type preserved
function first<T>(arr: T[]): T { return arr[0]; }
const y = first([1, 2, 3]);     // y is 'number' ✅
const z = first(["a", "b"]);    // z is 'string' ✅
```

---

# 8. Angular Basics

> 📚 Reference: https://angular.dev/

### Q1 — What is a component and what does it consist of?

A component is the basic building block of an Angular app — it controls a part of the UI.

```ts
@Component({
  selector:    'app-order-list',      // HTML tag to use this component
  templateUrl: './order-list.component.html', // template
  styleUrls:   ['./order-list.component.scss'] // styles
})
export class OrderListComponent implements OnInit {
  orders: Order[] = [];

  constructor(private orderService: OrderService) {}

  ngOnInit(): void {              // lifecycle hook — called after init
    this.orderService.getAll()
      .subscribe(o => this.orders = o);
  }
}
```

---

### Q2 — What is data binding? Name the four types.

```html
<!-- 1. Interpolation: component → template (one-way) -->
<h1>{{ title }}</h1>

<!-- 2. Property binding: component → DOM (one-way) -->
<img [src]="imageUrl" [alt]="altText">

<!-- 3. Event binding: DOM → component (one-way) -->
<button (click)="onSave()">Save</button>

<!-- 4. Two-way binding: component ↔ template (ngModel) -->
<input [(ngModel)]="username">
```

---

### Q3 — What is a service and why use it?

Services share logic and data across components. They are singletons (by default) provided via DI.

```ts
@Injectable({ providedIn: 'root' }) // singleton across entire app
export class OrderService {
  constructor(private http: HttpClient) {}

  getAll(): Observable<Order[]> {
    return this.http.get<Order[]>('/api/orders');
  }
}
// Inject into any component via constructor — DI handles the rest
```

---

### Q4 — What is `*ngIf` and `*ngFor`?

```html
<!-- ngIf — conditionally render element -->
<div *ngIf="isLoggedIn">Welcome back!</div>
<div *ngIf="!isLoggedIn">Please log in</div>

<!-- ngIf with else template -->
<div *ngIf="orders.length > 0; else noOrders">
  <p>You have {{ orders.length }} orders</p>
</div>
<ng-template #noOrders><p>No orders found</p></ng-template>

<!-- ngFor — iterate over array -->
<li *ngFor="let order of orders; let i = index; trackBy: trackById">
  {{ i + 1 }}. Order #{{ order.id }}
</li>
```

---

# 9. HTML & CSS Basics

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/HTML

### Q1 — What is the CSS box model?

Every element is a box: content → padding → border → margin (inside-out).

```css
.card {
  width: 200px;         /* content width */
  padding: 16px;        /* space inside border */
  border: 2px solid #ccc;
  margin: 8px;          /* space outside border */
}

/* box-sizing: border-box — width includes padding + border (more intuitive) */
* { box-sizing: border-box; }
```

---

### Q2 — What is the difference between `display: flex` and `display: grid`?

`flex` — **one-dimensional** layout (row OR column). `grid` — **two-dimensional** layout (rows AND columns simultaneously).

```css
/* Flexbox — horizontal row of items */
.nav {
  display: flex;
  gap: 16px;
  align-items: center;    /* vertical center */
  justify-content: space-between; /* horizontal spread */
}

/* Grid — two-dimensional page layout */
.layout {
  display: grid;
  grid-template-columns: 250px 1fr; /* sidebar + main */
  grid-template-rows: 64px 1fr 40px; /* header + content + footer */
}
```

---

### Q3 — What is semantic HTML?

Semantic tags **describe meaning** to browsers and screen readers. Always prefer them over generic `<div>`.

```html
<!-- ❌ Non-semantic -->
<div class="header"><div class="nav">...</div></div>
<div class="main"><div class="article">...</div></div>
<div class="footer">...</div>

<!-- ✅ Semantic -->
<header><nav>...</nav></header>
<main><article>...</article></main>
<footer>...</footer>
```

---

# 10. Design Patterns Basics

> 📚 Reference: https://refactoring.guru/design-patterns

### Q1 — What is a Singleton pattern?

Ensures a class has only **one instance** and provides a global access point.

```csharp
// Use DI container instead of manual Singleton in .NET
builder.Services.AddSingleton<IAppConfig, AppConfig>(); // DI manages lifecycle

// Manual (use Lazy<T> for thread safety)
public sealed class Logger
{
    private static readonly Lazy<Logger> _instance = new(() => new Logger());
    private Logger() { }
    public static Logger Instance => _instance.Value;
    public void Log(string msg) => Console.WriteLine(msg);
}
```

---

### Q2 — What is the Repository pattern?

Abstracts data access behind an interface — decouples business logic from database technology.

```csharp
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid id);
    Task AddAsync(Order order);
}

public class SqlOrderRepository : IOrderRepository
{
    private readonly AppDbContext _db;
    // ... EF Core implementation
}

// Service depends on interface — easy to swap or mock in tests
public class OrderService
{
    private readonly IOrderRepository _repo;
    public OrderService(IOrderRepository repo) => _repo = repo;
}
```

---

### Q3 — What is the difference between composition and inheritance?

**Inheritance** (is-a): `Dog extends Animal`. Tightly coupled — changes to base affect all children.  
**Composition** (has-a): `Dog has a Bark`. Flexible — swap behaviours at runtime.

```csharp
// ❌ Inheritance — rigid, cannot change bark at runtime
class Dog : Animal { void Bark() { } }

// ✅ Composition — inject behaviour
public class Dog
{
    private readonly IBarkBehaviour _bark;
    public Dog(IBarkBehaviour bark) => _bark = bark;
    public void Bark() => _bark.Bark();
}

var quietDog = new Dog(new SilentBark());
var loudDog  = new Dog(new LoudBark());
```

---

# 11. DSA Basics

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/standard/collections/

### Q1 — What is Big O notation?

Big O describes how **time or space grows** as input size `n` increases.

| Notation | Name | Example |
|----------|------|---------|
| O(1) | Constant | Dictionary lookup |
| O(log n) | Logarithmic | Binary search |
| O(n) | Linear | Loop through array |
| O(n log n) | Log-linear | Merge sort |
| O(n²) | Quadratic | Nested loops |
| O(2ⁿ) | Exponential | Recursive Fibonacci (naive) |

```csharp
// O(1) — constant
int GetFirst(int[] arr) => arr[0];

// O(n) — linear
int Sum(int[] arr) { int s = 0; foreach (var x in arr) s += x; return s; }

// O(n²) — quadratic (avoid for large inputs)
bool HasDuplicate(int[] arr)
{
    for (int i = 0; i < arr.Length; i++)
        for (int j = i + 1; j < arr.Length; j++)
            if (arr[i] == arr[j]) return true;
    return false;
}

// O(n) with HashSet — better
bool HasDuplicate2(int[] arr)
{
    var seen = new HashSet<int>();
    foreach (var x in arr)
        if (!seen.Add(x)) return true;
    return false;
}
```

---

### Q2 — When do you use a `List` vs `Dictionary` vs `HashSet`?

```csharp
// List<T>   — ordered, allows duplicates, O(n) search
var list = new List<string> { "a", "b", "c" };
bool found = list.Contains("b"); // O(n) linear scan

// Dictionary<K,V> — key-value lookup, O(1) average
var dict = new Dictionary<string, int> { ["Alice"] = 30, ["Bob"] = 25 };
int age = dict["Alice"];          // O(1)

// HashSet<T> — unique values only, O(1) Contains
var ids = new HashSet<Guid>();
ids.Add(orderId);                 // O(1) add
bool exists = ids.Contains(orderId); // O(1) lookup — much faster than List!
```

---

### Q3 — What is a stack vs a queue?

**Stack** — LIFO (Last In, First Out). **Queue** — FIFO (First In, First Out).

```csharp
// Stack — undo operations, DFS
var stack = new Stack<int>();
stack.Push(1); stack.Push(2); stack.Push(3);
Console.WriteLine(stack.Pop());   // 3 (last in, first out)

// Queue — task processing, BFS
var queue = new Queue<string>();
queue.Enqueue("task1"); queue.Enqueue("task2");
Console.WriteLine(queue.Dequeue()); // "task1" (first in, first out)
```

---

# 12. Azure / Cloud Basics

> 📚 Reference: https://learn.microsoft.com/en-us/azure/

### Q1 — What is the difference between IaaS, PaaS, and SaaS?

| | IaaS | PaaS | SaaS |
|-|------|------|------|
| You manage | OS + App + Data | App + Data | Nothing (use it) |
| Azure manages | Hardware + Network | Hardware + OS | Everything |
| Example | Azure VM | Azure App Service | Microsoft 365 |

---

### Q2 — What is Azure Blob Storage used for?

Blob Storage stores **unstructured data** — images, videos, documents, backups, logs.

```csharp
var client    = new BlobServiceClient(connectionString);
var container = client.GetBlobContainerClient("avatars");
await container.CreateIfNotExistsAsync();

// Upload
var blob = container.GetBlobClient("user-123.jpg");
await blob.UploadAsync(fileStream, overwrite: true);

// Download
var download = await blob.DownloadContentAsync();
byte[] data = download.Value.Content.ToArray();
```

---

### Q3 — What is Azure Service Bus?

A **managed message broker** for decoupling services. Messages sent to a queue are processed by exactly one consumer. Topics support fan-out (one message → multiple subscribers).

```csharp
// Producer — sends message to queue
var sender = new ServiceBusClient(connectionString)
    .CreateSender("orders-queue");
await sender.SendMessageAsync(new ServiceBusMessage(
    BinaryData.FromObjectAsJson(new { OrderId = id })));

// Consumer — receives and processes
var processor = client.CreateProcessor("orders-queue");
processor.ProcessMessageAsync += async args =>
{
    var order = args.Message.Body.ToObjectFromJson<OrderMessage>();
    await ProcessOrderAsync(order);
    await args.CompleteMessageAsync(args.Message);
};
```

---

# 13. Git & DevOps Basics

> 📚 Reference: https://git-scm.com/docs

### Q1 — What is the difference between `git merge` and `git rebase`?

**Merge** — creates a merge commit, preserves full history. **Rebase** — replays commits on top of another branch, creates linear history.

```bash
# Merge — safe for shared branches, shows all history
git checkout main
git merge feature/orders   # creates a merge commit

# Rebase — clean linear history, use only on private branches
git checkout feature/orders
git rebase main            # replays feature commits on top of main
# NEVER rebase shared/public branches — rewrites history
```

---

### Q2 — What is a CI/CD pipeline?

**CI (Continuous Integration)** — automatically build and test on every push.  
**CD (Continuous Delivery/Deployment)** — automatically deploy after CI passes.

```yaml
# Azure Pipelines example
trigger:
  branches: [ main ]

jobs:
  - job: Build
    steps:
      - script: dotnet restore
      - script: dotnet build --no-restore
      - script: dotnet test --no-build  # tests must pass
      - script: dotnet publish -o $(Build.ArtifactStagingDirectory)
      - publish: $(Build.ArtifactStagingDirectory)

  - deployment: Deploy
    environment: Production
    steps:
      - task: AzureWebApp@1
        inputs:
          appName: my-api
```

---

### Q3 — What is `git stash`?

`git stash` temporarily **saves uncommitted changes** so you can switch branches without committing.

```bash
git stash           # save uncommitted changes
git checkout main   # switch branches cleanly
# ... do hotfix work ...
git checkout feature/my-work
git stash pop       # restore saved changes
```

---

# 14. Unit Testing Basics

> 📚 Reference: https://xunit.net/

### Q1 — What is a unit test?

A unit test tests a **single class or method in complete isolation** — no database, no network, no file system. Dependencies are replaced with mocks.

```csharp
[Fact]
public void Add_TwoPositiveNumbers_ReturnsSum()
{
    // Arrange
    var calc = new Calculator();

    // Act
    var result = calc.Add(3, 4);

    // Assert
    Assert.Equal(7, result);
}
```

---

### Q2 — What is the AAA pattern?

**Arrange** — set up everything needed.  
**Act** — call the method under test (one call only).  
**Assert** — verify the result (one logical outcome).

```csharp
[Fact]
public async Task GetOrder_WhenExists_ReturnsOrder()
{
    // Arrange
    var mockRepo = new Mock<IOrderRepository>();
    mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>()))
            .ReturnsAsync(new Order { Status = "Pending" });
    var svc = new OrderService(mockRepo.Object);

    // Act
    var order = await svc.GetOrderAsync(Guid.NewGuid());

    // Assert
    Assert.NotNull(order);
    Assert.Equal("Pending", order.Status);
}
```

---

### Q3 — What is mocking?

Mocking replaces a real dependency with a **fake object** that you control. Use Moq library in .NET.

```csharp
var mockRepo = new Mock<IOrderRepository>();

// Setup — define what the mock returns
mockRepo.Setup(r => r.GetByIdAsync(orderId)).ReturnsAsync(new Order());

// Verify — check the mock was called correctly
mockRepo.Verify(r => r.GetByIdAsync(orderId), Times.Once);
```

---

# 15. HLD / System Design Basics

> 📚 Reference: https://learn.microsoft.com/en-us/azure/architecture/

### Q1 — What is horizontal vs vertical scaling?

**Vertical scaling (scale up)** — bigger machine (more CPU, RAM).  
**Horizontal scaling (scale out)** — more machines (load balanced).

```
Vertical:   [Server 4CPU] → [Server 16CPU]   ← has upper limit, expensive
Horizontal: [Server] → [Server][Server][Server]  ← scales indefinitely, needs load balancer
```

---

### Q2 — What is a load balancer?

A load balancer **distributes incoming requests** across multiple server instances to prevent any one server from being overwhelmed.

```
Client
  │
  ▼
Load Balancer
  ├──► App Server 1
  ├──► App Server 2
  └──► App Server 3

Algorithms: Round Robin, Least Connections, IP Hash (sticky sessions)
Azure: Application Gateway (L7), Azure Load Balancer (L4)
```

---

### Q3 — What is caching and what are the caching strategies?

Caching stores frequently accessed data in fast memory to reduce database load.

| Strategy | How | Use when |
|----------|-----|---------|
| Cache-aside | App checks cache; miss → load DB → store | General purpose |
| Write-through | Write to cache AND DB together | Consistency critical |
| Write-behind | Write to cache; async write to DB | High write throughput |
| Read-through | Cache loads from DB automatically | Transparent caching |

```csharp
// Cache-aside pattern
public async Task<Order?> GetOrderAsync(Guid id)
{
    var cacheKey = $"order:{id}";
    var cached   = await _cache.GetStringAsync(cacheKey);
    if (cached is not null)
        return JsonSerializer.Deserialize<Order>(cached);

    var order = await _db.Orders.FindAsync(id);
    if (order is not null)
        await _cache.SetStringAsync(cacheKey,
            JsonSerializer.Serialize(order),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10) });
    return order;
}
```

---

### Q4 — What is REST vs HTTP?

HTTP is the **transport protocol**. REST is an **architectural style** that uses HTTP. A REST API uses HTTP methods (GET/POST/PUT/DELETE) to represent CRUD operations on resources.

```
REST principles:
✅ Stateless — each request contains all info (no server session)
✅ Resource-based URLs — /api/orders/42 (noun, not verb)
✅ HTTP methods = actions — GET=read, POST=create, PUT=update, DELETE=remove
✅ Uniform interface
✅ JSON for data exchange
```

---

# 16. LLD Basics

### Q1 — What is SOLID?

Five principles for writing maintainable OOP code:

| Letter | Principle | One-liner |
|--------|-----------|-----------|
| S | Single Responsibility | One class, one reason to change |
| O | Open/Closed | Open for extension, closed for modification |
| L | Liskov Substitution | Subclasses must be substitutable for their base |
| I | Interface Segregation | Many small interfaces over one fat interface |
| D | Dependency Inversion | Depend on abstractions, not concretions |

```csharp
// D — Dependency Inversion
// ❌ Wrong — depends on concrete class
public class OrderService
{
    private readonly SqlOrderRepository _repo = new(); // tight coupling
}

// ✅ Correct — depends on abstraction
public class OrderService
{
    private readonly IOrderRepository _repo;
    public OrderService(IOrderRepository repo) => _repo = repo; // injected
}
```

---

### Q2 — What is the difference between `new` and Dependency Injection?

Using `new` inside a class creates a **hardcoded dependency** — impossible to swap or mock. DI **provides the dependency from outside** — flexible and testable.

```csharp
// ❌ new — hardcoded, untestable
public class ReportService
{
    private readonly SqlRepo _repo = new SqlRepo("connection string"); // cannot mock
}

// ✅ DI — injectable, testable
public class ReportService
{
    private readonly IRepo _repo;
    public ReportService(IRepo repo) => _repo = repo; // can inject SqlRepo or MockRepo
}
```

---

# 17. AI in .NET Basics

> 📚 Reference: https://learn.microsoft.com/en-us/semantic-kernel/

### Q1 — What is Semantic Kernel?

Semantic Kernel is Microsoft's open-source SDK for integrating **LLMs (Large Language Models)** into .NET apps. It manages prompts, memory, and function calling.

```csharp
var kernel = Kernel.CreateBuilder()
    .AddAzureOpenAIChatCompletion(
        deploymentName: "gpt-4o",
        endpoint:       config["Azure:OpenAI:Endpoint"]!,
        apiKey:         config["Azure:OpenAI:Key"]!)
    .Build();

var result = await kernel.InvokePromptAsync(
    "Summarise this order in one sentence: {{$order}}", 
    new KernelArguments { ["order"] = orderJson });

Console.WriteLine(result);
```

---

### Q2 — What is RAG (Retrieval-Augmented Generation)?

RAG enhances LLM responses by **retrieving relevant documents** from a vector store and including them in the prompt. This grounds the LLM in current, specific data without fine-tuning.

```
User question
    │
    ▼
Embed question → vector
    │
    ▼
Search vector store → top-k relevant docs
    │
    ▼
Prompt = system + retrieved docs + user question
    │
    ▼
LLM generates grounded answer
```

---

### Q3 — What is the difference between a prompt and a system prompt?

**System prompt** — sets the AI's persona, constraints, and behaviour globally.  
**User prompt** — the actual question or task from the user.

```csharp
var messages = new ChatHistory();
messages.AddSystemMessage(
    "You are a helpful customer support agent for Acme Shop. " +
    "Only answer questions about orders, returns, and products. " +
    "Be polite and concise.");

messages.AddUserMessage("What is the return policy?");

var response = await chatService.GetChatMessageContentsAsync(messages);
```

---

> ✅ **All 17 topics covered** with entry-level questions, definitions, and code examples.
>
> 💡 **Interview tips for entry-level:**
> - Always explain **what** something is before **how** it works
> - Relate answers to real projects: "I used this when..."
> - If unsure, say "I understand the concept as..." rather than guessing specifics
> - For coding questions: think out loud, start with brute force, then optimise

---

*Last updated: 2026 | .NET 8 / C# 12 / Angular 17 / TypeScript 5*
