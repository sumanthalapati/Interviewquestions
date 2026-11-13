# Start Here — From Reading to Engineering Mastery

This repository is a full-stack software engineering curriculum, not a list to memorize. Use it to build a mental model, write working code, explain trade-offs, and diagnose failures.

## Choose Your Path

| Your goal | Start with | Continue with | Prove mastery with |
|---|---|---|---|
| New to software interviews | [Entry-Level Questions](entry-level-questions.md) | [C#/.NET Core Guide](readme.md), [SQL Server](sql-server.md), [DSA](dsa.md) | Use the [Workbook Index](WORKBOOK-INDEX.md), then build a small CRUD API |
| Full-stack .NET + Angular | [C#/.NET Core Guide](readme.md) | [ASP.NET Core Fundamentals](aspnet-core-fundamentals.md), [Angular](angular.md), [TypeScript](typescript.md) | Complete the [.NET](dotnet-backend-workbook.md) and [frontend](frontend-engineering-workbook.md) capstones |
| Backend engineer | [ASP.NET Core Fundamentals](aspnet-core-fundamentals.md) | [API Design](api-design.md), [Backend Patterns](backend-design-patterns.md), [SQL Server](sql-server.md) | Complete the [.NET](dotnet-backend-workbook.md) and [SQL](sql-data-workbook.md) workbooks |
| System-design interviews | [System Design Interview Guide](system-design-interview-guide.md) | [Fundamentals](system-design-fundamentals-extended.md), [HLD](hld.md), [Extended Designs](system-design-extended.md) | Complete one [Systems Workbook](systems-engineering-workbook.md) module and a 45-minute mock |
| Distributed systems | [Technology Fundamentals](technologies-fundamentals.md) | [Distributed Patterns](distributed-systems-patterns.md), [Advanced Topics](advanced-topics.md), [Whitepapers](whitepapers-architecture-deep-dive.md) | Explain and test a failure/recovery path |
| Production readiness | [Production Scenarios](production-scenarios.md) | [Security](security.md), [Cloud & DevOps](cloud-devops.md), [PR Review](pr-review.md) | Complete the production modules in the [Systems Workbook](systems-engineering-workbook.md) |
| AI engineering | [AI in .NET](ai-dotnet.md) | [AI Engineering Design](ai-engineering-design.md), [AI System Design](ai-system-design.md) | Build an evaluated, observable RAG or tool workflow |
| Inference engineering | [AI Engineering Design](ai-engineering-design.md#aie-m3-transformer-shapes-attention-and-kv-state) | [Inference Engineering](inference-engineering.md), [AI System Design](ai-system-design.md) | Benchmark and operate a model server under an SLO |
| AI research and ML mathematics | [AI Mathematics & Research Workbook](ai-math-research-workbook.md) | [AI System Design](ai-system-design.md), [Inference Engineering](inference-engineering.md) | Derive, implement, reproduce, ablate, and publish one result |
| Company-focused preparation | [Company Interview Guides](company-specific-interview-guides.md) | [Company System Designs](companies-system-design.md), [Behavioral Mastery](behavioral-interview-mastery.md) | Complete one technical and one STAR mock |

The [Guide Index](GUIDE-INDEX.md) describes every file and helps you find a specific topic. Use the [Engineering Practice Workbook Index](WORKBOOK-INDEX.md) when you want topic-wise questions, detailed answer keys, wrong/correct code, failure checks, and build tasks for every major domain.

When you are ready to move from reading to implementation, use [Hands-On Engineering Labs](HANDS-ON-LABS.md). Each lab begins with a weak design, defines an invariant and fault model, and ends with observable acceptance criteria.

## The Mastery Loop

Use this loop for every question or pattern. Reading alone creates familiarity; the final steps create usable skill.

1. **Predict** — answer the question before reading.
2. **Understand the problem** — name the failure, coupling, or constraint the concept addresses.
3. **Trace the “before” code** — identify exactly where it fails and under what input or load.
4. **Rebuild the “after” solution** — type it without copying, then run or mentally trace it.
5. **Explain the mechanism** — describe how data, control, errors, and state move through the solution.
6. **Challenge it** — ask what happens during retries, concurrency, partial failure, malicious input, and deployment.
7. **Compare trade-offs** — state when the concept is useful, unnecessary, or dangerous.
8. **Recall later** — revisit after 1 day, 1 week, and 1 month.

Use the [lab mastery rubric](HANDS-ON-LABS.md#mastery-rubric) to distinguish recognizing a term from being able to implement, recover, and operate it.

### A 75-Minute Study Session

| Time | Activity | Output |
|---:|---|---|
| 10 min | Recall yesterday’s topics without notes | Gaps to revisit |
| 20 min | Study one new topic | A one-paragraph mental model |
| 20 min | Recreate the before/after example | Working or traceable code |
| 15 min | Add one failure case and one test | Evidence the design works |
| 10 min | Explain it aloud and record trade-offs | Interview-ready explanation |

## Recommended 12-Week Sequence

Adjust the pace, but preserve the dependency order.

| Week | Focus | Core guides | Deliverable |
|---:|---|---|---|
| 1 | Language and OOP foundations | [C#/.NET Core](readme.md), [OOP Patterns](oop-design-patterns.md) | Model a small domain with tests |
| 2 | SQL and persistence | [SQL Server](sql-server.md), [Entity Framework](entity-framework.md) | Transactional repository with concurrency handling |
| 3 | HTTP and APIs | [ASP.NET Core Fundamentals](aspnet-core-fundamentals.md), [API Design](api-design.md) | Validated, paginated REST API |
| 4 | Backend architecture | [Backend Patterns](backend-design-patterns.md), [Dependency Injection](dependency-injection.md) | Refactor a coupled use case |
| 5 | JavaScript and TypeScript | [JavaScript](javascript.md), [TypeScript](typescript.md) | Typed client with error mapping |
| 6 | Angular and reactive state | [Angular](angular.md), [RxJS](rxjs.md), [NgRx](ngrx.md) | Feature with loading/error/empty states |
| 7 | Testing and review | [Unit Testing](unit-testing.md), [PR Review](pr-review.md) | Test pyramid and written code review |
| 8 | System-design foundations | [Fundamentals](system-design-fundamentals-extended.md), [Interview Framework](system-design-interview-guide.md) | Capacity estimate and architecture sketch |
| 9 | Distributed systems | [Distributed Patterns](distributed-systems-patterns.md), [Advanced Topics](advanced-topics.md) | Failure-mode table for one workflow |
| 10 | Security and production | [Security](security.md), [Production Scenarios](production-scenarios.md) | Threat model, dashboards, and alerts |
| 11 | Cloud and delivery | [Cloud & DevOps](cloud-devops.md), [Azure DevOps](azure-devops.md) | Safe deployment and rollback plan |
| 12 | Mock interviews | [Company Guides](company-specific-interview-guides.md), [Behavioral Mastery](behavioral-interview-mastery.md) | Two timed mocks and a gap report |

## Three Capstones

### 1. Production Checkout

Build a checkout API and Angular page. Include validation, authorization, idempotency, transaction boundaries, an outbox, retries with jitter, observability, and tests. Use:

- [Angular frontend patterns](angular.md#frontend-design-patterns)
- [Backend design patterns](backend-design-patterns.md)
- [Dependency injection](dependency-injection.md)
- [Distributed systems patterns](distributed-systems-patterns.md)
- [Security](security.md)

### 2. Real-Time Collaboration

Design a collaborative document or whiteboard. Cover connection management, ordering, reconnects, conflict resolution, snapshots, permissions, presence, and regional failure. Use:

- [Real-Time Collaborative Systems](real-time-collaborative-systems.md)
- [Social and Messaging Infrastructure](social-messaging-infrastructure.md)
- [System Design Extended](system-design-extended.md)
- [Mobile System Design](mobile-system-design-extended.md)

### 3. Evaluated AI Assistant

Build a grounded assistant with retrieval, citations, tool authorization, prompt-injection defenses, evaluation datasets, cost limits, and tracing. Use:

- [AI in .NET](ai-dotnet.md)
- [AI Engineering Design](ai-engineering-design.md)
- [Inference Engineering](inference-engineering.md)
- [AI Mathematics & Research Workbook](ai-math-research-workbook.md)
- [AI System Design](ai-system-design.md)
- [Security Production Scenarios](security-production-scenarios.md)

## What “I Know This” Means

You have command of a topic when you can do all of the following without reading the answer:

- define it in plain language;
- name the concrete problem it solves;
- show the failing “before” design and predict its failure;
- implement or sketch the “after” design;
- explain how control, data, errors, and state move;
- name at least two trade-offs and one misuse;
- discuss testing, security, observability, and operations;
- adapt it to a new example rather than repeating the guide’s example.

If one item is missing, that is your next study task—not a reason to reread the whole chapter.

## Mock-Interview Method

For system design, use a 45-minute clock:

1. 0–5 minutes: clarify users, features, scale, and success criteria.
2. 5–10 minutes: estimate traffic, storage, and bandwidth with explicit assumptions.
3. 10–20 minutes: define APIs, data model, and the high-level flow.
4. 20–35 minutes: deepen the riskiest path—consistency, ordering, fan-out, or failure recovery.
5. 35–42 minutes: cover security, observability, deployment, and cost.
6. 42–45 minutes: summarize trade-offs and the next bottleneck.

For coding or framework questions, use the repository’s standard answer sequence: **question → answer → problem → before → failure → after → mechanism → trade-offs → production checks → exercise**.

## Keep a Gap Log

After each session, record only four things:

```text
Topic:
What I could not explain:
The smallest experiment that will resolve it:
Review dates: tomorrow / next week / next month
```

This turns a very large repository into a personal queue of small, testable learning tasks.
