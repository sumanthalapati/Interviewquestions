# 🔷 TypeScript Interview Questions — Complete Guide

> **100+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Type System Fundamentals](#1-type-system-fundamentals)
2. [Interfaces & Type Aliases](#2-interfaces--type-aliases)
3. [Generics](#3-generics)
4. [Utility Types](#4-utility-types)
5. [Classes & OOP](#5-classes--oop)
6. [Type Guards & Narrowing](#6-type-guards--narrowing)
7. [Enums & Const Assertions](#7-enums--const-assertions)
8. [Modules & Declaration Files](#8-modules--declaration-files)
9. [Advanced Types](#9-advanced-types)
10. [tsconfig & Compiler Options](#10-tsconfig--compiler-options)

---

# 1. Type System Fundamentals

---

## 1.1 Primitive Types, any, unknown, never

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/2/everyday-types.html
> 📚 Medium: https://medium.com/swlh/typescript-types-advanced-tutorial-f3d43c3ab1f1

### Q1. What are TypeScript's primitive types and how does type inference work? What is the difference between `any`, `unknown`, and `never`, and when should you use each?

**Answer:**
TypeScript primitives are `string`, `number`, `boolean`, `null`, `undefined`, `symbol`, and `bigint`. Type inference lets the compiler deduce types automatically — use explicit annotations only when inference is too broad, when declaring without initializing, or for function return types. `any` completely disables type checking (avoid it). `unknown` is the type-safe counterpart — you must narrow it before use. `never` represents values that can never exist: the return type of a function that always throws, or the type of an exhausted union. `void` is used for functions that intentionally return nothing — distinct from `undefined` in that you cannot assign a `void` expression to a non-void variable in strict mode.

❌ **Violates — `any` silently kills safety:**
```typescript
let user: any = getUser();
user.nonExistent.doSomething(); // No compile error — crashes at runtime ❌

function process(value: any) {
  value.toUpperCase(); // TypeScript won't catch this if value is a number ❌
}
```

✅ **Satisfies — use `unknown` and narrow before use:**
```typescript
const name = 'Alice';   // inferred: string ✅
const count = 0;        // inferred: number ✅

function process(value: unknown): string {
  if (typeof value === 'string') return value.toUpperCase();
  if (typeof value === 'number') return value.toFixed(2);
  throw new Error('Unsupported type');
}

type Status = 'active' | 'inactive' | 'pending';
function label(s: Status): string {
  if (s === 'active')   return 'Active';
  if (s === 'inactive') return 'Inactive';
  if (s === 'pending')  return 'Pending';
  const _check: never = s; // TS errors if a new Status is added but not handled ✅
  return _check;
}
```

---

### Q2. What are union (`|`) and intersection (`&`) types? How do they combine types and what are real-world use cases?

**Answer:**
A union type `A | B` means a value can be either `A` or `B` — you can only safely access members common to both without narrowing. An intersection type `A & B` means a value must satisfy both `A` and `B` simultaneously — it has all members of both. Unions model "one of several possibilities" (e.g., API responses, discriminated unions). Intersections model "combining multiple shapes" (e.g., mixins, extending base types without interface inheritance). Be cautious: intersecting two primitive types like `string & number` produces `never`.

❌ **Violates — accessing union member without narrowing:**
```typescript
type Result = { data: string } | { error: Error };

function handle(r: Result) {
  console.log(r.data); // ❌ Error: 'data' does not exist on type '{ error: Error }'
}
```

✅ **Satisfies — union with narrowing, intersection for composition:**
```typescript
type ApiSuccess = { status: 'ok'; data: string };
type ApiError   = { status: 'error'; message: string };
type ApiResult  = ApiSuccess | ApiError;

function handle(r: ApiResult) {
  if (r.status === 'ok') {
    console.log(r.data);    // ✅ narrowed to ApiSuccess
  } else {
    console.log(r.message); // ✅ narrowed to ApiError
  }
}

type Loggable  = { log(): void };
type Serializable = { serialize(): string };
type Service   = Loggable & Serializable; // must have both methods ✅

function use(s: Service) {
  s.log();
  s.serialize();
}
```

---

### Q3. What are literal types and const assertions (`as const`)? How do they prevent type widening?

**Answer:**
Literal types restrict a variable to a specific value rather than its general type — `'GET'` instead of `string`, `42` instead of `number`. Without `as const`, TypeScript widens array and object literals to their general types (e.g., `{ method: 'GET' }` becomes `{ method: string }`). The `as const` assertion freezes the entire structure to its narrowest literal types and makes all properties `readonly`. This is essential when passing object literals to functions that expect discriminated unions or literal-typed parameters.

❌ **Violates — widening produces incorrect types:**
```typescript
const config = { method: 'GET', retries: 3 };
// Inferred as: { method: string; retries: number } — too wide!

function fetch(method: 'GET' | 'POST') {}
fetch(config.method); // ❌ Error: Argument of type 'string' not assignable to 'GET' | 'POST'
```

✅ **Satisfies — `as const` locks types to literals:**
```typescript
const config = { method: 'GET', retries: 3 } as const;
// Inferred as: { readonly method: 'GET'; readonly retries: 3 }

function fetch(method: 'GET' | 'POST') {}
fetch(config.method); // ✅ 'GET' is assignable

const DIRECTIONS = ['north', 'south', 'east', 'west'] as const;
type Direction = typeof DIRECTIONS[number]; // 'north' | 'south' | 'east' | 'west' ✅
```

---

### Q4. What are type assertions (`as`), the non-null assertion operator (`!`), and the `satisfies` operator (TS 4.9+)? When is each appropriate?

**Answer:**
`as T` tells TypeScript to treat a value as type `T`, bypassing inference — use it only when you know more than the compiler (e.g., after a DOM query). It does not perform runtime conversion. The non-null assertion `!` removes `null | undefined` from a type — use it sparingly when you are certain a value is defined, such as after a DOM lookup that you know will succeed. The `satisfies` operator (TS 4.9+) validates that a value matches a type without widening the inferred type — you get both type safety and precise inference on the result.

❌ **Violates — `as` used to silence legitimate errors:**
```typescript
const input = document.getElementById('name') as HTMLInputElement;
input.value = 'test'; // Might crash if element doesn't exist or isn't an input ❌

const data = JSON.parse(response) as User; // No runtime validation — dangerous ❌
```

✅ **Satisfies — appropriate use of each operator:**
```typescript
// as: only after guard confirms the type
const el = document.getElementById('name');
if (el instanceof HTMLInputElement) {
  el.value = 'test'; // ✅ narrowed safely, no assertion needed
}

// ! : justified when you control the DOM
const canvas = document.getElementById('canvas')!; // known to exist ✅

// satisfies: validate shape, keep precise inference
const palette = {
  red:   [255, 0, 0],
  green: '#00ff00',
} satisfies Record<string, string | number[]>;

palette.red.at(0);      // ✅ inferred as number[], not string | number[]
palette.green.toUpperCase(); // ✅ inferred as string
```

---

### Q5. What does `strictNullChecks` change? What null-related bugs does it catch? How do optional chaining `?.` and nullish coalescing `??` help?

**Answer:**
Without `strictNullChecks`, `null` and `undefined` are assignable to every type — a major source of runtime errors. With it enabled, `null` and `undefined` are distinct types, so you must handle them explicitly before accessing members. Optional chaining `?.` short-circuits and returns `undefined` if any part of the chain is `null` or `undefined`, instead of throwing. Nullish coalescing `??` provides a fallback only for `null` or `undefined` (not falsy values like `0` or `''`), unlike `||` which catches all falsy values — a subtle but important distinction.

❌ **Violates — null-unsafe code that compiles without `strictNullChecks`:**
```typescript
function getCity(user: User | null): string {
  return user.address.city; // ❌ runtime crash if user is null
}

const port = config.port || 3000; // ❌ returns 3000 even if config.port is 0 (valid port!)
```

✅ **Satisfies — safe null handling with `?.` and `??`:**
```typescript
function getCity(user: User | null): string {
  return user?.address?.city ?? 'Unknown'; // ✅ safe chain + meaningful default
}

const port = config.port ?? 3000; // ✅ only falls back if port is null/undefined, not 0

// Array method safety
const firstAdmin = users?.find(u => u.role === 'admin')?.name ?? 'None';
```

---

### Q6. What are template literal types? How do you build string types like `${string}Id` or `EventName<T>`?

**Answer:**
Template literal types use the same backtick syntax as JavaScript template literals but operate at the type level, constructing new string types from existing ones. They can combine string literals, unions, and type parameters — when a union is used inside a template literal, TypeScript distributes across all members, producing a union of all possible combinations. Built-in string manipulation types like `Capitalize<S>`, `Lowercase<S>`, `Uppercase<S>`, and `Uncapitalize<S>` work alongside them. They are particularly powerful for event systems, CSS-in-JS, and strongly-typed API route building.

❌ **Violates — stringly typed event system with no safety:**
```typescript
function on(event: string, handler: () => void) {} // ❌ any string accepted
on('usr-clck', () => {}); // typo — no error
```

✅ **Satisfies — template literal types for precise string constraints:**
```typescript
type Entity = 'user' | 'product' | 'order';
type EventName<T extends string> = `on${Capitalize<T>}Changed`;
type EntityEvent = EventName<Entity>; // 'onUserChanged' | 'onProductChanged' | 'onOrderChanged'

type IdField<T extends string> = `${T}Id`;
type UserId    = IdField<'user'>;    // 'userId'
type ProductId = IdField<'product'>; // 'productId'

type CSSProperty = `${`margin` | `padding`}-${'top' | 'right' | 'bottom' | 'left'}`;
// 'margin-top' | 'margin-right' | ... | 'padding-bottom' | 'padding-left'

function on<T extends Entity>(event: EventName<T>, handler: () => void) {}
on('onUserChanged', () => {}); // ✅
on('onUserDeleted', () => {}); // ❌ compile error
```

---

### Q7. What are tuple types? How do named tuples, variadic tuples, and rest elements work?

**Answer:**
A tuple is a fixed-length array where each position has a specific type. Unlike a regular array type, tuples enforce both the number and type of elements at each index. Named tuples (TS 4.0+) add labels to improve readability in IDE tooltips without affecting the type behavior. Variadic tuple types allow tuples to be composed using spread syntax with generic type parameters — enabling type-safe function argument concatenation. Rest elements in tuples capture variable-length tails while maintaining the types of leading fixed elements.

❌ **Violates — using plain arrays loses positional type information:**
```typescript
function getRange(): number[] {
  return [0, 100]; // caller doesn't know index 0 is min, index 1 is max
}

const [a, b, c] = getRange(); // c is number (no error) but is undefined at runtime ❌
```

✅ **Satisfies — tuples with named elements and variadic composition:**
```typescript
type Range = [min: number, max: number];
function getRange(): Range { return [0, 100]; }
const [min, max] = getRange(); // ✅ clear semantics

// Rest elements
type StringsAndNumber = [...string[], number];
const t: StringsAndNumber = ['a', 'b', 42]; // ✅

// Variadic tuples for function composition
type Concat<T extends unknown[], U extends unknown[]> = [...T, ...U];
type T1 = Concat<[string, number], [boolean]>; // [string, number, boolean] ✅

// Practical: typed useState-like hook return
type UseState<T> = [state: T, setState: (val: T) => void];
function useState<T>(init: T): UseState<T> {
  let state = init;
  return [state, (val) => { state = val; }];
}
```

---

### Q8. How do function types work in TypeScript? Cover parameter types, return types, optional and default parameters, rest parameters, and overload signatures.

**Answer:**
Function types in TypeScript specify the types of each parameter and the return type. Optional parameters are marked with `?` and must come after required ones; they receive `undefined` if not passed. Default parameters provide a fallback value and are implicitly optional. Rest parameters collect trailing arguments into a typed array. Function overloads let you define multiple call signatures for a single implementation — only the overload signatures are visible externally; the implementation signature is hidden and must be broad enough to handle all overloads.

❌ **Violates — loose function types with implicit any:**
```typescript
function add(a, b) { return a + b; } // ❌ implicit any parameters
function greet(name?: string, greeting: string = 'Hello') {} // ❌ optional before required
```

✅ **Satisfies — fully typed function with overloads:**
```typescript
function add(a: number, b: number): number { return a + b; }

function greet(greeting: string = 'Hello', name?: string): string {
  return name ? `${greeting}, ${name}!` : `${greeting}!`;
}

function sum(...nums: number[]): number {
  return nums.reduce((a, b) => a + b, 0);
}

// Overloads
function format(value: string): string;
function format(value: number, decimals: number): string;
function format(value: string | number, decimals?: number): string {
  if (typeof value === 'string') return value.trim();
  return value.toFixed(decimals ?? 2);
}
format('hello ');    // ✅ uses first overload
format(3.14159, 2);  // ✅ uses second overload
```

---

### Q9. What is type narrowing? Explain `typeof`, `instanceof`, the `in` operator, discriminated unions, and truthiness narrowing.

**Answer:**
Type narrowing is TypeScript's process of refining a broad type to a more specific one within a branch of code, based on runtime checks the compiler can analyze. `typeof` narrows primitives. `instanceof` narrows class instances. The `in` operator checks property existence and narrows object union members. Discriminated unions use a common literal-typed property (the discriminant) to make narrowing exhaustive and reliable. Truthiness narrowing removes `null`, `undefined`, `0`, `''`, and `false` from a type inside an `if (value)` guard. TypeScript's control flow analysis tracks these narrowings through assignments and branches.

❌ **Violates — accessing union members without narrowing:**
```typescript
type Shape = { radius: number } | { width: number; height: number };
function area(s: Shape): number {
  return Math.PI * s.radius ** 2; // ❌ 'radius' does not exist on rectangle type
}
```

✅ **Satisfies — multiple narrowing techniques:**
```typescript
// typeof
function double(x: string | number) {
  if (typeof x === 'string') return x.repeat(2);
  return x * 2;
}

// instanceof
function logError(e: unknown) {
  if (e instanceof Error) console.error(e.message); // ✅
}

// in operator
type Circle = { kind: 'circle'; radius: number };
type Rect   = { kind: 'rect'; width: number; height: number };
type Shape  = Circle | Rect;

function area(s: Shape): number {
  if (s.kind === 'circle') return Math.PI * s.radius ** 2; // ✅ discriminated union
  return s.width * s.height;
}

// truthiness
function print(val: string | null | undefined) {
  if (val) console.log(val.toUpperCase()); // ✅ null/undefined removed
}
```

---

### Q10. What is structural typing (duck typing)? How does TypeScript check type compatibility, and when are two distinct named types assignable to each other?

**Answer:**
TypeScript uses structural typing: a type is compatible with another if it has at least all the required properties with compatible types — the names of the types are irrelevant. This means a class `Dog` with `{ name: string; bark(): void }` is assignable to an interface `Animal` with `{ name: string }` even without an explicit `implements` declaration. This is in contrast to nominal typing (C#, Java) where explicit declarations are required. Structural compatibility is checked when assigning values, passing arguments, and returning from functions. Excess property checking is a special case that only applies to fresh object literals.

❌ **Violates — assuming TypeScript uses nominal typing:**
```typescript
class USD { constructor(public amount: number) {} }
class EUR { constructor(public amount: number) {} }

function pay(price: USD) { console.log(price.amount); }
const cost = new EUR(100);
pay(cost); // ❌ Intended to be an error — but TypeScript ALLOWS this structurally!
// Use branded types to prevent this (see Section 9)
```

✅ **Satisfies — understanding structural compatibility:**
```typescript
interface Printable { print(): void; }

class Report {
  print() { console.log('Printing report'); }
  save() { console.log('Saving'); }
}

function output(p: Printable) { p.print(); }
output(new Report()); // ✅ Report has print(), so it's compatible — no implements needed

// Structural check allows subsets
type Named = { name: string };
type Person = { name: string; age: number };

const p: Person = { name: 'Alice', age: 30 };
const n: Named = p; // ✅ Person has all fields of Named — assignable
```

---

# 2. Interfaces & Type Aliases

---

## 2.1 Interface vs Type Alias

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/2/everyday-types.html#differences-between-type-aliases-and-interfaces
> 📚 Medium: https://blog.logrocket.com/types-vs-interfaces-in-typescript/

### Q1. What are the key differences between `interface` and `type` alias? When should you prefer one over the other?

**Answer:**
Both `interface` and `type` can describe object shapes, but they differ in key ways. Interfaces support declaration merging — two interfaces with the same name are automatically merged into one. Type aliases cannot be merged but are more expressive: they can name unions, intersections, primitives, tuples, and conditional types. Interfaces use `extends` for inheritance; type aliases use `&` for intersection. Classes can `implement` both. The general guidance: use `interface` for public API contracts and object shapes that may be extended; use `type` for unions, tuples, mapped types, and complex type expressions.

❌ **Violates — using type alias where declaration merging is needed:**
```typescript
// In a library's type definitions:
type Request = { body: unknown };
type Request = { user: User }; // ❌ Error: Duplicate identifier 'Request'
// Cannot augment — consumers cannot extend this
```

✅ **Satisfies — interface for extendable contracts, type for complex expressions:**
```typescript
// Interface — mergeable, extendable
interface Repository<T> {
  findById(id: string): Promise<T>;
  save(entity: T): Promise<void>;
}
interface Repository<T> {
  delete(id: string): Promise<void>; // ✅ merges into the same interface
}

// Type alias — for unions and complex shapes
type ID = string | number;
type Nullable<T> = T | null;
type ApiResult<T> = { data: T; status: number } | { error: string; status: number };

// Class implements interface
class UserRepo implements Repository<User> {
  findById(id: string) { return fetch(`/users/${id}`).then(r => r.json()); }
  save(user: User) { return fetch('/users', { method: 'POST' }).then(() => {}); }
  delete(id: string) { return fetch(`/users/${id}`, { method: 'DELETE' }).then(() => {}); }
}
```

---

### Q2. What are optional (`?`) and readonly properties in interfaces? What are their real-world use cases?

**Answer:**
Optional properties marked with `?` may be absent from a value of that type — their type becomes `T | undefined`. They are used in function option bags, partial update DTOs, and configuration objects where not every field is required. `readonly` properties can be set during object creation but not reassigned afterward — TypeScript enforces this at compile time only (no runtime freeze). Use `readonly` for IDs set at construction time, immutable value objects, and event payload types where mutation would be a bug.

❌ **Violates — mutable ID allows dangerous reassignment:**
```typescript
interface Order {
  id: string;       // ❌ nothing prevents reassignment
  total: number;
}
const o: Order = { id: 'ord_1', total: 50 };
o.id = 'ord_999'; // No error — order ID should never change
```

✅ **Satisfies — readonly for invariants, optional for flexible config:**
```typescript
interface Order {
  readonly id: string;
  readonly createdAt: Date;
  total: number;
  discount?: number;  // optional — not all orders have discounts
  note?: string;
}

const o: Order = { id: 'ord_1', createdAt: new Date(), total: 50 };
// o.id = 'ord_999'; // ❌ compile error — readonly ✅
o.total = 45;        // ✅ mutable field

interface RequestOptions {
  timeout?: number;
  retries?: number;
  headers?: Record<string, string>;
}
function fetch(url: string, opts: RequestOptions = {}) { /* ... */ }
```

---

### Q3. What are index signatures (`[key: string]: unknown`)? What do they allow and what are their pitfalls?

**Answer:**
Index signatures allow an object to have any number of properties with keys of a specified type (usually `string` or `number`) all sharing the same value type. They are useful for dictionaries and maps where keys are dynamic. The pitfalls are significant: all explicitly named properties must be assignable to the index signature's value type, which forces the value type to be broad (like `unknown`). With `noUncheckedIndexedAccess` enabled in tsconfig, indexed access returns `T | undefined`, which is more correct since the key may not exist.

❌ **Violates — index signature value type conflicts with named properties:**
```typescript
interface Config {
  [key: string]: string;
  port: number; // ❌ Error: 'number' is not assignable to type 'string'
}
```

✅ **Satisfies — correct index signature usage with proper value type:**
```typescript
interface StringMap {
  [key: string]: string;
}
const headers: StringMap = { 'Content-Type': 'application/json' }; // ✅

// Mix named and dynamic with union value type
interface FlexConfig {
  [key: string]: string | number | boolean;
  debug: boolean;   // ✅ boolean extends string | number | boolean
  timeout: number;  // ✅
}

// Prefer Record for simple dictionaries
type Translations = Record<string, string>;

// With noUncheckedIndexedAccess
const map: Record<string, number> = { a: 1 };
const val = map['b']; // type: number | undefined — forces null check ✅
```

---

### Q4. How does extending interfaces with `extends` work? Can an interface extend multiple interfaces?

**Answer:**
An interface can extend one or more interfaces using the `extends` keyword, inheriting all their members. Extending multiple interfaces is supported by separating them with commas. This enables building up layered contracts — a base `Entity` with an ID, a `Timestamped` mixin with dates, and a domain type that combines them. If two extended interfaces have conflicting property types for the same key, TypeScript reports an error. Unlike intersection types (`&`), which silently produce `never` for conflicting primitives, `extends` is explicit and errors at the interface declaration.

❌ **Violates — duplicating properties instead of extending:**
```typescript
interface Animal { name: string; }
interface Dog {
  name: string; // ❌ duplicated — won't stay in sync with Animal
  breed: string;
}
```

✅ **Satisfies — single and multiple interface extension:**
```typescript
interface Entity {
  id: string;
}
interface Timestamped {
  createdAt: Date;
  updatedAt: Date;
}
interface SoftDeletable {
  deletedAt?: Date;
}

interface User extends Entity, Timestamped, SoftDeletable {
  name: string;
  email: string;
}

const user: User = {
  id: 'u_1',
  name: 'Alice',
  email: 'alice@example.com',
  createdAt: new Date(),
  updatedAt: new Date(),
}; // ✅ all required fields from all extended interfaces
```

---

### Q5. What is declaration merging? How do you use it to augment existing interfaces like Express `Request` or the global `Window`?

**Answer:**
Declaration merging occurs when TypeScript automatically combines multiple declarations with the same name in the same scope into a single definition. This is unique to interfaces (not type aliases). It is the mechanism used by library authors to allow consumers to extend third-party types. The most common use cases are augmenting Express's `Request` to add a `user` property after authentication middleware, adding custom properties to the browser's `Window` object, and extending environment-specific globals.

❌ **Violates — casting to `any` to add custom properties:**
```typescript
app.use((req, res, next) => {
  (req as any).user = await authenticate(req); // ❌ loses all type safety
  next();
});
```

✅ **Satisfies — declaration merging for type-safe augmentation:**
```typescript
// In types/express/index.d.ts
declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
      requestId: string;
    }
  }
}

// Now in middleware:
app.use((req, res, next) => {
  req.user = { id: '123', role: 'admin' }; // ✅ fully typed
  next();
});

// Augmenting Window
declare global {
  interface Window {
    analytics: AnalyticsInstance;
    __APP_VERSION__: string;
  }
}
window.analytics.track('page_view'); // ✅ no more 'any' cast
```

---

### Q6. How do call signatures and construct signatures work in interfaces?

**Answer:**
A call signature in an interface defines the shape of a callable value — a function. This allows an interface to describe not just an object but something that can be invoked. A construct signature describes something that can be called with `new`, i.e., a class constructor. These are useful when working with factories, constructor functions, and higher-order function patterns. Both can coexist in an interface alongside regular property signatures, enabling rich descriptions of things like class constructors that also have static properties.

❌ **Violates — using `Function` type, which loses all signature information:**
```typescript
interface Transformer {
  transform: Function; // ❌ no information about parameters or return type
}
```

✅ **Satisfies — call and construct signatures:**
```typescript
// Call signature
interface StringTransformer {
  (input: string): string;
  description: string; // can also have properties
}

const upper: StringTransformer = Object.assign(
  (s: string) => s.toUpperCase(),
  { description: 'Converts to uppercase' }
);
upper('hello'); // ✅ returns 'HELLO'

// Construct signature
interface EntityConstructor<T> {
  new(id: string): T;
}

function create<T>(Ctor: EntityConstructor<T>, id: string): T {
  return new Ctor(id);
}

class User { constructor(public id: string) {} }
const user = create(User, 'u_1'); // ✅ type inferred as User
```

---

### Q7. How do you write recursive or self-referential interfaces? Give examples like TreeNode and a JSON value type.

**Answer:**
A recursive interface references itself in one of its property types. TypeScript supports this as long as the recursion is not direct in a type alias (pre-TS 3.7) but interfaces have always allowed it. Recursive types are essential for modeling tree structures, nested menus, file system hierarchies, and the JSON data format. The `JsonValue` type is a classic example that covers all valid JSON: primitives, arrays of JSON values, and objects mapping strings to JSON values.

❌ **Violates — using `any` for nested tree nodes:**
```typescript
interface TreeNode {
  value: string;
  children: any[]; // ❌ loses all type information for subtree
}
```

✅ **Satisfies — recursive interface and JSON value type:**
```typescript
interface TreeNode<T> {
  value: T;
  children: TreeNode<T>[]; // ✅ self-referential
}

const tree: TreeNode<string> = {
  value: 'root',
  children: [
    { value: 'child1', children: [] },
    { value: 'child2', children: [{ value: 'grandchild', children: [] }] },
  ],
};

// JSON value type
type JsonPrimitive = string | number | boolean | null;
type JsonArray    = JsonValue[];
type JsonObject   = { [key: string]: JsonValue };
type JsonValue    = JsonPrimitive | JsonArray | JsonObject;

function parseJson(raw: string): JsonValue {
  return JSON.parse(raw); // ✅ safe return type
}
```

---

### Q8. What is excess property checking? Why does it trigger on object literals but not on variable assignments?

**Answer:**
When you pass a fresh object literal directly to a function or assign it to a typed variable, TypeScript performs excess property checking — it reports an error if the literal has any properties not in the target type. This catches typos in option bags and configuration objects. However, when you first assign the object to an intermediate variable and then pass that variable, TypeScript uses structural compatibility instead — which only requires the target's properties to be present, not that no extras exist. This seemingly inconsistent behavior is intentional: fresh literals are unlikely to be intentionally passing extra properties.

❌ **Violates — typo in option object passes structural check but is silently ignored:**
```typescript
interface Options { timeout: number; retries: number; }

function request(url: string, opts: Options) { /* ... */ }

const opts = { timeout: 5000, retries: 3, reries: 3 }; // typo!
request('/api', opts); // ✅ no error — structural check ignores extra 'reries'
// The typo goes undetected ❌
```

✅ **Satisfies — understanding when excess property checking fires:**
```typescript
interface Options { timeout: number; retries: number; }

// Direct literal — excess property check fires ✅
request('/api', { timeout: 5000, retries: 3, reries: 3 }); // ❌ compile error: 'reries' not in Options

// Variable — structural check only
const opts: Options = { timeout: 5000, retries: 3 }; // ✅ typed variable prevents the extra field too

// To allow extras intentionally, use an index signature or spread
interface FlexOptions extends Options { [key: string]: unknown; }
```

---

### Q9. What is the difference between `Readonly<T>` and `ReadonlyArray<T>`? Why is `Readonly<T>` shallow?

**Answer:**
`Readonly<T>` makes all top-level properties of `T` readonly — you cannot reassign them, but if a property is itself an object or array, its contents can still be mutated. `ReadonlyArray<T>` is an array type that disallows mutating methods like `push`, `pop`, and `splice`, and prevents index assignment. Both are shallow — they do not recursively make nested objects immutable. For deep immutability you need a recursive `DeepReadonly<T>` type (see Section 4). In function signatures, preferring `ReadonlyArray<T>` over `T[]` signals that the function won't mutate the array, which is a useful contract.

❌ **Violates — assuming Readonly prevents deep mutation:**
```typescript
interface Config { db: { host: string; port: number }; }
const config: Readonly<Config> = { db: { host: 'localhost', port: 5432 } };

// config.db = { host: 'other', port: 3306 }; // ❌ compile error ✅
config.db.host = 'hacked'; // ✅ no error — Readonly is SHALLOW ❌
```

✅ **Satisfies — correct use and understanding of shallow Readonly:**
```typescript
// ReadonlyArray prevents mutation methods
function sum(nums: ReadonlyArray<number>): number {
  // nums.push(1); // ❌ compile error ✅ — signals no mutation
  return nums.reduce((a, b) => a + b, 0);
}

// Deep immutability requires custom type
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K];
};

const config: DeepReadonly<Config> = { db: { host: 'localhost', port: 5432 } };
// config.db.host = 'hacked'; // ❌ compile error now ✅
```

---

### Q10. How do you model loading states with discriminated unions? Explain the Loading | Loaded | Error pattern.

**Answer:**
A discriminated union for async state uses a literal-typed `status` field as the discriminant, combined with status-specific data in separate union members. This eliminates impossible states — you cannot have both `data` and `error` present at the same time, and you cannot access `data` when in the `loading` state. This pattern is the TypeScript equivalent of a state machine and composes cleanly with React components, Redux reducers, and RxJS. Each branch of a switch on `status` is narrowed to its specific type.

❌ **Violates — flat state with optional fields allows impossible combinations:**
```typescript
interface State {
  loading: boolean;
  data?: User[];
  error?: string;
}
// Possible impossible state: { loading: false, data: [...], error: 'oops' } ❌
```

✅ **Satisfies — discriminated union eliminates impossible states:**
```typescript
type LoadingState = { status: 'loading' };
type LoadedState<T> = { status: 'loaded'; data: T };
type ErrorState = { status: 'error'; error: Error };
type AsyncState<T> = LoadingState | LoadedState<T> | ErrorState;

function render(state: AsyncState<User[]>): string {
  switch (state.status) {
    case 'loading': return 'Loading...';
    case 'loaded':  return `${state.data.length} users`; // ✅ data is typed
    case 'error':   return `Error: ${state.error.message}`;
  }
}

// React example
function UserList({ state }: { state: AsyncState<User[]> }) {
  if (state.status === 'loading') return <Spinner />;
  if (state.status === 'error')   return <ErrorMessage error={state.error} />;
  return <ul>{state.data.map(u => <li key={u.id}>{u.name}</li>)}</ul>; // ✅
}
```

---

# 3. Generics

---

## 3.1 Generic Functions and Constraints

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/2/generics.html
> 📚 Medium: https://levelup.gitconnected.com/typescript-generics-in-depth-98af9f3a2c9d

### Q1. What are generics and why do they exist? Explain with a simple identity function example.

**Answer:**
Generics allow you to write reusable code that works with multiple types while preserving type information — unlike using `any`, which discards it. The identity function is the canonical example: it takes a value and returns it unchanged. With `any`, the return type is also `any`, losing the caller's type. With a generic type parameter `<T>`, the return type is inferred as `T` — the same type as the input. Generics are the mechanism behind nearly all of TypeScript's utility types and are essential for type-safe collections, APIs, and higher-order functions.

❌ **Violates — `any` discards type information:**
```typescript
function identity(value: any): any {
  return value;
}
const result = identity(42); // result: any ❌ — TypeScript lost the number type
result.toFixed(2); // no error even if identity returned something else
```

✅ **Satisfies — generic preserves the type:**
```typescript
function identity<T>(value: T): T {
  return value;
}

const n = identity(42);        // T inferred as number ✅
const s = identity('hello');   // T inferred as string ✅
n.toFixed(2);                  // ✅ number methods available
// s.toFixed(2);               // ❌ compile error — string doesn't have toFixed ✅

// Generic arrow function (note the comma to disambiguate from JSX)
const wrap = <T,>(value: T): T[] => [value];
wrap(1);       // number[] ✅
wrap('hello'); // string[] ✅
```

---

### Q2. How do generic constraints work with `extends`? How do you constrain to objects with specific shapes?

**Answer:**
Generic constraints use `extends` to restrict what types can be passed as a type parameter. Without a constraint, TypeScript only allows operations valid for all types. With `T extends { length: number }`, you can safely access `.length` on `T`. Constraints are checked at the call site — invalid type arguments produce a compile error. You can constrain to interfaces, specific shapes, other type parameters, or built-in types. `keyof T` is often used in conjunction with constraints to write type-safe property accessor functions.

❌ **Violates — accessing property without constraint:**
```typescript
function longest<T>(a: T, b: T): T {
  return a.length >= b.length ? a : b; // ❌ Error: 'length' does not exist on type 'T'
}
```

✅ **Satisfies — constraint grants access to required properties:**
```typescript
function longest<T extends { length: number }>(a: T, b: T): T {
  return a.length >= b.length ? a : b; // ✅
}
longest('hello', 'hi');      // ✅ string has length
longest([1, 2, 3], [1, 2]); // ✅ array has length
// longest(1, 2);            // ❌ compile error: number has no length ✅

// keyof constraint for property accessor
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]; // ✅ fully type-safe
}
const user = { name: 'Alice', age: 30 };
getProperty(user, 'name'); // string ✅
// getProperty(user, 'email'); // ❌ compile error ✅
```

---

### Q3. How do generic interfaces and generic classes work? Give a reusable container example.

**Answer:**
Generic interfaces and classes parameterize their shape over one or more type parameters, making them reusable across different contained types while preserving full type safety. A `Stack<T>` class stores and retrieves items of type `T` — calling `.pop()` returns `T | undefined`, not `any`. Generic interfaces enable type-safe repository patterns, event emitters, and API response wrappers. The type parameter is provided when the interface is implemented or the class is instantiated.

❌ **Violates — untyped container stores anything, returns any:**
```typescript
class Stack {
  private items: any[] = [];
  push(item: any) { this.items.push(item); }
  pop(): any { return this.items.pop(); }
}
const s = new Stack();
s.push('hello');
const val = s.pop(); // any — no type safety ❌
val.toFixed(); // no error even though val is a string
```

✅ **Satisfies — generic class preserves item type:**
```typescript
class Stack<T> {
  private items: T[] = [];

  push(item: T): void { this.items.push(item); }
  pop(): T | undefined { return this.items.pop(); }
  peek(): T | undefined { return this.items[this.items.length - 1]; }
  get size(): number { return this.items.length; }
}

const numStack = new Stack<number>();
numStack.push(1);
numStack.push(2);
const top = numStack.pop(); // type: number | undefined ✅
// numStack.push('hello');  // ❌ compile error ✅

// Generic interface
interface Repository<T, ID = string> {
  findById(id: ID): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<T>;
  delete(id: ID): Promise<void>;
}
```

---

### Q4. How do multiple type parameters work? Explain with `function pair<K, V>(key: K, val: V): [K, V]`.

**Answer:**
A generic function or type can have multiple type parameters, each independently inferred or explicitly provided. Multiple parameters are listed in the angle brackets separated by commas. They can be constrained independently and can reference each other in constraints. This is essential for typed key-value pairs, mapping functions, and any operation that relates two or more distinct types. TypeScript infers each parameter independently from the call arguments.

❌ **Violates — single any parameter forces unnecessary widening:**
```typescript
function pair(key: any, val: any): [any, any] {
  return [key, val]; // ❌ all type information lost
}
const [k, v] = pair('id', 42); // both are 'any'
```

✅ **Satisfies — multiple type parameters retain all type information:**
```typescript
function pair<K, V>(key: K, val: V): [K, V] {
  return [key, val];
}
const [k, v] = pair('id', 42);  // k: string, v: number ✅
const [k2, v2] = pair(true, { x: 1 }); // k2: boolean, v2: { x: number } ✅

// Multiple parameters with constraints
function mapKeys<T extends object, K extends keyof T>(
  obj: T,
  keys: K[]
): Pick<T, K> {
  return keys.reduce((acc, k) => ({ ...acc, [k]: obj[k] }), {} as Pick<T, K>);
}

const user = { id: 1, name: 'Alice', email: 'alice@x.com', role: 'admin' };
const subset = mapKeys(user, ['id', 'name']); // { id: number; name: string } ✅
```

---

### Q5. What are default generic parameters? How does `interface Response<T = unknown>` work?

**Answer:**
Default type parameters provide a fallback type when the type argument is not explicitly supplied or cannot be inferred. They follow the same rules as default function parameters: once a default is used, subsequent parameters must also have defaults. Default generics make APIs more ergonomic — callers who don't care about the type parameter get a safe default (`unknown` for response bodies, `Error` for error types) while callers who need precision can specify it. They are commonly used in Promise wrappers, API response types, and React component prop types.

❌ **Violates — always requiring explicit type parameter adds verbosity:**
```typescript
interface ApiResponse<T> { data: T; status: number; }
// Every usage must specify T even when it's not needed
const raw: ApiResponse<unknown> = await fetch('/health').then(r => r.json());
```

✅ **Satisfies — default type parameter makes common case ergonomic:**
```typescript
interface ApiResponse<T = unknown> {
  data: T;
  status: number;
  message?: string;
}

// Without type arg — defaults to unknown ✅
const raw: ApiResponse = await fetchRaw('/health');

// With type arg — fully typed ✅
const users: ApiResponse<User[]> = await fetchTyped<User[]>('/users');
users.data.map(u => u.name); // ✅ TypeScript knows data is User[]

// Default with constraint
interface Result<T = void, E extends Error = Error> {
  value?: T;
  error?: E;
}
const r: Result = { value: undefined }; // T=void, E=Error ✅
const r2: Result<User, ValidationError> = { value: user }; // ✅
```

---

### Q6. What are conditional types? How does `T extends U ? X : Y` work, and what is distributive behavior?

**Answer:**
Conditional types select one of two types based on whether `T` extends `U`, evaluated at type-check time rather than runtime. They enable type-level branching and are the foundation of many utility types. Distributive behavior: when `T` is a naked type parameter (not wrapped in `[]` or `{}`) and you apply a conditional type, TypeScript distributes it over each member of a union automatically — `ToArray<string | number>` becomes `string[] | number[]` rather than `(string | number)[]`. To prevent distribution, wrap `T` in `[T]`.

❌ **Violates — using conditional type incorrectly expects non-distributive behavior:**
```typescript
type ToArray<T> = T extends unknown ? T[] : never;
type Result = ToArray<string | number>;
// Expected: (string | number)[] — but actually: string[] | number[] ❌ (surprising!)
```

✅ **Satisfies — understanding and controlling distribution:**
```typescript
// Distributive (default)
type IsString<T> = T extends string ? true : false;
type A = IsString<string | number>; // boolean (true | false) — distributed ✅

// Non-distributive — wrap in tuple
type IsStringExact<T> = [T] extends [string] ? true : false;
type B = IsStringExact<string | number>; // false — string|number not extends string ✅

// Practical: filter union members
type NonNullable<T> = T extends null | undefined ? never : T;
type C = NonNullable<string | null | undefined>; // string ✅

// Extract string-like keys
type StringKeys<T> = {
  [K in keyof T]: T[K] extends string ? K : never;
}[keyof T];
type D = StringKeys<{ name: string; age: number; email: string }>;
// 'name' | 'email' ✅
```

---

### Q7. How does the `infer` keyword work? Show how to extract inner types for `ReturnType<T>` and array element types.

**Answer:**
The `infer` keyword appears only within the `extends` clause of a conditional type and declares a new type variable to be inferred from whatever type occupies that position in a successful match. It lets you extract types from within complex structures — the return type of a function, the resolved value of a Promise, the element type of an array, or the first parameter of a constructor. `infer` is what makes utility types like `ReturnType`, `Parameters`, and `Awaited` possible without any runtime code.

❌ **Violates — manually repeating return types creates maintenance burden:**
```typescript
function fetchUser(): Promise<User> { /* ... */ return Promise.resolve({} as User); }

// Must manually repeat User here — breaks if return type changes
async function process(): Promise<User> {
  return fetchUser();
}
```

✅ **Satisfies — `infer` extracts types automatically:**
```typescript
// ReturnType implementation
type ReturnType<T extends (...args: any) => any> =
  T extends (...args: any) => infer R ? R : never;

function fetchUser(): Promise<User> { return Promise.resolve({} as User); }
type FetchResult = ReturnType<typeof fetchUser>; // Promise<User> ✅

// Array element type
type ElementType<T> = T extends (infer E)[] ? E : never;
type E = ElementType<string[]>; // string ✅
type F = ElementType<number[]>; // number ✅

// First argument type
type FirstArg<T extends (...args: any) => any> =
  T extends (first: infer F, ...rest: any[]) => any ? F : never;

function greet(name: string, age: number): void {}
type G = FirstArg<typeof greet>; // string ✅

// Unwrap Promise
type Awaited<T> = T extends Promise<infer U> ? Awaited<U> : T;
type H = Awaited<Promise<Promise<string>>>; // string ✅
```

---

### Q8. What are mapped types? How do you add or remove `readonly` and optional modifiers?

**Answer:**
Mapped types iterate over the keys of a type using `[K in keyof T]` and transform each property. The value type can be changed, and modifiers (`readonly`, `?`) can be added with `+` or removed with `-`. This is the mechanism behind `Partial<T>` (adds `?`), `Required<T>` (removes `?`), and `Readonly<T>` (adds `readonly`). The `as` clause in mapped types (TS 4.1+) enables key remapping, allowing you to rename or filter keys during the mapping.

❌ **Violates — manually writing every variant of a type:**
```typescript
interface User { id: string; name: string; email: string; }
interface PartialUser { id?: string; name?: string; email?: string; } // ❌ manual duplication
interface ReadonlyUser { readonly id: string; readonly name: string; readonly email: string; }
```

✅ **Satisfies — mapped types generate variants automatically:**
```typescript
// Built-in — understanding the implementation
type MyPartial<T> = { [K in keyof T]?: T[K] };
type MyRequired<T> = { [K in keyof T]-?: T[K] };   // -? removes optional
type MyReadonly<T> = { readonly [K in keyof T]: T[K] };
type Mutable<T>   = { -readonly [K in keyof T]: T[K] }; // -readonly removes readonly

// Key remapping with 'as'
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};
type UserGetters = Getters<{ name: string; age: number }>;
// { getName: () => string; getAge: () => number } ✅

// Filter keys by value type
type OnlyStrings<T> = {
  [K in keyof T as T[K] extends string ? K : never]: T[K];
};
type StringFields = OnlyStrings<{ id: number; name: string; email: string }>;
// { name: string; email: string } ✅
```

---

### Q9. How do template literal types combine with generics? Show `type EventName<T extends string> = \`on${Capitalize<T>}\``.

**Answer:**
Template literal types become especially powerful when combined with generic type parameters, allowing the construction of entire families of string types parametrically. When a generic union is used inside a template literal, TypeScript distributes over each member. Combined with the built-in string manipulation types (`Capitalize`, `Uppercase`, `Lowercase`, `Uncapitalize`), you can build event system types, getter/setter name derivations, CSS property types, and API route types that are all computed from a single source-of-truth type.

❌ **Violates — manually listing all event name variants:**
```typescript
type UserEvent = 'onUserCreated' | 'onUserUpdated' | 'onUserDeleted';
type OrderEvent = 'onOrderCreated' | 'onOrderUpdated' | 'onOrderDeleted';
// ❌ duplicated pattern — breaks if action list changes
```

✅ **Satisfies — generic template literal types generate the union:**
```typescript
type Action = 'created' | 'updated' | 'deleted';
type EventName<T extends string> = `on${Capitalize<T>}`;
type EntityEvent<E extends string, A extends string = Action> =
  `on${Capitalize<E>}${Capitalize<A>}`;

type UserEvent = EntityEvent<'user'>; // 'onUserCreated' | 'onUserUpdated' | 'onUserDeleted' ✅

// Type-safe event emitter
type EventMap<T extends string> = {
  [K in T as EventName<K>]: (payload: Record<string, unknown>) => void;
};

type UserEvents = EventMap<'login' | 'logout' | 'register'>;
// { onLogin: ...; onLogout: ...; onRegister: ... } ✅

// Getter types
type Getter<T extends string> = `get${Capitalize<T>}`;
type Setter<T extends string> = `set${Capitalize<T>}`;
```

---

### Q10. What are recursive generic types? Implement `DeepPartial<T>` and `DeepReadonly<T>`.

**Answer:**
Recursive generic types reference themselves in their definition to handle arbitrarily nested structures. TypeScript supports recursive type aliases since TS 3.7. The key challenge is the base case: you must stop recursing for primitives and non-object types, otherwise the recursion bottoms out incorrectly. These types are invaluable for deep clone utilities, nested configuration objects, and ORMs that need to express partial updates to deeply nested documents. Note that TypeScript limits recursion depth to prevent infinite loops.

❌ **Violates — shallow Partial misses nested required fields:**
```typescript
interface Config { server: { host: string; port: number }; db: { url: string }; }
type Update = Partial<Config>;
// { server?: { host: string; port: number }; db?: { url: string } }
// nested fields are still required! ❌
const update: Update = { server: {} }; // ❌ Error: host and port required
```

✅ **Satisfies — recursive types handle nested structures:**
```typescript
type DeepPartial<T> = T extends (infer E)[]
  ? DeepPartial<E>[]
  : T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;

type DeepReadonly<T> = T extends (infer E)[]
  ? ReadonlyArray<DeepReadonly<E>>
  : T extends object
  ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
  : T;

interface Config {
  server: { host: string; port: number };
  db: { url: string; pool: { min: number; max: number } };
}

type PartialConfig = DeepPartial<Config>;
const update: PartialConfig = { server: { host: 'localhost' } }; // ✅ port is optional now

type FrozenConfig = DeepReadonly<Config>;
const cfg: FrozenConfig = { server: { host: 'x', port: 80 }, db: { url: 'y', pool: { min: 1, max: 5 } } };
// cfg.server.host = 'z'; // ❌ compile error ✅
```

---

# 4. Utility Types

---

## 4.1 Built-in Utility Types

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/utility-types.html
> 📚 Medium: https://javascript.plainenglish.io/mastering-typescripts-built-in-utility-types-a-practical-guide-9f9a2c2d7a8e

### Q1. What are `Partial<T>` and `Required<T>`? When do you use each?

**Answer:**
`Partial<T>` makes every property of `T` optional (adds `?` to each), producing a type where any subset of fields is valid. It is the correct type for update/patch payloads where only changed fields are sent. `Required<T>` is the opposite — it removes `?` from every property, making all fields mandatory. Use it when a function receives a fully hydrated object that downstream guarantees all fields are present, or in tests that need to assert the complete shape. Both are shallow — they do not affect nested types.

❌ **Violates — using the full type for a partial update:**
```typescript
interface User { id: string; name: string; email: string; bio?: string; }

function updateUser(id: string, changes: User) { /* ... */ }
// Caller must supply ALL fields even for a name-only change ❌
updateUser('u1', { id: 'u1', name: 'Bob', email: 'bob@x.com' });
```

✅ **Satisfies — `Partial` for updates, `Required` for complete objects:**
```typescript
interface User { id: string; name: string; email: string; bio?: string; }

function updateUser(id: string, changes: Partial<Omit<User, 'id'>>): Promise<User> {
  return patch(`/users/${id}`, changes);
}
updateUser('u1', { name: 'Bob' }); // ✅ only supply what changed

// Required: configuration resolved after defaults applied
type RawConfig = { host?: string; port?: number; timeout?: number; };
type ResolvedConfig = Required<RawConfig>; // all fields now mandatory

function applyDefaults(cfg: RawConfig): ResolvedConfig {
  return { host: 'localhost', port: 3000, timeout: 5000, ...cfg };
}
```

---

### Q2. What does `Readonly<T>` do and what are its limitations?

**Answer:**
`Readonly<T>` wraps every property of `T` with the `readonly` modifier, preventing reassignment at the TypeScript type level. It is the correct type for function parameters that must not be mutated, frozen configuration objects, and Redux state slices. The key limitation is that it is shallow: nested object properties remain mutable. `Object.freeze` at runtime is also shallow. For genuine deep immutability at the type level, a recursive `DeepReadonly<T>` is needed. `ReadonlyArray<T>` is the array-specific variant that removes all mutating methods.

❌ **Violates — mutating a parameter the caller doesn't expect to change:**
```typescript
function processItems(items: string[]): string[] {
  items.sort(); // ❌ sorts the original array — caller's array is mutated
  return items;
}
```

✅ **Satisfies — `Readonly` and `ReadonlyArray` express non-mutation intent:**
```typescript
function processItems(items: ReadonlyArray<string>): string[] {
  // items.sort(); // ❌ compile error — ReadonlyArray has no sort ✅
  return [...items].sort(); // ✅ copy, then sort
}

function render(config: Readonly<AppConfig>): void {
  // config.debug = true; // ❌ compile error ✅
  console.log(config.debug);
}

// As const gives Readonly at the variable level
const STATUS = { ACTIVE: 'active', INACTIVE: 'inactive' } as const;
// STATUS.ACTIVE = 'x'; // ❌ compile error ✅
```

---

### Q3. What are `Pick<T, K>` and `Omit<T, K>`? When do you use each?

**Answer:**
`Pick<T, K>` creates a new type with only the properties of `T` whose keys are in the union `K`. `Omit<T, K>` creates a new type with all properties of `T` except those in `K`. Use `Pick` when you want a focused projection — e.g., a card component that only needs `name` and `avatar`. Use `Omit` when you want to exclude a few fields from a larger type — e.g., removing `id` and `createdAt` from a DTO before creation. They compose naturally with `Partial`, `Readonly`, and `Required`.

❌ **Violates — manually redeclaring a subset of an interface:**
```typescript
interface User { id: string; name: string; email: string; role: string; createdAt: Date; }
interface UserCard { name: string; email: string; } // ❌ duplicated — won't stay in sync
```

✅ **Satisfies — `Pick` and `Omit` stay in sync with the source type:**
```typescript
interface User { id: string; name: string; email: string; role: string; createdAt: Date; }

type UserCard   = Pick<User, 'name' | 'email'>;           // ✅ only what's needed
type CreateUser = Omit<User, 'id' | 'createdAt' | 'role'>; // ✅ exclude server-set fields

function renderCard(user: UserCard) {
  console.log(user.name, user.email);
}

// Combine with Partial for patch DTOs
type PatchUser = Partial<Omit<User, 'id' | 'createdAt'>>;
// { name?: string; email?: string; role?: string } ✅
```

---

### Q4. What is `Record<K, V>`? How do you use it for typed dictionaries and config maps?

**Answer:**
`Record<K, V>` constructs an object type whose keys are type `K` (which must extend `string | number | symbol`) and whose values are all type `V`. It is the clean way to express dictionaries, lookup tables, and configuration maps — replacing `{ [key: string]: V }` index signatures with a more readable form. When `K` is a union of string literals, TypeScript requires all members of the union to be present as keys, making it exhaustive. This is invaluable for i18n translations, route definitions, and role-permission maps.

❌ **Violates — using plain object with no key type constraint:**
```typescript
const permissions: { [key: string]: boolean } = {};
permissions['nonExistentRole'] = true; // No error — any string is valid ❌
```

✅ **Satisfies — `Record` with literal union enforces exhaustiveness:**
```typescript
type Role = 'admin' | 'editor' | 'viewer';
type Permission = 'read' | 'write' | 'delete';

const rolePermissions: Record<Role, Set<Permission>> = {
  admin:  new Set(['read', 'write', 'delete']),
  editor: new Set(['read', 'write']),
  viewer: new Set(['read']),
  // Missing 'viewer' would be a compile error ✅
};

// i18n
type Locale = 'en' | 'fr' | 'de';
const labels: Record<Locale, { greeting: string; farewell: string }> = {
  en: { greeting: 'Hello', farewell: 'Goodbye' },
  fr: { greeting: 'Bonjour', farewell: 'Au revoir' },
  de: { greeting: 'Hallo', farewell: 'Auf Wiedersehen' },
};
```

---

### Q5. What are `Exclude<T, U>`, `Extract<T, U>`, and `NonNullable<T>`?

**Answer:**
These three utility types filter union members. `Exclude<T, U>` removes from `T` all members assignable to `U`. `Extract<T, U>` keeps only members of `T` that are assignable to `U`. `NonNullable<T>` is shorthand for `Exclude<T, null | undefined>`. They are built on distributive conditional types and operate purely at the type level. Common use cases: building complementary unions, narrowing a broad union to a subset, and removing nullable from a type before passing to a function that requires non-null.

❌ **Violates — manually redeclaring filtered unions:**
```typescript
type AllEvents = 'click' | 'focus' | 'blur' | 'keydown' | 'keyup';
type KeyEvents = 'keydown' | 'keyup'; // ❌ duplicated — must be kept in sync manually
type MouseEvents = 'click' | 'focus' | 'blur';
```

✅ **Satisfies — derive filtered unions automatically:**
```typescript
type AllEvents = 'click' | 'focus' | 'blur' | 'keydown' | 'keyup';
type KeyEvents   = Extract<AllEvents, 'keydown' | 'keyup'>;      // 'keydown' | 'keyup' ✅
type NonKeyEvents = Exclude<AllEvents, 'keydown' | 'keyup'>;     // 'click' | 'focus' | 'blur' ✅

type MaybeUser = User | null | undefined;
type DefiniteUser = NonNullable<MaybeUser>; // User ✅

function requireUser(user: NonNullable<MaybeUser>): void {
  console.log(user.name); // ✅ null and undefined removed
}

// Practical: exclude internal event types from public API
type InternalEvent = 'sys:init' | 'sys:cleanup';
type PublicEvent   = 'user:login' | 'user:logout' | 'sys:init';
type ExposedEvents = Exclude<PublicEvent, InternalEvent>; // 'user:login' | 'user:logout' ✅
```

---

### Q6. What are `ReturnType<T>`, `Parameters<T>`, `ConstructorParameters<T>`, and `InstanceType<T>`?

**Answer:**
These utility types use `infer` to extract type information from function and class types. `ReturnType<T>` extracts the return type of a function type. `Parameters<T>` extracts the parameter types as a tuple. `ConstructorParameters<T>` does the same for a class constructor. `InstanceType<T>` extracts the instance type of a class constructor type — useful when you have the class itself (not an instance) and need to describe what `new` produces. They are invaluable for wrapping functions with middleware, creating type-safe decorators, and building mock factories.

❌ **Violates — manually repeating return types creates drift:**
```typescript
async function fetchUsers(): Promise<User[]> { /* ... */ return []; }

// If fetchUsers return type changes, this breaks silently:
async function cachedFetchUsers(): Promise<User[]> { // ❌ must manually update
  return fetchUsers();
}
```

✅ **Satisfies — derive types from the function itself:**
```typescript
async function fetchUsers(): Promise<User[]> { return []; }

type FetchResult = Awaited<ReturnType<typeof fetchUsers>>; // User[] ✅
type FetchParams = Parameters<typeof fetchUsers>; // [] ✅

// Wrapping arbitrary functions
function memoize<T extends (...args: any[]) => any>(
  fn: T
): (...args: Parameters<T>) => ReturnType<T> {
  const cache = new Map<string, ReturnType<T>>();
  return (...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    if (!cache.has(key)) cache.set(key, fn(...args));
    return cache.get(key)!;
  };
}

class UserService { constructor(private db: Database, private cache: Cache) {} }
type ServiceArgs = ConstructorParameters<typeof UserService>; // [Database, Cache] ✅
type ServiceInstance = InstanceType<typeof UserService>; // UserService ✅
```

---

### Q7. What does `Awaited<T>` do? How does it unwrap nested Promise types?

**Answer:**
`Awaited<T>` recursively unwraps `Promise` types — `Awaited<Promise<Promise<string>>>` resolves to `string`. Before TS 4.5, developers used a custom `UnwrapPromise` type. `Awaited` is now the canonical way to express "the type you get after awaiting this value". It correctly handles `PromiseLike` (thenable objects), not just native Promises, and is used internally in the types of `Promise.all`, `Promise.allSettled`, and `Promise.race`. Understanding `Awaited` is essential when building typed async middleware and composing async operations.

❌ **Violates — manually annotating the awaited type:**
```typescript
async function getData(): Promise<User> { return {} as User; }

// If getData return type changes, this breaks:
const result: User = await getData(); // annotation must be kept manually in sync ❌
```

✅ **Satisfies — using `Awaited` to derive the resolved type:**
```typescript
async function getData(): Promise<User[]> { return []; }

type Data = Awaited<ReturnType<typeof getData>>; // User[] ✅

// Nested promises
type DeepPromise = Promise<Promise<Promise<number>>>;
type Resolved = Awaited<DeepPromise>; // number ✅

// Promise.all preserves tuple types with Awaited
async function loadAll() {
  return Promise.all([
    fetchUser('u1'),      // Promise<User>
    fetchOrders('u1'),    // Promise<Order[]>
  ]);
}
type AllResult = Awaited<ReturnType<typeof loadAll>>; // [User, Order[]] ✅
```

---

### Q8. How do you combine utility types? Explain patterns like `Partial<Pick<User, 'name' | 'email'>>`.

**Answer:**
Utility types compose like functions — apply them left to right reading outward. `Partial<Pick<User, 'name' | 'email'>>` first picks only the `name` and `email` fields, then makes them optional — giving a type where you can provide either, both, or neither. Combining utility types enables expressing complex real-world shapes: profile update payloads, API DTOs, form states, and query filters. The composition approach is more maintainable than manually writing every variant because it stays in sync with the source type automatically.

❌ **Violates — manually redeclaring composed shapes:**
```typescript
interface ProfileUpdate {
  name?: string;
  email?: string;
  // ❌ if User.name or User.email type changes, this goes stale
}
```

✅ **Satisfies — composed utility types stay in sync:**
```typescript
interface User { id: string; name: string; email: string; role: 'admin'|'user'; createdAt: Date; }

// Profile update: only name/email, both optional
type ProfileUpdate = Partial<Pick<User, 'name' | 'email'>>;

// Admin patch: everything except id and createdAt, all optional
type AdminPatch = Partial<Omit<User, 'id' | 'createdAt'>>;

// Read-only view with only safe-to-expose fields
type UserView = Readonly<Pick<User, 'id' | 'name' | 'role'>>;

// Required version of a partial config (after defaults applied)
type Config = { host?: string; port?: number };
type ResolvedConfig = Required<Readonly<Config>>;

// Form state: all fields optional strings (for form inputs)
type UserForm = { [K in keyof Pick<User, 'name' | 'email'>]?: string };
```

---

### Q9. How do you build custom utility types? Implement `RequireAtLeastOne<T>`, `Mutable<T>`, and `DeepPartial<T>`.

**Answer:**
Custom utility types are advanced mapped or conditional types that solve domain-specific problems not covered by the built-ins. `Mutable<T>` removes `readonly` from all properties using the `-readonly` modifier. `DeepPartial<T>` recursively applies `Partial` to nested objects. `RequireAtLeastOne<T>` is the most complex — it ensures at least one property from a set is present by distributing a `Required<Pick<T, K>>` over each key and unioning the results with `Partial<Omit<T, K>>`.

❌ **Violates — contact form allows all fields to be empty:**
```typescript
interface ContactForm { email?: string; phone?: string; }
const form: ContactForm = {}; // ❌ neither email nor phone — makes no sense
```

✅ **Satisfies — `RequireAtLeastOne` enforces the constraint:**
```typescript
type RequireAtLeastOne<T, Keys extends keyof T = keyof T> = Omit<T, Keys> &
  { [K in Keys]-?: Required<Pick<T, K>> & Partial<Omit<T, K>> }[Keys];

interface ContactForm { email?: string; phone?: string; message: string; }
type ValidContact = RequireAtLeastOne<ContactForm, 'email' | 'phone'>;

const a: ValidContact = { email: 'x@x.com', message: 'hi' }; // ✅
const b: ValidContact = { phone: '123', message: 'hi' };     // ✅
// const c: ValidContact = { message: 'hi' };                // ❌ compile error ✅

// Mutable<T>
type Mutable<T> = { -readonly [K in keyof T]: T[K] };
type MutableUser = Mutable<Readonly<User>>; // all readonly removed ✅

// DeepPartial<T>
type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;
```

---

### Q10. What are practical API patterns using utility types? Show DTO to ViewModel mapping and form field types derived from a model.

**Answer:**
Utility types shine in the layer between API data and UI presentation. A DTO (Data Transfer Object) mirrors the API response shape. A ViewModel derives from the DTO using `Pick`, `Omit`, and `Partial`, adding computed or display-only fields. Form types are typically all-optional string fields derived from the model keys. This approach ensures the ViewModel and form types automatically update when the DTO changes, eliminating the manual synchronization that causes bugs in large codebases.

❌ **Violates — ViewModel manually duplicates DTO fields:**
```typescript
// DTO
interface UserDTO { id: string; firstName: string; lastName: string; email: string; roleId: number; }

// ViewModel — duplicated manually ❌
interface UserViewModel { id: string; firstName: string; lastName: string; email: string; fullName: string; }
```

✅ **Satisfies — ViewModel derived from DTO with utility types:**
```typescript
interface UserDTO {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  roleId: number;
  createdAt: string;
}

// ViewModel: pick display fields, add computed fullName
type UserViewModel = Pick<UserDTO, 'id' | 'firstName' | 'lastName' | 'email'> & {
  fullName: string; // computed field not in DTO
};

function toViewModel(dto: UserDTO): UserViewModel {
  return { ...dto, fullName: `${dto.firstName} ${dto.lastName}` }; // ✅
}

// Form type: editable fields become optional strings
type EditableFields = 'firstName' | 'lastName' | 'email';
type UserForm = { [K in EditableFields]?: string };

// API patch type
type UserPatch = Partial<Pick<UserDTO, EditableFields>>;
```

---

# 5. Classes & OOP

---

## 5.1 TypeScript Classes

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/2/classes.html
> 📚 Medium: https://blog.bitsrc.io/understanding-typescript-classes-and-access-modifiers-c8c84c8ede02

### Q1. What does TypeScript add to JavaScript class syntax? Explain constructors, properties, and methods with TypeScript-specific additions.

**Answer:**
TypeScript classes extend JavaScript classes with compile-time type checking for properties and methods, access modifiers (`public`, `private`, `protected`, `readonly`), parameter properties shorthand, abstract classes, the `override` keyword, and typed interfaces that classes can implement. Properties must be declared in the class body (or via parameter properties) before use — TypeScript enforces `strictPropertyInitialization`, requiring all non-optional properties to be assigned in the constructor. Methods have full return type annotations. These additions make classes self-documenting contracts rather than loose bags of behavior.

❌ **Violates — property used before declaration, no type annotations:**
```typescript
class User {
  constructor(name, email) { // ❌ implicit any parameters
    this.name = name;        // ❌ Error with strictPropertyInitialization: property not declared
    this.email = email;
  }
  greet() { return `Hi ${this.name}`; }
}
```

✅ **Satisfies — fully typed class with declared properties:**
```typescript
class User {
  readonly id: string;
  name: string;
  email: string;
  private passwordHash: string;

  constructor(name: string, email: string, password: string) {
    this.id = crypto.randomUUID();
    this.name = name;
    this.email = email;
    this.passwordHash = hash(password);
  }

  greet(): string {
    return `Hi, I'm ${this.name}`;
  }

  verifyPassword(input: string): boolean {
    return hash(input) === this.passwordHash;
  }
}
```

---

### Q2. What do `public`, `private`, `protected`, and `readonly` access modifiers enforce?

**Answer:**
`public` (default) allows access from anywhere. `private` restricts access to the declaring class only — subclasses cannot access it. `protected` allows access in the declaring class and its subclasses, but not from outside. `readonly` prevents reassignment after initialization (in constructor or at declaration). All four are compile-time only — at runtime, JavaScript has no enforcement for TypeScript's `private` and `protected` (use `#` for true runtime privacy). These modifiers communicate intent and catch misuse during development.

❌ **Violates — all fields public, direct mutation from anywhere:**
```typescript
class BankAccount {
  balance: number = 0; // ❌ anyone can set balance = 1000000

  constructor(public owner: string) {}
}
const acc = new BankAccount('Alice');
acc.balance = 999999; // ❌ no error — bypasses all business logic
```

✅ **Satisfies — appropriate modifiers enforce encapsulation:**
```typescript
class BankAccount {
  readonly id: string;
  private balance: number;
  protected owner: string;

  constructor(owner: string, initialBalance: number) {
    this.id = crypto.randomUUID();
    this.owner = owner;
    this.balance = initialBalance;
  }

  deposit(amount: number): void {
    if (amount <= 0) throw new Error('Amount must be positive');
    this.balance += amount;
  }

  getBalance(): number { return this.balance; }
}

const acc = new BankAccount('Alice', 100);
// acc.balance = 999; // ❌ compile error ✅
// acc.id = 'fake';   // ❌ compile error — readonly ✅
acc.deposit(50);       // ✅ controlled mutation via method
```

---

### Q3. What is the parameter properties shorthand? How does `constructor(private name: string, public age: number)` work?

**Answer:**
Parameter properties are a TypeScript shorthand that declares and initializes a class member in one step inside the constructor signature. Prefixing a constructor parameter with an access modifier (`public`, `private`, `protected`) or `readonly` causes TypeScript to automatically declare a property with that name and modifier, and assign the parameter value to it. This eliminates the repetitive pattern of declaring properties at the top, then assigning them in the constructor body. It is idiomatic TypeScript for simple value-object classes and DTOs.

❌ **Violates — verbose manual declaration and assignment:**
```typescript
class Point {
  public x: number;
  public y: number;
  readonly label: string;

  constructor(x: number, y: number, label: string) {
    this.x = x;       // ❌ boilerplate — three lines to do what one can
    this.y = y;
    this.label = label;
  }
}
```

✅ **Satisfies — parameter properties eliminate boilerplate:**
```typescript
class Point {
  constructor(
    public x: number,
    public y: number,
    readonly label: string,
  ) {}
  // x, y, label are automatically declared and assigned ✅

  toString(): string { return `${this.label}(${this.x}, ${this.y})`; }
}

class UserService {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly emailService: EmailService,
    private readonly logger: Logger,
  ) {}
  // No explicit property declarations needed ✅
}
```

---

### Q4. What is the difference between abstract classes and interfaces? When do you use each?

**Answer:**
An abstract class is a class that cannot be instantiated directly — it exists to be extended. It can contain concrete implementations (actual method bodies), constructor logic, and state, as well as abstract methods that subclasses must implement. An interface is a pure type contract with no implementation. Use an abstract class when subclasses share implementation (the Template Method pattern), need constructor logic, or maintain state. Use an interface when you only need a contract — especially for dependency injection, mocking in tests, and defining cross-cutting capabilities.

❌ **Violates — duplicating shared logic across subclasses:**
```typescript
class PDFReport {
  generate(data: unknown[]): void {
    this.validate(data); // ❌ duplicated in every report type
    console.log('PDF:', data);
  }
  private validate(data: unknown[]) { if (!data.length) throw new Error('No data'); }
}
class ExcelReport {
  generate(data: unknown[]): void {
    if (!data.length) throw new Error('No data'); // ❌ same validation duplicated
    console.log('Excel:', data);
  }
}
```

✅ **Satisfies — abstract class for shared logic, interface for contracts:**
```typescript
abstract class BaseReport {
  generate(data: unknown[]): void {
    this.validate(data); // ✅ shared logic in one place
    this.render(data);
  }
  private validate(data: unknown[]): void {
    if (!data.length) throw new Error('No data');
  }
  protected abstract render(data: unknown[]): void; // subclasses implement this
}

class PDFReport extends BaseReport {
  protected render(data: unknown[]): void { console.log('PDF:', data); }
}

// Interface for DI / mocking
interface Logger { log(msg: string): void; error(msg: string, err?: Error): void; }
class ConsoleLogger implements Logger { /* ... */ }
class NoopLogger implements Logger { log() {} error() {} } // test double ✅
```

---

### Q5. How do static members and static blocks work? Cover shared state, factory methods, and the singleton pattern.

**Answer:**
Static members belong to the class itself, not to instances — they are accessed via the class name. Static properties hold shared state (counters, caches, registries). Static methods are utility functions or factory methods that don't need instance state. Static initialization blocks (TS 4.4+ / ES2022) run once when the class is loaded and are useful for complex static initialization. The singleton pattern uses a private constructor and a static `instance` property to ensure only one instance exists — though in TypeScript, module-level constants are usually a simpler alternative.

❌ **Violates — instance method used as factory, creating unnecessary instances:**
```typescript
class Logger {
  createLogger(name: string): Logger { return new Logger(); } // ❌ must instantiate to create
}
const factory = new Logger(); // wasteful
const logger = factory.createLogger('app');
```

✅ **Satisfies — static factory, shared state, singleton:**
```typescript
class Logger {
  private static instanceCount = 0;
  private static readonly registry = new Map<string, Logger>();

  static {
    // Static initialization block — runs once at class load ✅
    console.log('Logger class initialized');
  }

  static create(name: string): Logger {
    if (this.registry.has(name)) return this.registry.get(name)!;
    const instance = new Logger(name);
    this.registry.set(name, instance);
    Logger.instanceCount++;
    return instance;
  }

  private constructor(private name: string) {}

  log(msg: string): void { console.log(`[${this.name}] ${msg}`); }
}

const appLogger = Logger.create('app'); // ✅
const appLogger2 = Logger.create('app'); // returns same instance ✅
```

---

### Q6. What is the `override` keyword (TS 4.3+)? What does `noImplicitOverride` prevent?

**Answer:**
The `override` keyword explicitly marks a method as overriding a parent class method. With `noImplicitOverride` enabled in tsconfig, TypeScript requires `override` on any method that overrides a base class method, and reports an error if `override` is used on a method that does not exist in the parent. This catches two classes of bugs: silently overriding a method when you meant to add a new one, and failing to update an override when the parent method is renamed or removed. It is the TypeScript equivalent of Java's `@Override` annotation.

❌ **Violates — silent override can break at runtime if parent method is renamed:**
```typescript
class Animal {
  makeSound(): void { console.log('...'); }
}
class Dog extends Animal {
  makeSound(): void { console.log('Woof'); } // ❌ no 'override' — if Animal.makeSound is renamed, this becomes a new unrelated method
}
```

✅ **Satisfies — `override` makes intent explicit and catches renames:**
```typescript
class Animal {
  makeSound(): void { console.log('...'); }
  move(distance: number): void { console.log(`Moved ${distance}m`); }
}

class Dog extends Animal {
  override makeSound(): void { console.log('Woof'); } // ✅ explicit override

  // override fly(): void {} // ❌ compile error: 'fly' does not exist in Animal ✅
}

// With noImplicitOverride in tsconfig:
class Cat extends Animal {
  makeSound(): void { console.log('Meow'); }
  // ❌ Error: Method 'makeSound' will overwrite the base type method — add 'override' ✅
}
```

---

### Q7. What is the difference between private class fields (`#`) and TypeScript's `private` keyword?

**Answer:**
TypeScript's `private` keyword is a compile-time-only annotation — it is erased during compilation, producing ordinary JavaScript properties that are fully accessible at runtime (via bracket notation or `as any`). JavaScript's private class fields, prefixed with `#`, are enforced at runtime by the JavaScript engine — they are truly inaccessible outside the class, even through reflection. `#` fields also don't show up in `Object.keys()`, `JSON.stringify()`, or `for...in` loops. For security-sensitive data, use `#`. For general encapsulation with better DX (readable stack traces, debuggability), TypeScript `private` is often sufficient.

❌ **Violates — TypeScript `private` is bypassed at runtime:**
```typescript
class Secret {
  private key: string = 'abc123';
}
const s = new Secret();
console.log((s as any).key); // 'abc123' — bypassed at runtime ❌
```

✅ **Satisfies — `#` enforces runtime privacy:**
```typescript
class Secret {
  #key: string;

  constructor(key: string) {
    this.#key = key;
  }

  verify(input: string): boolean {
    return input === this.#key;
  }
}

const s = new Secret('abc123');
// s.#key;           // ❌ Syntax error at runtime ✅
// (s as any).key;   // undefined — field doesn't exist on the object ✅
console.log(s.verify('abc123')); // true ✅

// TypeScript private — ok for general encapsulation
class Service {
  private cache = new Map<string, unknown>(); // compile-time only ✅
}
```

---

### Q8. What are mixins? How do you compose behaviors from multiple base classes in TypeScript?

**Answer:**
Mixins are a pattern for composing behavior from multiple sources — solving the multiple inheritance problem without the diamond problem. In TypeScript, a mixin is a function that takes a constructor as input and returns a new class that extends it, adding new behavior. By chaining mixin applications, a class can gain behaviors from multiple sources. This is more type-safe than copying methods onto a prototype. TypeScript's `implements` can be combined with the mixin pattern to get both the structural contract and the implementation.

❌ **Violates — duplicating behavior across unrelated classes:**
```typescript
class User {
  createdAt = new Date();
  updatedAt = new Date();
  update() { this.updatedAt = new Date(); } // ❌ duplicated
}
class Order {
  createdAt = new Date();
  updatedAt = new Date();
  update() { this.updatedAt = new Date(); } // ❌ same code repeated
}
```

✅ **Satisfies — mixin function composes behavior:**
```typescript
type Constructor<T = {}> = new (...args: any[]) => T;

function Timestamped<TBase extends Constructor>(Base: TBase) {
  return class extends Base {
    createdAt = new Date();
    updatedAt = new Date();
    touch() { this.updatedAt = new Date(); }
  };
}

function Activatable<TBase extends Constructor>(Base: TBase) {
  return class extends Base {
    isActive = true;
    activate() { this.isActive = true; }
    deactivate() { this.isActive = false; }
  };
}

class EntityBase { constructor(public id: string) {} }

const TimestampedActivatable = Activatable(Timestamped(EntityBase));
class User extends TimestampedActivatable {
  constructor(id: string, public name: string) { super(id); }
}

const u = new User('u1', 'Alice');
u.touch();      // ✅ from Timestamped
u.deactivate(); // ✅ from Activatable
```

---

### Q9. What are decorators in TypeScript? Explain class, method, property, and parameter decorators, including the new TC39 decorators in TS 5.0.

**Answer:**
Decorators are functions that annotate and modify classes, methods, properties, or parameters. The experimental decorators (enabled with `experimentalDecorators: true`) are widely used by frameworks like Angular and NestJS. TypeScript 5.0 added support for the TC39 Stage 3 decorators, which have a different API — they receive a context object instead of the legacy descriptor arguments. Class decorators wrap or replace the class. Method decorators intercept calls. Property decorators observe and transform property access. Parameter decorators mark parameters for dependency injection metadata.

❌ **Violates — manual logging wrapper duplicated across every method:**
```typescript
class UserService {
  getUser(id: string): User {
    console.log(`getUser called with ${id}`); // ❌ logging duplicated everywhere
    const user = this.repo.find(id);
    console.log(`getUser returned`, user);
    return user;
  }
}
```

✅ **Satisfies — method decorator encapsulates cross-cutting concern:**
```typescript
// Legacy experimental decorator
function Log(target: object, key: string, descriptor: PropertyDescriptor) {
  const original = descriptor.value;
  descriptor.value = function (...args: unknown[]) {
    console.log(`${key} called with`, args);
    const result = original.apply(this, args);
    console.log(`${key} returned`, result);
    return result;
  };
  return descriptor;
}

class UserService {
  @Log
  getUser(id: string): User { return this.repo.find(id); } // ✅ logging via decorator
}

// TC39 (TS 5.0+) class decorator
function sealed(target: typeof UserService, context: ClassDecoratorContext) {
  context.addInitializer(function () { Object.seal(this); });
}

// Property decorator for validation
function MinLength(min: number) {
  return function (target: object, context: ClassFieldDecoratorContext) {
    return function (this: object, value: string) {
      if (value.length < min) throw new Error(`Must be at least ${min} chars`);
      return value;
    };
  };
}
```

---

### Q10. How does a class implement multiple interfaces? Explain interface segregation in TypeScript.

**Answer:**
A class implements multiple interfaces by listing them comma-separated after `implements`. TypeScript verifies at compile time that the class provides all required members from every interface. Interface Segregation Principle (the "I" in SOLID) states that no class should be forced to implement methods it doesn't use — prefer many small, focused interfaces over one large "fat" interface. In TypeScript, this means splitting a `UserService` interface into `UserReader`, `UserWriter`, and `UserDeleter` so that read-only consumers (e.g., a report generator) only depend on `UserReader`.

❌ **Violates — fat interface forces all consumers to depend on all methods:**
```typescript
interface UserService {
  getUser(id: string): User;
  createUser(dto: CreateUserDTO): User;
  deleteUser(id: string): void;
  sendEmail(userId: string): void; // ❌ unrelated to user CRUD
}
// Report generator must implement deleteUser even though it never deletes ❌
```

✅ **Satisfies — segregated interfaces, class implements multiple:**
```typescript
interface UserReader   { getUser(id: string): Promise<User>; listUsers(): Promise<User[]>; }
interface UserWriter   { createUser(dto: CreateUserDTO): Promise<User>; updateUser(id: string, dto: Partial<User>): Promise<User>; }
interface UserDeleter  { deleteUser(id: string): Promise<void>; }

class UserRepository implements UserReader, UserWriter, UserDeleter {
  async getUser(id: string): Promise<User> { return db.find(id); }
  async listUsers(): Promise<User[]> { return db.findAll(); }
  async createUser(dto: CreateUserDTO): Promise<User> { return db.create(dto); }
  async updateUser(id: string, dto: Partial<User>): Promise<User> { return db.update(id, dto); }
  async deleteUser(id: string): Promise<void> { await db.delete(id); }
}

// Report generator only needs UserReader ✅
class ReportService {
  constructor(private reader: UserReader) {}
  async generateReport() { const users = await this.reader.listUsers(); /* ... */ }
}
```

---

# 6. Type Guards & Narrowing

---

## 6.1 Narrowing Techniques

> 📚 Reference: https://www.typescriptlang.org/docs/handbook/2/narrowing.html
> 📚 Medium: https://blog.logrocket.com/how-to-use-type-guards-typescript/

### Q1. How does the `typeof` type guard work? What are its limitations with `object` types?

**Answer:**
`typeof` narrows primitive types: it reliably distinguishes `'string'`, `'number'`, `'boolean'`, `'bigint'`, `'symbol'`, `'undefined'`, and `'function'`. TypeScript understands `typeof` checks inside conditionals and narrows the type in each branch. The critical limitation is that `typeof null === 'object'` — a JavaScript quirk. Also, all objects, arrays, and class instances return `'object'`, so `typeof` cannot distinguish between them. For objects and class instances, use `instanceof` or user-defined type guards instead.

❌ **Violates — using typeof to distinguish object types:**
```typescript
function process(val: string | Date | null) {
  if (typeof val === 'object') {
    val.toISOString(); // ❌ val could be null here! typeof null === 'object'
  }
}
```

✅ **Satisfies — typeof for primitives, additional check for null:**
```typescript
function process(val: string | Date | null | number): string {
  if (typeof val === 'string')  return val.toUpperCase();    // ✅ string
  if (typeof val === 'number')  return val.toFixed(2);       // ✅ number
  if (val === null)             return 'null';               // ✅ null check first
  return val.toISOString();                                  // ✅ Date narrowed
}

// typeof limitation — can't distinguish object subtypes
function logObj(val: Date | RegExp | object) {
  if (typeof val === 'object') {
    // val is still Date | RegExp | object — typeof doesn't help here ❌
    // Use instanceof instead:
    if (val instanceof Date) console.log(val.toISOString());
    else if (val instanceof RegExp) console.log(val.source);
  }
}
```

---

### Q2. How does `instanceof` type guard work? What are its limitations with interfaces?

**Answer:**
`instanceof` checks whether an object was created by a particular constructor function, using the prototype chain. TypeScript narrows the type to the class within the `instanceof` branch. It works with any class but has a fundamental limitation: interfaces exist only at compile time and are erased. You cannot use `instanceof` with an interface — there is no constructor to check against. For interface-based narrowing, use user-defined type guards that inspect properties instead.

❌ **Violates — using instanceof with an interface (compile error):**
```typescript
interface Serializable { serialize(): string; }

function handle(val: Serializable | string) {
  if (val instanceof Serializable) { // ❌ Error: 'Serializable' only refers to a type
    val.serialize();
  }
}
```

✅ **Satisfies — instanceof for classes, type guards for interfaces:**
```typescript
class HttpError extends Error {
  constructor(public statusCode: number, message: string) { super(message); }
}
class NetworkError extends Error {
  constructor(public url: string, message: string) { super(message); }
}

function handleError(e: unknown): string {
  if (e instanceof HttpError)    return `HTTP ${e.statusCode}: ${e.message}`; // ✅
  if (e instanceof NetworkError) return `Network failure at ${e.url}`;
  if (e instanceof Error)        return e.message;
  return 'Unknown error';
}

// Interface narrowing — user-defined guard instead
interface Serializable { serialize(): string; }
function isSerializable(val: unknown): val is Serializable {
  return typeof val === 'object' && val !== null && typeof (val as any).serialize === 'function';
}
```

---

### Q3. How does the `in` operator narrow types? When does it distinguish union members?

**Answer:**
The `in` operator checks whether a property exists on an object and TypeScript narrows the type based on which union members could have that property. If `'swim' in animal` is true, TypeScript narrows `animal` to the union members that have a `swim` property. The `in` guard is most reliable when each union member has a unique property (or a unique combination of properties) that acts as a discriminant. It also works for narrowing `unknown` — though a user-defined type guard is more precise.

❌ **Violates — checking a property that exists on multiple union members:**
```typescript
type Fish = { swim(): void; fins: number };
type Bird = { fly(): void; fins?: number }; // fins is optional on Bird too

function move(animal: Fish | Bird) {
  if ('fins' in animal) {
    animal.swim(); // ❌ Bird might have fins? but swim doesn't exist on Bird
  }
}
```

✅ **Satisfies — `in` guard with unique discriminating properties:**
```typescript
type Fish = { swim(): void; gills: number };
type Bird = { fly(): void; wingspan: number };
type Animal = Fish | Bird;

function move(animal: Animal): void {
  if ('gills' in animal) {
    animal.swim();     // ✅ narrowed to Fish
    console.log(animal.gills);
  } else {
    animal.fly();      // ✅ narrowed to Bird
    console.log(animal.wingspan);
  }
}

// Narrowing unknown with 'in'
function processEvent(event: unknown) {
  if (typeof event === 'object' && event !== null && 'type' in event) {
    console.log((event as { type: string }).type); // ✅ safe access
  }
}
```

---

### Q4. What are user-defined type guards? How does `function isUser(x: unknown): x is User` work?

**Answer:**
A user-defined type guard is a function with a special return type annotation `paramName is Type`. When this function returns `true`, TypeScript narrows the type of `paramName` to `Type` in the calling scope. The implementation is your responsibility — TypeScript trusts the annotation without verifying it. Type guards accept `unknown` and validate arbitrary shapes, making them the correct tool for narrowing API responses, `JSON.parse` results, and interface-typed values. They compose naturally with `&&` for multi-property validation.

❌ **Violates — casting JSON parse result directly without validation:**
```typescript
const data = JSON.parse(response) as User; // ❌ no validation — trust without checking
console.log(data.name.toUpperCase()); // runtime crash if data is malformed
```

✅ **Satisfies — user-defined type guard validates before narrowing:**
```typescript
interface User { id: string; name: string; email: string; }

function isUser(x: unknown): x is User {
  return (
    typeof x === 'object' &&
    x !== null &&
    typeof (x as any).id === 'string' &&
    typeof (x as any).name === 'string' &&
    typeof (x as any).email === 'string'
  );
}

const raw = JSON.parse(response);
if (isUser(raw)) {
  console.log(raw.name.toUpperCase()); // ✅ safely narrowed to User
} else {
  throw new Error('Invalid user payload');
}

// Array filter with type guard
const items: (User | null)[] = [user1, null, user2];
const users: User[] = items.filter(isUser); // ✅ filter returns User[] not (User|null)[]
```

---

### Q5. What are assertion functions? How does `function assert(cond: unknown): asserts cond` work?

**Answer:**
Assertion functions use the `asserts` keyword in their return type annotation. If the function returns normally (without throwing), TypeScript narrows the type in the scope after the call. There are two forms: `asserts condition` — narrows based on a condition being truthy after the call — and `asserts value is Type` — narrows `value` to `Type` after the call. They are equivalent to inline `if (!condition) throw` but reusable and named, making validation logic shareable across a codebase.

❌ **Violates — inline null checks scattered everywhere:**
```typescript
function processUser(user: User | null) {
  if (!user) throw new Error('User required'); // ❌ duplicated pattern
  user.name; // narrowed only after inline check
}
function processOrder(order: Order | null) {
  if (!order) throw new Error('Order required'); // ❌ same pattern repeated
}
```

✅ **Satisfies — reusable assertion function:**
```typescript
function assert(condition: unknown, msg: string): asserts condition {
  if (!condition) throw new Error(msg);
}

function assertIsString(val: unknown): asserts val is string {
  if (typeof val !== 'string') throw new TypeError(`Expected string, got ${typeof val}`);
}

function processUser(user: User | null) {
  assert(user !== null, 'User required'); // ✅
  user.name; // TypeScript knows user is User here ✅
}

const input: unknown = getInput();
assertIsString(input);
input.toUpperCase(); // ✅ narrowed to string after assertion ✅
```

---

### Q6. What are discriminated unions and why are they the most reliable narrowing pattern?

**Answer:**
A discriminated union (also called a tagged union or algebraic data type) is a union where every member has a common property with a unique literal type — the discriminant. TypeScript's control flow analysis narrows the entire union to a single member when you check the discriminant. They are the most reliable narrowing pattern because the discriminant is always present (not optional), the literal type makes comparison exhaustive, and adding a new variant causes compile errors in all `switch` statements that don't handle it (when combined with `never` exhaustiveness checking).

❌ **Violates — optional properties lead to impossible states and unreliable narrowing:**
```typescript
interface Response {
  data?: User;
  error?: string;
  loading: boolean;
}
// Possible: { loading: false, data: user, error: 'oops' } — contradictory ❌
```

✅ **Satisfies — discriminated union makes impossible states unrepresentable:**
```typescript
type Loading  = { status: 'loading' };
type Success  = { status: 'success'; data: User };
type Failure  = { status: 'failure'; error: Error; retryable: boolean };
type Response = Loading | Success | Failure;

function render(r: Response): string {
  switch (r.status) {
    case 'loading': return 'Loading...';
    case 'success': return `Welcome ${r.data.name}`;    // ✅ r is Success here
    case 'failure': return `Error: ${r.error.message}`; // ✅ r is Failure here
    // TypeScript ensures all cases are handled ✅
  }
}

// Adding a new variant:
type Stale = { status: 'stale'; data: User; staleSince: Date };
// render() now has a type error — unhandled case 'stale' ✅
```

---

### Q7. How does exhaustiveness checking with `never` work? How do you implement it in a switch statement?

**Answer:**
Exhaustiveness checking leverages the `never` type to ensure every union variant is handled. In a switch on a discriminated union, if all cases are covered, TypeScript narrows the remaining type to `never`. Assigning `never` to a variable of type `never` is valid. If a case is missing, the remaining type is not `never`, and assigning it to a `never`-typed variable produces a compile error. The `assertNever` helper function combines this check with a runtime error for defense in depth.

❌ **Violates — switch without exhaustiveness check silently skips new variants:**
```typescript
type Shape = { kind: 'circle'; r: number } | { kind: 'rect'; w: number; h: number };

function area(s: Shape): number {
  switch (s.kind) {
    case 'circle': return Math.PI * s.r ** 2;
    // ❌ forgot 'rect' — TypeScript doesn't warn, returns undefined at runtime
  }
  return 0; // silent bug
}
```

✅ **Satisfies — exhaustiveness check catches missing cases:**
```typescript
function assertNever(x: never): never {
  throw new Error(`Unhandled case: ${JSON.stringify(x)}`);
}

type Shape =
  | { kind: 'circle'; r: number }
  | { kind: 'rect'; w: number; h: number }
  | { kind: 'triangle'; base: number; height: number };

function area(s: Shape): number {
  switch (s.kind) {
    case 'circle':   return Math.PI * s.r ** 2;
    case 'rect':     return s.w * s.h;
    case 'triangle': return 0.5 * s.base * s.height;
    default: return assertNever(s); // ✅ compile error if a case is added but not handled
  }
}
```

---

### Q8. How does TypeScript's control flow analysis track types through if/else branches, loops, and assignments?

**Answer:**
TypeScript's control flow analysis (CFA) tracks the type of a variable at every point in the code flow. After a type guard narrows a variable to a specific type, TypeScript carries that narrowing through subsequent code until the variable is reassigned or the flow merges back (e.g., after an if/else). CFA handles early returns (the common guard pattern), loops, `try/catch` blocks, and reassignments. If you reassign a variable to a value of a different type, TypeScript widens the type at the assignment point. Understanding CFA is key to writing narrowing code that avoids redundant checks.

❌ **Violates — unnecessary repeated checks because CFA is not leveraged:**
```typescript
function processValue(val: string | number | null) {
  if (val !== null) {
    if (typeof val === 'string') val.toUpperCase();
    if (typeof val === 'number') val.toFixed(); // ✅ but below check is unnecessary
  }
  if (val !== null && typeof val === 'string') val.toUpperCase(); // ❌ repeated
}
```

✅ **Satisfies — CFA correctly carries narrowing through branches:**
```typescript
function process(val: string | number | null): string {
  // Guard pattern — early return narrows for the rest of the function
  if (val === null) return 'null';
  // val is string | number here ✅

  if (typeof val === 'string') {
    return val.toUpperCase(); // val: string ✅
  }
  return val.toFixed(2); // val: number ✅ — CFA knows string branch returned

}

// Reassignment widens the type
let x: string | number = 'hello';
// x: string here
x = 42;
// x: number here — CFA tracks the assignment ✅
```

---

### Q9. How does narrowing with truthiness and equality work? When does `if (value)` remove `null` and `undefined`?

**Answer:**
Truthiness narrowing removes `null`, `undefined`, `0`, `''`, `false`, and `NaN` from the type inside an `if (value)` guard. For union types containing these falsy primitives, truthiness narrows effectively. Strict equality (`=== null`, `=== undefined`) narrows more precisely — `val === null` removes only `null`, not `undefined`. Loose equality `== null` removes both `null` and `undefined` in one check (one of the few valid uses of `==` in TypeScript). Understanding which falsy values truthiness removes is crucial — `if (port)` fails when `port = 0` is valid.

❌ **Violates — truthiness removes valid falsy values:**
```typescript
function startServer(port: number | undefined) {
  const p = port || 3000; // ❌ port=0 is a valid port but falsy — defaults to 3000 incorrectly
  listen(p);
}
```

✅ **Satisfies — precise equality for null/undefined, truthiness for strings and objects:**
```typescript
function startServer(port: number | undefined) {
  const p = port ?? 3000; // ✅ only defaults when port is null/undefined, not 0
  listen(p);
}

function processName(name: string | null | undefined): string {
  if (name) return name.trim(); // ✅ removes null, undefined, AND empty string — appropriate here
  return 'Anonymous';
}

function processAge(age: number | null | undefined): number {
  if (age === null || age === undefined) return 0; // ✅ precise — preserves age=0
  return age;
  // Equivalent: if (age == null) return 0; — loose == catches both null and undefined
}
```

---

### Q10. How do you narrow API error responses in a real-world scenario? Implement a `Result<T, E>` type.

**Answer:**
A `Result<T, E>` type (inspired by Rust's `Result`) wraps either a success value or an error, making error handling explicit and type-safe. It avoids `try/catch` hell for expected failure cases and forces callers to handle both branches. Combined with discriminated union narrowing, the type of `result.value` or `result.error` is known without casting. This pattern is increasingly common in TypeScript codebases for API clients, data parsing, and service layer operations.

❌ **Violates — throwing for expected errors forces try/catch everywhere:**
```typescript
async function getUser(id: string): Promise<User> {
  const res = await fetch(`/users/${id}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`); // ❌ callers must try/catch
  return res.json();
}
// Every call site must wrap in try/catch ❌
```

✅ **Satisfies — `Result<T, E>` makes errors explicit in the type:**
```typescript
type Ok<T>  = { ok: true;  value: T };
type Err<E> = { ok: false; error: E };
type Result<T, E = Error> = Ok<T> | Err<E>;

function ok<T>(value: T): Ok<T>   { return { ok: true, value }; }
function err<E>(error: E): Err<E> { return { ok: false, error }; }

async function getUser(id: string): Promise<Result<User>> {
  const res = await fetch(`/users/${id}`);
  if (!res.ok) return err(new Error(`HTTP ${res.status}`));
  const data = await res.json();
  return isUser(data) ? ok(data) : err(new Error('Invalid user shape'));
}

// Caller handles both branches with full type safety:
const result = await getUser('u1');
if (result.ok) {
  console.log(result.value.name); // ✅ result.value: User
} else {
  console.error(result.error.message); // ✅ result.error: Error
}
```

---

---

# ⚖️ TypeScript Comparisons — Side-by-Side Differences

---

## TS-C1 — `interface` vs `type`

| | `interface` | `type` |
|-|------------|--------|
| Extension | `extends` (open, mergeable) | `&` intersection (closed) |
| Declaration merging | ✅ Yes (add props across files) | ❌ No |
| Union types | ❌ | ✅ `type Status = 'a' \| 'b'` |
| Tuple types | ❌ | ✅ `type Pair = [string, number]` |
| Mapped / conditional types | ❌ | ✅ |
| Implements (class) | ✅ | ✅ |
| Use for | Object shapes, class contracts | Unions, intersections, aliases, utilities |

```typescript
// interface — prefer for object shapes and class contracts
interface User { name: string; email: string; }
interface Admin extends User { role: 'admin'; } // extend
interface User { age: number; } // declaration merge — adds age to User everywhere

// type — for unions, intersections, and complex types
type Status = 'pending' | 'paid' | 'shipped';       // union
type AdminUser = User & { role: 'admin' };           // intersection
type Pair<T> = [T, T];                               // tuple
type Nullable<T> = T | null;                         // utility
type Keys = keyof User;                              // 'name' | 'email'
```

---

## TS-C2 — `unknown` vs `any` vs `never`

| | `any` | `unknown` | `never` |
|-|-------|----------|---------|
| Type-safe | ❌ No (opt out of type system) | ✅ Must narrow before use | ✅ Unreachable code |
| Assignable to | Anything | Only `unknown` or `any` | Nothing |
| Can call methods | ✅ (unsafely) | ❌ Must narrow first | N/A |
| Use for | Legacy JS migration (avoid) | Safe typed catch/external data | Exhaustive checks, throw functions |

```typescript
// any — disables type checking (avoid)
let x: any = getData();
x.foo(); // no error, but crashes at runtime if x is null

// unknown — must narrow before use
let y: unknown = getData();
if (typeof y === 'string') y.toUpperCase(); // ✅ safe
// y.toUpperCase(); // ❌ compile error — must check type first

// never — exhaustive switch
type Shape = 'circle' | 'square';
function area(s: Shape): number {
  switch (s) {
    case 'circle': return Math.PI;
    case 'square': return 1;
    default:
      const _exhaustive: never = s; // compile error if new Shape added without handling
      throw new Error(`Unhandled: ${_exhaustive}`);
  }
}
```

---

## TS-C3 — `readonly` vs `const` vs `as const`

| | `const` | `readonly` | `as const` |
|-|---------|-----------|-----------|
| Scope | Variable binding (block) | Object property | Value is fully readonly + literal type |
| Prevents reassignment | ✅ Variable | ✅ Property | ✅ Entire object tree |
| Runtime effect | ✅ | ❌ (TS only) | ❌ (TS only) |
| Inferred type | Mutable type | Mutable type | Narrow literal type |

```typescript
const arr = [1, 2, 3];
arr.push(4);          // ✅ allowed — const prevents reassignment, not mutation
arr = [5];            // ❌ compile error

const arrConst = [1, 2, 3] as const;
arrConst.push(4);     // ❌ readonly array
// Type: readonly [1, 2, 3] — exact tuple, not number[]

const config = { env: 'prod', port: 3000 } as const;
// Type: { readonly env: 'prod'; readonly port: 3000 }
// Useful for string literal unions from object keys
type Env = typeof config.env; // 'prod' (literal) not string
```

---

## TS-C4 — `Partial<T>` vs `Required<T>` vs `Pick<T>` vs `Omit<T>`

| Utility | What it does | Example |
|---------|-------------|---------|
| `Partial<T>` | All props optional | Update DTOs |
| `Required<T>` | All props required | Validate complete object |
| `Pick<T, K>` | Keep only specified keys | Read-only projection |
| `Omit<T, K>` | Remove specified keys | Create DTO without ID |
| `Readonly<T>` | All props readonly | Immutable config |
| `Record<K, V>` | Map of key→value | Lookup table |

```typescript
interface User { id: number; name: string; email: string; age?: number; }

type UpdateUser  = Partial<User>;              // all optional
type FullUser    = Required<User>;             // all required (age too)
type UserPreview = Pick<User, 'id' | 'name'>; // { id; name }
type CreateUser  = Omit<User, 'id'>;          // no id (DB generates it)
type UserMap     = Record<string, User>;       // { [key: string]: User }
```

---

## TS-C5 — `enum` vs `const enum` vs Union String Literals

| | `enum` | `const enum` | String Literal Union |
|-|--------|-------------|---------------------|
| Runtime object | ✅ Exists in JS output | ❌ Inlined at compile time | ❌ No runtime object |
| Reverse mapping | ✅ `Status[0]` = `'Active'` | ❌ | ❌ |
| Bundle size | Larger | ✅ Smaller (inlined) | ✅ Smallest |
| Type safety | ✅ | ✅ | ✅ |
| Use for | When you need runtime iteration | Constant values, no runtime needed | Most cases — simplest |

```typescript
// enum — generates JS object
enum Status { Pending = 'pending', Paid = 'paid' }
console.log(Status.Paid); // 'paid'

// const enum — inlined, no runtime object
const enum Direction { Up, Down }
let d = Direction.Up; // compiled to: let d = 0

// String literal union — simplest, no overhead
type Status = 'pending' | 'paid' | 'shipped';
let s: Status = 'paid'; // ✅
let bad: Status = 'unknown'; // ❌ compile error
```

---

## TS-C6 — `?.` Optional Chaining vs `??` Nullish Coalescing vs `||` OR

| | `?.` | `??` | `\|\|` |
|-|----|-----|------|
| Purpose | Safe property access | Default for null/undefined | Default for falsy |
| Returns default for | `null` / `undefined` access | `null` / `undefined` | `0`, `''`, `false`, `null`, `undefined` |
| Short-circuits on | null/undefined | null/undefined | Any falsy |

```typescript
const user = getUser(); // might be null

// ?. — safe navigation
const name = user?.profile?.name; // undefined if user or profile is null

// ?? — default only for null/undefined
const count = user?.orderCount ?? 0; // 0 if null/undefined, keeps 0 if actually 0

// || — replaces ALL falsy values (dangerous for numbers/booleans)
const count2 = user?.orderCount || 0;
// ❌ If orderCount = 0 (valid), returns 0 via ||, looks correct by accident
// ❌ If orderCount = 0, user?.orderCount || 10 → 10, WRONG! (0 is falsy)
// ✅ Use ?? for numbers and booleans
```

---

## TS-C7 — Generic Constraints vs Conditional Types vs Mapped Types

```typescript
// Generic constraint — T must have specific shape
function getLength<T extends { length: number }>(item: T): number {
  return item.length; // safe — T guaranteed to have length
}

// Conditional type — type depends on input type
type IsString<T> = T extends string ? 'yes' : 'no';
type A = IsString<string>;  // 'yes'
type B = IsString<number>;  // 'no'

// Practical: NonNullable — strips null/undefined
type NonNullable<T> = T extends null | undefined ? never : T;
type C = NonNullable<string | null>; // string

// Mapped type — transform every property
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
};
type UserGetters = Getters<{ name: string; age: number }>;
// { getName: () => string; getAge: () => number }
```


---

# ⚖️ TypeScript Comparisons — Side-by-Side Differences

---

## TS-C1 — `interface` vs `type`

| | `interface` | `type` |
|-|------------|--------|
| Extension | ✅ `extends` + declaration merging | ✅ `&` intersection (no merging) |
| Union types | ❌ | ✅ `type Status = "A" \| "B"` |
| Tuple types | ❌ | ✅ `type Pair = [string, number]` |
| Primitive alias | ❌ | ✅ `type ID = string` |
| Declaration merging | ✅ Multiple declarations merge | ❌ Error if redeclared |
| Mapped/conditional types | ❌ | ✅ |
| Prefer for | Object shapes, classes, APIs | Unions, tuples, complex types |

```ts
// interface — for object shapes, class contracts
interface User { id: number; name: string; }
interface Admin extends User { role: "admin"; } // extends
interface User { email: string; }               // ✅ merges with first declaration

// type — for unions, tuples, computed types
type Status  = "pending" | "shipped" | "cancelled"; // union — only type can do this
type Point   = [number, number];                     // tuple
type Partial<T> = { [K in keyof T]?: T[K] };       // mapped type

// Both equivalent for object shapes — prefer interface for objects
interface OrderI { id: string; total: number; }
type OrderT = { id: string; total: number; };
```

---

## TS-C2 — `any` vs `unknown` vs `never` vs `void`

| | `any` | `unknown` | `never` | `void` |
|-|-------|-----------|---------|--------|
| Assignable from | Anything | Anything | Nothing | Only `undefined` |
| Assignable to | Anything | Only `unknown` or `any` | Anything | Only `void`/`undefined` |
| Type-safe | ❌ Disables checking | ✅ Must narrow before use | ✅ | ✅ |
| Use for | Legacy JS migration | Safe unknown input | Unreachable code / exhaustive check | Functions returning nothing |

```ts
// any — escape hatch, disables TypeScript
let x: any = "hello";
x.toFixed();   // ❌ no error at compile time → runtime crash

// unknown — type-safe any: must narrow before use
let y: unknown = "hello";
y.toUpperCase(); // ❌ compile error
if (typeof y === "string") y.toUpperCase(); // ✅ narrowed

// never — exhaustive checks, unreachable paths
function assertNever(x: never): never {
  throw new Error(`Unexpected: ${JSON.stringify(x)}`);
}
type Shape = "circle" | "square";
function area(s: Shape) {
  switch (s) {
    case "circle": return Math.PI;
    case "square": return 1;
    default: return assertNever(s); // compile error if Shape gets new case
  }
}

// void — function with no return value
function log(msg: string): void { console.log(msg); }
```

---

## TS-C3 — `enum` vs `const enum` vs Union String Literal

| | `enum` | `const enum` | Union Literal (`"A" \| "B"`) |
|-|--------|-------------|------------------------------|
| Runtime object | ✅ Exists in JS output | ❌ Inlined (no JS object) | ❌ Erased at compile time |
| Reverse mapping | ✅ `Status[0] === "Active"` | ❌ | ❌ |
| Tree-shaking | ❌ Bundle includes enum object | ✅ Fully inlined | ✅ No runtime cost |
| Type safety | ✅ | ✅ | ✅ |
| Use for | When you need reverse lookup or runtime object | Perf-critical constant lookup | ✅ Default — prefer for most cases |

```ts
// enum — generates runtime object
enum Status { Pending = "pending", Shipped = "shipped" }
console.log(Status.Pending); // "pending" — exists at runtime

// const enum — inlined, no runtime object
const enum Direction { Up = "UP", Down = "DOWN" }
// compiles to: if (dir === "UP") (no enum object in output)

// Union literal — zero runtime cost, most readable
type Status = "pending" | "shipped" | "cancelled";
// ✅ Recommended: no runtime object, full type safety, easily extended
```

---

## TS-C4 — `as` (Type Assertion) vs Type Guard vs `satisfies`

| | `as T` | Type Guard (`is T`) | `satisfies` (TS 4.9) |
|-|--------|--------------------|-----------------------|
| Compile-time check | Overrides — may be wrong | Actual runtime check | Validates + preserves literal type |
| Runtime safety | ❌ No | ✅ Yes | ❌ No (compile only) |
| Narrows type | One-time cast | ✅ In scope after check | Validates without widening |
| Use for | When you know better than TS | Runtime discrimination | Config objects with inference |

```ts
// as — override, no safety guarantee
const el = document.getElementById("myBtn") as HTMLButtonElement; // TS trusts you

// Type guard — safe narrowing
function isString(x: unknown): x is string {
  return typeof x === "string"; // runtime check
}
if (isString(value)) value.toUpperCase(); // ✅ safe

// satisfies — validate shape without widening type
const palette = {
  red:   [255, 0, 0],
  green: "#00ff00",
} satisfies Record<string, string | number[]>;
palette.red;   // type: number[] (literal preserved, not widened to string | number[])
palette.green; // type: string
```

---

## TS-C5 — `Partial<T>` vs `Required<T>` vs `Readonly<T>` vs `Pick<T>` vs `Omit<T>`

| Utility | Effect | Use for |
|---------|--------|---------|
| `Partial<T>` | All properties optional | Update DTOs, patch operations |
| `Required<T>` | All properties required | Enforce after partial fill |
| `Readonly<T>` | All properties readonly | Immutable config, frozen objects |
| `Pick<T, K>` | Only selected keys | Projection, subset DTO |
| `Omit<T, K>` | All except selected keys | Remove sensitive fields (password) |
| `Record<K, V>` | Object with specific key/value types | Dictionaries, lookup maps |

```ts
interface User { id: number; name: string; email: string; password: string; }

type UpdateDto   = Partial<User>;          // all optional → PATCH body
type CreateDto   = Omit<User, "id">;       // no id (DB generates it)
type PublicUser  = Omit<User, "password">; // strip sensitive field
type UserSummary = Pick<User, "id" | "name">; // only what UI needs
type UserMap     = Record<number, User>;   // { [id]: User }

// Combining utilities
type PatchDto = Partial<Omit<User, "id">>; // all optional except id
```

---

## TS-C6 — `T extends U` vs `T & U` vs `T | U`

| | `T \| U` (Union) | `T & U` (Intersection) | `T extends U` (Constraint) |
|-|----------------|----------------------|--------------------------|
| Meaning | Either T or U | Both T and U simultaneously | T must be assignable to U |
| Type narrowing | Required (could be either) | All properties available | Generic constraint |
| Use for | Function can accept multiple types | Mixins, combined shapes | Generic type bounds |

```ts
// Union — can be one or the other
type StringOrNumber = string | number;
function print(x: string | number) {
  if (typeof x === "string") x.toUpperCase(); // must narrow
  else x.toFixed(2);
}

// Intersection — must satisfy both
type Timestamped = { createdAt: Date };
type Named       = { name: string };
type Entity      = Timestamped & Named; // must have both createdAt AND name

// Extends — generic constraint
function getLength<T extends { length: number }>(x: T): number {
  return x.length; // guaranteed to have .length (string, array, etc.)
}
```

---

## TS-C7 — `readonly` vs `const` vs `as const`

| | `const` | `readonly` (property) | `as const` |
|-|---------|----------------------|-----------|
| Scope | Variable binding | Class/interface property | Literal type inference |
| Mutates object | ✅ (binding fixed, content mutable) | ❌ | ❌ Deep readonly |
| Affects | Variable re-assignment | Object property assignment | Entire expression literal type |

```ts
const arr = [1, 2, 3];
arr.push(4); // ✅ const doesn't prevent mutation

// as const — deepest readonly, narrows to literal types
const config = { env: "prod", port: 3000 } as const;
// type: { readonly env: "prod"; readonly port: 3000 }
config.env = "dev"; // ❌ compile error — readonly

// Useful for exhaustive checks
const STATUSES = ["pending", "shipped", "cancelled"] as const;
type Status = typeof STATUSES[number]; // "pending" | "shipped" | "cancelled"
```

---

## TS-C8 — Generics: `T` vs `T extends object` vs `T extends keyof U`

```ts
// Unconstrained generic — accepts anything
function identity<T>(x: T): T { return x; }

// Constrained — must have specific shape
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]; // type-safe property access
}
const name = getProperty({ name: "Alice", age: 30 }, "name"); // type: string

// Conditional type
type IsArray<T> = T extends any[] ? "yes" : "no";
type A = IsArray<string[]>; // "yes"
type B = IsArray<string>;   // "no"

// Infer — extract type from generic
type UnpackPromise<T> = T extends Promise<infer U> ? U : T;
type Result = UnpackPromise<Promise<string>>; // string
```

