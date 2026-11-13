# Contribution and Writing Standard

This repository teaches concepts for practical use, not short-term memorization. Every change should help a reader understand a mechanism, apply it, and recognize its limits.

## Required Topic Structure

Use this sequence for a new question, concept, or pattern. A small topic may combine adjacent sections, but it must answer every item.

```markdown
## ID. Topic Name

**Question:** What should the reader be able to answer?

**Answer:** A direct, plain-language mental model.

**What problem does it solve?** The concrete pain, failure, or constraint.

**Before this concept:** How the code or system worked previously.

❌ **Wrong/before example:** Complete enough to trace the failure.

**Why it fails:** The input, load, timing, or change that exposes the problem.

✅ **After/correct example:** The smallest complete design that solves it.

**How it works now:** Control flow, data flow, state, errors, and ownership.

**Trade-offs and when not to use it:** Costs, complexity, and simpler alternatives.

**Production checks:** Security, concurrency, failure, observability, deployment, and cost.

**Try it:** A concrete exercise with an observable result.
```

## Example Quality Rules

### Keep before and after comparable

Use the same domain, requirement, input, and scale in both examples. If “before” is checkout, “after” must not switch to notifications. The reader should see exactly what changed.

### Show the failure, not just ugly code

Weak:

```csharp
// bad code here
```

Useful:

```csharp
public async Task ChargeAsync(Order order)
{
    await gateway.ChargeAsync(order.Total);
    await gateway.ChargeAsync(order.Total); // a retried request charges twice
}
```

Then state the trigger and outcome: “The client times out after the first charge and retries. Because the request has no idempotency key, the second call creates another charge.”

### Make critical paths complete

Avoid `...`, `/* implementation */`, or a comment where the teaching point should be. It is acceptable to omit unrelated UI markup or framework boilerplate, but code that demonstrates authorization, transactions, cancellation, retries, or concurrency must show the relevant check.

### Use realistic correctness boundaries

Examples should explicitly consider relevant boundaries:

- input validation and error mapping;
- tenant/resource authorization, not only authentication;
- cancellation and timeouts for I/O;
- transaction and concurrency behavior;
- retry safety and idempotency;
- secret and personal-data handling;
- logging without leaking sensitive data;
- metrics and traces for important failure paths;
- rollout and backward compatibility when contracts change.

Not every topic needs every boundary. Include the ones a production implementation cannot safely ignore.

### Prefer explicit assumptions

Capacity estimates are models, not facts. Write the assumption, unit, formula, result, and a sanity check.

```text
Assumption: 2,000,000 active users send 4 messages/day.
Average writes = 2,000,000 × 4 / 86,400 ≈ 93 writes/second.
Peak factor = 8, so plan for ≈ 744 writes/second before headroom.
Sanity check: changing messages/user/day from 4 to 40 changes the result by 10×.
```

Use decimal units (`kB`, `MB`, `GB`) for powers of 1000 and binary units (`KiB`, `MiB`, `GiB`) for powers of 1024.

## System-Design Answer Standard

A full design should cover:

1. scope, actors, and explicit non-goals;
2. functional and non-functional requirements;
3. scale assumptions and calculations;
4. API/events and error semantics;
5. data model, ownership, indexes, and retention;
6. high-level architecture and the critical read/write flows;
7. consistency, ordering, concurrency, and idempotency;
8. failure modes, recovery, backpressure, and degradation;
9. security, privacy, abuse prevention, and tenant isolation;
10. observability, SLOs, alerting, deployment, migration, and cost;
11. alternatives, trade-offs, and the next likely bottleneck.

Do not name a technology until the requirement that motivates it is clear. “Use Kafka” is not a design decision; “retain ordered events per order for replay while allowing independent consumer progress” is a requirement that may justify a log.

## Diagrams

Every arrow should have a meaning. Label important commands, events, protocols, or failure transitions. A diagram should help answer a question that prose alone makes difficult.

For a request path, show at least:

```text
caller → edge/auth → application → durable state → asynchronous side effects
```

For a failure path, show where the timeout occurs, what is retried, where deduplication happens, and how the system recovers.

## Terminology

- Define an acronym on first use: “service-level objective (SLO).”
- Distinguish authentication (who) from authorization (what this principal may do).
- Distinguish concurrency (overlapping work) from parallelism (simultaneous execution).
- Do not use “exactly once” without naming the boundary and mechanism.
- Prefer “at-least-once delivery with idempotent effects” when that is the real guarantee.
- Do not call eventual consistency a defect; state the convergence condition and acceptable staleness.
- Use “dependency injection” for supplying collaborators and “dependency inversion” for the design principle.

## Sources and Time-Sensitive Claims

- Prefer official documentation, standards, and original papers.
- Link to a source near the claim it supports.
- Label estimates and inferences as such.
- Company interview processes, compensation, cloud limits, framework versions, and product behavior change. Include an “as of” date or avoid presenting them as permanent facts.
- Explain external material in the repository’s own words and link to the original.

## Avoid Duplication

Keep one authoritative explanation and link to it from related guides. A short recap is useful only when it adapts the concept to a different context.

For example, define the transactional outbox deeply in [Distributed Systems Patterns](distributed-systems-patterns.md), show how ASP.NET Core registers its worker in [Backend Design Patterns](backend-design-patterns.md), and link the two instead of maintaining duplicate tutorials.

## Workbook Module Standard

A workbook is the practice layer for an existing guide, not a compressed copy of it. Organize it topic by topic and link to the authoritative explanation before asking the reader to apply the idea. A complete module should contain:

1. **Study links and a concept map** that name the prerequisite guide sections and show how the ideas relate.
2. **Four to six closed-book questions** that test explanation, comparison, debugging, design, and production judgment—not only definitions.
3. **A wrong/before example** that is complete enough to run or trace and that produces a concrete failure under stated conditions.
4. **A corrected/after example** using the same domain, inputs, and requirement so the reader can isolate what changed.
5. **A detailed answer key** that explains the mechanism, why the first approach fails, why the correction works, and which trade-offs remain.
6. **Production and failure checks** covering the relevant security, concurrency, data, performance, observability, deployment, and cost boundaries.
7. **A build or debugging task** with an observable success condition and evidence the learner can save.

A domain workbook should end with a cumulative capstone that combines several modules. Preserve the reference guides as the source of truth; extend or link them when a workbook reveals a missing explanation rather than maintaining two competing tutorials.

Do not make the answer key a collection of one-line definitions. A learner who completes a module should be able to explain the topic, implement it, find a broken implementation, choose when not to use it, and defend the decision in a design review.

## Review Checklist

- [ ] A beginner can state the main idea after the first paragraph.
- [ ] The problem and failure are concrete.
- [ ] Before and after examples use the same scenario.
- [ ] The relevant code path is complete and internally consistent.
- [ ] “How it works now” explains the mechanism rather than repeating the definition.
- [ ] Trade-offs and a simpler alternative are named.
- [ ] Relevant production concerns are covered.
- [ ] The exercise has an observable success condition.
- [ ] Links point to existing files and headings.
- [ ] Code fences are balanced.
- [ ] The same explanation is not duplicated elsewhere.
- [ ] `pwsh ./scripts/validate-docs.ps1` passes.

## Local Validation

Run:

```powershell
pwsh ./scripts/validate-docs.ps1
```

The validator checks local Markdown targets, section anchors, code-fence balance, obsolete custom-anchor syntax, trailing whitespace, discoverability of every top-level guide from `GUIDE-INDEX.md`, and the required labels in structured mastery and pattern sections (`HTML-M`, `EF-M`, `NGRX-M`, `TS-M`, `ASPF-M`, `ASPA-M`, `ASPX-M`, `TECH-M`, `AIE-M`, `INF-M`, `BDP`, `DSP`, and `DI`). It does not prove technical correctness; a human still needs to trace the examples and challenge their assumptions.
