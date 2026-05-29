# PR / Code Review Interview Questions

## Code Review Fundamentals

**Q1: What is the purpose of a code review?**

Code review serves multiple purposes beyond catching bugs: it ensures code quality and maintainability, spreads knowledge across the team so no one person is the sole owner of a module, enforces architectural consistency and coding standards, provides a learning opportunity for both author and reviewer, and acts as a second set of eyes to catch security issues, performance problems, or logical errors. It also creates a discussion record that documents *why* decisions were made.

**Q2: What do you look for when reviewing a pull request?**

A thorough review covers several layers:
- **Correctness**: Does the code do what it's supposed to? Are edge cases handled?
- **Security**: Are there injection vulnerabilities, exposed secrets, missing authorization checks, or unvalidated inputs?
- **Performance**: Are there N+1 queries, unnecessary allocations, blocking async calls, or missing indexes?
- **Maintainability**: Is the code readable? Are methods/classes appropriately sized? Is duplication introduced?
- **Test coverage**: Are the new paths covered by tests? Do the tests actually assert meaningful behavior?
- **API design**: If it's a public API, is the interface intuitive and consistent with existing conventions?
- **Error handling**: Are exceptions caught and handled (or propagated) appropriately?
- **Dependencies**: Are new packages necessary? Do they have good maintenance records?

**Q3: How do you give constructive feedback in a code review?**

Use a collaborative, non-judgmental tone — critique the code, not the person. Prefix comments with context: "nit:" for minor style preferences, "suggestion:" for non-blocking improvements, "question:" when you don't understand intent, "blocker:" for issues that must be resolved. Explain *why* something is a concern, not just *what* to change. Acknowledge good decisions too — positive reinforcement improves team culture. Ask questions ("Could this throw if X is null?") rather than making demands.

**Q4: What is the ideal size for a pull request and why?**

Most teams recommend PRs under 400 lines of changed code. Smaller PRs are reviewed faster (reviewers are more attentive), are easier to test, and have fewer merge conflicts. Large PRs overwhelm reviewers and lead to rubber-stamping. When a feature requires many changes, break it into a feature branch with multiple smaller PRs stacked on each other.

---

## Security Review

**Q5: What security issues do you look for in a .NET code review?**

- **SQL injection**: Raw string concatenation in queries instead of parameterized queries or ORM.
- **XSS (Cross-Site Scripting)**: Rendering unencoded user input in Razor views — look for `Html.Raw()` on user-provided data.
- **Insecure deserialization**: Using `BinaryFormatter` or `JavaScriptSerializer` with untrusted input.
- **Missing authorization**: Endpoints accessible without `[Authorize]`, or authorization checks that can be bypassed.
- **Sensitive data exposure**: Logging passwords, tokens, PII; connection strings or API keys hardcoded.
- **CSRF**: Missing antiforgery tokens on state-changing form posts.
- **Dependency vulnerabilities**: `dotnet list package --vulnerable` finds known CVEs in NuGet packages.
- **Insecure random**: Using `System.Random` for security tokens instead of `RandomNumberGenerator`.

**Q6: How do you spot a potential SQL injection in a C# code review?**

Look for string interpolation or concatenation in database calls:

```csharp
// DANGEROUS — SQL injection
var query = $"SELECT * FROM Users WHERE Email = '{email}'";
connection.Execute(query);

// SAFE — parameterized
var query = "SELECT * FROM Users WHERE Email = @email";
connection.Execute(query, new { email });

// SAFE — EF Core LINQ
var user = await dbContext.Users.FirstOrDefaultAsync(u => u.Email == email);
```

If raw SQL is used (e.g., `ExecuteSqlRaw`), parameters must be passed separately — never interpolated.

---

## Performance Review

**Q7: What performance anti-patterns do you look for in a code review?**

- **N+1 queries**: A loop that executes a query per iteration — look for `await dbContext.X.FindAsync(id)` inside `foreach` loops. Fix with `Include()` or batching.
- **Missing `async/await`**: Synchronous calls in async context (`.Result`, `.Wait()`) that can cause thread pool starvation.
- **Over-fetching**: `SELECT *` or loading entire entities when only a few fields are needed — use projections.
- **Repeated computation**: Calling `.Count()` multiple times on a LINQ query that hits the database each time.
- **Missing cancellation token propagation**: Async methods accepting `CancellationToken` but not passing it to downstream calls.
- **Large object allocations in hot paths**: String concatenation in loops instead of `StringBuilder`; `ToList()` on large collections unnecessarily.
- **Unindexed filter columns**: New queries filtering on columns that have no database index.

**Q8: What is the async/await anti-pattern `.Result` / `.Wait()` and why is it dangerous?**

Calling `.Result` or `.Wait()` on a `Task` in an async context blocks the calling thread synchronously. In ASP.NET Core (which has no `SynchronizationContext`), this can cause deadlocks. The blocking thread holds a thread pool thread while waiting, reducing throughput. The fix is to `await` the task properly. Never mix blocking and async code.

---

## Code Quality

**Q9: What SOLID principle violations do you look for in a code review?**

- **SRP violations**: A class that handles both business logic and data access, or a method that does multiple distinct things.
- **OCP violations**: A giant `switch` or `if-else` chain on a type/enum that requires editing the same method every time a new case is added.
- **LSP violations**: Overriding a base method to throw `NotImplementedException`, or a subclass that changes the behavior expected by the base class contract.
- **ISP violations**: An interface with many methods where implementors leave half of them throwing `NotImplementedException`.
- **DIP violations**: A high-level class instantiating a low-level class directly with `new` instead of depending on an abstraction.

**Q10: How do you evaluate test quality in a code review?**

Good tests should be: readable (test name describes the scenario), independent (no shared mutable state between tests), deterministic (no random data, no dependency on system clock without mocking), asserting behavior (not implementation details), and covering both happy paths and error/edge cases. Red flags: tests that only verify mocks were called without asserting outcomes, tests with `Thread.Sleep`, tests that require a specific environment setup, and test classes with no `[Fact]`/`[Test]` methods that actually run.

**Q11: What do you look for regarding exception handling in a code review?**

- **Empty catch blocks** (`catch (Exception) { }`) — silently swallow errors.
- **Catching `Exception` broadly** when a specific exception type should be caught.
- **Rethrowing with `throw ex`** — destroys the original stack trace; use `throw` (bare) to preserve it.
- **Using exceptions for flow control** — e.g., checking if a record exists by catching an exception instead of checking first.
- **Missing finally or `using`** — resources (connections, streams) not disposed in error paths.
- **Async exception handling**: `async void` methods where exceptions can't be caught by the caller.

---

## Architecture & Design

**Q12: What architectural issues do you raise in a code review?**

- Business logic leaking into controllers (should be in a service/domain layer).
- Services directly instantiating dependencies (`new SomeService()`) instead of injecting them.
- Circular dependencies between layers (e.g., data layer referencing the business layer).
- Inappropriate use of static state that will break in multi-instance deployments.
- Hard-coded configuration values (URLs, timeouts) that should be in `appsettings.json`.
- Missing idempotency in operations that may be retried (e.g., API calls, message handlers).

**Q13: How do you review a database migration in a PR?**

Check: Is the migration reversible (is there a `Down` method)? Does it add a NOT NULL column without a default on a large table (can lock the table)? Does it drop a column that might still be read by the running application (requires a multi-step deploy)? Does it rename a column (also multi-step — add new, deploy code using both, then drop old)? Are there new indexes added `CONCURRENTLY` (Postgres) or with care on SQL Server to avoid locking? Does the migration run in a transaction?

---

## PR Process & Tooling

**Q14: What should a PR description contain?**

A good PR description includes: a summary of what changed and why (not just what files — the `git diff` shows that), a link to the related issue/ticket, steps to test or reproduce the scenario, screenshots for UI changes, notes on any risks or deployment considerations (migrations, feature flags, config changes), and a checklist of self-review items completed.

**Q15: What is the "boy scout rule" in code reviews?**

Leave the code cleaner than you found it — if you touch a file, fix obvious issues nearby (rename confusing variables, extract magic numbers to constants, remove dead code). But scope it reasonably: very large unrelated refactors in a bug-fix PR make review harder and increase risk.

**Q16: How do you handle disagreements during a code review?**

Escalate to a discussion rather than a blocking standoff. Reference team conventions, existing patterns, or documented architectural decisions. If no standard exists, agree to resolve it in a team discussion and document the outcome. Avoid blocking PRs over style preferences where no standard exists — either merge and address in a follow-up, or create the standard first. A "disagree and commit" culture avoids paralysis.

**Q17: What is the difference between a blocking and a non-blocking comment?**

A blocking comment (often labeled "blocker" or "must fix") means the PR cannot be merged until addressed — it points to a correctness issue, security vulnerability, or agreed-upon standard violation. A non-blocking comment (labeled "nit", "suggestion", or "optional") is advice or preference — the author can address it or note why they disagree. Distinguishing these prevents reviewers from inadvertently blocking PRs over minor opinions.

---

## Checklist

**Q18: What does a pre-merge PR checklist look like for a .NET backend service?**

A typical checklist covers:
- [ ] Code compiles with no new warnings
- [ ] All existing tests pass; new tests added for new logic
- [ ] No hardcoded secrets or connection strings
- [ ] Sensitive data not logged
- [ ] All new endpoints have appropriate `[Authorize]` or explicit `[AllowAnonymous]`
- [ ] Async methods propagate `CancellationToken`
- [ ] No `.Result` or `.Wait()` on Tasks
- [ ] EF Core migrations reviewed for safety
- [ ] New packages checked for known vulnerabilities
- [ ] API breaking changes identified and versioned
- [ ] Feature flag or dark-launch strategy for risky changes

---

## Real-World Scenario Questions

**Q19: You see this code in a PR. What do you say?**

```csharp
public User GetUser(int id) {
    try {
        return _db.Users.Find(id);
    }
    catch (Exception ex) {
        return null;
    }
}
```

This silently swallows all exceptions — including transient database errors, connection failures, and unexpected bugs. The caller receives `null` with no indication of what went wrong, making debugging very difficult. The fix depends on intent: if `null` is a valid "not found" response, let `Find` return `null` naturally (it does for EF Core when not found) and remove the try-catch. If the concern is specific transient errors, handle them specifically with retry logic. Never swallow `Exception` broadly.

**Q20: You see a controller action with 200 lines of business logic. What's your approach?**

First, understand what the code does before commenting. Then note that the action violates the Single Responsibility Principle and makes the code untestable (you can't unit test a controller action that does everything). Comment constructively: suggest extracting the business logic into a service class, injecting it via the constructor. Offer to help with the refactor if it's significant. If the PR is otherwise correct and the team is in a time crunch, note it as a non-blocking tech debt item and file a follow-up ticket.
