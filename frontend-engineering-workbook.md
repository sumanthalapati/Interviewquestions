# Frontend Engineering Practice Workbook

This workbook turns the repository's frontend guides into deliberate practice. It is organized by engineering topic rather than framework trivia. Every module asks you to explain the browser/runtime model, diagnose a weak implementation, write a safer design, and prove the result with tests or production evidence.

Use it with [HTML & CSS](html-css.md), [JavaScript](javascript.md), [TypeScript](typescript.md), [Angular](angular.md), [RxJS](rxjs.md), and [NgRx](ngrx.md). Attempt each question without notes, then compare your reasoning with the answer key. The goal is to make a decision and defend it, not memorize an API name.

## Workbook Index

1. [HTML semantics and accessibility](#1-html-semantics-and-accessibility)
2. [CSS layout, responsiveness, and rendering cost](#2-css-layout-responsiveness-and-rendering-cost)
3. [JavaScript values, closures, modules, and object behavior](#3-javascript-values-closures-modules-and-object-behavior)
4. [Event loop, asynchronous work, DOM, and networking](#4-event-loop-asynchronous-work-dom-and-networking)
5. [TypeScript modeling, generics, narrowing, and API boundaries](#5-typescript-modeling-generics-narrowing-and-api-boundaries)
6. [Angular architecture, templates, DI, lifecycle, and signals](#6-angular-architecture-templates-di-lifecycle-and-signals)
7. [Angular forms, routing, HTTP, and feature boundaries](#7-angular-forms-routing-http-and-feature-boundaries)
8. [RxJS streams, flattening, cancellation, errors, and sharing](#8-rxjs-streams-flattening-cancellation-errors-and-sharing)
9. [NgRx state, effects, selectors, and entity modeling](#9-ngrx-state-effects-selectors-and-entity-modeling)
10. [Frontend design patterns and state ownership](#10-frontend-design-patterns-and-state-ownership)
11. [Browser security, authentication, and data protection](#11-browser-security-authentication-and-data-protection)
12. [Testing strategy, performance, and observability](#12-testing-strategy-performance-and-observability)
13. [API integration and production failure workbook](#13-api-integration-and-production-failure-workbook)

---

## 1. HTML Semantics and Accessibility

### Concept map

- Semantic elements communicate document structure to browsers, assistive technology, search engines, and maintainers.
- Native controls already provide much of the keyboard, focus, role, value, and state behavior that custom widgets must reproduce. Authors must still supply the right element, accessible name, instructions, and error context.
- Accessible name, role, state, focus order, landmark structure, headings, form labels, error association, and live announcements are separate concerns.
- ARIA can add missing semantics; it does not repair incorrect interaction behavior, contrast, focus management, or a missing native element.
- Accessibility is tested with keyboard-only operation, an accessibility tree, automated checks, zoom/reflow, and representative screen readers—not one lint rule.

### Wrong/before example

```html
<div class="save" onclick="saveProfile()">Save</div>

<input id="email" placeholder="Email">
<div class="error">Invalid value</div>

<div class="dialog">
  <div onclick="closeDialog()">X</div>
  <div>Delete account?</div>
</div>
```

The clickable `div` is absent from the normal tab order and has no button semantics. The placeholder is not a persistent label. The error is not programmatically associated with the input. The dialog lacks a name, modality semantics, focus entry/containment/restoration, and Escape behavior.

### Correct/after example

```html
<form aria-labelledby="profile-heading" novalidate>
  <h1 id="profile-heading">Edit profile</h1>

  <label for="email">Email address</label>
  <input
    id="email"
    name="email"
    type="email"
    autocomplete="email"
    aria-invalid="true"
    aria-describedby="email-error">
  <p id="email-error" role="alert">Enter a valid email address.</p>

  <button type="submit">Save profile</button>
</form>

<dialog id="delete-dialog" aria-labelledby="delete-title">
  <form method="dialog">
    <h2 id="delete-title">Delete account?</h2>
    <p>This action cannot be undone.</p>
    <button type="submit" value="cancel" autofocus>Cancel</button>
    <button type="submit" value="delete">Delete account</button>
  </form>
</dialog>
```

The form example shows a post-validation state; before validation, do not expose a field as invalid or announce an error that has not occurred. JavaScript must still call `showModal()`, reset then inspect the dialog's `returnValue`, perform deletion only for the explicit `delete` result, handle cancellation, and verify that focus returns to the opener. Resetting avoids treating a value retained from an earlier opening as a new confirmation. Native `<dialog>` reduces work; it does not decide product-safe focus and confirmation behavior for you.

### Practice questions

1. Why is `<button>` normally better than `<div role="button" tabindex="0">`, and what would the custom element still need?
2. Distinguish an element's visible label, accessible name, description, role, value, and state.
3. A checkout form shows a red border around invalid fields. What additional behavior is needed for accessible validation?
4. When should `aria-live`, `role="status"`, and `role="alert"` be used, and why can excessive announcements make a page worse?
5. How would you test a modal, data table, and SPA route change without assuming an automated checker proves accessibility?

### Detailed answer key

1. A native button provides focusability, semantic role, keyboard activation for Enter/Space, disabled behavior, form integration, and platform accessibility mappings. A custom element must reproduce keyboard events without double activation, focus, disabled state, high-contrast/focus styling, role/name/state, and form behavior. Prefer the native element unless the semantics are genuinely different.
2. The visible label is what sighted users read. The accessible name identifies the control in the accessibility tree, commonly from a `<label>`, text content, or `aria-labelledby`. A description supplies supplementary help/error text. Role says what the element is. Value is its current data. State includes expanded, selected, checked, invalid, disabled, and similar properties. A control can have a correct role but an unusable or missing name.
3. Provide persistent labels, mark invalid state programmatically, associate a specific error with the control, move or summarize focus appropriately after submission, announce new errors without repeating excessively, preserve entered data, and explain recovery. Do not rely on color alone; include text/icon semantics and sufficient contrast.
4. Use a polite status region for non-urgent changes such as results loaded; use an assertive alert for important time-sensitive errors. Live regions should exist before content changes when practical. Announcing every keystroke, loading frame, or decorative update overwhelms users and can interrupt important speech.
5. Inspect landmarks/headings/names in the accessibility tree; complete all actions using only the keyboard; verify visible focus, order, Escape, trapping/restoration, sorting announcements, header associations, captions, and route title/focus; zoom to 200–400%; run automated checks; and perform representative screen-reader flows. Test actual tasks rather than individual nodes only.

### Failure and production checks

- Block releases on critical automated violations but maintain manual keyboard/screen-reader scenarios.
- Monitor design-system components so fixes propagate instead of re-solving buttons, dialogs, errors, and menus per feature.
- Test loading, empty, error, success, permission-denied, and dynamically updated states.
- Include reduced motion, high contrast/forced colors, responsive reflow, localization expansion, and 200%+ zoom.
- Track accessibility regressions by component and user journey; do not use a single score as proof of usability.

### Build/debug task

Implement an accessible account form and destructive confirmation dialog. Write keyboard tests for focus order, error focus/association, Escape/cancel, focus restoration, and submission. Inspect the accessibility tree and record one manual screen-reader walkthrough with the problems you found and fixed.

---

## 2. CSS Layout, Responsiveness, and Rendering Cost

### Concept map

- Normal flow, flexbox, grid, positioning, containment, stacking contexts, and overflow solve different layout problems.
- Responsive design follows available space and content behavior, not a list of popular device widths.
- Intrinsic sizes, `min-width: auto`, replaced elements, long words, writing modes, and localization frequently expose layout assumptions.
- Style calculation, layout, paint, rasterization, and compositing are different rendering stages; a visual change may affect one or several.
- Specificity, cascade layers, inheritance, custom properties, and component boundaries determine whether CSS stays predictable.

### Wrong/before example

```css
.dashboard { width: 1200px; }
.card { float: left; width: 380px; margin: 10px; }
.title { height: 24px; overflow: hidden; }
.sidebar { position: absolute; left: 0; top: 70px; height: 1000px; }

@media (max-width: 768px) {
  .dashboard { transform: scale(.62); transform-origin: top left; }
}
```

This makes content unreadable rather than reflowing it, assumes English-sized text and a fixed page height, removes the sidebar from normal layout, and creates brittle arithmetic.

### Correct/after example

```css
@layer reset, components, utilities;

@layer components {
  .dashboard {
    display: grid;
    grid-template-columns: minmax(14rem, 18rem) minmax(0, 1fr);
    gap: clamp(1rem, 2vw, 2rem);
    max-inline-size: 90rem;
    margin-inline: auto;
    padding: clamp(1rem, 3vw, 2.5rem);
  }

  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 18rem), 1fr));
    gap: 1rem;
  }

  .card { min-inline-size: 0; }
  .card img { max-inline-size: 100%; block-size: auto; }
  .title { overflow-wrap: anywhere; }

  @media (max-width: 48rem) {
    .dashboard { grid-template-columns: 1fr; }
  }
}
```

Do not add containment as a generic performance ritual. If profiling shows a useful boundary, choose the smallest suitable form and test sizing, positioned descendants, overflow, sticky behavior, and clipped focus/visual affordances.

### Practice questions

1. When should flexbox, grid, and normal flow be chosen, and why is “one-dimensional versus two-dimensional” only a starting rule?
2. Why does `minmax(0, 1fr)` often fix overflow that `1fr` exposes?
3. What creates a stacking context, and why can `z-index: 999999` still appear under another element?
4. Compare changing `top/left`, `width`, `transform`, and `opacity` in an animation. Which rendering work may each trigger?
5. How would you design breakpoints for a reusable component embedded in differently sized parents?

### Detailed answer key

1. Normal flow is best for ordinary document content. Flexbox distributes/aligns items along a main axis and handles content-sized rows/columns. Grid coordinates tracks and placement across rows and columns. Real components combine them: grid for page regions, flex for control groups, flow for text. Choose from content relationships, source order, wrapping, intrinsic sizing, and accessibility—not a slogan.
2. A grid/flex item's automatic minimum size may be its min-content width, preventing the track from shrinking below a long word/table. `minmax(0,1fr)` gives the fractional track a zero minimum so the item can shrink and handle its own overflow. The content still needs wrapping or intentional scrolling.
3. Triggers include positioned elements with non-auto `z-index`, transforms, opacity below 1, filters, isolation, certain containment, and others. `z-index` compares siblings inside the same stacking context; a child cannot escape an ancestor whose entire context sits below another context.
4. `top/left` on positioned elements often requires layout and paint; width commonly affects layout and downstream geometry; transforms and opacity can often update compositor layers without layout/paint after promotion. “Compositor-only” is not free: large layers consume memory, may rasterize, and excessive `will-change` is harmful.
5. Prefer container queries when behavior depends on component space, use intrinsic grids/wrapping, and place breakpoints where content stops working. Test localized text, user zoom, narrow sidebars, and large fonts. Viewport queries remain useful for global navigation/page-level decisions.

### Failure and production checks

- Test overflow with long unbroken text, large translated labels, real tables/images, and 400% zoom.
- Preserve DOM/source order when visual layout changes; CSS reordering must not create a confusing keyboard/screen-reader sequence.
- Measure layout shifts, long rendering tasks, layer count/memory, and animation frame drops on representative hardware.
- Establish cascade layers/design tokens/component contracts instead of escalating specificity and `!important`.
- Respect `prefers-reduced-motion`; avoid motion that is essential to understanding or can cause discomfort.

### Build/debug task

Build a dashboard that works inside full-width, half-width, and narrow containers without component-specific JavaScript. Add localization stress strings, a large data table, 400% zoom, reduced-motion styles, and a performance recording. Explain one layout, paint, and compositing decision.

---

## 3. JavaScript Values, Closures, Modules, and Object Behavior

### Concept map

- Primitives are copied as values; objects/functions are referenced by object identity. Assignment never performs an automatic deep copy.
- Lexical scope and closures retain access to bindings, not frozen snapshots of every value.
- `this` depends on call form for ordinary functions; arrow functions capture lexical `this` and cannot be rebound as methods/constructors.
- Prototypes provide delegated property lookup; `class` is syntax over this object model with private-field additions.
- ES modules have static structure, live bindings, single evaluation per module instance, and circular-dependency timing considerations.
- Equality, coercion, property descriptors, iteration, and mutation semantics must be explicit at API boundaries.

### Wrong/before example

```javascript
const defaults = { filters: { tags: [] } };

function createSearchOptions(overrides) {
  const options = { ...defaults, ...overrides }; // shallow copy
  options.filters.tags.push('featured');
  return options;
}

const first = createSearchOptions({});
const second = createSearchOptions({});
// Both share defaults.filters.tags and leak state between calls.
```

### Correct/after example

```javascript
function createSearchOptions(overrides = {}) {
  return {
    pageSize: overrides.pageSize ?? 20,
    filters: {
      category: overrides.filters?.category ?? null,
      tags: [...(overrides.filters?.tags ?? [])]
    }
  };
}

const first = createSearchOptions();
first.filters.tags.push('featured');
const second = createSearchOptions();
console.assert(second.filters.tags.length === 0);
```

Explicit construction documents ownership better than blindly deep-cloning arbitrary objects, which can mishandle class instances, functions, platform objects, performance, and non-cloneable data.

### Practice questions

1. Explain why a closure in a `for (var i...)` loop can observe the final value, and compare `let` and an explicit factory function.
2. How do ordinary methods, detached methods, `.call`, `.bind`, and arrow properties affect `this` and allocation?
3. Distinguish shallow copy, `structuredClone`, JSON serialization, and domain-specific copying.
4. What are ES-module live bindings, and how can a circular dependency read an uninitialized binding?
5. Why should `Object.freeze()` not be described as deep immutability, and how can TypeScript `readonly` differ from runtime protection?

### Detailed answer key

1. `var` creates one function-scoped binding; callbacks execute later and all read its final value. `let` creates a new per-iteration binding. A factory also creates a new lexical parameter for each callback. Closures capture bindings and can observe subsequent mutations to those bindings/objects.
2. `obj.method()` sets `this` to `obj`; detaching `const f=obj.method; f()` loses that receiver (undefined in strict mode). `.call` invokes with an explicit receiver; `.bind` returns a wrapper with fixed receiver/leading args. Arrow properties capture construction-time lexical `this` and allocate a function per instance; prototype methods are shared and can be bound only at callback boundaries.
3. Spread/`Object.assign` copy only own enumerable top-level properties. `structuredClone` supports many built-in structured types and cycles, but it cannot clone functions or some platform resources and does not preserve arbitrary custom class prototypes as an application contract. JSON drops unsupported values, converts a `Date` to text through `toJSON`, serializes maps/sets as ordinary empty objects unless customized, and fails on cycles. Domain copying explicitly preserves invariants and ownership.
4. Imported variables remain connected to the exporting module rather than copied once. Modules instantiate before evaluation; a cycle can execute code that accesses a lexical export before its declaration initializes, causing a temporal-dead-zone error or partial initialization patterns. Break cycles or defer access deliberately.
5. `Object.freeze` prevents top-level own-property changes but nested objects remain mutable unless recursively frozen. TypeScript `readonly` is a compile-time constraint and can be bypassed by aliases/JavaScript/casts; it emits no automatic runtime freeze. Prefer immutable ownership/API design over assuming either is absolute protection.

### Failure and production checks

- Test aliasing and mutation boundaries with nested data, maps/sets, dates, class instances, and large payloads.
- Keep module dependency direction acyclic; detect cycles in builds and avoid module-load side effects.
- Use `Object.is`, strict equality, or explicit domain comparison intentionally; test `NaN`, `-0`, nullish values, and coercion at external boundaries.
- Avoid prototype pollution by validating keys and using safe object construction for untrusted dictionaries.
- Profile copying/normalization on large state trees; immutability should enable reasoning, not create invisible quadratic work.

### Build/debug task

Create a small normalized entity store without a framework. Implement immutable add/update/remove, memoized selectors, domain-safe copying, and module boundaries. Write tests that attempt alias mutation, duplicate IDs, cyclic imports, `NaN` values, and malicious `__proto__` keys.

---

## 4. Event Loop, Asynchronous Work, DOM, and Networking

### Concept map

- JavaScript execution uses a call stack plus host queues. Promise reactions run as microtasks; timers/events are tasks. The browser normally drains microtasks before rendering and taking the next task.
- Long synchronous work and unbounded microtask chains block input and rendering even when code uses promises.
- Fetch resolves for HTTP error statuses; it rejects mainly for network/abort failures. Response bodies are streams and usually consumable once.
- `AbortController` communicates cancellation; every layer must propagate and respect the signal.
- DOM reads/writes can trigger style/layout work. Batch reads, then writes; use platform observers rather than polling where appropriate.
- Browser caches, CORS, credentials, service workers, storage, and network retries have correctness/security semantics, not only performance effects.

### Wrong/before example

```javascript
input.addEventListener('input', async event => {
  const response = await fetch(`/api/search?q=${event.target.value}`);
  const results = await response.json();
  resultsElement.innerHTML = results
    .map(item => `<li>${item.name}</li>`)
    .join('');
});
```

Requests race, obsolete work is not cancelled, HTTP failures are parsed as success, the query is not encoded, and `innerHTML` creates an injection sink if names are untrusted.

### Correct/after example

```javascript
let currentRequest;
let sequence = 0;

input.addEventListener('input', debounce(async event => {
  currentRequest?.abort();
  currentRequest = new AbortController();
  const requestSequence = ++sequence;
  const query = event.target.value.trim();

  if (!query) {
    resultsElement.replaceChildren();
    return;
  }

  try {
    const response = await fetch(
      `/api/search?q=${encodeURIComponent(query)}`,
      { signal: currentRequest.signal, credentials: 'same-origin' }
    );
    if (!response.ok) throw new Error(`Search failed: ${response.status}`);

    const results = parseSearchResults(await response.json());
    if (requestSequence !== sequence) return;

    const fragment = document.createDocumentFragment();
    for (const item of results) {
      const li = document.createElement('li');
      li.textContent = item.name;
      fragment.append(li);
    }
    resultsElement.replaceChildren(fragment);
  } catch (error) {
    if (error.name === 'AbortError' || requestSequence !== sequence) return;
    showSearchError(error);
  }
}, 250));
```

The sequence check belongs on failure as well as success: an older request can fail after a newer query starts, and its error must not replace the current query's state.

### Practice questions

1. Predict the order of synchronous logs, promise callbacks, `queueMicrotask`, and `setTimeout(...,0)`. Why can an infinite microtask chain starve rendering?
2. Distinguish concurrency, parallelism, asynchrony, a Web Worker, and `requestAnimationFrame`.
3. Why does `fetch` require both `try/catch` and a `response.ok` check? How should timeouts and user cancellation differ in telemetry?
4. What causes layout thrashing, and how do `ResizeObserver`, `IntersectionObserver`, and batching help?
5. When should browser storage, HTTP cache, Cache Storage/service workers, and in-memory state be used, and what can go wrong with each?

### Detailed answer key

1. Current synchronous code finishes first. Promise reactions and `queueMicrotask` callbacks run in queued order during the microtask checkpoint, then the browser may render, then a timer task can run. Each microtask can queue another, so an endless chain prevents the checkpoint from finishing and starves input/render/tasks.
2. Asynchrony lets work complete later without blocking the caller. Concurrency means multiple tasks make progress over time. Parallelism means simultaneous execution. A worker can run JavaScript on another thread but communicates by messages/transfers and has no direct DOM access. `requestAnimationFrame` schedules main-thread work before a paint; it does not make heavy work parallel.
3. Network/abort failures reject; HTTP 404/500 usually resolve with `ok=false`. Parse only after handling status/content contract. A user abort is expected control flow, a deadline may indicate load/dependency latency, and a network failure is transport failure; record distinct outcomes and avoid noisy error reporting for intentional cancellation.
4. Interleaving geometry reads after DOM/style writes can force repeated synchronous layout. Read required measurements together, then apply writes, prefer CSS, and use observers that report resize/visibility changes without polling every frame. Observer callbacks can still create loops if they mutate size carelessly.
5. In-memory state is fast/ephemeral per page. Web Storage is synchronous, string-based, origin-scoped, and poor for secrets/large data. IndexedDB supports structured async local data but needs schema/consistency handling. HTTP cache follows validators/cache headers. Cache Storage/service workers enable offline/request strategies but can serve stale incompatible assets. Every layer needs versioning, privacy, quota, invalidation, and logout behavior.

### Failure and production checks

- Test slow/out-of-order responses, offline transitions, aborts, duplicate submissions, 4xx/5xx, malformed JSON, and partial streams.
- Propagate cancellation through UI, client service, retry wrapper, and server; verify obsolete responses cannot update current state.
- Monitor long tasks, interaction latency, failed resource loads, API phase timing, and client-visible streaming/buffering.
- Sanitize or use safe DOM APIs; enforce CSP/Trusted Types where appropriate rather than trusting output encoding by convention.
- Version service-worker caches and test update, rollback, offline, and mixed-old/new-tab behavior.

### Build/debug task

Build a cancellable typeahead that supports loading/empty/error/offline states and safe rendering. Add a mock server that deliberately reorders and delays responses. Test that only the latest query renders, cancellation is quiet, HTTP errors display correctly, and keyboard interaction remains usable.

---

## 5. TypeScript Modeling, Generics, Narrowing, and API Boundaries

### Concept map

- TypeScript checks JavaScript statically; types are erased and cannot validate runtime input by themselves.
- Prefer domain types that make invalid states difficult: discriminated unions, branded identifiers, readonly boundaries, exact result variants.
- `unknown` requires proof before use; `any` opts out. Type assertions state trust without checking it.
- Generics preserve relationships between inputs and outputs; constraints express required capabilities.
- Narrowing follows control flow, predicates, discriminants, and assertion functions; mutation/aliasing can invalidate assumptions.
- Mapped, conditional, indexed-access, template-literal, and utility types should clarify contracts rather than simulate a language inside the type system.

### Wrong/before example

```typescript
interface ApiOrder {
  id: string;
  status: string;
  total: number;
}

async function loadOrder(id: string): Promise<ApiOrder> {
  const response = await fetch(`/api/orders/${id}`);
  return await response.json() as ApiOrder;
}

function render(order: ApiOrder) {
  if (order.status === 'paid') showReceipt(order);
  else showPaymentButton(order); // cancelled/failed/unknown also treated as payable
}
```

The assertion validates nothing, `status` permits every string, money has no currency/precision contract, and error/loading/not-found states are outside the type model.

### Correct/after example

```typescript
type OrderId = string & { readonly __brand: 'OrderId' };
type OrderStatus = 'pending' | 'paid' | 'cancelled' | 'failed';

type Order = Readonly<{
  id: OrderId;
  status: OrderStatus;
  totalMinor: number;
  currency: 'USD' | 'INR';
}>;

type LoadState<T> =
  | { readonly kind: 'idle' }
  | { readonly kind: 'loading' }
  | { readonly kind: 'success'; readonly value: T }
  | { readonly kind: 'not-found' }
  | { readonly kind: 'error'; readonly message: string; readonly retryable: boolean };

function parseOrder(value: unknown): Order {
  return orderSchema.parse(value); // runtime validator at the trust boundary
}

function assertNever(value: never): never {
  throw new Error(`Unhandled variant: ${JSON.stringify(value)}`);
}

function describeLoad<T>(state: LoadState<T>): string {
  switch (state.kind) {
    case 'idle': return 'Not requested';
    case 'loading': return 'Loading';
    case 'success': return 'Loaded';
    case 'not-found': return 'Not found';
    case 'error': return state.message;
    default: return assertNever(state);
  }
}
```

### Practice questions

1. Compare `any`, `unknown`, `never`, `void`, and `undefined` in practical API design.
2. When should a generic use a constraint such as `<T extends { id: string }>` and when should a concrete domain type be preferred?
3. How do discriminated unions improve state handling, and how does an exhaustive `never` check expose future changes?
4. Why can `Readonly<T>` and `Partial<T>` be misleading at nested/runtime/patch boundaries?
5. What is the difference between `satisfies`, a type annotation, and `as`, and which preserves inference while checking compatibility?

### Detailed answer key

1. `any` disables checking and flows unsafely. `unknown` can hold anything but requires narrowing. `never` represents an impossible value/return and supports exhaustiveness. `void` means a caller should not use a return value, not necessarily that runtime returns `undefined`. `undefined` is a concrete value/type often indicating absence. Use `unknown` for untrusted input and `never` for impossible branches.
2. A constraint is useful for a reusable algorithm that needs a capability while preserving the rest of `T`, such as indexing entities by ID. A concrete type is clearer when behavior and invariants are domain-specific; avoid generic abstractions that erase meaningful distinctions such as Order and Customer.
3. A stable discriminant narrows every variant's fields and prevents illegal combinations such as loading with data and error simultaneously. A switch whose default passes to `assertNever` stops compiling when a new variant is added but not handled.
4. Both utilities are shallow. `Readonly` emits no runtime freeze and nested mutable members remain mutable. `Partial` makes every top-level property optional but cannot distinguish omitted from explicitly undefined/deleted and may violate patch invariants. Define domain-specific patch commands and validate runtime input.
5. An annotation checks and may widen the expression to the annotated type. `as` asserts compatibility and can suppress evidence requirements. `satisfies` checks assignability while retaining the expression's inferred specific type, useful for configuration maps and exhaustive keys.

### Failure and production checks

- Validate JSON, storage, URL params, messages, and third-party SDK data at runtime; never rely on generated/static interfaces alone.
- Enable strict compiler options appropriate to the codebase (`strict`, indexed access, exact optional semantics) and fix errors deliberately.
- Model money, time zones, units, IDs, permissions, and state transitions explicitly.
- Keep public generics understandable; add type-level tests for complex utilities and avoid excessive compile-time cost.
- Treat assertions/non-null assertions as reviewed trust points with tests or upstream invariants.

### Build/debug task

Create a typed API client that accepts `unknown`, validates a paginated order response, maps transport DTOs to domain types, models all request states, supports cancellation, and exhaustively renders them. Write runtime tests for missing fields, extra enum values, wrong currency, overflow, and malformed dates.

---

## 6. Angular Architecture, Templates, DI, Lifecycle, and Signals

### Concept map

- Organize by cohesive feature and dependency direction, not by giant folders of technical file types.
- Components own view interaction/rendering; application services/facades coordinate use cases; infrastructure adapters talk to HTTP/storage.
- Angular DI chooses construction/lifetime at composition boundaries. Required collaborators should be explicit and correctly scoped.
- Template bindings should be predictable and cheap; avoid methods with hidden work/side effects during change detection.
- Lifecycle hooks describe view/content/input timing; subscriptions/effects/listeners need ownership and cleanup.
- Signals model synchronous reactive state; computed values derive state, and effects synchronize with external systems rather than calculate ordinary state.

### Wrong/before example

```typescript
@Component({ selector: 'app-orders', templateUrl: './orders.html' })
export class OrdersComponent implements OnInit {
  orders: Order[] = [];

  ngOnInit() {
    const http = new HttpClient(/* manually constructed dependencies */);
    setInterval(() => {
      http.get<Order[]>('/api/orders').subscribe(rows => this.orders = rows);
    }, 1000);
  }

  visibleOrders() {
    return this.orders.filter(x => expensivePermissionCheck(x));
  }
}
```

The component constructs infrastructure, nests unmanaged work, leaks timers/subscriptions, polls regardless of visibility, trusts DTOs, and repeats expensive filtering during rendering.

### Correct/after example

```typescript
@Injectable()
export class OrdersFacade {
  private readonly api = inject(OrdersApi);
  private readonly refresh = new Subject<void>();

  readonly state = toSignal(
    this.refresh.pipe(
      startWith(undefined),
      switchMap(() => this.api.loadOrders().pipe(
        map(orders => ({ kind: 'success', orders }) as const),
        startWith({ kind: 'loading' } as const),
        catchError(error => of({ kind: 'error', error: mapError(error) } as const))
      ))
    ),
    { initialValue: { kind: 'loading' } as const }
  );

  refreshNow(): void { this.refresh.next(); }
}

@Component({
  selector: 'app-orders',
  templateUrl: './orders.html',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OrdersComponent {
  readonly facade = inject(OrdersFacade);
  readonly state = this.facade.state;
}
```

The feature provider scope must be chosen deliberately: root scope shares state across the app; route/component scope creates a bounded instance.

### Practice questions

1. How do standalone components, feature routes, facades, domain services, and infrastructure adapters divide responsibility?
2. Compare root, route, component, and environment-injector provider scopes. What bug occurs when a stateful service has an accidental duplicate provider?
3. When should `computed` versus `effect` be used with signals, and why is writing derived state in effects risky?
4. What timing guarantees do constructor, input setters, `ngOnChanges`, `ngOnInit`, `ngAfterViewInit`, and destroy cleanup provide?
5. Why can calling a method from a template become expensive or unstable, and what alternatives exist?

### Detailed answer key

1. Standalone components compose UI and interaction. Feature routes define lazy boundary/providers/navigation. A facade exposes view-shaped state/commands. Domain/application services enforce use cases independent of templates. Infrastructure adapters implement HTTP/storage ports. Keep dependencies inward and make framework/provider choices at composition roots.
2. Root is one application instance; route scope lives with a routed feature injector; component scope creates per-component-subtree instances; environment injectors create deliberate environment boundaries. Providing the same stateful service in child and root creates two stores/caches/event channels, so updates appear to “disappear” across consumers.
3. `computed` derives a pure cached value from signals. `effect` performs external synchronization such as storage, logging, or an imperative library, with explicit cleanup. Prefer commands or an owned RxJS pipeline for event-driven network work rather than making an effect an accidental request loop. Using effects to copy one signal into another creates timing cycles, inconsistent sources of truth, and unnecessary writes; derive instead.
4. Constructor is for DI/basic initialization, not view access. Inputs may change multiple times; `ngOnChanges` reports them before `ngOnInit` on the first pass. `ngOnInit` runs once after initial inputs. A `static: true` view query can be read in `ngOnInit` but does not update for later structural changes; dynamic view queries are ready by `ngAfterViewInit`, while content queries have the corresponding content hooks. Destroy is where resources owned by the instance must stop; modern helpers can bind cleanup to the destroy context.
5. Change detection may evaluate methods repeatedly; allocation, filtering, I/O, state mutation, or nondeterminism creates cost and expression instability. Use fields/signals/computed values, pure pipes with understood caching, memoized selectors, and move side effects out of template evaluation.

### Failure and production checks

- Test provider scope and route unload/re-entry; verify stores, caches, timers, and subscriptions do not survive or duplicate unexpectedly.
- Enforce feature dependency boundaries and lazy loading; detect accidental eager imports.
- Profile change-detection/component rendering with realistic lists and events; use stable tracking keys.
- Clean up RxJS, DOM listeners, timers, effects, observers, and third-party widgets on destroy.
- Model loading/empty/error/permission/stale/offline states rather than letting `undefined` leak into templates.

### Build/debug task

Build a lazy-loaded Orders feature with route-scoped facade state, typed API adapter, signal-derived filters, OnPush components, and explicit loading/error states. Add tests proving two route visits do not duplicate polling and a second consumer in the same route receives the same facade instance.

---

## 7. Angular Forms, Routing, HTTP, and Feature Boundaries

### Concept map

- Reactive forms make form state and validation explicit; typed forms reduce field/value mistakes but runtime/server validation remains authoritative.
- Sync validators answer immediately; async validators need debouncing/cancellation and must not become an authorization boundary.
- Route configuration defines URL ownership, lazy loading, resolvers, guards, and provider lifetimes. Guards improve UX but the server enforces authorization.
- Interceptors handle cross-cutting transport policy such as correlation, auth attachment, telemetry, and bounded retry—not feature-specific business decisions.
- DTO parsing/mapping belongs at a trust boundary. Components should consume domain/view models, not raw transport shapes.
- Optimistic UI needs an operation identity, rollback/reconciliation strategy, and behavior for concurrent edits.

### Wrong/before example

```typescript
submit(): void {
  if (this.form.valid) {
    this.http.post('/api/users', this.form.value).subscribe(() => {
      this.router.navigate(['/users']);
    });
  }
}

export const adminGuard = () => localStorage.getItem('role') === 'admin';
```

`form.value` can omit disabled controls and is not a validated domain command. Double clicks can duplicate writes, errors leave no state, subscription ownership is unclear, and client-controlled storage is treated as authorization.

### Correct/after example

```typescript
type SubmitState =
  | { kind: 'idle' }
  | { kind: 'submitting' }
  | { kind: 'validation-error'; fields: Record<string, string> }
  | { kind: 'failed'; message: string; retryable: boolean }
  | { kind: 'succeeded'; userId: UserId };

submit(): void {
  this.form.markAllAsTouched();
  if (this.form.invalid || this.submitState().kind === 'submitting') return;

  const command = mapFormToCreateUser(this.form.getRawValue());
  this.submitState.set({ kind: 'submitting' });

  this.usersApi.create(command, crypto.randomUUID()).pipe(
    take(1)
  ).subscribe({
    next: result => {
      this.submitState.set({ kind: 'succeeded', userId: result.id });
      void this.router.navigate(['/users', result.id]);
    },
    error: error => this.submitState.set(mapSubmitError(error))
  });
}
```

The API still validates permissions, invariants, uniqueness, and idempotency. A client idempotency key is useful only when the server stores and enforces its semantics.

### Practice questions

1. Compare `value` and `getRawValue()` in Angular forms, and explain why neither is automatically a valid command.
2. How should an async username validator handle typing, cancellation, network failure, and server race conditions at final submission?
3. What belongs in a route guard, resolver, interceptor, facade, and API adapter?
4. Why is retrying every failed HTTP request in an interceptor unsafe? Which operations and statuses need special treatment?
5. Design an optimistic “favorite item” interaction that handles rapid toggles, server rejection, and responses arriving out of order.

### Detailed answer key

1. `value` normally excludes disabled controls while `getRawValue()` includes them. Both reflect UI state, not proof of authorization, correct units, canonical IDs, or business validity. Map explicitly to a command and let the server validate.
2. Debounce and `switchMap` to cancel obsolete checks; distinguish unavailable from “name taken”; never permanently block on a transient lookup. On submission, the server enforces a unique constraint/transaction because availability can change after the check. Map the resulting conflict back to the field.
3. A guard decides navigation UX based on current auth/state but is not security. A resolver obtains route-critical data when blocking navigation is justified. Interceptors handle transport-wide policy. Facades own feature state/commands. Adapters validate/map API contracts. Keep business-specific retries/errors outside a global interceptor.
4. Non-idempotent writes may repeat effects; 4xx validation/auth usually should not retry; overload responses need `Retry-After`; network timeout may leave commit outcome unknown; refresh-token retry needs single-flight/loop prevention. Retry only when operation semantics, budget, backoff/jitter, cancellation, and server idempotency support it.
5. Give each intent a sequence/operation ID, update local state immediately, send serialized/latest-intent requests, ignore stale responses, reconcile with canonical server state, and surface failure. For a boolean toggle, `switchMap` can cancel client observation but may not cancel a committed server write; version/precondition or idempotent “set favorite true/false” semantics are safer than “toggle.”

### Failure and production checks

- Test double submit, browser back/forward, route reuse, refresh, expired auth, validation conflicts, and unsaved-change navigation.
- Keep auth tokens/cookies and refresh behavior centralized with single-flight renewal and hard loop limits.
- Map transport, validation, conflict, authorization, rate-limit, dependency, and unknown errors to stable UI states.
- Preserve correlation/idempotency/precondition headers through client layers and expose them in diagnostics without secrets.
- Validate payload schemas and handle backward/forward-compatible optional fields deliberately.

### Build/debug task

Create a typed registration flow with sync and cancellable async validation, server conflict mapping, duplicate-submit protection, unsaved-change guard, correlation ID, and stable success navigation. Write tests that reorder availability and submission responses and prove server authorization is never inferred from the guard.

---

## 8. RxJS Streams, Flattening, Cancellation, Errors, and Sharing

### Concept map

- An observable is a lazy producer contract; each subscription may create independent work unless the source is shared.
- `switchMap` switches to the latest inner stream, `concatMap` queues in order, `mergeMap` runs concurrently, and `exhaustMap` ignores new triggers while one is active.
- Unsubscription requests teardown; whether external work truly stops depends on source implementation.
- Error terminates a stream unless caught. `catchError` placement decides whether one inner failure or the outer event stream dies.
- Hot/cold and unicast/multicast are related but distinct properties. Subjects are imperative bridges, not default state containers.
- Sharing/replay needs explicit reset, lifetime, cache, completion, and error semantics.

### Wrong/before example

```typescript
this.search.valueChanges.subscribe(query => {
  this.api.search(query).subscribe(results => {
    this.results = results;
  });
});
```

Nested subscriptions obscure teardown, race old/new results, and make loading/error handling fragmented. Component destruction may leave both subscriptions active.

### Correct/after example

```typescript
readonly searchState$ = this.search.valueChanges.pipe(
  map(value => value.trim()),
  debounceTime(250),
  distinctUntilChanged(),
  switchMap(query => query.length < 2
    ? of({ kind: 'idle' } as const)
    : this.api.search(query).pipe(
        map(results => ({ kind: 'success', results } as const)),
        startWith({ kind: 'loading' } as const),
        catchError(error => of({ kind: 'error', error: mapError(error) } as const))
      )
  ),
  shareReplay({ bufferSize: 1, refCount: true })
);
```

`switchMap` cancels the prior HTTP observable subscription; Angular's HTTP backend can abort the request, but a server may already have performed work. Never treat client cancellation as transaction rollback.

### Practice questions

1. Choose among `switchMap`, `concatMap`, `mergeMap`, and `exhaustMap` for typeahead, ordered saves, parallel image metadata, and login submit.
2. How does placing `catchError` inside versus outside a flattening operator change stream survival?
3. Compare `Subject`, `BehaviorSubject`, `ReplaySubject`, `AsyncSubject`, signals, and a store for UI state.
4. What are common `shareReplay` leak/stale-error surprises, and which reset/lifetime questions should be answered?
5. Why can `takeUntil(destroy$)` be incorrectly placed, and how do framework destruction helpers reduce—not eliminate—ownership mistakes?

### Detailed answer key

1. Typeahead uses `switchMap` because obsolete reads should stop updating. Ordered saves use `concatMap` if order matters. Independent bounded parallel metadata can use `mergeMap` with a concurrency limit. Login submit often uses `exhaustMap` to ignore double clicks while one attempt runs; if the latest should replace, semantics differ.
2. Inside the inner stream, one request becomes an error state/value and the outer event stream continues accepting future triggers. Outside, the first error terminates the entire composed stream unless replaced with another continuing source.
3. Subject has no current value; BehaviorSubject has one current seed; ReplaySubject replays N/time-window values; AsyncSubject emits the final value on completion. Signals fit synchronous Angular state/derivation. A store adds standardized state/effects/selectors/devtools for shared complex state. Choose ownership/replay/async/error needs; do not use subjects as mutable global variables by habit.
4. Replay can retain large or stale values and keep a source alive when lifetime is not deliberate. In the shown `shareReplay({ bufferSize: 1, refCount: true })`, reference counting addresses the active source subscription; it is not a freshness, logout, tenant-change, or completed-cache invalidation policy. Verify the installed RxJS version's reset behavior. When exact reset semantics matter, use `share` with an explicit replay connector/reset policy or implement deliberate cache invalidation.
5. With `source$.pipe(takeUntil(destroy$), switchMap(() => inner$))`, completion of the upstream does not necessarily tear down the active inner immediately; the higher-order operator can keep it alive until that inner completes. Put owner teardown after the higher-order composition (or use a correctly placed framework helper), and still ensure custom sources implement cleanup. Framework helpers tie teardown to an injection context but do not fix service-scope or shared-cache lifetime errors.

### Failure and production checks

- Marble/test-scheduler tests should cover ordering, cancellation, concurrency, debounce, retries, and error survival.
- Cap concurrency and buffering; observe queue growth/backpressure for fast producers and slow consumers.
- Distinguish retryable transport errors from validation/auth/unknown commit; use bounded exponential backoff with jitter and cancellation.
- Audit every share/replay for owner, reset, cache size, tenant/auth invalidation, and sensitive-value retention.
- Track request cancellation, retries, active subscriptions where useful, stale response prevention, and user-visible error states.

### Build/debug task

Implement four buttons/inputs demonstrating each flattening strategy against a controllable delayed API. Write deterministic scheduler tests that prove the expected ordering, ignored triggers, cancellation, concurrency cap, and that one request error does not kill future attempts.

---

## 9. NgRx State, Effects, Selectors, and Entity Modeling

### Concept map

- Store state should represent durable shared client state and explicit request status, not every local input or derivable value.
- Actions describe events/intents; reducers are pure state transitions; effects coordinate external work; selectors derive view state.
- Normalized entities avoid duplicated conflicting object copies. IDs plus entity maps support targeted immutable updates.
- Selectors are memoized by input identity; reducers must preserve unchanged references and avoid in-place mutation.
- Effects require concurrency semantics, failure actions, correlation, and loop prevention.
- Store lifetime, feature registration, logout/tenant reset, persistence, and router boundaries are correctness decisions.

### Wrong/before example

```typescript
export const loadOrders = createAction('[Orders] Load');

load$ = createEffect(() => this.actions$.pipe(
  ofType(loadOrders),
  mergeMap(() => this.api.getOrders().pipe(
    tap(orders => this.store.dispatch(setOrders({ orders })))
  ))
), { dispatch: false });

export const reducer = createReducer(initialState,
  on(setOrders, (state, { orders }) => {
    state.orders = orders; // mutation
    return state;
  })
);
```

Parallel duplicate loads race, the effect dispatches imperatively with no error action, and reducer mutation breaks immutability/memoization.

### Correct/after example

```typescript
export const OrdersActions = createActionGroup({
  source: 'Orders Page',
  events: {
    'Load Requested': props<{ requestId: string }>(),
    'Load Succeeded': props<{ requestId: string; orders: readonly Order[] }>(),
    'Load Failed': props<{ requestId: string; error: UiError }>()
  }
});

type OrdersLoadState = 'idle' | 'loading' | 'loaded' | 'error';

const initialState = adapter.getInitialState({
  activeRequestId: null as string | null,
  loadState: 'idle' as OrdersLoadState,
  error: null as UiError | null
});

load$ = createEffect(() => this.actions$.pipe(
  ofType(OrdersActions.loadRequested),
  switchMap(({ requestId }) => this.api.getOrders().pipe(
    map(orders => OrdersActions.loadSucceeded({ requestId, orders })),
    catchError(error => of(OrdersActions.loadFailed({
      requestId,
      error: mapError(error)
    })))
  ))
));

export const reducer = createReducer(initialState,
  on(OrdersActions.loadRequested, (state, { requestId }) => ({
    ...state,
    activeRequestId: requestId,
    loadState: 'loading',
    error: null
  })),
  on(OrdersActions.loadSucceeded, (state, { requestId, orders }) =>
    requestId !== state.activeRequestId
      ? state
      : adapter.setAll(orders, {
          ...state,
          activeRequestId: null,
          loadState: 'loaded',
          error: null
        })
  ),
  on(OrdersActions.loadFailed, (state, { requestId, error }) =>
    requestId !== state.activeRequestId
      ? state
      : { ...state, activeRequestId: null, loadState: 'error', error }
  )
);
```

This example defines refresh as “latest request wins” and the reducer enforces the correlation ID. If the product should ignore triggers while a load is active, use `exhaustMap` but do not advance state to an ID for a request the effect drops. A write queue might use `concatMap`; independent item loads may use bounded `mergeMap`.

### Practice questions

1. Which state belongs locally in a component/signal, in a feature facade/service, in URL/router state, or in the global store?
2. Why store IDs and normalized entities rather than duplicate nested objects across slices?
3. What makes a selector recompute, and how can projector allocation defeat downstream rendering optimization?
4. How should an effect handle duplicate load actions, stale responses, correlation, retry, and logout?
5. What is wrong with persisting the entire NgRx store to local storage and restoring it after every deployment?

### Detailed answer key

1. Local ephemeral presentation/input stays local. Feature-shared state with bounded lifetime can live in a route-scoped facade. Shareable/navigation-defining filters belong in the URL. Global store fits cross-feature durable client state with complex transitions/effects/debugging. Avoid globalizing state merely to avoid passing inputs.
2. One canonical entity avoids conflicting copies; relationships use IDs; updates preserve unrelated references and selectors join data. Denormalized view models should be derived. Some read-only snapshots can remain denormalized when update/join complexity does not justify normalization.
3. A selector runs when input selector references change; memoization usually remembers recent arguments. Returning a newly allocated array/object whenever inputs change can cause consumers to render even if semantic content is equal. Preserve reducer references, narrow inputs, compose selectors, and avoid expensive unrelated dependencies.
4. Select a flattening policy, include request/entity IDs, map errors to actions, ignore stale success by request/version where necessary, bound retries, cancel/reset on logout/tenant change, and avoid action cycles. Reducers should model request state explicitly.
5. State contains stale schemas, sensitive data, non-serializable values, expired auth, in-flight flags, and server-derived facts. Persist only explicitly versioned safe slices, validate/migrate/expire them, clear on logout/tenant change, and reconcile with the server.

### Failure and production checks

- Test reducers for immutability/reference preservation and selectors for projector behavior.
- Test effects with deterministic action/time streams, including overlap, cancellation, retry, failure, and logout.
- Reset tenant/user-scoped entities, caches, and errors when identity changes.
- Avoid secrets/tokens/PII in devtools, actions, persisted state, and telemetry.
- Monitor repeated action loops, effect failure, request duplication, entity growth, and long selector/render work.

### Build/debug task

Build a route-lazy Orders feature with entity adapter, URL-backed filters, request correlation, refresh/load concurrency, optimistic status update with rollback, and logout reset. Add reducer/selector/effect tests, then inspect the action timeline for a forced out-of-order response.

---

## 10. Frontend Design Patterns and State Ownership

### Concept map

- Patterns are named trade-offs for recurring forces; they are not mandatory folder structures.
- Container/presentational separation, facade, adapter/anti-corruption layer, repository/client, strategy, state machine, command, observer, and mediator patterns solve different ownership problems.
- The composition root chooses implementations and lifetimes; business/UI classes should not locate global services dynamically.
- State has an owner, source of truth, mutation commands, derivations, persistence/freshness policy, and cleanup boundary.
- A state machine is useful when allowed transitions matter; booleans multiply illegal combinations.
- Abstractions should follow stable variation. Premature “generic base components/services” often couple unrelated features.

### Wrong/before example

```typescript
export class BaseCrudComponent<T> {
  endpoint = '';
  items: T[] = [];
  selected?: T;
  loading = false;

  save(item: T) { /* knows HTTP, notifications, routing, forms */ }
  delete(item: T) { /* every feature overrides half of this */ }
}
```

Inheritance shares accidental workflow assumptions. Orders, users, and invoices may all have “CRUD” verbs but different permissions, transitions, validation, concurrency, audit, and failure semantics.

### Correct/after example

```typescript
export interface OrdersPort {
  load(query: OrdersQuery): Observable<readonly Order[]>;
  cancel(command: CancelOrder): Observable<Order>;
}

@Injectable()
export class OrdersFacade {
  private readonly port = inject(ORDERS_PORT);
  // Owns order-specific state transitions and exposes view-shaped state.
}

export const ORDERS_PORT = new InjectionToken<OrdersPort>('OrdersPort');

export const provideOrders = () => [
  OrdersFacade,
  { provide: ORDERS_PORT, useClass: HttpOrdersAdapter }
];
```

The port is application-shaped rather than a generic HTTP wrapper. A fake adapter can support focused tests; the real adapter maps the external API to the domain contract.

### Practice questions

1. When does a facade clarify a feature, and when does it become a pass-through layer that hides useful types?
2. Compare inheritance, composition, strategy, and configuration for reusable components/behavior.
3. How does an adapter protect the application from an external API, and what mapping/validation belongs there?
4. Turn `isLoading`, `hasError`, `hasData`, and `isSaving` booleans into state machines. What illegal combinations disappear?
5. How do you decide whether state belongs to URL, server, cache/store, feature service, component, form, or DOM/widget?

### Detailed answer key

1. A facade is valuable when it owns orchestration, state transitions, view-shaped selectors, commands, error policy, or framework isolation. It is noise when every method/property merely renames an underlying service/store and forces developers to jump files without establishing a boundary.
2. Inheritance couples lifecycle and protected internals; use only for a true substitutable “is-a” contract. Composition assembles small capabilities and is usually safer. Strategy injects a behavior that varies independently. Configuration handles data differences; too many callbacks/flags can become an implicit programming language. Prefer explicit feature components over a universal configurable component.
3. Validate untrusted DTOs, convert dates/money/IDs/status variants, translate errors, handle version compatibility, and expose an application-owned contract. This prevents transport/provider details spreading through templates and makes replacement/testing possible.
4. Model load as idle/loading/success/empty/error; save as idle/submitting/succeeded/conflict/error, or combine into a deliberate product state if operations interact. Illegal “loading + success + error” combinations become unrepresentable and transition handling becomes exhaustive.
5. Server owns authoritative shared business facts. URL owns bookmarkable navigation/filter state. A cache/store owns explicitly shared client projections. A feature service owns bounded workflow state. Component/form owns local interaction/edit state. DOM/widget owns transient imperative state only when not needed elsewhere. Choose one source and derive other representations.

### Failure and production checks

- Review each abstraction for the variation it isolates and the dependency direction it creates.
- Test adapters with contract fixtures and unknown/new enum fields; avoid leaking provider DTOs.
- Document state owner, lifetime, reset/logout behavior, persistence, freshness, and concurrency.
- Prefer explicit state transitions with logging/devtools for workflows involving retries, approval, upload, payment, or collaboration.
- Delete abstractions that have one implementation and no meaningful policy boundary if they only obscure behavior.

### Build/debug task

Choose an existing feature with component-owned HTTP/state. Refactor it into an application-shaped port, adapter, facade/state machine, and presentational components. Record which responsibilities moved, which abstraction you intentionally did not add, and how tests prove the same behavior during timeout, conflict, and cancellation.

---

## 11. Browser Security, Authentication, and Data Protection

### Concept map

- XSS is untrusted data becoming executable markup/script/URL/code. Context-sensitive output handling, safe DOM APIs, sanitization for allowed HTML, CSP, and Trusted Types form defense in depth.
- CSRF abuses ambient credentials such as cookies; SameSite plus anti-forgery tokens and origin checks are common controls.
- CORS controls whether browser JavaScript may read cross-origin responses and whether the browser proceeds with preflighted requests; simple cross-origin requests can still be sent. It is not authentication, CSRF protection, or a server-to-server firewall.
- OAuth/OIDC flows require state/nonce/PKCE, exact redirects, secure token handling, and server-side authorization.
- The browser is controlled by the user/attacker: guards, hidden buttons, environment variables, minification, and client validation do not protect server resources.
- Third-party scripts, dependencies, source maps, telemetry, storage, service workers, and postMessage widen the data/supply-chain boundary.

### Wrong/before example

```typescript
localStorage.setItem('access_token', token);
preview.innerHTML = userHtml;

window.addEventListener('message', event => {
  if (event.data.type === 'payment-complete') finishCheckout(event.data);
});
```

A successful XSS can steal the long-lived token, arbitrary HTML enters an injection sink, and any origin can forge the payment message.

### Correct/after example

```typescript
window.addEventListener('message', event => {
  if (event.origin !== 'https://payments.example.com') return;
  if (event.source !== paymentFrame.contentWindow) return;
  const message = paymentMessageSchema.safeParse(event.data);
  if (!message.success) return;
  reconcilePaymentWithServer(message.data.operationId);
});

// Render untrusted text as text.
preview.textContent = userText;
```

For same-site web applications, a secure HttpOnly SameSite cookie/BFF can reduce JavaScript token exposure, but cookie authentication needs CSRF controls. No browser storage choice makes XSS harmless.

### Practice questions

1. Distinguish stored, reflected, and DOM XSS, and explain why framework interpolation safety does not make every API safe.
2. When does CSRF apply, and how do SameSite cookies and anti-forgery tokens complement rather than replace server authorization?
3. What does CORS protect, what does a preflight do, and why does `Access-Control-Allow-Origin: *` not expose every authenticated cookie request?
4. Compare browser token storage, HttpOnly cookies/BFF, in-memory tokens, refresh rotation, and their threat trade-offs.
5. How should `postMessage`, third-party scripts, dependency updates, source maps, and frontend telemetry be secured?

### Detailed answer key

1. Stored payload persists on the server; reflected returns in a response; DOM XSS is created by client-side source-to-sink behavior. Template interpolation usually escapes text, but bypass/sanitizer trust APIs, `innerHTML`, URLs, styles, script construction, third-party widgets, and direct DOM operations have different contexts. Validate and use safe sinks.
2. CSRF matters when a browser automatically attaches authority (usually cookies/client certs) to a cross-site request. SameSite reduces cross-site attachment under defined navigation rules; anti-forgery binds a request to the legitimate app/session. The server must still authenticate and authorize the action and should validate origin/content types where appropriate.
3. CORS is a browser policy controlling cross-origin script access. A preflight asks whether a non-simple method/header/origin is allowed before the actual request, but a simple request can be sent even when its response is unreadable. A credentialed response cannot use `Access-Control-Allow-Origin: *`; it needs an allowed explicit origin and credential permission, while cookie attachment is also constrained by SameSite and browser third-party-cookie policy. Non-browser clients ignore CORS. The server still needs authentication, authorization, network controls, and CSRF defenses.
4. Local/session storage is script-readable and durable enough for theft via XSS. In-memory reduces persistence but is still script-accessible and complicates refresh. HttpOnly cookies hide token material from JavaScript but use ambient authority and need CSRF. A BFF can keep provider tokens server-side. Short lifetimes, audience/scope, rotation/reuse detection, revocation, and XSS prevention remain necessary.
5. Verify message origin, source, schema, nonce/operation, and recheck sensitive result with the server. Minimize and integrity/control third-party scripts, pin/audit dependencies, use CSP, protect publishing credentials, restrict production source-map access, and redact/filter telemetry. Never log tokens, authorization headers, full URLs with secrets, PII, or user content by default.

### Failure and production checks

- Run dependency/SAST checks plus manual source-to-sink and authorization reviews; scanners do not prove safety.
- Enforce CSP/reporting and Trusted Types where compatible; monitor violations before strict rollout.
- Test login callback state/nonce/PKCE, token expiry/refresh races, logout across tabs, revoked sessions, and tenant change.
- Use server-side object/tenant authorization for every resource; hide/disable UI only for experience.
- Maintain an inventory and incident-removal path for third-party scripts, packages, extensions, and service workers.

### Build/debug task

Threat-model a SPA or BFF login and checkout flow. Draw trust boundaries, token/cookie paths, redirects, CSRF/XSS controls, postMessage use, telemetry, and logout. Add tests for forged origin/message, expired/reused refresh, cross-tenant ID, malicious HTML, and duplicate payment completion.

---

## 12. Testing Strategy, Performance, and Observability

### Concept map

- Unit tests verify pure logic/state transitions; component tests verify rendered behavior; integration/contract tests verify boundaries; E2E tests cover a few critical journeys.
- Test outcomes and accessibility, not private implementation details or giant snapshots.
- Performance includes loading (LCP), responsiveness (INP), visual stability (CLS), resource/network cost, JavaScript execution, memory, and application-specific latency.
- Budgets and real-user monitoring complement lab profiling. Field distributions expose devices/networks that local development misses.
- Frontend observability joins release/session/route, errors, resource/API spans, user interactions, and backend correlation while protecting privacy.
- Source maps, sampling, grouping, release markers, and actionable ownership turn telemetry into diagnosis.

### Wrong/before example

```typescript
it('works', () => {
  const fixture = TestBed.createComponent(CheckoutComponent);
  fixture.detectChanges();
  expect(fixture.nativeElement.innerHTML).toMatchSnapshot();
});

window.onerror = (_, __, ___, ____, error) => {
  fetch('/telemetry', { method: 'POST', body: JSON.stringify(error) });
};
```

The snapshot may pass while checkout is unusable. Raw Error serialization loses useful fields, has no release/correlation/context, may leak data, and error reporting itself can loop/fail.

### Correct/after example

```typescript
it('prevents duplicate payment and recovers from a retryable timeout', async () => {
  api.charge.mockRejectedValueOnce(timeoutError)
            .mockResolvedValueOnce({ receiptId: 'r-1' });

  await renderCheckout();
  await user.click(screen.getByRole('button', { name: 'Pay ₹500' }));

  expect(screen.getByRole('button', { name: 'Pay ₹500' })).toBeDisabled();
  expect(await screen.findByRole('alert')).toHaveTextContent('Try again');
  expect(api.charge).toHaveBeenCalledTimes(1);

  await user.click(screen.getByRole('button', { name: 'Try again' }));
  expect(await screen.findByText(/receipt r-1/i)).toBeVisible();
  expect(api.charge.mock.calls[0][0].idempotencyKey)
    .toBe(api.charge.mock.calls[1][0].idempotencyKey);
});
```

### Practice questions

1. For a stateful Angular checkout, what belongs in unit, component, integration/contract, and E2E tests?
2. Why are role/name-based queries and user events more robust than CSS selectors and direct method calls?
3. Diagnose a page with good LCP but poor INP. Which traces/profiles and code patterns would you inspect?
4. How do bundle budgets, code splitting, preloading, image/font strategy, and caching interact?
5. Design privacy-safe frontend telemetry that connects a failed user action to the backend without logging sensitive form values.

### Detailed answer key

1. Unit-test totals, state machine, reducer/selectors, validation mapping. Component-test form interaction, accessible state, disabled/duplicate behavior. Integration/contract-test client/adapter schema, auth/correlation/idempotency, mock server failures. E2E-test one successful payment and a few high-risk recovery paths against a realistic stack. Do not duplicate every assertion at every layer.
2. They interact through the accessibility/user contract and survive DOM/CSS refactoring. Direct method calls bypass event, focus, change-detection, and disabled semantics. Implementation queries are sometimes appropriate for non-user infrastructure but should be intentional.
3. INP reflects interaction delay plus event processing and next paint. Inspect long tasks around interactions, main-thread flame chart, change detection, large synchronous reducers/selectors, layout thrashing, third-party code, hydration, and microtask chains. Break work, reduce render scope, defer noncritical tasks, virtualize, or move suitable CPU work to a worker.
4. Budgets catch growth. Split by route/feature, but too many chunks add requests and waterfalls. Preload likely next routes under network/device constraints. Optimize responsive image dimensions/formats and avoid font-blocking/layout shifts. Long-lived hashed assets can cache immutably; HTML/config needs safe revalidation. Measure actual navigation/user cohorts.
5. Generate a random session/trace correlation, include release, route template, operation name, error class/code, timing phases, and backend trace/request ID. Redact query strings/user text, hash or omit identity, sample, bound breadcrumbs, honor consent/retention/access, and make telemetry transport nonblocking/retry-bounded.

### Failure and production checks

- Run tests in CI with deterministic clocks/network and keep a small browser matrix for critical flows.
- Set JS/CSS/image/font and Core Web Vitals budgets; compare per route and release.
- Track uncaught errors, unhandled rejections, failed resources, API failures, long tasks, Web Vitals, and user journey success.
- Upload source maps to protected tooling and associate exact build/release; avoid publicly exposing source unnecessarily.
- Test telemetry failure, ad blockers, offline mode, sampling, deduplication, and PII redaction.

### Build/debug task

Choose one critical route. Add a layered test plan, bundle and Web Vitals budgets, user-timing marks, API correlation, release-aware error reporting, and a dashboard that can answer “which release, route, operation, and backend trace caused this failure?” Inject a long task and API timeout, then verify diagnosis.

---

## 13. API Integration and Production Failure Workbook

### Concept map

- A UI request is a distributed operation: DNS/TLS/network, gateway, auth, service, datastore, cache, and client state can fail independently.
- Timeouts, retries, cancellation, idempotency, pagination, concurrency control, rate limiting, and compatibility are product semantics.
- Loading is not one boolean. Initial load, background refresh, pagination, mutation, stale data, offline data, and partial failure need distinct UX.
- Offset pagination supports page numbers but drifts under writes and becomes expensive deep in a dataset; keyset/cursor pagination follows a stable unique order.
- ETags/version fields support optimistic concurrency; a conflict needs merge/reload/overwrite policy.
- Resilience includes degraded behavior, bounded queues, cached data with freshness, feature flags, rollout, and observability.

### Wrong/before example

```typescript
async function saveProfile(profile: Profile) {
  for (;;) {
    try {
      return await http.put('/api/profile', profile);
    } catch {
      // Retry forever immediately, including auth/validation/conflict errors.
    }
  }
}
```

This can create a retry storm, repeat an unknown-commit write, ignore cancellation and rate limits, keep stale edits overwriting newer data, and trap the UI forever.

### Correct/after example

```typescript
type SaveResult =
  | { kind: 'saved'; profile: Profile; version: string }
  | { kind: 'conflict'; server: Profile; serverVersion: string }
  | { kind: 'validation'; fields: Record<string, string> }
  | { kind: 'failed'; retryable: boolean; message: string };

function saveProfile(
  command: UpdateProfile,
  version: string,
  idempotencyKey: string
): Observable<SaveResult> {
  return http.put<unknown>('/api/profile', command, {
    headers: {
      'If-Match': version,
      'Idempotency-Key': idempotencyKey
    }
  }).pipe(
    retry({
      count: 2,
      delay: (error, retryCount) => {
        const delayMs = retryDelayMs(error, retryCount);
        return delayMs === null
          ? throwError(() => error)
          : timer(delayMs);
      }
    }),
    map(payload => {
      const saved = parseSavedProfile(payload);
      return {
        kind: 'saved',
        profile: saved.profile,
        version: saved.version
      } as const;
    }),
    catchError(error => of(mapProfileSaveError(error)))
  );
}
```

`retryDelayMs` returns `null` for non-retryable errors; otherwise it respects `Retry-After` and the retry budget and adds jitter. The callback returns an observable (`timer` or `throwError`), as RxJS requires. Parsing happens after `retry`, so a malformed success payload is not retried as though it were a transient transport failure. The caller must reuse the same idempotency key for retries of one logical save, and the server must enforce it; otherwise an unknown-commit write is not safe to replay.

### Practice questions

1. Page 1 loads, page 2 fails, and cached page 1 is five minutes old. Design the state and user actions without blanking useful content.
2. A user submits an order, the client times out, and the server may have committed. What should the client and server do next?
3. Two browser tabs edit the same profile. One saves, then the other receives `412 Precondition Failed`. Design recovery.
4. A release changes an enum and older clients do not know the new value. How should transport parsing and UI behavior respond?
5. A rate-limited endpoint returns `429` with `Retry-After`, while thousands of clients retry together. How do client jitter, UI, and server idempotency help?
6. An API is down but cached results exist. What determines whether stale data may be shown and how it must be labeled?

### Detailed answer key

1. Keep page 1 visible with an explicit stale timestamp if allowed. Model initial versus next-page error separately, provide retry for page 2, preserve the cursor, and avoid duplicate append. Background refresh can update page 1 without replacing it with a spinner. If freshness is safety-critical, stale content may be hidden instead—this is a product invariant.
2. The server accepts an idempotency key and stores request fingerprint/outcome atomically with the effect. The client retries/status-checks with the same key, never creates a new order blindly, and presents “checking status” rather than false failure. If no idempotency/status contract exists, escalate uncertainty instead of assuming rollback.
3. Send a version/ETag and reject stale writes. Show server and local changes, offer field-aware merge/reload or authorized overwrite with a new precondition, preserve the user's draft, and avoid last-write-wins silently. Track conflicts for product improvement.
4. Runtime parsing should map recognized values and preserve an `unknown` variant rather than crash or assert impossibility. Render a safe fallback, capture version/telemetry, and maintain tolerant-reader/additive rollout rules. Critical unknown states may block an unsafe action.
5. Respect server timing, add randomized jitter and bounded attempts, coordinate/single-flight shared requests, and show a countdown/manual retry. Idempotency prevents repeated writes. The server should enforce quota and load shedding; clients cannot repair insufficient capacity but should not synchronize a retry spike.
6. Data class, age/freshness SLO, authorization, source version, and risk determine use. Label stale/offline state and last update, disable actions requiring fresh truth, refresh when connectivity returns, and never serve another tenant/user's cache. Payments, permissions, inventory, or safety data may require fail-closed behavior.

### Failure and production checks

- Maintain a stable client error taxonomy and map every status/transport/parser failure to an owned UI state.
- Use deadlines, cancellation, bounded retry with jitter, idempotency, and concurrency preconditions deliberately per operation.
- Test old/new client-server combinations, unknown fields/enums, feature flags, canary rollback, and partial deployment.
- Track stale age, cache source, cursor/version/idempotency IDs, retries, conflicts, throttling, offline use, and journey success.
- Never expose raw internal errors, tokens, secrets, stack traces, or another tenant's cached data.

### Build/debug task

Build a paginated editable catalogue with cursor pagination, stale-while-revalidate cache, offline display, optimistic favorite updates, ETag-protected edits, idempotent create, rate-limit countdown, and a typed unknown-enum fallback. Use a fault-injection mock to delay, reorder, duplicate, throttle, conflict, corrupt, and disconnect requests; prove every scenario has a recoverable state.

---

## Cumulative Frontend Capstone

Build one production-shaped feature—for example order management, booking, or support tickets—and provide this evidence:

1. Semantic/accessibility audit and keyboard/screen-reader test notes.
2. Responsive/intrinsic layout with performance budgets.
3. Runtime-validated API adapter and explicit domain/state model.
4. Angular feature boundary with deliberate provider lifetime.
5. RxJS concurrency/cancellation tests and, if justified, NgRx entity/effect tests.
6. Threat model covering XSS, CSRF, auth, authorization, storage, postMessage, and dependencies.
7. Failure-injection matrix for timeout, unknown commit, conflict, throttle, offline, stale cache, malformed data, and rollback.
8. Component/integration/E2E tests plus release-aware observability and backend correlation.
9. Engineering note explaining trade-offs, rejected patterns, remaining risks, and the metric proving success.

**Completion standard:** You can explain the browser/framework mechanism, show the wrong design failing, implement the corrected design, inject a realistic failure, and use telemetry/tests to prove recovery. A working happy-path screen alone is not mastery.
