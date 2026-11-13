# Engineering Practice Workbook Index

This is the practice companion to the repository's reference guides. The reference files explain concepts deeply; the workbooks make you retrieve, calculate, implement, debug, failure-test, and defend those concepts without copying an answer.

## Choose a Workbook

| Goal | Primary workbook | Continue with |
|---|---|---|
| C#, .NET, ASP.NET Core, APIs, EF Core, DI, backend patterns | [C#/.NET & Backend Workbook](dotnet-backend-workbook.md) | [SQL & Data Workbook](sql-data-workbook.md), [Systems Workbook](systems-engineering-workbook.md) |
| SQL Server, modeling, querying, indexing, concurrency, recovery, EF/Dapper | [SQL & Data Workbook](sql-data-workbook.md) | [C#/.NET & Backend Workbook](dotnet-backend-workbook.md) |
| HTML, CSS, JavaScript, TypeScript, Angular, RxJS, NgRx, browser production concerns | [Frontend Engineering Workbook](frontend-engineering-workbook.md) | [Systems Workbook](systems-engineering-workbook.md) |
| DSA, OOP/LLD, system design, distributed systems, security, cloud/DevOps, reliability, testing | [Systems & Software Engineering Workbook](systems-engineering-workbook.md) | [Hands-On Engineering Labs](HANDS-ON-LABS.md) |
| AI product engineering, RAG, retrieval, transformers, agents, tools, MCP, evaluation | [AI Engineering Design workbook sections](ai-engineering-design.md#ai-engineering-practice-workbook) | [AI Mathematics & Research Workbook](ai-math-research-workbook.md) |
| LLM inference, GPU/KV memory, batching, quantization, distributed serving, production and cost | [Inference Engineering Workbook](inference-engineering.md#topic-wise-practice-workbook) | [AI Mathematics & Research Workbook](ai-math-research-workbook.md) |
| ML mathematics, neural networks, transformers, RL, fine-tuning, MLOps, paper reproduction | [AI Mathematics & Research Workbook](ai-math-research-workbook.md) | [AI System Design](ai-system-design.md) |
| Integrated implementation and failure drills | [Hands-On Engineering Labs](HANDS-ON-LABS.md) | Any domain workbook above |

## The Workbook Loop

Use this loop for every module:

1. **Retrieve:** answer the questions without opening the guide.
2. **Explain:** describe the problem, invariant, before-state, corrected design, and trade-off aloud.
3. **Implement:** type the solution yourself; do not paste the example.
4. **Break it:** inject the named race, timeout, duplicate, stale read, invalid input, outage, or security failure.
5. **Observe:** identify the test, metric, log, trace, query plan, or profile that proves the cause.
6. **Recover:** demonstrate retry, rollback, replay, restore, reconciliation, or safe rejection.
7. **Teach:** explain the topic in simple language and answer one skeptical follow-up.
8. **Revisit:** repeat after one day, one week, and one month.

## Mastery Levels

| Level | Evidence |
|---:|---|
| 0 — Recognize | You recognize vocabulary only after seeing it. |
| 1 — Explain | You can explain the problem and main mechanism without notes. |
| 2 — Apply | You can select the concept for a new scenario and reject a tempting wrong choice. |
| 3 — Implement | You can write working code/query/configuration and focused tests. |
| 4 — Recover | You can inject failure and preserve or restore the invariant. |
| 5 — Operate | You can define SLOs, telemetry, security, capacity, rollout, cost, and trade-offs. |
| 6 — Teach | You can derive the idea, compare alternatives, and coach someone through a new case. |

Do not award yourself a level from reading. Keep evidence: code, tests, diagrams, plans, benchmark manifests, incident notes, or recordings.

## Topic Coverage Map

| Repository area | Workbook coverage |
|---|---|
| C# language, OOP, collections, LINQ, async, runtime, memory | .NET & Backend Workbook |
| ASP.NET Core, MVC, APIs, middleware, DI, auth, EF Core, testing | .NET & Backend Workbook |
| SQL Server syntax, modeling, windows/aggregation, pagination | SQL & Data Workbook |
| Plans, indexes, transactions, locking, procedures, recovery | SQL & Data Workbook |
| HTML/CSS, JavaScript/TypeScript, browser platform | Frontend Engineering Workbook |
| Angular, Signals, forms, router, RxJS, NgRx, frontend patterns | Frontend Engineering Workbook |
| DSA, OOP patterns, low-level and high-level design | Systems Workbook |
| Caching, load balancing, storage, queues, distributed patterns | Systems Workbook |
| Security, cloud, Kubernetes, CI/CD, Azure DevOps | Systems Workbook |
| Observability, incidents, testing, review, technical debt | Systems Workbook |
| Behavioral judgment and technical communication | Systems Workbook |
| AI engineering and inference | AI Engineering and Inference workbooks |
| ML mathematics, research, RL, fine-tuning, MLOps | AI Mathematics & Research Workbook |

## A Sustainable Weekly Rotation

| Day | Practice |
|---|---|
| Monday | One language/framework module and its code exercise |
| Tuesday | One SQL/data module with query-plan or concurrency exercise |
| Wednesday | One frontend or API integration module |
| Thursday | One system-design/distributed/security module |
| Friday | One AI/inference/math module or production diagnosis |
| Saturday | One integrated hands-on lab and failure injection |
| Sunday | Closed-book review, answer correction, and story/explanation recording |

Adjust the domain mix to your goals, but keep implementation, failure, and explanation in every week.

## Answering a Design Question

Use this structure until it becomes natural:

```text
1. Clarify users, functions, constraints, and what is out of scope.
2. State the invariant and required consistency/security behavior.
3. Estimate scale with units and uncertainty.
4. Draw the simplest end-to-end flow and name ownership.
5. Choose data/API/communication models from access and failure needs.
6. Walk one normal request and one failure timeline.
7. Add capacity, observability, rollout, recovery, and cost.
8. State trade-offs, rejected alternatives, and the next scaling threshold.
```

## Evidence Portfolio

By the end, keep at least:

- one production-style .NET/API project;
- one SQL performance and concurrency investigation;
- one accessible, tested frontend feature with state and cancellation;
- one distributed-system design with failure injection;
- one secure CI/CD rollout and rollback plan;
- one observability/incident report;
- one AI or inference evaluation/benchmark artifact if relevant;
- eight behavioral stories grounded in real evidence.

The goal is not to finish every question once. The goal is to produce enough repeated evidence that you can recognize, implement, diagnose, and explain the topic under unfamiliar conditions.
