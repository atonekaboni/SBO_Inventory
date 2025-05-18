/* 
Tutorial: Conceptual Available-to-Promise (ATP) Calculation in SQL for SAP Business One
Author: Amirhossein Tonekaboni, SAP Business One Consultant
Contact: https://linkedin.com/in/atonekaboni
Version: 1.0
Date: May 17, 2025
Purpose: Teach the concept, logic, and SQL framework for ATP using SAP B1 tables.
Note: Educational only; placeholders and abstracted logic prevent direct execution.
*/

/* 
Step 1: Define Input Parameters
Logic: Variables scope the query to an item, warehouse, and time period, filtering data. 
In SAP B1, ItemCode and WhsCode are key for inventory queries.
How To: Use DECLARE to set variables matching SAP B1 table fields.
*/

DECLARE @ItemCode NVARCHAR(50) = 'P20002';  -- Item to analyze
DECLARE @WhsCode NVARCHAR(50) = '01';      -- Warehouse to check
DECLARE @FromDate DATE = '2014-05-01';     -- Start date for transactions

/* 
Step 2: Capture Initial Stock
Logic: Get current stock from OITW, SAP B1’s item warehouse table. SUM aggregates 
stock, with ISNULL ensuring 0 for no stock. This baseline starts the ATP calculation.
How To: Query OITW, filter by ItemCode and WhsCode, handle nulls.
*/

DECLARE @OnHand DECIMAL(18,6) = (
    SELECT ISNULL(SUM([StockQuantityField]), 0)  -- Placeholder for OnHand
    FROM OITW  -- SAP B1 table for item warehouse stock
    WHERE ItemCode = @ItemCode AND WhsCode = @WhsCode
);

/* 
Step 3: Retrieve Item Metadata
Logic: Fetch item name from OITM, SAP B1’s item master table, for output readability. 
This one-time lookup avoids redundant joins, improving performance.
How To: Query OITM once, store ItemName in a variable for final SELECT.
*/

DECLARE @ItemName NVARCHAR(255) = (
    SELECT [ItemNameField]  -- Placeholder for ItemName
    FROM OITM  -- SAP B1 table for item master data
    WHERE ItemCode = @ItemCode
);

/* 
Step 4: Aggregate Transactions with a CTE
Logic: A CTE (ATPData) unifies data from multiple SAP B1 document types (initial stock, 
sales orders, purchase orders, production orders, transfer requests) using UNION ALL. 
Each SELECT aligns columns (SortOrder, DeliveryDate, Ordered, Committed) to form a 
stock change timeline. SortOrder ensures initial stock is first, then transactions.
How To: Define a CTE with UNION ALL, align SELECTs, use SortOrder for sequence.
*/

WITH ATPData AS (
    /* 
    Initial Stock Snapshot
    Logic: Static row for current stock, SortOrder 0 to appear first. No table queried; 
    aligns with CTE structure. DeliveryDate is NULL, Ordered/Committed are 0, using 
    @OnHand in final SELECT. This sets the ATP starting point.
    How To: Create a static SELECT, set SortOrder 0, match CTE columns.
    */
    SELECT 
        0 AS SortOrder,
        CAST(NULL AS DATE) AS DeliveryDate,
        'Available Stock' AS DocType,
        'OnHand' AS Document,
        0 AS Ordered,
        0 AS Committed
        -- Fields like BPCode, UoM omitted; typically NULL

    UNION ALL

    /* 
    Sales Orders (Stock Out)
    Logic: Identifies stock reserved for customers, reducing availability. Queries ORDR 
    (headers) and RDR1 (lines), filtering for open, non-canceled orders by item, 
    warehouse, and date. Aggregates open quantities as Committed, using due date for 
    timeline. Joins OWHS, OCRD for context.
    How To: Join ORDR/RDR1, filter open transactions, aggregate quantities, use due dates.
    */
    SELECT 
        1 AS SortOrder,
        T0.[DueDateField] AS DeliveryDate,  -- Placeholder for DocDueDate
        'Sales Order' AS DocType,
        CAST(T0.[DocNumField] AS VARCHAR(50)) AS Document,  -- Placeholder for DocNum
        0 AS Ordered,
        SUM(T1.[OpenQuantityField]) AS Committed  -- Placeholder for OpenQty
    FROM ORDR T0  -- SAP B1 table for sales order headers
    INNER JOIN RDR1 T1 ON T0.DocEntry = T1.DocEntry  -- SAP B1 table for sales order lines
    INNER JOIN OWHS T2 ON T1.WhsCode = T2.WhsCode  -- SAP B1 table for warehouse details
    LEFT JOIN OCRD ON T0.[CardCodeField] = OCRD.CardCode  -- SAP B1 table for business partners
    -- WHERE T1.ItemCode = @ItemCode AND T1.WhsCode = @WhsCode
    --   AND T0.[CanceledField] = 'N' AND T1.[LineStatusField] = 'O'
    --   AND T0.[DueDateField] >= @FromDate
    -- GROUP BY [DueDateField], [OtherFields]
    -- Note: Conditions abstracted for concept

    UNION ALL

    /* 
    Purchase Orders (Stock In)
    Logic: Captures stock from suppliers, increasing availability. Queries OPOR (headers) 
    and POR1 (lines), filtering for open, non-canceled orders. Aggregates quantities as 
    Ordered, using due date. Joins OWHS, OCRD for details.
    How To: Join OPOR/POR1, filter transactions, aggregate quantities, include due dates.
    */

    SELECT 
        2 AS SortOrder,
        T0.[DueDateField] AS DeliveryDate,  -- Placeholder for DocDueDate
        'Purchase Order' AS DocType,
        CAST(T0.[DocNumField] AS VARCHAR(50)) AS Document,
        SUM(T1.[QuantityField]) AS Ordered,  -- Placeholder for Quantity
        0 AS Committed
    FROM OPOR T0  -- SAP B1 table for purchase order headers
    INNER JOIN POR1 T1 ON T0.DocEntry = T1.DocEntry  -- SAP B1 table for purchase order lines
    INNER JOIN OWHS T2 ON T1.WhsCode = T2.WhsCode  -- SAP B1 table for warehouse details
    LEFT JOIN OCRD ON T0.[CardCodeField] = OCRD.CardCode  -- SAP B1 table for business partners
    -- WHERE T1.ItemCode = @ItemCode AND T1.WhsCode = @WhsCode
    --   AND T0.[CanceledField] = 'N' AND T1.[LineStatusField] = 'O'
    --   AND T0.[DueDateField] >= @FromDate
    -- GROUP BY [DueDateField], [OtherFields]
    -- Note: Logic generalized

    UNION ALL

    /* 
    Production Orders (Stock In)
    Logic: Accounts for stock from manufacturing, increasing availability. Queries OWOR, 
    filtering for active orders (e.g., Planned/Released). Uses planned quantities as 
    Ordered, with due date. Joins OITM, OWHS for details.
    How To: Query OWOR, filter statuses, use planned quantities, align with CTE.
    */

    SELECT 
        3 AS SortOrder,
        OWOR.[DueDateField] AS DeliveryDate,  -- Placeholder for DueDate
        'Production Order' AS DocType,
        CAST(OWOR.[DocNumField] AS VARCHAR(50)) AS Document,
        OWOR.[PlannedQuantityField] AS Ordered,  -- Placeholder for PlannedQty
        0 AS Committed
    FROM OWOR  -- SAP B1 table for production orders
    INNER JOIN OITM ON OWOR.ItemCode = OITM.ItemCode  -- SAP B1 table for item master data
    LEFT JOIN OWHS ON OWOR.[WarehouseField] = OWHS.WhsCode  -- SAP B1 table for warehouse details
    -- WHERE OWOR.ItemCode = @ItemCode AND OWOR.[WarehouseField] = @WhsCode
    --   AND OWOR.[StatusField] IN ('P', 'R')
    --   AND OWOR.[DueDateField] >= @FromDate
    -- Note: Filters simplified

    UNION ALL

    /* 
    Transfer Requests (Stock In/Out)
    Logic: Handles inter-warehouse movements, increasing or decreasing availability. 
    Queries OWTQ (headers) and WTR1 (lines), using CASE to assign quantities as Ordered 
    (incoming) or Committed (outgoing) based on warehouse. Uses due date. Joins OWHS for 
    warehouse names.
    How To: Use CASE for quantity logic, join OWTQ/WTR1, filter warehouse movements.
    */

    SELECT 
        4 AS SortOrder,
        T0.[DueDateField] AS DeliveryDate,  -- Placeholder for DocDueDate
        'Transfer Request' AS DocType,
        CAST(T0.[DocNumField] AS VARCHAR(50)) AS Document,
        CASE 
            WHEN T1.[FromWarehouseField] = @WhsCode THEN 0
            ELSE T1.[QuantityField]  -- Placeholder for Quantity
        END AS Ordered,
        CASE 
            WHEN T1.[FromWarehouseField] = @WhsCode THEN T1.[QuantityField]
            ELSE 0
        END AS Committed
    FROM OWTQ T0  -- SAP B1 table for transfer request headers
    INNER JOIN WTR1 T1 ON T0.DocEntry = T1.DocEntry  -- SAP B1 table for transfer request lines
    LEFT JOIN OWHS T2 ON T1.[FromWarehouseField] = T2.WhsCode  -- SAP B1 table for source warehouse
    LEFT JOIN OWHS T3 ON T1.[ToWarehouseField] = T3.WhsCode  -- SAP B1 table for destination warehouse
    -- WHERE T1.ItemCode = @ItemCode
    --   AND (T1.[FromWarehouseField] = @WhsCode OR T1.[ToWarehouseField] = @WhsCode)
    --   AND T0.[CanceledField] = 'N'
    -- Note: Conditions abstracted
)

/* 
Step 5: Calculate ATP and Format Output
Logic: Computes ATP with window functions: ATP = @OnHand - SUM(Committed) + SUM(Ordered), 
ordered by DeliveryDate and SortOrder. CASE ensures initial stock (NULL DeliveryDate) 
is first. Output shows stock timeline with DocType, DeliveryDate, and ATP.
How To: Use SUM OVER with custom ORDER BY for running totals, sort chronologically.
*/

SELECT 
    @ItemCode AS ItemCode,
    @ItemName AS ItemName,
    DocType,
    Document,
    CAST(DeliveryDate AS DATE) AS DeliveryDate,
    Ordered,
    Committed,
    (@OnHand 
        - SUM(Committed) OVER (ORDER BY 
            CASE WHEN DeliveryDate IS NULL THEN 0 ELSE 1 END, 
            DeliveryDate, SortOrder)  -- Cumulative outgoing stock
        + SUM(Ordered) OVER (ORDER BY 
            CASE WHEN DeliveryDate IS NULL THEN 0 ELSE 1 END, 
            DeliveryDate, SortOrder)  -- Cumulative incoming stock
    ) AS Available  -- ATP value
    -- Fields like UoM, Warehouse omitted
FROM ATPData
ORDER BY 
    CASE WHEN DeliveryDate IS NULL THEN 0 ELSE 1 END,  -- Initial stock first
    DeliveryDate,
    SortOrder;

/* 
Key SQL Framework Components and SAP B1 Tables
- DECLARE: Sets parameters (ItemCode, WhsCode, FromDate).
- CTE with UNION ALL: Unifies OITW, ORDR/RDR1, OPOR/POR1, OWOR, OWTQ/WTR1.
- Window Functions: SUM OVER for running ATP totals.
- CASE: Conditional logic (e.g., transfer quantities).
- JOIN/GROUP BY: Aggregate data from SAP B1 tables.
- Tables: OITW (stock), OITM (items), ORDR/RDR1 (sales), OPOR/POR1 (purchases), 
  OWOR (production), OWTQ/WTR1 (transfers), OWHS (warehouses), OCRD (partners).
Logic Flow: Parameters -> Stock retrieval -> CTE aggregation -> ATP calculation -> Output.
*/
