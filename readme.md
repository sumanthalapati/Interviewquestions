# 🟣 .NET Interview Questions — Complete Guide

> **500+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents

1. [C# Core Concepts](#1-c-core-concepts)
   - [SOLID Principles](#11-solid-principles)
   - [OOP — Classes, Interfaces, Abstract](#12-oop--classes-interfaces-abstract)
   - [Memory — Stack, Heap, GC, IDisposable](#13-memory--stack-heap-gc-idisposable)
   - [Types — Value, Reference, Boxing, Casting](#14-types--value-reference-boxing-casting)
   - [Collections — List, Dict, HashSet, Array](#15-collections--list-dict-hashset-array)
   - [Delegates, Func, Action, LINQ](#16-delegates-func-action-linq)
   - [Async / Await / Threading](#17-async--await--threading)
   - [Null Handling & Exception Keywords](#18-null-handling--exception-keywords)
   - [Misc C# Keywords & Features](#19-misc-c-keywords--features)
   - [Records & Init-Only Properties](#110-records--init-only-properties)
   - [Pattern Matching](#111-pattern-matching)
   - [Span<T> and Memory<T>](#112-spant-and-memoryt)
   - [Nullable Reference Types](#113-nullable-reference-types)
   - [Modern C# Features (C# 9–13)](#114-modern-c-language-features-c-913)
   - [Source Generators](#115-source-generators)
2. [ASP.NET Core / Web API](#2-aspnet-core--web-api)
   - [Request Pipeline & Middleware](#21-request-pipeline--middleware)
   - [Dependency Injection & Lifetimes](#22-dependency-injection--lifetimes)
   - [Controllers, Routing, Model Binding](#23-controllers-routing-model-binding)
   - [HTTP Methods & Status Codes](#24-http-methods--status-codes)
   - [Authentication & Authorization](#25-authentication--authorization)
   - [Performance — Caching, Async, Pagination](#26-performance--caching-async-pagination)
   - [Testing — Unit & Integration](#27-testing--unit--integration)
   - [Logging & Observability](#28-logging--observability)
3. [SQL Server](#3-sql-server)
   - [Indexes & Performance](#31-indexes--performance)
   - [Joins, Aggregates & Window Functions](#32-joins-aggregates--window-functions)
   - [CTEs, Temp Tables, Stored Procedures, Functions](#33-ctes-temp-tables-stored-procedures-functions)
   - [ACID, Transactions & Concurrency](#34-acid-transactions--concurrency)
   - [Common Query Patterns](#35-common-query-patterns)
4. [Entity Framework / ORM](#4-entity-framework--orm)
5. [Design Patterns & SOLID (Deep Dive)](#5-design-patterns--solid-deep-dive)
6. [Microservices](#6-microservices)
7. [Azure / Cloud](#7-azure--cloud)
8. [Angular](#8-angular)
9. [ASP.NET MVC](#9-aspnet-mvc)
10. [Coding / Algorithms](#10-coding--algorithms)
11. [JavaScript](#11-javascript)
12. [DevOps / CI/CD / Git](#12-devops--cicd--git)
13. [AI Integration in .NET](#13-ai-integration-in-net)

---

# 1. C# Core Concepts

---

## 1.1 SOLID Principles

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles

### S — Single Responsibility Principle (SRP)

**Definition:** A class should have **one and only one reason to change** — it should do one thing only.

❌ **Violates SRP** — one class handles both user data AND email sending:
```csharp
public class UserService
{
    public void RegisterUser(string email, string password)
    {
        // 1. Saves user to DB
        var user = new User { Email = email, Password = password };
        _db.Users.Add(user);
        _db.SaveChanges();

        // 2. Also sends email — WRONG: two responsibilities!
        var smtpClient = new SmtpClient("smtp.gmail.com");
        smtpClient.Send("no-reply@app.com", email, "Welcome!", "Hello!");
    }
}
```

✅ **Satisfies SRP** — each class has one job:
```csharp
public class UserService
{
    private readonly IEmailService _emailService;
    private readonly AppDbContext _db;

    public UserService(IEmailService emailService, AppDbContext db)
    {
        _emailService = emailService;
        _db = db;
    }

    public void RegisterUser(string email, string password)
    {
        var user = new User { Email = email, Password = password };
        _db.Users.Add(user);
        _db.SaveChanges();
        _emailService.SendWelcomeEmail(email); // delegates email work
    }
}

public class EmailService : IEmailService
{
    public void SendWelcomeEmail(string email)
    {
        // Only email logic lives here
    }
}
```

---

### O — Open/Closed Principle (OCP)

**Definition:** Classes should be **open for extension** but **closed for modification**. Add new behaviour without changing existing code.

❌ **Violates OCP** — adding a new discount type means editing existing code:
```csharp
public class DiscountCalculator
{
    public double Calculate(string customerType, double price)
    {
        if (customerType == "Regular")   return price * 0.9;
        if (customerType == "Premium")   return price * 0.8;
        if (customerType == "VIP")       return price * 0.7;
        // Every new type → edit this method ❌
        return price;
    }
}
```

✅ **Satisfies OCP** — new types added by creating new classes, not editing old ones:
```csharp
public interface IDiscountStrategy
{
    double Apply(double price);
}

public class RegularDiscount  : IDiscountStrategy { public double Apply(double p) => p * 0.9; }
public class PremiumDiscount  : IDiscountStrategy { public double Apply(double p) => p * 0.8; }
public class VIPDiscount      : IDiscountStrategy { public double Apply(double p) => p * 0.7; }
// Add new type → new class only, zero changes to existing code ✅

public class DiscountCalculator
{
    private readonly IDiscountStrategy _strategy;
    public DiscountCalculator(IDiscountStrategy strategy) => _strategy = strategy;
    public double Calculate(double price) => _strategy.Apply(price);
}
```

> **Does Factory pattern violate OCP?**
> A basic `if/switch` factory does violate OCP. To fix it, use a *dictionary-based* or *reflection-based* factory that maps types to strategies — then adding a new type only means registering it, not editing the factory.

---

### L — Liskov Substitution Principle (LSP)

**Definition:** A subclass must be **substitutable** for its parent class without breaking the program.

❌ **Violates LSP** — `Square` breaks the expected behaviour of `Rectangle`:
```csharp
public class Rectangle
{
    public virtual int Width  { get; set; }
    public virtual int Height { get; set; }
    public int Area() => Width * Height;
}

public class Square : Rectangle
{
    public override int Width  { set { base.Width = base.Height = value; } }
    public override int Height { set { base.Width = base.Height = value; } }
}

// Usage — breaks LSP:
Rectangle r = new Square();
r.Width  = 5;
r.Height = 10;
Console.WriteLine(r.Area()); // Expected 50, but prints 100 ❌
```

✅ **Satisfies LSP** — use a shared interface instead of forced inheritance:
```csharp
public interface IShape { int Area(); }
public class Rectangle : IShape
{
    public int Width { get; set; }
    public int Height { get; set; }
    public int Area() => Width * Height;
}
public class Square : IShape
{
    public int Side { get; set; }
    public int Area() => Side * Side;
}
```

---

### I — Interface Segregation Principle (ISP)

**Definition:** A class should **not be forced to implement interfaces it doesn't use**. Keep interfaces small and focused.

❌ **Violates ISP** — `PrinterOnlyDevice` forced to implement scan/fax:
```csharp
public interface IMultiFunctionDevice
{
    void Print(string doc);
    void Scan(string doc);
    void Fax(string doc);
}

public class SimplePrinter : IMultiFunctionDevice
{
    public void Print(string doc) { /* works */ }
    public void Scan(string doc) => throw new NotImplementedException(); // ❌
    public void Fax(string doc)  => throw new NotImplementedException(); // ❌
}
```

✅ **Satisfies ISP** — split into focused interfaces:
```csharp
public interface IPrinter { void Print(string doc); }
public interface IScanner { void Scan(string doc);  }
public interface IFax     { void Fax(string doc);   }

public class SimplePrinter  : IPrinter { public void Print(string doc) { /* ok */ } }
public class AllInOnePrinter: IPrinter, IScanner, IFax
{
    public void Print(string doc) { }
    public void Scan(string doc)  { }
    public void Fax(string doc)   { }
}
```

---

### D — Dependency Inversion Principle (DIP)

**Definition:** High-level modules should **not depend on low-level modules**. Both should depend on **abstractions** (interfaces). Dependency Injection (DI) is the practical implementation of DIP.

❌ **Violates DIP** — `OrderService` directly creates `SqlOrderRepository`:
```csharp
public class OrderService
{
    private readonly SqlOrderRepository _repo = new SqlOrderRepository(); // ❌ tight coupling
    public void PlaceOrder(Order o) => _repo.Save(o);
}
```

✅ **Satisfies DIP** — depend on interface, inject at runtime:
```csharp
public interface IOrderRepository { void Save(Order o); }

public class SqlOrderRepository : IOrderRepository
{
    public void Save(Order o) { /* SQL logic */ }
}

public class OrderService
{
    private readonly IOrderRepository _repo;
    public OrderService(IOrderRepository repo) => _repo = repo; // ✅ injected
    public void PlaceOrder(Order o) => _repo.Save(o);
}

// Registration in Program.cs:
builder.Services.AddScoped<IOrderRepository, SqlOrderRepository>();
```

> **Why constructor injection?** It makes dependencies explicit, enables easy mocking in tests, and prevents using the object in an invalid state.

---

## 1.2 OOP — Classes, Interfaces, Abstract

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/

### Abstract Class vs Interface

| Feature | Abstract Class | Interface |
|---|---|---|
| Can have implementation | ✅ Yes | ✅ Yes (default methods, C#8+) |
| Multiple inheritance | ❌ No (single) | ✅ Yes (multiple) |
| Constructors | ✅ Yes | ❌ No |
| Fields | ✅ Yes | ❌ No (only properties) |
| Access modifiers | ✅ Any | Public only (default) |
| Use when | Shared base behaviour | Contract / capability |

```csharp
// Abstract class — shared base
public abstract class Animal
{
    public string Name { get; set; }          // shared state ✅
    public abstract void MakeSound();          // must override
    public void Breathe() => Console.WriteLine("Breathing..."); // shared impl
}

// Interface — contract
public interface ISwimmable { void Swim(); }
public interface IFlyable   { void Fly();  }

public class Duck : Animal, ISwimmable, IFlyable // ✅ multiple interfaces
{
    public override void MakeSound() => Console.WriteLine("Quack");
    public void Swim() => Console.WriteLine("Swimming");
    public void Fly()  => Console.WriteLine("Flying");
}
```

**If abstract class has both abstract and non-abstract methods, must you implement all?**
No — you only **must** override `abstract` methods. `virtual` methods are optional overrides. Non-abstract non-virtual methods are inherited as-is.

---

### Abstract vs Virtual

```csharp
public abstract class Shape
{
    public abstract double Area();          // MUST override — no body allowed
    public virtual  string Describe() => $"Area: {Area()}"; // CAN override — has default body
}

public class Circle : Shape
{
    public double Radius { get; set; }
    public override double Area() => Math.PI * Radius * Radius; // required ✅
    // Describe() not overridden — uses base version ✅
}
```

---

### Sealed Class

**Definition:** A `sealed` class cannot be inherited. Used to prevent extension and enable JIT optimisations.

```csharp
public sealed class Configuration
{
    public string ConnectionString { get; set; }
}

// ❌ Compile error:
// public class ExtendedConfig : Configuration { }
```

---

### Inheritance & Multiple Inheritance in C#

C# supports **single class inheritance** but **multiple interface implementation**. To resolve ambiguous interface methods:

```csharp
public interface IA { void Hello(); }
public interface IB { void Hello(); }

public class MyClass : IA, IB
{
    // Explicit implementation to resolve conflict:
    void IA.Hello() => Console.WriteLine("IA Hello");
    void IB.Hello() => Console.WriteLine("IB Hello");
}

var obj = new MyClass();
((IA)obj).Hello(); // IA Hello
((IB)obj).Hello(); // IB Hello
```

---

### Polymorphism

**Types:**
1. **Compile-time (static)** — Method overloading
2. **Runtime (dynamic)** — Method overriding with `virtual`/`override`

```csharp
// Overloading (compile-time)
public class Calculator
{
    public int Add(int a, int b)          => a + b;
    public double Add(double a, double b) => a + b;
    public int Add(int a, int b, int c)   => a + b + c;
}

// Overriding (runtime)
public class Animal    { public virtual  void Speak() => Console.WriteLine("..."); }
public class Dog : Animal { public override void Speak() => Console.WriteLine("Woof"); }
public class Cat : Animal { public override void Speak() => Console.WriteLine("Meow"); }

Animal a = new Dog(); a.Speak(); // "Woof" — runtime dispatch ✅
```

**Overload vs Override:**
| | Overload | Override |
|---|---|---|
| Same method name | ✅ | ✅ |
| Same signature | ❌ | ✅ |
| Inheritance needed | ❌ | ✅ |
| Resolved at | Compile time | Runtime |

---

## 1.3 Memory — Stack, Heap, GC, IDisposable

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/

### Stack vs Heap

| Stack | Heap |
|---|---|
| Value types (int, bool, struct) | Reference types (class, array, string) |
| Method call frames | Dynamically allocated objects |
| Auto-freed when scope ends | Freed by Garbage Collector |
| Fast (LIFO pointer move) | Slower (GC overhead) |
| Fixed size (~1MB default) | Large, limited by RAM |

```csharp
void Example()
{
    int x = 5;                    // Stack — gone when method returns
    string s = "hello";           // s reference on Stack, "hello" on Heap
    var obj = new MyClass();      // obj ref on Stack, MyClass instance on Heap
}
```

---

### Garbage Collection & Generations

**Definition:** The .NET GC automatically reclaims heap memory for objects that are no longer reachable. It uses a **generational** model for performance.

| Generation | Description |
|---|---|
| Gen 0 | Short-lived objects (most objects). Collected most frequently. |
| Gen 1 | Survived Gen 0. Buffer between short and long-lived. |
| Gen 2 | Long-lived objects (static, caches). Collected least frequently. |
| Large Object Heap (LOH) | Objects > 85KB. Collected with Gen 2. |

```csharp
// GC promotes surviving objects each collection cycle:
// Object created → Gen 0 → (survives) → Gen 1 → (survives) → Gen 2

// Force GC (avoid in production — just for illustration):
GC.Collect(0); // Gen 0 only
GC.Collect();  // Full collection
```

---

### IDisposable & using

**Definition:** `IDisposable` is an interface that lets you **explicitly release unmanaged resources** (file handles, DB connections, network streams) that the GC doesn't know about.

**Why call Dispose() if GC exists?**
GC only manages **managed** memory. Unmanaged resources (file handles, SQL connections, sockets) are NOT freed by GC — only by `Dispose()`. Without it, you get **resource leaks**.

❌ **Resource leak** — connection never closed:
```csharp
public void GetData()
{
    var conn = new SqlConnection(connectionString);
    conn.Open();
    var cmd = new SqlCommand("SELECT * FROM Users", conn);
    cmd.ExecuteReader();
    // conn never closed! ❌ — connection pool exhausted over time
}
```

✅ **using statement** — auto-calls Dispose():
```csharp
public void GetData()
{
    using (var conn = new SqlConnection(connectionString))
    using (var cmd  = new SqlCommand("SELECT * FROM Users", conn))
    {
        conn.Open();
        using var reader = cmd.ExecuteReader(); // C#8 shorthand
        while (reader.Read()) { /* process */ }
    } // Dispose() called automatically ✅
}
```

✅ **Implementing IDisposable correctly:**
```csharp
public class FileProcessor : IDisposable
{
    private FileStream _stream;
    private bool _disposed = false;

    public FileProcessor(string path)
    {
        _stream = new FileStream(path, FileMode.Open);
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this); // Tell GC: no need to call finalizer
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
                _stream?.Dispose(); // Managed resources
            _disposed = true;
        }
    }

    ~FileProcessor() => Dispose(false); // Finalizer as safety net
}
```

---

### Memory Leak Prevention

A **memory leak** in .NET = objects that are still referenced (so GC can't collect them) but never actually used again.

Common causes:
- Static collections that grow forever
- Event handlers not unsubscribed
- Large objects in LOH
- Unclosed connections/streams

```csharp
// ❌ Static list grows forever — memory leak:
public static class Cache
{
    public static List<byte[]> _data = new List<byte[]>();
    public static void Add() => _data.Add(new byte[1024 * 1024]); // 1MB each call
}

// ✅ Fix: use weak references, set max size, or use IMemoryCache with expiry:
var cache = new MemoryCache(new MemoryCacheOptions());
cache.Set("key", largeObject, TimeSpan.FromMinutes(10)); // auto-evicts ✅
```

---

## 1.4 Types — Value, Reference, Boxing, Casting

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-types

### Value Types vs Reference Types

```csharp
// Value type — copy semantics:
int a = 10;
int b = a;  // b is an independent copy
b = 20;
Console.WriteLine(a); // 10 — unchanged ✅

// Reference type — reference semantics:
var list1 = new List<int> { 1, 2, 3 };
var list2 = list1;  // both point to same object
list2.Add(4);
Console.WriteLine(list1.Count); // 4 — changed! ⚠️
```

---

### Boxing and Unboxing

**Definition:**
- **Boxing** = converting a value type to `object` (wraps it on the heap) — implicit.
- **Unboxing** = extracting the value back from `object` — explicit cast required.

Both are performance-costly operations.

```csharp
// Boxing:
int num = 42;
object boxed = num;          // Value type → Heap allocation ⚠️
Console.WriteLine(boxed);   // "42"

// Unboxing:
int unboxed = (int)boxed;    // Must cast explicitly
// int wrong = (double)boxed; // InvalidCastException at runtime ❌

// Performance problem — avoid boxing in hot paths:
ArrayList list = new ArrayList();
list.Add(1);  // Boxes each int ❌ — use List<int> instead ✅
```

---

### Type Conversion & Casting

```csharp
// Implicit (safe, no data loss):
int x = 10;
double d = x;   // int → double ✅

// Explicit cast (may throw or truncate):
double pi = 3.14;
int truncated = (int)pi;              // 3 — truncates ⚠️
Console.WriteLine(truncated);        // 3

// Convert.ToInt32 vs (int) cast:
double val = 9.987;
int cast    = (int)val;              // 9 — truncates toward zero
int convert = Convert.ToInt32(val);  // 10 — rounds to nearest ✅

float f = 1.5f;
int castF    = (int)f;              // 1 — truncated
int convertF = Convert.ToInt32(f);  // 2 — banker's rounding

// Safe cast with 'as' and 'is':
object obj = "Hello";
string s = obj as string;    // null if fails, no exception ✅
if (obj is string str)       // pattern matching (C#7+) ✅
    Console.WriteLine(str);
```

**Convert.ToString() vs .ToString():**
```csharp
string s1 = Convert.ToString(null);  // "" — never throws ✅
string s2 = null.ToString();         // NullReferenceException ❌
```

---

### ref vs out vs value parameters

| | `ref` | `out` | value |
|---|---|---|---|
| Must be initialized before call | ✅ | ❌ | ✅ |
| Must be assigned inside method | ❌ | ✅ | ❌ |
| Passes by | Reference | Reference | Copy |

```csharp
void WithRef(ref int x) => x *= 2;

void WithOut(out int x)
{
    x = 100; // MUST assign ✅
}

int a = 5;
WithRef(ref a);     // a = 10
WithOut(out int b); // b = 100

// Practical use of out:
bool parsed = int.TryParse("123", out int result); // ✅ idiomatic pattern
```

---

### Span\<T\>

**Definition:** `Span<T>` is a stack-allocated, zero-copy view over a contiguous block of memory. It avoids heap allocations when slicing arrays or strings.

```csharp
// ❌ Creates new string allocation each slice:
string full = "Hello World";
string sub  = full.Substring(0, 5);  // New heap allocation

// ✅ Span — zero allocation:
ReadOnlySpan<char> span = full.AsSpan(0, 5); // No new allocation
Console.WriteLine(span.ToString()); // "Hello"

// Array slicing:
int[] numbers = { 1, 2, 3, 4, 5 };
Span<int> middle = numbers.AsSpan(1, 3); // { 2, 3, 4 } — no copy
middle[0] = 99; // modifies original array
```

---

### record vs class

**Definition:** `record` is a reference type optimised for **immutable data** with value-based equality. A `class` has reference-based equality by default.

```csharp
// class — reference equality:
var c1 = new Point(1, 2);
var c2 = new Point(1, 2);
Console.WriteLine(c1 == c2); // False — different objects

// record — value equality:
public record Point(int X, int Y);
var p1 = new Point(1, 2);
var p2 = new Point(1, 2);
Console.WriteLine(p1 == p2); // True ✅

// Non-destructive mutation:
var p3 = p1 with { X = 99 }; // new record, p1 unchanged ✅

// Use record when: DTOs, value objects, immutable data transfer
// Use class when:  mutable entities, services, repositories
```

---

## 1.5 Collections — List, Dict, HashSet, Array

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/standard/collections/

### Overview Table

| Type | Ordered | Unique Keys | Null Keys | Use Case |
|---|---|---|---|---|
| `Array` | ✅ | ❌ | ✅ | Fixed-size, fast index |
| `List<T>` | ✅ | ❌ | ✅ | Dynamic ordered list |
| `Dictionary<K,V>` | ❌ | ✅ | ❌ | Key→Value lookup O(1) |
| `HashSet<T>` | ❌ | N/A | ❌ | Unique items, fast lookup |
| `Hashtable` | ❌ | ✅ | ❌ | Non-generic (legacy) |
| `Queue<T>` | FIFO | ❌ | ✅ | Processing order |
| `Stack<T>` | LIFO | ❌ | ✅ | Undo, DFS |

### Array vs ArrayList

```csharp
// Array — fixed size, strongly typed:
int[] arr = new int[3] { 1, 2, 3 };
// arr.Add(4); // ❌ compile error — fixed size

// ArrayList — dynamic but NOT type-safe (legacy):
ArrayList list = new ArrayList();
list.Add(1);      // boxes int → object ⚠️
list.Add("oops"); // runtime error ❌ — mixed types
int val = (int)list[0]; // unboxing required ⚠️

// ✅ Use List<T> instead:
List<int> typed = new List<int> { 1, 2, 3 };
typed.Add(4);
```

### Dictionary vs Hashtable

```csharp
// Hashtable — legacy, non-generic, thread-unsafe:
Hashtable ht = new Hashtable();
ht["key"] = "value";              // stores as object ⚠️

// Dictionary<K,V> — generic, type-safe, faster:
var dict = new Dictionary<string, int>();
dict["Alice"] = 90;
dict["Bob"]   = 85;

// Safe access:
if (dict.TryGetValue("Alice", out int score))
    Console.WriteLine(score); // 90 ✅

// Thread-safe version:
var concurrent = new ConcurrentDictionary<string, int>();
```

### HashSet vs Dictionary

```csharp
// HashSet — unique values only, O(1) lookup:
var set = new HashSet<string> { "A", "B", "C" };
set.Add("A"); // ignored — already exists
Console.WriteLine(set.Contains("B")); // True ✅

// Use HashSet for: duplicate removal, fast membership check
// Use Dictionary for: key-value pairs, lookups by key
```

### IEnumerable vs IQueryable vs IList

| | IEnumerable\<T\> | IQueryable\<T\> | IList\<T\> |
|---|---|---|---|
| Execution | In-memory (LINQ to Objects) | Deferred → DB (LINQ to SQL) | Immediate, in-memory |
| Where/Select | Run in C# | Translated to SQL | Run in C# |
| Random access | ❌ | ❌ | ✅ |
| Count/Add | ❌ | ❌ | ✅ |
| Inherits | — | IEnumerable | IEnumerable, ICollection |

```csharp
// IQueryable — filter happens in SQL (efficient):
IQueryable<User> query = _db.Users.Where(u => u.Age > 18);
// SQL: SELECT * FROM Users WHERE Age > 18 ✅

// IEnumerable — filter happens in C# after full load (inefficient):
IEnumerable<User> query = _db.Users.AsEnumerable().Where(u => u.Age > 18);
// SQL: SELECT * FROM Users (loads ALL, then filters in memory) ❌
```

---

## 1.6 Delegates, Func, Action, LINQ

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/

### Delegates

**Definition:** A delegate is a **type-safe function pointer** — a variable that holds a reference to a method.

```csharp
// Delegate declaration:
public delegate int MathOperation(int a, int b);

// Implementation:
public class Calculator
{
    public static int Add(int a, int b) => a + b;
    public static int Mul(int a, int b) => a * b;
}

// Usage:
MathOperation op = Calculator.Add;
Console.WriteLine(op(3, 4)); // 7

op = Calculator.Mul;
Console.WriteLine(op(3, 4)); // 12

// Multicast delegate:
op += Calculator.Add; // chain multiple methods
```

### Func vs Action

```csharp
// Func<TIn..., TOut> — has return value:
Func<int, int, int> add    = (a, b) => a + b;
Func<string, string> upper = s => s.ToUpper();
Console.WriteLine(add(3, 4));      // 7
Console.WriteLine(upper("hello")); // HELLO

// Action<TIn...> — returns void:
Action<string> log = msg => Console.WriteLine($"[LOG] {msg}");
log("Started");

// Predicate<T> — returns bool (shorthand for Func<T, bool>):
Predicate<int> isEven = n => n % 2 == 0;
Console.WriteLine(isEven(4)); // True
```

---

### LINQ

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/linq/

```csharp
var employees = new List<Employee>
{
    new Employee { Id=1, Name="Alice", Dept="IT",  Salary=90000 },
    new Employee { Id=2, Name="Bob",   Dept="HR",  Salary=70000 },
    new Employee { Id=3, Name="Carol", Dept="IT",  Salary=95000 },
    new Employee { Id=4, Name="Dave",  Dept="HR",  Salary=72000 },
    new Employee { Id=5, Name="Eve",   Dept="IT",  Salary=88000 },
};

// Top 3 salaries:
var top3 = employees.OrderByDescending(e => e.Salary).Take(3).ToList();

// Find duplicates:
var duplicates = employees
    .GroupBy(e => e.Dept)
    .Where(g => g.Count() > 1)
    .SelectMany(g => g)
    .ToList();

// Group and sum:
var deptTotals = employees
    .GroupBy(e => e.Dept)
    .Select(g => new { Dept = g.Key, Total = g.Sum(e => e.Salary) });

// Left join (method syntax):
var result = employees.GroupJoin(
    departments,
    emp  => emp.DeptId,
    dept => dept.Id,
    (emp, depts) => new { emp.Name, DeptName = depts.FirstOrDefault()?.Name ?? "None" }
);

// Distinct pincodes with highest amount:
var orders = new List<Order>(); // 1000 orders with Id, Name, Amount, Pincode
var distinctPincodeHighest = orders
    .GroupBy(o => o.Pincode)
    .Select(g => new { Pincode = g.Key, MaxAmount = g.Max(o => o.Amount) })
    .OrderByDescending(x => x.MaxAmount);
```

---

## 1.7 Async / Await / Threading

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/

### Thread vs Task

| | Thread | Task |
|---|---|---|
| Level | OS thread | Abstraction over ThreadPool |
| Cost | ~1MB stack per thread | Lightweight |
| Return value | ❌ | ✅ |
| Exception handling | Complex | `try/catch` on await ✅ |
| Composition | Manual | `Task.WhenAll`, `Task.WhenAny` |

### What problem does async/await solve?

It solves **thread starvation / scalability** — NOT raw speed. Without async, a thread blocks while waiting for I/O (DB, HTTP, file). With async, the thread is returned to the pool to serve other requests during the wait.

❌ **Synchronous — blocks thread:**
```csharp
[HttpGet("data")]
public IActionResult GetData()
{
    var data = _httpClient.GetStringAsync("https://api.example.com").Result; // Blocks! ❌
    return Ok(data);
}
```

✅ **Async — releases thread during I/O wait:**
```csharp
[HttpGet("data")]
public async Task<IActionResult> GetDataAsync()
{
    var data = await _httpClient.GetStringAsync("https://api.example.com"); // Thread freed ✅
    return Ok(data);
}
```

### Race Condition in Banking

```csharp
// ❌ Race condition — two threads read same balance simultaneously:
public class BankAccount
{
    private decimal _balance = 1000;

    public void Withdraw(decimal amount)
    {
        if (_balance >= amount)     // Thread A reads 1000 ✅
        {
            // Thread B also reads 1000 here — both proceed ❌
            _balance -= amount;     // Both withdraw → balance goes negative!
        }
    }
}

// ✅ Fix with lock:
public class BankAccount
{
    private decimal _balance = 1000;
    private readonly object _lock = new object();

    public void Withdraw(decimal amount)
    {
        lock (_lock)
        {
            if (_balance >= amount)
                _balance -= amount; // Only one thread at a time ✅
        }
    }
}

// ✅ Or with SemaphoreSlim for async:
private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);

public async Task WithdrawAsync(decimal amount)
{
    await _semaphore.WaitAsync();
    try
    {
        if (_balance >= amount)
            _balance -= amount;
    }
    finally
    {
        _semaphore.Release();
    }
}
```

### Parallel Programming

```csharp
// Task.WhenAll — run tasks concurrently, await all:
var task1 = FetchUsersAsync();
var task2 = FetchOrdersAsync();
var (users, orders) = await (task1, task2); // Both run simultaneously ✅

// Parallel.ForEach — CPU-bound parallelism:
Parallel.ForEach(items, item => ProcessItem(item)); // Uses ThreadPool

// PLINQ:
var results = numbers.AsParallel().Where(n => IsPrime(n)).ToList();
```

---

## 1.8 Null Handling & Exception Keywords

### Throw vs Throw ex

```csharp
// ❌ throw ex — resets stack trace, loses origin:
try { RiskyOperation(); }
catch (Exception ex) { throw ex; } // Stack trace starts HERE ❌

// ✅ throw — preserves original stack trace:
try { RiskyOperation(); }
catch (Exception ex)
{
    _logger.LogError(ex, "Operation failed");
    throw; // Preserves full stack trace ✅
}

// ✅ Wrap with context:
catch (Exception ex)
{
    throw new ApplicationException("Payment processing failed", ex); // inner exception preserved ✅
}
```

### Null Reference Types

```csharp
// Types of null issues:
string name = null;
int len = name.Length;      // NullReferenceException at runtime ❌

// ✅ Null-conditional operator:
int? len = name?.Length;    // null if name is null ✅

// ✅ Null-coalescing:
string display = name ?? "Unknown"; // "Unknown" if name is null ✅

// ✅ Null-coalescing assignment:
name ??= "Default"; // assigns only if null ✅

// ✅ Nullable reference types (C#8+ — enable in .csproj):
// <Nullable>enable</Nullable>
string nonNull = "Hello";    // Cannot be null (warning if you try)
string? nullable = null;     // Explicitly nullable ✅
```

---

## 1.9 Misc C# Keywords & Features

### StringBuilder

**Definition:** `StringBuilder` is a mutable string buffer. Use it when concatenating strings in a loop — `string` concatenation creates a new object each time (O(n²)).

```csharp
// ❌ String concat in loop — O(n²) allocations:
string result = "";
for (int i = 0; i < 10000; i++)
    result += i.ToString(); // Each + creates a new string object!

// ✅ StringBuilder — single buffer, O(n):
var sb = new StringBuilder();
for (int i = 0; i < 10000; i++)
    sb.Append(i);
string result = sb.ToString();
```

---

### Partial Class

**Definition:** A `partial` class splits a class definition across multiple files. Compiled into one class. **Must be in the same project/assembly** — cannot span projects.

```csharp
// File1.cs:
public partial class Customer
{
    public int Id { get; set; }
    public string Name { get; set; }
}

// File2.cs (same namespace, same assembly only):
public partial class Customer
{
    public decimal GetBalance() => _account.Balance;
}
```

---

### Static Class

**Definition:** A `static` class cannot be instantiated. All members must be static. Used for utility/helper methods.

```csharp
public static class MathHelper
{
    public static double CircleArea(double r) => Math.PI * r * r;
    public static bool IsEven(int n) => n % 2 == 0;
}

// Usage:
double area = MathHelper.CircleArea(5); // ✅ no 'new' needed
// var h = new MathHelper(); // ❌ compile error
```

---

### var vs dynamic vs object

| | `var` | `dynamic` | `object` |
|---|---|---|---|
| Type resolved at | Compile time | Runtime | Compile time |
| IntelliSense | ✅ Full | ❌ None | ❌ Limited |
| Performance | Same as explicit | Slower (DLR) | Boxing if value type |
| Use case | Local type inference | Interop, reflection | Base type for all |

```csharp
var x = 42;         // int at compile time — same as 'int x = 42'
dynamic y = 42;     // runtime — can change type
y = "now a string"; // no compile error, but risky ⚠️

object z = 42;      // boxes int ⚠️
int back = (int)z;  // unbox — must cast
```

---

### First(), FirstOrDefault(), Single(), SingleOrDefault()

| Method | Expects | If empty | If multiple |
|---|---|---|---|
| `First()` | ≥1 match | Exception ❌ | Returns first |
| `FirstOrDefault()` | 0 or more | `default(T)` ✅ | Returns first |
| `Single()` | exactly 1 | Exception ❌ | Exception ❌ |
| `SingleOrDefault()` | 0 or 1 | `default(T)` ✅ | Exception ❌ |

```csharp
var users = _db.Users.Where(u => u.Id == id);

// Use Single() when you KNOW exactly one result should exist:
var user = users.Single(); // throws if 0 or 2+ — use for PK lookups

// Use FirstOrDefault() for flexible queries:
var user = users.FirstOrDefault(); // null if not found — safer ✅
```

---

### Primary vs Secondary Constructor (C#12)

```csharp
// Primary constructor (C#12) — parameters available in entire class body:
public class Point(int x, int y)
{
    public int X { get; } = x;
    public int Y { get; } = y;
    public double Length => Math.Sqrt(X * X + Y * Y);
}

// Constructor chaining (secondary):
public class Person
{
    public string Name { get; }
    public int Age { get; }

    public Person(string name) : this(name, 0) { }       // chains to below
    public Person(string name, int age)
    {
        Name = name;
        Age = age;
    }
}
```

---

# 2. ASP.NET Core / Web API

---

## 2.1 Request Pipeline & Middleware

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/

### What is Middleware?

**Definition:** Middleware is software assembled into the request pipeline to handle requests and responses. Each middleware can short-circuit or pass control to the next component.

```
Request → MW1 → MW2 → MW3 → Controller → MW3 → MW2 → MW1 → Response
```

### App.Use() vs App.Run()

```csharp
// App.Use() — passes to next middleware:
app.Use(async (context, next) =>
{
    Console.WriteLine("Before");
    await next.Invoke(); // ← calls next middleware ✅
    Console.WriteLine("After");
});

// App.Run() — TERMINAL: does NOT call next:
app.Run(async (context) =>
{
    await context.Response.WriteAsync("Done"); // Pipeline ends here
    // ❌ Nothing after this runs
});
```

### Custom Middleware

```csharp
public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        _logger.LogInformation("→ {Method} {Path}", context.Request.Method, context.Request.Path);
        var sw = Stopwatch.StartNew();

        await _next(context); // ← continue pipeline

        sw.Stop();
        _logger.LogInformation("← {StatusCode} in {Ms}ms", context.Response.StatusCode, sw.ElapsedMilliseconds);
    }
}

// Extension method:
public static class MiddlewareExtensions
{
    public static IApplicationBuilder UseRequestLogging(this IApplicationBuilder app)
        => app.UseMiddleware<RequestLoggingMiddleware>();
}

// Registration in Program.cs — ORDER MATTERS:
app.UseExceptionHandler("/error"); // ← must be first!
app.UseHttpsRedirection();
app.UseAuthentication();           // ← before Authorization!
app.UseAuthorization();
app.UseRequestLogging();           // custom
app.MapControllers();
```

### Middleware vs Filters

| | Middleware | Filters |
|---|---|---|
| Scope | Entire pipeline | MVC action level |
| Access to controller context | ❌ | ✅ |
| Registered in | `Program.cs` | Controller/Action attribute |
| Use for | Auth, logging, exceptions | Validation, action-specific logic |

---

## 2.2 Dependency Injection & Lifetimes

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection

### Singleton vs Scoped vs Transient

| Lifetime | Created | Shared | Use For |
|---|---|---|---|
| `Singleton` | Once at app start | All requests & users | Config, caches, heavy clients |
| `Scoped` | Once per HTTP request | Within same request | DbContext, unit of work |
| `Transient` | Every injection | Never | Lightweight, stateless services |

```csharp
// Registration:
builder.Services.AddSingleton<IAppConfig, AppConfig>();      // one instance ever
builder.Services.AddScoped<IOrderService, OrderService>();   // one per request
builder.Services.AddTransient<IEmailSender, EmailSender>();  // new each time

// ❌ Common mistake — injecting Scoped into Singleton:
builder.Services.AddSingleton<MyService>(); // MyService depends on IOrderService (Scoped)
// Result: Scoped service captured in Singleton → state leaks between requests!

// ✅ Fix: inject IServiceScopeFactory to Singleton and create scope manually:
public class MyService
{
    private readonly IServiceScopeFactory _scopeFactory;
    public MyService(IServiceScopeFactory f) => _scopeFactory = f;

    public void DoWork()
    {
        using var scope = _scopeFactory.CreateScope();
        var orderSvc = scope.ServiceProvider.GetRequiredService<IOrderService>();
        orderSvc.Process();
    }
}
```

### What happens when DbContext is Singleton?

```csharp
// ❌ NEVER do this:
builder.Services.AddSingleton<AppDbContext>(); // shared across ALL requests!

// Problems:
// 1. EF tracking is NOT thread-safe → concurrent request crashes
// 2. Change tracking accumulates across requests → memory leak
// 3. Stale data — cached entities never refreshed

// ✅ Always use AddDbContext (registers as Scoped by default):
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));
```

---

## 2.3 Controllers, Routing, Model Binding

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/web-api/

### Full REST Controller Skeleton

```csharp
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _service;
    public OrdersController(IOrderService service) => _service = service;

    // GET api/orders
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OrderDto>>> GetAll()
    {
        var orders = await _service.GetAllAsync();
        return Ok(orders);
    }

    // GET api/orders/5
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDto>> GetById(int id)
    {
        var order = await _service.GetByIdAsync(id);
        return order is null ? NotFound() : Ok(order);
    }

    // POST api/orders
    [HttpPost]
    public async Task<ActionResult<OrderDto>> Create([FromBody] CreateOrderRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var created = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created); // 201 ✅
    }

    // PUT api/orders/5 — full update
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateOrderRequest request)
    {
        // PUT replaces entire resource — unspecified fields reset to default ⚠️
        await _service.UpdateAsync(id, request);
        return NoContent(); // 204 ✅
    }

    // PATCH api/orders/5 — partial update
    [HttpPatch("{id:int}")]
    public async Task<IActionResult> Patch(int id, [FromBody] JsonPatchDocument<OrderDto> patch)
    {
        await _service.PatchAsync(id, patch);
        return NoContent();
    }

    // DELETE api/orders/5
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
```

### Model Binding Sources

```csharp
// [FromRoute]  → api/orders/{id}
// [FromQuery]  → api/orders?page=1&size=10
// [FromBody]   → JSON request body
// [FromHeader] → Authorization: Bearer token
// [FromForm]   → multipart/form-data

[HttpGet("search")]
public IActionResult Search([FromQuery] string name, [FromQuery] int page = 1)
{
    // GET /api/orders/search?name=Alice&page=2 ✅
}
```

### Model Validation

```csharp
public class CreateOrderRequest
{
    [Required(ErrorMessage = "Customer name is required")]
    [StringLength(100, MinimumLength = 2)]
    public string CustomerName { get; set; }

    [Range(0.01, double.MaxValue, ErrorMessage = "Amount must be positive")]
    public decimal Amount { get; set; }

    [EmailAddress]
    public string Email { get; set; }
}

// [ApiController] automatically returns 400 with validation errors ✅
// Without [ApiController], check ModelState manually:
if (!ModelState.IsValid) return BadRequest(ModelState);
```

---

## 2.4 HTTP Methods & Status Codes

### When to use which method

| Method | Idempotent | Body | Use Case |
|---|---|---|---|
| GET | ✅ | ❌ | Retrieve |
| POST | ❌ | ✅ | Create |
| PUT | ✅ | ✅ | Full replace |
| PATCH | ❌ | ✅ | Partial update |
| DELETE | ✅ | Optional | Delete |

**PUT if you update only name (id, name, isActive)?**
All unspecified fields (isActive) get reset to defaults. PUT = full replace. Use PATCH for partial updates.

### Common Status Codes

```csharp
return Ok(data);             // 200 — success with body
return Created(...);         // 201 — created resource
return NoContent();          // 204 — success, no body
return BadRequest(err);      // 400 — invalid request / validation fail
return Unauthorized();       // 401 — not authenticated
return Forbid();             // 403 — authenticated but no permission
return NotFound();           // 404 — resource not found
return Conflict();           // 409 — duplicate / concurrency conflict
return StatusCode(500, msg); // 500 — server error
```

**401 vs 403:**
- `401 Unauthorized` — You are NOT logged in (send credentials).
- `403 Forbidden` — You ARE logged in but don't have permission.

---

## 2.5 Authentication & Authorization

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/security/

### JWT Token Flow

```
1. User POSTs /auth/login { email, password }
2. Server validates credentials
3. Server creates JWT:
   Header: { alg: HS256, typ: JWT }
   Payload: { sub: userId, role: Admin, exp: 1h, iat: now }
   Signature: HMACSHA256(base64Header + "." + base64Payload, secretKey)
4. Server returns: { accessToken, refreshToken }
5. Client stores token (memory/httpOnly cookie)
6. Client sends: Authorization: Bearer <token>
7. Server validates signature + expiry on every request
```

```csharp
// JWT configuration:
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer   = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidIssuer      = config["Jwt:Issuer"],
            ValidAudience    = config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(config["Jwt:Secret"]))
        };
    });

// Token generation:
public string GenerateToken(User user)
{
    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub,   user.Id.ToString()),
        new Claim(ClaimTypes.Role,               user.Role),
        new Claim(JwtRegisteredClaimNames.Email, user.Email),
    };

    var key   = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secret));
    var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
    var token = new JwtSecurityToken(
        issuer:   _issuer,
        audience: _audience,
        claims:   claims,
        expires:  DateTime.UtcNow.AddHours(1),
        signingCredentials: creds);

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

### What if JWT token expires?

1. Access token expires (e.g. 15 min)
2. Client sends refresh token to `/auth/refresh`
3. Server validates refresh token (stored in DB/Redis)
4. Server issues new access token + optionally rotates refresh token

### Role-based vs Policy-based Auth

```csharp
// Role-based:
[Authorize(Roles = "Admin,Manager")]
public IActionResult AdminOnly() { }

// Policy-based (more flexible):
builder.Services.AddAuthorization(opts =>
{
    opts.AddPolicy("CanEditOrders", policy =>
        policy.RequireRole("Admin")
              .RequireClaim("department", "Sales"));
});

[Authorize(Policy = "CanEditOrders")]
public IActionResult EditOrder() { }

// Bypass auth for specific condition (AllowAnonymous):
[AllowAnonymous]
[HttpGet("public")]
public IActionResult PublicEndpoint() { }
```

### Session-based vs JWT

| | Session | JWT |
|---|---|---|
| State stored | Server (DB/Redis) | Client (token itself) |
| Scalability | Requires sticky sessions or shared store | Stateless ✅ |
| Revocation | Easy (delete session) | Hard (need token blocklist) |
| Suitable for | MVC apps | APIs, microservices, mobile |

---

## 2.6 Performance — Caching, Async, Pagination

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/performance/caching/overview

### Caching Types

| Type | Where | Use Case |
|---|---|---|
| In-Memory | App server RAM | Single server, fast lookup |
| Distributed (Redis) | Separate cache server | Multi-server, shared state |
| Response Cache | HTTP headers | GET endpoints, CDN-friendly |

```csharp
// In-memory cache:
builder.Services.AddMemoryCache();

public class ProductService
{
    private readonly IMemoryCache _cache;
    private readonly AppDbContext _db;

    public async Task<List<Product>> GetProductsAsync()
    {
        return await _cache.GetOrCreateAsync("products", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await _db.Products.ToListAsync(); // only hits DB on cache miss ✅
        });
    }
}

// Redis distributed cache:
builder.Services.AddStackExchangeRedisCache(opts =>
    opts.Configuration = "localhost:6379");
```

### Pagination

```csharp
// ❌ Loading all records — memory bomb for large datasets:
var allOrders = await _db.Orders.ToListAsync();
var page = allOrders.Skip((pageNum - 1) * pageSize).Take(pageSize).ToList(); // ❌ loads all first

// ✅ Efficient pagination — SQL OFFSET/FETCH:
public async Task<PagedResult<Order>> GetOrdersAsync(int pageNum, int pageSize)
{
    var totalCount = await _db.Orders.CountAsync();
    var items = await _db.Orders
        .OrderBy(o => o.Id)
        .Skip((pageNum - 1) * pageSize)
        .Take(pageSize)
        .ToListAsync(); // SQL: OFFSET N ROWS FETCH NEXT M ROWS ONLY ✅

    return new PagedResult<Order>
    {
        Items      = items,
        TotalCount = totalCount,
        PageNumber = pageNum,
        PageSize   = pageSize,
        TotalPages = (int)Math.Ceiling((double)totalCount / pageSize)
    };
}
```

### API returning millions of records

```csharp
// ✅ Streaming with IAsyncEnumerable (no full load):
[HttpGet("stream")]
public async IAsyncEnumerable<Order> StreamOrders()
{
    await foreach (var order in _db.Orders.AsAsyncEnumerable())
        yield return order; // sends each row as it arrives ✅
}
```

### Rate Limiting (ASP.NET Core 7+)

```csharp
builder.Services.AddRateLimiter(opts =>
{
    opts.AddFixedWindowLimiter("default", limiterOpts =>
    {
        limiterOpts.PermitLimit        = 100;
        limiterOpts.Window             = TimeSpan.FromMinutes(1);
        limiterOpts.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOpts.QueueLimit         = 10;
    });
    opts.RejectionStatusCode = 429;
});

app.UseRateLimiter();

[EnableRateLimiting("default")]
[HttpGet]
public IActionResult Get() { }
```

---

## 2.7 Testing — Unit & Integration

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/core/testing/

### Unit Testing with xUnit + Moq

```csharp
// Service under test:
public class OrderService
{
    private readonly IOrderRepository _repo;
    public OrderService(IOrderRepository repo) => _repo = repo;
    public async Task<OrderDto> GetOrderAsync(int id)
    {
        var order = await _repo.GetByIdAsync(id);
        return order is null ? throw new NotFoundException() : MapToDto(order);
    }
}

// Unit test:
public class OrderServiceTests
{
    [Fact]
    public async Task GetOrderAsync_ReturnsDto_WhenOrderExists()
    {
        // Arrange
        var mockRepo = new Mock<IOrderRepository>();
        mockRepo.Setup(r => r.GetByIdAsync(1))
                .ReturnsAsync(new Order { Id = 1, Amount = 100 });

        var service = new OrderService(mockRepo.Object);

        // Act
        var result = await service.GetOrderAsync(1);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(1,   result.Id);
        Assert.Equal(100, result.Amount);
    }

    [Fact]
    public async Task GetOrderAsync_ThrowsNotFoundException_WhenNotFound()
    {
        var mockRepo = new Mock<IOrderRepository>();
        mockRepo.Setup(r => r.GetByIdAsync(99)).ReturnsAsync((Order)null);

        var service = new OrderService(mockRepo.Object);

        await Assert.ThrowsAsync<NotFoundException>(() => service.GetOrderAsync(99));
    }
}
```

### Integration Test with WebApplicationFactory

```csharp
public class OrdersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace real DB with in-memory:
                services.RemoveAll<AppDbContext>();
                services.AddDbContext<AppDbContext>(opts =>
                    opts.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetOrders_Returns200()
    {
        var response = await _client.GetAsync("/api/orders");
        response.EnsureSuccessStatusCode();
    }
}
```

**What makes a test valuable?**
- Tests a real business rule, not implementation details
- Fast and deterministic
- Fails for the right reason
- Easy to understand what went wrong

---

## 2.8 Logging & Observability

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/

### Structured Logging with Serilog

```csharp
// Why structured logging? Log as data, not strings — query by field in Splunk/Seq/Grafana
// ❌ String logging — can't query by orderId:
_logger.LogInformation("Order 123 placed by user 456"); // ❌

// ✅ Structured logging — queryable fields:
_logger.LogInformation("Order {OrderId} placed by {UserId}", orderId, userId); // ✅

// Serilog setup in Program.cs:
builder.Host.UseSerilog((ctx, config) =>
{
    config
        .ReadFrom.Configuration(ctx.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console(new JsonFormatter())          // local
        .WriteTo.ApplicationInsights(telemetryClient); // Azure
});
```

### Global Exception Handling

```csharp
// Custom exception middleware:
public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (NotFoundException ex)
        {
            _logger.LogWarning(ex, "Resource not found");
            ctx.Response.StatusCode  = 404;
            await ctx.Response.WriteAsJsonAsync(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception");
            ctx.Response.StatusCode  = 500;
            await ctx.Response.WriteAsJsonAsync(new { error = "An unexpected error occurred" });
        }
    }
}
```

---

# 3. SQL Server

---

## 3.1 Indexes & Performance

> 📚 Reference: https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes

### Clustered vs Non-Clustered Index

| | Clustered | Non-Clustered |
|---|---|---|
| Stores actual data rows | ✅ Yes | ❌ No (stores pointer) |
| Per table limit | 1 only | Up to 999 |
| Default on | Primary Key | Any column(s) |
| Lookup speed | Fastest for PK | Good with covering index |

```sql
-- Clustered index (usually primary key):
CREATE CLUSTERED INDEX CIX_Users_Id ON Users(Id);

-- Non-clustered index on frequently queried column:
CREATE NONCLUSTERED INDEX NIX_Users_Email ON Users(Email);

-- Covering index — includes extra columns to avoid key lookup:
CREATE NONCLUSTERED INDEX NIX_Orders_CustomerId
ON Orders(CustomerId)
INCLUDE (Amount, OrderDate);  -- avoids trips back to clustered index ✅
```

### Query Performance Optimization Techniques

1. **Use indexes** on WHERE, JOIN, ORDER BY columns
2. **Avoid SELECT \*** — fetch only needed columns
3. **Use covering indexes** to avoid key lookups
4. **Avoid functions on indexed columns in WHERE** (defeats index):
   ```sql
   -- ❌ Index not used:
   WHERE YEAR(OrderDate) = 2024
   -- ✅ Index used:
   WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'
   ```
5. **Use pagination** (OFFSET/FETCH) instead of TOP on huge tables
6. **Avoid implicit type conversion** in JOINs/WHERE
7. **Use `SET NOCOUNT ON`** in stored procedures
8. **Analyse execution plans** — look for Table Scan vs Index Seek

### Find missing index

```sql
-- Missing index suggestions from SQL Server:
SELECT
    mid.statement        AS TableName,
    migs.avg_user_impact AS PotentialImprovement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_details     mid
JOIN sys.dm_db_missing_index_groups      mig  ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
ORDER BY migs.avg_user_impact DESC;
```

---

## 3.2 Joins, Aggregates & Window Functions

### Join Types

```sql
-- Sample:
-- Employees: Id, Name, DeptId
-- Departments: Id, Name

-- INNER JOIN — only matched rows:
SELECT e.Name, d.Name AS Dept
FROM Employees e
INNER JOIN Departments d ON e.DeptId = d.Id;

-- LEFT JOIN — all employees, matched dept or NULL:
SELECT e.Name, d.Name
FROM Employees e
LEFT JOIN Departments d ON e.DeptId = d.Id;

-- RIGHT JOIN — all departments, matched employee or NULL:
SELECT e.Name, d.Name
FROM Employees e
RIGHT JOIN Departments d ON e.DeptId = d.Id;

-- FULL OUTER JOIN — all rows from both, NULLs where no match:
SELECT e.Name, d.Name
FROM Employees e
FULL OUTER JOIN Departments d ON e.DeptId = d.Id;

-- SELF JOIN — employee and their manager (same table):
SELECT e.Name AS Employee, m.Name AS Manager
FROM Employees e
LEFT JOIN Employees m ON e.ManagerId = m.Id;

-- Department with 0 employees:
SELECT d.Name
FROM Departments d
LEFT JOIN Employees e ON d.Id = e.DeptId
WHERE e.Id IS NULL;
```

### Window Functions

```sql
-- RANK vs DENSE_RANK:
-- Data: Salaries: 90000, 90000, 80000, 70000
-- RANK:       1, 1, 3, 4  (skips 2)
-- DENSE_RANK: 1, 1, 2, 3  (no skip)
-- ROW_NUMBER: 1, 2, 3, 4  (always unique)

SELECT
    Name,
    Salary,
    RANK()       OVER (ORDER BY Salary DESC) AS RankNum,
    DENSE_RANK() OVER (ORDER BY Salary DESC) AS DenseRankNum,
    ROW_NUMBER() OVER (ORDER BY Salary DESC) AS RowNum
FROM Employees;

-- Nth highest salary:
SELECT Salary FROM (
    SELECT Salary, DENSE_RANK() OVER (ORDER BY Salary DESC) AS Rnk
    FROM Employees
) ranked
WHERE Rnk = 5; -- 5th highest ✅

-- 2nd highest (alternative):
SELECT MAX(Salary) FROM Employees
WHERE Salary < (SELECT MAX(Salary) FROM Employees);
```

### Common Query Patterns

```sql
-- Duplicate records:
SELECT Name, COUNT(*) AS Count
FROM Employees
GROUP BY Name
HAVING COUNT(*) > 1;

-- Delete ONE duplicate, keep one:
WITH CTE AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Name ORDER BY Id) AS rn
    FROM Employees
)
DELETE FROM CTE WHERE rn > 1;

-- Swap Male/Female:
UPDATE Employees
SET Gender = CASE WHEN Gender = 'Male' THEN 'Female' ELSE 'Male' END;

-- Toggle isActive (0↔1):
UPDATE Users SET IsActive = 1 - IsActive;

-- 2nd highest salary using CTE:
WITH Ranked AS (
    SELECT Salary, DENSE_RANK() OVER (ORDER BY Salary DESC) AS Rnk
    FROM Employees
)
SELECT TOP 1 Salary FROM Ranked WHERE Rnk = 2;

-- Employees with >= 2 projects:
SELECT EmployeeId, COUNT(ProjectId) AS ProjectCount
FROM EmployeeProjects
GROUP BY EmployeeId
HAVING COUNT(ProjectId) >= 2;

-- Customers with > 3 orders:
SELECT c.Id AS CustId, c.Name AS CustName, COUNT(o.Id) AS OrderCount
FROM Customers c
JOIN Orders o ON c.Id = o.CustomerId
GROUP BY c.Id, c.Name
HAVING COUNT(o.Id) > 3;

-- Laptop sales including zero-sales brands:
SELECT b.BrandName, COALESCE(SUM(s.Quantity), 0) AS TotalQuantity
FROM Brands b
LEFT JOIN Sales s ON b.Id = s.BrandId AND s.ProductType = 'Laptop'
GROUP BY b.BrandName;

-- SELECT * FROM Employees WHERE 1=0:
-- Returns empty result set WITH column structure — used to create empty typed temp tables

-- SELECT * INTO newtable FROM oldtable WHERE 1=0:
-- Creates newtable with same schema but NO data ✅ useful for staging

-- SELECT * INTO newtable FROM oldtable WHERE 1=1:
-- Creates newtable and COPIES all data ✅ useful for backup/clone

-- COUNT(*) vs COUNT(name) vs COUNT(address):
-- COUNT(*) counts all rows including NULLs — fastest
-- COUNT(name) counts non-NULL name values
-- COUNT(address) counts non-NULL address values — slowest if many NULLs

-- ISNULL vs COALESCE:
SELECT ISNULL(commission, 0) FROM Employees;       -- 2 args only
SELECT COALESCE(commission, bonus, 0) FROM Employees; -- multiple args, first non-null ✅

-- Last inserted record:
SELECT SCOPE_IDENTITY();          -- last identity in current scope ✅
SELECT @@IDENTITY;                 -- last identity in session (any table)
SELECT IDENT_CURRENT('tableName'); -- last identity for specific table

-- SQL Pagination:
SELECT * FROM Orders
ORDER BY Id
OFFSET (@PageNum - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;
```

---

## 3.3 CTEs, Temp Tables, Stored Procedures, Functions

### CTE vs Temp Table

| | CTE | Temp Table |
|---|---|---|
| Scope | Single statement | Session / stored proc |
| Indexed | ❌ | ✅ |
| Reusable | ❌ | ✅ |
| Performance | Better for simple queries | Better for complex multi-step |

```sql
-- CTE:
WITH TopSalaries AS (
    SELECT *, DENSE_RANK() OVER (ORDER BY Salary DESC) AS Rnk
    FROM Employees
)
SELECT * FROM TopSalaries WHERE Rnk <= 3;

-- Temp table:
CREATE TABLE #TempEmployees (Id INT, Name NVARCHAR(100), Salary DECIMAL(10,2));
INSERT INTO #TempEmployees SELECT Id, Name, Salary FROM Employees WHERE DeptId = 1;
SELECT * FROM #TempEmployees;
DROP TABLE #TempEmployees;

-- ⚠️ Temp tables CANNOT be used inside user-defined functions
-- ✅ Temp tables CAN be used inside stored procedures
```

### Stored Procedure vs Function

| | Stored Procedure | Function |
|---|---|---|
| Return type | None/output params | Scalar or table |
| Can call in SELECT | ❌ | ✅ |
| Can use in WHERE/JOIN | ❌ | ✅ (table-valued) |
| DML (INSERT/UPDATE) | ✅ | ❌ (scalar) |
| Error handling | ✅ TRY/CATCH | Limited |

```sql
-- Stored Procedure:
CREATE PROCEDURE GetEmployeesByDept
    @DeptId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Employees WHERE DeptId = @DeptId;
END;
EXEC GetEmployeesByDept @DeptId = 1;

-- Scalar Function:
CREATE FUNCTION GetFullName(@FirstName NVARCHAR(50), @LastName NVARCHAR(50))
RETURNS NVARCHAR(100)
AS
BEGIN
    RETURN @FirstName + ' ' + @LastName;
END;
SELECT dbo.GetFullName(FirstName, LastName) FROM Employees; -- usable in SELECT ✅

-- Table-Valued Function:
CREATE FUNCTION GetOrdersByCustomer(@CustomerId INT)
RETURNS TABLE
AS
RETURN (
    SELECT * FROM Orders WHERE CustomerId = @CustomerId
);
SELECT * FROM dbo.GetOrdersByCustomer(1); -- usable in FROM ✅
```

---

## 3.4 ACID, Transactions & Concurrency

### ACID Properties

| Property | Definition |
|---|---|
| **Atomicity** | All operations succeed or all fail (all-or-nothing) |
| **Consistency** | DB goes from one valid state to another |
| **Isolation** | Concurrent transactions don't interfere |
| **Durability** | Committed data survives crashes |

```sql
-- Transaction example (banking transfer):
BEGIN TRANSACTION;
BEGIN TRY
    UPDATE Accounts SET Balance = Balance - 500 WHERE Id = 1; -- debit
    UPDATE Accounts SET Balance = Balance + 500 WHERE Id = 2; -- credit

    IF @@ERROR <> 0
        ROLLBACK TRANSACTION;
    ELSE
        COMMIT TRANSACTION; -- both succeed or both rolled back ✅
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

### Optimistic vs Pessimistic Concurrency

```sql
-- Optimistic concurrency (rowversion/timestamp):
-- Add RowVersion column to table:
ALTER TABLE Orders ADD RowVersion ROWVERSION NOT NULL;

-- Update only if RowVersion matches what we read:
UPDATE Orders
SET Amount = @NewAmount, Status = @NewStatus
WHERE Id = @Id AND RowVersion = @OriginalRowVersion;
-- If 0 rows affected → someone else modified it → show conflict error to user ✅

-- Pessimistic concurrency (lock the row):
BEGIN TRANSACTION;
SELECT * FROM Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @Id; -- locks row
-- Do work...
UPDATE Orders SET Status = 'Processing' WHERE Id = @Id;
COMMIT TRANSACTION;
```

---

## 3.5 Common Query Patterns

### WHERE vs HAVING

```sql
-- WHERE filters individual rows BEFORE GROUP BY
-- HAVING filters groups AFTER GROUP BY

-- ✅ Correct usage:
SELECT DeptId, AVG(Salary) AS AvgSalary
FROM Employees
WHERE IsActive = 1              -- filter rows first ✅
GROUP BY DeptId
HAVING AVG(Salary) > 70000;    -- filter groups ✅

-- ❌ Can't use aggregate in WHERE:
-- WHERE AVG(Salary) > 70000   -- syntax error!
```

### UNION vs UNION ALL

```sql
-- UNION — removes duplicates (slower, sorts internally):
SELECT Name FROM Customers
UNION
SELECT Name FROM Prospects; -- removes duplicate names

-- UNION ALL — keeps duplicates (faster):
SELECT Name FROM Customers
UNION ALL
SELECT Name FROM Prospects; -- all rows, including dupes ✅ (use when no dupes expected)
```

### Primary Key vs Unique Key vs Foreign Key

```sql
-- Primary Key: uniquely identifies each row, NOT NULL, one per table
-- Unique Key: ensures uniqueness, allows ONE NULL, multiple per table
-- Foreign Key: references PK of another table, maintains referential integrity

CREATE TABLE Users (
    Id       INT PRIMARY KEY IDENTITY,          -- PK: not null, unique, clustered index
    Email    NVARCHAR(255) UNIQUE,              -- unique but allows null
    Username NVARCHAR(50) NOT NULL
);

CREATE TABLE Orders (
    Id         INT PRIMARY KEY IDENTITY,
    UserId     INT NOT NULL,
    FOREIGN KEY (UserId) REFERENCES Users(Id)   -- FK: must exist in Users ✅
);
```

---

# 4. Entity Framework / ORM

> 📚 Reference: https://learn.microsoft.com/en-us/ef/core/

## EF Core vs Dapper vs ADO.NET

| | EF Core | Dapper | ADO.NET |
|---|---|---|---|
| Abstraction | High | Medium | Low |
| Performance | Good | Excellent | Excellent |
| Raw SQL | `FromSqlRaw()` | Native | Native |
| Migrations | ✅ | ❌ | ❌ |
| LINQ | ✅ | ❌ | ❌ |
| Use when | CRUD-heavy apps | Complex queries, perf | Full control |

```csharp
// ADO.NET:
using var conn = new SqlConnection(connectionString);
conn.Open();
using var cmd = new SqlCommand("SELECT * FROM Users WHERE Id = @Id", conn);
cmd.Parameters.AddWithValue("@Id", userId);
using var reader = cmd.ExecuteReader();

// Dapper:
using var conn = new SqlConnection(connectionString);
var user = await conn.QueryFirstOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Id = @Id", new { Id = userId });

// EF Core:
var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId);
```

## N+1 Problem

```csharp
// ❌ N+1 — 1 query for orders + N queries for each customer:
var orders = await _db.Orders.ToListAsync();
foreach (var order in orders)
{
    var customer = await _db.Customers.FindAsync(order.CustomerId); // N queries!
}

// ✅ Fix with Include (eager loading — 1 JOIN query):
var orders = await _db.Orders
    .Include(o => o.Customer)   // single JOIN query ✅
    .ToListAsync();

// ✅ Fix with explicit load for optional:
var orders = await _db.Orders
    .Include(o => o.Customer)
    .Include(o => o.Items)      // nested
    .ToListAsync();
```

## AsNoTracking

```csharp
// EF tracks entities by default — enables change detection and SaveChanges()
// ❌ Unnecessary tracking for read-only queries:
var products = await _db.Products.ToListAsync(); // EF tracks all in memory ❌

// ✅ AsNoTracking — faster queries, less memory for read-only:
var products = await _db.Products.AsNoTracking().ToListAsync(); // ✅

// Global default for read-heavy services:
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));
```

## EF Migrations

```bash
# Add migration after model change:
dotnet ef migrations add AddOrderStatus

# Apply to DB:
dotnet ef database update

# Revert last migration:
dotnet ef database update PreviousMigrationName

# Script SQL (production):
dotnet ef migrations script --output migration.sql

# Code First vs Database First:
# Code First  — define C# models → EF generates DB schema ✅ recommended
# DB First    — existing DB → EF generates C# models (legacy/external DBs)
```

## EF Concurrency (Optimistic)

```csharp
public class Order
{
    public int Id { get; set; }
    public decimal Amount { get; set; }

    [Timestamp]  // adds rowversion column ✅
    public byte[] RowVersion { get; set; }
}

// In controller:
try
{
    _db.Orders.Update(order);
    await _db.SaveChangesAsync();
}
catch (DbUpdateConcurrencyException ex)
{
    // Another user modified — return 409 Conflict ✅
    return Conflict("The record was modified by another user. Please refresh.");
}
```

---

# 5. Design Patterns & SOLID (Deep Dive)

> 📚 Reference: https://refactoring.guru/design-patterns/csharp

## Singleton Pattern

**Definition:** Ensures a class has **only one instance** globally and provides a global access point.

```csharp
// Thread-safe Singleton using Lazy<T>:
public class AppConfiguration
{
    private static readonly Lazy<AppConfiguration> _instance =
        new Lazy<AppConfiguration>(() => new AppConfiguration());

    private AppConfiguration()
    {
        ConnectionString = "Server=..."; // load from config
    }

    public static AppConfiguration Instance => _instance.Value;
    public string ConnectionString { get; private set; }
}

// Usage:
var config = AppConfiguration.Instance;

// ✅ In ASP.NET Core DI — use AddSingleton instead of manual Singleton:
builder.Services.AddSingleton<IAppConfiguration, AppConfiguration>();
```

## Repository Pattern

```csharp
public interface IOrderRepository
{
    Task<Order> GetByIdAsync(int id);
    Task<IEnumerable<Order>> GetAllAsync();
    Task AddAsync(Order order);
    Task UpdateAsync(Order order);
    Task DeleteAsync(int id);
}

public class EfOrderRepository : IOrderRepository
{
    private readonly AppDbContext _db;
    public EfOrderRepository(AppDbContext db) => _db = db;

    public Task<Order> GetByIdAsync(int id)
        => _db.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == id);

    public async Task AddAsync(Order order)
    {
        await _db.Orders.AddAsync(order);
        await _db.SaveChangesAsync();
    }
    // ... other methods
}

// Registration:
builder.Services.AddScoped<IOrderRepository, EfOrderRepository>();
```

## Strategy Pattern

```csharp
// Interest calculator — different strategies per account type:
public interface IInterestStrategy { decimal Calculate(decimal balance); }

public class SavingsInterest  : IInterestStrategy { public decimal Calculate(decimal b) => b * 0.05m; }
public class CurrentInterest  : IInterestStrategy { public decimal Calculate(decimal b) => b * 0.02m; }
public class FixedDepInterest : IInterestStrategy { public decimal Calculate(decimal b) => b * 0.08m; }

public class InterestCalculator
{
    private IInterestStrategy _strategy;
    public void SetStrategy(IInterestStrategy s) => _strategy = s;
    public decimal Calculate(decimal balance) => _strategy.Calculate(balance);
}
```

## Factory Pattern

```csharp
public interface INotification { void Send(string message); }
public class EmailNotification : INotification { public void Send(string m) => Console.WriteLine($"Email: {m}"); }
public class SmsNotification   : INotification { public void Send(string m) => Console.WriteLine($"SMS: {m}"); }

// Dictionary factory — doesn't violate OCP:
public class NotificationFactory
{
    private readonly Dictionary<string, Func<INotification>> _map = new()
    {
        ["email"] = () => new EmailNotification(),
        ["sms"]   = () => new SmsNotification(),
    };

    public INotification Create(string type)
        => _map.TryGetValue(type, out var factory)
            ? factory()
            : throw new ArgumentException($"Unknown type: {type}");
}

// Factory vs DI:
// Use Factory when: type decided at RUNTIME based on data
// Use DI when: type decided at STARTUP based on config
```

## CQRS

**Definition:** Command Query Responsibility Segregation — separate models for read (Query) and write (Command) operations.

```csharp
// MediatR-based CQRS:
// Command (write):
public record CreateOrderCommand(string CustomerName, decimal Amount) : IRequest<int>;

public class CreateOrderHandler : IRequestHandler<CreateOrderCommand, int>
{
    private readonly AppDbContext _db;
    public CreateOrderHandler(AppDbContext db) => _db = db;

    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var order = new Order { CustomerName = cmd.CustomerName, Amount = cmd.Amount };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync(ct);
        return order.Id;
    }
}

// Query (read):
public record GetOrderQuery(int Id) : IRequest<OrderDto>;

public class GetOrderHandler : IRequestHandler<GetOrderQuery, OrderDto>
{
    private readonly AppDbContext _db;
    public GetOrderHandler(AppDbContext db) => _db = db;

    public async Task<OrderDto> Handle(GetOrderQuery q, CancellationToken ct)
        => await _db.Orders.AsNoTracking()
                    .Where(o => o.Id == q.Id)
                    .Select(o => new OrderDto(o.Id, o.CustomerName, o.Amount))
                    .FirstOrDefaultAsync(ct);
}

// Controller:
[HttpPost]
public async Task<IActionResult> Create([FromBody] CreateOrderCommand cmd)
    => Ok(await _mediator.Send(cmd));
```

---

# 6. Microservices

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/

## Communication Patterns

```
Synchronous:  Service A → HTTP/gRPC → Service B (real-time response needed)
Asynchronous: Service A → Message Queue → Service B (decoupled, resilient)
```

## Service Communication

```csharp
// HTTP client (synchronous):
builder.Services.AddHttpClient<IOrderServiceClient, OrderServiceClient>(client =>
{
    client.BaseAddress = new Uri("https://order-service");
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddPolicyHandler(GetRetryPolicy())          // Polly retry
.AddPolicyHandler(GetCircuitBreakerPolicy()); // Circuit breaker

// Circuit Breaker — if service keeps failing, stop calling it:
static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
    => HttpPolicyExtensions
        .HandleTransientHttpError()
        .CircuitBreakerAsync(5, TimeSpan.FromSeconds(30)); // open after 5 failures ✅
```

## Azure Service Bus — Queue vs Topic

| Queue | Topic |
|---|---|
| One consumer | Multiple subscribers |
| Point-to-point | Publish/Subscribe |
| Use when: one processor per message | Use when: multiple services need same message |

```csharp
// Send message to Service Bus:
await using var client = new ServiceBusClient(connectionString);
var sender = client.CreateSender("orders-queue");
await sender.SendMessageAsync(new ServiceBusMessage(JsonSerializer.Serialize(order)));

// Idempotency — handle duplicate messages safely:
public async Task ProcessOrderAsync(string messageId, OrderEvent order)
{
    if (await _db.ProcessedMessages.AnyAsync(m => m.Id == messageId))
        return; // already processed — safe to skip ✅

    await ProcessAsync(order);
    _db.ProcessedMessages.Add(new ProcessedMessage { Id = messageId });
    await _db.SaveChangesAsync();
}
```

## Distributed Tracing

```csharp
// Add correlation ID across services:
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation()
        .AddOtlpExporter()); // to Jaeger / Azure App Insights

// Each request gets a TraceId — follow it across service boundaries ✅
```

---

# 7. Azure / Cloud

> 📚 Reference: https://learn.microsoft.com/en-us/azure/

## Azure App Service vs VM

| App Service | Azure VM |
|---|---|
| PaaS — fully managed | IaaS — you manage OS |
| Auto-scale, SSL, deployment slots | Full OS control |
| No OS patching | Manual patching required |
| Best for: web apps, APIs | Best for: legacy apps, custom OS config |

## Azure Functions

```csharp
// HTTP Trigger:
public class OrderFunction
{
    [Function("CreateOrder")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        var order = await req.ReadFromJsonAsync<CreateOrderRequest>();
        // process...
        var response = req.CreateResponse(HttpStatusCode.Created);
        return response;
    }
}

// Timer Trigger (scheduled):
public class DailyReportFunction
{
    [Function("DailyReport")]
    public void Run([TimerTrigger("0 0 6 * * *")] TimerInfo timer) // 6 AM daily
    {
        _reportService.GenerateDailyReport();
    }
}

// Queue Trigger:
public class OrderProcessorFunction
{
    [Function("ProcessOrder")]
    public async Task Run([ServiceBusTrigger("orders-queue")] ServiceBusReceivedMessage msg)
    {
        var order = JsonSerializer.Deserialize<Order>(msg.Body);
        await _orderService.ProcessAsync(order);
    }
}
```

## Azure Key Vault

```csharp
// Why: store secrets (connection strings, API keys) outside code/config ✅
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{vaultName}.vault.azure.net/"),
    new DefaultAzureCredential()); // uses Managed Identity — no secrets in code! ✅

// Access:
var secret = configuration["MySecret"]; // reads from Key Vault transparently ✅
```

## Managed Identity

```csharp
// What: Azure resource authenticates to other Azure services WITHOUT credentials
// Why: eliminates secrets from code entirely

// App Service → Key Vault without password:
var client   = new SecretClient(
    new Uri("https://myvault.vault.azure.net/"),
    new DefaultAzureCredential()); // uses system-assigned managed identity ✅

var secret = await client.GetSecretAsync("DatabasePassword");
```

## CI/CD Pipeline (Azure DevOps)

```yaml
# azure-pipelines.yml:
trigger:
  branches:
    include: [ main ]

stages:
- stage: Build
  jobs:
  - job: BuildJob
    steps:
    - task: DotNetCoreCLI@2
      inputs:
        command: restore
    - task: DotNetCoreCLI@2
      inputs:
        command: build
        arguments: --configuration Release
    - task: DotNetCoreCLI@2
      inputs:
        command: test
    - task: DotNetCoreCLI@2
      inputs:
        command: publish
        publishWebProjects: true

- stage: Deploy
  jobs:
  - deployment: DeployToAppService
    environment: Production
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            inputs:
              appName: my-api
              package: '$(Pipeline.Workspace)/**/*.zip'
```

---

# 8. Angular

> 📚 Reference: https://angular.dev/

## Core Concepts

### Component Lifecycle Hooks

```typescript
@Component({ selector: 'app-user', template: `<h1>{{title}}</h1>` })
export class UserComponent implements OnInit, OnDestroy {
    title = 'User';
    private destroy$ = new Subject<void>();

    constructor(private userService: UserService) {
        // DO NOT call APIs here — injector not ready for data fetching ❌
    }

    ngOnInit(): void {
        // ✅ Safe to call APIs here
        this.userService.getUsers()
            .pipe(takeUntil(this.destroy$))
            .subscribe(users => this.users = users);
    }

    ngOnDestroy(): void {
        this.destroy$.next();
        this.destroy$.complete(); // prevent memory leak ✅
    }
}

// Hook order: constructor → ngOnChanges → ngOnInit → ngDoCheck
//             → ngAfterContentInit → ngAfterContentChecked
//             → ngAfterViewInit → ngAfterViewChecked → ngOnDestroy
```

### Data Binding

```typescript
// 1. Interpolation:        {{ value }}
// 2. Property binding:     [src]="imageUrl"
// 3. Event binding:        (click)="handleClick()"
// 4. Two-way binding:      [(ngModel)]="name"  — requires FormsModule

@Component({
    template: `
        <h1>{{ title }}</h1>                       <!-- interpolation -->
        <img [src]="imageUrl">                     <!-- property binding -->
        <button (click)="save()">Save</button>     <!-- event binding -->
        <input [(ngModel)]="name">                 <!-- two-way -->
    `
})
```

### Parent ↔ Child Communication

```typescript
// Parent → Child (@Input):
// child.component.ts:
@Input() userId: number;
@Input() label: string = 'Default';

// parent.component.html:
<app-child [userId]="selectedId" [label]="'Edit User'"></app-child>

// Child → Parent (@Output + EventEmitter):
// child.component.ts:
@Output() saved = new EventEmitter<User>();
onSave() { this.saved.emit(this.user); }

// parent.component.html:
<app-child (saved)="onChildSaved($event)"></app-child>
```

### Services & Dependency Injection

```typescript
// Singleton service:
@Injectable({ providedIn: 'root' }) // application-wide singleton ✅
export class UserService {
    constructor(private http: HttpClient) {}

    getUsers(): Observable<User[]> {
        return this.http.get<User[]>('/api/users');
    }
}

// Non-singleton — provide at component level:
@Component({
    providers: [UserService] // new instance per component ✅
})
```

### RxJS — Observables vs Promises

| | Observable | Promise |
|---|---|---|
| Values | Multiple | Single |
| Lazy | ✅ (needs subscribe) | ❌ (eager) |
| Cancelable | ✅ unsubscribe | ❌ |
| Operators | Rich (map, filter, etc.) | Limited |

```typescript
// BehaviourSubject — holds current value, replays to new subscribers:
const currentUser$ = new BehaviorSubject<User>(null);
currentUser$.next(loggedInUser); // emit
currentUser$.value;              // get current value sync ✅

// takeUntil — auto-unsubscribe to prevent memory leaks:
this.service.getData()
    .pipe(takeUntil(this.destroy$))
    .subscribe(data => this.data = data);

// Convert Promise to Observable:
from(fetch('/api/data')).subscribe(res => console.log(res));
```

### Lazy Loading

```typescript
// app-routing.module.ts:
const routes: Routes = [
    {
        path: 'admin',
        loadChildren: () => import('./admin/admin.module').then(m => m.AdminModule)
        // AdminModule only loaded when user navigates to /admin ✅
    }
];
```

### HTTP Interceptors

```typescript
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
    intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
        const token = this.authService.getToken();
        const authReq = req.clone({
            headers: req.headers.set('Authorization', `Bearer ${token}`)
        });
        return next.handle(authReq);
    }
}
```

### Pure vs Impure Pipes

```typescript
// Pure pipe — only recalculates when input reference changes (default, performant):
@Pipe({ name: 'currency', pure: true })
export class CurrencyPipe implements PipeTransform {
    transform(value: number): string { return `₹${value.toFixed(2)}`; }
}

// Impure pipe — recalculates on EVERY change detection cycle (use sparingly):
@Pipe({ name: 'filter', pure: false })
export class FilterPipe implements PipeTransform {
    transform(items: any[], search: string): any[] {
        return items.filter(i => i.name.includes(search));
    }
}
```

---

# 9. ASP.NET MVC

> 📚 Reference: https://learn.microsoft.com/en-us/aspnet/core/mvc/

## ViewBag vs ViewData vs TempData

```csharp
// ViewData — dictionary, requires casting:
ViewData["Title"] = "Home Page";
// In view: @ViewData["Title"]

// ViewBag — dynamic wrapper over ViewData:
ViewBag.Title = "Home Page";
// In view: @ViewBag.Title

// TempData — survives ONE redirect (stored in session/cookie):
TempData["Message"] = "Order placed successfully!";
return RedirectToAction("Confirmation"); // survives redirect ✅
// In view: @TempData["Message"]  — read once, then deleted

// ✅ Strongly typed ViewModel preferred over all three:
return View(new HomeViewModel { Title = "Home", Orders = orders });
```

## MVC Request Lifecycle

```
1. Request arrives
2. Routing matches URL to Controller/Action
3. Controller Activator creates controller, injects dependencies
4. Action Filters run (before action)
5. Model Binding populates action parameters
6. Model Validation runs
7. Action method executes
8. Result Filters run
9. Action Result executes (renders View / returns JSON)
10. Response sent
```

## Action Filters

```csharp
// Custom action filter:
public class LogExecutionTimeFilter : IActionFilter
{
    private Stopwatch _sw;

    public void OnActionExecuting(ActionExecutingContext context)
    {
        _sw = Stopwatch.StartNew();
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        _sw.Stop();
        var logger = context.HttpContext.RequestServices.GetService<ILogger<LogExecutionTimeFilter>>();
        logger.LogInformation("{Action} took {Ms}ms",
            context.ActionDescriptor.DisplayName, _sw.ElapsedMilliseconds);
    }
}

// Apply globally:
builder.Services.AddControllersWithViews(opts =>
    opts.Filters.Add<LogExecutionTimeFilter>());
```

---

# 10. Coding / Algorithms

## String Operations

```csharp
// Reverse a string:
string Reverse(string s) => new string(s.Reverse().ToArray());

// Reverse words in a sentence (keep word order):
string ReverseWordsLetters(string s)
    => string.Join(" ", s.Split(' ').Select(w => new string(w.Reverse().ToArray())));

// First non-repeating character:
char? FirstNonRepeating(string s)
{
    var freq = s.GroupBy(c => c).ToDictionary(g => g.Key, g => g.Count());
    return s.FirstOrDefault(c => freq[c] == 1);
}

// Check palindrome:
bool IsPalindrome(string s)
{
    s = s.ToLower().Where(char.IsLetterOrDigit).ToArray().ToString(); // clean
    return s == new string(s.Reverse().ToArray());
}

// Anagram check:
bool AreAnagrams(string a, string b)
    => a.ToLower().OrderBy(c => c).SequenceEqual(b.ToLower().OrderBy(c => c));

// Occurrence of each character:
var freq = str.GroupBy(c => c).ToDictionary(g => g.Key, g => g.Count());

// Remove duplicates from string:
string RemoveDupes(string s) => new string(s.Distinct().ToArray());

// Longest substring without repeating characters:
int LongestUniqueSubstring(string s)
{
    var map  = new Dictionary<char, int>();
    int max  = 0, left = 0;
    for (int right = 0; right < s.Length; right++)
    {
        if (map.ContainsKey(s[right]))
            left = Math.Max(left, map[s[right]] + 1);
        map[s[right]] = right;
        max = Math.Max(max, right - left + 1);
    }
    return max;
}

// Run-length encoding ("aabbcddab" → "2a2b1c2d1a1b"):
string RunLengthEncode(string s)
{
    var sb = new StringBuilder();
    int i  = 0;
    while (i < s.Length)
    {
        char c  = s[i];
        int cnt = 0;
        while (i < s.Length && s[i] == c) { cnt++; i++; }
        sb.Append(cnt).Append(c);
    }
    return sb.ToString();
}
```

## Array Operations

```csharp
// Two sum — find indices that add to target:
int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.ContainsKey(complement))
            return new[] { map[complement], i };
        map[nums[i]] = i;
    }
    return Array.Empty<int>();
}

// Move zeros to end:
void MoveZeros(int[] arr)
{
    int insertPos = 0;
    foreach (int n in arr)
        if (n != 0) arr[insertPos++] = n;
    while (insertPos < arr.Length)
        arr[insertPos++] = 0;
}

// 3rd largest in one loop:
int ThirdLargest(int[] arr)
{
    int first = int.MinValue, second = int.MinValue, third = int.MinValue;
    foreach (int n in arr)
    {
        if (n > first)        { third = second; second = first; first = n; }
        else if (n > second)  { third = second; second = n; }
        else if (n > third)   { third = n; }
    }
    return third;
}

// Rotate array left by K:
void RotateLeft(int[] arr, int k)
{
    k %= arr.Length;
    Reverse(arr, 0, k - 1);
    Reverse(arr, k, arr.Length - 1);
    Reverse(arr, 0, arr.Length - 1);
}
```

## Algorithms

```csharp
// Check balanced brackets [{()}]:
bool IsBalanced(string s)
{
    var stack = new Stack<char>();
    var pairs = new Dictionary<char, char> { [')'] = '(', [']'] = '[', ['}'] = '{' };
    foreach (char c in s)
    {
        if ("([{".Contains(c)) stack.Push(c);
        else if (pairs.ContainsKey(c))
        {
            if (stack.Count == 0 || stack.Pop() != pairs[c]) return false;
        }
    }
    return stack.Count == 0;
}

// Fibonacci:
IEnumerable<int> Fibonacci()
{
    int a = 0, b = 1;
    while (true)
    {
        yield return a;
        (a, b) = (b, a + b);
    }
}

// Prime check:
bool IsPrime(int n)
{
    if (n < 2) return false;
    for (int i = 2; i <= Math.Sqrt(n); i++)
        if (n % i == 0) return false;
    return true;
}

// Factorial (recursive):
long Factorial(int n) => n <= 1 ? 1 : n * Factorial(n - 1);

// Merge strings alternately:
string MergeStrings(string s1, string s2)
{
    var sb  = new StringBuilder();
    int len = Math.Max(s1.Length, s2.Length);
    for (int i = 0; i < len; i++)
    {
        if (i < s1.Length) sb.Append(s1[i]);
        if (i < s2.Length) sb.Append(s2[i]);
    }
    return sb.ToString();
}

// All permutations of "ABC":
IEnumerable<string> Permutations(string s)
{
    if (s.Length <= 1) return new[] { s };
    return s.SelectMany((c, i) =>
        Permutations(s.Remove(i, 1)).Select(p => c + p));
}

// Casting output example:
double d = 9.987;
int castD    = (int)d;              // 9 (truncate)
int convertD = Convert.ToInt32(d);  // 10 (round)

float f = 1.5f;
int castF    = (int)f;              // 1 (truncate)
int convertF = Convert.ToInt32(f);  // 2 (round — banker's rounding: .5 rounds to even)

// Virtual/override output:
// B b = new A(); b.Display();
// → A.Display() runs (b is declared as B but holds A — virtual method = A's version)
// A a = new B(); a.Display();
// → B.Display() runs (override: runtime type is B) ✅

// Series: 1, 3, 7, 13, ... → differences: +2, +4, +6 → next: +8 → 21
```

---

# 11. JavaScript

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript

## Core Concepts

```javascript
// Hoisting — var declarations hoisted (not value), let/const not hoisted:
console.log(a); // undefined (hoisted, not initialized) ⚠️
console.log(b); // ReferenceError ❌ (let in temporal dead zone)
var a = 1;
let b = 2;

// Type coercion:
console.log(true + 1);   // 2   (boolean coerced to number)
console.log(1 + '2');    // "12" (number coerced to string — string wins)
console.log('2' + 1);    // "21" (same — left-to-right + string = concat)

// == vs ===:
console.log(1 == '1');   // true  (== coerces types)
console.log(1 === '1');  // false (=== strict — no coercion) ✅

// DOM:
const btn = document.getElementById('myBtn');
btn.addEventListener('click', () => alert('clicked!'));

// jQuery/AJAX:
$.ajax({ url: '/api/data', method: 'GET', success: data => console.log(data) });

// Get user input:
const name = document.getElementById('nameInput').value;
```

---

# 12. DevOps / CI/CD / Git

> 📚 Reference: https://learn.microsoft.com/en-us/azure/devops/

## Git Commands

```bash
# Daily workflow:
git clone <url>               # clone repo
git checkout -b feature/xyz   # create branch
git add .                     # stage all
git commit -m "feat: add XYZ" # commit
git push origin feature/xyz   # push branch
git pull origin main          # sync latest

# Merge conflict resolution:
git fetch origin
git merge origin/main          # triggers conflict markers
# Edit conflicted files, choose changes
git add <resolved-file>
git commit -m "resolve merge conflict"

# Useful:
git log --oneline --graph      # visual branch history
git stash                      # save uncommitted changes temporarily
git stash pop                  # restore stashed changes
git rebase main                # cleaner history than merge ✅
git cherry-pick <commit-hash>  # apply specific commit to current branch
```

## Zero-Downtime Deployment Strategies

| Strategy | Description |
|---|---|
| **Blue-Green** | Two identical envs, switch DNS — instant rollback |
| **Canary** | Route 5% traffic to new version, gradually increase |
| **Rolling** | Update instances one by one |
| **Feature Flags** | Deploy code but disable feature — release separately |

## Containerization

```dockerfile
# Dockerfile for .NET app:
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApi.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "MyApi.dll"]
```

---

# 13. AI Integration in .NET

> 📚 Reference: https://learn.microsoft.com/en-us/azure/ai-services/openai/

## Calling AI API in .NET

```csharp
// Using Semantic Kernel (Microsoft's AI orchestration library):
var kernel = Kernel.CreateBuilder()
    .AddAzureOpenAIChatCompletion(
        deploymentName: "gpt-4",
        endpoint:       config["AzureOpenAI:Endpoint"],
        apiKey:         config["AzureOpenAI:Key"])
    .Build();

var result = await kernel.InvokePromptAsync("Summarize this customer complaint: {{$input}}",
    new KernelArguments { ["input"] = customerText });

// HTTP-based call:
var client = new HttpClient();
client.DefaultRequestHeaders.Add("api-key", apiKey);

var body = new
{
    messages = new[] { new { role = "user", content = prompt } },
    max_tokens = 500
};

var response = await client.PostAsJsonAsync(endpoint, body);
var result   = await response.Content.ReadFromJsonAsync<OpenAIResponse>();
```

## Chatbot Design

```csharp
// Maintain conversation history for context:
public class ChatbotService
{
    private readonly List<ChatMessage> _history = new();

    public async Task<string> ChatAsync(string userMessage)
    {
        _history.Add(new ChatMessage(ChatRole.User, userMessage));

        var response = await _openAiClient.GetChatCompletionsAsync(
            new ChatCompletionsOptions
            {
                Messages      = _history.ToArray(), // ← full history = context ✅
                DeploymentName = "gpt-4",
                MaxTokens      = 500,
            });

        var reply = response.Value.Choices[0].Message.Content;
        _history.Add(new ChatMessage(ChatRole.Assistant, reply));
        return reply;
    }
}
```

## Fixing Wrong Chatbot Answers

1. **Prompt engineering** — be explicit, add system instructions
2. **RAG (Retrieval Augmented Generation)** — inject relevant docs into prompt
3. **Fine-tuning** — train on domain-specific examples
4. **Temperature** — lower = more deterministic, higher = more creative
5. **Guardrails** — validate output format, filter hallucinations

```csharp
// System prompt to constrain behaviour:
var systemPrompt = """
    You are a banking assistant for Acme Bank.
    Only answer questions related to accounts, loans, and transactions.
    If asked about anything else, politely redirect.
    Always respond in formal English.
    """;
```

---

> ✅ **All 450+ questions covered** across all 13 categories.
>
> 💡 **Tips for interviews:**
> - Always explain the "why" before the "how"
> - Use concrete examples from your project
> - Mention trade-offs (e.g. EF vs Dapper — it's context-dependent)
> - For coding questions: think aloud, mention edge cases, test with examples

---

*Last updated: 2026 | .NET 8 / C# 12 / Angular 17+*

---

## 1.10 Records & Init-Only Properties

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record

### Q1 — What is a `record` and when should you use it instead of a `class`?

A `record` is a reference type (or value type with `record struct`) that provides **value-based equality**, a compiler-generated `ToString`, `Equals`, `GetHashCode`, and supports **non-destructive mutation** via `with` expressions. Use records for immutable data transfer objects, domain events, and command/query objects.

❌ **Wrong** — using a class where value equality and immutability are needed:
```csharp
public class Point
{
    public int X { get; set; }
    public int Y { get; set; }
}

var a = new Point { X = 1, Y = 2 };
var b = new Point { X = 1, Y = 2 };
Console.WriteLine(a == b); // False — reference equality!
```

✅ **Correct** — record gives value equality and immutability for free:
```csharp
public record Point(int X, int Y);

var a = new Point(1, 2);
var b = new Point(1, 2);
Console.WriteLine(a == b);     // True — value equality!

var c = a with { Y = 99 };     // non-destructive mutation
Console.WriteLine(c);          // Point { X = 1, Y = 99 }
```

---

### Q2 — What are `init`-only setters and when are they useful?

`init` setters allow a property to be set **only during object initialization** (constructor or object initialiser), then become immutable — without requiring a constructor parameter for each property.

❌ **Wrong** — mutable setter allows accidental post-construction mutation:
```csharp
public class OrderDto
{
    public Guid Id { get; set; }       // can be changed after creation
    public string Status { get; set; }
}

var dto = new OrderDto { Id = Guid.NewGuid(), Status = "Pending" };
dto.Status = "Cancelled"; // silently allowed — dangerous in DTOs
```

✅ **Correct** — `init` setter locks the value after construction:
```csharp
public class OrderDto
{
    public Guid Id { get; init; }
    public string Status { get; init; }
}

var dto = new OrderDto { Id = Guid.NewGuid(), Status = "Pending" };
// dto.Status = "Cancelled"; // ❌ compile error — init-only
```

---

### Q3 — What is `required` and how does it enforce initialization?

C# 11 introduced `required` members — the compiler enforces that every caller must supply them during object initialisation, replacing constructor overloads for mandatory fields.

❌ **Wrong** — no enforcement, fields silently default to null:
```csharp
public class CustomerDto
{
    public string Name { get; init; }   // nothing forces caller to set this
    public string Email { get; init; }
}
var dto = new CustomerDto(); // Name = null, Email = null — silent bug
```

✅ **Correct** — `required` causes compile error if property is omitted:
```csharp
public class CustomerDto
{
    public required string Name { get; init; }
    public required string Email { get; init; }
}

var dto = new CustomerDto { Name = "Alice", Email = "a@b.com" }; // ✅
// var bad = new CustomerDto(); // ❌ CS9035: required member 'Name' not set
```

---

## 1.11 Pattern Matching

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/functional/pattern-matching

### Q1 — What is a switch expression and how does it differ from a switch statement?

A switch expression is an **expression-bodied** form that returns a value, supports exhaustiveness checking, and uses `=>` arms instead of `case`/`break`. It eliminates fall-through bugs and works naturally with records and tuples.

❌ **Wrong** — verbose switch statement, easy to forget `break`:
```csharp
string Describe(Shape shape)
{
    string result;
    switch (shape)
    {
        case Circle c:
            result = $"Circle r={c.Radius}";
            break;
        case Rectangle r:
            result = $"Rect {r.W}x{r.H}";
            break;
        default:
            result = "Unknown";
            break;
    }
    return result;
}
```

✅ **Correct** — concise switch expression, exhaustive:
```csharp
string Describe(Shape shape) => shape switch
{
    Circle c    => $"Circle r={c.Radius}",
    Rectangle r => $"Rect {r.W}x{r.H}",
    _           => "Unknown"
};
```

---

### Q2 — What are property, positional, and list patterns?

Property patterns match on an object's property values; positional patterns deconstruct a record/tuple; list patterns (C# 11) match against collection elements.

❌ **Wrong** — chained if-else with manual property access:
```csharp
string Classify(Order o)
{
    if (o.Status == "Paid" && o.Total > 1000) return "VIP";
    if (o.Status == "Paid") return "Standard";
    return "Unpaid";
}
```

✅ **Correct** — property pattern is declarative and readable:
```csharp
string Classify(Order o) => o switch
{
    { Status: "Paid", Total: > 1000 } => "VIP",
    { Status: "Paid" }               => "Standard",
    _                                => "Unpaid"
};

// Positional pattern with record
var point = new Point(0, 0);
string where = point switch
{
    (0, 0) => "Origin",
    (var x, 0) => $"X-axis at {x}",
    (0, var y) => $"Y-axis at {y}",
    var (x, y) => $"({x},{y})"
};

// List pattern (C# 11)
int[] nums = { 1, 2, 3 };
string desc = nums switch
{
    []          => "empty",
    [var x]     => $"one: {x}",
    [1, 2, ..] => "starts with 1,2",
    _           => "other"
};
```

---

### Q3 — What is the `is` type-pattern with `when` guard?

The `is` pattern combined with a `when` clause allows type-checking and condition evaluation in a single expression, replacing `as` + null check + cast chains.

❌ **Wrong** — double cast, verbose null check:
```csharp
void Process(object obj)
{
    var employee = obj as Employee;
    if (employee != null && employee.Salary > 50000)
        Console.WriteLine($"High earner: {employee.Name}");
}
```

✅ **Correct** — `is` pattern with `when`:
```csharp
void Process(object obj)
{
    if (obj is Employee { Salary: > 50000 } e)
        Console.WriteLine($"High earner: {e.Name}");
}
```

---

## 1.12 Span\<T\> and Memory\<T\>

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/api/system.span-1

### Q1 — What is `Span<T>` and why does it avoid allocations?

`Span<T>` is a **stack-allocated, ref struct** that represents a contiguous region of memory (array, stackalloc, unmanaged pointer) without copying data. It is used to slice arrays and strings with **zero heap allocation**.

❌ **Wrong** — `Substring` allocates a new string on every call:
```csharp
string Parse(string input)
{
    // allocates a new string for every slice
    string part = input.Substring(3, 5);
    return part.Trim();
}
```

✅ **Correct** — `AsSpan` + `Trim` on span, zero allocation:
```csharp
ReadOnlySpan<char> Parse(string input)
{
    ReadOnlySpan<char> span = input.AsSpan(3, 5);
    return span.Trim(); // no heap allocation
}

// Parsing integers without allocation:
ReadOnlySpan<char> text = "  42  ".AsSpan().Trim();
int value = int.Parse(text); // parse directly from span
```

---

### Q2 — When should you use `Memory<T>` instead of `Span<T>`?

`Span<T>` cannot be stored on the heap (it's a ref struct), so it cannot cross `await` boundaries. `Memory<T>` is the heap-safe counterpart used in **async methods** and stored in fields.

❌ **Wrong** — `Span<T>` cannot be used across await:
```csharp
async Task ProcessAsync(byte[] data)
{
    Span<byte> span = data.AsSpan(); // ❌ can't use across await
    await SomeAsyncOperation();
    ProcessSpan(span); // compile error: Span across await
}
```

✅ **Correct** — use `Memory<T>` in async context:
```csharp
async Task ProcessAsync(byte[] data)
{
    Memory<byte> mem = data.AsMemory();
    await SomeAsyncOperation();
    ProcessMemory(mem); // ✅ safe across await

    // Access the span only within sync slice
    Span<byte> span = mem.Span;
    span[0] = 0xFF;
}
```

---

### Q3 — What is `stackalloc` and when is it appropriate?

`stackalloc` allocates a buffer on the **stack**, avoiding heap pressure for short-lived, fixed-size buffers. Combined with `Span<T>`, it's safe without unsafe code.

❌ **Wrong** — heap-allocating a temporary buffer:
```csharp
byte[] buffer = new byte[128]; // heap allocation for temp work
// ... use buffer, then GC must collect it
```

✅ **Correct** — stack-allocate with Span for small, short-lived buffers:
```csharp
Span<byte> buffer = stackalloc byte[128]; // stack — no GC pressure
// Use buffer for local processing, automatically freed on return
FillBuffer(buffer);
SendData(buffer);
```

---

## 1.13 Nullable Reference Types

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/nullable-references

### Q1 — What does `#nullable enable` do and why should you turn it on?

`#nullable enable` (or `<Nullable>enable</Nullable>` in .csproj) activates the **nullable reference type** annotation system. The compiler now distinguishes between `string` (non-nullable, must not be null) and `string?` (nullable, must be null-checked). This moves null reference errors from runtime to compile time.

❌ **Wrong** — no nullable annotations, runtime NullReferenceException:
```csharp
public class UserService
{
    public string GetDisplayName(User user)
    {
        return user.Profile.Name.ToUpper(); // NullReferenceException if Profile or Name is null
    }
}
```

✅ **Correct** — nullable annotations force the caller to handle nulls:
```csharp
#nullable enable
public class UserService
{
    public string GetDisplayName(User user)
    {
        string? name = user.Profile?.Name;
        return name?.ToUpper() ?? "Anonymous"; // handled at compile time
    }
}
```

---

### Q2 — What is the null-forgiving operator `!` and when is it acceptable?

The `!` (null-forgiving) operator suppresses the compiler's nullable warning. It is **only acceptable** when you have out-of-band knowledge that a value cannot be null (e.g., after an assertion, or in test setup).

❌ **Wrong** — using `!` to silence warnings without understanding the risk:
```csharp
string? value = GetValue();
int length = value!.Length; // silences warning but may throw at runtime
```

✅ **Correct** — use `!` only after a null-guard:
```csharp
string? value = GetValue();
if (value is null) throw new InvalidOperationException("value must not be null");
int length = value!.Length; // safe: we just guarded above

// Better — let the compiler track it:
if (value is not null)
    int length = value.Length; // no ! needed; compiler knows it's non-null
```

---

## 1.14 Modern C# Language Features (C# 9–13)

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/

### Q1 — What are file-scoped namespaces and global usings?

C# 10 introduced **file-scoped namespaces** (eliminates one level of indentation) and **global usings** (import a namespace once for the whole project).

❌ **Wrong** — old block-scoped namespace, boilerplate usings in every file:
```csharp
// MyService.cs
using System;
using System.Collections.Generic;
using Microsoft.Extensions.Logging;

namespace MyApp.Services
{
    public class MyService { }
}
```

✅ **Correct** — file-scoped namespace + global usings in one file:
```csharp
// GlobalUsings.cs
global using System;
global using System.Collections.Generic;
global using Microsoft.Extensions.Logging;

// MyService.cs — no usings needed, no extra braces
namespace MyApp.Services;

public class MyService { }
```

---

### Q2 — What are primary constructors in C# 12?

**Primary constructors** embed constructor parameters directly in the class/struct declaration. The parameters become in-scope throughout the class body, removing boilerplate field declarations.

❌ **Wrong** — C# 9 style: explicit field + constructor:
```csharp
public class OrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<Order?> GetAsync(Guid id) => await _repo.GetByIdAsync(id);
}
```

✅ **Correct** — C# 12 primary constructor:
```csharp
public class OrderService(IOrderRepository repo, ILogger<OrderService> logger)
{
    public async Task<Order?> GetAsync(Guid id)
    {
        logger.LogInformation("Fetching order {Id}", id);
        return await repo.GetByIdAsync(id);
    }
}
```

---

### Q3 — What are collection expressions (C# 12)?

Collection expressions provide a unified, concise `[...]` syntax for creating lists, arrays, spans, and other collection types, replacing `new List<T> { }`, `new[] { }`, and `ImmutableArray.Create()`.

❌ **Wrong** — different syntax for each collection type:
```csharp
int[] array  = new int[] { 1, 2, 3 };
List<int> list = new List<int> { 1, 2, 3 };
Span<int> span = new int[] { 1, 2, 3 }; // extra alloc
```

✅ **Correct** — unified collection expression syntax:
```csharp
int[]     array = [1, 2, 3];
List<int> list  = [1, 2, 3];
Span<int> span  = [1, 2, 3]; // compiler picks stackalloc when safe

// Spread operator
int[] first  = [1, 2];
int[] second = [3, 4];
int[] all    = [..first, ..second]; // [1, 2, 3, 4]
```

---

### Q4 — What are raw string literals and when do they help?

Raw string literals (C# 11) start with three or more `"` characters and eliminate the need for `\n`, `\"`, and `\\` escapes. They are ideal for JSON, SQL, regex, and XML embedded in code.

❌ **Wrong** — escaped strings are hard to read and error-prone:
```csharp
string json = "{\n  \"name\": \"Alice\",\n  \"age\": 30\n}";
string sql  = "SELECT * FROM Users WHERE Name = \"Alice\" AND Active = 1";
```

✅ **Correct** — raw string literals preserve exact formatting:
```csharp
string json = """
    {
      "name": "Alice",
      "age": 30
    }
    """;

string sql = """
    SELECT *
    FROM   Users
    WHERE  Name = "Alice"
      AND  Active = 1
    """;
```

---

### Q5 — What are top-level statements (C# 9) and how do they simplify console apps?

Top-level statements allow a file to contain executable statements **without a class or Main method**. The compiler generates the entry point automatically. This is the default template for `dotnet new console` from .NET 6 onwards.

❌ **Wrong** — unnecessary ceremony for a simple program:
```csharp
using System;

namespace MyApp
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello, World!");
        }
    }
}
```

✅ **Correct** — top-level statements:
```csharp
Console.WriteLine("Hello, World!");

// args, async Main, and return codes all still work:
await SomethingAsync();
return 0;
```

---

## 1.15 Source Generators

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/source-generators-overview

### Q1 — What are source generators and what problems do they solve?

Source generators are **compile-time code generators** that run as part of the Roslyn compiler pipeline. They inspect the compilation (syntax trees, symbols) and emit additional C# source files. They replace runtime reflection and `ILEmit`-based approaches with zero-runtime-overhead, AOT-compatible code.

❌ **Wrong** — runtime reflection for serialization is slow and breaks AOT:
```csharp
// System.Text.Json without source gen — uses runtime reflection:
string json = JsonSerializer.Serialize(myObject);
// Slow on first call; throws in NativeAOT / Blazor WASM trimming
```

✅ **Correct** — source-generated `JsonSerializerContext` for zero reflection:
```csharp
[JsonSerializable(typeof(Order))]
[JsonSerializable(typeof(List<Order>))]
public partial class AppJsonContext : JsonSerializerContext { }

// Usage — fully AOT-safe, no reflection:
string json = JsonSerializer.Serialize(order, AppJsonContext.Default.Order);
Order? obj  = JsonSerializer.Deserialize(json, AppJsonContext.Default.Order);
```

---

### Q2 — What is the `[LoggerMessage]` source generator?

The `[LoggerMessage]` source generator (in `Microsoft.Extensions.Logging`) generates **high-performance, structured logging** code at compile time. It avoids boxing value types and does not evaluate the message string if the log level is disabled.

❌ **Wrong** — string interpolation in logging allocates even when logging is disabled:
```csharp
_logger.LogInformation($"Processing order {orderId} for customer {customerId}");
// allocates the string even if Info is not enabled
```

✅ **Correct** — source-generated `[LoggerMessage]` is allocation-free:
```csharp
public static partial class Log
{
    [LoggerMessage(Level = LogLevel.Information,
                   Message = "Processing order {OrderId} for customer {CustomerId}")]
    public static partial void ProcessingOrder(
        ILogger logger, Guid orderId, Guid customerId);
}

// Usage — no allocation if Info is disabled:
Log.ProcessingOrder(_logger, orderId, customerId);
```

---

### Q3 — Name two other commonly used source generators in .NET.

❌ **Wrong** — relying on runtime code for DI registration and regex:
```csharp
// Runtime DI scanning (slower startup):
services.Scan(scan => scan.FromAssemblyOf<IOrderService>()...);

// Runtime-compiled regex (first call is slow, no AOT):
var regex = new Regex(@"\d{4}-\d{2}-\d{2}");
```

✅ **Correct** — source generators for DI and regex:
```csharp
// 1. Regex source generator — compiled at build time:
[GeneratedRegex(@"\d{4}-\d{2}-\d{2}")]
private static partial Regex DatePattern();

bool match = DatePattern().IsMatch("2026-05-29"); // zero first-call cost

// 2. Microsoft.Extensions.DependencyInjection source generator
// (automatic in .NET 8 — generates registration code at compile time
//  from IServiceCollection extension methods, reducing startup reflection)
```

---

