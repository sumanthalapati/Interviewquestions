# SQL Server & Data Engineering Practice Workbook

Use this workbook after reading [SQL Server](sql-server.md), [Entity Framework Core](entity-framework.md), and the database sections of [System Design Fundamentals](system-design-fundamentals-extended.md). It is organized by topic, not difficulty labels. Work closed-book first, run the examples in a disposable database, inspect actual execution plans, and write down why an answer remains correct under concurrency and failure.

For every module:

1. Predict the result or failure before executing anything.
2. Explain the invariant the database must protect.
3. Repair the wrong/before example.
4. Verify the answer with data, plans, waits, or recovery evidence.
5. Record the trade-off rather than declaring one technique universally best.

## Workbook Index

1. [Relational modeling, normalization, constraints, and ownership](#1-relational-modeling-normalization-constraints-and-ownership)
2. [SQL semantics: NULL, joins, sets, and aggregates](#2-sql-semantics-null-joins-sets-and-aggregates)
3. [CTEs, window functions, ROLLUP, CUBE, and GROUPING](#3-ctes-window-functions-rollup-cube-and-grouping)
4. [TOP, OFFSET-FETCH, and keyset pagination](#4-top-offset-fetch-and-keyset-pagination)
5. [Indexes, SARGability, plans, and statistics](#5-indexes-sargability-plans-and-statistics)
6. [Transactions, isolation, locking, deadlocks, and row versioning](#6-transactions-isolation-locking-deadlocks-and-row-versioning)
7. [Concurrency, idempotency, durable work, and outbox processing](#7-concurrency-idempotency-durable-work-and-outbox-processing)
8. [Stored procedures, functions, triggers, and temporary structures](#8-stored-procedures-functions-triggers-and-temporary-structures)
9. [Partitioning, replication, and sharding](#9-partitioning-replication-and-sharding)
10. [Backup, recovery, integrity, and security](#10-backup-recovery-integrity-and-security)
11. [Performance diagnosis and production operations](#11-performance-diagnosis-and-production-operations)
12. [EF Core, Dapper, and production data-access scenarios](#12-ef-core-dapper-and-production-data-access-scenarios)

---

## 1. Relational Modeling, Normalization, Constraints, and Ownership

### Concept map

- A table models one kind of fact at one declared grain.
- A primary/candidate key identifies one fact; a foreign key preserves references.
- `NOT NULL`, `CHECK`, `UNIQUE`, and foreign keys protect invariants for every writer, not only one API.
- Normalization removes update anomalies; deliberate denormalization duplicates data only with an owner and repair path.
- Natural keys express domain identity; surrogate keys simplify references but do not replace domain uniqueness.
- Temporal/audit/history requirements should be designed, not inferred from `UpdatedAt`.

### Wrong/before design

```sql
CREATE TABLE Orders
(
    OrderID        int IDENTITY PRIMARY KEY,
    CustomerName   nvarchar(200),
    CustomerEmail  nvarchar(320),
    ProductIDsCsv  varchar(max),
    QuantitiesCsv  varchar(max),
    Total          decimal(18,2),
    Status         varchar(30)
);
```

One row mixes order, customer, and repeated line facts. CSV fields cannot enforce product references or quantity constraints. Customer changes require inconsistent mass updates, and `Total`/`Status` accept impossible values.

### Corrected/after design

```sql
CREATE TABLE Customers
(
    CustomerID bigint IDENTITY CONSTRAINT PK_Customers PRIMARY KEY,
    Email nvarchar(320) NOT NULL,
    DisplayName nvarchar(200) NOT NULL,
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);

CREATE TABLE Products
(
    ProductID bigint IDENTITY CONSTRAINT PK_Products PRIMARY KEY,
    SKU nvarchar(64) NOT NULL,
    DisplayName nvarchar(200) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Products_IsActive DEFAULT (1),
    CONSTRAINT UQ_Products_SKU UNIQUE (SKU)
);

CREATE TABLE Orders
(
    OrderID bigint IDENTITY CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerID bigint NOT NULL,
    Status varchar(20) NOT NULL,
    Total decimal(18,2) NOT NULL,
    CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT sysutcdatetime(),
    RowVersion rowversion NOT NULL,
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT CK_Orders_Status CHECK (Status IN ('Pending','Paid','Cancelled','Shipped')),
    CONSTRAINT CK_Orders_Total CHECK (Total >= 0)
);

CREATE TABLE OrderLines
(
    OrderID bigint NOT NULL,
    LineNumber smallint NOT NULL,
    ProductID bigint NOT NULL,
    Quantity int NOT NULL,
    UnitPrice decimal(18,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderID, LineNumber),
    CONSTRAINT FK_OrderLines_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    CONSTRAINT CK_OrderLines_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderLines_UnitPrice CHECK (UnitPrice >= 0)
);
```

`UnitPrice` is an intentional historical snapshot owned by the order line; it need not follow a later catalogue price. `Orders.Total` is also a financial snapshot used by later examples. The transaction that finalizes pricing must own how line amounts, discounts, tax, shipping, and rounding produce it, and reconciliation should detect drift rather than assuming it always equals a simple line sum.

### Practice questions

1. Why is a surrogate `CustomerID` insufficient to prevent two accounts with the same email when email is the business identity?
2. An address appears in `Customers`, `Orders`, and `Shipments`. Is that always bad denormalization?
3. When should deletion be restricted, cascaded, soft-deleted, or anonymized?
4. Why is an application-only enum validation weaker than a `CHECK` constraint?
5. What is the grain of an inventory-balance table, and which key follows from it?

### Detailed answer key

1. Surrogates guarantee only row identity. Add a domain uniqueness constraint on a normalized email value if the domain guarantees uniqueness; otherwise model identity separately. Decide collation/case, normalization, reassignment, and deleted-account reuse explicitly.
2. Not always. Customer address is current profile data; order billing/shipping address may be an immutable commercial snapshot; shipment address is the operational destination. Duplication is valid when semantics and ownership differ. Reusing one mutable address row could rewrite history.
3. Restrict when dependents make deletion invalid; cascade only when dependents have no independent lifecycle; soft-delete when operational recovery/query semantics justify it; anonymize or purge according to retention/privacy obligations. Every choice needs indexes, query filters, restore behavior, and tests.
4. Other applications, scripts, imports, and future code can bypass the API. A database constraint is the final shared invariant. Application validation still improves messages and avoids needless round trips.
5. First declare whether one row means `(Warehouse, Product)`, `(Warehouse, Bin, Product)`, or `(Warehouse, Product, Lot)`. The candidate key contains exactly those dimensions. A vague `InventoryID` does not prevent duplicate balances at the intended grain.

### Production and failure checks

- Load representative duplicates and invalid boundaries to prove constraints fail.
- Document every duplicated field's source, refresh rule, and reconciliation path.
- Index foreign keys used for joins/deletes to avoid large scans and blocking.
- Plan zero-downtime constraint introduction: find/repair invalid rows before trusting it.
- Treat migrations as deployments with forward/backward compatibility and rollback strategy.

### Build task

Model a subscription product with customers, plans, plan versions, subscriptions, invoices, payments, and refunds. Write the grain and invariant for every table before DDL. Add five deliberately invalid inserts and prove the database rejects them.

---

## 2. SQL Semantics: NULL, Joins, Sets, and Aggregates

### Concept map

- SQL uses three-valued logic: comparisons with `NULL` are unknown, not true/false.
- `WHERE` retains only true predicates; `UNKNOWN` is removed.
- An outer join can accidentally become an inner join when a right-side predicate is placed in `WHERE`.
- `EXISTS`/`NOT EXISTS` express semi/anti joins and avoid `NOT IN` null traps.
- `UNION` removes duplicates; `UNION ALL` preserves them and usually does less work.
- `COUNT(*)`, `COUNT(column)`, and `COUNT(DISTINCT column)` answer different questions.

### Wrong/before query

```sql
-- Intended: all customers, plus their paid orders if any.
SELECT c.CustomerID, o.OrderID
FROM Customers AS c
LEFT JOIN Orders AS o ON o.CustomerID = c.CustomerID
WHERE o.Status = 'Paid';
```

Rows without an order have `o.Status = NULL`; the `WHERE` predicate is unknown, so they disappear.

### Corrected/after query

```sql
SELECT c.CustomerID, o.OrderID
FROM Customers AS c
LEFT JOIN Orders AS o
  ON o.CustomerID = c.CustomerID
 AND o.Status = 'Paid';

-- Customers with no orders: NULL-safe anti semi join.
SELECT c.CustomerID
FROM Customers AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM Orders AS o
    WHERE o.CustomerID = c.CustomerID
);
```

### Practice questions

1. What does `WHERE Col <> 5` do with `NULL`, and how would you include nulls deliberately?
2. Why can `NOT IN (SELECT NullableColumn ...)` unexpectedly return no rows?
3. When does replacing `UNION` with `UNION ALL` change correctness?
4. Explain the difference between `COUNT(*)`, `COUNT(ManagerID)`, and `COUNT(DISTINCT ManagerID)`.
5. Why can joining two one-to-many children before aggregating overcount both sides?

### Detailed answer key

1. `NULL <> 5` is unknown, so the row is filtered. Use `Col <> 5 OR Col IS NULL` only if null semantically belongs. Do not use `COALESCE` to a magic value that may collide or harm SARGability without justification.
2. If the subquery contains `NULL`, `x NOT IN (...)` requires proving `x` differs from every element, including the unknown comparison. The result is unknown. Prefer correlated `NOT EXISTS` or guarantee/filter non-null values.
3. If duplicates represent distinct source facts or are acceptable, `UNION ALL` is correct and avoids deduplication. If the business result is a mathematical set requiring duplicates removed, it changes semantics. Do not use `UNION` to hide an incorrect join.
4. `COUNT(*)` counts rows; `COUNT(ManagerID)` counts non-null manager IDs; `COUNT(DISTINCT ManagerID)` counts unique non-null manager IDs. Aggregates such as `AVG` also ignore nulls unless explicitly transformed.
5. A customer with 3 orders and 4 tickets becomes 12 joined rows. Aggregate each child to customer grain first, use correlated aggregates, or otherwise control the grain before combining results.

### Production and failure checks

- Seed nulls and duplicate keys in query tests; idealized data hides semantic errors.
- State output grain before writing joins and assert row counts/uniqueness.
- Inspect actual plans for unnecessary sorts/hash aggregates caused by accidental `DISTINCT`/`UNION`.
- Avoid `SELECT *`; schema additions can change bandwidth, mappings, and duplicate column behavior.
- Use decimal types and explicit divide-by-zero/null policies for financial aggregates.

### Build task

Create Customers, Orders, Payments, and SupportTickets with missing/duplicate relationships. Write and test: customers with no orders, latest successful payment, revenue per customer without multiplication, and a complete customer list with paid-order count including zero.

---

## 3. CTEs, Window Functions, ROLLUP, CUBE, and GROUPING

### Concept map

- A CTE names a query expression for one statement; it is not automatically materialized.
- Recursive CTEs need an anchor, progress, termination, and cycle/depth strategy.
- Window functions retain detail rows while computing across partitions.
- `ROW_NUMBER`, `RANK`, and `DENSE_RANK` differ at ties.
- Window frames matter: default `RANGE` can include peers unexpectedly.
- `ROLLUP` produces hierarchical prefixes, `CUBE` all combinations, and `GROUPING SETS` selected combinations.
- `GROUPING()` distinguishes real nulls from subtotal placeholders; `GROUPING_ID()` labels levels.

### Wrong/before query

```sql
-- Wrong for a physical 3-row moving average: default frame semantics are implicit.
SELECT SaleDate, Amount,
       AVG(Amount) OVER (ORDER BY SaleDate) AS MovingAverage
FROM Sales;
```

This is a running average, and duplicate dates may be peers under the default `RANGE` frame.

### Corrected/after query

```sql
SELECT SaleID, SaleDate, Amount,
       AVG(Amount) OVER
       (
           ORDER BY SaleDate, SaleID
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS MovingAverage3Rows
FROM Sales;

SELECT
    CASE WHEN GROUPING(Region) = 1 THEN 'ALL REGIONS'
         ELSE COALESCE(Region, '(Unknown region)') END AS RegionLabel,
    CASE WHEN GROUPING(Product) = 1 THEN 'ALL PRODUCTS'
         ELSE COALESCE(Product, '(Unknown product)') END AS ProductLabel,
    SUM(Amount) AS TotalAmount,
    GROUPING_ID(Region, Product) AS GroupingLevel
FROM Sales
GROUP BY CUBE(Region, Product);
```

### Practice questions

1. Choose `ROW_NUMBER`, `RANK`, or `DENSE_RANK` for “top three distinct salary levels” and explain ties.
2. Why is a CTE referenced twice not guaranteed to compute once?
3. What rows does `ROLLUP(Year, Quarter, Month)` produce, and why does column order matter?
4. Why is `COALESCE(Region,'ALL')` insufficient to label cube totals?
5. How do you protect a recursive hierarchy query from cycles?
6. For `GROUPING_ID(Region, Product)`, what do values 0, 1, 2, and 3 mean?

### Detailed answer key

1. `DENSE_RANK` gives tied salaries the same rank without gaps, so filtering `<=3` returns three salary levels (possibly more than three employees). `ROW_NUMBER` returns at most three rows per partition and arbitrarily splits ties unless deterministic tie-breakers exist. `RANK` preserves competition-ranking gaps, so filtering `<=3` can return fewer than three distinct salary levels.
2. A CTE is syntax for a relational expression; the optimizer can inline/re-evaluate/spool it. If reuse cost/plan stability matters, test a temp table with suitable statistics/indexes rather than assuming materialization.
3. `(Year,Quarter,Month)`, `(Year,Quarter)`, `(Year)`, and `()` grand total. Reordering changes the prefix hierarchy and therefore subtotal semantics.
4. A source row can have a genuine null region. Only `GROUPING(Region)=1` says the column was aggregated away. Collapsing both meanings corrupts reporting.
5. Enforce acyclic data if possible; carry a visited path/key set for diagnostic queries, make each recursion progress, cap depth with a justified `MAXRECURSION`, and investigate rather than merely hiding a cycle.
6. SQL Server assigns the lowest-order bit to the last argument. Therefore 0 means a detail row; 1 means `Product` was aggregated away, so it is a region subtotal; 2 means `Region` was aggregated away, so it is a product subtotal; and 3 means both were aggregated away, so it is the grand total. The numbers change if argument order changes, so expose a named level rather than leaking an unexplained integer to consumers.

### Production and failure checks

- Always make window ordering deterministic with a unique tie-breaker when row order matters.
- Specify `ROWS`/`RANGE` frames explicitly for cumulative/moving calculations.
- Watch sorts, spills, memory grants, and indexes aligned with partition/order columns.
- Use `GROUPING SETS` instead of an exponential cube when only selected totals are needed.
- Validate recursive queries on deep, orphaned, and cyclic data.

### Build task

Using an employee hierarchy and regional sales data, produce: reporting paths with depth, top-two earners per department including ties, month-over-month change, a three-month moving total, and selected region/product/grand totals safely labeled with `GROUPING`.

---

## 4. TOP, OFFSET-FETCH, and Keyset Pagination

### Concept map

- `TOP` limits rows; `ORDER BY` makes “which rows” deterministic.
- `WITH TIES` intentionally returns all rows sharing the boundary sort value.
- `OFFSET ... FETCH` supports numbered pages but processes/discards earlier rows and can drift under writes.
- Keyset pagination seeks after the last unique ordered key and scales better for next-page traversal.
- Pagination ordering must be total and stable; append a unique tie-breaker.
- DML `TOP` does not define affected order; select an ordered batch in a CTE/subquery.

### Wrong/before query

```sql
SELECT ProductID, Name, Price
FROM Products
ORDER BY Price DESC
OFFSET (@Page - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;
```

Equal prices have no deterministic order, deep pages grow expensive, and inserts/deletes can shift positions between requests.

### Corrected/after query

```sql
-- Cursor contains the final row's Price and ProductID.
SELECT TOP (@PageSize)
       ProductID, Name, Price
FROM Products
WHERE Price < @LastPrice
   OR (Price = @LastPrice AND ProductID > @LastProductID)
ORDER BY Price DESC, ProductID ASC;

-- Ordered maintenance batch.
WITH Batch AS
(
    SELECT TOP (@BatchSize) *
    FROM AuditEvents
    WHERE IsArchived = 1
    ORDER BY CreatedAt, AuditEventID
)
DELETE FROM Batch;
```

### Practice questions

1. When is `OFFSET-FETCH` preferable to keyset pagination?
2. Why must a keyset predicate mirror mixed ASC/DESC ordering?
3. What does `TOP (10) WITH TIES ... ORDER BY Score DESC` guarantee and not guarantee?
4. How can `@PageSize + 1` avoid a separate full count?
5. Why can an opaque cursor still need signing or validation?

### Detailed answer key

1. Small/stable administrative data and direct “jump to page N” requirements fit offsets. Keyset fits next/previous navigation, infinite scroll, large/changing tables, and bounded seek work.
2. The “after” relation is lexicographic in the declared directions. For `Price DESC, ID ASC`, later means lower price or equal price with higher ID. A mismatched comparator skips/duplicates rows.
3. It includes every row tied on the specified order expression with the tenth row, so result count may exceed ten. Ordering among equal-score rows remains unspecified unless another key is added—but adding a unique key removes ties for `WITH TIES` purposes.
4. Fetch one extra row; return only `PageSize` and set `hasMore` if the extra exists. This does not provide total pages but avoids an often costly/unstable count.
5. Clients can alter sort/filter/tenant values or forge state. Encode the complete query position/filter identity, validate bounds/version, and sign/encrypt when integrity/confidentiality is required.

### Production and failure checks

- Cap page size and validate page/cursor inputs.
- Index filter plus order keys and include projected columns only when the write/storage trade-off is justified.
- Bind filters and sort-version metadata to a validated, integrity-protected cursor so it cannot be reused for a different query.
- Test equal sort values, inserted/deleted rows between requests, and reverse navigation.
- Remember that keyset pagination avoids offset shifting; it does not freeze a snapshot. Define behavior when rows are inserted, deleted, or have their sort key changed between requests.
- Define null ordering explicitly and encode it in the predicate/cursor; ordinary `<`, `>`, and `=` comparisons do not seek past `NULL` values.
- Measure logical reads and p99 latency at shallow/deep offsets and keyset positions.

### Build task

Implement an orders endpoint sorted by `CreatedAt DESC, OrderID DESC` using offset and signed keyset cursors. Insert and delete rows between page calls, compare duplicates/misses, inspect plans/logical reads at page 1 and page 10,000, and document which API semantics you choose.

---

## 5. Indexes, SARGability, Plans, and Statistics

### Concept map

- A clustered index keeps its leaf level logically ordered by key; it does not guarantee contiguous files or query result order without `ORDER BY`. Nonclustered indexes contain keys plus row locators and included columns.
- Composite key order follows equality, then useful range/order patterns—not a universal selectivity slogan.
- SARGable predicates let the optimizer seek meaningful key ranges.
- Included columns cover output without changing navigation order.
- Statistics estimate cardinality; poor estimates distort join, memory, and access choices.
- A plan is a costed strategy for one compilation context, not proof of universal performance.

### Wrong/before query and index

```sql
CREATE INDEX IX_Orders_CustomerID ON Orders(CustomerID);

SELECT OrderID, CreatedAt, Total
FROM Orders
WHERE YEAR(CreatedAt) = @Year
  AND CustomerID = @CustomerID
ORDER BY CreatedAt DESC;
```

Without a matching indexed computed column, the function on `CreatedAt` normally prevents a direct seek on the underlying date range; the shown index also does not align fully with filter/order/output.

### Corrected/after query and candidate index

```sql
DECLARE @Start datetime2(0) = DATETIMEFROMPARTS(@Year,1,1,0,0,0,0);
DECLARE @End   datetime2(0) = DATEADD(year, 1, @Start);

SELECT OrderID, CreatedAt, Total
FROM Orders
WHERE CustomerID = @CustomerID
  AND CreatedAt >= @Start
  AND CreatedAt <  @End
ORDER BY CreatedAt DESC;

CREATE INDEX IX_Orders_Customer_Created
ON Orders(CustomerID, CreatedAt DESC)
INCLUDE (Total); -- OrderID is already the clustered key/row locator in this schema.
```

The candidate must still be tested against write rate, existing overlap, row width, and actual plans.

### Practice questions

1. Why is “put the most selective column first” incomplete index advice?
2. Distinguish seek predicate, residual predicate, key lookup, scan, and covering index.
3. How can stale/skewed statistics create a bad join or memory grant?
4. What is parameter sniffing, and why is `OPTION(RECOMPILE)` not a universal fix?
5. Why can adding every selected column as `INCLUDE` be harmful?

### Detailed answer key

1. Index order must support equality prefixes, ranges, joins, and required ordering across important queries. A highly selective range first can prevent later keys being seekable; an equality tenant key first can isolate data/order effectively. Measure workload, not one query.
2. A seek predicate navigates index ranges; residual filtering tests rows after navigation. A lookup fetches missing columns from the base/clustered structure per qualifying row. A scan reads a broad index/table range and may be correct for large result sets. Covering avoids lookups for a query.
3. The optimizer may expect 10 rows but receive 10 million, choosing nested loops/lookups and a tiny memory grant that spills. Or it may overestimate and reserve excess memory/reduce concurrency. Skew and correlated columns challenge single-column histograms.
4. Compilation uses parameter values to estimate/select a reusable plan; a plan good for rare values may fail for common values. Recompile adapts each execution but costs CPU and plan-cache benefits. Alternatives include query redesign, appropriate indexes/stats, `OPTIMIZE FOR`, plan variants, or separate paths based on measured distributions.
5. Wider indexes consume storage/memory/cache, increase every write/log/maintenance cost, lengthen build/recovery, and can duplicate existing indexes. Cover only valuable stable paths.

### Production and failure checks

- Capture actual rows versus estimates at key operators.
- Use `SET STATISTICS IO, TIME ON` in safe test contexts and Query Store/DMVs in production.
- Check sorts/hash spills, lookup counts, implicit conversions, residual predicates, and memory grants.
- Review duplicate/overlapping/unused indexes before adding another.
- Reproduce with representative parameter distributions and production-like data volume.

### Build task

Generate an Orders table with skewed customers and dates. Create three competing indexes, compare plans/reads/latency for rare/common customers, force stale statistics, repair them, and write an index decision record including write amplification and rollback.

---

## 6. Transactions, Isolation, Locking, Deadlocks, and Row Versioning

### Concept map

- A transaction protects an invariant across a bounded set of operations.
- Isolation levels control which concurrent phenomena are possible; they do not fix missing predicates or invariants.
- Locks coordinate conflicting access; lock duration/scope and access order drive blocking/deadlocks.
- Deadlocks are cycles; SQL Server chooses a victim. Applications should use a bounded retry only when the whole operation is safe to repeat, otherwise surface or compensate for the failure.
- Read committed snapshot supplies a committed version per statement; snapshot isolation supplies a transaction-level snapshot and can raise update conflicts. Both consume version-store resources, while writers still coordinate with locks.
- `XACT_ABORT`, `TRY/CATCH`, `XACT_STATE`, and short transactions make failure cleanup explicit.

### Wrong/before transaction

```sql
BEGIN TRANSACTION;

SELECT @Balance = Balance
FROM Accounts
WHERE AccountID = @From;

IF @Balance >= @Amount
BEGIN
    UPDATE Accounts SET Balance = Balance - @Amount WHERE AccountID = @From;
    WAITFOR DELAY '00:00:10'; -- remote API call while locks/transaction remain open
    UPDATE Accounts SET Balance = Balance + @Amount WHERE AccountID = @To;
END

COMMIT;
```

It has unclear error rollback, long lock duration, external work inside the transaction, and concurrent invariant risks.

### Corrected/after pattern

```sql
SET XACT_ABORT ON;

IF @Amount <= 0 THROW 50000, 'Transfer amount must be positive', 1;
IF @From = @To THROW 50000, 'Source and destination must differ', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Separate point lookups enforce acquisition order. An ORDER BY on one
    -- multi-row SELECT would sort output, but would not prove lock order.
    DECLARE @LockedBalance decimal(19,4);

    IF @From < @To
    BEGIN
        SELECT @LockedBalance = Balance
        FROM Accounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @From;
        IF @@ROWCOUNT <> 1 THROW 50002, 'Source account missing', 1;

        SELECT @LockedBalance = Balance
        FROM Accounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @To;
        IF @@ROWCOUNT <> 1 THROW 50002, 'Destination account missing', 1;
    END
    ELSE
    BEGIN
        SELECT @LockedBalance = Balance
        FROM Accounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @To;
        IF @@ROWCOUNT <> 1 THROW 50002, 'Destination account missing', 1;

        SELECT @LockedBalance = Balance
        FROM Accounts WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountID = @From;
        IF @@ROWCOUNT <> 1 THROW 50002, 'Source account missing', 1;
    END

    UPDATE Accounts
    SET Balance = Balance - @Amount
    WHERE AccountID = @From
      AND Balance >= @Amount;

    IF @@ROWCOUNT <> 1 THROW 50001, 'Insufficient funds or account missing', 1;

    UPDATE Accounts SET Balance = Balance + @Amount WHERE AccountID = @To;
    IF @@ROWCOUNT <> 1 THROW 50002, 'Destination account missing', 1;

    INSERT Outbox(EventType, Payload) VALUES ('TransferCommitted', @Payload);
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
```

External communication happens after commit through the outbox.

### Practice questions

1. Explain dirty, non-repeatable, phantom, lost-update/write-skew risks and which are relevant to an invariant.
2. Why can snapshot isolation reduce read blocking yet still produce update conflicts or write skew?
3. What makes a deadlock different from ordinary blocking?
4. Why should transactions avoid user input and network calls?
5. When is `NOLOCK` an invalid “performance fix”?

### Detailed answer key

1. Dirty reads observe uncommitted work; non-repeatable reads see a row change; phantoms see matching rows appear/disappear; lost updates overwrite concurrent decisions; write skew lets transactions update different rows while jointly breaking an invariant. Isolation choice follows the specific read/write predicate and invariant.
2. Ordinary reads use committed row versions rather than shared row/page data locks, although schema and other locks still exist; writers continue to coordinate with locks. Two snapshots can each observe an invariant as true and update disjoint rows so the combined result is false unless constraints, explicit locking, or serializable execution protect the predicate.
3. Blocking is a wait chain that can progress when a holder finishes. A deadlock is a cycle where no participant can progress, so the engine aborts one. Capture the graph, establish consistent access order, shorten work, index predicates, and implement bounded retry.
4. They make lock duration unbounded and hold scarce log/version/connection resources. Gather/validate beforehand; persist the atomic decision quickly; perform external effects asynchronously or with an explicit protocol.
5. It allows dirty, missing, duplicated, and internally inconsistent reads and can still block on schema locks. Use it only when those semantics are explicitly acceptable—not for money, inventory, or “make blocking disappear.” Fix queries/indexes/transaction scope or select appropriate row-versioning semantics.

### Production and failure checks

- Name the invariant and prove the transaction/constraint protects it under concurrent tests.
- Capture blocking/deadlock graphs, not screenshots of “slow query.”
- Keep transactions short and ensure every error path rolls back/disposes.
- Monitor transaction log, version store, long transactions, lock waits/escalation, and deadlock rate.
- Retry only entire idempotent units with jitter/bounds; do not retry an unknown partial external effect blindly.

### Build task

Run two concurrent transfer/booking sessions that deadlock or oversell under a naive design. Capture evidence, implement ordered locking or optimistic concurrency plus retry, and prove the invariant under a parallel test harness.

---

## 7. Concurrency, Idempotency, Durable Work, and Outbox Processing

### Concept map

- Optimistic concurrency detects changed versions; pessimistic locking prevents conflicting progress.
- Idempotency binds a caller key to request identity and a durable result, not merely “check then insert.”
- Unique constraints close races that application prechecks cannot.
- A durable SQL queue needs claim/lease, attempts, visibility, recovery, idempotent effects, and poison handling.
- The transactional outbox atomically records business state and an event to publish later.
- At-least-once delivery means consumers must deduplicate effects or make them naturally idempotent.

### Wrong/before claim

```sql
SELECT TOP (1) @JobID = JobID
FROM Jobs
WHERE Status = 'Pending'
ORDER BY CreatedAt;

UPDATE Jobs SET Status = 'Processing' WHERE JobID = @JobID;
```

Two workers can select the same job before either update commits.

### Corrected/after atomic lease claim

```sql
DECLARE @Now datetime2(3) = sysutcdatetime();
DECLARE @LeaseToken uniqueidentifier = NEWID();

;WITH Candidate AS
(
    SELECT TOP (1) *
    FROM Jobs WITH (UPDLOCK, READPAST, READCOMMITTEDLOCK)
    WHERE (Status = 'Pending' AND AvailableAt <= @Now)
       OR (Status = 'Processing' AND LeaseExpiresAt < @Now)
    ORDER BY AvailableAt, JobID
)
UPDATE Candidate
SET Status = 'Processing',
    LeaseOwner = @WorkerID,
    LeaseToken = @LeaseToken,
    LeaseExpiresAt = DATEADD(second, @LeaseSeconds, @Now),
    Attempts = Attempts + 1
OUTPUT inserted.JobID, inserted.LeaseOwner, inserted.LeaseToken,
       inserted.LeaseExpiresAt, inserted.Attempts;
```

`READCOMMITTEDLOCK` makes the lock-based claim explicit when read-committed snapshot is enabled; confirm the database isolation configuration because SQL Server restricts some `READPAST` combinations. It is intentionally not combined with `ROWLOCK`: SQL Server permits only one hint from the granularity group, and `READCOMMITTEDLOCK` and `ROWLOCK` are both members. `READPAST` skips row/key locks rather than page locks, so the claim can still block. Completion and renewal must fence stale owners, for example with `WHERE JobID = @JobID AND LeaseOwner = @WorkerID AND LeaseToken = @LeaseToken AND Status = 'Processing'`.

The statement makes claiming atomic, not execution exactly once. Lease expiry deliberately permits another worker to run the job after a crash, so business effects still need an idempotency key or an atomic processed-message record. Index and test the claim predicates, and measure starvation because repeatedly skipped or low-priority rows can wait indefinitely under sustained load.

### Practice questions

1. Why is “SELECT then INSERT if absent” insufficient idempotency?
2. What should happen when an idempotency key is reused with a different request body?
3. How does an outbox remove the database-plus-broker dual-write gap, and what does it not solve?
4. Why must expired processing leases be reclaimable?
5. How does a consumer prevent an email/payment effect from repeating after a crash before acknowledgement?

### Detailed answer key

1. Concurrent requests can both observe absence. Use a unique key and atomic transaction/upsert semantics; store a request fingerprint, state, and result. Handle uncertain in-progress ownership/timeouts explicitly.
2. Reject it as a conflict because the key identifies one logical operation. Returning the first result for a different payload hides a caller bug or attack.
3. Business state and the outbox row commit in the same local database transaction; a relay publishes later with retry. A crash after publish but before recording success causes another publish, so this closes the lost-event dual-write gap but does not provide exactly-once broker delivery, ordering across arbitrary aggregates, schema compatibility, or idempotent consumer effects.
4. A worker can die after claiming. Without lease expiry/recovery the job is stuck forever. Recovery must prevent an old worker completing after a new owner, typically via owner/token/version checks.
5. For a local database effect, insert a unique processed-message key and apply the state change in the same transaction. For an external payment or email, send a stable effect/idempotency key to a provider that deduplicates, or query/reconcile the provider before retrying; a local “sent” flag alone cannot atomically close the network gap. Acknowledge only after a durable outcome, and accept that an external receiver without deduplication cannot be made exactly-once by the consumer alone.

### Production and failure checks

- Unique constraints back every deduplication assumption.
- Hash/canonicalize request identity carefully and store durable response/status.
- Monitor oldest pending age, expired leases, attempts, poison/DLQ age, and outbox lag.
- Test crash before/after claim, effect, commit, publish, and acknowledgement.
- Fence stale lease owners and make retry/backoff/cancellation/dead-letter ownership explicit.

### Build task

Implement `POST /orders` idempotency, an order/outbox transaction, a lease-based SQL relay, and an idempotent consumer. Inject a crash at every boundary and prove ten retries yield one order and one logical downstream effect.

---

## 8. Stored Procedures, Functions, Triggers, and Temporary Structures

### Concept map

- Stored procedures encapsulate database operations, permissions, transaction boundaries, and result contracts.
- Scalar/multi-statement functions can hide per-row work/cardinality limitations; inline TVFs compose more naturally.
- Triggers execute per statement, not per row, and receive multi-row `inserted`/`deleted` sets.
- Temp tables have statistics/indexes and session scope; table variables differ by version/use; CTEs are statement expressions.
- Dynamic SQL must parameterize values and safely quote unavoidable identifiers.
- `SET NOCOUNT ON`, explicit columns/types, and stable result/error contracts matter to clients.

### Wrong/before trigger and dynamic SQL

```sql
CREATE TRIGGER trg_OrderAudit ON Orders AFTER UPDATE AS
BEGIN
    DECLARE @ID bigint = (SELECT OrderID FROM inserted); -- fails for multi-row update
    INSERT OrderAudit(OrderID, ChangedAt) VALUES (@ID, GETDATE());
END;

EXEC('SELECT * FROM Orders WHERE CustomerID = ' + @CustomerInput);
```

### Corrected/after set-based and parameterized form

```sql
CREATE OR ALTER TRIGGER trg_OrderAudit ON Orders AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT OrderAudit(OrderID, OldStatus, NewStatus, ChangedAt)
    SELECT i.OrderID, d.Status, i.Status, sysutcdatetime()
    FROM inserted AS i
    JOIN deleted  AS d ON d.OrderID = i.OrderID
    WHERE i.Status <> d.Status;
END;

DECLARE @sql nvarchar(max) =
    N'SELECT OrderID, Status FROM Orders WHERE CustomerID = @CustomerID;';
EXEC sys.sp_executesql @sql, N'@CustomerID bigint', @CustomerID=@CustomerID;
```

### Practice questions

1. When is an inline TVF preferable to a stored procedure or scalar function?
2. Why should trigger code assume zero/many rows, and how can triggers cause hidden recursion/contention?
3. Choose CTE, temp table, or table variable for a large intermediate reused three times.
4. Which parts of dynamic SQL can be parameters, and how are dynamic identifiers handled?
5. Why should a procedure not rely on implicit transaction ownership or undocumented result shapes?

### Detailed answer key

1. An inline TVF returns a relational expression that callers can join/filter and the optimizer can often integrate. Procedures are better for commands/multiple results/controlled transactions. Scalar functions suit small deterministic computations only after testing execution behavior.
2. One statement can affect thousands of rows or none. Scalar assumptions fail. Triggers extend the original transaction, can lock more data, recurse/cascade, and surprise application ownership; keep them set-based, bounded, observable, and justified.
3. Usually a temp table: materialize once, index it, gain statistics, and reuse. Verify because newer SQL Server versions improve table-variable estimates and a CTE may be cheapest for small/simple expressions.
4. Values can and should be parameters. Object/column names cannot be ordinary parameters; select them from a strict allow-list and wrap with `QUOTENAME`. Never concatenate untrusted fragments/operators/directions.
5. Nested callers may own a transaction; procedures need explicit contract/error behavior and should not unexpectedly commit someone else's work. Client mapping depends on columns/types/order; version changes safely.

### Production and failure checks

- Test procedures/triggers with zero, one, and thousands of affected rows.
- Measure tempdb allocation, spills, recompiles, and concurrency under realistic load.
- Grant execute/select on controlled interfaces instead of broad table ownership where appropriate.
- Capture procedure parameters safely for diagnosis without leaking secrets/PII.
- Document transaction, timeout, result, error, and retry contracts.

### Build task

Implement a search procedure with allow-listed dynamic sort, filters, keyset pagination, and a stable result contract. Compare CTE/temp-table plans for a reused intermediate, then bulk-update 1,000 rows and prove the audit trigger records all changes efficiently.

---

## 9. Partitioning, Replication, and Sharding

### Concept map

- Table partitioning divides one logical table/index inside a database; it does not create independent write scale by itself.
- Partition elimination needs predicates aligned with the partition key and compatible expressions/types.
- Replication creates copies for availability/read placement; asynchronous replicas can be stale.
- Sharding assigns ownership to independent databases using a routing key/map.
- A good shard key balances bytes/request rate, preserves common locality, is stable, and supports controlled rebalancing.
- Cross-shard queries/transactions, global uniqueness, schema rollout, backup, and resharding are first-class costs.

### Wrong/before scale plan

```text
Problem: Orders primary has slow queries.
Plan: shard by CountryCode immediately and send all reads to replicas.
```

This does not diagnose query/index/lock causes, one country can dominate, global reports fan out, and immediate read-after-write may return stale results.

### Corrected/after decision sequence

```sql
-- Partition-aligned retention query (illustrative monthly boundary).
SELECT OrderID, CreatedAt, Total
FROM Orders
WHERE CreatedAt >= @MonthStart
  AND CreatedAt <  @NextMonthStart;
```

```text
1. Measure bottleneck and headroom.
2. Repair queries/indexes/archive/connection and transaction issues.
3. Choose partitioning for manageability/elimination where applicable.
4. Add replicas only for compatible stale-read workloads and failover goals.
5. Shard when measured capacity, tenant-isolation, sovereignty, or availability requirements justify the added distributed-systems cost.
6. Use stable logical buckets -> physical shards for controlled movement.
```

### Practice questions

1. Why can a partitioned table still scan every partition?
2. What user behavior reveals asynchronous replication lag?
3. Compare range, hash, tenant, and directory-based sharding.
4. Why are logical buckets useful during resharding?
5. Why is replication not backup?

### Detailed answer key

1. Predicate lacks the partition key, wraps it incompatibly, uses implicit conversion, or requests most/all ranges. Partitioning primarily helps manageability and aligned access; verify elimination in the plan.
2. A user writes then reads from a lagging replica and sees old/missing state. Route read-your-writes to leader/session-consistent replica or use commit positions/tokens according to workflow.
3. Range preserves range locality but hot newest ranges/skew; hash balances better but scatters ranges; tenant preserves ownership but large tenants skew; directory offers flexible placement but needs a highly available cached map/control plane.
4. Hash into many stable logical buckets, then map buckets to physical shards. Moving selected buckets changes placement without changing the key formula or remapping almost every entity.
5. Deletion, corruption, or bad writes can replicate everywhere. Backups provide independent point-in-time recovery; only tested restore proves recoverability.

### Production and failure checks

- Track per-partition/shard bytes, QPS, p99, locks, connections, top keys, and growth—not fleet averages.
- Measure replica lag in time/bytes/commit position and declare read guarantees per workflow.
- Version/cache shard maps; test stale routing and movement cutover/rollback.
- Automate schema migrations, backup, restore, integrity, and failover across every shard.
- Keep analytics/fan-out off latency-critical transactional paths when possible.

### Build task

Design five-year order retention with monthly partitions, one asynchronous reporting replica, and future customer sharding. Show queries that do/do not eliminate partitions, define read-your-writes routing, and write a bucket-migration timeline with copy, catch-up, verify, cutover, and rollback.

---

## 10. Backup, Recovery, Integrity, and Security

### Concept map

- Recovery model and backup chain determine point-in-time options; full/differential/log backups have different roles.
- RPO is acceptable data loss; RTO is acceptable recovery time.
- A successful backup job is not a successful restore.
- `DBCC CHECKDB`, checksums, storage health, and restore verification address corruption/integrity.
- Least privilege, parameterization, encryption, key rotation, auditing, masking, and row-level controls are layered protections.
- High availability, disaster recovery, backup, and archival solve different failure modes.

### Wrong/before runbook

```text
- Nightly full backup exists.
- Availability Group has three replicas.
- Therefore RPO=0 and no restore drill is necessary.
```

### Corrected/after recovery contract

```text
Business target:
  RPO: <= 5 minutes for paid orders
  RTO: <= 60 minutes for regional database loss

Evidence:
  - full + differential + 5-minute log backups in independent account/region
  - encrypted, immutable retention with monitored chain
  - quarterly clean-environment point-in-time restore
  - application reconciliation and integrity checks
  - measured DNS/connection/secret/application recovery time
```

### Practice questions

1. Why can a full backup plus missing log backup prevent desired point-in-time recovery?
2. Distinguish failover from restore and when each is needed.
3. Why does parameterization improve security but not authorize data access?
4. What should a database credential used by an API be allowed to do?
5. How do you prove a restore is usable, not merely complete?
6. What different problems do TLS, Transparent Data Encryption, and client-side column encryption solve?

### Detailed answer key

1. A point-in-time restore under the full recovery model needs a suitable full backup, optionally a differential, and every required log backup through the target time. A missing log interrupts that restore sequence; taking another full backup does not itself reset or repair the transaction-log chain. Under bulk-logged recovery, a log backup containing minimally logged work may have to be restored to its end rather than to an arbitrary time inside it. Monitor continuity and rehearse the exact sequence.
2. Failover switches to a redundant current-ish copy for infrastructure failure. Restore reconstructs a prior/independent state after deletion, corruption, ransomware, or broader loss. Replicated corruption may require restore.
3. It separates code from values and prevents value-based injection while often helping plan reuse. Dynamic identifiers and sort fragments still require a strict allow-list and safe quoting. The authenticated principal may still request another tenant's row; application/database authorization and row predicates remain required.
4. Minimum operations on required procedures/tables/schemas, no owner/sysadmin/DDL unless justified, separated migration identity, short-lived/rotated secrets or managed identity, network restrictions, and auditing.
5. Run integrity checks, application smoke/consistency/reconciliation queries, verify users/permissions/keys/jobs/dependencies, measure time, and record achieved recovery point—not just “RESTORE completed.”
6. TLS protects data in transit between endpoints. Transparent Data Encryption encrypts database, log, and backup pages at rest, but SQL Server and sufficiently privileged identities still see plaintext. Client-side approaches such as Always Encrypted can hide selected plaintext from the database engine, with query, driver, enclave, and key-management trade-offs. None replaces authorization, auditing, secret/key backup, and tested rotation/recovery.

### Production and failure checks

- Alert on backup age/chain/copy/immutability and restore-test failure.
- Keep recovery credentials/keys/runbooks available when primary identity systems are impaired.
- Test accidental deletion, corruption, region loss, key loss, and compromised admin—not only server crash.
- Audit privileged/data access with retention and alert ownership; protect audit logs independently.
- Inventory sensitive columns, minimize collection, encrypt appropriately, and test deletion/retention workflows.

### Build task

Write and execute a disposable recovery drill: full backup, data changes, log backups, accidental deletion, tail-log if possible, point-in-time restore to another database, integrity/application validation, and an evidence report with achieved RPO/RTO.

---

## 11. Performance Diagnosis and Production Operations

### Concept map

- Diagnose from user symptom and time window through waits/resources, workload, plans, and data distribution.
- Query duration = queue/blocking + CPU + I/O + memory/spill + network/client effects; “slow SQL” has multiple causes.
- Query Store preserves plan/runtime history and supports regression investigation.
- DMVs are current/cumulative views and reset; capture context and baselines.
- Wait statistics guide investigation but are not fixes by themselves.
- Parameter sensitivity, memory grants, tempdb, log, storage, and connection pools interact.

### Wrong/before incident response

```text
1. Sort top queries by average duration.
2. Add every missing-index recommendation.
3. Clear the plan cache.
4. Restart SQL Server if still slow.
```

This destroys evidence, ignores blocking/resource saturation and tail behavior, and can increase write cost with redundant indexes.

### Corrected/after investigation flow

```text
symptom/SLO + exact time
 -> request/query correlation and affected cohort
 -> waits/blocking/deadlocks/resource saturation
 -> top workload delta (CPU, reads, writes, duration, executions)
 -> captured actual plan in a safe reproduction, or Query Store compiled-plan/runtime history
 -> estimate-vs-actual rows where actual execution data is available
 -> parameter/data/statistics/index/transaction cause
 -> reversible hypothesis and controlled test
 -> canary/monitor/rollback
```

### Practice questions

1. A query's duration rose but CPU and reads did not. What do you inspect next?
2. What do sort/hash spills reveal, and why is “add memory” incomplete?
3. How can a connection-pool increase make database latency worse?
4. Why might forcing the old plan be useful yet temporary?
5. What evidence distinguishes parameter sensitivity from general plan regression?

### Detailed answer key

1. Blocking/lock waits, queue/resource semaphore, network/client consumption, log flush, I/O latency, and execution count/concurrency. Break duration into wait/CPU and correlate the same interval.
2. Granted memory was insufficient for actual work, often due to underestimates/skew or concurrency pressure. Fix cardinality/query/index/data issues or grant behavior; blindly increasing memory can reduce concurrency or mask the cause.
3. It multiplies concurrent queries/locks/memory/CPU, causing queueing and context switching. A pool is a backpressure boundary; size globally against database capacity and query latency.
4. It can restore service quickly while investigation continues. Data/distribution/schema may evolve, and the old plan may be wrong for other parameters. Preserve evidence and implement a durable fix/monitoring.
5. Compare plans/metrics across parameter values and distributions. If rare/common parameters need opposing strategies and reuse causes swings, sensitivity is likely. A universally worse candidate after code/index/stats change indicates broader regression.

### Production and failure checks

- Establish baseline SLO/load/plan statistics before incidents.
- Preserve Query Store, blocking/deadlock graphs, plans, parameters safely, and deployment timeline.
- Measure p50/p95/p99 and concurrency, not averages alone.
- Make one reversible change at a time; predict the metric that should move.
- Review index/statistics maintenance based on measured fragmentation/change/workload, not ritual schedules.

### Build task

Create a reproducible incident: skewed parameter, stale stats, blocking transaction, and tempdb spill. Diagnose without restarting/clearing cache, produce an evidence timeline, apply one fix per cause, and prove both improvement and absence of a new regression.

---

## 12. EF Core, Dapper, and Production Data-Access Scenarios

### Concept map

- ORM convenience does not remove SQL/query-plan/transaction semantics.
- EF tracking is for unit-of-work changes; no-tracking suits read-only projections.
- Projection, eager/split loading, explicit loading, and N+1 choices affect round trips/cartesian expansion.
- `DbContext` is short-lived and not thread-safe; cancellation/timeouts flow to the provider.
- Optimistic concurrency tokens turn lost updates into explicit conflicts.
- Dapper maps SQL efficiently but still needs parameterization, ownership, transactions, and stable contracts.
- Execution-strategy retries require idempotent units and awareness of uncertain commits.

### Wrong/before EF/Dapper code

```csharp
var orders = await db.Orders.ToListAsync();
foreach (var order in orders)
{
    Console.WriteLine(order.Customer.Name); // lazy-load/N+1 or missing data
}

var sql = $"SELECT * FROM Orders WHERE CustomerId = {customerInput}";
var rows = await connection.QueryAsync<Order>(sql);
```

### Corrected/after code

```csharp
var orders = await db.Orders
    .Where(o => o.CustomerId == customerId && o.CreatedAt >= since)
    .OrderByDescending(o => o.CreatedAt)
    .ThenByDescending(o => o.Id)
    .Select(o => new OrderSummary(
        o.Id, o.CreatedAt, o.Total, o.Customer.DisplayName))
    .Take(101)
    .ToListAsync(cancellationToken);

const string sql = """
SELECT TOP (@Take)
       o.OrderID AS Id, o.CreatedAt, o.Total, c.DisplayName
FROM Orders AS o
JOIN Customers AS c ON c.CustomerID = o.CustomerID
WHERE o.CustomerID = @CustomerID
  AND o.CreatedAt >= @Since
ORDER BY o.CreatedAt DESC, o.OrderID DESC;
""";
var rows = await connection.QueryAsync<OrderSummary>(
    new CommandDefinition(sql,
        new { CustomerID = customerId, Since = since, Take = 101 },
        commandTimeout: 5, cancellationToken: cancellationToken));
```

### Practice questions

1. When should EF Core use tracking, no-tracking, projection, or compiled queries?
2. Compare a single huge include query with split queries and projections.
3. How does a `rowversion` concurrency token change update behavior?
4. What is dangerous about retrying `SaveChanges` after a timeout/connection loss?
5. When should a team choose EF Core, Dapper, raw ADO.NET, or a stored procedure?

### Detailed answer key

1. Tracking is for a bounded unit of work that modifies entities; no-tracking is for read-only entity materialization; projection is for API/query shapes and minimal columns; compiled queries are for measured hot stable shapes where compilation overhead matters. A scalar/DTO projection containing no entity is already untracked, so adding `AsNoTracking` to the sample would be redundant. Measure rather than apply any option globally.
2. Includes are convenient but sibling collections can multiply rows/data. Split queries reduce cartesian duplication but add round trips and can observe different committed states unless a suitable transaction supplies the required consistency. Projection often best expresses the needed shape. Choose by cardinality, latency, consistency requirement, and maintainability.
3. EF includes the original token in the `UPDATE` predicate; if another writer changed the row, zero rows update and a concurrency exception surfaces. The application must reload/merge/reject/retry deliberately—not swallow it.
4. The commit may have succeeded even if acknowledgement was lost. Blind retry can duplicate effects unless client-generated keys, invariants, idempotency, or reconciliation make it safe. When using an EF execution strategy with an explicit transaction, create and commit the entire transaction inside the strategy callback so the complete unit can be retried; keep external effects outside or coordinate them through an outbox.
5. EF for rich unit-of-work/productivity and LINQ; Dapper for explicit SQL/light mapping/hot queries; ADO.NET for maximum low-level control/streaming/bulk/provider needs; procedures for controlled database-side operations/security/plan/transaction contracts. A system can use several with clear ownership.

### Production and failure checks

- Log SQL shape/timing/rows with sensitive parameters redacted; inspect generated SQL and actual plans.
- Set command/request deadlines and propagate cancellation.
- Load-test round trips, materialized rows/bytes, pool waits, and database waits—not only API latency.
- Test optimistic conflicts, deadlock retries, uncertain commit, and transaction rollback.
- Keep migrations separate from runtime identity and design expand/migrate/contract rollouts.

### Build task

Implement the same order-history and optimistic-update workflow in EF Core and Dapper. Compare SQL, plans, allocations, round trips, concurrency behavior, cancellation, and maintainability. Produce a decision—not a benchmark-only winner.

---

## Cumulative SQL Production Capstone

Build a small order-processing database and application that demonstrates every workbook domain:

1. Normalized schema with database constraints and versioned migrations.
2. Reporting query using windows and safely labeled grouping sets.
3. Offset and signed keyset endpoints with supporting indexes.
4. Idempotent order creation, optimistic update, outbox, and lease-based relay.
5. Concurrent oversell/deadlock tests and measured retry behavior.
6. Query Store/plan/statistics investigation under skew and load.
7. Partition/replica/shard evolution plan with explicit thresholds.
8. Least-privilege identities, audit, backup chain, point-in-time restore drill, and achieved RPO/RTO.
9. EF Core plus one justified Dapper/procedure path.
10. Engineering report containing invariants, plans, failure timeline, metrics, trade-offs, and remaining risks.

**Completion standard:** You can predict semantics, write the query, read the plan, reproduce concurrency failure, repair it, and prove recovery. Memorizing syntax without observable correctness under load and failure is not mastery.
