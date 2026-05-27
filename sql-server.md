# 🗄️ SQL Server Interview Questions — Complete Guide

A comprehensive reference covering 100 T-SQL interview questions across 10 topics, each with conceptual explanations and side-by-side bad/good SQL examples.

---

## Table of Contents

1. [SELECT, Filtering & Aggregates](#1-select-filtering--aggregates)
2. [JOINs](#2-joins)
3. [Indexes & Query Performance](#3-indexes--query-performance)
4. [Stored Procedures, Functions & Dynamic SQL](#4-stored-procedures-functions--dynamic-sql)
5. [Triggers](#5-triggers)
6. [Transactions & Concurrency](#6-transactions--concurrency)
7. [Window Functions](#7-window-functions)
8. [CTEs & Subqueries](#8-ctes--subqueries)
9. [Database Design & Normalization](#9-database-design--normalization)
10. [Advanced T-SQL Patterns](#10-advanced-t-sql-patterns)

---
## 1. SELECT, Filtering & Aggregates

> 📚 Reference: https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql
> 📚 Medium: https://medium.com/learning-sql/sql-aggregates-group-by-having-explained-8c3e1e6e7c2a

---

### Q1. What is the difference between WHERE and HAVING, and when must you use each?

**Answer:** WHERE filters rows before any grouping or aggregation takes place, so it cannot reference aggregate functions. HAVING filters the result of a GROUP BY after aggregates have been computed, meaning it can reference expressions like SUM() or COUNT(). Using HAVING without GROUP BY is valid but unusual — it treats the entire result set as one group. For best performance, push as many conditions as possible into WHERE so fewer rows enter the aggregation step.

❌ **Violates:**
```sql
-- Wrong: WHERE cannot reference an aggregate function
SELECT DepartmentID, SUM(Salary) AS TotalSalary
FROM Employees
WHERE SUM(Salary) > 100000   -- ERROR: aggregate not allowed in WHERE
GROUP BY DepartmentID;
```

✅ **Satisfies:**
```sql
-- Correct: filter on raw column in WHERE, filter on aggregate in HAVING
SELECT DepartmentID, SUM(Salary) AS TotalSalary
FROM Employees
WHERE IsActive = 1                   -- eliminates inactive rows BEFORE grouping
GROUP BY DepartmentID
HAVING SUM(Salary) > 100000;        -- filters groups AFTER aggregation
```

---

### Q2. How does SQL Server handle NULL values, and what functions exist to deal with them?

**Answer:** NULL represents an unknown value and is not equal to anything — not even another NULL. Any arithmetic or string operation involving NULL returns NULL, and comparisons with NULL using = or <> always evaluate to UNKNOWN. Use IS NULL / IS NOT NULL to test for nullability. ISNULL(expr, replacement) substitutes a single replacement; COALESCE(a, b, c, ...) returns the first non-NULL argument and is ANSI-standard. NULLIF(a, b) returns NULL when a equals b, useful for avoiding divide-by-zero.

❌ **Violates:**
```sql
-- Wrong: = NULL never matches; rows with NULL ManagerID are missed
SELECT EmployeeID, Name
FROM Employees
WHERE ManagerID = NULL;   -- always returns 0 rows
```

✅ **Satisfies:**
```sql
-- Correct: use IS NULL for NULL comparison
SELECT EmployeeID, Name
FROM Employees
WHERE ManagerID IS NULL;   -- correctly finds top-level employees

-- COALESCE for display default
SELECT Name, COALESCE(Phone, Email, 'No contact') AS ContactInfo
FROM Employees;

-- NULLIF to prevent divide-by-zero
SELECT TotalRevenue / NULLIF(TotalUnits, 0) AS AvgPrice
FROM Sales;
```

---

### Q3. How does the CASE expression work, and what are the two forms?

**Answer:** CASE is an inline conditional expression that returns a single value and can appear in SELECT, ORDER BY, WHERE, or even GROUP BY clauses. The simple form compares one input expression against a list of WHEN values. The searched form evaluates independent Boolean conditions in each WHEN clause and is more flexible. CASE returns the first matching branch and short-circuits; if no WHEN matches and there is no ELSE, it returns NULL.

❌ **Violates:**
```sql
-- Wrong: tries to use IF (a statement, not an expression) inside SELECT
SELECT Name,
       IF(Salary > 80000, 'Senior', 'Junior') AS Level  -- syntax error in T-SQL
FROM Employees;
```

✅ **Satisfies:**
```sql
-- Simple CASE (equality check)
SELECT Name,
       CASE Department
           WHEN 'IT'      THEN 'Technology'
           WHEN 'Finance' THEN 'Finance'
           ELSE 'Other'
       END AS DivisionName
FROM Employees;

-- Searched CASE (range/condition check)
SELECT Name, Salary,
       CASE
           WHEN Salary >= 100000 THEN 'Band A'
           WHEN Salary >= 60000  THEN 'Band B'
           ELSE                       'Band C'
       END AS SalaryBand
FROM Employees
ORDER BY CASE WHEN Salary IS NULL THEN 1 ELSE 0 END, Salary DESC;
```

---

### Q4. What is the difference between COUNT(*), COUNT(column), and COUNT(DISTINCT column)?

**Answer:** COUNT(*) counts every row in the group including those with NULLs; it is the fastest variant. COUNT(column) counts only rows where that column is not NULL, which can give a lower number when the column contains NULLs. COUNT(DISTINCT column) counts only unique non-NULL values. SUM and AVG also silently ignore NULLs, so AVG(Salary) divides the sum by only the non-NULL rows — this can produce surprising results if you expect NULLs to count as zero.

❌ **Violates:**
```sql
-- Wrong assumption: developer thinks COUNT(ManagerID) equals total employees
SELECT COUNT(ManagerID) AS NumEmployees  -- misses rows where ManagerID IS NULL
FROM Employees;
```

✅ **Satisfies:**
```sql
-- Total rows regardless of NULLs
SELECT COUNT(*)                        AS TotalEmployees,
       COUNT(ManagerID)                AS HaveManager,      -- excludes NULLs
       COUNT(DISTINCT DepartmentID)    AS UniqueDepts,
       AVG(Salary)                     AS AvgSalary,        -- ignores NULL salaries
       AVG(COALESCE(Salary, 0))        AS AvgSalaryWithZero -- treats NULL as 0
FROM Employees;
```

---

### Q5. Explain GROUP BY ROLLUP, CUBE, and GROUPING SETS with an example.

**Answer:** ROLLUP produces subtotals along a hierarchy: it generates a row for each prefix of the column list plus a grand total, making it ideal for year/quarter/month reporting. CUBE generates subtotals for every possible combination of the listed columns — 2^n combinations. GROUPING SETS lets you specify exactly which grouping combinations you want, avoiding unnecessary computation. The GROUPING(col) function returns 1 when a column is NULL because it is a super-aggregate row, helping distinguish real NULLs from rollup placeholders.

❌ **Violates:**
```sql
-- Wrong: UNION ALL approach duplicates table scans unnecessarily
SELECT Region, Product, SUM(Sales) FROM SalesData GROUP BY Region, Product
UNION ALL
SELECT Region, NULL,    SUM(Sales) FROM SalesData GROUP BY Region
UNION ALL
SELECT NULL,   NULL,    SUM(Sales) FROM SalesData;  -- 3 separate scans
```

✅ **Satisfies:**
```sql
-- ROLLUP: hierarchy subtotals (Region > Product) + grand total
SELECT Region,
       Product,
       SUM(Sales)       AS TotalSales,
       GROUPING(Region) AS IsRegionRollup,
       GROUPING(Product) AS IsProductRollup
FROM SalesData
GROUP BY ROLLUP(Region, Product);

-- GROUPING SETS: only the combinations you need
SELECT Region, Product, SUM(Sales) AS TotalSales
FROM SalesData
GROUP BY GROUPING SETS ((Region, Product), (Region), ());
```

---

### Q6. How do TOP and OFFSET-FETCH differ for pagination?

**Answer:** TOP N returns the first N rows and is simple but not suitable for true pagination because there is no built-in "skip" mechanism — you would need a subquery workaround. OFFSET-FETCH (introduced in SQL Server 2012) provides proper page-based pagination by skipping a calculated number of rows and then fetching the next page. OFFSET-FETCH requires an ORDER BY clause; TOP does not, though using TOP without ORDER BY gives non-deterministic results. For server-side paging in applications, OFFSET-FETCH is the correct choice.

❌ **Violates:**
```sql
-- Wrong: TOP without ORDER BY gives non-deterministic rows; no page 2 possible
SELECT TOP 10 *
FROM Products;   -- which 10? undefined; page 2 is impossible without subquery hack
```

✅ **Satisfies:**
```sql
-- Page-based pagination: page 3 with 10 rows per page
DECLARE @PageNumber INT = 3;
DECLARE @PageSize   INT = 10;

SELECT ProductID, Name, Price
FROM Products
ORDER BY ProductID                          -- deterministic ordering required
OFFSET (@PageNumber - 1) * @PageSize ROWS  -- skip previous pages
FETCH NEXT @PageSize ROWS ONLY;            -- take current page
```

---

### Q7. What are the key string functions in T-SQL and when do you use them?

**Answer:** LEN returns character length excluding trailing spaces; DATALENGTH returns byte length which differs for Unicode. SUBSTRING(str, start, length) extracts a portion (1-based index). CHARINDEX(find, source) returns the position of the first occurrence, returning 0 if not found. STRING_AGG aggregates multiple rows into a delimited string (SQL Server 2017+). CONCAT handles NULLs gracefully by treating them as empty strings, unlike the + operator which propagates NULLs.

❌ **Violates:**
```sql
-- Wrong: + concatenation turns NULL into NULL for the whole expression
SELECT FirstName + ' ' + MiddleName + ' ' + LastName AS FullName
FROM Employees;   -- rows where MiddleName IS NULL return NULL for the entire name
```

✅ **Satisfies:**
```sql
-- CONCAT treats NULLs as empty string
SELECT CONCAT(FirstName, ' ', MiddleName, ' ', LastName) AS FullName,
       LEN(LastName)                                      AS LastNameLen,
       SUBSTRING(Email, 1, CHARINDEX('@', Email) - 1)    AS EmailUser
FROM Employees;

-- STRING_AGG: comma-separated list of employee names per department
SELECT DepartmentID,
       STRING_AGG(Name, ', ') WITHIN GROUP (ORDER BY Name) AS MemberList
FROM Employees
GROUP BY DepartmentID;
```

---

### Q8. What date functions does T-SQL provide, and what is the difference between GETDATE and SYSDATETIME?

**Answer:** GETDATE() returns the current date and time as datetime (3.33ms precision). SYSDATETIME() returns datetime2(7) with higher precision and is preferred for new code. DATEADD(part, n, date) adds an interval; DATEDIFF(part, start, end) returns the difference as an integer (it counts boundaries crossed, not exact elapsed time). TRY_CONVERT and TRY_CAST return NULL on conversion failure rather than throwing an error, making them safer for user-supplied data.

❌ **Violates:**
```sql
-- Wrong: CONVERT without TRY_ throws error on bad date strings
SELECT CONVERT(DATE, UserInput) AS OrderDate
FROM Orders;   -- crashes if UserInput = 'not-a-date'

-- Wrong: DATEDIFF misconception — counts month boundaries, not 30-day periods
SELECT DATEDIFF(MONTH, '2024-01-31', '2024-02-01') AS MonthDiff;
-- Returns 1, even though only 1 day apart
```

✅ **Satisfies:**
```sql
-- Safe date conversion
SELECT TRY_CONVERT(DATE, UserInput) AS OrderDate   -- NULL on bad input, no crash
FROM Orders;

-- Correct date arithmetic
SELECT OrderID,
       OrderDate,
       DATEADD(DAY, 30, OrderDate)                           AS DueDate,
       DATEDIFF(DAY, OrderDate, GETDATE())                   AS DaysOld,
       SYSDATETIME()                                         AS PreciseNow
FROM Orders
WHERE OrderDate >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE));
```

---

### Q9. What is the difference between EXISTS, IN, and correlated subqueries, and what is the NULL danger with NOT IN?

**Answer:** EXISTS returns TRUE as soon as it finds one matching row (short-circuit evaluation) and is generally the most efficient for large outer queries. IN materializes the subquery result set and checks membership; it works well when the subquery is small. NOT IN is dangerous: if the subquery returns even one NULL value, the entire NOT IN condition evaluates to UNKNOWN and zero rows are returned — a silent bug. NOT EXISTS does not have this problem and is the safe replacement.

❌ **Violates:**
```sql
-- NOT IN with NULL danger: if any customer has NULL email, returns 0 rows
SELECT Name
FROM Customers
WHERE CustomerID NOT IN (
    SELECT CustomerID FROM Orders WHERE Email IS NULL  -- if one NULL exists, all rows excluded
);
```

✅ **Satisfies:**
```sql
-- Safe: NOT EXISTS handles NULLs correctly
SELECT c.Name
FROM Customers c
WHERE NOT EXISTS (
    SELECT 1 FROM Orders o WHERE o.CustomerID = c.CustomerID
);

-- EXISTS short-circuits on first match
SELECT c.Name
FROM Customers c
WHERE EXISTS (
    SELECT 1 FROM Orders o
    WHERE o.CustomerID = c.CustomerID
      AND o.OrderDate >= '2024-01-01'
);
```

---

### Q10. What is the difference between DISTINCT and GROUP BY?

**Answer:** DISTINCT eliminates duplicate rows from a result set and operates on all selected columns together. GROUP BY collapses rows into groups and enables aggregate functions on each group; it can therefore produce richer results. When no aggregate function is used, GROUP BY and DISTINCT are semantically equivalent, but their query plans may differ. DISTINCT is clearer in intent when you simply want unique rows; GROUP BY should be used when aggregation is required.

❌ **Violates:**
```sql
-- Wrong: using GROUP BY without aggregation just to "seem professional"
-- creates confusion about intent
SELECT DepartmentID
FROM Employees
GROUP BY DepartmentID;   -- works, but intent is deduplication not aggregation
```

✅ **Satisfies:**
```sql
-- DISTINCT for simple deduplication
SELECT DISTINCT DepartmentID
FROM Employees;

-- GROUP BY for aggregation (correct use)
SELECT DepartmentID,
       COUNT(*)       AS HeadCount,
       AVG(Salary)    AS AvgSalary,
       MAX(HireDate)  AS LatestHire
FROM Employees
GROUP BY DepartmentID
HAVING COUNT(*) >= 3;
```

---
## 2. JOINs

> 📚 Reference: https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins
> 📚 Medium: https://medium.com/learning-sql/sql-joins-visual-guide-inner-left-right-full-cross-self-1a2b3c4d5e6f

---

### Q11. What is the difference between INNER JOIN, LEFT JOIN, RIGHT JOIN, and FULL OUTER JOIN?

**Answer:** INNER JOIN returns only rows that have a matching row in both tables. LEFT JOIN returns all rows from the left table and matching rows from the right table; unmatched right-side columns come back as NULL. RIGHT JOIN is the mirror image. FULL OUTER JOIN returns all rows from both tables, with NULLs on whichever side has no match. In practice, RIGHT JOIN is rarely used because the same result can be achieved by swapping the table order and using LEFT JOIN.

❌ **Violates:**
```sql
-- Wrong: INNER JOIN silently drops customers who have no orders
SELECT c.CustomerName, o.OrderID, o.TotalAmount
FROM Customers c
INNER JOIN Orders o ON c.CustomerID = o.CustomerID;
-- Customers with zero orders disappear from results
```

✅ **Satisfies:**
```sql
-- LEFT JOIN preserves ALL customers; OrderID is NULL for those with no orders
SELECT c.CustomerName,
       o.OrderID,
       COALESCE(o.TotalAmount, 0) AS TotalAmount
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID;

-- FULL OUTER JOIN: see all customers AND all orders even with broken FK
SELECT c.CustomerName, o.OrderID
FROM Customers c
FULL OUTER JOIN Orders o ON c.CustomerID = o.CustomerID
WHERE c.CustomerID IS NULL OR o.OrderID IS NULL;  -- orphaned rows on either side
```

---

### Q12. What is a CROSS JOIN and when is it actually useful?

**Answer:** A CROSS JOIN produces the Cartesian product of two tables — every row in the left table paired with every row in the right table. With M left rows and N right rows you get M×N result rows. Although they look dangerous, CROSS JOINs are deliberately used to generate all combinations, such as pairing every product with every date for gap analysis in reporting. A WHERE clause can then filter out combinations that already have data, revealing gaps.

❌ **Violates:**
```sql
-- Wrong: accidental CROSS JOIN due to missing ON clause (old-style comma join)
SELECT c.CustomerName, p.ProductName
FROM Customers c, Products p   -- missing WHERE join condition = full Cartesian product
WHERE c.Region = 'North';      -- only filters customers, still crosses with all products
```

✅ **Satisfies:**
```sql
-- Intentional CROSS JOIN: generate all date x product combinations for gap analysis
WITH Dates AS (
    SELECT CAST('2024-01-01' AS DATE) AS SaleDate
    UNION ALL
    SELECT DATEADD(DAY, 1, SaleDate) FROM Dates WHERE SaleDate < '2024-01-31'
)
SELECT d.SaleDate, p.ProductID, COALESCE(s.Revenue, 0) AS Revenue
FROM Dates d
CROSS JOIN Products p
LEFT JOIN DailySales s ON s.SaleDate = d.SaleDate AND s.ProductID = p.ProductID
OPTION (MAXRECURSION 31);
```

---

### Q13. How do you write a SELF JOIN and what problems does it solve?

**Answer:** A SELF JOIN joins a table to itself using two different aliases, treating each alias as a logically distinct table. The most common use is an employee-manager hierarchy where both the employee and their manager live in the same Employees table. Another common use is finding pairs of rows with a related condition (e.g., products in the same category with different prices). Without aliases the query would be ambiguous.

❌ **Violates:**
```sql
-- Wrong: cannot reference same table twice without aliases
SELECT EmployeeID, Name, ManagerID, Name  -- ambiguous: which Name?
FROM Employees e
JOIN Employees ON ManagerID = EmployeeID;  -- missing alias makes ON clause ambiguous
```

✅ **Satisfies:**
```sql
-- Employee + their manager's name using SELF JOIN
SELECT e.Name        AS Employee,
       m.Name        AS Manager,
       e.Department
FROM   Employees e
LEFT JOIN Employees m ON e.ManagerID = m.EmployeeID;
-- LEFT JOIN keeps employees who have no manager (CEO / top of hierarchy)

-- Finding same-category products at different price points
SELECT a.ProductName AS CheaperProduct,
       b.ProductName AS PricierProduct,
       a.CategoryID,
       b.Price - a.Price AS PriceDiff
FROM Products a
JOIN Products b ON a.CategoryID = b.CategoryID
               AND a.Price < b.Price;
```

---

### Q14. What is an anti-join and which approach is safest — LEFT JOIN + IS NULL, NOT EXISTS, or NOT IN?

**Answer:** An anti-join finds rows in one set that have no match in another. All three approaches can produce anti-join results, but they differ in NULL safety and performance. NOT IN fails silently when the subquery returns any NULL — the entire result set becomes empty because SQL cannot confirm "this value is not in a set that contains UNKNOWN". NOT EXISTS is NULL-safe and often the most efficient because the engine can stop as soon as a match is found. LEFT JOIN + IS NULL is equivalent to NOT EXISTS and can be more readable for simple cases.

❌ **Violates:**
```sql
-- NOT IN silently returns 0 rows if ANY CustomerID in Orders is NULL
SELECT c.CustomerName
FROM Customers c
WHERE c.CustomerID NOT IN (SELECT CustomerID FROM Orders);
-- If one order has NULL CustomerID, every customer is excluded!
```

✅ **Satisfies:**
```sql
-- Option 1: NOT EXISTS (NULL-safe, usually fastest)
SELECT c.CustomerName
FROM Customers c
WHERE NOT EXISTS (
    SELECT 1 FROM Orders o WHERE o.CustomerID = c.CustomerID
);

-- Option 2: LEFT JOIN + IS NULL (NULL-safe, readable)
SELECT c.CustomerName
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;
```

---

### Q15. Why do JOINs produce duplicate rows and how do you detect and fix them?

**Answer:** Duplicate rows appear when the join key is not unique on the "many" side of a one-to-many relationship. For example, joining a customer to their orders means each customer row is repeated for every order, which is correct. The bug appears when you join a customer to a lookup table that accidentally contains duplicate keys, multiplying rows unexpectedly. Detecting duplicates before joining with a COUNT/GROUP BY check prevents data explosion. A CTE with ROW_NUMBER() can deduplicate the lookup before the JOIN.

❌ **Violates:**
```sql
-- Wrong: DimCustomer has duplicate CustomerID rows (bad ETL), causing row multiplication
SELECT o.OrderID, c.CustomerName, SUM(o.Amount) AS Total
FROM Orders o
JOIN DimCustomer c ON o.CustomerID = c.CustomerID  -- if c has 3 rows per customer, each order triples
GROUP BY o.OrderID, c.CustomerName;
-- SUM doubles/triples because of JOIN fan-out
```

✅ **Satisfies:**
```sql
-- Deduplicate the dimension table first using ROW_NUMBER()
WITH UniqueCustomers AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY LoadDate DESC) AS rn
    FROM DimCustomer
)
SELECT o.OrderID, c.CustomerName, o.Amount
FROM Orders o
JOIN UniqueCustomers c ON o.CustomerID = c.CustomerID AND c.rn = 1;
```

---

### Q16. How do non-equi joins work, and when do you use BETWEEN in a JOIN?

**Answer:** A non-equi join uses inequality operators (>, <, BETWEEN, !=) in the ON clause instead of equality. They are less common but invaluable for range-based lookups such as mapping a salary to a pay band, applying a tax rate based on income, or detecting overlapping date ranges. Non-equi joins can produce large result sets if not constrained and typically cannot leverage hash or merge join strategies — nested loops are common, so indexing the range boundaries matters.

❌ **Violates:**
```sql
-- Wrong: scalar subquery per row for salary band lookup — O(n) subquery per row
SELECT e.Name, e.Salary,
       (SELECT BandName FROM SalaryBands WHERE e.Salary BETWEEN MinSalary AND MaxSalary) AS Band
FROM Employees e;  -- correlated subquery; slow for large tables
```

✅ **Satisfies:**
```sql
-- Non-equi join for salary band: single pass
SELECT e.Name, e.Salary, sb.BandName
FROM Employees e
JOIN SalaryBands sb ON e.Salary BETWEEN sb.MinSalary AND sb.MaxSalary;

-- Detect overlapping vacation date ranges (non-equi self-join)
SELECT a.EmployeeID AS Emp1, b.EmployeeID AS Emp2,
       a.StartDate, a.EndDate
FROM Vacations a
JOIN Vacations b ON a.EmployeeID <> b.EmployeeID
               AND a.StartDate <= b.EndDate
               AND a.EndDate   >= b.StartDate;
```

---

### Q17. What is CROSS APPLY vs OUTER APPLY, and how do you get the top 3 orders per customer?

**Answer:** APPLY is a SQL Server-specific operator that invokes a table-valued function (or an inline subquery) once per row of the left table, passing the current row's values as parameters. CROSS APPLY is like an INNER JOIN to the result — it omits left-side rows that produce no rows from the right side. OUTER APPLY is like a LEFT JOIN — it keeps left-side rows even when the applied expression returns nothing, filling right-side columns with NULL. This is the cleanest way to solve "top N per group" problems without complex window-function workarounds.

❌ **Violates:**
```sql
-- Wrong: ROW_NUMBER in a subquery works but APPLY reads more naturally; 
-- however the common mistake is no ORDER BY inside the subquery
SELECT CustomerID, OrderID, Amount
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY CustomerID) AS rn FROM Orders) x
WHERE rn <= 3;  -- missing ORDER BY in OVER() — ties broken arbitrarily
```

✅ **Satisfies:**
```sql
-- CROSS APPLY: top 3 orders per customer, deterministic ordering
SELECT c.CustomerName, o.OrderID, o.Amount, o.OrderDate
FROM Customers c
CROSS APPLY (
    SELECT TOP 3 OrderID, Amount, OrderDate
    FROM Orders
    WHERE CustomerID = c.CustomerID
    ORDER BY Amount DESC               -- deterministic: highest value orders
) o;

-- OUTER APPLY: keeps customers with zero orders (NULLs for order columns)
SELECT c.CustomerName, o.OrderID, o.Amount
FROM Customers c
OUTER APPLY (
    SELECT TOP 1 OrderID, Amount
    FROM Orders WHERE CustomerID = c.CustomerID
    ORDER BY OrderDate DESC
) o;
```

---

### Q18. How do you join three or more tables correctly?

**Answer:** Multi-table JOINs are processed left-to-right (with the optimizer free to reorder for performance). Each JOIN adds another result set to the running output. The key discipline is to declare the correct join type for each pair: INNER to require matching rows, LEFT to preserve the driving table's rows. A common error is mixing LEFT and INNER JOINs where the INNER JOIN later in the chain nullifies the LEFT JOIN effect on earlier tables.

❌ **Violates:**
```sql
-- Wrong: LEFT JOIN on Orders is negated by the subsequent INNER JOIN on OrderDetails
-- customers with no orders are dropped by the INNER JOIN
SELECT c.CustomerName, o.OrderID, od.ProductID
FROM Customers c
LEFT JOIN Orders o       ON c.CustomerID = o.CustomerID
INNER JOIN OrderDetails od ON o.OrderID   = od.OrderID;  -- eliminates NULL orders from LEFT JOIN
```

✅ **Satisfies:**
```sql
-- All JOINs must be LEFT if you want to preserve customers with no orders
SELECT c.CustomerName,
       o.OrderID,
       od.ProductID,
       p.ProductName
FROM Customers c
LEFT JOIN Orders o          ON c.CustomerID  = o.CustomerID
LEFT JOIN OrderDetails od   ON o.OrderID     = od.OrderID
LEFT JOIN Products p        ON od.ProductID  = p.ProductID
ORDER BY c.CustomerName, o.OrderDate;
```

---

### Q19. When would you use a JOIN instead of a correlated subquery, and vice versa?

**Answer:** A JOIN works set-based — all matching rows are combined in one pass, making it ideal when you need columns from both tables. A correlated subquery executes once per outer row, which is O(n) and can be significantly slower on large tables; however it can express "for each row, compute something" logic more intuitively. EXISTS-style correlated subqueries are acceptable when you only need a Boolean test (and the optimizer often rewrites them as semi-joins anyway). When you need aggregated values per outer row (e.g., total orders per customer in a SELECT list), a correlated subquery works but a derived table or window function is usually more efficient.

❌ **Violates:**
```sql
-- Correlated subquery for every row is O(n) — slow on millions of rows
SELECT c.CustomerName,
       (SELECT COUNT(*) FROM Orders o WHERE o.CustomerID = c.CustomerID) AS OrderCount
FROM Customers c;   -- subquery re-executes for each customer row
```

✅ **Satisfies:**
```sql
-- Single-pass JOIN with GROUP BY: one scan of Orders, then join
SELECT c.CustomerName, COALESCE(o.OrderCount, 0) AS OrderCount
FROM Customers c
LEFT JOIN (
    SELECT CustomerID, COUNT(*) AS OrderCount
    FROM Orders
    GROUP BY CustomerID
) o ON c.CustomerID = o.CustomerID;
```

---

### Q20. Write classic interview JOIN queries: customers with no orders, employees with their manager, and unsold products.

**Answer:** These three patterns are among the most commonly asked JOIN interview queries. Customers with no orders uses an anti-join (LEFT JOIN + IS NULL or NOT EXISTS). Employees with their manager uses a SELF JOIN with LEFT JOIN to preserve top-level employees. Unsold products uses a LEFT JOIN between Products and a sales table, filtering for NULL matches. Mastering these three covers the majority of real-world JOIN interview questions.

❌ **Violates:**
```sql
-- Wrong approach for all three: using NOT IN (NULL danger) or INNER JOIN (loses non-matching rows)
SELECT ProductName FROM Products
WHERE ProductID NOT IN (SELECT ProductID FROM Sales);  -- breaks if Sales.ProductID has NULLs
```

✅ **Satisfies:**
```sql
-- 1. Customers with no orders
SELECT c.CustomerName
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;

-- 2. Employee + their manager (SELF JOIN)
SELECT e.Name AS Employee, COALESCE(m.Name, 'No Manager') AS Manager
FROM Employees e
LEFT JOIN Employees m ON e.ManagerID = m.EmployeeID;

-- 3. Products never sold
SELECT p.ProductName
FROM Products p
LEFT JOIN OrderDetails od ON p.ProductID = od.ProductID
WHERE od.ProductID IS NULL;
```

---
