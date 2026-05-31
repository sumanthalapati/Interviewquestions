# 🟡 JavaScript Interview Questions — Complete Guide

> **100+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Core Language & Variables](#1-core-language--variables)
2. [Functions & Scope](#2-functions--scope)
3. [this Keyword & Context](#3-this-keyword--context)
4. [Prototypes & Inheritance](#4-prototypes--inheritance)
5. [Async JavaScript](#5-async-javascript)
6. [Event Loop & Concurrency](#6-event-loop--concurrency)
7. [ES6+ Modern Features](#7-es6-modern-features)
8. [Arrays & Objects](#8-arrays--objects)
9. [Error Handling & Debugging](#9-error-handling--debugging)
10. [Browser APIs & DOM](#10-browser-apis--dom)

---

# 1. Core Language & Variables

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Grammar_and_types
> 📚 Medium: https://medium.com/javascript-scene/javascript-es6-var-let-or-const-ba58b8dcde75

---

## 1.1 var, let, const & Scope

### Q1. How do var, let, and const differ in scope, hoisting, and the temporal dead zone (TDZ)? When should you use each?

**Answer:**
`var` is function-scoped and hoisted with `undefined` as its initial value — it is accessible before declaration. `let` and `const` are block-scoped and hoisted but NOT initialized, creating the Temporal Dead Zone (TDZ) — accessing them before declaration throws `ReferenceError`. Use `const` by default; `let` when you need to reassign; avoid `var` in modern code entirely. `const` does not make objects immutable — it prevents reassignment of the binding, not mutation of the object's properties.

❌ **Violates — var leaks out of blocks and hoisting causes silent bugs:**
```javascript
console.log(x); // undefined — var is hoisted, no error but wrong ❌
var x = 5;

for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // prints 3, 3, 3 — var leaked ❌
}

if (true) {
  var secret = 'leaked';
}
console.log(secret); // 'leaked' — var is NOT block-scoped ❌
```

✅ **Satisfies — use let/const with proper block scoping:**
```javascript
const API_URL = 'https://api.example.com'; // const by default

let count = 0; // let when reassignment needed
count++;

for (let i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // prints 0, 1, 2 ✅
}

// TDZ: fails fast — better than silent undefined
// console.log(y); // ReferenceError: Cannot access 'y' before initialization
let y = 10;
```

---

## 1.2 Data Types

### Q2. What are JavaScript's data types? Explain primitives vs objects and the typeof operator quirks.

**Answer:**
JavaScript has 7 primitive types: `string`, `number`, `boolean`, `null`, `undefined`, `symbol`, and `bigint`. Everything else is an object. Primitives are immutable and compared by value; objects are compared by reference. The `typeof` operator has a well-known quirk: `typeof null === 'object'` — a historical bug that can never be fixed for backwards compatibility. `typeof` a function returns `'function'` even though functions are objects.

❌ **Violates — relying on typeof null and confusing reference vs value equality:**
```javascript
if (typeof null === 'object') {
  // this is TRUE — a bug you'll hit if you check this way ❌
  console.log('null is an object'); // executes!
}

const a = { x: 1 };
const b = { x: 1 };
console.log(a === b); // false — different references ❌ (surprising to beginners)

typeof function(){} === 'object'; // false — returns 'function' ❌ (inconsistent)
```

✅ **Satisfies — correct null check and value comparisons:**
```javascript
// Correct null check
function isNull(val) {
  return val === null; // use strict equality, not typeof
}

// Checking all primitives correctly
console.log(typeof 'hello');     // 'string'
console.log(typeof 42);          // 'number'
console.log(typeof true);        // 'boolean'
console.log(typeof undefined);   // 'undefined'
console.log(typeof Symbol());    // 'symbol'
console.log(typeof 42n);         // 'bigint'
console.log(typeof null);        // 'object' — known quirk, use === null instead

// Object reference comparison
const a = { x: 1 };
const b = a;
console.log(a === b); // true — same reference ✅

// Deep equality needs JSON or library
console.log(JSON.stringify({ x: 1 }) === JSON.stringify({ x: 1 })); // true ✅
```

---

## 1.3 Type Coercion

### Q3. How does type coercion work in JavaScript? What is the difference between == and ===? What are truthy/falsy values?

**Answer:**
`==` performs abstract equality comparison with implicit type coercion; `===` performs strict equality with no coercion. JavaScript's coercion rules follow the Abstract Equality Comparison algorithm — `null == undefined` is `true`, but `null === undefined` is `false`. Falsy values are: `false`, `0`, `''`, `null`, `undefined`, `NaN`, and `0n`. Everything else is truthy, including `[]` and `{}`. Some coercions are especially surprising: `+[] === 0`, `+'' === 0`, `[] == false`.

❌ **Violates — using == leads to subtle bugs:**
```javascript
0 == false;       // true ❌
'' == false;      // true ❌
null == 0;        // false (but null == undefined is true) ❌ confusing
[] == false;      // true ❌
[] == ![];        // true ❌ (both sides coerce to 0)
NaN == NaN;       // false ❌ NaN is not equal to itself

if (value == null) { // catches both null AND undefined — misleading intent ❌
}
```

✅ **Satisfies — use === and explicit checks:**
```javascript
// Always use ===
0 === false;      // false ✅
'' === false;     // false ✅
NaN === NaN;      // false — use Number.isNaN() instead
Number.isNaN(NaN); // true ✅

// Explicit null/undefined check when intentional
if (value === null || value === undefined) { /* ... */ }
// Or use nullish coalescing
const result = value ?? 'default';

// Falsy check awareness
const falsy = [false, 0, '', null, undefined, NaN, 0n];
const truthy = [[], {}, 'false', -1, Infinity]; // all truthy!

// Intentional coercion with explicit comment
const num = +inputString; // convert string to number — explicit intent ✅
```

---

## 1.4 Destructuring

### Q4. Explain array and object destructuring including default values, renaming, nested destructuring, and rest.

**Answer:**
Destructuring is a syntax for unpacking values from arrays or properties from objects into distinct variables. Object destructuring uses `{}` and matches by key name; array destructuring uses `[]` and matches by position. You can provide default values with `=`, rename variables with `:`, and collect the rest with `...rest`. Nested destructuring allows extracting deeply nested values in a single expression.

❌ **Violates — verbose manual property extraction:**
```javascript
const user = { name: 'Alice', address: { city: 'NY', zip: '10001' } };

// Tedious, repetitive ❌
const name = user.name;
const city = user.address.city;
const zip = user.address.zip;
const role = user.role !== undefined ? user.role : 'guest'; // manual default ❌

const arr = [1, 2, 3];
const first = arr[0];
const second = arr[1];
```

✅ **Satisfies — clean destructuring with all features:**
```javascript
const user = { name: 'Alice', age: 30, address: { city: 'NY', zip: '10001' } };

// Object destructuring with rename and default
const { name, age, role = 'guest', address: { city, zip } } = user;
console.log(name, city, role); // 'Alice' 'NY' 'guest'

// Rename: extract 'name' into variable 'userName'
const { name: userName } = user;

// Array destructuring with skip and rest
const [first, , third, ...rest] = [1, 2, 3, 4, 5];
console.log(first, third, rest); // 1 3 [4, 5]

// Swapping variables without temp
let a = 1, b = 2;
[a, b] = [b, a];
console.log(a, b); // 2 1 ✅

// Function parameter destructuring
function greet({ name, role = 'user' }) {
  return `Hello ${name} (${role})`;
}
```

---

## 1.5 Spread and Rest

### Q5. Explain spread and rest operators. How does spread clone arrays/objects and how does it differ from Object.assign?

**Answer:**
The spread operator (`...`) expands an iterable into individual elements when used in expressions. The rest parameter (`...`) collects remaining arguments into an array when used in function signatures. Both use the same syntax but in opposite directions. Spread creates a **shallow copy** — nested objects are still referenced. `Object.assign` also does a shallow copy, but spread is preferred because it's more readable and also copies Symbol-keyed properties.

❌ **Violates — mutating original array/object, misusing spread:**
```javascript
// Mutating original ❌
const arr = [1, 2, 3];
const copy = arr; // NOT a copy — same reference ❌
copy.push(4);
console.log(arr); // [1, 2, 3, 4] — original mutated! ❌

// Thinking spread is a deep copy ❌
const obj = { a: { b: 1 } };
const copy2 = { ...obj };
copy2.a.b = 99;
console.log(obj.a.b); // 99 — nested object is still shared ❌
```

✅ **Satisfies — correct spread usage:**
```javascript
// Shallow copy arrays
const arr = [1, 2, 3];
const copy = [...arr];
copy.push(4);
console.log(arr); // [1, 2, 3] — original untouched ✅

// Merge objects (later keys win)
const defaults = { theme: 'light', lang: 'en' };
const userPrefs = { lang: 'fr' };
const config = { ...defaults, ...userPrefs }; // { theme: 'light', lang: 'fr' } ✅

// Rest parameters — preferred over arguments object
function sum(...nums) {
  return nums.reduce((a, b) => a + b, 0);
}
sum(1, 2, 3, 4); // 10 ✅

// Spread vs Object.assign — both shallow
// Object.assign mutates first arg; spread creates new object
const merged = Object.assign({}, defaults, userPrefs); // same result, less readable
const merged2 = { ...defaults, ...userPrefs }; // preferred ✅
```

---

## 1.6 Template Literals

### Q6. What are template literals? Explain tagged templates and their use cases.

**Answer:**
Template literals (backtick strings) allow embedded expressions with `${expression}`, multi-line strings without `\n`, and tagged templates. Tagged templates call a function with the string parts and interpolated values as separate arguments — enabling powerful patterns like SQL query sanitization, styled-components CSS-in-JS, and internationalization. The tag function receives a `strings` array of static parts and the interpolated values as rest arguments.

❌ **Violates — string concatenation and unsafe SQL:**
```javascript
// Verbose string concatenation ❌
const name = 'Alice';
const greeting = 'Hello, ' + name + '! You have ' + (messages.length) + ' messages.';

// Multi-line is awkward ❌
const html = '<div>\n' +
             '  <p>Content</p>\n' +
             '</div>';

// Unsafe SQL with user input ❌ (SQL injection risk)
const query = 'SELECT * FROM users WHERE id = ' + userId;
```

✅ **Satisfies — template literals and tagged templates:**
```javascript
const name = 'Alice';
const count = 5;

// Clean interpolation
const greeting = `Hello, ${name}! You have ${count} messages.`;

// Multi-line
const html = `
  <div>
    <p>${greeting}</p>
  </div>
`;

// Tagged template for safe SQL
function sql(strings, ...values) {
  return {
    text: strings.reduce((acc, str, i) => acc + str + (i < values.length ? `$${i + 1}` : ''), ''),
    values
  };
}
const userId = 42;
const query = sql`SELECT * FROM users WHERE id = ${userId}`;
// { text: 'SELECT * FROM users WHERE id = $1', values: [42] } ✅

// Tagged template for highlighting
function highlight(strings, ...values) {
  return strings.reduce((acc, str, i) =>
    acc + str + (values[i] !== undefined ? `<mark>${values[i]}</mark>` : ''), '');
}
```

---

## 1.7 Optional Chaining and Nullish Coalescing

### Q7. Explain optional chaining (?.), nullish coalescing (??), and logical assignment operators (??=, ||=, &&=).

**Answer:**
Optional chaining (`?.`) short-circuits and returns `undefined` if the left side is `null` or `undefined`, preventing TypeError on deeply nested property access. Nullish coalescing (`??`) returns the right side only when the left is `null` or `undefined` — unlike `||` which also triggers for `0`, `''`, and `false`. Logical assignment operators combine logical operations with assignment: `a ??= b` sets `a` only if `a` is nullish; `a ||= b` sets `a` if falsy; `a &&= b` sets `a` only if truthy.

❌ **Violates — verbose null checks and || for defaults causing bugs:**
```javascript
// Verbose nested null check ❌
const city = user && user.address && user.address.city;

// || default clobbers valid falsy values ❌
const port = config.port || 3000; // if port is 0, incorrectly uses 3000 ❌
const name = user.name || 'Anonymous'; // if name is '', uses 'Anonymous' ❌

// Manual conditional assignment ❌
if (obj.cache === null || obj.cache === undefined) {
  obj.cache = new Map();
}
```

✅ **Satisfies — modern operators:**
```javascript
// Optional chaining
const city = user?.address?.city; // undefined if any part is null/undefined ✅
const firstTag = article?.tags?.[0]; // works on arrays too
const len = str?.length ?? 0;

// Method calls
const result = obj?.method?.(); // won't throw if method doesn't exist ✅

// ?? vs || 
const port = config.port ?? 3000; // only uses 3000 if port is null/undefined ✅
// port = 0 → uses 0 ✅

// Logical assignment
let cache = null;
cache ??= new Map(); // assigns only if null/undefined ✅

let enabled = false;
enabled ||= getDefaultEnabled(); // assigns if falsy

let user = getUser();
user &&= formatUser(user); // transforms only if truthy ✅
```

---

## 1.8 Short-Circuit Evaluation

### Q8. How does short-circuit evaluation work with || and &&? What are practical patterns?

**Answer:**
In `a || b`, JavaScript evaluates `a` first — if it's truthy, `b` is never evaluated and `a` is returned. In `a && b`, if `a` is falsy, `b` is never evaluated and `a` is returned. These operators return the actual value that determined the result, not just `true`/`false`. This enables patterns like default values with `||`, guards with `&&`, and conditional rendering in JSX.

❌ **Violates — verbose conditionals instead of short-circuit:**
```javascript
// Verbose ❌
let displayName;
if (user.name) {
  displayName = user.name;
} else {
  displayName = 'Anonymous';
}

// Calling function without guard ❌
function process(callback) {
  callback(); // throws if callback is undefined ❌
}

// Not leveraging && for conditional execution ❌
if (isLoggedIn) {
  renderDashboard();
}
```

✅ **Satisfies — short-circuit patterns:**
```javascript
// Default value with ||
const displayName = user.name || 'Anonymous';

// Guard with &&
function process(callback) {
  callback && callback(); // safe call ✅
  // Modern: callback?.() is even better
}

// Conditional rendering (JSX-like)
const element = isLoggedIn && <Dashboard />;

// Short-circuit for lazy computation
const value = cache.get(key) || expensiveCompute(key);

// Chained defaults
const lang = user.lang || browser.lang || 'en';

// && for guard chains
const city = user && user.address && user.address.city;
// Modern equivalent: user?.address?.city

// Avoid side effects in short-circuit — be explicit
isDebug && console.log('debug info'); // acceptable for logging ✅
```

---

## 1.9 Symbol

### Q9. What is Symbol? How does Symbol() ensure uniqueness? What are well-known Symbols?

**Answer:**
`Symbol()` creates a unique, immutable primitive value — no two Symbols are ever equal, even with the same description. Symbols are often used as unique property keys to avoid naming collisions, especially in libraries. Well-known Symbols are built-in Symbol properties that allow objects to customize JavaScript's core behavior: `Symbol.iterator` makes an object iterable, `Symbol.toPrimitive` controls type conversion, `Symbol.hasInstance` customizes `instanceof`.

❌ **Violates — using strings as "unique" keys causes collisions:**
```javascript
// String keys can collide ❌
const ID = 'id';
const obj = {};
obj[ID] = 1;
// Some other library also uses 'id' — collision! ❌

// Symbols not equal even with same description — beginners miss this
const s1 = Symbol('tag');
const s2 = Symbol('tag');
console.log(s1 === s2); // false — symbols are always unique
// But if you WANT global sharing, use Symbol.for()
```

✅ **Satisfies — symbols for unique keys and well-known symbols:**
```javascript
// Unique property keys
const ID = Symbol('id');
const obj = {};
obj[ID] = 42;
// No collision with string 'id' properties ✅

// Symbols are not enumerable in for...in or Object.keys
const key = Symbol('key');
const o = { [key]: 'value', name: 'Alice' };
Object.keys(o); // ['name'] — symbol not included ✅
Object.getOwnPropertySymbols(o); // [Symbol(key)] ✅

// Global symbol registry
const s1 = Symbol.for('shared');
const s2 = Symbol.for('shared');
console.log(s1 === s2); // true — same symbol from registry ✅

// Well-known Symbol: making object iterable
const range = {
  from: 1, to: 5,
  [Symbol.iterator]() {
    let current = this.from;
    const last = this.to;
    return {
      next() {
        return current <= last
          ? { value: current++, done: false }
          : { done: true };
      }
    };
  }
};
console.log([...range]); // [1, 2, 3, 4, 5] ✅

// Symbol.toPrimitive
const money = {
  amount: 100,
  [Symbol.toPrimitive](hint) {
    if (hint === 'number') return this.amount;
    if (hint === 'string') return `$${this.amount}`;
    return this.amount;
  }
};
console.log(+money);    // 100
console.log(`${money}`); // '$100'
```

---

## 1.10 BigInt

### Q10. When should you use BigInt? How does arithmetic work and what are the restrictions when mixing with Number?

**Answer:**
`BigInt` handles integers beyond `Number.MAX_SAFE_INTEGER` (2^53 - 1). Use it for precise integer arithmetic with large numbers such as database IDs, cryptographic values, or financial calculations requiring exact integers. BigInt literals end with `n` (e.g., `42n`). You cannot mix BigInt and Number in arithmetic directly — it throws a TypeError. BigInt does not support decimal fractions and cannot be used with Math methods.

❌ **Violates — using Number for large integers loses precision:**
```javascript
// Number loses precision beyond MAX_SAFE_INTEGER ❌
console.log(Number.MAX_SAFE_INTEGER); // 9007199254740991
console.log(9007199254740992 === 9007199254740993); // true ❌ (wrong!)

// Mixing BigInt and Number throws ❌
const big = 42n;
const small = 1;
console.log(big + small); // TypeError: Cannot mix BigInt and other types ❌

// BigInt with Math functions ❌
Math.sqrt(9n); // TypeError ❌
```

✅ **Satisfies — BigInt for large integers with correct usage:**
```javascript
// Large integer precision
const bigId = 9007199254740993n;
console.log(bigId); // 9007199254740993n — exact! ✅

// Arithmetic with BigInt
const a = 100n;
const b = 200n;
console.log(a + b); // 300n
console.log(a * b); // 20000n
console.log(b / a); // 2n (integer division, no decimals)

// Correct way to mix: explicit conversion
const num = 5;
const result = BigInt(num) + 10n; // 15n ✅

// Comparison with Number (== works, === doesn't)
console.log(1n == 1);  // true (loose equality)
console.log(1n === 1); // false (different types)

// Check if number is safe integer
function safeAdd(a, b) {
  const result = a + b;
  if (!Number.isSafeInteger(result)) {
    return BigInt(a) + BigInt(b); // fallback to BigInt
  }
  return result;
}
```

---

# 2. Functions & Scope

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Functions
> 📚 Medium: https://medium.com/javascript-scene/master-the-javascript-interview-what-is-a-closure-b2f0d2152b36

---

## 2.1 Function Types

### Q11. How do function declarations, expressions, and arrow functions differ in hoisting, `this` binding, and the arguments object?

**Answer:**
Function declarations are fully hoisted — you can call them before they appear in the source. Function expressions (including arrow functions assigned to variables) are only hoisted as `undefined` if declared with `var`, or not at all with `let`/`const`. Arrow functions do not have their own `this` — they inherit `this` from the enclosing lexical scope. Arrow functions also lack the `arguments` object and cannot be used as constructors.

❌ **Violates — using arrow functions where regular functions needed, and calling before declaration:**
```javascript
// Arrow function as constructor ❌
const Person = (name) => { this.name = name; };
new Person('Alice'); // TypeError: Person is not a constructor ❌

// Arrow function loses this in method ❌
const obj = {
  value: 42,
  getValue: () => this.value // 'this' is outer scope, not obj ❌
};

// arguments in arrow function ❌
const args = () => console.log(arguments); // ReferenceError ❌
```

✅ **Satisfies — right function type for the context:**
```javascript
// Declaration — hoisted, can call before definition
greet('Alice'); // works! ✅
function greet(name) { return `Hello, ${name}`; }

// Expression — not hoisted
const double = function(x) { return x * 2; };

// Arrow — no this, no arguments, concise
const add = (a, b) => a + b;

// Method should be regular function for correct 'this'
const obj = {
  value: 42,
  getValue() { return this.value; } // shorthand method ✅
};

// Arrow works great in callbacks (inherits outer this)
class Timer {
  constructor() { this.count = 0; }
  start() {
    setInterval(() => this.count++, 1000); // 'this' is Timer instance ✅
  }
}

// Rest params replace arguments
function sum(...args) {
  return args.reduce((a, b) => a + b, 0);
}
```

---

## 2.2 Closures

### Q12. What is a closure? What are practical use cases and the common loop pitfall?

**Answer:**
A closure is a function that retains access to its outer (enclosing) scope even after that outer function has returned. Closures are created every time a function is created. They enable private state, factory functions, partial application, and memoization. The classic loop pitfall occurs when `var` is used — all closures share the same `i` variable; the fix is to use `let` (block scope) or wrap in an IIFE.

❌ **Violates — var in loop closures all share same variable:**
```javascript
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 100); // prints 3, 3, 3 ❌
}

// No encapsulation — counter is global ❌
let count = 0;
function increment() { count++; }
function getCount() { return count; }
// count is exposed and mutable from outside ❌
```

✅ **Satisfies — closures for private state and correct loop:**
```javascript
// Private state via closure
function makeCounter(initial = 0) {
  let count = initial; // private — not accessible outside
  return {
    increment() { count++; },
    decrement() { count--; },
    getCount() { return count; }
  };
}
const counter = makeCounter(10);
counter.increment();
console.log(counter.getCount()); // 11 ✅
// count is inaccessible directly ✅

// Loop fix with let (each iteration has own block scope)
for (let i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 100); // prints 0, 1, 2 ✅
}

// Factory function
function multiplier(factor) {
  return (number) => number * factor; // closes over 'factor'
}
const double = multiplier(2);
const triple = multiplier(3);
console.log(double(5)); // 10
console.log(triple(5)); // 15
```

---

## 2.3 IIFE

### Q13. What is an IIFE and what problem does it solve? What are modern alternatives?

**Answer:**
An IIFE (Immediately Invoked Function Expression) is a function that is defined and called in the same expression. It was used to create a private scope, avoiding polluting the global namespace before ES6 modules and block scoping existed. Modern alternatives include ES6 modules (which have their own scope), block scope with `let`/`const`, and explicit closures.

❌ **Violates — polluting global scope without IIFE:**
```javascript
// Everything leaks to global ❌
var x = 10;
var result = x * 2;
function helper() { return result + 1; }
// x, result, helper are all global ❌
```

✅ **Satisfies — IIFE and modern alternatives:**
```javascript
// Classic IIFE — function wrapped in parens and immediately called
(function() {
  var x = 10;
  var result = x * 2;
  console.log(result); // 20
})(); // x and result are private ✅

// Arrow IIFE
(() => {
  const setup = 'done';
  console.log(setup);
})();

// IIFE with return value
const config = (() => {
  const env = 'production';
  return { env, debug: env !== 'production' };
})();

// Modern alternative: block scope
{
  const x = 10;
  const result = x * 2;
  // x and result scoped to block ✅
}

// Best modern alternative: ES6 modules
// Each file is its own scope — no IIFE needed ✅
export function helper() { /* ... */ }
```

---

## 2.4 Higher-Order Functions

### Q14. What are higher-order functions? Implement map, filter, and reduce from scratch.

**Answer:**
A higher-order function is a function that either takes one or more functions as arguments or returns a function. JavaScript's built-in array methods like `map`, `filter`, and `reduce` are higher-order functions. Understanding them deeply means being able to implement them — `map` transforms each element, `filter` selects elements by predicate, `reduce` accumulates a result by applying a function to each element.

❌ **Violates — imperative loops instead of declarative higher-order functions:**
```javascript
// Verbose, mutation-heavy ❌
const nums = [1, 2, 3, 4, 5];
const doubled = [];
for (let i = 0; i < nums.length; i++) {
  doubled.push(nums[i] * 2); // mutating outside array ❌
}

const evens = [];
for (let i = 0; i < nums.length; i++) {
  if (nums[i] % 2 === 0) evens.push(nums[i]);
}
```

✅ **Satisfies — declarative higher-order functions and custom implementations:**
```javascript
// Using built-in HOFs
const nums = [1, 2, 3, 4, 5];
const doubled = nums.map(x => x * 2);        // [2, 4, 6, 8, 10]
const evens = nums.filter(x => x % 2 === 0); // [2, 4]
const sum = nums.reduce((acc, x) => acc + x, 0); // 15

// Custom map implementation
Array.prototype.myMap = function(callback) {
  const result = [];
  for (let i = 0; i < this.length; i++) {
    result.push(callback(this[i], i, this));
  }
  return result;
};

// Custom filter
Array.prototype.myFilter = function(predicate) {
  const result = [];
  for (let i = 0; i < this.length; i++) {
    if (predicate(this[i], i, this)) result.push(this[i]);
  }
  return result;
};

// Custom reduce
Array.prototype.myReduce = function(callback, initialValue) {
  let acc = initialValue !== undefined ? initialValue : this[0];
  const start = initialValue !== undefined ? 0 : 1;
  for (let i = start; i < this.length; i++) {
    acc = callback(acc, this[i], i, this);
  }
  return acc;
};

// Returning a function (HOF)
function withLogging(fn) {
  return function(...args) {
    console.log(`Calling with`, args);
    const result = fn(...args);
    console.log(`Result:`, result);
    return result;
  };
}
const loggedAdd = withLogging((a, b) => a + b);
loggedAdd(2, 3); // logs and returns 5 ✅
```

---

## 2.5 Currying and Partial Application

### Q15. What is currying and partial application? How do you implement them?

**Answer:**
Currying transforms a function that takes multiple arguments into a sequence of functions each taking one argument: `f(a, b, c)` becomes `f(a)(b)(c)`. Partial application fixes some arguments of a function and returns a new function expecting the remaining ones. Currying enables function composition and reuse. `Function.prototype.bind()` performs partial application natively.

❌ **Violates — duplicating logic for different configurations:**
```javascript
// Repeating logic with different values ❌
function addTax5(price) { return price * 1.05; }
function addTax10(price) { return price * 1.10; }
function addTax20(price) { return price * 1.20; }
// Repeated code for each tax rate ❌
```

✅ **Satisfies — currying and partial application:**
```javascript
// Manual currying
const addTax = (rate) => (price) => price * (1 + rate);
const addTax5  = addTax(0.05);
const addTax10 = addTax(0.10);
const addTax20 = addTax(0.20);
console.log(addTax5(100)); // 105 ✅

// Generic curry function
function curry(fn) {
  return function curried(...args) {
    if (args.length >= fn.length) {
      return fn(...args);
    }
    return function(...moreArgs) {
      return curried(...args, ...moreArgs);
    };
  };
}

const add = curry((a, b, c) => a + b + c);
console.log(add(1)(2)(3)); // 6
console.log(add(1, 2)(3)); // 6
console.log(add(1)(2, 3)); // 6 ✅

// Partial application with bind
function multiply(a, b) { return a * b; }
const double = multiply.bind(null, 2); // partial: a=2 fixed
console.log(double(5)); // 10 ✅

// Partial with arrow
const partial = (fn, ...preArgs) => (...laterArgs) => fn(...preArgs, ...laterArgs);
const triple = partial(multiply, 3);
console.log(triple(7)); // 21 ✅
```

---

## 2.6 Memoization

### Q16. What is memoization? Implement it and explain cache invalidation considerations.

**Answer:**
Memoization is an optimization technique that caches the return value of a function for given arguments, so repeated calls with the same arguments return the cached result instead of recomputing. It is effective for pure functions with expensive computations. The cache key is derived from the arguments — for complex objects, serialization (e.g., `JSON.stringify`) is needed. Cache invalidation is not automatic; stale data is a risk for time-sensitive or mutable-input functions.

❌ **Violates — expensive recomputation on every call:**
```javascript
// Fibonacci without memoization — exponential time ❌
function fib(n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2); // recomputes same values many times ❌
}
fib(40); // very slow ❌
```

✅ **Satisfies — memoization implementation:**
```javascript
// Simple memoize function
function memoize(fn) {
  const cache = new Map();
  return function(...args) {
    const key = JSON.stringify(args);
    if (cache.has(key)) {
      return cache.get(key); // cache hit ✅
    }
    const result = fn.apply(this, args);
    cache.set(key, result);
    return result;
  };
}

// Memoized fibonacci — O(n) time
const fib = memoize(function(n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2);
});
console.log(fib(50)); // instant ✅

// With TTL (time-to-live) for cache invalidation
function memoizeWithTTL(fn, ttlMs) {
  const cache = new Map();
  return function(...args) {
    const key = JSON.stringify(args);
    const entry = cache.get(key);
    if (entry && Date.now() - entry.time < ttlMs) {
      return entry.value;
    }
    const result = fn.apply(this, args);
    cache.set(key, { value: result, time: Date.now() });
    return result;
  };
}

const fetchUser = memoizeWithTTL(async (id) => {
  const res = await fetch(`/api/users/${id}`);
  return res.json();
}, 60000); // cache for 60 seconds ✅
```

---

## 2.7 arguments Object vs Rest Parameters

### Q17. What is the arguments object and why are rest parameters preferred?

**Answer:**
The `arguments` object is an array-like object available in regular functions containing all passed arguments. It is NOT a real array — it lacks array methods like `map`, `filter`, and `reduce`. Arrow functions do not have `arguments`. Rest parameters (`...args`) collect remaining arguments into a real array, work in arrow functions, are more explicit, and integrate naturally with destructuring.

❌ **Violates — using arguments object:**
```javascript
function sum() {
  // arguments is not a real array ❌
  return arguments.reduce((a, b) => a + b); // TypeError! ❌

  // Workaround needed ❌
  return Array.from(arguments).reduce((a, b) => a + b, 0);
}

// Doesn't work in arrow functions ❌
const sum2 = () => Array.from(arguments); // ReferenceError in strict mode ❌
```

✅ **Satisfies — rest parameters:**
```javascript
// Rest params — real array, works everywhere
function sum(...nums) {
  return nums.reduce((a, b) => a + b, 0); // nums is a real Array ✅
}
console.log(sum(1, 2, 3, 4, 5)); // 15

// Works in arrow functions
const multiply = (...factors) => factors.reduce((a, b) => a * b, 1);

// Combining fixed params with rest
function log(level, ...messages) {
  console[level](...messages);
}
log('warn', 'Something', 'went', 'wrong'); // console.warn('Something', 'went', 'wrong') ✅

// Rest with destructuring
function first([head, ...tail]) {
  return { head, tail };
}
console.log(first([1, 2, 3])); // { head: 1, tail: [2, 3] } ✅
```

---

## 2.8 Default Parameter Values

### Q18. How do default parameters work? What are evaluation timing rules and null vs undefined behavior?

**Answer:**
Default parameter values are evaluated at call time (not definition time), so using expressions or function calls as defaults is safe and creates fresh values each call. Defaults only trigger when the argument is `undefined` — passing `null` does NOT trigger the default. Parameters can reference earlier parameters in their default expressions. Mutable default values (like arrays or objects) are safe because they are re-evaluated per call.

❌ **Violates — old-style defaults with || and shared mutable defaults (common in other languages):**
```javascript
// || doesn't distinguish undefined from other falsy ❌
function greet(name) {
  name = name || 'Guest'; // fails if name is '' (empty string is valid but falsy) ❌
}

// null doesn't trigger default — common gotcha ❌
function connect(url = 'localhost') {
  console.log(url);
}
connect(null); // logs null, NOT 'localhost' ❌
```

✅ **Satisfies — proper default parameter usage:**
```javascript
// Default params — only undefined triggers default
function greet(name = 'Guest') {
  return `Hello, ${name}`;
}
greet();           // 'Hello, Guest' ✅
greet(undefined);  // 'Hello, Guest' ✅
greet(null);       // 'Hello, null' — null doesn't trigger default ✅
greet('');         // 'Hello, ' — empty string doesn't trigger default ✅

// Expression as default — evaluated each call
function createList(items = []) { // safe! new array each call ✅
  return items;
}

// Using earlier param in default
function range(start, end = start + 10) {
  return { start, end };
}
range(5); // { start: 5, end: 15 } ✅

// Computed default
function fetchData(url, timeout = getDefaultTimeout()) {
  // getDefaultTimeout() only called if timeout is undefined ✅
}

// Handle null explicitly if needed
function connect(url = null) {
  const target = url ?? 'localhost'; // null triggers ??, not default param
  console.log(target);
}
```

---

## 2.9 Named Function Expressions

### Q19. What are named function expressions and why are they useful for recursion and debugging?

**Answer:**
A named function expression is a function expression with an identifier after the `function` keyword. The name is only accessible inside the function itself (for self-reference/recursion) and shows up in stack traces — making debugging much easier than anonymous functions. Unlike function declarations, the name does not leak to the outer scope.

❌ **Violates — anonymous functions are hard to debug and can't self-reference:**
```javascript
// Anonymous — shows as <anonymous> in stack traces ❌
const factorial = function(n) {
  if (n <= 1) return 1;
  return n * factorial(n - 1); // relies on outer variable — breaks if reassigned ❌
};

const backup = factorial;
factorial = null; // reassign outer variable
backup(5); // TypeError: factorial is not a function ❌
```

✅ **Satisfies — named function expressions:**
```javascript
// Named — self-reference is safe, name shows in stack traces
const factorial = function fact(n) {
  if (n <= 1) return 1;
  return n * fact(n - 1); // 'fact' is the internal name — always safe ✅
};

const backup = factorial;
// factorial = null; // even if this happened:
// backup(5) would still work because 'fact' is internal ✅

console.log(factorial.name); // 'fact' ✅

// Named arrow — ES6 infers name from variable
const double = x => x * 2;
console.log(double.name); // 'double' — inferred ✅

// Useful in callbacks for stack traces
[1,2,3].map(function double(x) { return x * 2; });
// Stack trace shows 'double', not '<anonymous>' ✅
```

---

## 2.10 Function Composition

### Q20. What is function composition? Implement compose and pipe.

**Answer:**
Function composition combines multiple functions so the output of one becomes the input of the next. `compose` applies functions right-to-left (mathematical convention); `pipe` applies left-to-right (more intuitive for most developers). Both return a new function. Composition encourages building complex behavior from simple, single-purpose functions — a core functional programming principle.

❌ **Violates — nested function calls are hard to read:**
```javascript
// Nested calls — right-to-left reading, confusing ❌
const result = trim(toUpperCase(removeSpaces(addExclamation(input))));
// Hard to read and maintain ❌
```

✅ **Satisfies — compose and pipe implementations:**
```javascript
// compose: right-to-left
const compose = (...fns) => x => fns.reduceRight((acc, fn) => fn(acc), x);

// pipe: left-to-right (more readable)
const pipe = (...fns) => x => fns.reduce((acc, fn) => fn(acc), x);

// Simple transformations
const trim = str => str.trim();
const toLower = str => str.toLowerCase();
const addGreeting = str => `Hello, ${str}!`;
const capitalize = str => str.charAt(0).toUpperCase() + str.slice(1);

// pipe reads naturally left to right
const formatName = pipe(trim, toLower, capitalize, addGreeting);
console.log(formatName('  alice  ')); // 'Hello, Alice!' ✅

// compose: same functions, applied right-to-left
const formatName2 = compose(addGreeting, capitalize, toLower, trim);
console.log(formatName2('  alice  ')); // 'Hello, Alice!' ✅

// Async pipe
const pipeAsync = (...fns) => x => fns.reduce(
  (promise, fn) => promise.then(fn),
  Promise.resolve(x)
);

const processUser = pipeAsync(
  fetchUser,
  validateUser,
  formatUser
);
```

---

# 3. `this` Keyword & Context

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/this
> 📚 Medium: https://medium.com/better-programming/understanding-the-this-keyword-in-javascript-cb76d4c7c5e8

---

## 3.1 How `this` is Determined

### Q21. What are the 4 rules for determining `this` and their priority order?

**Answer:**
`this` is determined at call time, not definition time (except for arrow functions). The four binding rules in priority order are: 1) **new binding** — `new Fn()` sets `this` to the new object; 2) **explicit binding** — `call`, `apply`, or `bind` override `this`; 3) **implicit binding** — when called as `obj.method()`, `this` is `obj`; 4) **default binding** — standalone function call sets `this` to `globalThis` (or `undefined` in strict mode).

❌ **Violates — losing implicit binding:**
```javascript
const obj = {
  name: 'Alice',
  greet() { return `Hi, ${this.name}`; }
};

const greet = obj.greet; // detached from obj ❌
greet(); // 'Hi, undefined' — default binding, this is global ❌

setTimeout(obj.greet, 100); // also loses this ❌
```

✅ **Satisfies — understanding all 4 binding rules:**
```javascript
// 1. Default binding
function showThis() { console.log(this); }
showThis(); // globalThis (or undefined in strict mode)

// 2. Implicit binding
const obj = { name: 'Alice', greet() { return `Hi, ${this.name}`; } };
obj.greet(); // 'Hi, Alice' — this is obj ✅

// 3. Explicit binding
function greet() { return `Hi, ${this.name}`; }
greet.call({ name: 'Bob' });  // 'Hi, Bob'
greet.apply({ name: 'Carol' }); // 'Hi, Carol'
const boundGreet = greet.bind({ name: 'Dave' });
boundGreet(); // 'Hi, Dave' ✅

// 4. new binding
function Person(name) {
  this.name = name; // this = new empty object ✅
}
const p = new Person('Eve');
console.log(p.name); // 'Eve'

// Priority: new > explicit > implicit > default
function test() { console.log(this.name); }
const bound = test.bind({ name: 'Bound' });
bound.call({ name: 'Call' }); // 'Bound' — bind wins over call ✅
new bound(); // new wins over bind ✅
```

---

## 3.2 `this` in Arrow Functions

### Q22. How does `this` work in arrow functions? When should you use arrows vs regular functions?

**Answer:**
Arrow functions do not have their own `this` — they capture `this` lexically from the enclosing scope at the time they are defined. This means `this` in an arrow function is always the `this` of the surrounding code. Use arrow functions for callbacks, event handlers in class methods, and anywhere you want to preserve the outer `this`. Use regular functions for object methods, constructors, and any function that needs its own `this`.

❌ **Violates — wrong function type for the context:**
```javascript
// Arrow as object method — this is wrong ❌
const timer = {
  seconds: 0,
  start: () => {
    setInterval(() => this.seconds++, 1000); // this is outer scope, not timer ❌
  }
};

// Regular function in callback loses class this ❌
class Counter {
  constructor() { this.count = 0; }
  start() {
    setInterval(function() {
      this.count++; // this is global/undefined in strict mode ❌
    }, 1000);
  }
}
```

✅ **Satisfies — correct function type selection:**
```javascript
// Arrow in class method — preserves class instance as this
class Counter {
  constructor() { this.count = 0; }

  start() {
    // Arrow callback captures 'this' from start() method scope
    setInterval(() => {
      this.count++; // 'this' is the Counter instance ✅
      console.log(this.count);
    }, 1000);
  }
}

// Regular function for object methods
const obj = {
  value: 42,
  getValue() { return this.value; } // 'this' is obj ✅
};

// Arrow for callbacks
const numbers = [1, 2, 3];
const doubled = numbers.map(n => n * 2); // no 'this' needed ✅

// Nested arrow inherits outer this
class Fetcher {
  constructor(url) { this.url = url; }
  fetch() {
    return fetch(this.url).then(res => {
      console.log(this.url, 'responded'); // 'this' is Fetcher ✅
      return res.json();
    });
  }
}
```

---

## 3.3 call(), apply(), bind()

### Q23. What are the differences between call(), apply(), and bind()? When would you use each?

**Answer:**
All three explicitly set `this`. `call(thisArg, arg1, arg2, ...)` calls the function immediately with `this` set and args passed individually. `apply(thisArg, [argsArray])` calls immediately with args as an array. `bind(thisArg, ...args)` returns a new function with `this` permanently bound — it does not call immediately. Use `call`/`apply` for one-time invocation; use `bind` when you need to pass the function around with a fixed `this`.

❌ **Violates — calling borrowed methods incorrectly:**
```javascript
// apply with wrong argument format ❌
Math.max.apply(null, 1, 2, 3); // TypeError — second arg must be array ❌

// bind called immediately ❌
const fn = obj.method.bind(obj)(); // returns result, not bound fn ❌ (confusing)

// Not using bind when passing methods as callbacks ❌
class Button {
  constructor() { this.label = 'Click me'; }
  handleClick() { console.log(this.label); }
  render() {
    document.addEventListener('click', this.handleClick); // loses 'this' ❌
  }
}
```

✅ **Satisfies — call, apply, bind each in their right place:**
```javascript
function introduce(greeting, punctuation) {
  return `${greeting}, I'm ${this.name}${punctuation}`;
}
const user = { name: 'Alice' };

// call — immediate, args spread
introduce.call(user, 'Hello', '!'); // "Hello, I'm Alice!" ✅

// apply — immediate, args as array (great for spreading)
introduce.apply(user, ['Hi', '.']); // "Hi, I'm Alice." ✅

// apply classic use: Math.max with array
const nums = [3, 1, 4, 1, 5, 9];
Math.max.apply(null, nums); // 9 ✅ (use Math.max(...nums) in modern code)

// bind — returns new function
const aliceIntro = introduce.bind(user, 'Hey'); // 'Hey' pre-filled
aliceIntro('?'); // "Hey, I'm Alice?" ✅

// bind in class
class Button {
  constructor() {
    this.label = 'Click me';
    this.handleClick = this.handleClick.bind(this); // bound ✅
  }
  handleClick() { console.log(this.label); }
  render() {
    document.addEventListener('click', this.handleClick); // 'this' is correct ✅
  }
}
```

---

## 3.4 Losing `this`

### Q24. What are common ways `this` is lost and how do you fix them?

**Answer:**
`this` is lost when a method is detached from its object — stored in a variable, passed as a callback, or passed to event handlers. The method then gets called with default binding. Solutions include: binding with `.bind()`, using arrow functions, or wrapping in an arrow callback. Class field arrow functions are the most modern solution for class methods.

❌ **Violates — detaching methods loses this:**
```javascript
const user = {
  name: 'Alice',
  greet() { console.log(`Hi, ${this.name}`); }
};

const fn = user.greet;
fn(); // 'Hi, undefined' — this is global ❌

[1, 2, 3].forEach(user.greet); // 'Hi, undefined' for each ❌

setTimeout(user.greet, 100); // 'Hi, undefined' ❌
```

✅ **Satisfies — preserving this correctly:**
```javascript
const user = {
  name: 'Alice',
  greet() { console.log(`Hi, ${this.name}`); }
};

// Fix 1: bind
const fn = user.greet.bind(user);
fn(); // 'Hi, Alice' ✅

// Fix 2: arrow wrapper
setTimeout(() => user.greet(), 100); // 'Hi, Alice' ✅

// Fix 3: class field arrow (modern)
class User {
  name = 'Alice';
  greet = () => console.log(`Hi, ${this.name}`); // always bound ✅
}
const u = new User();
const { greet } = u;
greet(); // 'Hi, Alice' — this is always the instance ✅

// Fix 4: explicit callback wrapper
[1, 2, 3].forEach(() => user.greet()); // ✅
```

---

## 3.5 `this` in Classes

### Q25. How does `this` work in classes and what are class field arrow functions?

**Answer:**
In a class method, `this` refers to the instance when the method is called normally. However, when a method is passed as a callback, `this` is lost. Class field arrow functions solve this by defining the method as an arrow function property on each instance — `this` is permanently bound to the instance at construction time. The trade-off is that class field arrows are own properties (on each instance), not on the prototype.

❌ **Violates — unbound class methods fail as callbacks:**
```javascript
class Counter {
  count = 0;
  increment() { this.count++; } // prototype method
}

const c = new Counter();
const inc = c.increment;
inc(); // TypeError or NaN — 'this' is not c ❌

// React-style: forgetting to bind in constructor ❌
class Button extends Component {
  handleClick() { this.setState({ clicked: true }); }
  render() {
    return <button onClick={this.handleClick}>Click</button>; // 'this' lost ❌
  }
}
```

✅ **Satisfies — class field arrows and proper binding:**
```javascript
class Counter {
  count = 0;

  // Class field arrow — bound to instance, not on prototype
  increment = () => {
    this.count++; // 'this' is always the Counter instance ✅
  };

  // Static method — 'this' is the class itself
  static create() {
    return new this();
  }
}

const c = new Counter();
const inc = c.increment; // detach
inc(); // still works! this.count++ ✅

// Verify: increment is own property, not prototype
console.log(c.hasOwnProperty('increment')); // true
console.log(Counter.prototype.hasOwnProperty('increment')); // false

// Prototype methods are shared (memory efficient)
class CounterProto {
  count = 0;
  increment() { this.count++; } // on prototype — one copy shared ✅
}
// Must be called as method: c.increment() ✅
```

---

## 3.6 `this` in Event Listeners

### Q26. What does `this` refer to in event listeners? How does an arrow function handler differ?

**Answer:**
In a regular function event handler, `this` refers to the element that the event listener is attached to — identical to `event.currentTarget`. In an arrow function handler, `this` is NOT the element — it is the lexical `this` from where the arrow was defined. Use `event.currentTarget` for reliable element access regardless of function type.

❌ **Violates — arrow function handler when you need the element as this:**
```javascript
class Toggle {
  constructor(button) {
    // Arrow — 'this' is Toggle instance, NOT the button ❌
    button.addEventListener('click', () => {
      this.classList.toggle('active'); // 'this' is Toggle, not button ❌
    });
  }
}

// Using 'this' in arrow and expecting element
document.querySelectorAll('.btn').forEach(btn => {
  btn.addEventListener('click', () => {
    console.log(this); // not the button — outer this ❌
  });
});
```

✅ **Satisfies — understanding this in event listeners:**
```javascript
// Regular function — this is the element
document.querySelector('#btn').addEventListener('click', function(event) {
  console.log(this === event.currentTarget); // true ✅
  this.classList.toggle('active'); // 'this' is the button element ✅
});

// Arrow function — use event.currentTarget for reliability
document.querySelectorAll('.btn').forEach(btn => {
  btn.addEventListener('click', (event) => {
    event.currentTarget.classList.toggle('active'); // reliable ✅
    // 'this' here is whatever the outer scope's this is
  });
});

// Class with both concerns
class Toggle {
  constructor(button) {
    this.button = button;
    this.active = false;
    // Arrow preserves class 'this', use event.currentTarget for element
    button.addEventListener('click', (event) => {
      this.active = !this.active; // 'this' is Toggle instance ✅
      event.currentTarget.classList.toggle('active'); // element ✅
    });
  }
}
```

---

## 3.7 `new` Binding

### Q27. What does the `new` keyword do step by step? How does it set up `this`?

**Answer:**
When `new` is used with a constructor function, JavaScript performs 4 steps: 1) Creates a new empty object; 2) Sets that object's prototype to the constructor's `prototype` property; 3) Calls the constructor with `this` bound to the new object; 4) Returns the new object (unless the constructor explicitly returns a different object). If the constructor returns a primitive, it is ignored and the new object is returned.

❌ **Violates — forgetting new causes this to be global:**
```javascript
function Person(name) {
  this.name = name;
  this.greet = function() { return `Hi, I'm ${this.name}`; };
}

// Forgetting new — 'this' is global! ❌
const p = Person('Alice');
console.log(p); // undefined — function returns nothing ❌
console.log(window.name); // 'Alice' — polluted global! ❌
```

✅ **Satisfies — understanding new and constructor pattern:**
```javascript
function Person(name, age) {
  // At this point: this = {} (new empty object)
  this.name = name;
  this.age = age;
  // Implicitly returns 'this' ✅
}

// Add to prototype (shared across all instances)
Person.prototype.greet = function() {
  return `Hi, I'm ${this.name}`;
};

const p1 = new Person('Alice', 30);
const p2 = new Person('Bob', 25);

console.log(p1.greet()); // "Hi, I'm Alice" ✅
console.log(p1.greet === p2.greet); // true — shared prototype method ✅

// Guard against missing new
function SafePerson(name) {
  if (!(this instanceof SafePerson)) {
    return new SafePerson(name); // auto-fix ✅
  }
  this.name = name;
}

// What new does manually:
function manualNew(Constructor, ...args) {
  const obj = Object.create(Constructor.prototype); // step 1 & 2
  const result = Constructor.apply(obj, args);      // step 3
  return result instanceof Object ? result : obj;   // step 4
}
```

---

## 3.8 globalThis

### Q28. What is globalThis? How does strict mode affect default this binding?

**Answer:**
`globalThis` is the standard way to access the global object across environments: `window` in browsers, `global` in Node.js, `self` in Web Workers. Before `globalThis`, code needed environment checks. In non-strict mode, default binding sets `this` to `globalThis`. In strict mode (`'use strict'`), default binding sets `this` to `undefined` — preventing accidental global property creation.

❌ **Violates — environment-specific global access:**
```javascript
// Brittle environment detection ❌
const globalObj = typeof window !== 'undefined' ? window
                : typeof global !== 'undefined' ? global
                : typeof self !== 'undefined' ? self
                : this; // inconsistent ❌

// Non-strict: accidentally creates global ❌
function setName() {
  this.name = 'Alice'; // this is globalThis — creates global property! ❌
}
setName();
console.log(globalThis.name); // 'Alice' — polluted global ❌
```

✅ **Satisfies — globalThis and strict mode:**
```javascript
// globalThis — works everywhere ✅
console.log(globalThis); // window in browser, global in Node ✅

// Store cross-environment global config
globalThis.__APP_CONFIG__ = { version: '1.0.0' };

// Strict mode prevents accidental globals
'use strict';
function test() {
  console.log(this); // undefined — not globalThis ✅
}
test();

// Strict mode default binding
function strictFn() {
  'use strict';
  return this; // undefined ✅
}

// How to check environment
const isBrowser = typeof window !== 'undefined' && globalThis === window;
const isNode = typeof process !== 'undefined' && process.versions?.node;

// Safe global access pattern
function getGlobal() {
  return globalThis; // always correct ✅
}
```

---

## 3.9 Method Chaining

### Q29. How does returning `this` enable method chaining? Implement a fluent API.

**Answer:**
Method chaining allows calling multiple methods on the same object in sequence: `obj.method1().method2().method3()`. This works when each method returns `this` — the instance itself. It creates a fluent interface that is readable and expressive. jQuery popularized this pattern; it is also used in builder patterns, query builders, and test assertion libraries.

❌ **Violates — methods that return undefined force separate statements:**
```javascript
class QueryBuilder {
  constructor() { this.query = ''; }

  select(fields) {
    this.query += `SELECT ${fields} `;
    // No return — next call fails ❌
  }
  from(table) {
    this.query += `FROM ${table} `;
  }
}

const qb = new QueryBuilder();
qb.select('*'); // can't chain ❌
qb.from('users');
// No chaining possible, verbose ❌
```

✅ **Satisfies — fluent API with method chaining:**
```javascript
class QueryBuilder {
  constructor() {
    this._select = '*';
    this._from = '';
    this._where = [];
    this._limit = null;
  }

  select(fields) {
    this._select = fields;
    return this; // enables chaining ✅
  }

  from(table) {
    this._from = table;
    return this;
  }

  where(condition) {
    this._where.push(condition);
    return this;
  }

  limit(n) {
    this._limit = n;
    return this;
  }

  build() {
    let q = `SELECT ${this._select} FROM ${this._from}`;
    if (this._where.length) q += ` WHERE ${this._where.join(' AND ')}`;
    if (this._limit) q += ` LIMIT ${this._limit}`;
    return q;
  }
}

const query = new QueryBuilder()
  .select('name, email')
  .from('users')
  .where('age > 18')
  .where('active = 1')
  .limit(10)
  .build();

console.log(query);
// SELECT name, email FROM users WHERE age > 18 AND active = 1 LIMIT 10 ✅
```

---

## 3.10 `this` Edge Cases

### Q30. What are common `this` edge cases with setTimeout, array methods, and strict mode?

**Answer:**
`this` behaves unexpectedly in several edge cases. `setTimeout` callbacks are called with `this` as `globalThis` (or `undefined` in strict). Array methods like `forEach`, `map`, and `filter` accept a second argument as the `this` context, which is rarely used but good to know. Methods called through computed property access can lose `this`. Strict mode changes the default binding from `globalThis` to `undefined`.

❌ **Violates — assuming this is preserved in async contexts:**
```javascript
const obj = {
  data: [1, 2, 3],
  name: 'obj',
  process() {
    // Regular function callback — 'this' is lost ❌
    return this.data.map(function(x) {
      return `${this.name}: ${x}`; // this.name is undefined ❌
    });
  }
};

// setTimeout loses this ❌
const timer = {
  id: 42,
  start() {
    setTimeout(function() {
      console.log(this.id); // undefined ❌
    }, 100);
  }
};
```

✅ **Satisfies — all edge cases handled:**
```javascript
const obj = {
  data: [1, 2, 3],
  name: 'obj',

  process() {
    // Arrow callback inherits this from process() ✅
    return this.data.map(x => `${this.name}: ${x}`);

    // Alternative: thisArg as second argument to map ✅
    return this.data.map(function(x) {
      return `${this.name}: ${x}`;
    }, this); // second arg sets 'this' inside callback ✅
  },

  start() {
    // Arrow for setTimeout ✅
    setTimeout(() => console.log(this.id), 100); // 42 ✅
  }
};

// Strict mode default binding
function strict() {
  'use strict';
  return this; // undefined, not globalThis ✅
}

// Computed property access — this is set by how method is called
const method = obj.process;
method(); // loses this ❌ — must do obj.process() ✅

// IIFE loses this
const result = (function() { return this; })();
// globalThis in sloppy mode, undefined in strict
```


---

# 4. Prototypes & Inheritance

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Inheritance_and_the_prototype_chain
> 📚 Medium: https://medium.com/javascript-scene/master-the-javascript-interview-what-s-the-difference-between-class-prototypal-inheritance-e4cd0a7562e9

---

## 4.1 Prototype Chain

### Q31. What is the prototype chain? What is the difference between __proto__ and prototype?

**Answer:**
Every JavaScript object has an internal `[[Prototype]]` link pointing to another object (its prototype). When a property is not found on an object, JavaScript walks up the chain until it finds it or reaches `null` (end of chain). `prototype` is a property of constructor functions — it is the object that becomes the `[[Prototype]]` of instances created with `new`. `__proto__` is a non-standard (but widely supported) getter/setter for `[[Prototype]]`. Use `Object.getPrototypeOf(obj)` instead.

❌ **Violates — using __proto__ directly and not understanding chain:**
```javascript
// __proto__ is deprecated for direct use ❌
const obj = {};
obj.__proto__ = { greet() { return 'hi'; } }; // works but avoid ❌

// Mutating prototype after construction ❌
function Animal(name) { this.name = name; }
const cat = new Animal('Cat');
Animal.prototype.sound = 'meow'; // this actually works but is confusing ❌

// Infinite prototype loop (theoretical) ❌
// a.__proto__ = b; b.__proto__ = a; // TypeError in JS ❌
```

✅ **Satisfies — prototype chain correctly used:**
```javascript
function Animal(name) {
  this.name = name;
}
Animal.prototype.speak = function() {
  return `${this.name} makes a sound`;
};

const dog = new Animal('Dog');

// Correct prototype inspection
console.log(Object.getPrototypeOf(dog) === Animal.prototype); // true ✅
console.log(dog.speak()); // 'Dog makes a sound' — found on prototype ✅

// Chain: dog -> Animal.prototype -> Object.prototype -> null
console.log(Object.getPrototypeOf(Animal.prototype) === Object.prototype); // true
console.log(Object.getPrototypeOf(Object.prototype)); // null — end of chain ✅

// Property lookup order
dog.speak;     // not on dog → found on Animal.prototype ✅
dog.toString;  // not on dog or Animal.prototype → found on Object.prototype ✅
dog.missing;   // not anywhere → undefined ✅
```

---

## 4.2 Constructor Functions and Prototypal Inheritance

### Q32. How do you set up inheritance manually using constructor functions and prototypes?

**Answer:**
Before ES6 classes, prototypal inheritance was set up by assigning the child constructor's `prototype` to an object that inherits from the parent's prototype using `Object.create`. You must also fix the `constructor` property. The child's constructor must call the parent constructor with `call` to initialize inherited properties on the instance.

❌ **Violates — naive prototype assignment breaks inheritance:**
```javascript
function Animal(name) { this.name = name; }
Animal.prototype.speak = function() { return `${this.name} speaks`; };

function Dog(name, breed) { this.breed = breed; } // forgot to call Animal ❌

// Direct assignment — replaces prototype entirely ❌
Dog.prototype = Animal.prototype; // shared reference — mutations affect Animal! ❌
```

✅ **Satisfies — correct prototypal inheritance:**
```javascript
function Animal(name) {
  this.name = name;
}
Animal.prototype.speak = function() {
  return `${this.name} makes a sound`;
};

function Dog(name, breed) {
  Animal.call(this, name); // call parent constructor ✅
  this.breed = breed;
}

// Create prototype chain without calling Animal constructor
Dog.prototype = Object.create(Animal.prototype); // ✅
Dog.prototype.constructor = Dog; // fix constructor reference ✅

Dog.prototype.bark = function() {
  return `${this.name} barks!`;
};

const rex = new Dog('Rex', 'Labrador');
console.log(rex.speak()); // 'Rex makes a sound' — inherited ✅
console.log(rex.bark());  // 'Rex barks!' — own method ✅
console.log(rex instanceof Dog);    // true ✅
console.log(rex instanceof Animal); // true ✅
console.log(rex.constructor === Dog); // true ✅
```

---

## 4.3 Object.create()

### Q33. What does Object.create() do? What are null prototype objects?

**Answer:**
`Object.create(proto)` creates a new object whose `[[Prototype]]` is set to `proto`. Passing `null` creates an object with no prototype at all — it doesn't inherit `toString`, `hasOwnProperty`, or any Object methods. This is useful for pure hash maps where you don't want prototype pollution. `Object.create` also accepts a second argument: a property descriptor map.

❌ **Violates — prototype pollution risk with plain objects as maps:**
```javascript
// Plain object as map — vulnerable to prototype keys ❌
const map = {};
map['constructor'] = 'hacked'; // overwrites inherited constructor ❌
map['toString'] = 'hacked';    // overwrites inherited method ❌

// Checking for key 'hasOwnProperty' fails ❌
if (map['hasOwnProperty']) {
  // This is truthy even for a fresh object because of prototype! ❌
}
```

✅ **Satisfies — Object.create for prototype control:**
```javascript
// Inherit from specific object
const animal = {
  speak() { return `${this.name} speaks`; }
};
const dog = Object.create(animal);
dog.name = 'Rex';
console.log(dog.speak()); // 'Rex speaks' — inherited from animal ✅

// Null prototype — safe hash map
const safeMap = Object.create(null);
safeMap['key'] = 'value';
safeMap['constructor'] = 'safe'; // just a regular key, no collision ✅
console.log(Object.getPrototypeOf(safeMap)); // null ✅

// Object.create with property descriptors
const obj = Object.create({}, {
  name: {
    value: 'Alice',
    writable: true,
    enumerable: true,
    configurable: true
  }
});
console.log(obj.name); // 'Alice' ✅

// Pure prototype setup
function create(proto, props) {
  const obj = Object.create(proto);
  return Object.assign(obj, props);
}
const myDog = create(animal, { name: 'Buddy', breed: 'Poodle' });
console.log(myDog.speak()); // 'Buddy speaks' ✅
```

---

## 4.4 Class Syntax

### Q34. How is class syntax syntactic sugar over prototypes? What actually happens under the hood?

**Answer:**
ES6 `class` syntax does not introduce a new object model — it is syntactic sugar over constructor functions and prototype chains. The class body defines methods on the prototype. The `constructor` method IS the constructor function. Class methods are non-enumerable (unlike manually added prototype methods). Classes are not hoisted (unlike function declarations) and are always in strict mode.

❌ **Violates — thinking classes are fundamentally different from prototypes:**
```javascript
class Point {
  constructor(x, y) {
    this.x = x;
    this.y = y;
  }
  toString() { return `(${this.x}, ${this.y})`; }
}

// Mistake: thinking class creates a new type system
typeof Point; // 'function' — it IS a function! ❌ (surprise for some)

// Class is not hoisted ❌
const p = new MyClass(); // ReferenceError ❌
class MyClass {}
```

✅ **Satisfies — understanding class as syntactic sugar:**
```javascript
class Animal {
  // Class fields (ES2022) — own properties on each instance
  type = 'animal';

  constructor(name) {
    this.name = name;
  }

  // Prototype method — non-enumerable ✅
  speak() {
    return `${this.name} speaks`;
  }

  // Static — on the class itself, not prototype
  static create(name) {
    return new this(name);
  }

  // Getter/setter
  get info() { return `${this.type}: ${this.name}`; }
  set info(val) { [this.type, this.name] = val.split(':'); }
}

// Under the hood, equivalent to:
function AnimalFn(name) { this.name = name; }
AnimalFn.prototype.speak = function() { return `${this.name} speaks`; };
Object.defineProperty(AnimalFn.prototype, 'speak', { enumerable: false }); // classes do this

// Verify class is prototype-based
const a = new Animal('Cat');
console.log(typeof Animal);                        // 'function' ✅
console.log(a.speak === Animal.prototype.speak);   // true ✅
console.log(Object.getPrototypeOf(a) === Animal.prototype); // true ✅
console.log(Object.keys(Animal.prototype));        // [] — methods not enumerable ✅
```

---

## 4.5 Class Inheritance (extends, super)

### Q35. How do extends and super work in ES6 class inheritance?

**Answer:**
`extends` sets up the prototype chain: the child class's `prototype` inherits from the parent's `prototype`, and the child constructor inherits from the parent constructor (for static methods). `super()` inside a child constructor calls the parent constructor — it is mandatory in derived class constructors before accessing `this`. `super.method()` calls a method on the parent prototype.

❌ **Violates — forgetting super() in constructor:**
```javascript
class Animal {
  constructor(name) { this.name = name; }
}

class Dog extends Animal {
  constructor(name, breed) {
    // Missing super() ❌
    this.breed = breed; // ReferenceError: Must call super before accessing 'this' ❌
  }
}
```

✅ **Satisfies — correct use of extends and super:**
```javascript
class Animal {
  constructor(name) {
    this.name = name;
  }

  speak() {
    return `${this.name} makes a sound`;
  }

  toString() {
    return `Animal(${this.name})`;
  }
}

class Dog extends Animal {
  constructor(name, breed) {
    super(name); // call parent constructor first ✅
    this.breed = breed;
  }

  speak() {
    const parentSpeech = super.speak(); // call parent method ✅
    return `${parentSpeech} — specifically a bark!`;
  }

  toString() {
    return `Dog(${this.name}, ${this.breed})`;
  }
}

const d = new Dog('Rex', 'Labrador');
console.log(d.speak()); // 'Rex makes a sound — specifically a bark!' ✅
console.log(d instanceof Dog);    // true ✅
console.log(d instanceof Animal); // true ✅

// Static inheritance
class MyArray extends Array {
  sum() { return this.reduce((a, b) => a + b, 0); }
}
const arr = new MyArray(1, 2, 3);
console.log(arr.sum()); // 6 ✅
console.log(arr.map(x => x * 2) instanceof MyArray); // true — map returns MyArray ✅
```

---

## 4.6 instanceof Operator

### Q36. How does instanceof work? What are its prototype chain traversal pitfalls?

**Answer:**
`instanceof` checks if `Constructor.prototype` appears anywhere in an object's prototype chain. It walks the chain repeatedly. It can fail when objects cross iframe/realm boundaries (different `Array` constructors). It can be customized using `Symbol.hasInstance`. `typeof` is better for primitives; `instanceof` is for objects.

❌ **Violates — instanceof with primitives and cross-realm pitfalls:**
```javascript
// instanceof doesn't work on primitives ❌
'hello' instanceof String; // false — primitive, not String object ❌
42 instanceof Number;       // false ❌

// Cross-realm (iframe) issue ❌
// const arr = iframe.contentWindow.Array.of(1,2,3);
// arr instanceof Array; // false — different Array constructor ❌

// Easy to fool ❌
function Foo() {}
const f = new Foo();
Object.setPrototypeOf(f, Array.prototype);
f instanceof Array; // true — but it's not really an array! ❌
```

✅ **Satisfies — instanceof used correctly:**
```javascript
class Animal {}
class Dog extends Animal {}
class Cat extends Animal {}

const dog = new Dog();
console.log(dog instanceof Dog);    // true ✅
console.log(dog instanceof Animal); // true — chain includes Animal.prototype ✅
console.log(dog instanceof Cat);    // false ✅

// Custom Symbol.hasInstance
class EvenNumber {
  static [Symbol.hasInstance](num) {
    return typeof num === 'number' && num % 2 === 0;
  }
}
console.log(2 instanceof EvenNumber); // true ✅
console.log(3 instanceof EvenNumber); // false ✅

// Better type checking for built-ins
const arr = [1, 2, 3];
Array.isArray(arr);                            // true — cross-realm safe ✅
Object.prototype.toString.call(arr) === '[object Array]'; // true — reliable ✅

// instanceof for custom classes is fine
function isAnimal(obj) {
  return obj instanceof Animal;
}
```

---

## 4.7 hasOwnProperty / Object.hasOwn()

### Q37. How do you distinguish own properties from inherited ones? What is Object.hasOwn()?

**Answer:**
`hasOwnProperty` checks if a property exists directly on an object (not inherited). `Object.hasOwn(obj, key)` is the modern replacement — it is safer because it works on objects with null prototype (which don't have `hasOwnProperty`) and avoids `hasOwnProperty` being overridden. Use `in` operator to check own AND inherited properties.

❌ **Violates — iterating with for...in without own property check:**
```javascript
// for...in iterates inherited properties too ❌
function Animal(name) { this.name = name; }
Animal.prototype.speak = function() {};

const dog = new Animal('Rex');
for (const key in dog) {
  console.log(key); // 'name' AND 'speak' (inherited!) ❌
}

// hasOwnProperty on null-prototype object ❌
const obj = Object.create(null);
obj.hasOwnProperty('key'); // TypeError: obj.hasOwnProperty is not a function ❌
```

✅ **Satisfies — correct own property checking:**
```javascript
function Animal(name) { this.name = name; }
Animal.prototype.speak = function() {};

const dog = new Animal('Rex');

// Filter to own properties only
for (const key in dog) {
  if (Object.hasOwn(dog, key)) { // modern, safe ✅
    console.log(key); // only 'name' ✅
  }
}

// Object.hasOwn — works on null-prototype objects
const safeMap = Object.create(null);
safeMap.key = 'value';
Object.hasOwn(safeMap, 'key'); // true ✅
// safeMap.hasOwnProperty('key'); // TypeError ❌

// 'in' checks own + inherited
console.log('name' in dog);   // true — own ✅
console.log('speak' in dog);  // true — inherited ✅
console.log('missing' in dog); // false ✅

// Object.keys — only own enumerable
console.log(Object.keys(dog)); // ['name'] — not 'speak' ✅

// Own + non-enumerable
Object.getOwnPropertyNames(dog); // all own props regardless of enumerable
```

---

## 4.8 Mixins

### Q38. What is a mixin pattern? How do you compose behaviors in JavaScript without multiple inheritance?

**Answer:**
JavaScript does not support multiple inheritance — a class can only extend one parent. Mixins are a pattern to copy methods from multiple source objects onto a class prototype, composing behaviors from multiple sources. The simplest approach uses `Object.assign`. More sophisticated mixins use factory functions that return classes extended from a given base.

❌ **Violates — trying to extend multiple classes (not supported):**
```javascript
class Flyable { fly() { return 'flying'; } }
class Swimmable { swim() { return 'swimming'; } }

// Cannot extend multiple classes ❌
class Duck extends Flyable, Swimmable {} // SyntaxError ❌
```

✅ **Satisfies — mixin patterns:**
```javascript
// Simple object mixin
const Flyable = {
  fly() { return `${this.name} is flying`; }
};

const Swimmable = {
  swim() { return `${this.name} is swimming`; }
};

class Duck {
  constructor(name) { this.name = name; }
}

// Copy methods onto prototype
Object.assign(Duck.prototype, Flyable, Swimmable);

const duck = new Duck('Donald');
console.log(duck.fly());  // 'Donald is flying' ✅
console.log(duck.swim()); // 'Donald is swimming' ✅

// Functional mixin (class factory — more powerful)
const withFly = (Base) => class extends Base {
  fly() { return `${this.name} is flying`; }
};

const withSwim = (Base) => class extends Base {
  swim() { return `${this.name} is swimming`; }
};

class Animal {
  constructor(name) { this.name = name; }
}

class Duck2 extends withFly(withSwim(Animal)) {
  quack() { return 'quack!'; }
}

const d = new Duck2('Daffy');
console.log(d.fly());   // 'Daffy is flying' ✅
console.log(d.swim());  // 'Daffy is swimming' ✅
console.log(d instanceof Animal); // true ✅
```

---

## 4.9 Property Descriptors

### Q39. What are property descriptors? How do Object.defineProperty, enumerable, writable, and configurable work?

**Answer:**
Each property on an object has a descriptor with attributes: `value`, `writable` (can value be changed), `enumerable` (shows in for...in and Object.keys), and `configurable` (can descriptor be changed or property deleted). `Object.defineProperty` sets these explicitly. `Object.freeze` makes all properties non-writable and non-configurable; `Object.seal` makes them non-configurable but still writable.

❌ **Violates — not understanding immutability limits:**
```javascript
const obj = { x: 1 };
Object.freeze(obj);

obj.x = 99;         // silently fails (or throws in strict mode) ❌
obj.y = 2;          // silently fails ❌
delete obj.x;       // silently fails ❌
console.log(obj.x); // still 1 — mutation had no effect ❌

// freeze is shallow ❌
const nested = { a: { b: 1 } };
Object.freeze(nested);
nested.a.b = 99; // works! freeze doesn't deep-freeze ❌
```

✅ **Satisfies — property descriptors and correct immutability:**
```javascript
const obj = {};

Object.defineProperty(obj, 'PI', {
  value: 3.14159,
  writable: false,     // cannot change value
  enumerable: true,    // shows in Object.keys
  configurable: false  // cannot delete or redefine
});

obj.PI = 99;           // silently fails (throws in strict mode)
console.log(obj.PI);   // 3.14159 ✅

// Non-enumerable property
Object.defineProperty(obj, '_secret', {
  value: 'hidden',
  enumerable: false,
  writable: true,
  configurable: true
});
console.log(Object.keys(obj));       // ['PI'] — _secret not listed ✅
console.log(obj._secret);            // 'hidden' — still accessible ✅

// Inspect descriptor
console.log(Object.getOwnPropertyDescriptor(obj, 'PI'));
// { value: 3.14159, writable: false, enumerable: true, configurable: false }

// Deep freeze utility
function deepFreeze(obj) {
  Object.getOwnPropertyNames(obj).forEach(name => {
    const value = obj[name];
    if (typeof value === 'object' && value !== null) {
      deepFreeze(value);
    }
  });
  return Object.freeze(obj);
}
```

---

## 4.10 Object.create vs Object.assign vs Spread

### Q40. What are the differences between Object.create, Object.assign, and spread in prototype handling?

**Answer:**
`Object.create(proto)` creates a new object with `proto` as its prototype — the prototype relationship is set up, not properties copied. `Object.assign(target, source)` copies own enumerable properties (no prototype link). Spread `{ ...source }` also copies own enumerable properties into a new plain object with `Object.prototype` as prototype. Neither `assign` nor spread copies the source's prototype chain.

❌ **Violates — expecting prototype methods to transfer with assign/spread:**
```javascript
class Animal {
  speak() { return 'sound'; }
}
const dog = new Animal();

// Spread creates plain object — loses prototype methods ❌
const copy = { ...dog };
copy.speak(); // TypeError: copy.speak is not a function ❌
// dog's methods are on Animal.prototype, not own properties ❌

// Object.assign same issue ❌
const copy2 = Object.assign({}, dog);
copy2.speak(); // TypeError ❌
```

✅ **Satisfies — understanding each approach:**
```javascript
class Animal {
  constructor(name) { this.name = name; }
  speak() { return `${this.name} speaks`; }
}
const dog = new Animal('Rex');

// Object.create — sets up prototype link
const dogCopy = Object.create(Object.getPrototypeOf(dog));
Object.assign(dogCopy, dog); // copy own properties
dogCopy.speak(); // 'Rex speaks' ✅ — prototype preserved

// Spread — plain object copy, own enumerable props only
const plain = { ...dog }; // { name: 'Rex' }
plain.speak; // undefined — prototype methods not copied ✅ (expected)

// Object.assign — same as spread for prototype handling
const assigned = Object.assign({}, dog); // { name: 'Rex' }

// When to use each:
// Object.create — set up prototype chain ✅
// Object.assign / spread — merge/copy plain data ✅
// Neither replaces clone for class instances — use structuredClone or copy constructor

// Summary
const proto = { greet() { return 'hi'; } };
const obj = Object.create(proto);
obj.name = 'Alice';
const spread = { ...obj }; // { name: 'Alice' } — proto.greet gone
Object.getPrototypeOf(spread) === Object.prototype; // true
Object.getPrototypeOf(obj) === proto; // true ✅
```

---

# 5. Async JavaScript

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Asynchronous
> 📚 Medium: https://medium.com/javascript-scene/master-the-javascript-interview-what-is-a-promise-27fc71e77261

---

## 5.1 Callbacks and Callback Hell

### Q41. What is callback hell and why is it a problem?

**Answer:**
Callback hell (also called the pyramid of doom) occurs when multiple asynchronous operations are nested inside each other's callbacks, creating deeply indented code that is hard to read, maintain, and debug. Error handling must be repeated at each level. Refactoring is difficult. Promises and async/await were introduced to solve this.

❌ **Violates — deeply nested callbacks:**
```javascript
// Pyramid of doom ❌
getUser(userId, function(err, user) {
  if (err) return handleError(err);
  getOrders(user.id, function(err, orders) {
    if (err) return handleError(err);
    getOrderDetails(orders[0].id, function(err, details) {
      if (err) return handleError(err);
      getProduct(details.productId, function(err, product) {
        if (err) return handleError(err);
        console.log(product); // finally got the data ❌ (4 levels deep)
      });
    });
  });
});
```

✅ **Satisfies — flat async/await:**
```javascript
// Flat, readable async/await ✅
async function getProductForUser(userId) {
  try {
    const user = await getUser(userId);
    const orders = await getOrders(user.id);
    const details = await getOrderDetails(orders[0].id);
    const product = await getProduct(details.productId);
    return product;
  } catch (err) {
    handleError(err); // single error handler ✅
  }
}

// Named callback approach (intermediate solution)
function handleProduct(err, product) {
  if (err) return handleError(err);
  console.log(product);
}
function handleDetails(err, details) {
  if (err) return handleError(err);
  getProduct(details.productId, handleProduct);
}
// Still verbose but at least not nested ✅
```

---

## 5.2 Promise Basics

### Q42. What are the three states of a Promise? How do .then(), .catch(), and .finally() work?

**Answer:**
A Promise has three states: **pending** (initial), **fulfilled** (resolved successfully), and **rejected** (failed). Once settled (fulfilled or rejected), a Promise cannot change state. `.then(onFulfilled, onRejected)` handles both states; `.catch(onRejected)` is shorthand for `.then(null, onRejected)`; `.finally(fn)` runs regardless of outcome and passes through the original value or error. All three return new Promises, enabling chaining.

❌ **Violates — incorrect error handling and not chaining:**
```javascript
// Swallowing errors ❌
fetch('/api/data')
  .then(res => res.json())
  .then(data => console.log(data));
  // No .catch — unhandled rejection if fetch fails ❌

// Nested .then instead of chaining ❌
fetch('/api/user')
  .then(res => {
    res.json().then(user => { // nested — breaks chaining ❌
      console.log(user);
    });
  });
```

✅ **Satisfies — proper Promise chaining and error handling:**
```javascript
// Creating a Promise
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Promise states
const p = new Promise((resolve, reject) => {
  setTimeout(() => resolve('success'), 1000);
});

// Chaining — each .then returns a new Promise ✅
fetch('/api/user')
  .then(res => {
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json(); // return value is passed to next .then ✅
  })
  .then(user => {
    console.log(user.name);
    return user;
  })
  .catch(err => {
    console.error('Failed:', err); // catches any error in chain ✅
    return null; // recover — chain continues with null
  })
  .finally(() => {
    hideSpinner(); // always runs ✅
  });

// Manual resolve/reject
function divide(a, b) {
  return new Promise((resolve, reject) => {
    if (b === 0) reject(new Error('Division by zero'));
    else resolve(a / b);
  });
}
```

---

## 5.3 Promise Combinators

### Q43. Explain Promise.all, Promise.allSettled, Promise.race, and Promise.any with their behaviors.

**Answer:**
`Promise.all` resolves when ALL promises resolve (fail-fast on first rejection). `Promise.allSettled` waits for ALL promises to settle (never rejects) and gives an array of `{status, value/reason}` objects. `Promise.race` resolves/rejects as soon as the FIRST promise settles. `Promise.any` resolves with the FIRST fulfilled promise (rejects only if ALL reject, with AggregateError).

❌ **Violates — using Promise.all when you need all results regardless of failures:**
```javascript
// Promise.all fails fast — one rejection aborts everything ❌
const results = await Promise.all([
  fetchUser(),    // succeeds
  fetchOrders(),  // FAILS — Promise.all rejects ❌
  fetchCart()     // result discarded even if it would have succeeded ❌
]);
// You lose the successful results ❌
```

✅ **Satisfies — choosing the right combinator:**
```javascript
const p1 = fetch('/api/user').then(r => r.json());
const p2 = fetch('/api/orders').then(r => r.json());
const p3 = fetch('/api/cart').then(r => r.json());

// Promise.all — parallel, fail-fast ✅ (use when all must succeed)
try {
  const [user, orders, cart] = await Promise.all([p1, p2, p3]);
} catch (err) {
  console.error('At least one failed:', err);
}

// Promise.allSettled — wait for all, never rejects ✅
const results = await Promise.allSettled([p1, p2, p3]);
results.forEach(result => {
  if (result.status === 'fulfilled') console.log(result.value);
  else console.error(result.reason);
});

// Promise.race — first one wins (useful for timeouts) ✅
const timeout = new Promise((_, reject) =>
  setTimeout(() => reject(new Error('Timeout')), 5000)
);
const data = await Promise.race([fetch('/api/slow'), timeout]);

// Promise.any — first success wins ✅ (use for redundant requests)
const fastest = await Promise.any([
  fetch('https://api1.example.com/data'),
  fetch('https://api2.example.com/data'),
  fetch('https://api3.example.com/data')
]);
// Uses whichever responds first successfully ✅
```

---

## 5.4 async/await

### Q44. What is async/await? How does error handling work and what does an async function always return?

**Answer:**
`async/await` is syntactic sugar over Promises. An `async` function always returns a Promise — returning a non-Promise value wraps it in `Promise.resolve()`. `await` pauses execution of the async function until the Promise settles (but does not block the thread). Errors from rejected Promises are thrown at the `await` point and caught with `try/catch`. An uncaught throw in an async function returns a rejected Promise.

❌ **Violates — missing await, not catching errors:**
```javascript
// Forgetting await ❌
async function getUser() {
  const res = fetch('/api/user'); // missing await — res is a Promise, not response ❌
  return res.json(); // TypeError: res.json is not a function ❌
}

// async in forEach — doesn't work as expected ❌
async function processAll(ids) {
  ids.forEach(async (id) => {
    await processItem(id); // forEach doesn't await these ❌
  });
  // function returns before all items processed ❌
}
```

✅ **Satisfies — correct async/await:**
```javascript
// Async function always returns Promise
async function double(x) {
  return x * 2; // wrapped in Promise.resolve ✅
}
double(5).then(console.log); // 10 ✅

// Error handling with try/catch
async function fetchUser(id) {
  try {
    const res = await fetch(`/api/users/${id}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    console.error('fetchUser failed:', err);
    throw err; // re-throw so caller knows ✅
  }
}

// Parallel with await
async function loadDashboard() {
  const [user, stats] = await Promise.all([
    fetchUser(1),
    fetchStats()
  ]); // runs in parallel ✅
  return { user, stats };
}

// Correct async iteration (for await, not forEach)
async function processAll(ids) {
  for (const id of ids) {
    await processItem(id); // sequential ✅
  }
  // or parallel:
  await Promise.all(ids.map(processItem)); // ✅
}
```

---

## 5.5 Sequential vs Parallel Execution

### Q45. What is the difference between sequential and parallel async execution with async/await?

**Answer:**
Using `await` inside a loop executes operations sequentially — the next iteration waits for the current to complete. This is correct when order matters or operations depend on each other. For independent operations, `Promise.all` with `map` runs them in parallel — all start immediately. Parallel is much faster for network requests; sequential is necessary when operations have dependencies.

❌ **Violates — sequential when parallel would be faster:**
```javascript
// Sequential loop for independent requests — slow! ❌
async function fetchAll(userIds) {
  const users = [];
  for (const id of userIds) {
    const user = await fetchUser(id); // waits for each before starting next ❌
    users.push(user);
  }
  return users;
  // 10 users × 200ms each = 2000ms total ❌
}

// Parallel when sequential needed ❌
async function processOrdered(tasks) {
  await Promise.all(tasks.map(t => processTask(t))); // order not guaranteed ❌
}
```

✅ **Satisfies — sequential vs parallel with clear intent:**
```javascript
// Parallel — all requests fire at once ✅
async function fetchAllParallel(userIds) {
  const users = await Promise.all(userIds.map(id => fetchUser(id)));
  return users;
  // 10 users × 200ms = ~200ms total ✅
}

// Sequential — when order or dependencies matter ✅
async function processSequential(items) {
  const results = [];
  for (const item of items) {
    const result = await processItem(item); // each depends on previous
    results.push(result);
  }
  return results;
}

// Controlled concurrency — parallel but limited (e.g., 3 at a time)
async function fetchWithLimit(ids, limit = 3) {
  const results = [];
  for (let i = 0; i < ids.length; i += limit) {
    const batch = ids.slice(i, i + limit);
    const batchResults = await Promise.all(batch.map(fetchUser));
    results.push(...batchResults);
  }
  return results;
}

// await in reduce — sequential with accumulator
async function sequentialReduce(items) {
  return items.reduce(async (accPromise, item) => {
    const acc = await accPromise;
    const result = await processItem(item);
    return [...acc, result];
  }, Promise.resolve([]));
}
```

---

## 5.6 Error Handling in Async Code

### Q46. How do you handle errors in async code? What is unhandled promise rejection?

**Answer:**
Async errors can be handled with `try/catch` around `await`, `.catch()` on Promise chains, or globally with `window.addEventListener('unhandledrejection')`. A promise rejection is "unhandled" if no `.catch()` or `try/catch` handles it — this causes a warning (or process crash in Node.js). Always handle Promise rejections. `Promise.allSettled` avoids rejection propagation when you want all results.

❌ **Violates — ignoring rejections:**
```javascript
// Unhandled rejection ❌
async function badFetch() {
  const data = await fetch('/api/fail'); // if this rejects, no handler ❌
  return data.json();
}
badFetch(); // Promise rejects, nobody handles it ❌

// Swallowing errors silently ❌
async function silent() {
  try {
    await riskyOperation();
  } catch {} // empty catch — error silently disappears ❌
}
```

✅ **Satisfies — comprehensive error handling:**
```javascript
// try/catch with async/await
async function fetchData(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP error: ${res.status}`);
    return await res.json();
  } catch (err) {
    if (err instanceof TypeError) {
      console.error('Network error:', err);
    } else {
      console.error('Request failed:', err);
    }
    throw err; // re-throw so caller can handle too ✅
  }
}

// Chained .catch
fetch('/api/data')
  .then(res => res.json())
  .then(processData)
  .catch(err => {
    logError(err);
    return fallbackData(); // graceful recovery ✅
  });

// Global unhandled rejection handler
window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled rejection:', event.reason);
  event.preventDefault(); // prevent browser default logging
});

// Node.js equivalent
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Wrapper to ensure all async errors are handled
async function withErrorHandling(fn) {
  try {
    return await fn();
  } catch (err) {
    errorReporter.send(err);
    throw err;
  }
}
```

---

## 5.7 The Microtask Queue

### Q47. What is the microtask queue and why do Promise callbacks run before setTimeout even with delay 0?

**Answer:**
The event loop has two separate queues: the macrotask queue (for setTimeout, setInterval, I/O) and the microtask queue (for Promise `.then`/`.catch`, `queueMicrotask`, MutationObserver). After each macrotask, the engine drains the entire microtask queue before picking the next macrotask. This is why Promise callbacks run before `setTimeout(fn, 0)` — the microtask queue is processed first.

❌ **Violates — wrong assumptions about execution order:**
```javascript
// Many developers assume setTimeout(0) runs "immediately" ❌
console.log('start');
setTimeout(() => console.log('timeout'), 0);
Promise.resolve().then(() => console.log('promise'));
console.log('end');

// Wrong assumption: start → timeout → promise → end ❌
// Actual: start → end → promise → timeout ✅
```

✅ **Satisfies — understanding microtask vs macrotask order:**
```javascript
console.log('1: sync start');

setTimeout(() => console.log('5: macrotask - setTimeout'), 0);

Promise.resolve()
  .then(() => console.log('3: microtask - promise 1'))
  .then(() => console.log('4: microtask - promise 2'));

queueMicrotask(() => console.log('3b: microtask - queueMicrotask'));

console.log('2: sync end');

// Output order:
// 1: sync start
// 2: sync end
// 3: microtask - promise 1
// 3b: microtask - queueMicrotask
// 4: microtask - promise 2  (added to microtask queue by first .then)
// 5: macrotask - setTimeout

// Practical implication: keep microtasks short
// Infinite microtask loop starves macrotasks (and rendering) ❌
function badMicrotaskLoop() {
  Promise.resolve().then(badMicrotaskLoop); // starves event loop ❌
}
```

---

## 5.8 Async Iteration

### Q48. What is async iteration? How do for await...of and async generators work?

**Answer:**
Async iteration allows iterating over asynchronous data sources — like paginated APIs or streams — using `for await...of`. An async iterable implements `Symbol.asyncIterator` returning an object whose `next()` returns a Promise. Async generators (`async function*`) simplify creating async iterables — `yield` pauses and `await` can be used inside.

❌ **Violates — loading all data before processing:**
```javascript
// Loads everything into memory before processing ❌
async function processAllPages() {
  const allData = [];
  let page = 1;
  while (true) {
    const data = await fetchPage(page++);
    if (data.length === 0) break;
    allData.push(...data); // accumulates ALL pages in memory ❌
  }
  return allData.map(processItem);
}
```

✅ **Satisfies — async iteration for streaming/lazy processing:**
```javascript
// Async generator — yields pages lazily ✅
async function* paginate(url) {
  let page = 1;
  while (true) {
    const res = await fetch(`${url}?page=${page}`);
    const data = await res.json();
    if (data.length === 0) return;
    yield data; // yield one page at a time ✅
    page++;
  }
}

// Consume with for await...of
async function processPages() {
  for await (const page of paginate('/api/users')) {
    for (const user of page) {
      await processUser(user); // process one at a time ✅
    }
  }
}

// Custom async iterable
class AsyncRange {
  constructor(start, end, delay = 100) {
    this.start = start;
    this.end = end;
    this.delay = delay;
  }

  [Symbol.asyncIterator]() {
    let current = this.start;
    const { end, delay } = this;
    return {
      async next() {
        await new Promise(r => setTimeout(r, delay));
        if (current <= end) return { value: current++, done: false };
        return { done: true };
      }
    };
  }
}

for await (const num of new AsyncRange(1, 5)) {
  console.log(num); // 1, 2, 3, 4, 5 with delays ✅
}
```

---

## 5.9 Aborting Async Operations

### Q49. How do you cancel async operations using AbortController and AbortSignal?

**Answer:**
`AbortController` creates an `AbortSignal` that can be passed to `fetch` (and other APIs). Calling `controller.abort()` causes the signal to fire, the fetch Promise rejects with an `AbortError`, and the network request is cancelled. This is essential for preventing stale data from outdated requests (race conditions) and for cleanup in React effects.

❌ **Violates — no cancellation leads to race conditions:**
```javascript
// No cancellation — stale response can arrive after new request ❌
async function search(query) {
  const res = await fetch(`/api/search?q=${query}`);
  const data = await res.json();
  displayResults(data); // could be stale if user typed faster ❌
}
// User types 'a', then 'ab' — 'ab' response arrives first, then 'a' overwrites ❌
```

✅ **Satisfies — AbortController for cancellation:**
```javascript
// Basic abort
let controller = new AbortController();

async function fetchData(url) {
  try {
    const res = await fetch(url, { signal: controller.signal });
    return await res.json();
  } catch (err) {
    if (err.name === 'AbortError') {
      console.log('Fetch aborted'); // expected — not an error ✅
      return null;
    }
    throw err;
  }
}

// Cancel on demand
controller.abort(); // cancels the fetch ✅

// Debounced search with cancellation
let searchController = null;
async function search(query) {
  // Cancel previous search
  searchController?.abort();
  searchController = new AbortController();

  try {
    const res = await fetch(`/api/search?q=${query}`, {
      signal: searchController.signal
    });
    const data = await res.json();
    displayResults(data); // only latest request's data shown ✅
  } catch (err) {
    if (err.name !== 'AbortError') throw err;
  }
}

// React useEffect cleanup pattern
// useEffect(() => {
//   const controller = new AbortController();
//   fetchData(controller.signal);
//   return () => controller.abort(); // cleanup on unmount ✅
// }, []);
```

---

## 5.10 Converting Callbacks to Promises

### Q50. How do you convert callback-based APIs to Promises? What is promisification?

**Answer:**
Promisification wraps a callback-based function in a Promise. The convention for Node.js callbacks is error-first: `callback(err, result)`. You create a Promise where `resolve` is called with the result and `reject` with the error. Node.js provides `util.promisify` for automatic conversion of standard error-first callbacks.

❌ **Violates — mixing callbacks and Promises awkwardly:**
```javascript
// Callback inside Promise executor with wrong error handling ❌
function readFilePromise(path) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, (err, data) => {
      if (err) resolve(null); // should reject, not resolve with null ❌
      resolve(data); // called even if err exists ❌
    });
  });
}
```

✅ **Satisfies — correct promisification:**
```javascript
const fs = require('fs');
const util = require('util');

// Manual promisification
function readFilePromise(path, encoding = 'utf8') {
  return new Promise((resolve, reject) => {
    fs.readFile(path, encoding, (err, data) => {
      if (err) reject(err); // ✅ reject on error
      else resolve(data);   // ✅ resolve on success
    });
  });
}

// Usage
readFilePromise('./data.json')
  .then(JSON.parse)
  .then(data => console.log(data))
  .catch(err => console.error('Read failed:', err));

// util.promisify — auto-converts error-first callbacks ✅
const readFile = util.promisify(fs.readFile);
const writeFile = util.promisify(fs.writeFile);

async function copyFile(src, dest) {
  const content = await readFile(src, 'utf8');
  await writeFile(dest, content);
}

// Generic promisify
function promisify(fn) {
  return function(...args) {
    return new Promise((resolve, reject) => {
      fn(...args, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  };
}

// Promisify with multiple result args
function promisifyMulti(fn) {
  return function(...args) {
    return new Promise((resolve, reject) => {
      fn(...args, (err, ...results) => {
        if (err) reject(err);
        else resolve(results.length === 1 ? results[0] : results);
      });
    });
  };
}
```

---

# 6. Event Loop & Concurrency

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Event_loop
> 📚 Medium: https://medium.com/better-programming/is-javascript-synchronous-or-asynchronous-what-the-heck-is-a-promise-7aa9dd8f3bfb

---

## 6.1 The Event Loop

### Q51. Explain the event loop step by step — call stack, Web APIs, and callback queue.

**Answer:**
JavaScript is single-threaded with one call stack. When an async operation (setTimeout, fetch, event listener) is encountered, it is handed to a Web API (browser) or C++ API (Node.js) which handles it off the main thread. When the async operation completes, its callback is placed in the callback/task queue. The event loop continuously checks: if the call stack is empty, it moves the next callback from the queue to the stack for execution.

❌ **Violates — blocking the call stack:**
```javascript
// Synchronous blocking — event loop can't process anything ❌
function blockFor(ms) {
  const start = Date.now();
  while (Date.now() - start < ms) {} // CPU spin ❌
}

blockFor(3000); // UI freezes for 3 seconds ❌
// No events, no rendering, nothing processes during this time ❌
```

✅ **Satisfies — understanding event loop mechanics:**
```javascript
// Event loop walkthrough
console.log('A'); // 1. sync — goes on call stack immediately

setTimeout(() => console.log('B'), 0); // 2. handed to Web API → timer → callback queue

Promise.resolve().then(() => console.log('C')); // 3. → microtask queue

console.log('D'); // 4. sync

// Execution order: A → D → C → B
// A, D: call stack (sync)
// C: microtask queue (after call stack clears)
// B: callback/macrotask queue (after microtask queue clears)

// Visualizing the event loop
// ┌─────────────────────────┐
// │      Call Stack         │ ← executes synchronous code
// ├─────────────────────────┤
// │   Microtask Queue       │ ← Promise .then, queueMicrotask
// ├─────────────────────────┤
// │   Macrotask Queue       │ ← setTimeout, setInterval, I/O
// └─────────────────────────┘

// Non-blocking alternative to spin-wait ✅
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
async function doWork() {
  await delay(3000); // non-blocking ✅
  console.log('done after 3s');
}
```

---

## 6.2 Macrotasks vs Microtasks

### Q52. What is the difference between macrotasks and microtasks? What is their execution order?

**Answer:**
Macrotasks (tasks): setTimeout, setInterval, setImmediate, I/O, UI events. Microtasks: Promise `.then`/`.catch`/`.finally`, `queueMicrotask`, MutationObserver. The event loop rule: run one macrotask → drain ALL microtasks → render (if browser) → next macrotask. Microtasks added during microtask processing are also processed before the next macrotask.

❌ **Violates — wrong mental model of execution order:**
```javascript
// Assuming all callbacks have equal priority ❌
setTimeout(() => console.log('timeout 1'), 0);
setTimeout(() => console.log('timeout 2'), 0);
Promise.resolve().then(() => {
  console.log('promise 1');
  // Adding another microtask INSIDE a microtask ❌ (common surprise)
  Promise.resolve().then(() => console.log('promise 2'));
});

// Wrong order assumption: promise 1 → timeout 1 → promise 2 → timeout 2 ❌
// Actual: promise 1 → promise 2 → timeout 1 → timeout 2 ✅
```

✅ **Satisfies — correct microtask/macrotask model:**
```javascript
// Execution order demonstration
console.log('sync 1');

setTimeout(() => console.log('macro 1'), 0);

Promise.resolve()
  .then(() => {
    console.log('micro 1');
    return Promise.resolve();
  })
  .then(() => console.log('micro 2'));

setTimeout(() => console.log('macro 2'), 0);

console.log('sync 2');

// Output:
// sync 1, sync 2    ← call stack (sync)
// micro 1, micro 2  ← microtask queue (fully drained)
// macro 1, macro 2  ← macrotask queue (one at a time)

// Use queueMicrotask for fine-grained control
function scheduleHigh(fn) {
  queueMicrotask(fn); // runs before any setTimeout ✅
}

function scheduleLow(fn) {
  setTimeout(fn, 0); // runs after all microtasks ✅
}
```

---

## 6.3 setTimeout(fn, 0)

### Q53. Why doesn't setTimeout(fn, 0) mean immediate execution? What are its use cases?

**Answer:**
`setTimeout(fn, 0)` schedules `fn` as a macrotask, not for immediate execution. It runs after: the current call stack completes, all microtasks are drained, and the browser possibly renders. The actual delay may be longer than 0ms — browsers clamp minimum timer intervals (typically 1ms, 4ms for nested timers). Use cases: deferring work after rendering, yielding the thread, running code after the current event handler.

❌ **Violates — expecting setTimeout(0) to be immediate:**
```javascript
let value = 0;

setTimeout(() => {
  console.log(value); // expects 0 but actually printed after setup ❌
}, 0);

value = 42;
// setTimeout(0) runs AFTER this line ✅ (but many think it runs immediately) ❌

// UI update not visible before setTimeout(0) ❌
button.textContent = 'Loading...';
setTimeout(() => {
  heavyComputation(); // browser doesn't repaint before this ❌
}, 0);
```

✅ **Satisfies — correct understanding of setTimeout(0):**
```javascript
// Deferred execution after current stack
console.log('1');
setTimeout(() => console.log('3'), 0); // runs after '2'
console.log('2');
// Output: 1, 2, 3 ✅

// Use case: read DOM after it updates
function updateAndRead() {
  element.textContent = 'Updated';
  setTimeout(() => {
    console.log(element.offsetHeight); // DOM has updated ✅
  }, 0);
}

// Yield to browser to render
async function processLargeArray(items) {
  for (let i = 0; i < items.length; i++) {
    processItem(items[i]);
    if (i % 100 === 0) {
      // Yield to event loop every 100 items ✅
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  }
}

// Clamping: nested setTimeouts get minimum ~4ms delay
// Use MessageChannel for true 0-delay macrotask scheduling
const { port1, port2 } = new MessageChannel();
port1.onmessage = () => console.log('faster than setTimeout(0)');
port2.postMessage(null); // ✅
```

---

## 6.4 requestAnimationFrame

### Q54. When should you use requestAnimationFrame instead of setTimeout for animations?

**Answer:**
`requestAnimationFrame` (rAF) calls the callback just before the browser's next repaint — typically 60 times per second (16.7ms apart). Unlike `setTimeout`, rAF is synchronized with the display refresh rate, automatically pauses in background tabs (saving CPU/battery), and avoids layout thrashing when reading/writing DOM. Always use rAF for animations, never `setTimeout`/`setInterval`.

❌ **Violates — using setTimeout for animation:**
```javascript
// setTimeout animation — choppy and wasteful ❌
function animate() {
  element.style.left = (parseFloat(element.style.left) + 1) + 'px';
  setTimeout(animate, 16); // not synced to display refresh ❌
  // Runs even in background tabs ❌
  // May cause layout thrashing ❌
}
setTimeout(animate, 16);
```

✅ **Satisfies — requestAnimationFrame for animations:**
```javascript
// rAF animation — smooth and efficient ✅
let position = 0;
let animationId;

function animate(timestamp) {
  position += 2;
  element.style.transform = `translateX(${position}px)`;

  if (position < 300) {
    animationId = requestAnimationFrame(animate); // loops until done ✅
  }
}

animationId = requestAnimationFrame(animate);

// Cancel animation
function stopAnimation() {
  cancelAnimationFrame(animationId); // ✅
}

// Read/write separation to avoid layout thrashing
function updateElements(elements) {
  requestAnimationFrame(() => {
    // Read phase — all reads first
    const heights = elements.map(el => el.offsetHeight);

    // Write phase — all writes after reads
    elements.forEach((el, i) => {
      el.style.height = `${heights[i] * 2}px`;
    }); // ✅ no layout thrashing
  });
}

// rAF throttle for scroll/resize handlers
let ticking = false;
window.addEventListener('scroll', () => {
  if (!ticking) {
    requestAnimationFrame(() => {
      updateScrollUI();
      ticking = false;
    });
    ticking = true;
  }
}); // ✅
```

---

## 6.5 Why JavaScript is Single-Threaded

### Q55. Why is JavaScript single-threaded and how does the event loop enable concurrency?

**Answer:**
JavaScript was designed for the browser where multi-threaded DOM access would cause race conditions (two threads modifying the DOM simultaneously). Single-threading eliminates the need for locks and simplifies the programming model. Concurrency is achieved through the event loop — async I/O operations are delegated to browser/OS APIs which run on separate threads, and callbacks are queued when done. JavaScript code itself always runs on one thread.

❌ **Violates — trying to share mutable state across "threads":**
```javascript
// JavaScript doesn't have traditional threads — this pattern is wrong mindset ❌
// You can't do this in JS (unlike Java/C++):
// Thread 1: counter++;
// Thread 2: counter++;
// Race condition — impossible in JS but common mistake to worry about ❌

// Wrong: thinking async = multi-threaded ❌
let total = 0;
async function addToTotal(n) {
  // Even with await, only one piece of code runs at a time ✅
  // No race condition possible in single-threaded JS ✅
  total += n;
}
```

✅ **Satisfies — understanding single-thread concurrency model:**
```javascript
// JS is concurrent but not parallel
// These appear to run simultaneously but don't:
fetch('/api/a').then(handleA); // delegated to browser networking
fetch('/api/b').then(handleB); // also delegated — runs in parallel at OS level
// JS code (handleA, handleB) runs serially ✅ — no races

// Advantages of single-threading:
// 1. No mutex/lock needed
// 2. No race conditions in JS code
// 3. Simpler mental model

// Worker threads DO run in parallel
const worker = new Worker('worker.js');
worker.postMessage({ task: 'heavy computation' });
worker.onmessage = (e) => {
  console.log('Result from worker:', e.data); // callback on main thread ✅
};
// worker.js runs on separate thread but can't access main thread DOM ✅

// Node.js worker_threads
const { Worker } = require('worker_threads');
const worker = new Worker(`
  const { parentPort } = require('worker_threads');
  parentPort.postMessage(heavyCompute());
`, { eval: true });
```

---

## 6.6 Blocking the Event Loop

### Q56. What blocks the event loop and how do you prevent it?

**Answer:**
Any synchronous, CPU-intensive operation blocks the event loop: large array operations, complex calculations, JSON parsing of huge payloads, or infinite loops. While blocked, no events, network callbacks, timers, or UI renders can execute. Solutions: Web Workers for CPU work, chunking work with `setTimeout(0)`, using `requestIdleCallback`, or streaming data instead of parsing all at once.

❌ **Violates — synchronous heavy computation blocks UI:**
```javascript
// Blocks event loop for the duration ❌
function sortHugeArray(arr) {
  return arr.sort((a, b) => a - b); // blocks if arr has millions of items ❌
}

button.onclick = () => {
  const result = sortHugeArray(millionItems); // UI freezes ❌
  display(result);
};

// Synchronous JSON parse of huge payload ❌
const data = JSON.parse(hugeString); // blocks if hugeString is very large ❌
```

✅ **Satisfies — non-blocking patterns:**
```javascript
// Web Worker for CPU-intensive work ✅
// main.js
const worker = new Worker('sorter.js');
worker.postMessage(millionItems);
worker.onmessage = (e) => display(e.data);
// UI stays responsive ✅

// sorter.js
self.onmessage = (e) => {
  const sorted = e.data.sort((a, b) => a - b);
  self.postMessage(sorted);
};

// Chunked processing to yield to event loop ✅
async function processInChunks(items, chunkSize = 1000) {
  const results = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    const chunk = items.slice(i, i + chunkSize);
    results.push(...chunk.map(processItem));
    // Yield every chunk — allows UI updates and events ✅
    await new Promise(resolve => setTimeout(resolve, 0));
  }
  return results;
}

// requestIdleCallback for low-priority work ✅
requestIdleCallback((deadline) => {
  while (deadline.timeRemaining() > 0 && tasks.length > 0) {
    processTask(tasks.shift()); // only runs when browser is idle ✅
  }
  if (tasks.length > 0) requestIdleCallback(arguments.callee);
});
```

---

## 6.7 Web Workers

### Q57. What are Web Workers? How does communication work and what are SharedArrayBuffer's use cases?

**Answer:**
Web Workers run JavaScript on a separate background thread, allowing CPU-intensive code without blocking the main thread. Workers have no access to the DOM or main thread variables. Communication is via `postMessage` / `onmessage` — data is serialized (structured clone) meaning it is copied, not shared. `SharedArrayBuffer` enables true shared memory between threads, requiring `Atomics` for synchronization.

❌ **Violates — trying to share DOM or objects directly:**
```javascript
// Worker cannot access DOM ❌
// worker.js
document.getElementById('output').textContent = 'done'; // ReferenceError ❌

// Direct object sharing doesn't work — postMessage clones ❌
const sharedObj = { count: 0 };
worker.postMessage(sharedObj);
sharedObj.count = 1; // worker has its own copy — this change is not seen ❌
```

✅ **Satisfies — Web Workers with proper communication:**
```javascript
// main.js
const worker = new Worker('worker.js');

// Send data to worker (structured clone — copy)
worker.postMessage({ type: 'PROCESS', data: largeArray });

// Receive result
worker.onmessage = (event) => {
  console.log('Worker result:', event.data);
};

// Transferable objects — transfer ownership, zero-copy ✅
const buffer = new ArrayBuffer(1024 * 1024); // 1MB
worker.postMessage({ buffer }, [buffer]); // transfer, not copy
// buffer is now unusable in main thread — worker owns it ✅

// SharedArrayBuffer — true shared memory ✅
const shared = new SharedArrayBuffer(4);
const view = new Int32Array(shared);

worker.postMessage({ shared });

// Atomics for thread-safe operations
Atomics.add(view, 0, 1); // atomic increment — safe across threads ✅
Atomics.wait(view, 0, 0); // block until value at index 0 !== 0

// worker.js
self.onmessage = ({ data: { type, data } }) => {
  if (type === 'PROCESS') {
    const result = data.map(heavyCompute);
    self.postMessage(result);
  }
};
```

---

## 6.8 setImmediate / process.nextTick

### Q58. Where do setImmediate and process.nextTick fit in the Node.js event loop?

**Answer:**
`process.nextTick` callbacks run after the current operation completes but BEFORE the event loop continues — they are processed before any I/O, timers, or `setImmediate`. `setImmediate` runs in the "check" phase of the event loop — after I/O events but before timers. In practice: `process.nextTick` > Promise microtasks > `setImmediate` > `setTimeout`.

❌ **Violates — misusing process.nextTick causing starvation:**
```javascript
// Recursive nextTick starves I/O — infinite loop of nextTick ❌
function recurse() {
  process.nextTick(recurse); // never lets I/O callbacks run ❌
}
recurse();

// Confusing setImmediate with setTimeout(0) ❌
setImmediate(() => console.log('immediate'));
setTimeout(() => console.log('timeout'), 0);
// Order is NOT guaranteed between these two ❌
```

✅ **Satisfies — Node.js event loop phases:**
```javascript
// Node.js event loop phase order:
// timers → I/O callbacks → idle/prepare → poll → check → close callbacks
// nextTick and Promises run between each phase (micro-ish)

console.log('start');

process.nextTick(() => console.log('nextTick 1'));

Promise.resolve().then(() => console.log('promise 1'));

setImmediate(() => console.log('setImmediate'));

setTimeout(() => console.log('setTimeout 0'), 0);

process.nextTick(() => console.log('nextTick 2'));

console.log('end');

// Output:
// start
// end
// nextTick 1   ← process.nextTick (runs before promises!)
// nextTick 2
// promise 1    ← Promise microtask
// setTimeout 0 ← (or setImmediate, order varies at top level)
// setImmediate

// Use process.nextTick for: emitting events after synchronous setup
class EventEmitter {
  constructor() {
    process.nextTick(() => {
      this.emit('ready'); // emit after caller has chance to add listener ✅
    });
  }
}
```

---

## 6.9 Debounce vs Throttle

### Q59. What are debounce and throttle? Implement both from scratch and explain when to use each.

**Answer:**
**Debounce** delays function execution until after a specified time has elapsed since the last call — useful for search-as-you-type where you want to wait for the user to stop typing. **Throttle** ensures a function is called at most once per time window — useful for scroll or resize handlers where you want regular updates but not on every event. Debounce = "call after quiet period"; Throttle = "call at most every N ms".

❌ **Violates — calling expensive functions on every event:**
```javascript
// Fires an API call on every single keystroke ❌
input.addEventListener('input', (e) => {
  fetchSearchResults(e.target.value); // 100s of requests ❌
});

// Fires on every scroll pixel ❌
window.addEventListener('scroll', () => {
  updateParallaxEffect(); // jank and performance issues ❌
});
```

✅ **Satisfies — debounce and throttle implementations:**
```javascript
// Debounce — delays until quiet
function debounce(fn, delay) {
  let timeoutId;
  return function(...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      fn.apply(this, args);
    }, delay);
  };
}

// Throttle — at most once per interval
function throttle(fn, interval) {
  let lastCall = 0;
  return function(...args) {
    const now = Date.now();
    if (now - lastCall >= interval) {
      lastCall = now;
      return fn.apply(this, args);
    }
  };
}

// Debounce for search input ✅
const debouncedSearch = debounce((query) => {
  fetchSearchResults(query);
}, 300); // wait 300ms of silence
input.addEventListener('input', (e) => debouncedSearch(e.target.value));

// Throttle for scroll ✅
const throttledScroll = throttle(() => {
  updateParallaxEffect();
}, 16); // max 60fps
window.addEventListener('scroll', throttledScroll);

// Debounce with immediate option (fire on leading edge)
function debounceLeading(fn, delay) {
  let timeoutId;
  return function(...args) {
    if (!timeoutId) fn.apply(this, args); // fire immediately ✅
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => { timeoutId = null; }, delay);
  };
}
```

---

## 6.10 Rendering and the Event Loop

### Q60. When does the browser render in relation to the event loop? What is requestIdleCallback?

**Answer:**
The browser rendering step (style + layout + paint) happens between macrotasks — the browser renders after the current macrotask and all microtasks have completed. Long macrotasks delay rendering, causing jank. `requestAnimationFrame` callbacks run just before rendering. `requestIdleCallback` fires when the browser is idle (no rendering needed, no tasks queued) — ideal for analytics, prefetching, or non-critical work.

❌ **Violates — blocking rendering with synchronous work:**
```javascript
// Multiple DOM writes causing multiple reflows ❌
function updateAll(items) {
  items.forEach(item => {
    const height = item.offsetHeight; // read — triggers layout ❌
    item.style.height = (height * 2) + 'px'; // write — invalidates layout ❌
    // Alternating read/write = thrashing ❌
  });
}
```

✅ **Satisfies — render-aware patterns:**
```javascript
// Batch DOM reads then writes inside rAF ✅
function updateAll(items) {
  requestAnimationFrame(() => {
    // Phase 1: all reads
    const heights = items.map(item => item.offsetHeight);

    // Phase 2: all writes
    items.forEach((item, i) => {
      item.style.height = `${heights[i] * 2}px`;
    });
  }); // only one layout/paint ✅
}

// requestIdleCallback for non-critical work ✅
function sendAnalytics(data) {
  if ('requestIdleCallback' in window) {
    requestIdleCallback(() => {
      sendToAnalyticsServer(data); // runs when browser is idle ✅
    }, { timeout: 2000 }); // fallback after 2s if never idle
  } else {
    setTimeout(() => sendToAnalyticsServer(data), 0); // fallback ✅
  }
}

// Rendering timeline:
// [Macrotask] → [Microtasks] → [rAF] → [render] → [rIC if idle] → [Next macrotask]

// Force layout — avoid reading these synchronously after DOM writes:
// offsetHeight, offsetWidth, scrollTop, getBoundingClientRect, etc.
// Reading them forces the browser to flush pending styles ❌ (costly)
```


---

# 7. ES6+ Modern Features

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes
> 📚 Medium: https://medium.com/javascript-scene/javascript-factory-functions-vs-constructor-functions-vs-classes-2f22ceddf33e

---

## 7.1 Classes — Full Syntax

### Q61. What is the full class syntax including private fields, static methods, and getters/setters?

**Answer:**
ES2022 added private class fields with the `#` prefix — they are truly private, accessible only within the class body (not through `this` in subclasses or any external code). Static fields and methods belong to the class itself. Getters and setters define computed properties. Private methods (`#methodName`) are also supported. Private fields are NOT the same as underscore convention — the engine enforces privacy.

❌ **Violates — underscore convention is not true privacy:**
```javascript
class BankAccount {
  constructor(balance) {
    this._balance = balance; // convention only — still accessible ❌
  }
  withdraw(amount) {
    this._balance -= amount; // anyone can also do account._balance -= 1000000 ❌
  }
}

const account = new BankAccount(1000);
account._balance = 999999; // no enforcement ❌
```

✅ **Satisfies — full modern class syntax:**
```javascript
class BankAccount {
  // Private field — truly inaccessible outside ✅
  #balance;
  #transactionHistory = [];

  // Static field
  static #interestRate = 0.05;

  constructor(initialBalance) {
    this.#balance = initialBalance;
  }

  // Private method
  #recordTransaction(amount, type) {
    this.#transactionHistory.push({ amount, type, date: new Date() });
  }

  // Getter
  get balance() {
    return this.#balance;
  }

  // Setter with validation
  set balance(value) {
    if (value < 0) throw new Error('Balance cannot be negative');
    this.#balance = value;
  }

  deposit(amount) {
    this.#balance += amount;
    this.#recordTransaction(amount, 'deposit');
    return this; // chainable ✅
  }

  withdraw(amount) {
    if (amount > this.#balance) throw new Error('Insufficient funds');
    this.#balance -= amount;
    this.#recordTransaction(amount, 'withdrawal');
    return this;
  }

  // Static method
  static getInterestRate() {
    return BankAccount.#interestRate;
  }

  // Check private field from outside — hasPrivateField
  static isAccount(obj) {
    try { obj.#balance; return true; }
    catch { return false; }
  }
}

const acc = new BankAccount(1000);
acc.deposit(500).withdraw(200); // chaining ✅
console.log(acc.balance); // 1300 — getter ✅
// acc.#balance; // SyntaxError — truly private ✅
```

---

## 7.2 Modules

### Q62. How do ES6 modules work? What is the difference between default and named exports? What is dynamic import?

**Answer:**
ES6 modules use `import`/`export` syntax. **Named exports** export multiple values by name — they must be imported by the same name (or aliased). **Default exports** export one main value — imported with any name. Modules are singletons — the same instance is shared across all imports. `import()` (dynamic import) is lazy — loads a module on demand and returns a Promise. This enables code splitting.

❌ **Violates — mixing module systems or re-exporting incorrectly:**
```javascript
// CommonJS in ESM context ❌
const fs = require('fs'); // SyntaxError in ESM ❌

// Default export imported with wrong syntax ❌
// math.js: export default function add(a,b) { return a+b; }
import { add } from './math.js'; // Wrong — add is default export ❌
```

✅ **Satisfies — ES6 modules in full:**
```javascript
// utils.js — named exports
export const PI = 3.14159;
export function add(a, b) { return a + b; }
export function subtract(a, b) { return a - b; }

// calculator.js — default export
export default class Calculator {
  add(a, b) { return a + b; }
}

// main.js — importing
import Calculator from './calculator.js';        // default — any name ✅
import { add, subtract, PI } from './utils.js';  // named — must match ✅
import { add as sum } from './utils.js';          // alias ✅
import * as utils from './utils.js';              // namespace import ✅

// Re-export
export { add, subtract } from './utils.js'; // re-export named ✅
export { default as Calc } from './calculator.js'; // re-export default as named ✅

// Dynamic import — lazy loading ✅
async function loadChart() {
  const { Chart } = await import('./chart.js');
  return new Chart();
}

// Code splitting — load only when needed
button.addEventListener('click', async () => {
  const { heavyFeature } = await import('./heavyFeature.js');
  heavyFeature(); // loaded on demand ✅
});

// Modules are singletons
// import { state } from './store.js';
// All importers share the same state object ✅
```

---

## 7.3 Generators

### Q63. What are generator functions? How does yield work and what are practical use cases?

**Answer:**
A generator function (`function*`) returns an iterator. Execution pauses at each `yield` and resumes when `next()` is called. `next()` returns `{ value, done }`. Generators are lazy — they produce values on demand. Use cases: infinite sequences, custom iterables, async flow control, coroutines, and implementing `async/await` (generators + Promises is what transpilers used before native async/await).

❌ **Violates — eager computation when lazy is better:**
```javascript
// Generates entire infinite sequence upfront — impossible ❌
function* naturalNumbers() {
  // Can't return an array of all natural numbers ❌
}

// Without generators — large eager array ❌
function range(start, end) {
  const result = [];
  for (let i = start; i <= end; i++) result.push(i); // all in memory ❌
  return result;
}
const r = range(0, 1000000); // 1M items allocated ❌
```

✅ **Satisfies — generators for lazy evaluation:**
```javascript
// Infinite sequence — only computes on demand ✅
function* naturals() {
  let n = 1;
  while (true) {
    yield n++;
  }
}

// Take first N from any generator
function* take(gen, n) {
  let count = 0;
  for (const val of gen) {
    if (count++ >= n) return;
    yield val;
  }
}

console.log([...take(naturals(), 5)]); // [1, 2, 3, 4, 5] ✅

// Lazy range
function* range(start, end, step = 1) {
  for (let i = start; i <= end; i += step) {
    yield i;
  }
}

for (const i of range(0, 1000000)) {
  if (i > 10) break; // stops early — no memory wasted ✅
}

// Two-way communication with next(value)
function* dialog() {
  const name = yield 'What is your name?';
  const age = yield `Hello ${name}! How old are you?`;
  yield `${name} is ${age} years old.`;
}

const gen = dialog();
console.log(gen.next().value);       // 'What is your name?'
console.log(gen.next('Alice').value); // 'Hello Alice! How old are you?'
console.log(gen.next(30).value);     // 'Alice is 30 years old.'
```

---

## 7.4 Iterators

### Q64. What is the iterator protocol? How does for...of work and how do you create custom iterables?

**Answer:**
An **iterable** is an object with a `[Symbol.iterator]()` method returning an **iterator**. An **iterator** is an object with a `next()` method returning `{ value, done }`. `for...of` calls `Symbol.iterator` to get the iterator and calls `next()` until `done: true`. Built-in iterables: arrays, strings, Maps, Sets, generators. `for...in` iterates enumerable property keys — different and unrelated.

❌ **Violates — for...in on arrays:**
```javascript
const arr = [10, 20, 30];
arr.customProp = 'oops';

for (const key in arr) {
  console.log(key); // '0', '1', '2', 'customProp' ❌ — includes non-index props
}
// for...in on arrays is almost always wrong ❌
```

✅ **Satisfies — iterables and for...of:**
```javascript
// for...of uses Symbol.iterator ✅
const arr = [10, 20, 30];
for (const val of arr) {
  console.log(val); // 10, 20, 30 — values, not keys ✅
}

// Strings are iterable
for (const char of 'hello') {
  console.log(char); // h, e, l, l, o — handles Unicode correctly ✅
}

// Custom iterable object
const countdown = {
  from: 5,
  [Symbol.iterator]() {
    let count = this.from;
    return {
      next() {
        return count >= 0
          ? { value: count--, done: false }
          : { done: true };
      },
      [Symbol.iterator]() { return this; } // iterable iterator ✅
    };
  }
};

console.log([...countdown]); // [5, 4, 3, 2, 1, 0] ✅

// Destructuring uses Symbol.iterator
const [first, second] = countdown; // 5, 4 ✅

// for...in vs for...of
const obj = { a: 1, b: 2 };
for (const key in obj) console.log(key);   // 'a', 'b' — keys
for (const val of Object.values(obj)) console.log(val); // 1, 2 — values ✅
```

---

## 7.5 Map vs Object and Set vs Array

### Q65. When should you use Map over Object and Set over Array? What are WeakMap and WeakSet?

**Answer:**
`Map` allows any type as key (not just strings/symbols), maintains insertion order, has a `.size` property, and is optimized for frequent additions/deletions. Use `Map` when keys are unknown at runtime or non-string. `Set` stores unique values with O(1) lookup — use for deduplication or membership checks. `WeakMap` and `WeakSet` hold weak references — keys can be garbage collected when no other references exist, making them ideal for private data or caching without memory leaks.

❌ **Violates — using Object when Map is better:**
```javascript
// Object as map — prototype collision risk ❌
const map = {};
map['constructor'] = 'value'; // shadows prototype ❌
map['__proto__'] = 'value';   // security risk ❌

// Array for uniqueness — O(n) includes ❌
const seen = [];
items.forEach(item => {
  if (!seen.includes(item)) { // O(n) check ❌
    seen.push(item);
  }
});

// No easy size for object ❌
const count = Object.keys(map).length; // extra step ❌
```

✅ **Satisfies — Map, Set, WeakMap, WeakSet:**
```javascript
// Map — any key type, ordered, O(1) operations
const map = new Map();
map.set({ id: 1 }, 'object key'); // non-string key ✅
map.set(42, 'number key');
map.set('name', 'string key');
console.log(map.size); // 3 ✅

// Iterate Map
for (const [key, value] of map) {
  console.log(key, value); // ✅
}

// Set — unique values, O(1) has()
const set = new Set([1, 2, 2, 3, 3]);
console.log([...set]); // [1, 2, 3] — deduplicated ✅
set.has(2); // true — O(1) ✅

// Deduplication
const unique = [...new Set(arr)]; // ✅

// WeakMap — keys must be objects, doesn't prevent GC
const cache = new WeakMap();
function processUser(user) {
  if (cache.has(user)) return cache.get(user); // cache hit
  const result = expensiveCompute(user);
  cache.set(user, result); // won't prevent user from being GC'd ✅
  return result;
}

// WeakSet — membership check without preventing GC
const processedNodes = new WeakSet();
function processOnce(node) {
  if (processedNodes.has(node)) return;
  doProcess(node);
  processedNodes.add(node); // node can still be GC'd ✅
}
```

---

## 7.6 Proxy and Reflect

### Q66. What are Proxy and Reflect? What are common trap use cases?

**Answer:**
`Proxy` wraps an object and intercepts operations (traps): `get`, `set`, `has`, `deleteProperty`, `apply`, `construct`, etc. `Reflect` mirrors the same operations as static methods — used inside traps to perform the default operation. Proxy enables: validation, logging, reactivity systems (like Vue 3), default values, and access control. Overused proxies hurt performance — use only when interception is the right pattern.

❌ **Violates — setting invalid data directly without validation:**
```javascript
const user = { age: 25, name: 'Alice' };

// No validation — invalid data enters directly ❌
user.age = -5;    // negative age — allowed ❌
user.age = 'old'; // wrong type — allowed ❌
```

✅ **Satisfies — Proxy and Reflect:**
```javascript
// Validation proxy
function createValidated(target, validators) {
  return new Proxy(target, {
    set(target, prop, value, receiver) {
      if (validators[prop]) {
        const error = validators[prop](value);
        if (error) throw new TypeError(`${prop}: ${error}`);
      }
      return Reflect.set(target, prop, value, receiver); // default behavior ✅
    }
  });
}

const user = createValidated({}, {
  age: (v) => typeof v !== 'number' ? 'must be number' : v < 0 ? 'must be positive' : null,
  name: (v) => typeof v !== 'string' ? 'must be string' : null
});

user.age = 25;     // ✅
user.name = 'Bob'; // ✅
// user.age = -1;  // TypeError ✅

// Default value proxy
const withDefaults = (defaults) => new Proxy({}, {
  get(target, prop, receiver) {
    return Reflect.get(target, prop, receiver) ?? defaults[prop];
  }
});

const config = withDefaults({ timeout: 3000, retries: 3 });
config.timeout; // 3000 ✅ (from defaults)
config.timeout = 5000;
config.timeout; // 5000 ✅ (own value)

// Logging proxy for debugging
const logger = (target) => new Proxy(target, {
  get(t, prop, r) {
    console.log(`GET ${String(prop)}`);
    return Reflect.get(t, prop, r);
  },
  set(t, prop, value, r) {
    console.log(`SET ${String(prop)} = ${value}`);
    return Reflect.set(t, prop, value, r);
  }
});
```

---

## 7.7 WeakRef and FinalizationRegistry

### Q67. What are WeakRef and FinalizationRegistry? When are they useful?

**Answer:**
`WeakRef` holds a weak reference to an object — if no other strong references exist, the object can be garbage collected. `WeakRef.prototype.deref()` returns the object or `undefined` if GC'd. `FinalizationRegistry` registers a callback that fires after an object is GC'd — useful for cleanup. They are advanced tools for cache implementations that should not prevent GC of cached values.

❌ **Violates — strong reference prevents garbage collection:**
```javascript
// Cache holds strong reference — objects never GC'd ❌
const cache = new Map();
function process(obj) {
  if (cache.has(obj)) return cache.get(obj);
  const result = expensiveCompute(obj);
  cache.set(obj, result); // obj is now strongly referenced — no GC ❌
  return result;
}
// Memory leak: all processed objects stay in memory forever ❌
```

✅ **Satisfies — WeakRef for GC-friendly caches:**
```javascript
// WeakRef cache — objects can be GC'd when not in use elsewhere
const cache = new Map();
const registry = new FinalizationRegistry((key) => {
  cache.delete(key); // cleanup when object is GC'd ✅
  console.log(`Cleaned up cache for key: ${key}`);
});

function cacheResult(key, obj) {
  const ref = new WeakRef(obj);
  cache.set(key, ref);
  registry.register(obj, key); // register for cleanup ✅
}

function getCached(key) {
  const ref = cache.get(key);
  if (!ref) return null;
  const obj = ref.deref(); // returns object or undefined if GC'd ✅
  if (!obj) {
    cache.delete(key); // already GC'd
    return null;
  }
  return obj;
}

// Important: GC timing is non-deterministic — don't rely on it for logic ✅
// WeakRef is for performance optimization only, not correctness ✅
```

---

## 7.8 Logical Operators Deep Dive

### Q68. Explain ??, ?., ??=, ||=, &&= with practical patterns.

**Answer:**
`??` (nullish coalescing) returns right side only when left is `null`/`undefined` — unlike `||` which triggers on any falsy. `?.` (optional chaining) short-circuits on `null`/`undefined`. `??=` (nullish assignment) assigns only if left is nullish. `||=` assigns if left is falsy. `&&=` assigns if left is truthy. These operators enable concise, safe patterns for default values and conditional updates.

❌ **Violates — using || for defaults with falsy valid values:**
```javascript
const config = { port: 0, name: '', debug: false };

// All wrong — valid falsy values overridden ❌
const port = config.port || 3000;    // 0 → 3000 ❌
const name = config.name || 'app';   // '' → 'app' ❌
const debug = config.debug || true;  // false → true ❌
```

✅ **Satisfies — correct modern operators:**
```javascript
const config = { port: 0, name: '', debug: false };

// ?? — only null/undefined triggers fallback ✅
const port = config.port ?? 3000;    // 0 → 0 ✅
const name = config.name ?? 'app';   // '' → '' ✅
const debug = config.debug ?? true;  // false → false ✅

// ?. — safe property access
const user = null;
const city = user?.address?.city;         // undefined ✅ (no TypeError)
const len = user?.name?.length ?? 0;      // 0 ✅
user?.save?.();                           // safe method call ✅
const val = arr?.[0]?.property;           // safe array access ✅

// Logical assignment
let cache = null;
cache ??= new Map();          // assign if null/undefined ✅

let count = 0;
count ||= 10;                 // assign if falsy — 0 → 10 (careful!) ✅

let enabled = getUser();
enabled &&= formatUser(enabled); // transform if truthy ✅

// Practical: initialize nested config
function initConfig(options = {}) {
  options.timeout ??= 5000;
  options.retries ??= 3;
  options.verbose ??= false;
  return options;
}
```

---

## 7.9 structuredClone

### Q69. What is structuredClone? What can and cannot it clone?

**Answer:**
`structuredClone()` (available since Chrome 98, Node 17) performs a deep clone using the structured clone algorithm. It handles circular references, Date objects, RegExp, Map, Set, ArrayBuffer, and more — unlike `JSON.parse(JSON.stringify())` which loses Dates (converts to strings), `undefined`, functions, and fails on circular references. It cannot clone: functions, class instances' methods (only own data properties), DOM nodes, and Proxy objects.

❌ **Violates — JSON deep clone with lossy behavior:**
```javascript
const data = {
  date: new Date(),           // becomes string after JSON ❌
  fn: () => 'hello',         // lost after JSON ❌
  undef: undefined,          // lost after JSON ❌
  set: new Set([1, 2]),      // becomes {} after JSON ❌
  map: new Map([['a', 1]])   // becomes {} after JSON ❌
};

const clone = JSON.parse(JSON.stringify(data));
console.log(clone.date instanceof Date); // false — it's a string ❌
console.log(clone.fn);                  // undefined — lost ❌
console.log(clone.set);                 // {} — not a Set ❌
```

✅ **Satisfies — structuredClone:**
```javascript
// structuredClone — deep copy preserving types ✅
const data = {
  date: new Date(),
  set: new Set([1, 2, 3]),
  map: new Map([['key', 'value']]),
  arr: [1, [2, [3]]],
  buffer: new ArrayBuffer(8)
};

const clone = structuredClone(data);
console.log(clone.date instanceof Date);   // true ✅
console.log(clone.set instanceof Set);     // true ✅
console.log(clone.map instanceof Map);     // true ✅
console.log(clone.arr !== data.arr);       // true — deep copy ✅

// Handles circular references ✅
const circular = { name: 'circular' };
circular.self = circular;
const cloneCirc = structuredClone(circular); // works! ✅

// What structuredClone CANNOT clone:
const withFn = { fn: () => 'hello' };
// structuredClone(withFn); // DataCloneError ❌

// Class instances — only own data, not methods
class Point { constructor(x, y) { this.x = x; this.y = y; } move() {} }
const p = new Point(1, 2);
const cp = structuredClone(p);
console.log(cp.x, cp.y);                // 1, 2 ✅ (data preserved)
console.log(cp instanceof Point);       // false ❌ (just plain object)
console.log(cp.move);                   // undefined ❌ (no methods)
```

---

## 7.10 Modern Array Methods

### Q70. What are flat, flatMap, Array.from, findLast, at(), toSorted, and toReversed?

**Answer:**
`flat(depth)` flattens nested arrays. `flatMap` maps then flattens one level — more efficient than `.map().flat()`. `Array.from` converts iterables/array-likes to arrays. `findLast`/`findLastIndex` search from the end. `at()` supports negative indexing. `toSorted`/`toReversed`/`toSpliced`/`with` (ES2023) are non-mutating versions of sort/reverse/splice/bracket-assignment.

❌ **Violates — mutating arrays unexpectedly and verbose alternatives:**
```javascript
// sort() mutates the original array ❌
const arr = [3, 1, 2];
const sorted = arr.sort(); // arr is now [1, 2, 3] — mutated! ❌
console.log(arr); // [1, 2, 3] — original changed ❌

// Last element the hard way ❌
const last = arr[arr.length - 1]; // verbose ❌

// Manual flatten ❌
const nested = [[1, 2], [3, 4]];
const flat = [].concat(...nested); // works but verbose ❌
```

✅ **Satisfies — modern array methods:**
```javascript
// flat — flatten nested arrays
const nested = [1, [2, [3, [4]]]];
nested.flat();    // [1, 2, [3, [4]]] — one level ✅
nested.flat(2);   // [1, 2, 3, [4]] — two levels ✅
nested.flat(Infinity); // [1, 2, 3, 4] — fully flat ✅

// flatMap — map + flat(1) — more efficient
const sentences = ['Hello World', 'Foo Bar'];
sentences.flatMap(s => s.split(' ')); // ['Hello', 'World', 'Foo', 'Bar'] ✅

// Array.from
Array.from('hello');             // ['h', 'e', 'l', 'l', 'o'] ✅
Array.from({ length: 5 }, (_, i) => i); // [0, 1, 2, 3, 4] ✅
Array.from(new Set([1, 2, 3])); // [1, 2, 3] ✅
Array.from(document.querySelectorAll('div')); // NodeList → Array ✅

// at() — negative indexing
const arr = [1, 2, 3, 4, 5];
arr.at(-1);  // 5 ✅
arr.at(-2);  // 4 ✅

// findLast / findLastIndex
arr.findLast(x => x % 2 === 0);      // 4 ✅
arr.findLastIndex(x => x % 2 === 0); // 3 ✅

// Non-mutating sort/reverse (ES2023)
const original = [3, 1, 2];
const sorted = original.toSorted();   // [1, 2, 3] — new array ✅
console.log(original);                // [3, 1, 2] — unchanged ✅

const reversed = original.toReversed(); // [2, 1, 3] ✅
const updated = original.with(1, 99);   // [3, 99, 2] — replace at index ✅
```

---

# 8. Arrays & Objects

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array
> 📚 Medium: https://medium.com/javascript-scene/reduce-composing-software-fe22f0c39a1d

---

## 8.1 map vs filter vs reduce

### Q71. When should you use map, filter, and reduce? Can reduce replace them both?

**Answer:**
`map` transforms each element, returning an array of the same length. `filter` selects elements, returning a shorter or equal length array. `reduce` accumulates all elements into a single output value (which can itself be an array or object). `reduce` is the most general — it can implement `map` and `filter` — but using them specifically is more readable and more intent-revealing. Chain them for expressive data pipelines.

❌ **Violates — wrong method for the task:**
```javascript
const nums = [1, 2, 3, 4, 5];

// Using reduce when map is clearer ❌
const doubled = nums.reduce((acc, n) => [...acc, n * 2], []); // verbose ❌

// Using map when filter is needed ❌
const evens = nums.map(n => n % 2 === 0 ? n : null).filter(Boolean); // unnecessarily complex ❌

// Forgetting initial value in reduce ❌
const sum = [].reduce((a, b) => a + b); // TypeError on empty array ❌
```

✅ **Satisfies — right tool for each task:**
```javascript
const nums = [1, 2, 3, 4, 5];

// map — transform each element ✅
const doubled = nums.map(n => n * 2); // [2, 4, 6, 8, 10]

// filter — select elements ✅
const evens = nums.filter(n => n % 2 === 0); // [2, 4]

// reduce — accumulate ✅
const sum = nums.reduce((acc, n) => acc + n, 0); // 15

// Chain: sum of doubled evens
const result = nums
  .filter(n => n % 2 === 0)
  .map(n => n * 2)
  .reduce((acc, n) => acc + n, 0); // 12 ✅

// reduce as map
const mapViaReduce = (arr, fn) =>
  arr.reduce((acc, item) => [...acc, fn(item)], []);

// reduce as filter
const filterViaReduce = (arr, pred) =>
  arr.reduce((acc, item) => pred(item) ? [...acc, item] : acc, []);

// reduce for grouping (common interview pattern)
const people = [
  { name: 'Alice', dept: 'Eng' },
  { name: 'Bob', dept: 'Eng' },
  { name: 'Carol', dept: 'Design' }
];
const byDept = people.reduce((acc, p) => {
  (acc[p.dept] ??= []).push(p);
  return acc;
}, {}); // { Eng: [...], Design: [...] } ✅
```

---

## 8.2 find vs findIndex vs some vs every vs includes

### Q72. When should you use find, findIndex, some, every, and includes?

**Answer:**
`find` returns the first element matching a predicate (or `undefined`). `findIndex` returns its index (or -1). `some` returns `true` if any element matches. `every` returns `true` if all elements match. `includes` checks for exact value with `===` (uses SameValueZero, so works with `NaN`). Use `some`/`every` for boolean checks; `find`/`findIndex` when you need the element or position.

❌ **Violates — using the wrong method:**
```javascript
const users = [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }];

// indexOf for objects — always -1 ❌
users.indexOf({ id: 1, name: 'Alice' }); // -1 — different reference ❌

// filter when find is intended ❌
const user = users.filter(u => u.id === 1)[0]; // returns array, then [0] ❌

// some with wrong return usage ❌
const result = users.some(u => u.name); // always true if any name exists — wrong predicate ❌
```

✅ **Satisfies — correct use of each:**
```javascript
const nums = [1, 2, 3, 4, 5];
const users = [{ id: 1, active: true }, { id: 2, active: false }];

// find — first match or undefined ✅
nums.find(n => n > 3);              // 4
users.find(u => u.id === 2);        // { id: 2, active: false }

// findIndex — index or -1 ✅
nums.findIndex(n => n > 3);         // 3

// some — any match? ✅
nums.some(n => n > 4);              // true
users.some(u => u.active);          // true

// every — all match? ✅
nums.every(n => n > 0);             // true
users.every(u => u.active);         // false

// includes — value check (SameValueZero) ✅
nums.includes(3);                   // true
[NaN].includes(NaN);                // true! (unlike ===) ✅
[NaN].indexOf(NaN);                 // -1 (indexOf uses ===) ❌

// includes with objects — reference check
const obj = { id: 1 };
[obj].includes(obj);                // true — same reference ✅
[obj].includes({ id: 1 });          // false — different reference ✅

// Decision tree:
// Need the element itself? → find
// Need the position? → findIndex
// Need boolean "does any match"? → some
// Need boolean "do all match"? → every
// Need boolean "is this exact value present"? → includes
```

---

## 8.3 Sorting

### Q73. How does Array.sort() work by default? How do you sort correctly and what is stable sort?

**Answer:**
`Array.sort()` with no comparator sorts elements as **strings** by default — `[10, 9, 2].sort()` gives `[10, 2, 9]` (lexicographic). For numeric sort, pass `(a, b) => a - b`. A comparator returning negative means "a before b", positive means "b before a", zero means equal. Since ES2019, the spec requires sort to be **stable** — equal elements maintain their relative order. V8 and all modern engines implement stable sort.

❌ **Violates — default sort for numbers:**
```javascript
const nums = [10, 9, 2, 100, 21];
nums.sort(); // [10, 100, 2, 21, 9] — lexicographic ❌

const people = [
  { name: 'Charlie', age: 30 },
  { name: 'Alice', age: 25 },
  { name: 'Bob', age: 25 }
];
// Sort by age — unstable in old engines could reorder Alice/Bob ❌
people.sort((a, b) => a.age - b.age);
```

✅ **Satisfies — correct sorting:**
```javascript
// Numeric sort ✅
const nums = [10, 9, 2, 100, 21];
nums.sort((a, b) => a - b); // [2, 9, 10, 21, 100] ascending ✅
nums.sort((a, b) => b - a); // descending ✅

// String sort ✅
const words = ['banana', 'apple', 'cherry'];
words.sort((a, b) => a.localeCompare(b)); // locale-aware ✅

// Object sort by property ✅
const people = [
  { name: 'Charlie', age: 30 },
  { name: 'Alice', age: 25 },
  { name: 'Bob', age: 25 }
];
people.sort((a, b) => a.age - b.age);
// Alice and Bob maintain relative order (stable) ✅

// Multi-key sort
people.sort((a, b) => {
  const ageDiff = a.age - b.age;
  return ageDiff !== 0 ? ageDiff : a.name.localeCompare(b.name); // age, then name ✅
});

// Non-mutating sort (ES2023)
const sorted = people.toSorted((a, b) => a.age - b.age);
// people unchanged ✅

// Custom sort order
const priority = ['high', 'medium', 'low'];
const tasks = ['low', 'high', 'medium', 'high'];
tasks.sort((a, b) => priority.indexOf(a) - priority.indexOf(b));
// ['high', 'high', 'medium', 'low'] ✅
```

---

## 8.4 Object Methods

### Q74. What do Object.keys, values, entries, assign, freeze, seal, and preventExtensions do?

**Answer:**
`Object.keys/values/entries` return arrays of own enumerable string-keyed properties. `Object.assign` copies own enumerable properties (shallow). `Object.freeze` prevents all changes — no add, delete, or modify. `Object.seal` prevents add/delete but allows modifying existing values. `Object.preventExtensions` only prevents adding new properties. None of these are deep — nested objects are still mutable unless explicitly handled.

❌ **Violates — thinking freeze is deep:**
```javascript
const config = Object.freeze({
  db: { host: 'localhost', port: 5432 }
});

config.newProp = 'x';    // silently fails ✅ (blocked)
config.db.host = 'evil'; // SUCCEEDS — freeze is shallow ❌
console.log(config.db.host); // 'evil' ❌
```

✅ **Satisfies — object methods correctly used:**
```javascript
const obj = { a: 1, b: 2, c: 3 };

// Enumeration
Object.keys(obj);    // ['a', 'b', 'c'] ✅
Object.values(obj);  // [1, 2, 3] ✅
Object.entries(obj); // [['a',1], ['b',2], ['c',3]] ✅

// entries → Map
const map = new Map(Object.entries(obj));

// fromEntries — inverse of entries
const obj2 = Object.fromEntries([['x', 1], ['y', 2]]); // { x: 1, y: 2 } ✅

// assign — shallow merge, mutates target
const merged = Object.assign({}, { a: 1 }, { b: 2 }); // { a: 1, b: 2 } ✅

// freeze — no mutations allowed (shallow)
const frozen = Object.freeze({ x: 1, nested: { y: 2 } });
// frozen.x = 99;        // silently fails (TypeError in strict mode)
frozen.nested.y = 99; // still works — shallow! ❌

// Deep freeze
function deepFreeze(obj) {
  Object.values(obj).forEach(v => {
    if (typeof v === 'object' && v !== null) deepFreeze(v);
  });
  return Object.freeze(obj);
}

// seal — no add/delete, but can modify
const sealed = Object.seal({ name: 'Alice', age: 30 });
sealed.name = 'Bob'; // works ✅
// sealed.email = 'x'; // fails — can't add ✅

// preventExtensions — can only prevent new properties
const limited = Object.preventExtensions({ x: 1 });
// limited.y = 2; // fails ✅
limited.x = 99;  // works ✅
delete limited.x; // works ✅
```

---

## 8.5 Deep Copy vs Shallow Copy

### Q75. What is the difference between shallow and deep copy? When does each approach fail?

**Answer:**
A shallow copy copies the top-level properties but nested objects are still shared references. A deep copy creates completely independent copies of all nested structures. Spread and `Object.assign` are shallow. `JSON.parse(JSON.stringify())` is a deep copy but loses functions, `undefined`, `Date` (becomes string), `Map`, `Set`, and circular references. `structuredClone` is the modern deep copy solution handling most types.

❌ **Violates — shallow copy causing shared state bugs:**
```javascript
const original = { name: 'Alice', scores: [90, 85, 92] };
const copy = { ...original }; // shallow copy ❌

copy.scores.push(100); // modifies the SAME array ❌
console.log(original.scores); // [90, 85, 92, 100] — original mutated! ❌

// JSON fails on special types ❌
const data = {
  date: new Date(),
  fn: () => 'hello',
  map: new Map([['a', 1]])
};
const jsonCopy = JSON.parse(JSON.stringify(data));
jsonCopy.date instanceof Date; // false — converted to string ❌
jsonCopy.fn;   // undefined — lost ❌
jsonCopy.map;  // {} — not a Map ❌
```

✅ **Satisfies — choosing the right copy method:**
```javascript
const original = { name: 'Alice', scores: [90, 85], meta: { active: true } };

// Shallow copy — only works for flat objects
const shallow = { ...original };

// Deep copy options:

// 1. structuredClone (modern, recommended) ✅
const deep1 = structuredClone(original);
deep1.scores.push(100);
console.log(original.scores); // [90, 85] — unchanged ✅

// 2. JSON (simple, but lossy)
const deep2 = JSON.parse(JSON.stringify(original));
// Works for plain data — fails for Date, Map, Set, functions ❌

// 3. Manual recursive deep clone (educational)
function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (obj instanceof Date) return new Date(obj);
  if (obj instanceof Map) return new Map([...obj].map(([k, v]) => [deepClone(k), deepClone(v)]));
  if (obj instanceof Set) return new Set([...obj].map(deepClone));
  if (Array.isArray(obj)) return obj.map(deepClone);
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) => [k, deepClone(v)])
  );
}

// Quick reference:
// spread/assign → shallow, fast, no special types
// structuredClone → deep, handles most types, no functions
// JSON → deep, lossy (no Date/Map/Set/fn/undefined), handles simple data
// custom → deep, handles anything you code for
```

---

## 8.6 Array Destructuring Tricks

### Q76. What are advanced array destructuring patterns for swapping, skipping, and default values?

**Answer:**
Array destructuring by position enables powerful one-liners. Variables can be swapped without a temp variable using `[a, b] = [b, a]`. Elements can be skipped with consecutive commas. Default values prevent `undefined` for missing elements. Combined with rest, you can split arrays into head/tail.

❌ **Violates — verbose array manipulation:**
```javascript
// Swapping with temp variable ❌
let a = 1, b = 2;
const temp = a;
a = b;
b = temp;

// Manual array split ❌
const arr = [1, 2, 3, 4, 5];
const first = arr[0];
const rest = arr.slice(1);

// No default for missing elements ❌
const [x, y, z] = [1, 2];
z; // undefined — no default ❌
```

✅ **Satisfies — advanced destructuring tricks:**
```javascript
// Swap without temp ✅
let a = 1, b = 2;
[a, b] = [b, a];
console.log(a, b); // 2, 1 ✅

// Skip elements with commas
const [first, , third, , fifth] = [1, 2, 3, 4, 5];
console.log(first, third, fifth); // 1, 3, 5 ✅

// Default values
const [x = 0, y = 0, z = 0] = [1, 2];
console.log(z); // 0 — default applied ✅

// Head and tail
const [head, ...tail] = [1, 2, 3, 4, 5];
console.log(head, tail); // 1, [2, 3, 4, 5] ✅

// Nested array destructuring
const matrix = [[1, 2], [3, 4]];
const [[a1, a2], [b1, b2]] = matrix;
console.log(a1, b2); // 1, 4 ✅

// From function return
function getCoords() { return [10, 20]; }
const [x2, y2] = getCoords(); ✅

// With iterables
const [first2, second2] = new Set([1, 2, 3]);
console.log(first2, second2); // 1, 2 ✅

// Regex match destructuring
const [, year, month, day] = '2024-05-26'.match(/(\d{4})-(\d{2})-(\d{2})/);
console.log(year, month, day); // '2024' '05' '26' ✅
```

---

## 8.7 Computed Property Names

### Q77. How do computed property names work in object literals?

**Answer:**
ES6 allows dynamic property keys in object literals using square bracket syntax `[expression]`. The expression is evaluated at runtime and the result is used as the key name. This enables creating objects with dynamic keys from variables, function calls, or template literals without a separate assignment step.

❌ **Violates — separate assignment for dynamic keys:**
```javascript
// Pre-ES6 pattern — verbose ❌
function createField(name, value) {
  const obj = {};
  obj[name] = value; // separate step ❌
  return obj;
}

// Can't use dynamic keys in object literal ❌
const key = 'name';
const obj = { key: 'Alice' }; // creates key 'key', not 'name' ❌
```

✅ **Satisfies — computed property names:**
```javascript
const field = 'name';
const index = 3;

// Dynamic key from variable ✅
const obj = { [field]: 'Alice' }; // { name: 'Alice' } ✅

// Expression as key ✅
const obj2 = {
  [`item_${index}`]: 'value',         // 'item_3'
  [Symbol.iterator]: function*() {},  // Symbol key ✅
  [`${field}Upper`]: 'ALICE'          // 'nameUpper'
};

// Factory pattern
function createAction(type) {
  return {
    [type]: (payload) => ({ type, payload }),  // dynamic method name ✅
    [`${type}Success`]: (data) => ({ type: `${type}_SUCCESS`, data })
  };
}

// Computed keys in destructuring
const key2 = 'age';
const { [key2]: age } = { age: 30, name: 'Bob' };
console.log(age); // 30 ✅

// Enum-like pattern
const ACTION = {
  ['INCREMENT']: 'INCREMENT',
  ['DECREMENT']: 'DECREMENT'
};
```

---

## 8.8 Property and Method Shorthand

### Q78. What are ES6 object literal shorthands and how do they improve code?

**Answer:**
ES6 introduced two shorthands: **property shorthand** — when variable name matches key, write just the variable: `{ name }` instead of `{ name: name }`. **Method shorthand** — omit `function` keyword: `{ greet() {} }` instead of `{ greet: function() {} }`. Method shorthand creates non-enumerable methods and can use `super`, unlike the function expression form.

❌ **Violates — verbose object creation:**
```javascript
const name = 'Alice';
const age = 30;
const email = 'alice@example.com';

// Verbose repetition ❌
const user = {
  name: name,
  age: age,
  email: email,
  greet: function() {            // verbose ❌
    return `Hi, ${this.name}`;
  },
  toString: function() {         // verbose ❌
    return `${this.name} (${this.age})`;
  }
};
```

✅ **Satisfies — ES6 shorthands:**
```javascript
const name = 'Alice';
const age = 30;
const email = 'alice@example.com';

// Property shorthand ✅
const user = {
  name,     // same as name: name ✅
  age,
  email,

  // Method shorthand ✅
  greet() {
    return `Hi, ${this.name}`;
  },

  // Computed + shorthand
  toString() {
    return `${this.name} (${this.age})`;
  },

  // Getter/setter shorthand
  get initials() {
    return this.name.split(' ').map(w => w[0]).join('');
  }
};

// In function returns
function createPoint(x, y) {
  return { x, y }; // shorthand ✅
}

// Destructuring + shorthand in function params
function connect({ host = 'localhost', port = 3000 } = {}) {
  return { host, port, connected: true }; // ✅
}

// ES2015+ class method syntax is also shorthand
class Animal {
  speak() {}  // shorthand for speak: function() {}
}
```

---

## 8.9 for...of vs for...in vs forEach vs for

### Q79. What are the differences between for...of, for...in, forEach, and regular for loops?

**Answer:**
`for` loop: most flexible, works with `break`/`continue`/`return`, best for index-based access. `for...of`: iterates values of any iterable, works with `break`/`continue`, handles async with `await`. `for...in`: iterates enumerable property keys (own + inherited) — almost never use on arrays. `forEach`: functional, no `break`/`continue`/`return` to outer scope, does not work with `await` (no sequential async).

❌ **Violates — forEach with async/await and for...in on arrays:**
```javascript
// forEach doesn't await — all run in parallel ❌
async function processAll(items) {
  items.forEach(async (item) => {
    await processItem(item); // not awaited by forEach ❌
  });
  // returns before processing completes ❌
}

// for...in on array — includes prototype and non-index props ❌
Array.prototype.customMethod = function() {};
const arr = [1, 2, 3];
for (const key in arr) {
  console.log(key); // '0', '1', '2', 'customMethod' ❌
}
```

✅ **Satisfies — right loop for the right task:**
```javascript
const arr = [1, 2, 3, 4, 5];

// for — index control, break/continue, performance ✅
for (let i = 0; i < arr.length; i++) {
  if (arr[i] === 3) break; // ✅
  console.log(arr[i]);
}

// for...of — values, break/continue, async ✅
for (const val of arr) {
  if (val === 3) continue; // ✅
  console.log(val);
}

// for...of with index (entries)
for (const [i, val] of arr.entries()) {
  console.log(i, val); // ✅
}

// forEach — functional, no break, sync only ✅
arr.forEach((val, i) => {
  console.log(i, val);
});

// for...in — only for object keys ✅
const obj = { a: 1, b: 2 };
for (const key in obj) {
  if (Object.hasOwn(obj, key)) { // filter inherited ✅
    console.log(key, obj[key]);
  }
}

// Async sequential — use for...of, NOT forEach ✅
async function processSequential(items) {
  for (const item of items) {
    await processItem(item); // awaited correctly ✅
  }
}
```

---

## 8.10 Array-like Objects

### Q80. What are array-like objects and how do you convert them to real arrays?

**Answer:**
Array-like objects have a `length` property and indexed elements but lack array methods like `map`, `filter`, and `reduce`. Examples: `arguments`, `NodeList` (from `querySelectorAll`), `HTMLCollection`, `String`. Convert them to real arrays with `Array.from()`, spread `[...arrayLike]`, or `Array.prototype.slice.call(arrayLike)` (old way). Once converted, all array methods are available.

❌ **Violates — calling array methods on array-likes:**
```javascript
function sum() {
  return arguments.reduce((a, b) => a + b); // TypeError — arguments is not an array ❌
}

const divs = document.querySelectorAll('div');
divs.map(el => el.textContent); // TypeError — NodeList has no map ❌

// Old conversion approach — verbose ❌
const arr = Array.prototype.slice.call(arguments); // works but ugly ❌
```

✅ **Satisfies — array-like to array conversion:**
```javascript
// arguments → array
function sum() {
  return Array.from(arguments).reduce((a, b) => a + b, 0); ✅
  // Better: use rest params instead
}
function sumRest(...nums) {
  return nums.reduce((a, b) => a + b, 0); // nums is already an Array ✅
}

// NodeList → array ✅
const divs = document.querySelectorAll('div');
const divArray = Array.from(divs);           // ✅
const divArray2 = [...divs];                 // ✅ (spread works on iterables)
divArray.map(el => el.textContent);          // ✅

// Array.from with mapping function
const inputs = document.querySelectorAll('input');
const values = Array.from(inputs, input => input.value); // ✅

// String — array-like and iterable
Array.from('hello');  // ['h','e','l','l','o'] ✅
[...'hello'];         // ['h','e','l','l','o'] ✅ — handles Unicode!
'hello'.split('');    // ['h','e','l','l','o'] ❌ — breaks on emoji

// Custom array-like
const arrayLike = { 0: 'a', 1: 'b', 2: 'c', length: 3 };
Array.from(arrayLike); // ['a', 'b', 'c'] ✅

// Check if something is array-like
function isArrayLike(obj) {
  return obj != null && typeof obj.length === 'number' && obj.length >= 0;
}
```

---

# 9. Error Handling & Debugging

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Control_flow_and_error_handling
> 📚 Medium: https://medium.com/javascript-scene/javascript-error-handling-best-practices-a3d64ad30e68

---

## 9.1 try/catch/finally

### Q81. How does try/catch/finally execution flow work? What always runs?

**Answer:**
Code in `try` runs normally. If any exception is thrown, execution jumps to `catch` (skipping remaining `try` code). `finally` always executes regardless of whether an error occurred or not — even if `try` has a `return` or `throw`, `finally` runs first. If `finally` contains a `return`, it overrides the `try`'s return value. `catch` is optional if `finally` is present.

❌ **Violates — unexpected finally behavior:**
```javascript
function tricky() {
  try {
    return 'try';
  } finally {
    return 'finally'; // overrides try's return ❌ (surprising!)
  }
}
console.log(tricky()); // 'finally' — not 'try' ❌

// Forgetting to re-throw when needed ❌
function getData() {
  try {
    return fetchData();
  } catch (err) {
    console.log(err); // logs but swallows — caller has no idea ❌
  }
}
```

✅ **Satisfies — correct try/catch/finally:**
```javascript
// Basic flow
function divide(a, b) {
  try {
    if (b === 0) throw new RangeError('Cannot divide by zero');
    return a / b;
  } catch (err) {
    if (err instanceof RangeError) {
      console.warn('Math error:', err.message);
      return Infinity; // recover ✅
    }
    throw err; // re-throw unknown errors ✅
  } finally {
    console.log('divide() completed'); // always runs ✅
  }
}

// Resource cleanup with finally
async function withDB(fn) {
  const connection = await db.connect();
  try {
    return await fn(connection);
  } catch (err) {
    await connection.rollback();
    throw err; // re-throw after cleanup ✅
  } finally {
    await connection.close(); // always release connection ✅
  }
}

// try/finally without catch (let errors propagate, but always clean up)
function withLock(lock, fn) {
  lock.acquire();
  try {
    return fn();
  } finally {
    lock.release(); // always release ✅
  }
}
```

---

## 9.2 Error Types

### Q82. What are JavaScript's built-in error types? When does each get thrown?

**Answer:**
`Error` is the base type. `TypeError` is thrown when a value is not of the expected type (calling non-function, accessing property of null). `ReferenceError` when a variable doesn't exist. `SyntaxError` for invalid code (parse time). `RangeError` when a value is out of allowed range (`new Array(-1)`). `URIError` for malformed URI. `EvalError` is rarely thrown now. All extend `Error` and have `message` and `stack` properties.

❌ **Violates — throwing and catching undifferentiated errors:**
```javascript
// Throwing strings instead of Error objects ❌
throw 'Something went wrong'; // string has no stack trace ❌

// Catching all errors the same way ❌
try {
  riskyOperation();
} catch (err) {
  console.log(err); // no type check — treats network error same as bug ❌
}
```

✅ **Satisfies — using correct error types:**
```javascript
// Common error types and when they occur
try {
  null.property;       // TypeError ✅
} catch (e) { console.log(e instanceof TypeError); } // true

try {
  undeclaredVar;       // ReferenceError ✅
} catch (e) { console.log(e instanceof ReferenceError); } // true

try {
  new Array(-1);       // RangeError ✅
} catch (e) { console.log(e instanceof RangeError); } // true

// Differentiating error types in catch
async function loadData(url) {
  try {
    const res = await fetch(url);
    return await res.json();
  } catch (err) {
    if (err instanceof TypeError) {
      throw new Error(`Network error: ${err.message}`); // wrapping ✅
    }
    if (err instanceof SyntaxError) {
      throw new Error(`Invalid JSON from ${url}`); ✅
    }
    throw err; // unknown — re-throw ✅
  }
}

// Error properties
const err = new TypeError('Expected a string');
console.log(err.name);    // 'TypeError'
console.log(err.message); // 'Expected a string'
console.log(err.stack);   // stack trace string ✅
```

---

## 9.3 Custom Error Classes

### Q83. How do you create custom error classes? How does instanceof work with them?

**Answer:**
Extend the `Error` class to create semantic custom errors. Set the `name` property to the class name for stack trace readability. Custom errors can have additional properties for structured error data. `instanceof` works correctly with custom error classes as long as the chain is maintained. Avoid overriding `stack` manually.

❌ **Violates — generic errors with string messages:**
```javascript
// Generic Error with context baked into message string ❌
throw new Error(`Validation failed: field "email" must be a valid email address`);
// Caller can't programmatically extract field name or error type ❌
```

✅ **Satisfies — custom error classes:**
```javascript
// Base app error
class AppError extends Error {
  constructor(message, code, statusCode = 500) {
    super(message);
    this.name = this.constructor.name; // 'AppError'
    this.code = code;
    this.statusCode = statusCode;
    // Fix stack trace in V8
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

// Specific errors
class ValidationError extends AppError {
  constructor(field, message) {
    super(`Validation failed for "${field}": ${message}`, 'VALIDATION_ERROR', 400);
    this.field = field;
  }
}

class NotFoundError extends AppError {
  constructor(resource, id) {
    super(`${resource} with id "${id}" not found`, 'NOT_FOUND', 404);
    this.resource = resource;
    this.id = id;
  }
}

// Usage
function getUser(id) {
  const user = db.find(id);
  if (!user) throw new NotFoundError('User', id);
  return user;
}

// Type-safe catch
try {
  getUser(999);
} catch (err) {
  if (err instanceof NotFoundError) {
    res.status(404).json({ error: err.message, resource: err.resource }); // ✅
  } else if (err instanceof ValidationError) {
    res.status(400).json({ error: err.message, field: err.field }); // ✅
  } else {
    throw err; // unknown ✅
  }
}
```

---

## 9.4 Async Error Handling

### Q84. What are the patterns for error handling in async code? When use try/catch vs .catch()?

**Answer:**
Both `try/catch` with `await` and `.catch()` handle Promise rejections. `try/catch` is cleaner when handling multiple awaits together. `.catch()` is cleaner for single chains and allows recovery by returning a fallback value. Mixing both in the same call is redundant. Always handle rejections — unhandled rejections will crash Node.js in future versions and throw in browsers.

❌ **Violates — redundant error handling and swallowed errors:**
```javascript
// Double-handling — redundant ❌
async function fetchData() {
  try {
    return await fetch('/api').catch(err => { throw err; }); // pointless .catch ❌
  } catch (err) {
    console.log(err);
  }
}

// Promise chain without final .catch ❌
fetch('/api/data')
  .then(r => r.json())
  .then(processData); // no .catch — unhandled rejection ❌
```

✅ **Satisfies — clean async error handling:**
```javascript
// try/catch for multiple operations ✅
async function processUser(id) {
  try {
    const user = await getUser(id);       // any of these can throw
    const orders = await getOrders(user);
    const result = await processOrders(orders);
    return result;
  } catch (err) {
    logger.error('processUser failed', { id, err });
    throw new AppError('Processing failed', 'PROCESS_ERROR');
  }
}

// .catch() for single chains and recovery ✅
const data = await fetch('/api/data')
  .then(res => res.json())
  .catch(() => ({ default: true })); // fallback on error ✅

// Granular error handling for specific steps
async function load() {
  const user = await getUser().catch(err => {
    if (err instanceof NotFoundError) return null; // handle specifically ✅
    throw err; // re-throw others
  });

  if (!user) return null;
  return user;
}

// Async error in event handlers — must handle explicitly
element.addEventListener('click', async (e) => {
  try {
    await handleClick(e);
  } catch (err) {
    showError(err); // event handlers don't propagate async errors ✅
  }
});
```

---

## 9.5 Global Error Handlers

### Q85. How do you set up global error handlers for uncaught errors and unhandled promise rejections?

**Answer:**
`window.onerror` catches uncaught synchronous errors (runtime errors that escape all try/catch). `window.addEventListener('unhandledrejection')` catches Promise rejections that have no `.catch()`. In Node.js, use `process.on('uncaughtException')` and `process.on('unhandledRejection')`. These are last-resort handlers for logging — not for recovery. Always try to handle errors where they occur.

❌ **Violates — no global safety net and no distinction:**
```javascript
// No global handler — errors silently fail or show browser default ❌
// Users see a broken page with no feedback ❌

// process.exit in uncaughtException without cleanup ❌
process.on('uncaughtException', (err) => {
  console.error(err);
  process.exit(1); // no graceful shutdown ❌
});
```

✅ **Satisfies — proper global error handling:**
```javascript
// Browser: catch all runtime errors
window.onerror = function(message, source, lineno, colno, error) {
  errorReporter.send({
    message,
    source,
    line: lineno,
    column: colno,
    stack: error?.stack
  });
  return false; // false = show browser's default behavior too
};

// Browser: catch unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
  errorReporter.send({
    type: 'UnhandledPromiseRejection',
    reason: event.reason,
    stack: event.reason?.stack
  });
  event.preventDefault(); // prevent console error in some browsers
});

// Node.js
process.on('uncaughtException', (err, origin) => {
  logger.fatal({ err, origin }, 'Uncaught exception');
  // Graceful shutdown — allow current requests to finish
  server.close(() => process.exit(1)); ✅
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error({ reason, promise }, 'Unhandled rejection');
  // In Node 15+, this crashes by default — which is correct behavior ✅
});

// Track error rate — if too high, something is fundamentally wrong
let errorCount = 0;
window.addEventListener('unhandledrejection', () => {
  errorCount++;
  if (errorCount > 10) {
    showMaintenanceBanner(); // ✅
  }
});
```

---

## 9.6 console Methods

### Q86. What are the different console methods and when should you use each?

**Answer:**
`console.log` is for general output. `console.warn` for non-critical issues (yellow). `console.error` for errors (red, includes stack trace in some envs). `console.table` renders arrays/objects as tables. `console.group`/`groupEnd` indents related logs. `console.time`/`timeEnd` measures elapsed time. `console.assert` logs only if the condition is false. `console.count` counts calls. `console.trace` prints a stack trace.

❌ **Violates — logging everything as console.log:**
```javascript
// All severity treated the same ❌
console.log('Error fetching data:', err); // should be error ❌
console.log('Warning: deprecated API used'); // should be warn ❌
console.log('Info: user logged in'); // ok ✅

// Manual timer ❌
const start = Date.now();
heavyOperation();
console.log('Time:', Date.now() - start); // verbose ❌
```

✅ **Satisfies — right console method for each purpose:**
```javascript
// Severity levels
console.log('User clicked button');          // info ✅
console.info('Server started on port 3000'); // same as log, semantic ✅
console.warn('Cache miss rate is high');     // warning ✅
console.error('Failed to connect to DB', err); // error + stack ✅

// console.table — great for arrays of objects
const users = [{ name: 'Alice', age: 30 }, { name: 'Bob', age: 25 }];
console.table(users); // renders as table ✅

// console.group — indent related logs
console.group('User Registration');
console.log('Validating...');
console.log('Creating account...');
console.groupEnd();

// console.time / timeEnd — named timer
console.time('sort');
largeArray.sort();
console.timeEnd('sort'); // 'sort: 23.456ms' ✅

// console.assert — only logs if false
console.assert(user.age >= 18, 'User must be adult', user); // ✅

// console.count
function handleClick() {
  console.count('click'); // click: 1, click: 2, etc. ✅
}

// console.trace — stack trace at any point
function debugging() {
  console.trace('Where am I called from?'); ✅
}

// console.dir — full object inspection (not toString)
console.dir(document.body, { depth: 2 }); ✅
```

---

## 9.7 Debugging Techniques

### Q87. What are effective debugging techniques using browser DevTools?

**Answer:**
Browser DevTools offer far more than `console.log`. Breakpoints pause execution at a line. Conditional breakpoints only pause when an expression is true. Logpoints log values without modifying source code. The call stack panel shows the execution path. Watch expressions evaluate at each pause. The Network panel shows request/response details. The Performance profiler reveals bottlenecks.

❌ **Violates — console.log only debugging:**
```javascript
// Spray-and-pray logging ❌
function process(data) {
  console.log('data', data);          // ❌
  console.log('step 1 done');         // ❌
  const result = transform(data);
  console.log('result', result);      // ❌ (all must be manually removed later)
  return result;
}
```

✅ **Satisfies — effective debugging strategies:**
```javascript
// 1. debugger statement — opens DevTools at this line
function suspiciousFunction(data) {
  debugger; // execution pauses here in DevTools ✅
  return process(data);
}

// 2. Conditional debugging — only break on bad state
function handleItem(item) {
  if (item.id === 42) debugger; // only pause for the problematic item ✅
  return item;
}

// 3. console.table for structured data
console.table(users.map(u => ({ id: u.id, name: u.name, active: u.active })));

// DevTools techniques (non-code):
// - Set breakpoint: click line number in Sources panel
// - Conditional breakpoint: right-click line → Add conditional breakpoint
// - Logpoint: right-click → Add logpoint (no code change needed) ✅
// - Watch expressions: add in right panel, evaluated on each pause
// - Call stack: see exactly how you got here
// - Scope variables: see all variables in current scope

// 4. console.trace for call origin
function whoCalledMe() {
  console.trace(); // prints current call stack ✅
}

// 5. Source maps: minified code maps to original source
// Ensure build tools output .map files for production debugging ✅

// 6. Network tab: check request URL, headers, payload, response
// Filter by XHR/Fetch for API calls ✅
```

---

## 9.8 Source Maps

### Q88. What are source maps and how do they help debug minified code?

**Answer:**
Source maps are files (`.map`) that map minified/transpiled code back to the original source code. When DevTools loads a page, it checks for source map references (`//# sourceMappingURL=`) and uses them to show original TypeScript/JSX/ES6+ code in the debugger instead of minified output. They contain JSON with mappings between positions in the minified output and positions in source files.

❌ **Violates — shipping without source maps and impossible debugging:**
```javascript
// Minified error stack (without source map) ❌:
// TypeError: Cannot read property 'x' of undefined
//     at a.b (main.min.js:1:2847)
//     at c (main.min.js:1:5291)
// Impossible to debug without source map ❌
```

✅ **Satisfies — source maps in practice:**
```javascript
// Source map anatomy (simplified JSON):
// {
//   "version": 3,
//   "sources": ["src/utils.js", "src/app.js"],
//   "sourcesContent": ["...original source code..."],
//   "mappings": "AAAA,SAAS,GAAG..." // VLQ encoded position mappings
// }

// webpack config — generate source maps ✅
// webpack.config.js
module.exports = {
  devtool: 'source-map',           // production: full source map
  // devtool: 'eval-source-map',   // development: inline, fast rebuild
  // devtool: 'hidden-source-map', // production: map exists but not referenced (for error reporting)
};

// Generated output includes reference:
// //# sourceMappingURL=main.js.map

// Sentry / error tracking with source maps ✅
// Upload maps to Sentry — errors show original line/column/file
// Never serve maps publicly in production if code is proprietary!

// Inline source maps (single file)
// //# sourceMappingURL=data:application/json;base64,...

// Check if source maps work:
// 1. Open DevTools → Sources panel
// 2. Look for original files alongside minified
// 3. Set breakpoint in original source — hits at correct minified position ✅
```

---

## 9.9 Performance Measurement

### Q89. How do you measure JavaScript performance using performance.now(), console.time(), and the Performance API?

**Answer:**
`performance.now()` returns a high-resolution timestamp in milliseconds (sub-millisecond precision) relative to page load. `console.time()`/`timeEnd()` is convenient for quick measurements. The Performance API (`performance.mark`, `performance.measure`) creates named marks and measures that appear in the browser's Performance profiler and can be collected programmatically. Use `performance.getEntriesByType` to query metrics.

❌ **Violates — using Date.now() for performance measurement:**
```javascript
// Date.now() is low resolution and subject to clock skew ❌
const start = Date.now();
doWork();
console.log('Time:', Date.now() - start, 'ms'); // millisecond precision only ❌

// Measuring async code incorrectly ❌
const t = performance.now();
fetch('/api').then(r => r.json()); // not awaited — measures nothing useful ❌
console.log(performance.now() - t); // 0 — async not included ❌
```

✅ **Satisfies — accurate performance measurement:**
```javascript
// performance.now — high resolution ✅
const start = performance.now();
doExpensiveWork();
const duration = performance.now() - start;
console.log(`Work took ${duration.toFixed(3)}ms`); // sub-millisecond ✅

// Async measurement ✅
async function measureAsync(fn, label) {
  const start = performance.now();
  await fn();
  const end = performance.now();
  console.log(`${label}: ${(end - start).toFixed(2)}ms`);
}

// Performance marks and measures (appears in DevTools profiler)
performance.mark('computation-start');
heavyComputation();
performance.mark('computation-end');
performance.measure('computation', 'computation-start', 'computation-end');

// Query measurements
const measures = performance.getEntriesByName('computation');
console.log(measures[0].duration); // ✅

// console.time — simple and readable
console.time('sort-100k');
largeArray.sort((a, b) => a - b);
console.timeEnd('sort-100k'); // 'sort-100k: 45.123ms' ✅

// PerformanceObserver — observe in real time
const observer = new PerformanceObserver((list) => {
  list.getEntries().forEach(entry => {
    console.log(entry.name, entry.duration);
  });
});
observer.observe({ entryTypes: ['measure', 'longtask'] }); // ✅
```

---

## 9.10 Memory Leaks

### Q90. What are common causes of JavaScript memory leaks and how do you detect them?

**Answer:**
Memory leaks occur when objects are kept in memory longer than needed. Common causes: unremoved event listeners, closures holding large scopes, detached DOM nodes still referenced in JavaScript, forgotten intervals/timeouts, accumulating data in global variables, and WeakRef misuse. Detect with Chrome DevTools: Heap Snapshot to see all objects, Allocation Timeline to track over time, and the Memory tab's retained size.

❌ **Violates — patterns that cause memory leaks:**
```javascript
// Event listener never removed — target and callback kept alive ❌
class Component {
  constructor() {
    document.addEventListener('resize', this.handleResize.bind(this));
    // If component is destroyed, listener keeps it in memory ❌
  }
}

// Interval never cleared ❌
function startPolling() {
  setInterval(() => fetchData(), 1000); // never stops even if unneeded ❌
}

// Detached DOM node held by JS ❌
let detached;
document.getElementById('btn').addEventListener('click', () => {
  detached = document.getElementById('heavy-element');
  detached.parentNode.removeChild(detached); // removed from DOM but JS holds reference ❌
});
```

✅ **Satisfies — leak-free patterns:**
```javascript
// Remove event listeners ✅
class Component {
  constructor() {
    this.handleResize = this.handleResize.bind(this);
    window.addEventListener('resize', this.handleResize);
  }

  destroy() {
    window.removeEventListener('resize', this.handleResize); // ✅
  }

  handleResize() { /* ... */ }
}

// AbortController for multiple listeners ✅
const controller = new AbortController();
document.addEventListener('click', handler, { signal: controller.signal });
document.addEventListener('keydown', handler2, { signal: controller.signal });
// Remove all at once:
controller.abort(); // ✅

// Clear intervals ✅
class Poller {
  start() {
    this.intervalId = setInterval(() => this.poll(), 1000);
  }
  stop() {
    clearInterval(this.intervalId); // ✅
  }
}

// Avoid retaining large objects in closures ✅
function processLargeData(data) {
  const result = data.map(transform);
  // Don't close over 'data' if not needed
  return () => result; // only closes over result, not data ✅
}

// DevTools: Heap snapshot workflow
// 1. Take baseline snapshot
// 2. Perform action suspected of leaking
// 3. Take second snapshot
// 4. Compare: look for growing counts/retained sizes ✅
```

---

# 10. Browser APIs & DOM

> 📚 Reference: https://developer.mozilla.org/en-US/docs/Web/API
> 📚 Medium: https://medium.com/javascript-scene/the-dom-api-for-beginners-a52e3e2e91a8

---

## 10.1 DOM Selection

### Q91. What are the differences between querySelector, getElementById, and getElementsByClassName? Live vs static NodeLists?

**Answer:**
`getElementById` is the fastest (direct hash lookup). `querySelector`/`querySelectorAll` accept CSS selectors — `querySelector` returns the first match, `querySelectorAll` returns a static `NodeList` (snapshot). `getElementsByClassName`/`getElementsByTagName` return **live** `HTMLCollection` — they update automatically when the DOM changes. Live collections in loops can cause infinite loops if elements are added during iteration.

❌ **Violates — live collection in loop causing issues:**
```javascript
// Live HTMLCollection in loop — dangerous ❌
const divs = document.getElementsByTagName('div'); // live ❌
for (let i = 0; i < divs.length; i++) {
  const clone = divs[i].cloneNode();
  document.body.appendChild(clone); // adds a div — divs.length grows! ❌
  // Potential infinite loop ❌
}
```

✅ **Satisfies — DOM selection best practices:**
```javascript
// getElementById — fastest, direct lookup ✅
const btn = document.getElementById('submit-btn');

// querySelector — CSS selector, returns first match, static ✅
const firstBtn = document.querySelector('.btn');
const input = document.querySelector('form input[type="email"]');

// querySelectorAll — static NodeList (snapshot) ✅
const allBtns = document.querySelectorAll('.btn');
allBtns.forEach(btn => btn.classList.add('active')); // safe — static ✅

// getElementsByClassName — live HTMLCollection ✅
const live = document.getElementsByClassName('item'); // live
// Convert to array to iterate safely
const snapshot = Array.from(live); // static copy ✅
snapshot.forEach(el => el.remove());

// Performance comparison (from fastest to slowest):
// getElementById > querySelector > querySelectorAll > getElementsBy*

// Scoped queries — search within element, not entire document ✅
const form = document.querySelector('#registration-form');
const emailInput = form.querySelector('[name="email"]'); // scoped ✅

// Element.matches — check if element matches selector
document.addEventListener('click', (e) => {
  if (e.target.matches('.btn-primary')) {
    handlePrimaryClick(e.target); // ✅
  }
});
```

---

## 10.2 Creating and Modifying DOM Elements

### Q92. What is the difference between innerHTML, textContent, and createElement? When is each safe to use?

**Answer:**
`createElement` creates an element safely — never parses HTML. `textContent` sets/reads text content without HTML parsing — safe for user content. `innerHTML` parses HTML strings — fast but **dangerous with user input** (XSS vulnerability). `insertAdjacentHTML` is faster than `innerHTML` for adding content (doesn't re-parse existing children). Always sanitize before using `innerHTML` with any user-supplied data.

❌ **Violates — innerHTML with user input (XSS):**
```javascript
// XSS vulnerability ❌
const userInput = '<img src=x onerror="stealCookies()">';
element.innerHTML = userInput; // executes attacker script ❌

// innerHTML for simple text — overkill and dangerous ❌
div.innerHTML = user.name; // if name contains < or >, it parses as HTML ❌
```

✅ **Satisfies — safe DOM manipulation:**
```javascript
// textContent — always safe for text ✅
div.textContent = user.name; // '<script>' shown as literal text ✅

// createElement — safe programmatic creation ✅
function createCard(user) {
  const card = document.createElement('div');
  card.className = 'card';

  const title = document.createElement('h2');
  title.textContent = user.name; // safe ✅

  const btn = document.createElement('button');
  btn.textContent = 'View Profile';
  btn.addEventListener('click', () => viewProfile(user.id));

  card.appendChild(title);
  card.appendChild(btn);
  return card;
}
document.body.appendChild(createCard(user));

// insertAdjacentHTML — faster than innerHTML, but sanitize first ✅
// Positions: 'beforebegin', 'afterbegin', 'beforeend', 'afterend'
list.insertAdjacentHTML('beforeend', `<li class="item">${escapeHtml(user.name)}</li>`);

// Safe HTML escape
function escapeHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;')
            .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// DocumentFragment — batch DOM manipulation ✅
const fragment = document.createDocumentFragment();
users.forEach(user => fragment.appendChild(createCard(user)));
document.body.appendChild(fragment); // single reflow ✅
```

---

## 10.3 Event Handling

### Q93. How do event bubbling and capturing work? What is event delegation?

**Answer:**
Events have 3 phases: **capture** (window → target), **target** (the element), **bubble** (target → window). `addEventListener` default is bubble phase; pass `true` as third arg for capture. `stopPropagation()` prevents further propagation. `preventDefault()` prevents default browser behavior (not propagation). **Event delegation** attaches one listener to a parent to handle events from many children — more efficient and works for dynamically added elements.

❌ **Violates — attaching listeners to every child element:**
```javascript
// N listeners for N items — inefficient and doesn't work for dynamic items ❌
document.querySelectorAll('.list-item').forEach(item => {
  item.addEventListener('click', handleClick); // 1 listener per element ❌
});

// stopPropagation prevents all ancestor handlers — overly broad ❌
child.addEventListener('click', (e) => {
  e.stopPropagation(); // may break other listeners on parents ❌
  handleChild(e);
});
```

✅ **Satisfies — event delegation and correct propagation:**
```javascript
// Event delegation — one listener on parent ✅
const list = document.querySelector('#item-list');
list.addEventListener('click', (event) => {
  const item = event.target.closest('.list-item'); // find the item ✅
  if (!item || !list.contains(item)) return;
  handleItemClick(item, event);
});
// Works for items added dynamically after listener attached ✅

// Capture phase — fires before target handles event
document.addEventListener('click', logClick, true); // capture ✅

// preventDefault — stop default but let event bubble
link.addEventListener('click', (e) => {
  e.preventDefault(); // don't navigate ✅
  handleNavigation(link.href); // custom handler
  // event still bubbles — other listeners fire ✅
});

// stopImmediatePropagation — stop all listeners on same element
element.addEventListener('click', (e) => {
  if (shouldBlock) e.stopImmediatePropagation(); // use sparingly ✅
});

// event.currentTarget vs event.target
list.addEventListener('click', (e) => {
  console.log(e.currentTarget); // always the list (listener's element)
  console.log(e.target);        // the actual clicked element (child)
});
```

---

## 10.4 Web Storage

### Q94. What are the differences between localStorage, sessionStorage, cookies, and IndexedDB?

**Answer:**
`localStorage` persists indefinitely until cleared (survives browser restart, tab close). `sessionStorage` clears when the tab/window closes. Both are synchronous, store strings only, and have ~5MB limit. Cookies persist until expiry, are sent with every HTTP request (security risk for sensitive data), have ~4KB limit, and can be HttpOnly (JS can't read). IndexedDB is async, stores structured data, handles large amounts, and is best for offline apps.

❌ **Violates — storing sensitive data in localStorage:**
```javascript
// Never store sensitive data in localStorage ❌
localStorage.setItem('authToken', jwt);       // accessible to any JS on page ❌
localStorage.setItem('password', userPass);   // XSS can steal this ❌

// Forgetting localStorage only stores strings ❌
localStorage.setItem('user', { name: 'Alice' }); // stores '[object Object]' ❌
JSON.parse(localStorage.getItem('user'));         // null — corrupted ❌
```

✅ **Satisfies — correct storage choice:**
```javascript
// localStorage — persist user preferences ✅
localStorage.setItem('theme', 'dark');
localStorage.setItem('user', JSON.stringify({ name: 'Alice', id: 1 })); // serialize ✅

const user = JSON.parse(localStorage.getItem('user') || 'null'); // ✅
const theme = localStorage.getItem('theme') ?? 'light';

localStorage.removeItem('theme');
localStorage.clear(); // clear all

// sessionStorage — temporary session data ✅
sessionStorage.setItem('formDraft', JSON.stringify(formData));
window.addEventListener('beforeunload', () => sessionStorage.removeItem('formDraft'));

// Cookies — auth tokens (HttpOnly, Secure, SameSite) ✅
// Set from server: Set-Cookie: token=abc; HttpOnly; Secure; SameSite=Strict
// JS-readable cookie (non-sensitive)
document.cookie = 'visited=true; max-age=86400; SameSite=Lax';

// IndexedDB — large structured data ✅
const request = indexedDB.open('myDB', 1);
request.onupgradeneeded = (e) => {
  const db = e.target.result;
  db.createObjectStore('users', { keyPath: 'id' });
};
request.onsuccess = (e) => {
  const db = e.target.result;
  const tx = db.transaction('users', 'readwrite');
  tx.objectStore('users').add({ id: 1, name: 'Alice' });
};

// Summary:
// Auth tokens → HttpOnly cookies (server-set) ✅
// User preferences → localStorage ✅
// Form drafts → sessionStorage ✅
// Offline data / large data → IndexedDB ✅
```

---

## 10.5 fetch API

### Q95. How do you use the fetch API? Why doesn't fetch reject on 4xx/5xx responses?

**Answer:**
`fetch` returns a Promise that resolves to a `Response` object. It only rejects on **network failures** (no connection, DNS failure) — NOT on HTTP error status codes (404, 500). You must check `response.ok` or `response.status` manually and throw if needed. For POST with JSON: set `Content-Type` header and `JSON.stringify` the body. Always handle both network errors and HTTP errors.

❌ **Violates — assuming fetch rejects on 4xx/5xx:**
```javascript
// 404 and 500 don't throw — fetch resolves! ❌
fetch('/api/user/999')
  .then(res => res.json()) // will try to parse error response body ❌
  .then(data => console.log(data)) // data might be an error object ❌
  .catch(err => console.error(err)); // only catches network errors ❌
```

✅ **Satisfies — correct fetch usage:**
```javascript
// Utility wrapper that throws on HTTP errors ✅
async function apiFetch(url, options = {}) {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options
  });

  if (!response.ok) { // response.ok = status 200-299 ✅
    const error = await response.json().catch(() => ({}));
    throw new Error(error.message || `HTTP ${response.status}: ${response.statusText}`);
  }

  return response.json();
}

// GET
const user = await apiFetch('/api/users/1');

// POST with JSON body ✅
const newUser = await apiFetch('/api/users', {
  method: 'POST',
  body: JSON.stringify({ name: 'Alice', email: 'alice@example.com' })
});

// With auth header
const data = await apiFetch('/api/protected', {
  headers: { Authorization: `Bearer ${token}` }
});

// Timeout with AbortController ✅
async function fetchWithTimeout(url, ms = 5000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), ms);
  try {
    return await apiFetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

// File upload (multipart/form-data) ✅
const formData = new FormData();
formData.append('file', fileInput.files[0]);
await fetch('/api/upload', { method: 'POST', body: formData });
// Don't set Content-Type — browser sets it with boundary ✅
```

---

## 10.6 URL and URLSearchParams

### Q96. How do you parse URLs and build query strings with URL and URLSearchParams?

**Answer:**
The `URL` class parses a URL string into components (protocol, hostname, pathname, search, hash). `URLSearchParams` parses and builds query strings — it handles encoding automatically. Both are available in browsers and Node.js (globalThis). Use these instead of manual string concatenation for query params — they handle encoding, special characters, and arrays correctly.

❌ **Violates — manual string concatenation for URLs:**
```javascript
// Manual URL building — encoding bugs ❌
const name = 'Alice & Bob';
const url = '/search?q=' + name + '&page=' + page;
// Results in: /search?q=Alice & Bob&page=1 — invalid URL ❌

// Manual parsing — fragile ❌
const search = window.location.search; // '?q=test&page=2'
const params = search.substring(1).split('&').reduce((acc, pair) => {
  const [k, v] = pair.split('=');
  acc[k] = v; // doesn't decode %20, +, etc. ❌
  return acc;
}, {});
```

✅ **Satisfies — URL and URLSearchParams:**
```javascript
// Parse a URL
const url = new URL('https://example.com/search?q=hello&page=2#results');
console.log(url.protocol); // 'https:'
console.log(url.hostname); // 'example.com'
console.log(url.pathname); // '/search'
console.log(url.search);   // '?q=hello&page=2'
console.log(url.hash);     // '#results'

// URLSearchParams — read query params ✅
const params = url.searchParams;
params.get('q');    // 'hello' ✅
params.get('page'); // '2' ✅

// Build query string safely ✅
const search = new URLSearchParams({
  q: 'Alice & Bob', // encoded automatically
  page: 2,
  tags: 'js'
});
search.append('tags', 'typescript'); // multiple values for same key

const apiUrl = new URL('/api/search', 'https://example.com');
apiUrl.search = search.toString();
console.log(apiUrl.href);
// 'https://example.com/api/search?q=Alice+%26+Bob&page=2&tags=js&tags=typescript' ✅

// Iterate all params
for (const [key, value] of params) {
  console.log(key, value); // ✅
}

// Relative URL resolution
const base = new URL('https://example.com/docs/guide/');
const relative = new URL('../api', base);
console.log(relative.href); // 'https://example.com/docs/api' ✅
```

---

## 10.7 IntersectionObserver

### Q97. How does IntersectionObserver work? What are its use cases?

**Answer:**
`IntersectionObserver` asynchronously observes when a target element's intersection with a viewport (or ancestor) changes. It fires a callback with `IntersectionObserverEntry` objects containing `isIntersecting`, `intersectionRatio`, and bounding box data. Key use cases: lazy loading images (load only when visible), infinite scroll, play/pause videos on visibility, and analytics (track if content was seen).

❌ **Violates — scroll event listener for visibility checks:**
```javascript
// Scroll listener for lazy loading — performance disaster ❌
window.addEventListener('scroll', () => {
  images.forEach(img => {
    const rect = img.getBoundingClientRect(); // forces layout ❌
    if (rect.top < window.innerHeight) {
      img.src = img.dataset.src; // load image ❌
    }
  });
}); // runs on every scroll pixel — very expensive ❌
```

✅ **Satisfies — IntersectionObserver for lazy loading:**
```javascript
// Lazy loading images ✅
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const img = entry.target;
      img.src = img.dataset.src; // load the image ✅
      img.removeAttribute('data-src');
      observer.unobserve(img); // stop watching once loaded ✅
    }
  });
}, {
  rootMargin: '200px', // load 200px before visible ✅
  threshold: 0.1       // trigger when 10% visible
});

document.querySelectorAll('img[data-src]').forEach(img => {
  observer.observe(img);
});

// Infinite scroll ✅
const sentinel = document.querySelector('#load-more-sentinel');
new IntersectionObserver((entries) => {
  if (entries[0].isIntersecting) {
    loadMoreItems();
  }
}, { threshold: 1.0 }).observe(sentinel);

// Analytics — track if user saw content ✅
const articleObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting && entry.intersectionRatio >= 0.5) {
      analytics.track('content_viewed', { id: entry.target.dataset.id });
      articleObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.5 });
```

---

## 10.8 MutationObserver

### Q98. What is MutationObserver and when should you use it?

**Answer:**
`MutationObserver` watches for changes to the DOM tree and fires a callback with a list of `MutationRecord` objects describing each change. It observes: child node additions/removals, attribute changes, and text content changes. It replaced the deprecated DOM Mutation Events. Use it for: detecting when third-party code modifies the DOM, implementing features that react to DOM changes (auto-resize, re-query), and testing.

❌ **Violates — polling DOM for changes:**
```javascript
// Polling — wasteful and imprecise ❌
setInterval(() => {
  const items = document.querySelectorAll('.new-item');
  if (items.length > lastCount) {
    handleNewItems(items);
    lastCount = items.length;
  }
}, 100); // runs every 100ms regardless ❌
```

✅ **Satisfies — MutationObserver:**
```javascript
// Watch for child list changes ✅
const observer = new MutationObserver((mutations) => {
  mutations.forEach(mutation => {
    mutation.addedNodes.forEach(node => {
      if (node.nodeType === Node.ELEMENT_NODE && node.matches('.item')) {
        handleNewItem(node); // react to new items ✅
      }
    });
    mutation.removedNodes.forEach(node => {
      handleRemovedItem(node);
    });
  });
});

observer.observe(document.getElementById('list'), {
  childList: true,   // watch for added/removed children ✅
  subtree: true,     // include all descendants
  attributes: false, // no attribute changes needed
  characterData: false
});

// Stop observing when done ✅
function cleanup() {
  observer.disconnect();
}

// Watch for attribute changes
const attrObserver = new MutationObserver((mutations) => {
  mutations.forEach(m => {
    console.log(`${m.attributeName} changed from`, m.oldValue, 'to', m.target.getAttribute(m.attributeName));
  });
});

attrObserver.observe(element, {
  attributes: true,
  attributeOldValue: true,           // capture previous value ✅
  attributeFilter: ['class', 'data-state'] // only these attrs ✅
});

// Use case: react when third-party widget loads
observer.observe(document.body, { childList: true, subtree: true });
```

---

## 10.9 History API

### Q99. How does the History API work for single-page app routing?

**Answer:**
The History API enables navigation without full page reloads. `pushState(state, title, url)` adds an entry to the history stack and updates the URL. `replaceState` modifies the current entry without adding a new one. The `popstate` event fires when the user navigates back/forward. SPAs use this to implement client-side routing — React Router, Vue Router, and similar libraries are built on this API.

❌ **Violates — URL hash-based routing (older approach):**
```javascript
// Hash routing — works but ugly URLs, SEO issues ❌
window.location.hash = '#/users/1'; // URL: example.com/#/users/1 ❌
window.addEventListener('hashchange', () => {
  route(window.location.hash.slice(1)); // ❌
});
```

✅ **Satisfies — History API for clean URLs:**
```javascript
// Navigate to a new URL without page reload ✅
function navigate(path, state = {}) {
  history.pushState(state, '', path);
  renderPage(path); // render the new "page" ✅
}

navigate('/users/1', { userId: 1 }); // URL: /users/1 ✅

// Handle browser back/forward buttons ✅
window.addEventListener('popstate', (event) => {
  const path = window.location.pathname;
  renderPage(path, event.state); // event.state = state passed to pushState ✅
});

// Replace current entry (no new history entry)
history.replaceState({ step: 2 }, '', '/checkout/step-2'); ✅

// Simple client-side router
class Router {
  constructor(routes) {
    this.routes = routes;
    window.addEventListener('popstate', () => this.render());
    document.addEventListener('click', (e) => {
      const link = e.target.closest('[data-link]');
      if (link) {
        e.preventDefault();
        this.navigate(link.getAttribute('href'));
      }
    });
  }

  navigate(path) {
    history.pushState({}, '', path);
    this.render();
  }

  render() {
    const path = window.location.pathname;
    const route = this.routes[path] || this.routes['/404'];
    document.getElementById('app').innerHTML = route();
  }
}

const router = new Router({
  '/': () => '<h1>Home</h1>',
  '/about': () => '<h1>About</h1>',
  '/404': () => '<h1>Not Found</h1>'
});
```

---

## 10.10 Modern Browser APIs

### Q100. What are the Clipboard API, Geolocation API, and Notification API? How do you use them?

**Answer:**
The **Clipboard API** (`navigator.clipboard`) provides async read/write access to the clipboard — requires HTTPS and user gesture. **Geolocation API** (`navigator.geolocation`) retrieves the device's position — requires user permission. **Notifications API** (`Notification`) shows system notifications — requires permission. All three require explicit user permission and only work on HTTPS (except localhost). Always check for API support and handle permission denial gracefully.

❌ **Violates — no permission handling and synchronous clipboard:**
```javascript
// Old synchronous clipboard — deprecated ❌
document.execCommand('copy'); // deprecated, may not work ❌

// Geolocation without error handling ❌
navigator.geolocation.getCurrentPosition(pos => {
  console.log(pos.coords); // crashes if denied or unavailable ❌
});

// Notification without permission check ❌
new Notification('Hello!'); // may throw if permission denied ❌
```

✅ **Satisfies — modern APIs with permission handling:**
```javascript
// Clipboard API ✅
async function copyToClipboard(text) {
  if (!navigator.clipboard) {
    // Fallback for older browsers
    const el = document.createElement('textarea');
    el.value = text;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
    return;
  }
  try {
    await navigator.clipboard.writeText(text);
    console.log('Copied!');
  } catch (err) {
    console.error('Clipboard write failed:', err);
  }
}

async function pasteFromClipboard() {
  const text = await navigator.clipboard.readText(); // requires user gesture ✅
  return text;
}

// Geolocation API ✅
function getLocation() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Geolocation not supported'));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lat: pos.coords.latitude, lon: pos.coords.longitude }),
      (err) => reject(new Error(`Geolocation error: ${err.message}`)),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 300000 }
    );
  });
}

// Notifications API ✅
async function showNotification(title, options = {}) {
  if (!('Notification' in window)) return;

  if (Notification.permission === 'default') {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return;
  }

  if (Notification.permission === 'granted') {
    const notification = new Notification(title, {
      body: options.body,
      icon: options.icon || '/icon.png',
      badge: '/badge.png',
      tag: options.tag // deduplicates notifications with same tag ✅
    });

    notification.onclick = () => {
      window.focus();
      notification.close();
    };
  }
}

// Service Worker Notifications (persist when page closed) ✅
// navigator.serviceWorker.ready.then(registration => {
//   registration.showNotification('Background notification');
// });
```

---

*End of JavaScript Interview Questions — Complete Guide*

> **Tip:** Bookmark this file and use `Ctrl+F` / `Cmd+F` to search for any topic. Good luck with your interviews!

---

# ⚖️ JavaScript Comparisons — Side-by-Side Differences

---

## JS-C1 — `var` vs `let` vs `const`

| | `var` | `let` | `const` |
|-|-------|-------|---------|
| Scope | Function | Block | Block |
| Hoisting | ✅ Hoisted (initialised `undefined`) | ✅ Hoisted (TDZ — not initialised) | ✅ Hoisted (TDZ) |
| Re-declaration | ✅ Allowed | ❌ Error | ❌ Error |
| Re-assignment | ✅ | ✅ | ❌ Variable binding only |
| Global object property | ✅ `window.x` if top-level | ❌ | ❌ |

```javascript
// var — function scoped, accessible before declaration
console.log(x); // undefined (hoisted)
var x = 5;

// let — block scoped, TDZ
console.log(y); // ReferenceError (temporal dead zone)
let y = 5;
{ let y = 10; } // different y
console.log(y); // 5

// const — prevents rebinding, not mutation
const arr = [1, 2];
arr.push(3);    // ✅ mutation allowed
arr = [4, 5];   // ❌ TypeError — cannot reassign const
```

---

## JS-C2 — `==` vs `===` (Loose vs Strict Equality)

| | `==` (loose) | `===` (strict) |
|-|-------------|---------------|
| Type coercion | ✅ Yes | ❌ No |
| Performance | Slightly slower (coercion) | Faster |
| Predictability | ❌ Surprising results | ✅ Consistent |
| Use | Almost never | Always |

```javascript
0   == false  // true  (false coerced to 0)
0   === false // false (number ≠ boolean)
''  == false  // true
null == undefined // true
null === undefined // false
[1] == 1     // true  (array coerced to number)
[1] === 1    // false

// Only safe == use: null check (catches both null and undefined)
if (x == null) { }  // equivalent to: if (x === null || x === undefined)
```

---

## JS-C3 — `null` vs `undefined` vs `NaN` vs `0` vs `''`

| Value | `typeof` | Falsy? | Description |
|-------|---------|--------|-------------|
| `null` | `'object'` (bug) | ✅ | Intentional absence of value |
| `undefined` | `'undefined'` | ✅ | Variable declared but not assigned |
| `NaN` | `'number'` | ✅ | Invalid number operation |
| `0` | `'number'` | ✅ | Zero |
| `''` | `'string'` | ✅ | Empty string |
| `false` | `'boolean'` | ✅ | Boolean false |

```javascript
typeof null        // 'object' — historical bug in JS
typeof undefined   // 'undefined'
null == undefined  // true
null === undefined // false

Number('abc')      // NaN
isNaN(NaN)         // true
NaN === NaN        // false! (NaN is never equal to itself)
Number.isNaN(NaN)  // true (use this — isNaN() coerces first)
```

---

## JS-C4 — Arrow Function vs Regular Function

| | Arrow Function | Regular Function |
|-|---------------|-----------------|
| `this` binding | Lexical (inherits from enclosing scope) | Dynamic (depends on caller) |
| `arguments` object | ❌ Not available | ✅ Available |
| `new` (constructor) | ❌ Cannot use | ✅ Can use |
| Prototype | ❌ No prototype | ✅ Has prototype |
| Use for | Callbacks, array methods, class methods | Constructors, methods needing own `this` |

```javascript
// Regular function — this depends on HOW it's called
const obj = {
  name: 'Alice',
  greet: function() { return this.name; } // this = obj when called as obj.greet()
};

// Arrow function — this inherited from where it's DEFINED
const obj2 = {
  name: 'Alice',
  // ❌ Arrow as method — this is outer scope (window/undefined), not obj2
  greet: () => this.name,     // undefined!
  // ✅ Arrow inside method — captures obj2's this
  greetLater: function() {
    setTimeout(() => console.log(this.name), 100); // this = obj2 ✅
  }
};
```

---

## JS-C5 — `call` vs `apply` vs `bind`

| | `call` | `apply` | `bind` |
|-|--------|---------|--------|
| Invokes immediately | ✅ | ✅ | ❌ Returns new function |
| Arguments | Individual | Array | Partial application |

```javascript
function greet(greeting, punctuation) {
  return `${greeting}, ${this.name}${punctuation}`;
}
const user = { name: 'Alice' };

greet.call(user, 'Hello', '!');        // "Hello, Alice!"
greet.apply(user, ['Hello', '!']);     // "Hello, Alice!" (args as array)
const boundGreet = greet.bind(user);   // new function with this=user
boundGreet('Hi', '.');                 // "Hi, Alice."

// bind partial application
const sayHello = greet.bind(user, 'Hello');
sayHello('?');  // "Hello, Alice?"
```

---

## JS-C6 — Callback vs Promise vs Async/Await

| | Callback | Promise | Async/Await |
|-|----------|---------|-------------|
| Readability | ❌ Callback hell | Better | ✅ Best (synchronous-looking) |
| Error handling | Manual try/catch in each | `.catch()` | `try/catch` |
| Parallel execution | Manual | `Promise.all()` | `await Promise.all()` |
| Cancellation | Manual | AbortController | AbortController |

```javascript
// Callback hell
getUser(id, (user) => {
  getOrders(user.id, (orders) => {
    getPayments(orders[0].id, (payment) => {
      // deeply nested!
    }, onError);
  }, onError);
}, onError);

// Promise chain
getUser(id)
  .then(user => getOrders(user.id))
  .then(orders => getPayments(orders[0].id))
  .catch(err => console.error(err));

// Async/await — clearest
try {
  const user    = await getUser(id);
  const orders  = await getOrders(user.id);
  const payment = await getPayments(orders[0].id);
} catch (err) { console.error(err); }

// Parallel — don't await sequentially when independent
const [user, config] = await Promise.all([getUser(id), getConfig()]);
```

---

## JS-C7 — `for...of` vs `for...in` vs `forEach` vs `map`

| | `for...of` | `for...in` | `forEach` | `map` |
|-|-----------|-----------|----------|-------|
| Iterates | Values | Enumerable keys | Values | Values |
| Works on | Iterables (array, string, Map, Set) | Objects | Arrays | Arrays |
| Returns | Nothing | Nothing | Nothing (void) | New array |
| `break`/`continue` | ✅ | ✅ | ❌ | ❌ |
| Async-friendly | ✅ `for await...of` | ❌ | ❌ | ❌ |

```javascript
const arr = [1, 2, 3];

for (const v of arr) { /* v = 1, 2, 3 */ }  // values ✅
for (const k in arr) { /* k = '0', '1', '2' */ } // keys ❌ (use for objects)

arr.forEach(v => console.log(v));  // side effects, no return value
const doubled = arr.map(v => v * 2); // [2, 4, 6] — transformation

// for...of with index via entries()
for (const [i, v] of arr.entries()) { console.log(i, v); }
```

---

## JS-C8 — Shallow Copy vs Deep Copy

| | Assignment (`=`) | Spread (`{...}`) / `Object.assign` | `structuredClone()` | `JSON.parse(JSON.stringify())` |
|-|----------------|-----------------------------------|--------------------|---------------------------------|
| Copies reference | ✅ Same object | ❌ New top-level object | ❌ Full deep copy | ❌ Full deep copy |
| Nested objects | Same reference | Same reference (shallow) | ✅ Copied | ✅ Copied |
| Functions | Same reference | Same reference | ❌ Lost | ❌ Lost |
| Dates / Maps / Sets | Same reference | Same reference | ✅ Preserved | ❌ Lost (→ string) |

```javascript
const a = { x: 1, nested: { y: 2 } };

const ref   = a;                       // same object — changes affect a
const shallow = { ...a };              // new object, nested.y still shared
const deep  = structuredClone(a);      // full independent copy ✅ (modern)

shallow.nested.y = 99;
console.log(a.nested.y); // 99! — shallow copy shares nested reference

deep.nested.y = 88;
console.log(a.nested.y); // still 99 — deep copy is independent
```


---

# ⚖️ JavaScript Comparisons — Side-by-Side Differences

---

## JS-C1 — `var` vs `let` vs `const`

| | `var` | `let` | `const` |
|-|-------|-------|---------|
| Scope | Function-scoped | Block-scoped | Block-scoped |
| Hoisted | ✅ Yes (initialised as `undefined`) | ✅ Yes (but TDZ — not accessible) | ✅ Yes (but TDZ) |
| Re-declare same scope | ✅ Yes | ❌ Error | ❌ Error |
| Re-assign | ✅ Yes | ✅ Yes | ❌ Error (binding, not value) |
| Use today | ❌ Avoid | ✅ For mutable bindings | ✅ Default — prefer always |

```js
// var hoisting trap
console.log(x); // undefined (not ReferenceError) — hoisted
var x = 5;

// let — TDZ (Temporal Dead Zone)
console.log(y); // ❌ ReferenceError — can't access before declaration
let y = 5;

// const — binding is immutable, but object contents can change
const user = { name: "Alice" };
user.name = "Bob";   // ✅ allowed — object mutated, not re-bound
user = {};           // ❌ TypeError — re-assignment of const binding
```

---

## JS-C2 — `==` (Loose) vs `===` (Strict) vs `Object.is()`

| | `==` (loose) | `===` (strict) | `Object.is()` |
|-|-------------|---------------|---------------|
| Type coercion | ✅ Yes (converts types) | ❌ No | ❌ No |
| `NaN == NaN` | `false` | `false` | `true` ✅ |
| `+0 === -0` | `true` | `true` | `false` ✅ |
| Use | ❌ Avoid — unpredictable | ✅ Default choice | Special cases (NaN, ±0) |

```js
0   == "0"   // true  — string coerced to number
0   === "0"  // false — different types
null == undefined  // true  (loose)
null === undefined // false (strict)

// Object.is quirks:
Object.is(NaN, NaN)  // true  — unlike ===
Object.is(+0, -0)    // false — unlike ===
```

---

## JS-C3 — `null` vs `undefined` vs `NaN` vs empty string

| | `null` | `undefined` | `NaN` | `""` |
|-|--------|------------|-------|------|
| Type | `"object"` (JS bug) | `"undefined"` | `"number"` | `"string"` |
| Meaning | Intentional absence | Not assigned / missing | Invalid number | Empty text |
| Falsy | ✅ | ✅ | ✅ | ✅ |
| `== null` | ✅ true | ✅ true | ❌ false | ❌ false |

```js
let a;
console.log(a);          // undefined — declared but not assigned

let b = null;
console.log(b);          // null — intentionally empty

console.log(0 / 0);      // NaN — invalid arithmetic
console.log(NaN === NaN);// false — NaN is not equal to itself!
console.log(isNaN(NaN)); // true  — use isNaN() or Number.isNaN()

// Safe null/undefined check
if (value == null) { }   // catches both null AND undefined
if (value === null) { }  // only null
if (value === undefined) { } // only undefined
```

---

## JS-C4 — `forEach` vs `map` vs `filter` vs `reduce` vs `find`

| | `forEach` | `map` | `filter` | `reduce` | `find` |
|-|----------|-------|---------|---------|--------|
| Returns | `undefined` | New array (same length) | New array (subset) | Single value | First match or `undefined` |
| Chainable | ❌ | ✅ | ✅ | ✅ | ❌ |
| Use for | Side effects | Transform each element | Subset of elements | Aggregate | First matching element |
| Break early | ❌ | ❌ | ❌ | ❌ | ✅ (stops at first match) |

```js
const nums = [1, 2, 3, 4, 5];

nums.forEach(n => console.log(n));          // side effect only, no return value
const doubled  = nums.map(n => n * 2);      // [2, 4, 6, 8, 10]
const evens    = nums.filter(n => n % 2 === 0); // [2, 4]
const sum      = nums.reduce((acc, n) => acc + n, 0); // 15
const firstBig = nums.find(n => n > 3);    // 4 (stops searching after 4)

// Chaining
const result = nums
  .filter(n => n % 2 === 0)   // [2, 4]
  .map(n => n * 10)            // [20, 40]
  .reduce((a, b) => a + b, 0); // 60
```

---

## JS-C5 — Arrow Function vs Regular Function

| | Regular Function | Arrow Function |
|-|----------------|---------------|
| `this` binding | Dynamic (caller determines `this`) | Lexical (`this` from surrounding scope) |
| `arguments` object | ✅ Available | ❌ Not available (use rest params) |
| Constructor (`new`) | ✅ Can be used | ❌ Cannot be called with `new` |
| Method shorthand | ✅ Good | ❌ Loses correct `this` |
| Callbacks | Careful with `this` | ✅ Preferred (captures `this`) |

```js
class Timer {
  constructor() { this.seconds = 0; }

  // ❌ Regular function — loses 'this' in setTimeout
  startBroken() {
    setInterval(function() {
      this.seconds++; // 'this' = global/undefined, not Timer!
    }, 1000);
  }

  // ✅ Arrow function — captures 'this' from class
  start() {
    setInterval(() => {
      this.seconds++; // 'this' = Timer instance ✅
    }, 1000);
  }
}

// ❌ Arrow function as object method — wrong 'this'
const obj = {
  name: "Alice",
  greet: () => console.log(this.name) // 'this' = global, not obj!
};

// ✅ Regular function as method — correct 'this'
const obj2 = {
  name: "Alice",
  greet() { console.log(this.name); } // 'this' = obj2 ✅
};
```

---

## JS-C6 — Promise vs async/await vs Callbacks vs Observable

| | Callback | Promise | async/await | Observable (RxJS) |
|-|---------|---------|-------------|-------------------|
| Multiple values | ❌ | ❌ (one resolve) | ❌ | ✅ |
| Cancellable | ❌ | ❌ | ❌ (AbortController workaround) | ✅ `.unsubscribe()` |
| Error handling | Try/catch hard | `.catch()` | try/catch ✅ | `.pipe(catchError())` |
| Readability | ❌ Callback hell | Medium | ✅ Best | Medium |
| Lazy | ❌ | ❌ (eager) | ❌ | ✅ Only runs when subscribed |

```js
// Callback — nested hell
getUser(id, (err, user) => {
  getOrders(user.id, (err, orders) => {
    getItem(orders[0].id, (err, item) => { /* ... */ });
  });
});

// Promise — chainable
getUser(id)
  .then(user => getOrders(user.id))
  .then(orders => getItem(orders[0].id))
  .catch(err => console.error(err));

// async/await — reads like sync
async function load(id) {
  try {
    const user   = await getUser(id);
    const orders = await getOrders(user.id);
    const item   = await getItem(orders[0].id);
  } catch (err) { console.error(err); }
}

// Parallel (don't await sequentially when independent)
const [user, settings] = await Promise.all([getUser(id), getSettings(id)]);
```

---

## JS-C7 — `call` vs `apply` vs `bind`

| | `call` | `apply` | `bind` |
|-|--------|---------|--------|
| Invokes immediately | ✅ | ✅ | ❌ (returns new function) |
| Args format | Individual: `fn.call(ctx, a, b)` | Array: `fn.apply(ctx, [a, b])` | Individual: `fn.bind(ctx, a, b)` |
| Use for | Borrow methods, set `this` immediately | Spread array as args | Partial application, event handlers |

```js
function greet(greeting, punctuation) {
  return `${greeting}, ${this.name}${punctuation}`;
}
const user = { name: "Alice" };

greet.call(user, "Hello", "!");     // "Hello, Alice!" — immediate call
greet.apply(user, ["Hello", "!"]); // "Hello, Alice!" — array args
const boundGreet = greet.bind(user, "Hello"); // new function with 'this' fixed
boundGreet("!");                    // "Hello, Alice!" — called later
```

---

## JS-C8 — `prototype` vs `class` vs Factory Function

| | Prototype | `class` (ES6) | Factory Function |
|-|----------|--------------|-----------------|
| Syntax | Verbose (`Function.prototype.method`) | Clean, familiar | Plain function |
| `this` risks | ✅ Bound via `new` | ✅ Bound via `new` | ❌ No `this` needed (closure) |
| Private data | ❌ Convention only | ✅ `#privateField` (ES2022) | ✅ Closure — truly private |
| Inheritance | `Object.create(proto)` | `extends` | Composition (mixin) |
| `instanceof` | ✅ | ✅ | ❌ |

```js
// Class (most common today)
class Counter {
  #count = 0;             // truly private (ES2022)
  increment() { this.#count++; }
  get value() { return this.#count; }
}

// Factory function — no 'this', private via closure
function createCounter() {
  let count = 0;          // private via closure
  return {
    increment: () => count++,
    get value() { return count; }
  };
}
```

---

## JS-C9 — `setTimeout` vs `setInterval` vs `requestAnimationFrame` vs `queueMicrotask`

| | `setTimeout` | `setInterval` | `requestAnimationFrame` | `queueMicrotask` |
|-|-------------|--------------|------------------------|-----------------|
| When runs | After N ms (macrotask) | Every N ms (macrotask) | Before next paint (~60fps) | End of current microtask queue |
| Cancellable | `clearTimeout` | `clearInterval` | `cancelAnimationFrame` | ❌ |
| Use for | Delayed action | Polling | Animation, smooth UI | Promise-like sequencing |
| Priority | Low (macrotask) | Low (macrotask) | High (before paint) | Highest (before macrotasks) |

```js
// Event loop order: Sync → Microtasks (Promise.then, queueMicrotask) → Macrotasks (setTimeout)
console.log("1");
setTimeout(() => console.log("4"), 0);   // macrotask — runs last
Promise.resolve().then(() => console.log("3")); // microtask — before setTimeout
queueMicrotask(() => console.log("2.5"));       // microtask — before setTimeout
console.log("2");
// Output: 1, 2, 2.5, 3, 4
```

