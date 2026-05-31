# 🔵 RxJS Interview Questions — Complete Guide

> **100+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Observables & Subscriptions](#1-observables--subscriptions)
2. [Subjects](#2-subjects)
3. [Creation Operators](#3-creation-operators)
4. [Transformation Operators](#4-transformation-operators)
5. [Filtering Operators](#5-filtering-operators)
6. [Combination Operators](#6-combination-operators)
7. [Error Handling](#7-error-handling)
8. [Multicasting & Sharing](#8-multicasting--sharing)
9. [Utility & Conditional Operators](#9-utility--conditional-operators)
10. [RxJS in Angular Patterns](#10-rxjs-in-angular-patterns)

---

## 1. Observables & Subscriptions

📚 **References:**
- [RxJS Official — Observable](https://rxjs.dev/guide/observable)
- [Angular In Depth — Cold vs Hot Observables](https://indepth.dev/posts/1159/rxjs-heads-up-pitfalls-to-be-aware-of)
- [RxJS — Subscription](https://rxjs.dev/guide/subscription)

---

### Q1. What is an Observable? How does it differ from a Promise? When would you choose each?

**Answer:** An Observable is a lazy, cancellable stream of zero or more values over time. A Promise is eager, non-cancellable, and resolves to exactly one value. Choose Observables when you need multiple values, cancellation, or composability with operators. Choose Promises for simple one-time async operations (e.g., `async/await` patterns where streams are overkill).

❌ **Wrong — treating Observable like a Promise:**
```typescript
// Observable does NOT execute until subscribed — this does nothing:
const data$ = this.http.get('/api/users');
// Forgot to subscribe — request never fires ❌
```

✅ **Correct:**
```typescript
this.http.get<User[]>('/api/users').subscribe({
  next: users => this.users = users,
  error: err => console.error(err),
  complete: () => console.log('done')
});
```

---

### Q2. How do you create an Observable from scratch using `new Observable()`?

**Answer:** You use the `Observable` constructor and pass a subscriber function. The subscriber receives an observer with `next`, `error`, and `complete` methods. Any cleanup logic (timers, event listeners) should be returned as a teardown function.

❌ **Wrong — no teardown, memory leak:**
```typescript
const tick$ = new Observable<number>(subscriber => {
  let count = 0;
  setInterval(() => subscriber.next(count++), 1000);
  // Missing return — interval keeps running after unsubscribe ❌
});
```

✅ **Correct:**
```typescript
const tick$ = new Observable<number>(subscriber => {
  let count = 0;
  const id = setInterval(() => subscriber.next(count++), 1000);
  return () => clearInterval(id); // teardown cleans up ✅
});
```

---

### Q3. What is the difference between `of`, `from`, and `fromEvent`?

**Answer:** `of(...values)` emits its arguments synchronously and completes. `from(iterable | promise | observable)` converts an existing data source into an Observable. `fromEvent(target, eventName)` creates an Observable from DOM or Node.js events and does NOT auto-complete — it runs until unsubscribed.

❌ **Wrong — using `of` with an array thinking it will iterate:**
```typescript
// of([1, 2, 3]) emits ONE value — the entire array ❌
of([1, 2, 3]).subscribe(v => console.log(v)); // logs [1,2,3]
```

✅ **Correct — use `from` to iterate:**
```typescript
from([1, 2, 3]).subscribe(v => console.log(v)); // logs 1, 2, 3 ✅

fromEvent(document, 'click')
  .pipe(takeUntil(this.destroy$))
  .subscribe(e => console.log('clicked', e));
```

---

### Q4. What are cold vs hot Observables? Give a real-world example of each.

**Answer:** A cold Observable starts producing values only when subscribed — each subscriber gets its own independent execution (e.g., `HttpClient.get()`). A hot Observable produces values regardless of subscribers — all subscribers share the same stream (e.g., mouse events, WebSockets, Subjects).

❌ **Wrong — assuming HTTP call is shared between subscribers:**
```typescript
const users$ = this.http.get('/api/users');
users$.subscribe(u => console.log('component A', u));
users$.subscribe(u => console.log('component B', u));
// Two HTTP requests fire! Cold observable executes twice ❌
```

✅ **Correct — share the cold observable to make it hot:**
```typescript
const users$ = this.http.get('/api/users').pipe(shareReplay(1));
users$.subscribe(u => console.log('component A', u));
users$.subscribe(u => console.log('component B', u));
// One HTTP request, result shared ✅
```

---

### Q5. What is lazy execution in RxJS and why does it matter?

**Answer:** Observables are lazy — the producer function does not run until `subscribe()` is called. This means you can define complex pipelines without side effects until you're ready. It also means multiple subscriptions trigger multiple executions unless you multicast.

❌ **Wrong — expecting Observable to auto-execute:**
```typescript
const log$ = new Observable(sub => {
  console.log('fetching data...');
  sub.next(42);
  sub.complete();
});
// Nothing logged yet — no subscribe ❌
```

✅ **Correct:**
```typescript
const log$ = new Observable(sub => {
  console.log('fetching data...'); // runs only on subscribe
  sub.next(42);
  sub.complete();
});
log$.subscribe(v => console.log(v)); // now it executes ✅
```

---

### Q6. How do you unsubscribe from an Observable? What happens if you don't?

**Answer:** Call `subscription.unsubscribe()` on the Subscription object returned by `subscribe()`. If you don't, you create memory leaks — the producer keeps running, the subscriber closure holds references, and in Angular components, callbacks may fire after the component is destroyed causing errors.

❌ **Wrong — never unsubscribing:**
```typescript
@Component({...})
export class MyComponent implements OnInit {
  ngOnInit() {
    interval(1000).subscribe(n => this.counter = n); // leaks after component destroy ❌
  }
}
```

✅ **Correct:**
```typescript
@Component({...})
export class MyComponent implements OnInit, OnDestroy {
  private sub!: Subscription;
  ngOnInit() {
    this.sub = interval(1000).subscribe(n => this.counter = n);
  }
  ngOnDestroy() {
    this.sub.unsubscribe(); // cleaned up ✅
  }
}
```

---

### Q7. How does `takeUntil` work, and why is it the preferred unsubscription pattern in Angular?

**Answer:** `takeUntil(notifier$)` completes the source Observable when `notifier$` emits. In Angular, a `Subject` named `destroy$` emits in `ngOnDestroy`, automatically completing all pipelines without tracking individual subscriptions. This scales well when a component has many subscriptions.

❌ **Wrong — managing multiple subscriptions manually:**
```typescript
private sub1: Subscription;
private sub2: Subscription;
ngOnDestroy() {
  this.sub1.unsubscribe();
  this.sub2.unsubscribe(); // easy to forget one ❌
}
```

✅ **Correct:**
```typescript
private destroy$ = new Subject<void>();

ngOnInit() {
  interval(1000).pipe(takeUntil(this.destroy$)).subscribe(...);
  fromEvent(document, 'click').pipe(takeUntil(this.destroy$)).subscribe(...);
}

ngOnDestroy() {
  this.destroy$.next();
  this.destroy$.complete(); // all streams auto-complete ✅
}
```

---

### Q8. What is the difference between `take(n)`, `takeWhile`, and `takeUntil`?

**Answer:** `take(n)` completes after emitting exactly `n` values. `takeWhile(predicate)` completes when the predicate returns false for an emitted value. `takeUntil(notifier$)` completes when another Observable emits. They each serve a different completion trigger scenario.

✅ **All three compared:**
```typescript
// take(3) — first 3 values only
interval(500).pipe(take(3)).subscribe(console.log); // 0, 1, 2

// takeWhile — keep while condition holds
interval(500).pipe(
  takeWhile(n => n < 3)
).subscribe(console.log); // 0, 1, 2

// takeUntil — stop when stop$ emits
const stop$ = new Subject<void>();
interval(500).pipe(takeUntil(stop$)).subscribe(console.log);
setTimeout(() => stop$.next(), 1600); // stops after ~1.5s
```

---

### Q9. What is a Subscription? Can you add child subscriptions to a parent?

**Answer:** A `Subscription` is an object representing the ongoing execution of an Observable. It has an `unsubscribe()` method to stop the execution. You can add child subscriptions with `parent.add(child)`, so calling `parent.unsubscribe()` also unsubscribes all added children.

✅ **Correct:**
```typescript
const parent = new Subscription();

const child1 = interval(1000).subscribe(console.log);
const child2 = fromEvent(document, 'click').subscribe(console.log);

parent.add(child1);
parent.add(child2);

// Unsubscribing parent cleans up everything ✅
parent.unsubscribe();
```

---

### Q10. What does `interval` vs `timer` do? How are they different?

**Answer:** `interval(period)` emits an incrementing integer every `period` milliseconds, starting after the first period. `timer(delay, period?)` emits after an initial `delay`, and optionally continues emitting every `period` after that. `timer(0)` is commonly used to emit once immediately.

❌ **Wrong — using interval when you need an immediate first value:**
```typescript
interval(1000).subscribe(console.log);
// First value arrives after 1 second — not immediate ❌
```

✅ **Correct — use timer for immediate + periodic:**
```typescript
timer(0, 1000).subscribe(console.log);
// Emits 0 immediately, then 1, 2, 3... every second ✅

// One-shot after 3s:
timer(3000).subscribe(() => console.log('fired once'));
```

---

## 2. Subjects

📚 **References:**
- [RxJS Official — Subject](https://rxjs.dev/guide/subject)
- [Angular In Depth — BehaviorSubject as State Store](https://indepth.dev/posts/1426/behaviorsubject-the-easy-solution-to-state-management)
- [RxJS — ReplaySubject](https://rxjs.dev/api/index/class/ReplaySubject)

---

### Q11. What is a Subject and how does it differ from a plain Observable?

**Answer:** A Subject is both an Observable and an Observer — it can emit values via `next()` and can be subscribed to. Unlike a cold Observable, a Subject is hot: all subscribers share the same execution. Values emitted before a new subscriber subscribes are missed.

❌ **Wrong — expecting late subscriber to get past values:**
```typescript
const subject = new Subject<number>();
subject.next(1); // emitted before subscribe
subject.subscribe(v => console.log(v)); // misses 1 ❌
subject.next(2); // sees 2
```

✅ **Correct — use BehaviorSubject if late subscribers need current value:**
```typescript
const subject = new BehaviorSubject<number>(0);
subject.next(1);
subject.subscribe(v => console.log(v)); // gets 1 (current value) ✅
subject.next(2); // gets 2
```

---

### Q12. What is a BehaviorSubject? When do you use it?

**Answer:** A `BehaviorSubject` stores the latest emitted value and immediately replays it to new subscribers. It requires an initial value at creation. It is the go-to choice for representing state in services — always having a current value available synchronously via `.getValue()`.

❌ **Wrong — using plain Subject for state that new subscribers need:**
```typescript
const isLoggedIn$ = new Subject<boolean>(); // new subscribers miss current auth state ❌
isLoggedIn$.next(true);
// Component subscribes later — gets nothing until next emit
```

✅ **Correct:**
```typescript
const isLoggedIn$ = new BehaviorSubject<boolean>(false);
isLoggedIn$.next(true);
// Late subscriber immediately gets `true` ✅
console.log(isLoggedIn$.getValue()); // synchronous access ✅
```

---

### Q13. What is a ReplaySubject? How does its buffer work?

**Answer:** A `ReplaySubject(bufferSize, windowTime?)` replays the last `bufferSize` values to every new subscriber. Optionally, `windowTime` discards values older than the given milliseconds. Use it when late subscribers need historical values, not just the latest one.

✅ **Correct:**
```typescript
const replay$ = new ReplaySubject<number>(3); // buffer last 3
replay$.next(1);
replay$.next(2);
replay$.next(3);
replay$.next(4);

replay$.subscribe(v => console.log(v)); // gets 2, 3, 4 — oldest dropped ✅

// With time window:
const timed$ = new ReplaySubject<number>(100, 500); // last 500ms
```

---

### Q14. What is an AsyncSubject? When does it emit?

**Answer:** An `AsyncSubject` only emits the LAST value and only when the source completes. If the source errors before completing, subscribers get the error. It behaves similarly to a Promise — you get the resolved value only once done.

✅ **Correct:**
```typescript
const async$ = new AsyncSubject<number>();
async$.next(1);
async$.next(2);
async$.next(3);
async$.subscribe(v => console.log(v)); // nothing yet

async$.complete(); // NOW emits 3 ✅
```

---

### Q15. How do you use BehaviorSubject as a simple state store in Angular?

**Answer:** Expose the Subject as a read-only Observable with `.asObservable()` to prevent external callers from calling `.next()`. Keep mutation logic in service methods. Components observe the state stream and react to changes.

❌ **Wrong — exposing the Subject directly:**
```typescript
@Injectable({ providedIn: 'root' })
export class UserService {
  userState$ = new BehaviorSubject<User | null>(null); // external code can call .next() ❌
}
```

✅ **Correct:**
```typescript
@Injectable({ providedIn: 'root' })
export class UserService {
  private _user$ = new BehaviorSubject<User | null>(null);
  readonly user$ = this._user$.asObservable(); // read-only ✅

  setUser(user: User) { this._user$.next(user); }
  clearUser() { this._user$.next(null); }
}
```

---

### Q16. How can you share state across multiple Angular components using a Subject?

**Answer:** Place a `BehaviorSubject` in a singleton service (`providedIn: 'root'`). Components inject the service and subscribe to the observable. When one component updates the state via a service method, all other components reacting to the stream automatically update.

✅ **Correct:**
```typescript
// cart.service.ts
@Injectable({ providedIn: 'root' })
export class CartService {
  private items$ = new BehaviorSubject<CartItem[]>([]);
  cart$ = this.items$.asObservable();

  addItem(item: CartItem) {
    this.items$.next([...this.items$.getValue(), item]);
  }
}

// In any component:
cart$ = inject(CartService).cart$; // reactive, always in sync ✅
```

---

### Q17. What is the danger of calling `subject.complete()` prematurely?

**Answer:** Once a Subject completes, it will never emit again — all future `next()` calls are ignored, and new subscribers immediately receive the complete notification. This can silently break state management if you complete a shared Subject too early.

❌ **Wrong:**
```typescript
const state$ = new BehaviorSubject<number>(0);
state$.complete();
state$.next(1); // silently ignored ❌
state$.subscribe(v => console.log(v)); // immediately completes, no value ❌
```

✅ **Correct — only complete destroy subjects:**
```typescript
// Complete only the takeUntil notifier, not the state subject:
this.destroy$.next();
this.destroy$.complete(); // safe — it's only used for teardown ✅
```

---

### Q18. What is the multicast behavior of Subjects? How many times does a side effect run?

**Answer:** All subscribers to a Subject share the same execution — the side effect in the producer runs once, and the value is multicasted. This contrasts with cold Observables where each subscriber triggers its own producer execution.

✅ **Correct:**
```typescript
const subject = new Subject<number>();

subject.subscribe(v => console.log('Sub A:', v));
subject.subscribe(v => console.log('Sub B:', v));

subject.next(42);
// Sub A: 42
// Sub B: 42
// Side effect (producing 42) happened only ONCE ✅
```

---

### Q19. How do you convert a Subject into a read-only Observable?

**Answer:** Call `.asObservable()` on the Subject. This returns an Observable that forwards emissions but does not expose `next()`, `error()`, or `complete()`, preventing external misuse of the Subject.

✅ **Correct:**
```typescript
class EventBus {
  private _event$ = new Subject<AppEvent>();
  readonly event$ = this._event$.asObservable(); // consumers can only listen ✅

  emit(event: AppEvent) {
    this._event$.next(event);
  }
}
```

---

### Q20. When would you choose ReplaySubject over BehaviorSubject?

**Answer:** Use `ReplaySubject` when late subscribers need more than just the latest value — for example, a chat history where new subscribers should see the last N messages, or an audit trail of recent state changes. Use `BehaviorSubject` when only the current value matters.

✅ **Correct:**
```typescript
// Chat room — replay last 50 messages to new joiners:
const messages$ = new ReplaySubject<Message>(50);

// Auth state — only current login status matters:
const isLoggedIn$ = new BehaviorSubject<boolean>(false);
```

---

## 3. Creation Operators

📚 **References:**
- [RxJS Official — Creation Operators](https://rxjs.dev/guide/operators#creation-operators-1)
- [RxJS — forkJoin](https://rxjs.dev/api/index/function/forkJoin)
- [RxJS — combineLatest](https://rxjs.dev/api/index/function/combineLatest)

---

### Q21. What does `defer` do and when should you use it?

**Answer:** `defer(factory)` delays the creation of an Observable until subscription time, calling the factory function for each subscriber. Use it when the Observable factory has side effects or depends on runtime values that might change between creation and subscription.

❌ **Wrong — Observable captures stale value at creation time:**
```typescript
let url = '/api/v1/users';
const data$ = this.http.get(url); // url captured now ❌
url = '/api/v2/users'; // too late — data$ still uses v1
```

✅ **Correct:**
```typescript
let url = '/api/v1/users';
const data$ = defer(() => this.http.get(url)); // url read at subscribe time ✅
url = '/api/v2/users';
data$.subscribe(...); // uses v2 ✅
```

---

### Q22. What is `iif` and how does it differ from `defer` with a conditional?

**Answer:** `iif(condition, trueObservable, falseObservable)` is a declarative conditional that evaluates the condition at subscribe time and subscribes to the matching Observable. It is syntactic sugar over `defer(() => condition() ? true$ : false$)`.

✅ **Correct:**
```typescript
const isAdmin$ = iif(
  () => this.authService.isAdmin(),
  this.http.get('/api/admin-data'),
  this.http.get('/api/user-data')
);

isAdmin$.subscribe(data => console.log(data)); // fetches based on role at subscribe time ✅
```

---

### Q23. What is the difference between `merge`, `concat`, `zip`, and `race`?

**Answer:** `merge` subscribes to all source Observables simultaneously and emits from whichever emits. `concat` subscribes to them sequentially — next only starts when previous completes. `zip` pairs emissions by index, emitting only when all sources have emitted for that index. `race` subscribes to all and uses only the first one to emit, cancelling the rest.

✅ **Correct:**
```typescript
// merge — interleaved
merge(of('A'), of('B')).subscribe(console.log); // A, B (order not guaranteed)

// concat — sequential
concat(of(1, 2), of(3, 4)).subscribe(console.log); // 1, 2, 3, 4

// zip — paired by index
zip(of(1, 2), of('a', 'b')).subscribe(console.log); // [1,'a'], [2,'b']

// race — fastest wins
race(timer(100), timer(200)).subscribe(() => console.log('first'));
```

---

### Q24. When do you use `forkJoin` vs `combineLatest`?

**Answer:** `forkJoin` waits for ALL source Observables to complete and emits a single array of their last values. It is best for parallel HTTP requests. `combineLatest` emits whenever ANY source emits (after all have emitted at least once) and continues indefinitely. Use `combineLatest` for reactive streams, `forkJoin` for one-shot parallel async operations.

❌ **Wrong — using forkJoin with infinite streams:**
```typescript
forkJoin([interval(1000), of(1)]).subscribe(console.log);
// Never emits because interval never completes ❌
```

✅ **Correct:**
```typescript
// forkJoin — parallel HTTP
forkJoin([
  this.http.get('/api/users'),
  this.http.get('/api/roles')
]).subscribe(([users, roles]) => { /* both done */ }); // ✅

// combineLatest — reactive UI state
combineLatest([this.filter$, this.sort$]).subscribe(
  ([filter, sort]) => this.applyFilterAndSort(filter, sort)
); // ✅
```

---

### Q25. What does `range(start, count)` do?

**Answer:** `range(start, count)` synchronously emits integers from `start` up to `start + count - 1`, then completes. It is useful for generating sequences without arrays.

✅ **Correct:**
```typescript
range(1, 5).subscribe(console.log); // 1, 2, 3, 4, 5

// Combine with operators:
range(1, 10).pipe(
  filter(n => n % 2 === 0),
  map(n => n * n)
).subscribe(console.log); // 4, 16, 36, 64, 100
```

---

### Q26. What is `ajax` from RxJS and when would you prefer it over Angular's HttpClient?

**Answer:** `ajax` from `rxjs/ajax` creates an Observable-based HTTP request without any Angular dependencies. It is useful in pure RxJS/non-Angular contexts (Node.js, Vanilla JS). In Angular, `HttpClient` is preferred because it integrates with interceptors, `HttpClientTestingModule`, and type safety.

✅ **Correct (non-Angular):**
```typescript
import { ajax } from 'rxjs/ajax';

ajax.getJSON('https://api.example.com/users').subscribe(users => console.log(users));

// With full config:
ajax({
  url: '/api/data',
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: { key: 'value' }
}).subscribe(res => console.log(res.response));
```

---

### Q27. How does `generate` work in RxJS?

**Answer:** `generate(initialState, condition, iterate, resultSelector?)` works like a for-loop converted into an Observable, emitting values as long as `condition` returns true, advancing state with `iterate`. It is useful for complex iterative sequences.

✅ **Correct:**
```typescript
// Generate Fibonacci-like sequence:
generate(
  [0, 1],                          // initial: [prev, curr]
  ([, curr]) => curr < 100,        // condition
  ([prev, curr]) => [curr, prev + curr], // iterate
  ([, curr]) => curr               // result selector
).subscribe(console.log); // 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
```

---

### Q28. How do you use `EMPTY` and `NEVER`? What are their use cases?

**Answer:** `EMPTY` is an Observable that completes immediately without emitting any values. `NEVER` is an Observable that never emits and never completes. Use `EMPTY` as a no-op fallback in error handling or conditional streams. Use `NEVER` in tests or to represent a permanently idle stream.

✅ **Correct:**
```typescript
import { EMPTY, NEVER } from 'rxjs';

// EMPTY as error fallback — swallow error gracefully:
this.http.get('/api').pipe(
  catchError(() => EMPTY) // no value, just completes ✅
).subscribe();

// NEVER in tests — mock a stream that never completes:
const mockHttp = { get: () => NEVER };
```

---

### Q29. How do you create an Observable from a DOM event using `fromEvent`?

**Answer:** `fromEvent(target, eventName)` creates an Observable that emits every time the event fires. It works with DOM elements, Node.js EventEmitters, and objects implementing `addEventListener`/`removeEventListener`. The Observable is hot and never auto-completes.

✅ **Correct:**
```typescript
const clicks$ = fromEvent<MouseEvent>(document, 'click');
const keypresses$ = fromEvent<KeyboardEvent>(document, 'keydown');

clicks$.pipe(
  map(e => ({ x: e.clientX, y: e.clientY })),
  takeUntil(this.destroy$)
).subscribe(pos => console.log('clicked at', pos));
```

---

### Q30. How does `throwError` work, and when should you use it in a pipeline?

**Answer:** `throwError(() => new Error('message'))` creates an Observable that immediately errors without emitting any values. Use it inside `catchError` or `switchMap` to propagate an error conditionally, or in tests to simulate error scenarios.

✅ **Correct:**
```typescript
import { throwError } from 'rxjs';

// Conditional error re-throw:
this.http.get('/api').pipe(
  switchMap(response => {
    if (!response) return throwError(() => new Error('Empty response'));
    return of(response);
  }),
  catchError(err => {
    console.error(err);
    return EMPTY; // graceful fallback
  })
).subscribe();
```

---

## 4. Transformation Operators

📚 **References:**
- [RxJS Official — Operators](https://rxjs.dev/guide/operators)
- [Angular In Depth — switchMap vs mergeMap vs concatMap](https://indepth.dev/posts/1368/rxjs-understanding-the-publish-and-share-operators)
- [RxJS — exhaustMap](https://rxjs.dev/api/operators/exhaustMap)

---

### Q31. What is `switchMap` and when should you use it?

**Answer:** `switchMap` maps each source value to an inner Observable and cancels the previous inner Observable when a new source value arrives. Use it when only the latest inner result matters — e.g., autocomplete search where old results should be discarded when the user keeps typing.

❌ **Wrong — using mergeMap for search (old results arrive out of order):**
```typescript
searchInput$.pipe(
  mergeMap(query => this.http.get(`/api/search?q=${query}`))
).subscribe(results => this.results = results);
// Old slow request may arrive AFTER newer fast one ❌
```

✅ **Correct:**
```typescript
searchInput$.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap(query => this.http.get(`/api/search?q=${query}`))
).subscribe(results => this.results = results); // only latest matters ✅
```

---

### Q32. What is `mergeMap` (flatMap)? When do you use it instead of switchMap?

**Answer:** `mergeMap` maps each source value to an inner Observable and subscribes to all of them concurrently without cancelling any. Use it when all inner Observables must complete — e.g., uploading multiple files simultaneously where each upload must finish.

✅ **Correct:**
```typescript
// Upload all files concurrently — none should be cancelled:
from(files).pipe(
  mergeMap(file => this.uploadService.upload(file))
).subscribe(result => console.log('uploaded:', result)); // ✅

// With concurrency limit (max 3 at once):
from(files).pipe(
  mergeMap(file => this.uploadService.upload(file), 3)
).subscribe();
```

---

### Q33. What is `concatMap`? When is sequential processing critical?

**Answer:** `concatMap` maps each value to an inner Observable but subscribes to them ONE AT A TIME, waiting for each to complete before starting the next. Use it when order matters — e.g., sequential API calls where call N depends on the result of call N-1, or processing a queue in order.

✅ **Correct:**
```typescript
// Process items in strict order:
const queue$ = from([item1, item2, item3]);
queue$.pipe(
  concatMap(item => this.processItem(item)) // item2 waits for item1 ✅
).subscribe();

// Sequential dependent calls:
of(userId).pipe(
  concatMap(id => this.http.get(`/api/users/${id}`)),
  concatMap(user => this.http.get(`/api/orders/${user.id}`))
).subscribe();
```

---

### Q34. What is `exhaustMap`? What is its key use case?

**Answer:** `exhaustMap` maps the source to an inner Observable but IGNORES new source values while the current inner Observable is still active. Use it for scenarios where you want to prevent duplicate triggers — e.g., a submit button that should ignore repeated clicks while the first submission is in-flight.

❌ **Wrong — using switchMap for form submit (cancels in-flight requests):**
```typescript
submitBtn$.pipe(
  switchMap(() => this.http.post('/api/submit', this.form.value))
).subscribe(); // cancels in-flight request if button clicked again ❌
```

✅ **Correct:**
```typescript
fromEvent(submitBtn, 'click').pipe(
  exhaustMap(() => this.http.post('/api/submit', this.form.value))
).subscribe(response => console.log('submitted', response)); // ignores extra clicks ✅
```

---

### Q35. What is the key difference matrix between switchMap, mergeMap, concatMap, and exhaustMap?

**Answer:** The four higher-order mapping operators differ in how they handle new source emissions while an inner Observable is active.

✅ **Summary table:**
```
Operator      | New emission while inner active | Order preserved?
--------------|----------------------------------|------------------
switchMap     | Cancels previous inner           | No (latest wins)
mergeMap      | Subscribes concurrently          | No
concatMap     | Queues (waits for current)       | Yes
exhaustMap    | Ignores new emission             | N/A (first wins)

Use case:
switchMap  → autocomplete, route-based data loading
mergeMap   → parallel file uploads, independent requests
concatMap  → ordered queue, sequential API chains
exhaustMap → form submit, login button, one-at-a-time actions
```

---

### Q36. How does `scan` differ from `reduce`?

**Answer:** `scan` emits the accumulated value after EACH emission (like Array.reduce but streaming). `reduce` only emits the final accumulated value after the source completes. Use `scan` for running totals or incremental state, `reduce` for final aggregations.

✅ **Correct:**
```typescript
// scan — running total (emits 1, 3, 6, 10)
of(1, 2, 3, 4).pipe(
  scan((acc, val) => acc + val, 0)
).subscribe(console.log);

// reduce — final total only (emits 10)
of(1, 2, 3, 4).pipe(
  reduce((acc, val) => acc + val, 0)
).subscribe(console.log);

// scan for state management:
actions$.pipe(
  scan((state, action) => reducer(state, action), initialState)
).subscribe(state => this.state = state);
```

---

### Q37. What does `map` do? How does it compare to `switchMap`?

**Answer:** `map` synchronously transforms each emitted value to another value — it never subscribes to anything. `switchMap` is for when the transformation returns an Observable that needs to be subscribed to. Confusing the two causes either missing subscriptions or unexpected concatentation.

❌ **Wrong — using map with a function that returns an Observable:**
```typescript
search$.pipe(
  map(query => this.http.get(`/api?q=${query}`)) // returns Observable<Observable<Data>> ❌
).subscribe(v => console.log(v)); // v is an Observable, not data!
```

✅ **Correct:**
```typescript
search$.pipe(
  switchMap(query => this.http.get(`/api?q=${query}`)) // flattens ✅
).subscribe(data => console.log(data));
```

---

### Q38. How do `buffer` and `bufferTime` work?

**Answer:** `buffer(closing$)` collects source values into an array and emits the array when `closing$` emits. `bufferTime(timeSpan)` emits a buffered array every `timeSpan` milliseconds. Use them for batching events before processing.

✅ **Correct:**
```typescript
// bufferTime — batch click events every 500ms
fromEvent(document, 'click').pipe(
  bufferTime(500),
  filter(clicks => clicks.length > 0)
).subscribe(clicks => console.log(`${clicks.length} clicks in 500ms`));

// buffer — collect until signal
const flush$ = interval(2000);
fromEvent(document, 'mousemove').pipe(
  buffer(flush$)
).subscribe(events => console.log('batch of events:', events.length));
```

---

### Q39. How does `groupBy` work in RxJS?

**Answer:** `groupBy(keySelector)` splits a source Observable into multiple grouped Observables keyed by the result of `keySelector`. Each group is itself an Observable. You typically follow it with `mergeMap` to process each group's stream.

✅ **Correct:**
```typescript
from([
  { name: 'Alice', dept: 'Eng' },
  { name: 'Bob', dept: 'HR' },
  { name: 'Carol', dept: 'Eng' }
]).pipe(
  groupBy(person => person.dept),
  mergeMap(group$ => group$.pipe(
    toArray(),
    map(members => ({ dept: group$.key, members }))
  ))
).subscribe(console.log);
// { dept: 'Eng', members: [Alice, Carol] }
// { dept: 'HR', members: [Bob] }
```

---

### Q40. What is `mapTo` and why was `pluck` deprecated?

**Answer:** `mapTo(value)` maps every emission to the same constant value (deprecated in RxJS 7, removed in 8 — use `map(() => value)` instead). `pluck` was deprecated because `map` with optional chaining (`map(obj => obj?.key)`) is clearer and type-safe.

✅ **Modern equivalents:**
```typescript
// Instead of mapTo:
clicks$.pipe(map(() => 'clicked')).subscribe(console.log); // ✅

// Instead of pluck('name'):
users$.pipe(map(user => user?.name)).subscribe(console.log); // ✅

// Instead of pluck('address', 'city'):
users$.pipe(map(u => u?.address?.city)).subscribe(console.log); // ✅
```

---

## 5. Filtering Operators

📚 **References:**
- [RxJS Official — Filtering](https://rxjs.dev/guide/operators#filtering-operators)
- [RxJS — distinctUntilChanged](https://rxjs.dev/api/operators/distinctUntilChanged)
- [RxJS — debounceTime vs throttleTime](https://rxjs.dev/api/operators/debounceTime)

---

### Q41. What does `distinctUntilChanged` do? How is it different from `distinct`?

**Answer:** `distinctUntilChanged` suppresses emissions that are the same as the PREVIOUS emission. `distinct` suppresses emissions seen ANYWHERE before. Use `distinctUntilChanged` for inputs/streams where consecutive duplicates are noise. Avoid `distinct` on infinite streams — it accumulates all seen values in memory.

❌ **Wrong — using distinct on an infinite stream:**
```typescript
someStream$.pipe(distinct()).subscribe(); // memory grows unboundedly ❌
```

✅ **Correct:**
```typescript
// Search input — don't re-search if query didn't change:
searchInput$.pipe(
  distinctUntilChanged()
).subscribe(query => this.search(query)); // ✅

// Custom comparator:
users$.pipe(
  distinctUntilChanged((prev, curr) => prev.id === curr.id)
).subscribe();
```

---

### Q42. What is `distinctUntilKeyChanged`?

**Answer:** `distinctUntilKeyChanged(key)` is a shorthand for `distinctUntilChanged((prev, curr) => prev[key] === curr[key])`. It suppresses consecutive emissions where a specific property hasn't changed.

✅ **Correct:**
```typescript
users$.pipe(
  distinctUntilKeyChanged('id') // only re-emit if user id changes ✅
).subscribe(user => this.loadUserProfile(user));
```

---

### Q43. What is the difference between `debounceTime` and `throttleTime`?

**Answer:** `debounceTime(ms)` waits for a pause of `ms` milliseconds after the last emission before emitting. It is used to "wait until the user stops typing." `throttleTime(ms)` emits the first value then ignores subsequent values for `ms` milliseconds. It limits rate but emits immediately.

✅ **Correct:**
```typescript
// debounceTime — emit after typing stops:
searchInput$.pipe(
  debounceTime(400),
  switchMap(q => this.search(q))
).subscribe();

// throttleTime — emit on scroll but not more than once per 200ms:
fromEvent(window, 'scroll').pipe(
  throttleTime(200)
).subscribe(() => this.checkScrollPosition());
```

---

### Q44. What does `auditTime` do? How does it differ from `debounceTime` and `throttleTime`?

**Answer:** `auditTime(ms)` ignores values for `ms` milliseconds and then emits the LAST value received during that window. Unlike `debounceTime` (which resets on each emission), `auditTime` uses a fixed window and always emits the most recent value at the end.

✅ **Correct:**
```typescript
// Mouse position — update UI at most every 100ms, always with latest position:
fromEvent<MouseEvent>(document, 'mousemove').pipe(
  auditTime(100),
  map(e => ({ x: e.clientX, y: e.clientY }))
).subscribe(pos => this.updateCursor(pos)); // ✅
```

---

### Q45. How do `skip`, `skipUntil`, and `skipWhile` work?

**Answer:** `skip(n)` ignores the first `n` emissions. `skipUntil(notifier$)` ignores all emissions until `notifier$` emits. `skipWhile(predicate)` ignores emissions while the predicate returns true, then passes all remaining through (even if predicate would return true again).

✅ **Correct:**
```typescript
// skip(2) — ignore first two:
of(1, 2, 3, 4).pipe(skip(2)).subscribe(console.log); // 3, 4

// skipUntil — ignore until event:
interval(500).pipe(
  skipUntil(fromEvent(document, 'click'))
).subscribe(console.log); // starts counting after first click

// skipWhile — skip while loading:
data$.pipe(
  skipWhile(d => d === null)
).subscribe(data => this.render(data));
```

---

### Q46. What is the difference between `first` and `take(1)`?

**Answer:** `take(1)` completes after the first emission, but does not error if the source completes without emitting. `first(predicate?)` also takes the first matching value, but throws an `EmptyError` if the source completes without emitting. Use `first` when you expect a value and want an error if absent.

✅ **Correct:**
```typescript
// take(1) — safe, no error if empty:
EMPTY.pipe(take(1)).subscribe({ complete: () => console.log('done') }); // no error

// first() — errors on empty:
EMPTY.pipe(first()).subscribe({ error: e => console.error(e) }); // EmptyError ✅

// first with predicate:
numbers$.pipe(
  first(n => n > 10)
).subscribe(console.log); // first number greater than 10
```

---

### Q47. How does `filter` work in RxJS?

**Answer:** `filter(predicate)` passes emissions downstream only when the predicate returns true. It works exactly like `Array.filter` but on a stream. Combined with TypeScript type guards, it can also narrow the type of the emitted values.

✅ **Correct:**
```typescript
// Basic filter:
from([1, 2, 3, 4, 5]).pipe(
  filter(n => n % 2 === 0)
).subscribe(console.log); // 2, 4

// Type guard narrowing:
events$.pipe(
  filter((e): e is ClickEvent => e.type === 'click')
).subscribe(clickEvent => clickEvent.target); // typed as ClickEvent ✅
```

---

### Q48. What is `sampleTime` and when is it useful?

**Answer:** `sampleTime(ms)` emits the most recently emitted value from the source every `ms` milliseconds, regardless of how many emissions occurred between samples. Use it for polling or throttling rapidly updating values like real-time metrics.

✅ **Correct:**
```typescript
// Sample temperature sensor every 1 second:
temperatureSensor$.pipe(
  sampleTime(1000)
).subscribe(temp => this.updateDisplay(temp)); // shows latest each second ✅
```

---

### Q49. What does `elementAt` do?

**Answer:** `elementAt(index)` emits only the value at the given zero-based index and then completes. If the source completes before reaching that index, it errors with `ArgumentOutOfRangeError` unless a default value is provided.

✅ **Correct:**
```typescript
from([10, 20, 30, 40]).pipe(
  elementAt(2)
).subscribe(console.log); // 30

// With default:
from([10, 20]).pipe(
  elementAt(5, -1) // index 5 doesn't exist, emits -1 instead
).subscribe(console.log); // -1
```

---

### Q50. How does `last` work and when does it error?

**Answer:** `last(predicate?)` emits the last value (matching the predicate if given) when the source completes, then itself completes. If the source completes without a matching emission, `last` throws `EmptyError`. It requires the source to complete.

✅ **Correct:**
```typescript
of(1, 2, 3).pipe(last()).subscribe(console.log); // 3

// Last even number:
of(1, 2, 3, 4, 5).pipe(
  last(n => n % 2 === 0)
).subscribe(console.log); // 4

// Error case:
EMPTY.pipe(last()).subscribe({ error: e => console.error('EmptyError', e) });
```

---

## 6. Combination Operators

📚 **References:**
- [RxJS Official — Combination](https://rxjs.dev/guide/operators#combination-operators)
- [RxJS — withLatestFrom](https://rxjs.dev/api/operators/withLatestFrom)
- [Angular In Depth — combineLatest patterns](https://indepth.dev/posts/1406/rxjs-combinelatest-vs-withlatestfrom)

---

### Q51. What is `withLatestFrom` and how does it differ from `combineLatest`?

**Answer:** `withLatestFrom(other$)` pairs each source emission with the LATEST value from `other$`, but ONLY when the source emits. It does not emit when `other$` changes. `combineLatest` emits whenever ANY source changes (after all have emitted once). Use `withLatestFrom` when the source drives the timing.

✅ **Correct:**
```typescript
// combineLatest — emits when either changes:
combineLatest([filter$, sort$]).subscribe(([f, s]) => this.reload(f, s));

// withLatestFrom — only when button clicked, take current filter:
saveBtn$.pipe(
  withLatestFrom(this.currentFilter$),
  switchMap(([_, filter]) => this.save(filter))
).subscribe(); // ✅ filter value is read at click time, not reactive
```

---

### Q52. What is the nested subscription anti-pattern and how do you fix it?

**Answer:** Nesting `.subscribe()` inside `.subscribe()` creates unmanaged inner subscriptions, breaks error propagation, and makes the code hard to read. The fix is to use higher-order mapping operators (`switchMap`, `mergeMap`, `concatMap`) to flatten the streams.

❌ **Wrong — nested subscriptions:**
```typescript
this.route.params.subscribe(params => {
  this.userService.getUser(params.id).subscribe(user => { // nested subscribe ❌
    this.profileService.getProfile(user.id).subscribe(profile => {
      this.profile = profile; // three levels deep ❌
    });
  });
});
```

✅ **Correct:**
```typescript
this.route.params.pipe(
  switchMap(params => this.userService.getUser(params.id)),
  switchMap(user => this.profileService.getProfile(user.id))
).subscribe(profile => this.profile = profile); // clean, composable ✅
```

---

### Q53. How does `startWith` work and what is a common use case?

**Answer:** `startWith(...values)` prepends synchronous values before the source Observable starts emitting. It is useful for providing an initial state or loading indicator before async data arrives.

✅ **Correct:**
```typescript
// Show loading until data arrives:
this.http.get<User[]>('/api/users').pipe(
  map(users => ({ status: 'loaded', users })),
  startWith({ status: 'loading', users: [] })
).subscribe(state => this.state = state); // ✅

// Initial form value for combineLatest:
combineLatest([
  this.filter$.pipe(startWith('')),
  this.page$.pipe(startWith(1))
]).subscribe(([filter, page]) => this.loadPage(filter, page));
```

---

### Q54. How does `pairwise` work?

**Answer:** `pairwise` emits the current and previous values as a two-element array `[prev, curr]` on each emission. The first emission from the source is held internally and emitted as `prev` on the second emission — meaning the first source value does NOT cause a pairwise emission.

✅ **Correct:**
```typescript
from([1, 2, 3, 4]).pipe(
  pairwise()
).subscribe(console.log);
// [1, 2], [2, 3], [3, 4]

// Detect scroll direction:
fromEvent(window, 'scroll').pipe(
  map(() => window.scrollY),
  pairwise(),
  map(([prev, curr]) => curr > prev ? 'down' : 'up')
).subscribe(dir => this.scrollDir = dir);
```

---

### Q55. How do you combine two HTTP responses that depend on each other?

**Answer:** Use `switchMap` (or `concatMap`) to make the second request dependent on the first response. This is the sequential dependent HTTP call pattern — flattening the nested async flow.

✅ **Correct:**
```typescript
this.http.get<User>('/api/me').pipe(
  switchMap(user => this.http.get<Order[]>(`/api/orders?userId=${user.id}`)),
  switchMap(orders => this.http.get<Product[]>(`/api/products?ids=${orders.map(o => o.productId)}`))
).subscribe(products => this.products = products); // ✅
```

---

### Q56. How does `zip` differ from `combineLatest`?

**Answer:** `zip` pairs emissions STRICTLY by index — it waits until all sources have emitted their Nth value before emitting `[N-th values]`. If one source emits faster, values are buffered. `combineLatest` emits the LATEST from each source whenever any emits.

✅ **Correct:**
```typescript
const a$ = of(1, 2, 3);
const b$ = of('a', 'b', 'c');

zip(a$, b$).subscribe(console.log);
// [1,'a'], [2,'b'], [3,'c'] — index-paired ✅

combineLatest([of(1), interval(1000)]).subscribe(console.log);
// [1, 0], [1, 1], [1, 2]... — reacts to any change ✅
```

---

### Q57. When would you use `merge` over `combineLatest`?

**Answer:** Use `merge` when you want to pass through all values from multiple sources as-is, without pairing or combining. Use `combineLatest` when you need the LATEST value from ALL sources together. `merge` is like a passthrough union; `combineLatest` is like a synchronized view.

✅ **Correct:**
```typescript
// merge — combine two event streams, handle both uniformly:
const allEvents$ = merge(touchEvents$, mouseEvents$);
allEvents$.subscribe(e => this.handleInput(e)); // ✅

// combineLatest — need all latest values together:
combineLatest([userId$, userRole$]).subscribe(
  ([id, role]) => this.authGuard(id, role)
); // ✅
```

---

### Q58. How does `concat` guarantee order? What happens if the first source never completes?

**Answer:** `concat` subscribes to the next source only after the current one completes. If the first source never completes (e.g., `interval`), the subsequent sources will never be subscribed to. This makes `concat` unsuitable for infinite streams.

❌ **Wrong — second source unreachable:**
```typescript
concat(
  interval(1000), // never completes ❌
  of('done')      // never reached
).subscribe(console.log);
```

✅ **Correct — use concat only with finite sources:**
```typescript
concat(
  of('First'),
  this.http.get('/api/data').pipe(map(d => JSON.stringify(d))),
  of('Complete')
).subscribe(console.log); // First, {data}, Complete ✅
```

---

### Q59. How do you handle multiple parallel API calls and wait for all results?

**Answer:** Use `forkJoin` for parallel HTTP calls that all need to complete before processing. It waits for all sources to complete and emits their last values as an array. If any source errors, `forkJoin` errors immediately.

✅ **Correct:**
```typescript
forkJoin({
  user: this.http.get<User>('/api/user'),
  settings: this.http.get<Settings>('/api/settings'),
  notifications: this.http.get<Notification[]>('/api/notifications')
}).subscribe(({ user, settings, notifications }) => {
  this.user = user;
  this.settings = settings;
  this.notifications = notifications;
}); // ✅ named object form for readability
```

---

### Q60. How does `combineLatestWith` (RxJS 7+) differ from `combineLatest`?

**Answer:** `combineLatestWith` is a pipeable operator form of `combineLatest`, introduced in RxJS 7. Instead of passing all sources as an array to a static function, you pipe one source and pass additional sources to `combineLatestWith`. Both are functionally equivalent.

✅ **Correct:**
```typescript
// RxJS 6 static form:
combineLatest([source1$, source2$]).subscribe(...);

// RxJS 7+ pipeable form:
source1$.pipe(
  combineLatestWith(source2$)
).subscribe(([val1, val2]) => ...); // ✅
```

---

## 7. Error Handling

📚 **References:**
- [RxJS Official — Error Handling](https://rxjs.dev/guide/operators#error-handling-operators)
- [RxJS — catchError](https://rxjs.dev/api/operators/catchError)
- [RxJS — retry](https://rxjs.dev/api/operators/retry)

---

### Q61. How does `catchError` work? What must it return?

**Answer:** `catchError(handler)` intercepts an error in the pipeline and calls `handler(err, caught$)`. The handler MUST return an Observable. If you return `EMPTY`, the stream completes silently. If you return another Observable, it replaces the errored one. If you rethrow, the error propagates further.

❌ **Wrong — returning nothing from catchError:**
```typescript
this.http.get('/api').pipe(
  catchError(err => { console.error(err); }) // returns undefined — breaks pipeline ❌
).subscribe();
```

✅ **Correct:**
```typescript
this.http.get<Data>('/api').pipe(
  catchError(err => {
    console.error(err);
    return of({ default: true } as Data); // fallback value ✅
  })
).subscribe(data => this.data = data);
```

---

### Q62. How do you retry a failed Observable a fixed number of times?

**Answer:** Use `retry(n)` to resubscribe to the source Observable up to `n` times on error. If the source still errors after `n` retries, the error propagates. Place `retry` before `catchError` in the pipeline.

✅ **Correct:**
```typescript
this.http.get('/api/data').pipe(
  retry(3), // try 3 more times on failure ✅
  catchError(err => {
    console.error('Failed after 3 retries:', err);
    return EMPTY;
  })
).subscribe(data => this.data = data);
```

---

### Q63. How do you retry with a delay between attempts? (RxJS 7+ approach)

**Answer:** In RxJS 7+, `retry({ count, delay })` supports a `delay` option: a number (milliseconds between retries) or a function returning an Observable (for backoff strategies). `retryWhen` is deprecated in favor of this approach.

✅ **Correct:**
```typescript
// Fixed delay:
this.http.get('/api').pipe(
  retry({ count: 3, delay: 1000 }) // wait 1s between retries ✅
).subscribe();

// Exponential backoff:
this.http.get('/api').pipe(
  retry({
    count: 5,
    delay: (error, retryCount) => timer(Math.pow(2, retryCount) * 1000)
  })
).subscribe();
```

---

### Q64. How do you rethrow an error after partial handling in `catchError`?

**Answer:** In the `catchError` handler, call `throwError(() => err)` or `throw err` to propagate the error further. This is useful when you want to log the error locally but still let the caller's `catchError` or `subscribe`'s error handler deal with it.

✅ **Correct:**
```typescript
this.http.get('/api').pipe(
  catchError(err => {
    this.logger.log(err); // local handling
    return throwError(() => err); // rethrow for parent to handle ✅
  })
).subscribe({
  error: err => this.showError(err.message) // caught here ✅
});
```

---

### Q65. What is `onErrorResumeNext`?

**Answer:** `onErrorResumeNext(...sources)` subscribes to each source in sequence and ignores any errors — when one source errors, it silently moves to the next. Use it when you have fallback sources and want to try them all regardless of errors.

✅ **Correct:**
```typescript
import { onErrorResumeNext } from 'rxjs';

onErrorResumeNext(
  this.http.get('/api/primary'),    // errors silently
  this.http.get('/api/secondary'),  // tried next ✅
  of(this.cachedData)               // final fallback
).subscribe(data => this.data = data);
```

---

### Q66. How do you handle errors globally in an Angular application using RxJS?

**Answer:** In Angular, implement a global `ErrorHandler` to catch uncaught errors. For HTTP errors, use an `HttpInterceptor` to catch all HTTP errors in one place and apply `catchError` to all requests globally.

✅ **Correct:**
```typescript
// HTTP Interceptor for global error handling:
@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    return next.handle(req).pipe(
      catchError((err: HttpErrorResponse) => {
        if (err.status === 401) this.router.navigate(['/login']);
        if (err.status === 500) this.notify.error('Server error');
        return throwError(() => err); // ✅
      })
    );
  }
}
```

---

### Q67. What happens when `catchError` returns `EMPTY`? When is this appropriate?

**Answer:** Returning `EMPTY` from `catchError` silently swallows the error — the stream completes without emitting a value or error. This is appropriate when a failed operation is non-critical and the UI should remain unaffected (e.g., background telemetry, optional preloads).

✅ **Correct:**
```typescript
// Non-critical background sync:
this.analyticsService.sync().pipe(
  catchError(err => {
    console.warn('Analytics sync failed, ignoring:', err);
    return EMPTY; // app continues normally ✅
  })
).subscribe();
```

---

### Q68. How does error handling differ inside `switchMap` vs outside?

**Answer:** An error inside a `switchMap`'s inner Observable terminates the ENTIRE outer stream unless caught inside the `switchMap`. Use `catchError` inside the inner observable to keep the outer stream alive after individual inner failures.

❌ **Wrong — inner error kills outer stream:**
```typescript
searchInput$.pipe(
  switchMap(query => this.http.get(`/api?q=${query}`)) // one 404 kills the whole stream ❌
).subscribe(...);
```

✅ **Correct — catch inside switchMap:**
```typescript
searchInput$.pipe(
  switchMap(query =>
    this.http.get(`/api?q=${query}`).pipe(
      catchError(() => of([])) // inner error → empty results, stream continues ✅
    )
  )
).subscribe(results => this.results = results);
```

---

### Q69. What is the difference between `retry` and `retryWhen` (deprecated)?

**Answer:** `retryWhen(notifier => ...)` was the old way to customize retry behavior — the notifier function received an Observable of errors and you returned an Observable whose emissions triggered retries. It was complex and error-prone. RxJS 7+ replaces it with `retry({ count, delay })` which is cleaner and more expressive.

✅ **Modern replacement:**
```typescript
// Old (deprecated retryWhen):
// source$.pipe(retryWhen(errors => errors.pipe(delay(1000), take(3))))

// New (RxJS 7+):
source$.pipe(
  retry({ count: 3, delay: 1000 }) // ✅ cleaner
).subscribe();
```

---

### Q70. How do you implement partial error recovery — succeed for some, fail for others?

**Answer:** Use `mergeMap` with per-item `catchError` to handle individual failures independently. Items that error return a fallback, while successful items emit normally. The outer stream remains active throughout.

✅ **Correct:**
```typescript
from(userIds).pipe(
  mergeMap(id =>
    this.http.get<User>(`/api/users/${id}`).pipe(
      catchError(err => of({ id, error: err.message, failed: true })) // per-item fallback ✅
    )
  )
).subscribe(result => {
  if (result.failed) console.warn('Failed for', result.id);
  else this.users.push(result as User);
});
```

---

## 8. Multicasting & Sharing

📚 **References:**
- [RxJS Official — Multicasting](https://rxjs.dev/guide/subject#multicasting)
- [RxJS — shareReplay](https://rxjs.dev/api/operators/shareReplay)
- [Angular In Depth — share vs shareReplay](https://indepth.dev/posts/1380/rxjs-share-vs-sharereplay)

---

### Q71. What is the difference between a unicast and multicast Observable?

**Answer:** A unicast Observable creates a new execution for each subscriber (cold). A multicast Observable shares a single execution among all subscribers (hot). `Subject`, `share`, `shareReplay`, and `publish` are mechanisms to convert cold Observables to multicast.

✅ **Correct:**
```typescript
// Unicast — 2 HTTP requests fire:
const cold$ = this.http.get('/api');
cold$.subscribe(a => console.log('A', a));
cold$.subscribe(b => console.log('B', b)); // separate request ❌ if sharing intent

// Multicast — 1 HTTP request, shared:
const hot$ = this.http.get('/api').pipe(shareReplay(1));
hot$.subscribe(a => console.log('A', a));
hot$.subscribe(b => console.log('B', b)); // ✅ same response
```

---

### Q72. What does `share` do? How is it different from `shareReplay`?

**Answer:** `share` multicasts the source and auto-connects when the first subscriber arrives, and disconnects when all subscribers unsubscribe (ref-counting). Late subscribers miss past emissions. `shareReplay(n)` also ref-counts (by default in RxJS 7+) but replays the last `n` emissions to late subscribers.

✅ **Correct:**
```typescript
// share — good for events, bad for HTTP (late sub gets nothing):
const clicks$ = fromEvent(document, 'click').pipe(share());

// shareReplay(1) — HTTP caching, late subscribers get last value:
const user$ = this.http.get<User>('/api/me').pipe(
  shareReplay(1) // ✅ subsequent subscribers get cached value
);
```

---

### Q73. How do you prevent multiple HTTP requests when multiple components subscribe to the same observable?

**Answer:** Use `shareReplay(1)` in the service to cache and share the HTTP call. The first subscription fires the request; subsequent subscribers receive the replayed response from cache without triggering new requests.

✅ **Correct:**
```typescript
@Injectable({ providedIn: 'root' })
export class ConfigService {
  private config$ = this.http.get<Config>('/api/config').pipe(
    shareReplay(1) // ✅ one request, shared across all consumers
  );

  getConfig() { return this.config$; }
}
```

---

### Q74. What is `refCount` behavior in `shareReplay`? What changed in RxJS 7?

**Answer:** In RxJS 6, `shareReplay` by default did NOT disconnect from the source when all subscribers unsubscribed (refCount: false) — potentially causing leaks. In RxJS 7, `shareReplay` defaults to `{ refCount: true }`, which disconnects when unsubscribed. Use `shareReplay({ bufferSize: 1, refCount: false })` to retain the old always-connected behavior for indefinite caching.

✅ **Correct:**
```typescript
// RxJS 7 default — disconnects when all unsubscribe:
const shared$ = source$.pipe(shareReplay(1)); // refCount: true ✅

// Always-on cache (does not disconnect):
const alwaysOn$ = source$.pipe(
  shareReplay({ bufferSize: 1, refCount: false })
); // ✅ for app-lifetime caches
```

---

### Q75. What is `publish` and `multicast`? Are they still used?

**Answer:** `publish()` is shorthand for `multicast(() => new Subject())`. `multicast(subject)` wraps a cold Observable in a Subject for multicasting — but requires manually calling `.connect()`. These are low-level and largely replaced by `share` and `shareReplay` in modern RxJS. `publish` was deprecated in RxJS 7.

✅ **Modern equivalent:**
```typescript
// Old:
// const published$ = source$.pipe(publish());
// published$.connect();

// Modern equivalent:
const shared$ = source$.pipe(share()); // auto-connects ✅
```

---

### Q76. What is `connectable` (RxJS 7+)?

**Answer:** `connectable(source, { connector, resetOnDisconnect })` creates a ConnectableObservable that does not start until `.connect()` is called. It replaces the deprecated `publish()` + `multicast()`. Use it when you need explicit control over when multicasting begins.

✅ **Correct:**
```typescript
import { connectable, Subject } from 'rxjs';

const connected$ = connectable(interval(1000), {
  connector: () => new Subject(),
  resetOnDisconnect: false
});

connected$.subscribe(a => console.log('A', a));
connected$.subscribe(b => console.log('B', b));

const connection = connected$.connect(); // starts NOW ✅
setTimeout(() => connection.unsubscribe(), 5000); // stop after 5s
```

---

### Q77. How does `shareReplay(1)` help implement simple caching in a service?

**Answer:** When the returned Observable is stored in the service, `shareReplay(1)` ensures that the HTTP request fires only once and the result is cached. Future subscribers get the cached value immediately without a new network round-trip.

✅ **Correct:**
```typescript
@Injectable({ providedIn: 'root' })
export class CountriesService {
  private countries$ = this.http.get<Country[]>('/api/countries').pipe(
    shareReplay({ bufferSize: 1, refCount: false }) // permanent cache ✅
  );

  getCountries(): Observable<Country[]> {
    return this.countries$; // same Observable instance returned each time
  }
}
```

---

### Q78. What is the difference between `share` and `Subject` for multicasting?

**Answer:** Both create hot, multicast streams, but `share` is operator-based and wraps an existing cold Observable. A `Subject` is imperative — you call `next()` manually. Use `share` when you have an existing Observable source. Use a `Subject` when you are the producer (e.g., triggering events in a service).

✅ **Correct:**
```typescript
// share — wrap existing cold observable:
const sharedHttp$ = this.http.get('/api').pipe(share());

// Subject — imperative event bus:
const events$ = new Subject<AppEvent>();
events$.next({ type: 'UserLoggedIn', payload: user });
```

---

### Q79. Can you explain the "diamond problem" with combineLatest and shared sources?

**Answer:** When two streams fed into `combineLatest` both derive from the same source, a single source emission causes BOTH derived streams to emit, which triggers `combineLatest` TWICE with intermediate inconsistent state. Solve this by using `share()` on the common source and careful structuring.

✅ **Correct:**
```typescript
// Problem:
const source$ = interval(1000);
const a$ = source$.pipe(map(n => n * 2));
const b$ = source$.pipe(map(n => n * 3));
combineLatest([a$, b$]).subscribe(console.log);
// Emits twice per source tick — inconsistent pairs ❌

// Solution — derive both from the same shared emission:
const shared$ = source$.pipe(share());
const a$ = shared$.pipe(map(n => n * 2));
const b$ = shared$.pipe(map(n => n * 3));
combineLatest([a$, b$]).subscribe(console.log); // ✅ still double-emits but shared
// Better: restructure into single map:
source$.pipe(map(n => [n * 2, n * 3])).subscribe(console.log); // ✅
```

---

### Q80. When should you NOT use `shareReplay`?

**Answer:** Avoid `shareReplay` when the cached data can become stale and you always need fresh values. Avoid it on streams with large payloads if memory is a concern. Also avoid `shareReplay` with `refCount: false` on per-request Observables — it keeps the source active and memory allocated indefinitely.

✅ **Correct guidance:**
```typescript
// Bad — shareReplay on a per-request stream that should not persist:
getUserById(id: number) {
  return this.http.get(`/api/users/${id}`).pipe(
    shareReplay({ bufferSize: 1, refCount: false }) // leaks, stale data if user changes ❌
  );
}

// Good — shareReplay only on stable reference data:
readonly countries$ = this.http.get('/api/countries').pipe(
  shareReplay({ bufferSize: 1, refCount: false }) // ✅ stable, rarely changes
);
```

---

## 9. Utility & Conditional Operators

📚 **References:**
- [RxJS Official — Utility Operators](https://rxjs.dev/guide/operators#utility-operators)
- [RxJS — tap](https://rxjs.dev/api/operators/tap)
- [RxJS — timeout](https://rxjs.dev/api/operators/timeout)

---

### Q81. What does `tap` do and when should you use it?

**Answer:** `tap(observer)` performs side effects for each emission (next, error, complete) WITHOUT modifying the stream. Use it for debugging, logging, analytics, or triggering secondary effects while keeping the main pipeline pure. Never use it to transform values.

❌ **Wrong — transforming values in tap:**
```typescript
data$.pipe(
  tap(data => data.processed = true) // mutating in tap — side effect, bad practice ❌
).subscribe();
```

✅ **Correct:**
```typescript
data$.pipe(
  tap(data => console.log('DEBUG received:', data)),   // logging ✅
  tap({ error: err => this.logger.error(err) }),        // error side effect ✅
  map(data => this.transform(data))
).subscribe();
```

---

### Q82. How does `delay` work? How is it different from `delayWhen`?

**Answer:** `delay(ms)` shifts every emission forward by a fixed `ms` milliseconds. `delayWhen(durationSelector)` delays each individual emission until the Observable returned by `durationSelector(value)` emits. Use `delayWhen` for variable per-item delays.

✅ **Correct:**
```typescript
// delay — fixed offset:
of('hello').pipe(delay(2000)).subscribe(console.log); // 'hello' after 2s

// delayWhen — variable delay per item:
from([1, 2, 3]).pipe(
  delayWhen(val => timer(val * 500)) // 500ms, 1000ms, 1500ms respectively
).subscribe(console.log); // ✅
```

---

### Q83. How does `timeout` work in RxJS?

**Answer:** `timeout({ each: ms })` errors with a `TimeoutError` if the source doesn't emit within `ms` milliseconds between emissions. `timeout({ first: ms })` applies only to the first emission. Use it to enforce SLA deadlines on Observables like HTTP calls.

✅ **Correct:**
```typescript
this.http.get('/api/slow-endpoint').pipe(
  timeout({ each: 5000 }), // error if no response within 5s ✅
  catchError(err => {
    if (err instanceof TimeoutError) return of(this.cachedData);
    return throwError(() => err);
  })
).subscribe();
```

---

### Q84. What does `toArray` do?

**Answer:** `toArray()` collects all emissions into an array and emits that array when the source completes. It requires the source to complete. Use it to convert a stream into a single array for batch processing.

✅ **Correct:**
```typescript
from([1, 2, 3, 4, 5]).pipe(
  filter(n => n % 2 !== 0),
  toArray()
).subscribe(console.log); // [1, 3, 5] ✅

// Good for converting paginated results:
this.paginatedStream$.pipe(
  toArray()
).subscribe(allPages => this.process(allPages));
```

---

### Q85. How do `count`, `max`, and `min` work in RxJS?

**Answer:** `count(predicate?)` emits the number of source emissions (optionally matching a predicate) when the source completes. `max(comparator?)` and `min(comparator?)` emit the maximum/minimum value when the source completes. All require the source to complete.

✅ **Correct:**
```typescript
of(3, 1, 4, 1, 5, 9).pipe(max()).subscribe(console.log); // 9
of(3, 1, 4, 1, 5, 9).pipe(min()).subscribe(console.log); // 1
of(1, 2, 3, 4, 5).pipe(count()).subscribe(console.log); // 5
of(1, 2, 3, 4, 5).pipe(count(n => n > 3)).subscribe(console.log); // 2 (4 and 5)

// Custom comparator for objects:
of({ age: 30 }, { age: 25 }, { age: 35 }).pipe(
  max((a, b) => a.age - b.age)
).subscribe(console.log); // { age: 35 }
```

---

### Q86. What does `every` do in RxJS?

**Answer:** `every(predicate)` emits a single boolean `true` when the source completes and ALL emissions satisfied the predicate, or `false` as soon as one emission fails the predicate (the source is unsubscribed immediately on first failure).

✅ **Correct:**
```typescript
of(2, 4, 6, 8).pipe(
  every(n => n % 2 === 0)
).subscribe(console.log); // true ✅

of(2, 3, 6, 8).pipe(
  every(n => n % 2 === 0)
).subscribe(console.log); // false (short-circuits at 3) ✅
```

---

### Q87. How do `find` and `findIndex` work in RxJS?

**Answer:** `find(predicate)` emits the first value from the source that satisfies the predicate, then completes. `findIndex(predicate)` emits the zero-based index of that first matching value. If no value matches and the source completes, they emit `undefined` and `-1` respectively.

✅ **Correct:**
```typescript
from([5, 12, 3, 18, 7]).pipe(
  find(n => n > 10)
).subscribe(console.log); // 12

from([5, 12, 3, 18, 7]).pipe(
  findIndex(n => n > 10)
).subscribe(console.log); // 1 (index of 12)
```

---

### Q88. What does `isEmpty` do?

**Answer:** `isEmpty()` emits `true` if the source completes without emitting any values, and `false` as soon as the source emits its first value (then completes). It is the inverse logic of checking for at least one emission.

✅ **Correct:**
```typescript
EMPTY.pipe(isEmpty()).subscribe(console.log); // true ✅
of(1, 2, 3).pipe(isEmpty()).subscribe(console.log); // false (after first emission)

// Practical — show empty state:
this.results$.pipe(isEmpty()).subscribe(empty => {
  this.showEmptyState = empty;
});
```

---

### Q89. What does `defaultIfEmpty` do?

**Answer:** `defaultIfEmpty(defaultValue)` emits `defaultValue` if the source completes without emitting any values. Otherwise, it passes all source values through unchanged. Use it for graceful defaults on potentially empty streams.

✅ **Correct:**
```typescript
EMPTY.pipe(defaultIfEmpty('No results')).subscribe(console.log); // 'No results'
of(1, 2).pipe(defaultIfEmpty(0)).subscribe(console.log); // 1, 2 (default not used)

// Practical — default search results:
this.search(query).pipe(
  defaultIfEmpty([] as Result[])
).subscribe(results => this.results = results); // ✅
```

---

### Q90. What does `sequenceEqual` do?

**Answer:** `sequenceEqual(compareTo$, comparator?)` emits `true` if the source and `compareTo$` emit the same sequence of values in the same order, and `false` otherwise. Both must complete for the comparison to resolve.

✅ **Correct:**
```typescript
import { sequenceEqual } from 'rxjs/operators';

const source$ = of(1, 2, 3);
const compare$ = of(1, 2, 3);

source$.pipe(sequenceEqual(compare$)).subscribe(console.log); // true ✅

const diff$ = of(1, 2, 4);
source$.pipe(sequenceEqual(diff$)).subscribe(console.log); // false ✅
```

---

## 10. RxJS in Angular Patterns

📚 **References:**
- [Angular Docs — async pipe](https://angular.dev/api/common/AsyncPipe)
- [Angular Docs — takeUntilDestroyed](https://angular.dev/api/core/rxjs-interop/takeUntilDestroyed)
- [Angular In Depth — Reactive patterns](https://indepth.dev/posts/1010/rxjs-in-angular-part-i)

---

### Q91. What is the async pipe and why is it preferred over manual subscribe/unsubscribe?

**Answer:** The `async` pipe in Angular templates subscribes to an Observable or Promise and returns the latest emitted value. It automatically unsubscribes when the component is destroyed, eliminating the need for manual subscription management and preventing memory leaks.

❌ **Wrong — manual subscription in component:**
```typescript
// Must manually manage subscription ❌
ngOnInit() { this.sub = this.users$.subscribe(u => this.users = u); }
ngOnDestroy() { this.sub.unsubscribe(); }
```

✅ **Correct — async pipe:**
```html
<!-- Template handles everything automatically ✅ -->
<ul>
  <li *ngFor="let user of users$ | async">{{ user.name }}</li>
</ul>
```
```typescript
// Component only needs the observable:
users$ = this.userService.getUsers();
```

---

### Q92. What is `takeUntilDestroyed` (Angular 16+) and how does it work?

**Answer:** `takeUntilDestroyed(destroyRef?)` is an RxJS operator from `@angular/core/rxjs-interop` that automatically completes a stream when the current injection context (component, directive, service) is destroyed. It replaces the `takeUntil(destroy$)` pattern without needing manual Subject management.

✅ **Correct:**
```typescript
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({...})
export class MyComponent {
  constructor() {
    interval(1000).pipe(
      takeUntilDestroyed() // automatically cleaned up ✅
    ).subscribe(n => this.counter = n);
  }
}

// Can also be used outside constructor with explicit DestroyRef:
export class MyComponent {
  private destroyRef = inject(DestroyRef);
  ngOnInit() {
    interval(1000).pipe(
      takeUntilDestroyed(this.destroyRef) // ✅
    ).subscribe();
  }
}
```

---

### Q93. How do you use `combineLatest` to load data from multiple APIs simultaneously in Angular?

**Answer:** `combineLatest` subscribes to all source Observables simultaneously and emits the latest combination whenever any source emits. For HTTP calls (which complete), use with `startWith` or prefer `forkJoin`. `combineLatest` shines when combining ongoing streams with HTTP data.

✅ **Correct:**
```typescript
@Component({...})
export class DashboardComponent {
  vm$ = combineLatest({
    user: this.userService.currentUser$,
    config: this.configService.config$,
    notifications: this.notificationService.notifications$
  }).pipe(
    takeUntilDestroyed()
  );
}
```
```html
<ng-container *ngIf="vm$ | async as vm">
  <h1>Hello {{ vm.user.name }}</h1>
  <app-notifications [items]="vm.notifications"></app-notifications>
</ng-container>
```

---

### Q94. How do you implement a type-ahead search with debounce in Angular?

**Answer:** Combine `fromEvent` or reactive form `valueChanges` with `debounceTime`, `distinctUntilChanged`, and `switchMap`. `switchMap` cancels in-flight requests when the user continues typing, and `debounceTime` prevents excessive API calls.

✅ **Correct:**
```typescript
@Component({...})
export class SearchComponent implements OnInit {
  results$!: Observable<SearchResult[]>;
  searchControl = new FormControl('');

  ngOnInit() {
    this.results$ = this.searchControl.valueChanges.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      filter(query => (query?.length ?? 0) >= 2),
      switchMap(query =>
        this.searchService.search(query!).pipe(
          catchError(() => of([]))
        )
      )
    );
  }
}
```
```html
<input [formControl]="searchControl" placeholder="Search...">
<ul>
  <li *ngFor="let result of results$ | async">{{ result.title }}</li>
</ul>
```

---

### Q95. How do you implement polling (recurring HTTP calls) with RxJS?

**Answer:** Use `timer(0, intervalMs).pipe(switchMap(() => this.http.get(...)))`. `timer(0, period)` starts immediately, then repeats. `switchMap` ensures only the latest request is active — if the previous HTTP call is still pending when the next tick fires, it is cancelled and a new request is started.

✅ **Correct:**
```typescript
@Component({...})
export class LiveDataComponent {
  liveData$ = timer(0, 5000).pipe(
    switchMap(() => this.http.get<LiveData>('/api/live').pipe(
      catchError(() => of(null)) // don't kill polling on error
    )),
    filter(data => data !== null),
    takeUntilDestroyed()
  );
}
```
```html
<div *ngIf="liveData$ | async as data">
  {{ data.value }}
</div>
```

---

### Q96. How do you manage state with `BehaviorSubject` in an Angular service?

**Answer:** Create private `BehaviorSubject` properties for each state slice. Expose read-only Observables and explicit mutation methods. Components observe state and react to changes. This pattern scales from simple flags to complex multi-slice state without NgRx.

✅ **Correct:**
```typescript
@Injectable({ providedIn: 'root' })
export class TodoService {
  private todos$ = new BehaviorSubject<Todo[]>([]);
  private loading$ = new BehaviorSubject<boolean>(false);
  private error$ = new BehaviorSubject<string | null>(null);

  readonly vm$ = combineLatest({
    todos: this.todos$,
    loading: this.loading$,
    error: this.error$
  });

  loadTodos() {
    this.loading$.next(true);
    this.http.get<Todo[]>('/api/todos').subscribe({
      next: todos => { this.todos$.next(todos); this.loading$.next(false); },
      error: err => { this.error$.next(err.message); this.loading$.next(false); }
    });
  }

  addTodo(todo: Todo) {
    this.todos$.next([...this.todos$.getValue(), todo]);
  }
}
```

---

### Q97. How do you use RxJS with Angular Reactive Forms?

**Answer:** Reactive form controls expose a `valueChanges` Observable and `statusChanges` Observable. These integrate seamlessly with RxJS pipelines for validation feedback, auto-save, or form-dependent data loading.

✅ **Correct:**
```typescript
@Component({...})
export class ProfileFormComponent {
  form = this.fb.group({
    username: ['', Validators.required],
    country: ['']
  });

  // Auto-check username availability:
  usernameAvailable$ = this.form.get('username')!.valueChanges.pipe(
    debounceTime(400),
    distinctUntilChanged(),
    filter(v => v.length >= 3),
    switchMap(username => this.userService.checkAvailability(username)),
    startWith(null),
    takeUntilDestroyed()
  );

  // Load states when country changes:
  states$ = this.form.get('country')!.valueChanges.pipe(
    switchMap(country => this.locationService.getStates(country)),
    takeUntilDestroyed()
  );
}
```

---

### Q98. How do you implement a loading/error state pattern with RxJS?

**Answer:** Use `switchMap` with `startWith` and `catchError` inside the inner Observable to produce a state object with `{ status: 'loading' | 'loaded' | 'error', data?, error? }`. The `startWith` inside `switchMap` ensures loading state is set for each new request.

✅ **Correct:**
```typescript
type LoadingState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'loaded'; data: T }
  | { status: 'error'; error: string };

@Component({...})
export class DataComponent {
  state$: Observable<LoadingState<User[]>> = this.trigger$.pipe(
    switchMap(() =>
      this.http.get<User[]>('/api/users').pipe(
        map(data => ({ status: 'loaded' as const, data })),
        catchError(err => of({ status: 'error' as const, error: err.message })),
        startWith({ status: 'loading' as const })
      )
    ),
    startWith({ status: 'idle' as const })
  );
}
```
```html
<ng-container [ngSwitch]="(state$ | async)?.status">
  <p *ngSwitchCase="'loading'">Loading...</p>
  <ul *ngSwitchCase="'loaded'">
    <li *ngFor="let user of (state$ | async)?.data">{{ user.name }}</li>
  </ul>
  <p *ngSwitchCase="'error'">Error: {{ (state$ | async)?.error }}</p>
</ng-container>
```

---

### Q99. What is the difference between `async` pipe with `*ngIf` vs `*ngFor`? What are common pitfalls?

**Answer:** `*ngIf="stream$ | async as value"` subscribes once and aliases the value. `*ngFor="let item of list$ | async"` also subscribes once per ngFor. The pitfall is using `async` multiple times in a template for the same Observable — each usage creates a separate subscription (and for HTTP, separate requests unless shared).

❌ **Wrong — multiple subscriptions to same observable:**
```html
<p>Count: {{ (users$ | async)?.length }}</p>
<ul>
  <li *ngFor="let user of users$ | async">{{ user.name }}</li>
</ul>
<!-- Two subscriptions = two HTTP requests! ❌ -->
```

✅ **Correct — single subscription with ngIf alias:**
```html
<ng-container *ngIf="users$ | async as users">
  <p>Count: {{ users.length }}</p>
  <ul>
    <li *ngFor="let user of users">{{ user.name }}</li>
  </ul>
</ng-container>
<!-- One subscription ✅ -->
```

---

### Q100. How do you combine route params and query params reactively in Angular?

**Answer:** Use `combineLatest([this.route.params, this.route.queryParams])` to react to changes in either. Use `switchMap` to reload data whenever route parameters change. This pattern ensures the component always reflects the current URL state.

✅ **Correct:**
```typescript
@Component({...})
export class ProductListComponent {
  products$ = combineLatest([
    this.route.params,
    this.route.queryParams
  ]).pipe(
    debounceTime(0), // coalesce simultaneous param + query param changes
    switchMap(([params, query]) =>
      this.productService.getProducts({
        categoryId: params['categoryId'],
        page: Number(query['page'] ?? 1),
        sort: query['sort'] ?? 'name'
      }).pipe(catchError(() => of([])))
    ),
    takeUntilDestroyed()
  );

  constructor(private route: ActivatedRoute, private productService: ProductService) {}
}
```

---

## 📌 Quick Reference Card

### Higher-Order Mapping Operators

| Operator | Concurrent inners | Cancels previous? | Order preserved? | Best for |
|---|---|---|---|---|
| `switchMap` | 1 (latest) | Yes | No | Autocomplete, route data |
| `mergeMap` | Unlimited | No | No | Parallel uploads, independent calls |
| `concatMap` | 1 at a time | No (queues) | Yes | Sequential operations, ordered queue |
| `exhaustMap` | 1 at a time | No (ignores) | N/A | Form submit, login button |

### Subject Types

| Type | Requires initial value | Replays to late subs | How many values replayed |
|---|---|---|---|
| `Subject` | No | No | 0 |
| `BehaviorSubject` | Yes | Yes | 1 (current) |
| `ReplaySubject(n)` | No | Yes | Last n |
| `AsyncSubject` | No | Yes (on complete) | 1 (last) |

### Unsubscription Patterns

```typescript
// Pattern 1: takeUntilDestroyed (Angular 16+, recommended)
stream$.pipe(takeUntilDestroyed()).subscribe();

// Pattern 2: takeUntil with destroy Subject
stream$.pipe(takeUntil(this.destroy$)).subscribe();

// Pattern 3: async pipe (in templates, recommended)
// {{ stream$ | async }}

// Pattern 4: Subscription.add()
this.sub.add(stream$.subscribe());
ngOnDestroy() { this.sub.unsubscribe(); }
```

### Error Handling Decision Tree

```
Error occurs in stream
    ├─ Can recover with fallback value? → catchError(() => of(fallback))
    ├─ Should retry automatically?     → retry({ count: 3, delay: 1000 })
    ├─ Should ignore and continue?     → catchError(() => EMPTY)
    ├─ Should rethrow for caller?      → catchError(err => throwError(() => err))
    └─ Inside switchMap (keep stream)? → inner pipe(catchError(() => of(null)))
```

---

*Generated for interview preparation — covers RxJS 7/8 with Angular 15-17+ patterns.*

---

# ⚖️ RxJS Comparisons — Side-by-Side Differences

---

## RX-C1 — `map` vs `switchMap` vs `mergeMap` vs `concatMap` vs `exhaustMap`

| | `map` | `switchMap` | `mergeMap` | `concatMap` | `exhaustMap` |
|-|-------|------------|-----------|------------|-------------|
| Input → Output | Value → Value | Observable → Observable | Observable → Observable | Observable → Observable | Observable → Observable |
| Concurrency | N/A | Cancels previous | ✅ All concurrent | Sequential (queue) | Ignores new until current done |
| Use for | Simple transform | Search autocomplete, navigation | Parallel HTTP calls | Ordered sequential calls | Login button (ignore double clicks) |
| Memory | N/A | Low (cancels) | Can accumulate | Sequential | Low (ignores) |

```typescript
// map — transform value (sync)
search$.pipe(
  map(term => term.toUpperCase())
);

// switchMap — cancel previous inner observable on new emission
searchInput$.pipe(
  debounceTime(300),
  switchMap(term => this.http.get(`/search?q=${term}`))
  // If user types again while request is in-flight → previous request cancelled
);

// mergeMap — all inner observables run concurrently
userIds$.pipe(
  mergeMap(id => this.http.get(`/users/${id}`))
  // All requests fire simultaneously, results arrive in any order
);

// concatMap — queue: wait for each to complete before starting next
actions$.pipe(
  concatMap(action => this.http.post('/log', action))
  // Actions logged in order, one at a time
);

// exhaustMap — ignore new emissions while inner is active
loginButton$.pipe(
  exhaustMap(() => this.auth.login(credentials))
  // Double-click ignored — only first click processed until login completes
);
```

---

## RX-C2 — `debounceTime` vs `throttleTime` vs `auditTime` vs `sampleTime`

| | `debounceTime(n)` | `throttleTime(n)` | `auditTime(n)` | `sampleTime(n)` |
|-|-----------------|-----------------|----------------|----------------|
| Emits | After n ms of silence | First event, then silence | Last event after n ms window | Latest value every n ms |
| Rapid events | Waits until pause | Emits first, silences rest | Emits last | Emits latest at interval |
| Use for | Search autocomplete | Scroll/resize handlers | UI updates | Periodic polling |

```typescript
// debounceTime — wait for typing to stop
searchInput.valueChanges.pipe(
  debounceTime(400), // only search after 400ms of no typing
  switchMap(term => this.searchService.search(term))
);

// throttleTime — limit scroll events
fromEvent(window, 'scroll').pipe(
  throttleTime(100) // handle scroll max once per 100ms
);
```

---

## RX-C3 — `takeUntil` vs `takeWhile` vs `take` vs `first`

| | `take(n)` | `first(predicate?)` | `takeUntil(signal$)` | `takeWhile(condition)` |
|-|----------|-------------------|---------------------|----------------------|
| Completes after | n emissions | First matching | Signal emits | Condition is false |
| Auto-unsubscribe | ✅ | ✅ | ✅ | ✅ |
| Error if no match | ❌ | ✅ (by default) | ❌ | ❌ |

```typescript
// takeUntil — most common pattern for component cleanup
export class MyComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit() {
    this.orderService.orders$.pipe(
      takeUntil(this.destroy$) // auto-unsubscribe on destroy
    ).subscribe(orders => this.orders = orders);
  }

  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

// Angular 16+ — takeUntilDestroyed (cleaner)
orders$ = this.orderService.orders$.pipe(
  takeUntilDestroyed(this.destroyRef) // inject DestroyRef
);
```

---

## RX-C4 — `combineLatest` vs `forkJoin` vs `zip` vs `withLatestFrom`

| | `combineLatest` | `forkJoin` | `zip` | `withLatestFrom` |
|-|----------------|-----------|-------|-----------------|
| Emits when | Any source emits (all have emitted at least once) | All sources complete | All emit in sync pairs | Source emits (uses latest from other) |
| Requires completion | ❌ | ✅ | ❌ | ❌ |
| Use for | Live combined state | Parallel HTTP (fire and wait) | Strict pairing | Snapshot of another stream |

```typescript
// combineLatest — reactive dashboard (emits on any change)
combineLatest([user$, settings$, permissions$]).pipe(
  map(([user, settings, permissions]) => ({ user, settings, permissions }))
).subscribe(state => this.updateUI(state));

// forkJoin — parallel HTTP calls, wait for all to complete
forkJoin({
  user: this.http.get('/api/user'),
  orders: this.http.get('/api/orders'),
  config: this.http.get('/api/config')
}).subscribe(({ user, orders, config }) => this.init(user, orders, config));

// withLatestFrom — take snapshot of currentUser when action fires
saveButton$.pipe(
  withLatestFrom(this.currentUser$), // doesn't subscribe to user$, just peeks
  switchMap(([_, user]) => this.save({ ...formData, userId: user.id }))
);
```

---

## RX-C5 — Hot vs Cold Observables

| | Cold Observable | Hot Observable |
|-|----------------|----------------|
| Data producer | Created per subscriber | Shared, exists independently |
| Each subscriber | Gets own data stream from start | Gets values from current point onward |
| Examples | `http.get()`, `of()`, `from()` | `Subject`, DOM events, WebSocket |
| Multicast | ❌ (each sub triggers new HTTP call) | ✅ (all subs share same stream) |

```typescript
// Cold — each subscriber gets own HTTP call
const orders$ = this.http.get('/api/orders');
orders$.subscribe(x => console.log('Sub1:', x)); // makes HTTP call
orders$.subscribe(x => console.log('Sub2:', x)); // makes ANOTHER HTTP call!

// Hot — share single HTTP call with shareReplay
const sharedOrders$ = this.http.get('/api/orders').pipe(shareReplay(1));
sharedOrders$.subscribe(x => console.log('Sub1:', x)); // HTTP call made
sharedOrders$.subscribe(x => console.log('Sub2:', x)); // gets cached value — no extra call

// Hot — Subject (always hot)
const clicks$ = new Subject<MouseEvent>();
document.addEventListener('click', e => clicks$.next(e));
// All subscribers share same click stream
```

---

## RX-C6 — `catchError` vs `retry` vs `retryWhen` vs `onErrorResumeNext`

| | `catchError` | `retry(n)` | `retryWhen` | `onErrorResumeNext` |
|-|------------|-----------|------------|---------------------|
| On error | Replace with fallback observable | Resubscribe n times | Resubscribe with custom logic | Continue with next observable |
| Stream terminates | With replacement | After n retries | Based on notifier | Completes normally |
| Use for | Fallback data, graceful error | Transient errors | Backoff retry strategy | Fire-and-forget sequences |

```typescript
this.http.get('/api/orders').pipe(
  retry(3),  // retry 3 times on error
  catchError(err => {
    this.log.error(err);
    return of([]); // return empty array as fallback
  })
);

// Exponential backoff retry
this.http.get('/api/data').pipe(
  retryWhen(errors$ => errors$.pipe(
    delayWhen((_, i) => timer(Math.pow(2, i) * 1000)), // 1s, 2s, 4s delays
    take(4) // max 4 retries
  ))
);
```


---

# ⚖️ RxJS Comparisons — Side-by-Side Differences

---

## RX-C1 — `switchMap` vs `mergeMap` vs `concatMap` vs `exhaustMap`

This is the **most asked RxJS interview question**. All four flatten inner Observables but handle concurrency differently.

| | `switchMap` | `mergeMap` (flatMap) | `concatMap` | `exhaustMap` |
|-|------------|---------------------|-------------|-------------|
| Concurrency | Cancels previous inner | All run concurrently | One at a time, queued | Ignores new until current completes |
| Order | ❌ Not guaranteed | ❌ Not guaranteed | ✅ FIFO guaranteed | ❌ Not guaranteed |
| Memory | Low (only last active) | ❌ Unbounded concurrent | Low (only one) | Low (only one) |
| Use for | Search autocomplete, latest-wins | Parallel independent tasks | Sequential tasks, upload queue | Login button (ignore spam clicks) |

```ts
// switchMap — cancel previous, only care about latest (typeahead search)
this.searchInput.valueChanges.pipe(
  debounceTime(300),
  switchMap(term => this.http.get(`/api/search?q=${term}`))
  // If user types fast, old requests cancelled — only last one matters
).subscribe(results => this.results = results);

// mergeMap — all concurrent, order not preserved (parallel uploads)
from(files).pipe(
  mergeMap(file => this.uploadService.upload(file)) // all upload simultaneously
).subscribe(result => this.onFileUploaded(result));

// concatMap — queued sequentially, order preserved (ordered payment steps)
from(paymentSteps).pipe(
  concatMap(step => this.processStep(step)) // step 2 waits for step 1
).subscribe();

// exhaustMap — ignores new events while busy (login button debounce)
this.loginBtn.clicks.pipe(
  exhaustMap(() => this.auth.login(this.form.value))
  // Double-click ignored — login already in progress
).subscribe(user => this.onLoggedIn(user));
```

---

## RX-C2 — `map` vs `tap` vs `filter` vs `scan`

| | `map` | `tap` | `filter` | `scan` |
|-|-------|-------|---------|--------|
| Transforms value | ✅ | ❌ (passthrough) | ❌ | ✅ (accumulates) |
| Side effects | ❌ | ✅ Purpose: side effects | ❌ | ❌ |
| Filters items | ❌ | ❌ | ✅ | ❌ |
| Stateful | ❌ | ❌ | ❌ | ✅ (accumulator) |

```ts
source$.pipe(
  tap(v => console.log('Before map:', v)),    // side-effect, doesn't change value
  map(v => v * 2),                            // transforms each value
  filter(v => v > 10),                        // drops values below threshold
  scan((acc, v) => acc + v, 0)               // running total (like reduce but emits each step)
).subscribe(total => this.runningTotal = total);
```

---

## RX-C3 — `combineLatest` vs `zip` vs `forkJoin` vs `withLatestFrom`

| | `combineLatest` | `zip` | `forkJoin` | `withLatestFrom` |
|-|----------------|-------|-----------|----------------|
| Emits when | Any source emits (after all emitted once) | All sources emit together | All sources complete | Source emits + latest from other |
| Number of emissions | Multiple | Paired | Once (on complete) | Source-driven |
| Use for | Live dashboard combining streams | Paired sequences | Parallel HTTP calls | Event + current state |

```ts
// combineLatest — re-emits whenever any changes (dashboard)
combineLatest([price$, quantity$]).pipe(
  map(([price, qty]) => price * qty)
).subscribe(total => this.total = total);

// forkJoin — wait for ALL to complete, emit once (parallel HTTP)
forkJoin({
  user:     this.http.get('/api/user'),
  orders:   this.http.get('/api/orders'),
  settings: this.http.get('/api/settings')
}).subscribe(({ user, orders, settings }) => {
  this.initPage(user, orders, settings);
});

// withLatestFrom — trigger from source, sample latest from other
this.saveBtn.clicks.pipe(
  withLatestFrom(this.formValues$) // take current form value on each click
).subscribe(([_, formValue]) => this.save(formValue));
```

---

## RX-C4 — `takeUntil` vs `takeWhile` vs `take` vs `first`

| | `take(n)` | `first(pred?)` | `takeWhile(pred)` | `takeUntil(notifier$)` |
|-|----------|---------------|------------------|----------------------|
| Completes after | n items | 1 item | Condition becomes false | Notifier emits |
| Unsubscribes | ✅ Auto | ✅ Auto | ✅ Auto | ✅ Auto |
| Use for | Limit stream | Get first value | While-loop semantics | Component destroy cleanup |

```ts
// takeUntil — essential for preventing memory leaks in Angular
@Component({...})
export class MyComponent implements OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit() {
    this.dataService.stream$.pipe(
      takeUntil(this.destroy$)  // auto-unsubscribe on destroy
    ).subscribe(data => this.data = data);
  }

  ngOnDestroy() { this.destroy$.next(); this.destroy$.complete(); }
}

// Angular 16+ takeUntilDestroyed — no manual Subject needed
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
this.dataService.stream$.pipe(
  takeUntilDestroyed(this.destroyRef) // auto from DestroyRef
).subscribe(data => this.data = data);
```

---

## RX-C5 — `catchError` vs `retry` vs `retryWhen` vs `onErrorResumeNext`

| | `catchError` | `retry(n)` | `retryWhen` | `onErrorResumeNext` |
|-|-------------|-----------|------------|-------------------|
| On error | Replace with fallback | Resubscribe n times | Resubscribe with custom logic | Continue with next Observable |
| Completes stream | ❌ (continues with fallback) | After n retries | Depends | After source errors |

```ts
this.http.get('/api/data').pipe(
  retry(3),                        // retry up to 3 times on error
  catchError(err => {
    console.error(err);
    return of([]);                 // fallback to empty array — stream continues
  })
).subscribe(data => this.data = data);

// retryWhen with exponential backoff
this.http.get('/api/data').pipe(
  retryWhen(errors => errors.pipe(
    delayWhen((_, i) => timer(Math.pow(2, i) * 1000)) // 1s, 2s, 4s delays
  ))
).subscribe();
```

---

## RX-C6 — Hot vs Cold Observables

| | Cold Observable | Hot Observable |
|-|----------------|---------------|
| Data producer | Created per subscriber | Shared, exists independently |
| Unicast/Multicast | Unicast (each subscriber gets own stream) | Multicast (all subscribers share) |
| Late subscribers | Get all values from start | Miss past values |
| Examples | `http.get()`, `of()`, `from()` | `Subject`, `fromEvent()`, WebSocket |

```ts
// Cold — each subscriber triggers a new HTTP request
const cold$ = this.http.get('/api/data');
cold$.subscribe(d => console.log('A', d)); // triggers HTTP request #1
cold$.subscribe(d => console.log('B', d)); // triggers HTTP request #2

// Hot — all subscribers share the same WebSocket
const hot$ = new Subject<Message>();
webSocket.onmessage = (msg) => hot$.next(msg);
hot$.subscribe(m => console.log('A', m)); // share the connection
hot$.subscribe(m => console.log('B', m)); // same messages, no extra connection

// Make cold hot: share() operator
const shared$ = this.http.get('/api/data').pipe(share());
shared$.subscribe(d => console.log('A', d)); // triggers ONE HTTP request
shared$.subscribe(d => console.log('B', d)); // reuses same request
```

