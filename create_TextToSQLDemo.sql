/* =====================================================================
   Text-to-SQL Agent - demo database setup
   Run in SSMS connected to localhost\SQLEXPRESS (press F5).
   Safe to re-run: it drops and rebuilds the tables each time.
   ===================================================================== */

IF DB_ID('TextToSQLDemo') IS NULL
    CREATE DATABASE TextToSQLDemo;
GO

USE TextToSQLDemo;
GO

DROP TABLE IF EXISTS dbo.OrderItems;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Customers;
GO

/* ---------- Tables ---------- */

CREATE TABLE dbo.Customers (
    CustomerID    INT           NOT NULL PRIMARY KEY,
    CustomerName  NVARCHAR(100) NOT NULL,
    Region        NVARCHAR(50)  NOT NULL,
    SignupDate    DATE          NOT NULL
);

CREATE TABLE dbo.Products (
    ProductID     INT           NOT NULL PRIMARY KEY,
    ProductName   NVARCHAR(100) NOT NULL,
    Category      NVARCHAR(50)  NOT NULL,
    ListPrice     DECIMAL(10,2) NOT NULL
);

CREATE TABLE dbo.Orders (
    OrderID       INT           NOT NULL PRIMARY KEY,
    CustomerID    INT           NOT NULL REFERENCES dbo.Customers(CustomerID),
    OrderDate     DATE          NOT NULL,
    Status        NVARCHAR(20)  NOT NULL   -- Completed / Cancelled / Refunded
);

CREATE TABLE dbo.OrderItems (
    OrderItemID   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OrderID       INT           NOT NULL REFERENCES dbo.Orders(OrderID),
    ProductID     INT           NOT NULL REFERENCES dbo.Products(ProductID),
    Quantity      INT           NOT NULL,
    UnitPrice     DECIMAL(10,2) NOT NULL,  -- price actually charged
    Discount      DECIMAL(4,2)  NOT NULL   -- e.g. 0.10 = 10% off
);
GO

/* ---------- Products (20) ---------- */

INSERT INTO dbo.Products (ProductID, ProductName, Category, ListPrice) VALUES
 (1,  'Printer Paper A4 (Box)',   'Office Supplies', 24.99),
 (2,  'Ballpoint Pens (50)',      'Office Supplies',  9.99),
 (3,  'Sticky Notes (12)',        'Office Supplies',  7.49),
 (4,  'Desk Organiser',           'Office Supplies', 18.50),
 (5,  'Wireless Mouse',           'Electronics',     22.00),
 (6,  'USB-C Hub',                'Electronics',     39.99),
 (7,  'Keyboard',                 'Electronics',     45.00),
 (8,  '27in Monitor',             'Electronics',    189.00),
 (9,  'Webcam HD',                'Electronics',     59.99),
 (10, 'Office Chair',             'Furniture',      149.00),
 (11, 'Standing Desk Converter',  'Furniture',      129.00),
 (12, 'Filing Cabinet',           'Furniture',       95.00),
 (13, 'Coffee Beans 1kg',         'Breakroom',       16.99),
 (14, 'Tea Bags (240)',           'Breakroom',        8.49),
 (15, 'Hand Sanitiser 5L',        'Cleaning',        21.99),
 (16, 'Disinfectant Wipes',       'Cleaning',         6.99),
 (17, 'Notebook A5 (10)',         'Office Supplies', 14.99),
 (18, 'Laptop Stand',             'Electronics',     29.99),
 (19, 'Headset',                  'Electronics',     49.99),
 (20, 'Whiteboard Markers (12)',  'Office Supplies', 11.49);
GO

/* ---------- Customers (200) ---------- */

;WITH n AS (
    SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO dbo.Customers (CustomerID, CustomerName, Region, SignupDate)
SELECT
    n,
    CONCAT('Customer ', FORMAT(n, '000')),
    CHOOSE(n % 5 + 1, 'London', 'South West', 'South East', 'Midlands', 'North'),
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 730, '2023-01-01')
FROM n;
GO

/* ---------- Orders (4,000, Jan 2025 - Oct 2026) ----------
   Customers 1-25 are "big buyers" and get a larger share of orders. */

;WITH n AS (
    SELECT TOP (4000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (OrderID, CustomerID, OrderDate, Status)
SELECT
    n,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 4
         THEN 1 + ABS(CHECKSUM(NEWID())) % 25
         ELSE 1 + ABS(CHECKSUM(NEWID())) % 200 END,
    DATEADD(DAY,
            ABS(CHECKSUM(NEWID())) % (DATEDIFF(DAY, '2025-01-01', '2026-10-31') + 1),
            '2025-01-01'),
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 90 THEN 'Completed'
         WHEN ABS(CHECKSUM(NEWID())) % 2 = 0    THEN 'Cancelled'
         ELSE 'Refunded' END
FROM n;
GO

/* ---------- Order items (1-4 lines per order) ---------- */

DROP TABLE IF EXISTS #lines;

SELECT
    o.OrderID,
    1 + ABS(CHECKSUM(NEWID())) % 20 AS ProductID,
    CASE WHEN o.CustomerID <= 25
         THEN 3 + ABS(CHECKSUM(NEWID())) % 8      -- big buyers: 3-10 units
         ELSE 1 + ABS(CHECKSUM(NEWID())) % 3 END  -- others: 1-3 units
        AS Quantity,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 0.10 ELSE 0.00 END AS Discount
INTO #lines
FROM dbo.Orders o
CROSS JOIN (VALUES (1),(2),(3),(4)) v(LineNum)
WHERE v.LineNum <= o.OrderID % 4 + 1;

INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice, Discount)
SELECT l.OrderID, l.ProductID, l.Quantity, p.ListPrice, l.Discount
FROM #lines l
JOIN dbo.Products p ON p.ProductID = l.ProductID;

DROP TABLE #lines;
GO

/* ---------- Quick checks ---------- */

-- Row counts
SELECT 'Customers' AS TableName, COUNT(*) AS Rows FROM dbo.Customers
UNION ALL SELECT 'Products',   COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;

-- Premium customers (lifetime completed revenue > 10,000)
SELECT COUNT(*) AS PremiumCustomers
FROM (
    SELECT o.CustomerID
    FROM dbo.Orders o
    JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
    WHERE o.Status = 'Completed'
    GROUP BY o.CustomerID
    HAVING SUM(oi.Quantity * oi.UnitPrice * (1 - oi.Discount)) > 10000
) p;

-- Revenue by quarter
SELECT
    YEAR(o.OrderDate) AS [Year],
    DATEPART(QUARTER, o.OrderDate) AS [Quarter],
    CAST(SUM(oi.Quantity * oi.UnitPrice * (1 - oi.Discount)) AS DECIMAL(12,2)) AS Revenue
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
WHERE o.Status = 'Completed'
GROUP BY YEAR(o.OrderDate), DATEPART(QUARTER, o.OrderDate)
ORDER BY [Year], [Quarter];
GO
