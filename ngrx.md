# 🏪 NgRx Interview Questions — Complete Guide

> **100+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Core Concepts & Store](#1-core-concepts--store)
2. [Actions](#2-actions)
3. [Reducers](#3-reducers)
4. [Selectors](#4-selectors)
5. [Effects](#5-effects)
6. [NgRx Entity](#6-ngrx-entity)
7. [Router Store](#7-router-store)
8. [Component Store](#8-component-store)
9. [Testing NgRx](#9-testing-ngrx)
10. [Patterns & Best Practices](#10-patterns--best-practices)

---

## 1. Core Concepts & Store

> 📚 Reference: https://ngrx.io/guide/store
> 📚 Medium: https://medium.com/angular-in-depth/ngrx-store-understanding-state-selectors-actions-effects-f0b58ded56ac

### Q1. What is NgRx and the Redux pattern? What are the 3 core Redux principles, and when should you choose NgRx over a plain service + BehaviorSubject?

**Answer:** NgRx is a reactive state management library for Angular built on the Redux pattern and powered by RxJS. Redux follows three core principles: (1) Single source of truth — the entire application state lives in one store; (2) State is read-only — the only way to change state is to dispatch an action; (3) Changes are made with pure functions — reducers take the previous state and an action and return a new state. Choose NgRx over a BehaviorSubject service when your app has complex shared state, many components need the same data, you need time-travel debugging, or multiple async operations interact with the same state slice. For simple, localised state a BehaviorSubject service is lighter and easier.

❌ **Violates** — Mutating state directly inside a service, bypassing the Redux flow:
```typescript
// BAD: direct mutation, no action, no reducer, no time-travel
@Injectable({ providedIn: 'root' })
export class ProductService {
  products: Product[] = []; // mutable public field

  addProduct(p: Product) {
    this.products.push(p); // mutation — cannot be tracked or replayed
  }
}
```

✅ **Satisfies** — Redux flow: dispatch action → reducer produces new state → selector reads it:
```typescript
// 1. Action
export const addProduct = createAction('[Products] Add Product', props<{ product: Product }>());

// 2. Reducer — pure function, returns new state
export const productsReducer = createReducer(
  initialState,
  on(addProduct, (state, { product }) => ({
    ...state,
    products: [...state.products, product]
  }))
);

// 3. Component dispatches
this.store.dispatch(addProduct({ product: newProduct }));
```

---

### Q2. How do you set up the NgRx Store in a module-based app (StoreModule.forRoot, StoreModule.forFeature) vs a standalone app (provideStore, provideState)? Show both.

**Answer:** In module-based apps, you register the root store with `StoreModule.forRoot(reducers)` in `AppModule` and feature slices with `StoreModule.forFeature('featureName', featureReducer)` in the feature module. In standalone Angular apps (Angular 14+), you use `provideStore(reducers)` in `bootstrapApplication` providers and `provideState('featureName', featureReducer)` in the route's providers array. Both approaches achieve the same result — a single global store with lazy-loaded feature slices. Prefer standalone for new Angular 17+ projects.

❌ **Violates** — Calling `StoreModule.forRoot` in a lazy-loaded feature module (causes the store to reset):
```typescript
// BAD: forRoot inside a feature module
@NgModule({
  imports: [
    StoreModule.forRoot({ products: productsReducer }) // ❌ should be forFeature
  ]
})
export class ProductsModule {}
```

✅ **Satisfies** — Module-based and standalone setup:
```typescript
// ===== MODULE-BASED =====
// app.module.ts
@NgModule({
  imports: [
    StoreModule.forRoot({ router: routerReducer }, {
      metaReducers,
      runtimeChecks: { strictStateImmutability: true, strictActionImmutability: true }
    }),
    StoreDevtoolsModule.instrument({ maxAge: 25 })
  ]
})
export class AppModule {}

// products.module.ts (feature)
@NgModule({
  imports: [
    StoreModule.forFeature('products', productsReducer),
    EffectsModule.forFeature([ProductsEffects])
  ]
})
export class ProductsModule {}

// ===== STANDALONE =====
// main.ts
bootstrapApplication(AppComponent, {
  providers: [
    provideStore({ router: routerReducer }, { metaReducers }),
    provideStoreDevtools({ maxAge: 25 }),
    provideEffects()
  ]
});

// products.routes.ts — lazy loaded route
export const PRODUCTS_ROUTES: Routes = [{
  path: '',
  component: ProductsComponent,
  providers: [
    provideState('products', productsReducer),
    provideEffects(ProductsEffects)
  ]
}];
```

---

### Q3. How should you design your state shape? What belongs in the store vs component state vs URL? Why is flat/normalised state better than deeply nested?

**Answer:** Put in the NgRx store only state that is shared across multiple components, needs to survive navigation, or is driven by async server data. Keep transient UI state (form validity, hover states, open/closed toggles) in component state. Put pagination, filters, and selected IDs in the URL so they are bookmarkable and shareable. Flat, normalised state stores entities as a dictionary keyed by ID (like a database table) with other slices holding only IDs as references — this avoids deeply nested updates, eliminates data duplication, and makes lookups O(1). Deeply nested state requires complex spread chains to update a single field and risks inconsistency when the same entity appears in multiple places.

❌ **Violates** — Deeply nested, denormalised state with duplicate data:
```typescript
// BAD: order contains full customer and full product objects
interface AppState {
  orders: {
    list: Array<{
      id: string;
      customer: { id: string; name: string; email: string }; // duplicated
      items: Array<{
        product: { id: string; name: string; price: number }; // duplicated
        quantity: number;
      }>;
    }>;
  };
}
```

✅ **Satisfies** — Flat, normalised state with ID references:
```typescript
// GOOD: each entity type lives in its own flat slice
interface AppState {
  orders: {
    ids: string[];
    entities: Record<string, Order>; // Order has customerId, itemIds
  };
  customers: {
    ids: string[];
    entities: Record<string, Customer>;
  };
  products: {
    ids: string[];
    entities: Record<string, Product>;
  };
}

interface Order {
  id: string;
  customerId: string; // reference only
  itemIds: string[];  // reference only
  status: OrderStatus;
}

// Join in a selector — not in the state
export const selectOrderWithDetails = createSelector(
  selectCurrentOrder,
  selectCustomerEntities,
  selectProductEntities,
  (order, customers, products) => ({
    ...order,
    customer: customers[order.customerId],
    items: order.itemIds.map(id => products[id])
  })
);
```

---

### Q4. How do you read state from the store using store.select()? How does the async pipe work with it, and why should you avoid manual subscribe/unsubscribe in components?

**Answer:** `store.select(selector)` returns an Observable that emits a new value every time the selected slice of state changes. The Angular `async` pipe subscribes to that Observable in the template, automatically unsubscribes when the component is destroyed, and triggers change detection only when a new value arrives. Manual `subscribe()` calls in components require you to track the subscription and call `unsubscribe()` in `ngOnDestroy`, or use `takeUntil` — forgetting either causes memory leaks. The async pipe eliminates this entire class of bugs and pairs perfectly with `OnPush` change detection.

❌ **Violates** — Manual subscribe without cleanup, causing a memory leak:
```typescript
// BAD: subscription never unsubscribed
@Component({ template: `<div>{{ products.length }} products</div>` })
export class ProductsComponent implements OnInit {
  products: Product[] = [];

  constructor(private store: Store) {}

  ngOnInit() {
    // Leak: this subscription lives forever
    this.store.select(selectAllProducts).subscribe(p => this.products = p);
  }
}
```

✅ **Satisfies** — async pipe handles subscription lifecycle automatically:
```typescript
@Component({
  template: `
    <ng-container *ngIf="products$ | async as products">
      <div>{{ products.length }} products</div>
      <app-product-card *ngFor="let p of products" [product]="p" />
    </ng-container>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductsComponent {
  products$ = this.store.select(selectAllProducts);
  isLoading$ = this.store.select(selectProductsLoading);
  error$ = this.store.select(selectProductsError);

  constructor(private store: Store) {}
}
```

---

### Q5. How do you dispatch actions using store.dispatch()? Show dispatching on component init, on button click, and from a service.

**Answer:** `store.dispatch(action)` sends an action object into the store, which passes through all meta-reducers, then all reducers, and then all effects. You call it with the result of an action creator function. You can dispatch from anywhere that has the `Store` injected: a component lifecycle hook, an event handler, a service method, or even another effect. The convention is to dispatch from components for user events and from effects for chained async operations.

❌ **Violates** — Dispatching a raw object instead of using the typed action creator:
```typescript
// BAD: no type safety, typos go undetected at compile time
this.store.dispatch({ type: 'Load Prodcuts' }); // typo, wrong format
```

✅ **Satisfies** — Dispatching from lifecycle, button click, and service:
```typescript
// products.component.ts
@Component({ template: `<button (click)="onAdd()">Add</button>` })
export class ProductsComponent implements OnInit {
  constructor(private store: Store) {}

  // On init — load data
  ngOnInit() {
    this.store.dispatch(ProductsActions.loadProducts());
  }

  // On button click — user event
  onAdd() {
    this.store.dispatch(ProductsActions.openAddProductDialog());
  }

  onDelete(id: string) {
    this.store.dispatch(ProductsActions.deleteProduct({ id }));
  }
}

// products-api.service.ts — dispatch from a service
@Injectable({ providedIn: 'root' })
export class ProductsApiService {
  constructor(private store: Store) {}

  refreshAfterSync() {
    // A service can dispatch when external events happen (e.g. WebSocket message)
    this.store.dispatch(ProductsActions.loadProducts());
  }
}
```

---

### Q6. How do you set up NgRx DevTools (StoreDevtoolsModule / provideStoreDevtools)? What is time-travel debugging, and what can you do in the Redux DevTools panel?

**Answer:** NgRx DevTools connects to the Redux DevTools browser extension to give you a live view of every dispatched action and the resulting state tree. In module-based apps, add `StoreDevtoolsModule.instrument({ maxAge: 25, logOnly: environment.production })` to `AppModule`. In standalone apps use `provideStoreDevtools(...)`. Time-travel debugging lets you click any past action in the history list and the UI reverts to exactly what the state looked like at that point — without re-running the app. In the DevTools panel you can inspect action payloads, diff state before/after each action, replay action sequences, import/export state snapshots, and skip individual actions to test different flows.

❌ **Violates** — Enabling full DevTools in production, leaking state to the browser:
```typescript
// BAD: full devtools in production — exposes entire app state
StoreDevtoolsModule.instrument({ maxAge: 100 }) // no production guard
```

✅ **Satisfies** — DevTools setup with production guard:
```typescript
// Module-based
@NgModule({
  imports: [
    StoreModule.forRoot(reducers),
    StoreDevtoolsModule.instrument({
      maxAge: 25,              // keep last 25 actions
      logOnly: environment.production, // read-only in prod
      autoPause: true,         // pause when devtools closed
      trace: false,
      traceLimit: 75
    })
  ]
})
export class AppModule {}

// Standalone (main.ts)
bootstrapApplication(AppComponent, {
  providers: [
    provideStore(reducers),
    provideStoreDevtools({
      maxAge: 25,
      logOnly: !isDevMode(),
      connectInZone: true
    })
  ]
});
```

---

### Q7. What are meta-reducers? Show a logging meta-reducer and a hydration meta-reducer that restores state from localStorage on startup.

**Answer:** A meta-reducer is a higher-order reducer — a function that takes a reducer and returns a new reducer, wrapping it to add cross-cutting behaviour. They run before the actual reducers, in order, for every dispatched action. Common uses include logging every action, resetting all state on logout, and hydrating state from localStorage on startup. Meta-reducers are registered in the `metaReducers` array passed to `StoreModule.forRoot` or `provideStore`.

❌ **Violates** — Performing side effects (localStorage write) inside the reducer instead of a meta-reducer:
```typescript
// BAD: side effects in reducer — impure, hard to test
on(saveSuccess, (state, action) => {
  localStorage.setItem('state', JSON.stringify(state)); // ❌ side effect
  return { ...state, saved: true };
})
```

✅ **Satisfies** — Logging meta-reducer and hydration meta-reducer:
```typescript
// logging.meta-reducer.ts
export function loggingMetaReducer(reducer: ActionReducer<AppState>): ActionReducer<AppState> {
  return (state, action) => {
    console.group(action.type);
    console.log('prev state', state);
    const nextState = reducer(state, action);
    console.log('next state', nextState);
    console.groupEnd();
    return nextState;
  };
}

// hydration.meta-reducer.ts
export function hydrationMetaReducer(reducer: ActionReducer<AppState>): ActionReducer<AppState> {
  return (state, action) => {
    if (action.type === INIT || action.type === UPDATE) {
      const stored = localStorage.getItem('appState');
      if (stored) {
        try {
          return JSON.parse(stored) as AppState;
        } catch {
          localStorage.removeItem('appState');
        }
      }
    }
    const nextState = reducer(state, action);
    localStorage.setItem('appState', JSON.stringify(nextState));
    return nextState;
  };
}

// app.module.ts
export const metaReducers: MetaReducer<AppState>[] = !environment.production
  ? [loggingMetaReducer, hydrationMetaReducer]
  : [hydrationMetaReducer];

@NgModule({
  imports: [StoreModule.forRoot(reducers, { metaReducers })]
})
export class AppModule {}
```

---

### Q8. What is AppState / RootState? How do you combine feature state interfaces using ActionReducerMap?

**Answer:** `AppState` (also called `RootState`) is a TypeScript interface that represents the shape of the entire store. Each key in `AppState` corresponds to a feature slice, and its value type is that feature's state interface. `ActionReducerMap<AppState>` is a typed object that maps each key to its corresponding reducer function — NgRx uses this to combine all reducers into one root reducer internally. Defining this interface gives you type-safe access throughout the codebase.

❌ **Violates** — Using `any` for the state type, losing all type safety:
```typescript
// BAD: any state — no autocomplete, no compile-time checking
const store: Store<any> = inject(Store);
store.select((s: any) => s.products.items); // no type checking
```

✅ **Satisfies** — Typed AppState and ActionReducerMap:
```typescript
// app.state.ts
import { RouterReducerState } from '@ngrx/router-store';
import { ProductsState } from './products/products.state';
import { AuthState } from './auth/auth.state';

export interface AppState {
  router: RouterReducerState;
  products: ProductsState;
  auth: AuthState;
}

// app.reducers.ts
import { ActionReducerMap } from '@ngrx/store';

export const reducers: ActionReducerMap<AppState> = {
  router: routerReducer,
  products: productsReducer,
  auth: authReducer
};

// Feature state is merged automatically when using forFeature
export interface ProductsState {
  ids: string[];
  entities: Record<string, Product>;
  isLoading: boolean;
  error: string | null;
}
```

---

### Q9. Why is immutability a strict requirement in NgRx reducers? Show the spread-based immutable update pattern for objects and arrays. What goes wrong if you mutate state directly?

**Answer:** NgRx selectors use reference equality checks (`===`) to detect changes — if you mutate the existing state object, the reference does not change, so the selector sees the same object and does not emit a new value, meaning the UI never updates. Additionally, time-travel debugging depends on having distinct immutable snapshots for each action; mutation corrupts these snapshots. Angular's `OnPush` change detection also relies on reference changes to know when to re-render. NgRx's `strictStateImmutability` runtime check will throw if you mutate, helping catch bugs early.

❌ **Violates** — Direct mutation inside a reducer:
```typescript
// BAD: mutates existing state, reference unchanged, UI won't update
on(updateProduct, (state, { product }) => {
  const existing = state.entities[product.id];
  existing.name = product.name; // ❌ mutation
  existing.price = product.price; // ❌ mutation
  return state; // same reference — selector won't fire
})
```

✅ **Satisfies** — Immutable spread patterns for objects and arrays:
```typescript
// Updating a property on a nested object
on(updateProduct, (state, { product }) => ({
  ...state,
  entities: {
    ...state.entities,
    [product.id]: { ...state.entities[product.id], ...product }
  }
})),

// Adding to an array
on(addTag, (state, { tag }) => ({
  ...state,
  tags: [...state.tags, tag]
})),

// Removing from an array by id
on(removeTag, (state, { id }) => ({
  ...state,
  tags: state.tags.filter(t => t.id !== id)
})),

// Updating one item in an array
on(toggleTag, (state, { id }) => ({
  ...state,
  tags: state.tags.map(t => t.id === id ? { ...t, active: !t.active } : t)
}))
```

---

### Q10. How does NgRx integrate with OnPush change detection? Why does store.select() + async pipe + OnPush give the best performance?

**Answer:** `ChangeDetectionStrategy.OnPush` tells Angular to only run change detection for a component when its `@Input` references change, an event fires within it, or an Observable bound with the `async` pipe emits. `store.select(selector)` only emits when the selected value changes (memoised by the selector), so the `async` pipe only triggers change detection when the data actually changes — not on every global change detection cycle. This combination means large lists and dashboards only re-render the components whose data changed, dramatically reducing unnecessary DOM work in complex applications.

❌ **Violates** — Default change detection with manual subscribe re-renders everything constantly:
```typescript
// BAD: Default CD, manual subscribe — re-renders on every CD cycle
@Component({
  // no changeDetection: ChangeDetectionStrategy.OnPush
  template: `<div *ngFor="let p of products">{{ p.name }}</div>`
})
export class ProductsComponent implements OnInit, OnDestroy {
  products: Product[] = [];
  private sub!: Subscription;

  ngOnInit() { this.sub = this.store.select(selectAllProducts).subscribe(p => this.products = p); }
  ngOnDestroy() { this.sub.unsubscribe(); }
}
```

✅ **Satisfies** — OnPush + async pipe, renders only when data changes:
```typescript
@Component({
  selector: 'app-products',
  template: `
    <ng-container *ngIf="vm$ | async as vm">
      <app-loading *ngIf="vm.isLoading" />
      <app-error *ngIf="vm.error" [message]="vm.error" />
      <app-product-card
        *ngFor="let p of vm.products; trackBy: trackById"
        [product]="p"
      />
    </ng-container>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush // ✅ only re-render when vm$ emits
})
export class ProductsComponent implements OnInit {
  vm$ = combineLatest({
    products: this.store.select(selectAllProducts),
    isLoading: this.store.select(selectProductsLoading),
    error: this.store.select(selectProductsError)
  });

  constructor(private store: Store) {}
  ngOnInit() { this.store.dispatch(ProductsActions.loadProducts()); }
  trackById(_: number, p: Product) { return p.id; }
}
```

---
