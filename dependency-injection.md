# Dependency Injection - Frontend and Backend Complete Guide

> Dependency Injection (DI) gives an object its collaborators from the outside instead of letting it construct or locate them itself. Each topic keeps its Angular and ASP.NET Core examples, lifetime implications, practical walkthrough, trade-offs, and exercise in one place.

**Related guides:** [Angular](angular.md) contains frontend component patterns. [Backend Design Patterns](backend-design-patterns.md) shows DI in application architecture. [Distributed Systems Patterns](distributed-systems-patterns.md) shows the resilience and messaging implementations commonly registered through DI.

---

## Table of Contents

1. [DI and Inversion of Control](#di-1-dependency-injection-and-inversion-of-control)
2. [Constructor Injection](#di-2-constructor-injection)
3. [`inject()` / Injection-Context Resolution](#di-3-angular-inject-and-injection-context)
4. [Method / Parameter Injection](#di-4-method-and-parameter-injection)
5. [Property / Setter Injection](#di-5-property-and-setter-injection)
6. [Interface Injection](#di-6-interface-injection)
7. [Field Injection](#di-7-field-injection-and-hidden-dependencies)
8. [Composition Root](#di-8-composition-root-pattern)
9. [Tokens and Abstractions](#di-9-injection-tokens-and-abstractions)
10. [Lifetimes and Scopes](#di-10-lifetimes-and-scopes)
11. [Hierarchical Injection](#di-11-hierarchical-injection)
12. [Factory / Provider Injection](#di-12-factory-and-provider-injection)
13. [Keyed / Named / Qualified Services](#di-13-keyed-named-and-qualified-services)
14. [Optional Injection](#di-14-optional-injection)
15. [Lazy Injection](#di-15-lazy-injection)
16. [Collection / Multi-Binding](#di-16-collection-and-multi-binding)
17. [Open Generic Injection](#di-17-open-generic-injection)
18. [Decorator Injection](#di-18-decorator-injection)
19. [Configuration and Options Injection](#di-19-configuration-and-options-injection)
20. [Service Locator Anti-Pattern](#di-20-service-locator-anti-pattern)
21. [Captive Dependencies, Disposal, and Circular Graphs](#di-21-captive-dependencies-disposal-and-circular-graphs)
22. [Testing and Dependency Overrides](#di-22-testing-and-dependency-overrides)

---

## DI-1. Dependency Injection and Inversion of Control

**Question:** What are Dependency Injection and Inversion of Control, and how do they work in frontend and backend applications?

**Answer:** Inversion of Control means object creation and wiring are moved out of business classes. Dependency Injection is the technique used to supply those dependencies through constructors, parameters, factories, or other explicit mechanisms.

**What problem does this concept solve?** Classes stop controlling the creation of infrastructure they use. Implementations can change, lifetimes can be managed centrally, and tests can provide controlled substitutes.

**Before this concept:** Angular components and .NET services used `new` to construct HTTP clients, repositories, loggers, and provider SDKs.

❌ **Wrong example:**

```typescript
export class BookingComponent {
  private api = new BookingApi(new HttpClient(/* impossible framework setup */));
}
```

```csharp
public sealed class BookingService
{
    private readonly SqlConnection _connection = new("hard-coded-connection");
    private readonly EmailClient _email = new("hard-coded-key");
}
```

✅ **Correct example:**

```typescript
@Component({ /* ... */ })
export class BookingComponent {
  constructor(private readonly bookings: BookingService) {}
}
```

```csharp
public sealed class BookingService(
    IBookingRepository repository,
    IEmailGateway email,
    ILogger<BookingService> logger)
{
    // Dependencies are supplied by the composition root.
}
```

**How it works after this pattern:** Angular and ASP.NET Core build object graphs from registrations, reuse or dispose instances according to scope, and make dependencies visible in contracts.

**Trade-off:** A container reduces wiring code but can hide complexity if registrations are scattered. Keep one clear composition root and small dependency lists.

### Practical walkthrough — Inversion of Control: stop `Checkout` from creating its world

#### Before DI

`CheckoutService` creates `new StripeClient()`, reads the wall clock, and opens a database context. It controls both the payment workflow and infrastructure construction. A test that checks a declined card now needs Stripe configuration and cannot control time.

#### After DI

Angular provides a `PaymentApi` and `Clock` through tokens; ASP.NET Core registers `IPaymentGateway`, `IClock`, and repositories in `Program.cs`. `CheckoutService` receives abstractions and controls only the workflow.

```text
Before: Checkout -> new StripeClient / new Date / new DbContext
After:  Composition root -> Checkout(IPaymentGateway, IClock, IOrderRepository)
```

**What changed:** control of construction moved outward to one configuration boundary. DI is not “using a container everywhere”; it is making dependencies explicit and having a composition root wire them.

**Practice:** replace `new Date()` in one feature with a `Clock` abstraction and write a test for an expiry boundary.

---

## DI-2. Constructor Injection

**Question:** Why is constructor injection the default and preferred DI type?

**Answer:** Required dependencies are constructor parameters. An object cannot be created without everything needed to be valid.

**What problem does this concept solve?** It makes dependencies explicit, supports immutability, and fails early when configuration is incomplete.

**Before this concept:** Dependencies were created internally or assigned later, allowing partially initialized objects.

❌ **Wrong example:**

```csharp
var service = new PaymentService();
service.Gateway = gateway; // calling Charge before assignment causes failure
```

✅ **Correct frontend example:**

```typescript
@Injectable({ providedIn: 'root' })
export class PaymentFacade {
  constructor(
    private readonly api: PaymentApi,
    private readonly telemetry: TelemetryService) {}
}
```

✅ **Correct backend example:**

```csharp
public sealed class PaymentService(
    IPaymentGateway gateway,
    IPaymentRepository repository,
    TimeProvider clock)
{
    public Task<Result> ChargeAsync(Payment payment, CancellationToken ct) =>
        gateway.ChargeAsync(payment, ct);
}
```

**How it works after this pattern:** The container resolves each parameter recursively and returns a fully constructed object. Tests instantiate the class with fakes directly.

**Trade-off:** Many constructor parameters often reveal too many responsibilities. Do not hide that signal by injecting the container itself.

### Practical walkthrough — Constructor injection: state required collaborators

#### Before DI

An Angular component calls `injector.get(PaymentApi)` midway through `pay()`. A C# service keeps a nullable `Gateway` property set later. The class can be constructed in an invalid state, and required dependencies are hidden from readers.

#### After DI

```typescript
export class CheckoutFacade {
  constructor(private readonly paymentApi: PaymentApi,
              private readonly clock: Clock) {}
}
```

```csharp
public sealed class CheckoutService(IPaymentGateway paymentGateway, IClock clock) { }
```

The object cannot exist until all required collaborators exist. Tests construct it with explicit fakes. Keep the constructor focused: if it reaches eight or ten dependencies, look for a missing cohesive service rather than hiding them with a service locator.

**Practice:** list every dependency required to run `Charge`. Anything absent from that list should not be a constructor parameter.

---

## DI-3. Angular `inject()` and Injection Context

**Question:** How does Angular's `inject()` function differ from constructor injection?

**Answer:** `inject()` asks Angular's active injection context for a dependency. It works in field initializers, factories, guards, interceptors, and other context-aware code.

**What problem does this concept solve?** It enables DI where no class constructor exists and makes functional Angular APIs possible.

**Before this concept:** Functional guards and interceptors required wrapper classes primarily to receive dependencies.

❌ **Wrong example:**

```typescript
function loadData() {
  const api = inject(ProductApi); // runtime error outside an injection context
  return api.load();
}
```

✅ **Correct frontend example:**

```typescript
export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isSignedIn() ? true : router.createUrlTree(['/login']);
};

@Injectable({ providedIn: 'root' })
export class ProductFacade {
  private readonly api = inject(ProductApi); // valid field initializer
}
```

✅ **Backend equivalent:** ASP.NET Core typically uses constructor injection for classes and parameter injection for endpoints; it has no direct equivalent that should be called from arbitrary business code.

**How it works after this pattern:** Angular resolves the token from the current environment/element injector without requiring a constructor-only API.

**Trade-off:** `inject()` still creates a dependency. Do not scatter it through ordinary helper functions or use it to disguise excessive coupling.

### Practical walkthrough — Angular `inject()`: use it where constructor parameters do not fit

#### Before the pattern

A route guard creates a `UserSession` manually or stores it in a module-level global. It is difficult to override in tests and can survive test cases unexpectedly.

#### After the pattern

```typescript
export const canPay: CanActivateFn = () => {
  const session = inject(UserSession);
  return session.hasPermission('payment:create');
};
```

`inject()` reads from the active Angular injection context, so it works in guards, interceptors, provider factories, and field initializers. It does **not** turn arbitrary later method calls into injectable contexts; calling it outside one throws.

**Backend equivalent:** minimal-API route parameters or a handler constructor receive dependencies from the request’s service provider. Do not keep `IServiceProvider` and call it inside business methods.

**Practice:** convert one Angular functional interceptor from a global import to `inject(AuthTokenSource)` and override it in a test.

---

## DI-4. Method and Parameter Injection

**Question:** When should a dependency be injected into a method or endpoint parameter instead of a constructor?

**Answer:** Use parameter injection when the dependency is needed only for one operation and the framework owns that method invocation.

**What problem does this concept solve?** It avoids storing request-specific or rarely used dependencies on a long-lived object.

**Before this concept:** Controllers injected every possible handler into the constructor even if each endpoint used only one.

❌ **Wrong example:** Pass infrastructure manually through every internal method until signatures become plumbing rather than domain APIs.

✅ **Correct frontend example:** Angular functional providers receive dependencies through a factory's parameters or `inject()` context; component event methods themselves are not automatically parameter-injected.

```typescript
export const API_CLIENT = new InjectionToken<ApiClient>('API_CLIENT', {
  providedIn: 'root',
  factory: () => new ApiClient(inject(HttpClient), inject(API_BASE_URL))
});
```

✅ **Correct backend example:**

```csharp
app.MapGet("/orders/{id:guid}", async (
    Guid id,
    IOrderQueries queries,
    CancellationToken ct) =>
{
    var order = await queries.GetAsync(id, ct);
    return order is null ? Results.NotFound() : Results.Ok(order);
});
```

**How it works after this pattern:** The framework resolves operation-specific dependencies at invocation time while request data remains ordinary parameters.

**Trade-off:** Prefer constructor injection when several methods share the dependency or the class logically requires it.

### Practical walkthrough — Method/parameter injection: inject only for one operation

#### Before the pattern

`InvoiceService` keeps a heavy PDF renderer in its constructor even though only `ExportMonthlyInvoice` uses it. Every normal invoice operation pays construction and dependency complexity costs.

#### After the pattern

The endpoint or factory receives the renderer for the one operation:

```csharp
app.MapPost("/invoices/{id}/export",
    async (InvoiceId id, IPdfRenderer renderer, IInvoiceService invoices) =>
        await invoices.ExportAsync(id, renderer));
```

In Angular, a factory or event handler can inject inside a valid context, or receive a renderer explicitly as a function parameter. The service’s normal required state remains smaller.

**What changed:** the dependency’s scope mirrors actual use. This is useful for rare collaborators, but do not use method injection to hide a core requirement of every call.

**Practice:** decide whether `CancellationToken`, `ILogger`, and `IClock` belong to constructor or method signatures in a given service.

---

## DI-5. Property and Setter Injection

**Question:** What is property/setter injection, and why is it less common in Angular and ASP.NET Core?

**Answer:** The object is created first, then the container or caller assigns a dependency through a writable property or setter.

**What problem does this concept solve?** It can support genuinely optional collaborators or legacy frameworks that construct objects before dependencies are available.

**Before this concept:** Some framework-created objects had no constructor hook for supplying a collaborator.

❌ **Wrong example:**

```csharp
public sealed class InvoiceService
{
    public IClock? Clock { get; set; }
    public DateTimeOffset CreateDate() => Clock!.GetUtcNow(); // hidden required dependency
}
```

✅ **Correct frontend guidance:** Angular normally uses constructor injection or `inject()`. An `@Input()` is component data binding, not dependency injection.

✅ **Correct backend exception:**

```csharp
public sealed class LegacyPlugin
{
    private IAuditSink _audit = NullAuditSink.Instance;
    public void SetAuditSink(IAuditSink audit) => _audit = audit ?? throw new ArgumentNullException();
}
```

**How it works after this pattern:** The object has a safe default and explicitly accepts an optional capability when the legacy host can provide it.

**Trade-off:** Required property injection creates invalid intermediate state. The built-in .NET container does not perform general property injection; prefer constructors.

### Practical walkthrough — Property/setter injection: understand why it is usually unsafe

#### Before/incorrect approach

```csharp
var checkout = new CheckoutService();
checkout.Gateway = gateway; // another caller may forget this line
await checkout.PayAsync(order);
```

The class can run with `Gateway == null`; initialization order becomes a runtime bug. Angular has no reason to use mutable property injection for required dependencies either.

#### When a controlled setter can work

A host framework may set optional plugin metadata after construction, or a test may set a deliberately optional collaborator. Even then, prefer a Null Object/default behavior or a constructor parameter that makes the contract clear.

**What changed when you choose constructor injection instead:** invalid objects become impossible to create. A setter is not “simpler DI”; it transfers correctness from the type system to caller discipline.

**Practice:** take a nullable injected property from a class and replace it with either a required constructor dependency or an explicit `NoOp...` implementation.

---

## DI-6. Interface Injection

**Question:** What is interface injection?

**Answer:** The consumer implements an interface containing a method through which an injector supplies a dependency.

**What problem does this concept solve?** It gives a plugin framework a standardized callback for supplying a capability after object creation.

**Before this concept:** Plugin hosts used reflection or concrete-type checks to configure plugins.

❌ **Wrong example:** Make every domain class implement framework-specific injection interfaces, coupling the domain to the container.

✅ **Correct example for a plugin boundary:**

```csharp
public interface IRequireLogger
{
    void SetLogger(ILogger logger);
}

public sealed class ExportPlugin : IRequireLogger
{
    private ILogger _logger = NullLogger.Instance;
    public void SetLogger(ILogger logger) => _logger = logger;
}
```

✅ **Frontend equivalent:** Angular does not use interface injection because TypeScript interfaces do not exist at runtime. Use `InjectionToken<T>` plus constructor injection or `inject()`.

**How it works after this pattern:** A plugin host configures all objects implementing one capability contract without knowing concrete types.

**Trade-off:** This is rare and framework-coupled. Constructor injection is clearer for normal application services.

### Practical walkthrough — Interface injection: recognize the narrow case

#### Before the pattern

A plugin host uses reflection to find optional methods on an extension. The host cannot know which dependency an extension needs until it fails at runtime.

#### After the pattern

```csharp
public interface IRequiresHostServices
{
    void SetHostServices(IPluginHostServices services);
}
```

The plugin contract explicitly says the host will supply a capability. TypeScript interfaces vanish at runtime, so Angular does not perform this pattern directly; use an `InjectionToken` and provider contract instead.

**What changed:** a framework/plugin lifecycle becomes visible in the type contract. For ordinary application classes, constructor injection is clearer and safer; interface injection is primarily a legacy or framework extensibility technique.

**Practice:** if a plugin needs database, logging, and HTTP access, design one constrained host capability rather than injecting the whole service provider.

---

## DI-7. Field Injection and Hidden Dependencies

**Question:** Is field injection a valid DI type?

**Answer:** Some frameworks write directly into annotated fields. It works technically but hides required dependencies and complicates direct construction and testing.

**What problem does this concept solve?** It reduces constructor syntax, but mostly at the cost of object clarity.

**Before this concept:** Large constructors looked uncomfortable, so dependencies were moved into invisible field annotations rather than reducing responsibilities.

❌ **Wrong backend example:**

```csharp
public sealed class OrderService
{
    [Inject] private IOrderRepository _orders = null!;
    [Inject] private IPaymentGateway _payments = null!;
}
```

❌ **Wrong frontend interpretation:**

```typescript
class PlainHelper {
  private api = inject(ApiService); // invalid if created with `new PlainHelper()`
}
```

✅ **Correct example:** Declare required dependencies through a constructor, or use Angular `inject()` only in a documented injection context.

**How it works after this pattern:** Dependencies are visible and direct unit construction either supplies them or fails at compile time.

**Trade-off:** Angular field initializers using `inject()` are supported context resolution, not reflection-based field mutation; still keep the dependency count small.

### Practical walkthrough — Field injection and hidden dependencies: avoid a disguised service locator

#### Before the pattern

```typescript
export class CheckoutFacade {
  private api = inject(PaymentApi); // valid Angular field initializer
  async pay() { return this.api.charge(); }
}
```

This Angular form is valid because it runs during construction in an injection context. The risk appears when dependencies are scattered across fields or retrieved lazily inside business methods: the public constructor no longer documents the object’s needs. Reflection-based private field injection in .NET is worse: it hides lifetime and test setup entirely.

#### After the pattern

Use constructor injection for core, required collaborators. Reserve Angular field `inject()` for components or framework-native code where it improves readability, keep it near the top of the class, and do not call `Injector.get()` later inside behavior.

**What changed:** dependencies are discoverable and tests can supply them deliberately. The rule is not “never use Angular `inject()`”; it is “never hide the dependency graph.”

**Practice:** open a class and identify its dependencies without reading method bodies. If you cannot, make them explicit.

---

## DI-8. Composition Root Pattern

**Question:** What is a composition root?

**Answer:** It is the application location where concrete implementations, decorators, lifetimes, configuration, and object graphs are wired.

**What problem does this concept solve?** It keeps construction policy out of business code and makes runtime architecture inspectable.

**Before this concept:** Registrations and `new` calls appeared throughout modules, controllers, and services.

❌ **Wrong example:** Register services conditionally from inside a request handler or import an Angular provider array into random feature classes.

✅ **Correct frontend example:**

```typescript
bootstrapApplication(AppComponent, {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor])),
    { provide: API_BASE_URL, useValue: environment.apiBaseUrl },
    { provide: PaymentGateway, useClass: StripeGateway }
  ]
});
```

✅ **Correct backend example:**

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddScoped<IOrderRepository, EfOrderRepository>();
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddHttpClient<IPaymentGateway, StripeGateway>();
var app = builder.Build();
```

**How it works after this pattern:** Business classes declare abstractions; the startup boundary decides concrete runtime policy.

**Trade-off:** Large startup files become hard to navigate. Group registrations by cohesive feature, but call them from one visible root.

### Practical walkthrough — Composition root: one place chooses real implementations

#### Before the pattern

Controllers, jobs, and components each choose their own `StripeGateway`/`FakeGateway`. Production behavior differs by entry point and integration configuration leaks through the codebase.

#### After the pattern

Angular assembles providers at the bootstrap, route, or component boundary. ASP.NET Core assembles registrations in `Program.cs`:

```csharp
builder.Services.AddScoped<ICheckoutService, CheckoutService>();
builder.Services.AddHttpClient<IPaymentGateway, StripeGateway>();
builder.Services.AddSingleton<IClock, SystemClock>();
```

Business classes do not register or resolve themselves. Tests create a smaller composition root with fakes.

**What changed:** implementation selection is centralized, reviewable, and environment-specific without contaminating domain code. Keep the root declarative; avoid writing business decisions in registration lambdas.

**Practice:** trace one `IPaymentGateway` from its registration to an endpoint, then replace it in an integration test without editing production code.

---

## DI-9. Injection Tokens and Abstractions

**Question:** Why do Angular and .NET need runtime service tokens?

**Answer:** The container needs a runtime key. .NET interfaces and classes are runtime types; TypeScript interfaces disappear, so Angular uses classes or `InjectionToken<T>`.

**What problem does this concept solve?** Consumers depend on stable capabilities instead of constructing specific implementations.

**Before this concept:** Components imported environment constants or concrete SDKs directly, and backend services depended on provider classes.

❌ **Wrong frontend example:** Use a string token such as `'API_URL'`; strings collide and lose type safety.

✅ **Correct frontend example:**

```typescript
export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL');
export const STORAGE = new InjectionToken<StoragePort>('STORAGE');

providers: [
  { provide: API_BASE_URL, useValue: environment.apiBaseUrl },
  { provide: STORAGE, useClass: BrowserStorageAdapter }
]
```

✅ **Correct backend example:**

```csharp
public interface IStorageGateway { Task<Uri> UploadAsync(Stream stream, CancellationToken ct); }
services.AddScoped<IStorageGateway, GcpStorageGateway>();
```

**How it works after this pattern:** The consumer knows the contract; the composition root chooses the environment-specific implementation.

**Trade-off:** An interface for every class adds noise. Introduce an abstraction at a meaningful boundary or when multiple implementations/testing justify it.

### Practical walkthrough — Tokens and abstractions: distinguish two payment implementations at runtime

#### Before the pattern

Angular tries to inject a TypeScript interface, which does not exist at runtime; .NET injects a concrete SDK everywhere. Both tie consumers to a detail that should vary.

#### After the pattern

```typescript
export const PAYMENT_API = new InjectionToken<PaymentApi>('PAYMENT_API');
```

```csharp
public interface IPaymentGateway { Task<ChargeResult> ChargeAsync(...); }
```

Consumers depend on a capability defined in their language. The composition root maps the token/interface to Stripe, Adyen, or sandbox implementation.

**What changed:** callers no longer need provider DTOs or SDK constructors. Do not invent abstractions for every internal class—put them at external, variable, or independently testable boundaries.

**Practice:** define an abstraction in language of the application (`Charge`, `Refund`, `GetStatus`) rather than mirroring a provider SDK method-for-method.

---

## DI-10. Lifetimes and Scopes

**Question:** What are transient, scoped, and singleton lifetimes, and how do they compare with Angular scopes?

**Answer:** Lifetime controls reuse and disposal.

| Concept | ASP.NET Core | Angular |
|---|---|---|
| New instance per resolution | Transient | Factory/provider or component-level resolution depending on hierarchy |
| One per request/subtree | Scoped per HTTP request | One per element/environment injector subtree |
| One for application root | Singleton | `providedIn: 'root'` |

**What problem does this concept solve?** It matches object reuse to state ownership and resource safety.

**Before this concept:** Objects were global by accident or created repeatedly, causing state leaks, connection misuse, or duplicated caches.

❌ **Wrong backend example:** A singleton captures scoped `DbContext`, keeping one context across requests.

❌ **Wrong frontend example:** Provide a supposed global cart store in every page component, creating a different cart per route subtree.

✅ **Correct backend example:**

```csharp
services.AddSingleton<ISystemClock, SystemClock>();
services.AddScoped<AppDbContext>();
services.AddScoped<IOrderService, OrderService>();
services.AddTransient<IEmailFormatter, EmailFormatter>();
```

✅ **Correct frontend example:**

```typescript
@Injectable({ providedIn: 'root' })
export class SessionStore {}

@Component({ providers: [WizardState] })
export class CheckoutWizardComponent {} // isolated state per wizard instance
```

**How it works after this pattern:** Global stateless services are reused, request/subtree state remains isolated, and disposable backend resources end with their scope.

**Trade-off:** Lifetime bugs are correctness bugs. Enable scope validation and document where Angular providers are registered.

### Practical walkthrough — Lifetimes and scopes: prevent request data leaking between users

#### Before the pattern

A singleton `CheckoutContext` stores the current user. Request A sets tenant A; request B concurrently reads tenant A’s state. Or a singleton holds an EF Core `DbContext`, which is not thread-safe and is disposed after a request.

#### After the pattern

```text
Angular root provider: one app-wide instance (stateless/configuration)
Angular component provider: one instance per component subtree
.NET singleton: one process instance
.NET scoped: one request/message/job instance
.NET transient: a new instance per resolution
```

Register stateful request work—such as `DbContext`, tenant context, or unit of work—as scoped. Register stateless, thread-safe policy/configuration as singleton. Use transients for lightweight stateless helpers.

**What changed:** object lifetime matches the state it owns. Lifetimes are behavior, not an optimization knob; draw two concurrent request diagrams before choosing one.

**Practice:** label `HttpClient`, `DbContext`, current-user context, clock, cache client, and validator with a justified lifetime.

---

## DI-11. Hierarchical Injection

**Question:** How does hierarchical DI work in Angular, and what is the backend equivalent?

**Answer:** Angular resolves from the nearest element/environment injector and then walks upward. A child can override a parent token. ASP.NET Core uses nested scopes but does not normally override registrations per controller subtree.

**What problem does this concept solve?** A feature subtree can own isolated state or substitute a local implementation without changing the whole application.

**Before this concept:** Wizard instances accidentally shared progress, or test/demo features changed global providers.

❌ **Wrong example:** Register a mutable wizard state in root and assume each open wizard gets a separate instance.

✅ **Correct frontend example:**

```typescript
@Component({
  selector: 'app-checkout-wizard',
  providers: [WizardState],
  template: `<app-step />`
})
export class CheckoutWizardComponent {}
// Descendants share the nearest WizardState; another wizard gets another instance.
```

✅ **Backend equivalent:**

```csharp
await using var scope = scopeFactory.CreateAsyncScope();
var processor = scope.ServiceProvider.GetRequiredService<JobProcessor>();
await processor.RunAsync(job, ct); // fresh scoped graph for one job
```

**How it works after this pattern:** State follows the UI subtree or backend operation scope rather than leaking globally.

**Trade-off:** Shadowed Angular providers can be surprising. Use root services by default and local providers intentionally.

### Practical walkthrough — Hierarchical Angular injection: override a component subtree safely

#### Before the pattern

The whole app uses a global `CurrencyFormatter`. A preview widget needs a temporary French locale, so it mutates global state; the rest of the page can flicker into French output.

#### After the pattern

Provide a different formatter at the preview component. Angular resolves nearest provider first, so children use French while the rest of the app keeps the root formatter.

```text
Root injector: CurrencyFormatter(en-IN)
  Preview component injector: CurrencyFormatter(fr-FR)
    Preview children resolve fr-FR
```

**Backend analogy:** a request scope provides per-request dependencies, but it is not a general nested override tree in the same way. Use an explicit scoped context or factory for a sub-operation rather than mutating global registrations.

**Practice:** provide a fake API only to one Angular component test and confirm sibling components still receive the real test default.

---

## DI-12. Factory and Provider Injection

**Question:** When should DI use a factory provider?

**Answer:** A factory creates an implementation when construction depends on configuration or other injected services.

**What problem does this concept solve?** It centralizes conditional construction without pushing container logic into consumers.

**Before this concept:** Components and services read configuration and manually chose concrete implementations.

❌ **Wrong example:** Inject `IServiceProvider` or Angular `Injector` and switch on environment inside business methods.

✅ **Correct frontend example:**

```typescript
export const storageProvider: Provider = {
  provide: STORAGE,
  deps: [PLATFORM_ID],
  useFactory: (platformId: object): StoragePort =>
    isPlatformBrowser(platformId)
      ? new BrowserStorageAdapter(localStorage)
      : new InMemoryStorageAdapter()
};
```

✅ **Correct backend example:**

```csharp
services.AddSingleton<IClock>(sp =>
    sp.GetRequiredService<IHostEnvironment>().IsDevelopment()
        ? new AdjustableClock(DateTimeOffset.UtcNow)
        : TimeProvider.System.AsClock());
```

**How it works after this pattern:** Consumers receive one stable abstraction; construction policy remains in provider registration.

**Trade-off:** Complex factories are difficult to test and validate. Move substantial creation rules into a dedicated typed factory.

### Practical walkthrough — Factory/provider injection: construct from runtime configuration

#### Before the pattern

Code has `if (region == "EU") new EuTaxGateway(...) else new UsTaxGateway(...)` in every checkout path. Construction rules and configuration validation are duplicated.

#### After the pattern

An Angular `useFactory` or .NET factory registration reads validated configuration once and returns the appropriate implementation. For per-request choice, inject a typed factory/selector rather than the raw container.

```csharp
public interface ITaxGatewayFactory { ITaxGateway For(Region region); }
```

**What changed:** construction policy is named, centralized, and testable. The factory must not quietly choose a wrong fallback for a missing region; reject invalid configuration at startup or return an explicit unsupported result.

**Practice:** write the table of valid regions/providers and unit-test the selector without any HTTP calls.

---

## DI-13. Keyed, Named, and Qualified Services

**Question:** How do you inject one of several implementations of the same interface?

**Answer:** Register implementations with distinct runtime keys or inject all implementations and select through a typed router.

**What problem does this concept solve?** It supports several providers without concrete-type dependencies or giant conditional constructors.

**Before this concept:** Callers injected Stripe, PayPal, and Razorpay classes separately and switched manually.

❌ **Wrong example:** Select by fragile class name or resolve arbitrary services from the container inside domain code.

✅ **Correct frontend example:**

```typescript
export const PRIMARY_ANALYTICS = new InjectionToken<Analytics>('PRIMARY_ANALYTICS');
export const AUDIT_ANALYTICS = new InjectionToken<Analytics>('AUDIT_ANALYTICS');

providers: [
  { provide: PRIMARY_ANALYTICS, useClass: ProductAnalytics },
  { provide: AUDIT_ANALYTICS, useClass: ComplianceAnalytics }
]
```

✅ **Correct backend example (.NET 8+):**

```csharp
services.AddKeyedScoped<IPaymentGateway, StripeGateway>("stripe");
services.AddKeyedScoped<IPaymentGateway, PayPalGateway>("paypal");

app.MapPost("/pay/stripe", async (
    [FromKeyedServices("stripe")] IPaymentGateway gateway,
    ChargeRequest request,
    CancellationToken ct) =>
{
    var result = await gateway.ChargeAsync(
        new Money(request.Amount, request.Currency), request.IdempotencyKey, ct);
    return result.IsSuccess ? Results.Ok(result) : Results.UnprocessableEntity(result.Error);
});
```

**How it works after this pattern:** The key expresses configuration-time selection. For runtime user data, a typed strategy router is usually safer than injecting the raw container.

**Trade-off:** String keys can drift. Prefer constants, enums with mapping, or a typed provider router.

### Practical walkthrough — Keyed/named/qualified services: select one of several legitimate implementations

#### Before the pattern

Two `INotificationSender` registrations exist. The last registration silently wins, so email sends where SMS was expected. In Angular, using the same broad token makes selection ambiguous.

#### After the pattern

Use distinct meaningful tokens in Angular, or keyed services in .NET, and keep the key at the composition/selection boundary:

```csharp
builder.Services.AddKeyedScoped<INotificationSender, EmailSender>("email");
builder.Services.AddKeyedScoped<INotificationSender, SmsSender>("sms");
```

The checkout service receives a `NotificationSelector`, not arbitrary strings from an HTTP request. Validate user input against allowed business channels.

**What changed:** multiplicity is explicit. For a small fixed set, separate interfaces like `IEmailSender` and `ISmsSender` may be even clearer than keys.

**Practice:** decide who owns mapping `"sms"` from an API request to the correct sender and why it should not be scattered.

---

## DI-14. Optional Injection

**Question:** When is optional injection appropriate?

**Answer:** A dependency is optional only when the object has a complete, valid fallback behavior without it.

**What problem does this concept solve?** Reusable libraries can integrate with capabilities that may not exist in every host.

**Before this concept:** Applications registered meaningless placeholder services only to satisfy constructors.

❌ **Wrong example:** Mark a payment gateway optional and use `gateway!` later even though payment cannot work without it.

✅ **Correct frontend example:**

```typescript
const analytics = inject(ANALYTICS, { optional: true });
analytics?.track('page_view'); // feature remains valid without analytics
```

✅ **Correct backend example:** Prefer the Null Object pattern because ASP.NET Core constructor resolution treats missing required services as configuration errors.

```csharp
services.TryAddSingleton<IAnalytics, NullAnalytics>();
```

**How it works after this pattern:** Truly optional behavior disappears safely, while required capabilities still fail fast during startup.

**Trade-off:** Excessive optional dependencies create many runtime paths. Use them mainly in libraries or plug-in capabilities.

### Practical walkthrough — Optional injection: model a feature that is truly optional

#### Before the pattern

Checkout asks the container for `LoyaltyReporter` and catches an exception if it is absent. A production registration typo silently disables an important feature.

#### After the pattern

If loyalty is deliberately optional, provide a `NoOpLoyaltyReporter` by default and replace it where enabled. In Angular, `inject(LOYALTY_REPORTER, { optional: true })` is acceptable only when `null` has a defined, tested meaning.

```text
Required payment gateway: application cannot start without it.
Optional analytics reporter: NoOp implementation is valid behavior.
```

**What changed:** optionality becomes a product decision rather than an accidental null. Treat required services as fail-fast startup errors.

**Practice:** classify email, audit logging, loyalty analytics, and payment capture as required/optional for your product, including outage behavior.

---

## DI-15. Lazy Injection

**Question:** What is lazy injection, and when should dependency creation be delayed?

**Answer:** Resolve or create an expensive dependency only when the operation that needs it runs.

**What problem does this concept solve?** It avoids startup cost or circular construction for a rarely used capability.

**Before this concept:** Every request or component eagerly created a heavy SDK client even when most paths never used it.

❌ **Wrong example:** Inject the root container and call `GetService` throughout business code under the name “lazy.”

✅ **Correct frontend example:**

```typescript
async openAdvancedEditor() {
  const { AdvancedEditorComponent } = await import('./advanced-editor.component');
  this.viewContainer.createComponent(AdvancedEditorComponent);
}
```

✅ **Correct backend example with an explicit factory:**

```csharp
services.AddScoped<Func<IReportRenderer>>(sp =>
    () => sp.GetRequiredService<PdfReportRenderer>());

public sealed class ReportService(Func<IReportRenderer> rendererFactory)
{
    public Task RenderAsync(Report report) => rendererFactory().RenderAsync(report);
}
```

**How it works after this pattern:** Expensive code or objects appear only on the path that needs them, while the dependency remains explicit through a typed factory.

**Trade-off:** Resolution failures move from startup to runtime. Do not use laziness to conceal circular or oversized designs.

### Practical walkthrough — Lazy injection: defer a rare expensive dependency

#### Before the pattern

Every product page constructs a heavy fraud-model client even though only a small percentage of checkouts call it. Startup and memory use increase, and a failed optional initialization can prevent unrelated reads.

#### After the pattern

Inject an explicit factory such as `Func<IFraudModel>` in .NET or use a deliberate dynamic import/provider factory in Angular. Create it at the moment the fraud path is selected and cache it only according to its safe lifetime.

**What changed:** cost is paid only if the behavior is used. Lazy creation does not make a dependency optional; failures still need handling, and it can hide a slow first-use path.

**Practice:** measure whether a dependency is actually expensive enough to justify laziness; otherwise prefer ordinary eager constructor injection.

---

## DI-16. Collection and Multi-Binding

**Question:** How do you inject several implementations of one contract?

**Answer:** Register each implementation and inject the collection. Angular uses `multi: true`; ASP.NET Core resolves `IEnumerable<T>`.

**What problem does this concept solve?** Pipelines and plug-in systems can discover implementations without a central switch statement.

**Before this concept:** A coordinator directly constructed every validator, exporter, or notification channel.

❌ **Wrong example:** Edit the coordinator whenever a new handler is added.

✅ **Correct frontend example:**

```typescript
export const FORM_VALIDATORS = new InjectionToken<FormValidator[]>('FORM_VALIDATORS');
providers: [
  { provide: FORM_VALIDATORS, useClass: RequiredValidator, multi: true },
  { provide: FORM_VALIDATORS, useClass: EmailValidator, multi: true }
]
```

✅ **Correct backend example:**

```csharp
services.AddScoped<IOrderRule, CreditLimitRule>();
services.AddScoped<IOrderRule, InventoryRule>();

public sealed class OrderPolicy(IEnumerable<IOrderRule> rules)
{
    public async Task<Result> CheckAsync(Order order, CancellationToken ct)
    {
        foreach (var rule in rules)
        {
            var result = await rule.CheckAsync(order, ct);
            if (result.IsFailure) return result;
        }
        return Result.Ok();
    }
}
```

**How it works after this pattern:** Adding an implementation requires registration, not coordinator modification.

**Trade-off:** Ordering may matter. Define priority explicitly rather than relying accidentally on registration order.

### Practical walkthrough — Collection/multi-binding: run validation rules or plugins

#### Before the pattern

A giant `CheckoutValidator` contains a `switch` for every country, promotion, and payment method. New rules require editing the same class and tests become tangled.

#### After the pattern

Angular registers several providers with `multi: true`; ASP.NET Core injects `IEnumerable<ICheckoutRule>`. The service runs all applicable rules in a documented order.

```text
Checkout -> [StockRule, FraudRule, AddressRule, PromotionRule] -> results
```

**What changed:** extensions are additive. But order, conflicts, and short-circuit semantics must be explicit—an unordered set of plugins is not a business workflow.

**Practice:** add a rule that applies only to an EU tenant and decide whether a rule failure stops later rules.

---

## DI-17. Open Generic Injection

**Question:** What is open generic registration in .NET, and what is the frontend equivalent?

**Answer:** One .NET registration supplies a generic implementation for many closed service types. Angular tokens are runtime values and do not automatically vary by TypeScript generic argument.

**What problem does this concept solve?** It avoids repeating identical registrations for repositories, validators, or handlers across entity types.

**Before this concept:** Every entity registered `IRepository<Customer>`, `IRepository<Order>`, and so on separately.

❌ **Wrong example:** Assume `InjectionToken<Repository<Order>>` and `InjectionToken<Repository<Customer>>` are different at runtime when they use the same token object.

✅ **Correct backend example:**

```csharp
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));

public sealed class OrderService(IRepository<Order> orders) { }
public sealed class CustomerService(IRepository<Customer> customers) { }
```

✅ **Correct frontend approach:** Create distinct runtime tokens or a typed repository factory keyed by entity name.

```typescript
export const ORDER_REPOSITORY = new InjectionToken<Repository<Order>>('ORDER_REPOSITORY');
export const CUSTOMER_REPOSITORY = new InjectionToken<Repository<Customer>>('CUSTOMER_REPOSITORY');
```

**How it works after this pattern:** .NET closes the generic registration automatically; Angular uses explicit runtime identity despite compile-time generics.

**Trade-off:** Generic repositories can erase domain meaning. Use domain-specific interfaces when operations differ.

### Practical walkthrough — Open generic injection: apply one policy to many entity types

#### Before the pattern

`OrderValidator`, `CustomerValidator`, and `GiftCardValidator` each duplicate generic plumbing for logging or repositories, even though the behavior is the same type parameterized operation.

#### After the pattern

ASP.NET Core registers an open generic such as `IRepository<T> -> EfRepository<T>` or `IValidator<T> -> Validator<T>`. The container closes it when a consumer requests `IRepository<Order>`.

Angular TypeScript generics are erased at runtime, so it needs explicit tokens/factories rather than assuming generic type information exists.

**What changed:** shared type-safe behavior is wired once on the backend. Do not use it to hide aggregate-specific repositories whose methods or loading rules differ.

**Practice:** list which CRUD operations are genuinely uniform and which deserve a domain-specific repository.

---

## DI-18. Decorator Injection

**Question:** How can DI compose logging, caching, or metrics around a service?

**Answer:** Register a decorator that implements the same interface and receives the inner implementation.

**What problem does this concept solve?** Cross-cutting behavior is composed without modifying core service code.

**Before this concept:** Each service duplicated cache and timing logic.

❌ **Wrong example:** Add logging, retry, cache, authorization, and domain behavior to one implementation until it has several reasons to change.

✅ **Correct frontend example:** Angular HTTP interceptors form a decorator-like chain around `HttpClient` requests.

```typescript
provideHttpClient(withInterceptors([authInterceptor, timingInterceptor]));
```

✅ **Correct backend example:**

```csharp
services.AddScoped<IProductReader, ProductReader>();
services.Decorate<IProductReader, CachedProductReader>(); // using Scrutor
services.Decorate<IProductReader, TimedProductReader>();
```

**How it works after this pattern:** The consumer receives one `IProductReader`; DI builds an ordered wrapper chain around the core implementation.

**Trade-off:** Order changes behavior. Document and test the chain; too many wrappers complicate tracing.

### Practical walkthrough — Decorator injection: add resilience without mixing it into payment logic

#### Before the pattern

`StripeGateway.Charge` contains tracing, retry rules, metrics, logging, and provider mapping. The core HTTP operation is difficult to test, and a second gateway copies policy with slight differences.

#### After the pattern

```text
Checkout -> MetricsGateway -> ResilientGateway -> StripeGateway
```

Every wrapper implements `IPaymentGateway` and delegates to the next. Angular can achieve similar interception for HTTP traffic with interceptor chains. Ordering matters: an outer metric includes retries; an inner metric measures one attempt.

**What changed:** cross-cutting behavior is composable. Do not decorate non-idempotent payment calls with automatic retry unless the gateway sends an idempotency key.

**Practice:** choose decorator order and write a test showing how many metrics are emitted when the first attempt times out.

---

## DI-19. Configuration and Options Injection

**Question:** Why inject typed configuration instead of reading environment variables everywhere?

**Answer:** Bind and validate configuration at the composition root, then inject a typed, purpose-specific object.

**What problem does this concept solve?** It centralizes parsing, validation, defaults, and reload behavior.

**Before this concept:** Services used string keys, parsed values repeatedly, and discovered missing configuration only on rare code paths.

❌ **Wrong example:**

```csharp
var timeout = int.Parse(Environment.GetEnvironmentVariable("TIMEOUT")!);
```

✅ **Correct frontend example:**

```typescript
export interface AppConfig { apiBaseUrl: string; supportUrl: string; }
export const APP_CONFIG = new InjectionToken<AppConfig>('APP_CONFIG');
providers: [{ provide: APP_CONFIG, useValue: environment }]
```

✅ **Correct backend example:**

```csharp
builder.Services.AddOptions<PaymentOptions>()
    .BindConfiguration("Payments")
    .ValidateDataAnnotations()
    .ValidateOnStart();

public sealed class PaymentClient(IOptions<PaymentOptions> options)
{
    private readonly PaymentOptions _options = options.Value;
}
```

**How it works after this pattern:** Invalid configuration fails during startup, and consumers use typed values rather than global string lookup.

**Trade-off:** Use `IOptionsSnapshot` for per-request refresh and `IOptionsMonitor` for change notifications only when dynamic reload is truly required.

### Practical walkthrough — Configuration/options injection: validate once, use typed settings

#### Before the pattern

Services read `Environment.GetEnvironmentVariable("PAYMENT_KEY")` or `localStorage` independently. Missing values are discovered halfway through a payment, and each class parses URLs/timeouts differently.

#### After the pattern

Bind configuration at the composition root to a typed, validated `PaymentOptions`/Angular config token. Fail startup for required invalid values; expose only the safe, public configuration to the browser.

```text
Raw environment/config -> validate -> typed options/token -> consumer
```

**What changed:** configuration is a dependency with a lifecycle and validation rules. Never inject secrets into an Angular bundle; browser config is public by definition.

**Practice:** define validation for base URL, timeout, and required secret, then decide which values can safely be sent to Angular.

---

## DI-20. Service Locator Anti-Pattern

**Question:** Why is resolving dependencies from `IServiceProvider` or Angular `Injector` inside business code considered a service-locator anti-pattern?

**Answer:** The class hides what it needs and discovers dependencies imperatively at runtime.

**What problem does this concept solve?** Service locator appears to make constructors shorter and permit dynamic lookup, but the important lesson is recognizing that it transfers complexity into hidden runtime behavior rather than solving coupling.

**Before this concept:** Dependency graphs were explicit but a large constructor exposed that the class had too many responsibilities.

❌ **Wrong frontend example:**

```typescript
export class OrderFacade {
  constructor(private injector: Injector) {}
  submit() { this.injector.get(PaymentApi).charge(); }
}
```

❌ **Wrong backend example:**

```csharp
public sealed class OrderService(IServiceProvider services)
{
    public Task Run() => services.GetRequiredService<IPaymentGateway>().ChargeAsync(...);
}
```

✅ **Correct example:** Inject the exact abstraction, a typed factory, or a typed strategy router.

**How it works after this pattern:** Dependencies are visible to readers, construction is validated early, and unit tests do not need a container.

**Trade-off:** Framework boundaries such as middleware activation or background scope creation may legitimately use a scope factory. Keep lookup at that boundary.

### Practical walkthrough — Service locator: see the hidden dependency failure

#### Before/anti-pattern

```csharp
public Task PayAsync() =>
    services.GetRequiredService<IPaymentGateway>().ChargeAsync(...);
```

The constructor says nothing about `IPaymentGateway`. A test constructs the service successfully, then fails only when `PayAsync` executes. The same risk applies to Angular business code calling `Injector.get()`.

#### After the pattern

Make the gateway a constructor parameter, or inject an explicit factory/selector when runtime choice is truly necessary. The composition root remains the only place that generally knows the container.

**What changed:** missing wiring fails at construction/startup and the object’s API tells the truth. Framework adapters can use a service provider at a boundary; core application code should not.

**Practice:** search for container lookups in business services and replace one with an explicit dependency. Note what becomes visible in the test.

---

## DI-21. Captive Dependencies, Disposal, and Circular Graphs

**Question:** What are the most dangerous DI lifetime and graph failures?

**Answer:** A captive dependency occurs when a long-lived object holds a shorter-lived object. Containers must also dispose owned resources and reject circular graphs.

**What problem does this concept solve?** Correct graph design prevents cross-request state leaks, disposed-object errors, memory leaks, and construction recursion.

**Before this concept:** Singleton services captured request DbContexts, components provided subscriptions without cleanup, and circular services depended on each other.

❌ **Wrong backend example:**

```csharp
services.AddScoped<AppDbContext>();
services.AddSingleton<OrderCache>(); // OrderCache constructor takes AppDbContext: captive dependency
```

❌ **Wrong frontend example:** `ServiceA -> ServiceB -> ServiceA`, or a root service holds a component-scoped object beyond the component's life.

✅ **Correct backend example:**

```csharp
public sealed class CleanupJob(IServiceScopeFactory scopes)
{
    public async Task RunAsync(CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.CleanupAsync(ct);
    }
}
```

✅ **Correct frontend example:** Break circular responsibilities using a lower-level shared abstraction and clean subscriptions with `takeUntilDestroyed()`.

**How it works after this pattern:** Each operation owns a valid scope, disposables end with that scope, and the dependency graph remains acyclic.

**Trade-off:** Do not create scopes casually to bypass lifetime rules. Scope creation belongs at operation boundaries such as jobs or messages.

### Practical walkthrough — Captive dependencies, disposal, and cycles: make lifetimes valid

#### Before the pattern

A singleton `ReportCache` receives scoped `AppDbContext`. It captures the first request’s disposed context and eventually throws or leaks tenant data. Separately, `OrderService -> PaymentService -> OrderService` forms a cycle, hiding unclear responsibilities.

#### After the pattern

Singletons depend only on singletons or create short-lived scopes at a clear operation boundary (for example, a background message). Scoped services own scoped disposables; the container disposes them at request/job end. Break cycles by extracting a lower-level port or restructuring the workflow.

```text
Invalid: Singleton -> Scoped DbContext
Valid:   Background worker -> creates scope -> Scoped handler + DbContext -> dispose
```

**What changed:** lifetime ownership becomes safe and the graph is acyclic. Creating scopes is not a loophole for injecting anything anywhere—it must align to a meaningful operation.

**Practice:** draw the dependency graph for a request and color singleton/scoped/transient nodes. Any arrow from a longer to shorter life needs redesign.

---

## DI-22. Testing and Dependency Overrides

**Question:** How does DI improve frontend and backend testing?

**Answer:** Tests replace boundary dependencies with controlled fakes while constructing the real class under test.

**What problem does this concept solve?** Tests become deterministic and do not call real payment, storage, clock, or network services.

**Before this concept:** Classes constructed real SDKs internally, so unit tests needed network credentials or unsafe global patches.

❌ **Wrong example:** Mock every internal class and assert implementation details, producing tests that pass while integration contracts fail.

✅ **Correct frontend example:**

```typescript
await TestBed.configureTestingModule({
  providers: [
    CheckoutFacade,
    { provide: PaymentApi, useValue: jasmine.createSpyObj('PaymentApi', ['charge']) }
  ]
}).compileComponents();
```

✅ **Correct backend example:**

```csharp
var fakeGateway = new FakePaymentGateway(PaymentResult.Success("p-123"));
var service = new PaymentService(fakeGateway, repository, fakeClock);
var result = await service.ChargeAsync(payment, CancellationToken.None);
Assert.True(result.IsSuccess);
```

**How it works after this pattern:** Unit tests replace unstable boundaries; integration tests override the composition root with containers or test implementations while exercising real framework wiring.

**Trade-off:** DI enables testing but does not require mocking everything. Prefer real value objects and pure domain logic; fake only external boundaries.

### Practical walkthrough — Testing and overrides: replace boundaries, keep behavior real

#### Before DI

An Angular checkout test patches a global `fetch`; a .NET test needs real payment credentials. Tests are slow, flaky, and cannot force unusual outcomes such as “payment accepted but webhook delayed.”

#### After DI

The unit test constructs the real checkout workflow with a fake gateway, clock, and repository. Angular `TestBed` replaces the token provider; .NET integration tests replace registrations in the test host.

```text
Production: Checkout + StripeGateway + SystemClock
Unit test:  Checkout + FakeGateway   + FixedClock
```

**What changed:** the test controls unstable boundaries but continues to exercise real domain decisions. Do not mock every internal method; use real value objects and add contract tests for adapters so fakes do not drift from production behavior.

**Practice:** write one unit test for declined payment, one adapter contract test, and one integration test that verifies the real composition root resolves the graph.

---

## Dependency Injection Type Comparison

| Type / pattern | Angular frontend | ASP.NET Core backend | Recommendation |
|---|---|---|---|
| Constructor injection | Supported | Supported | Default for required class dependencies |
| `inject()` context | Supported | No direct equivalent | Good for Angular functional APIs |
| Method/parameter injection | Factory/functions | Endpoints/actions | Good for operation-specific dependencies |
| Property/setter injection | Not idiomatic DI | Not built into default container | Avoid for required dependencies |
| Interface injection | Not possible with erased TS interfaces | Manual/plugin pattern | Rare, framework-specific |
| Field injection | `inject()` initializer is context-based | Not built in | Avoid hidden reflection-based injection |
| Token/abstraction | `InjectionToken<T>` | Runtime type/interface | Use at meaningful boundaries |
| Singleton/root | `providedIn: 'root'` | `AddSingleton` | Only stateless/thread-safe or intentional global state |
| Scoped/subtree | Component/environment provider | `AddScoped` request/job scope | Use for operation-owned state |
| Transient | New provider resolution | `AddTransient` | Use for lightweight stateless objects |
| Factory | `useFactory` | Delegate registration | Use for configuration-based construction |
| Keyed/named | Separate tokens | Keyed services | Prefer typed selection when runtime-driven |
| Optional | `optional: true` | Null Object/default registration | Only for genuinely optional behavior |
| Lazy | Dynamic import / typed factory | Explicit `Func<T>` factory | Use for expensive rare dependencies |
| Collection | `multi: true` | `IEnumerable<T>` | Good for pipelines/plugins |
| Open generic | Explicit tokens required | Native open-generic registration | Useful for truly generic behavior |
| Decorator | Interceptors/wrapper providers | Decorator registration | Good for cross-cutting behavior |
| Service locator | `Injector.get()` in business code | `IServiceProvider.GetService()` in business code | Avoid |

---

## Dependency Injection Interview Checklist

For any DI question, explain:

1. Which dependencies are required and which are truly optional?
2. Where is the composition root?
3. What lifetime owns each object?
4. Can a longer-lived object capture a shorter-lived one?
5. Who disposes resources?
6. Is selection made at configuration time or runtime?
7. Does a factory or collection express the requirement better than container lookup?
8. How will tests replace external boundaries?

---
