-- Created by Amirhossein Tonekaboni, SAP Business One Consultant
-- Date: May 17, 2025
-- Contact: https://linkedin.com/in/atonekaboni
-- Version: 1.0
-- Description: SQL query to replicate inventory tab with next available date
-- Use [%0] to select an item code; leave blank for all items
-- Test in a non-production environment
-- Licensed under MIT License
-- Note for Query Generator Users: The SQL files in this repository include comments for documentation. If you encounter issues in the SBO Query Generator, remove the comments (lines starting with --) before running the query.

SELECT 
    T0.ItemCode,
    T0.ItemName,
    T1.WhsCode AS WarehouseCode,
    T2.WhsName AS WarehouseName,
    SUM(T1.OnHand) AS OnHand,
    SUM(T1.OnOrder) AS OnOrder,
    SUM(T1.IsCommited) AS Committed,
    SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) AS Available,
    CASE 
        WHEN SUM(T1.OnHand) > 0 THEN 
            ROUND(SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) * 100.0 / SUM(T1.OnHand), 2)
        ELSE 0 
    END AS AvailabilityPercent,
    NULL AS NextAvailableDate
FROM OITM T0
LEFT JOIN OITW T1 ON T0.ItemCode = T1.ItemCode
LEFT JOIN OWHS T2 ON T1.WhsCode = T2.WhsCode
WHERE T0.ItemCode = CASE WHEN '[%0]' = '' THEN T0.ItemCode ELSE '[%0]' END
GROUP BY T0.ItemCode, T0.ItemName, T1.WhsCode, T2.WhsName

UNION ALL

SELECT 
    T0.ItemCode,
    T0.ItemName,
    'TOTAL' AS WarehouseCode,
    'TOTAL' AS WarehouseName,
    SUM(T1.OnHand) AS TotalOnHand,
    SUM(T1.OnOrder) AS TotalOnOrder,
    SUM(T1.IsCommited) AS TotalCommitted,
    SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) AS TotalAvailable,
    CASE 
        WHEN SUM(T1.OnHand) > 0 THEN 
            ROUND(SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) * 100.0 / SUM(T1.OnHand), 2)
        ELSE 0 
    END AS TotalAvailabilityPercent,
    COALESCE((
        SELECT TOP 1 CONVERT(NVARCHAR(30), ChangeDate, 23)
        FROM (
            SELECT 
                CONVERT(DATE, T3.DocDueDate) AS ChangeDate, 
                (T2.Quantity - ISNULL(T2.OpenQty, 0)) AS ChangeQty
            FROM POR1 T2
            JOIN OPOR T3 ON T2.DocEntry = T3.DocEntry
            WHERE T2.ItemCode = T0.ItemCode AND T3.DocStatus = 'O' AND T3.DocDueDate >= GETDATE()

            UNION ALL

            SELECT 
                CONVERT(DATE, T5.DocDueDate) AS ChangeDate, 
                -(T4.Quantity - ISNULL(T4.OpenQty, 0)) AS ChangeQty
            FROM RDR1 T4
            JOIN ORDR T5 ON T4.DocEntry = T5.DocEntry
            WHERE T4.ItemCode = T0.ItemCode AND T5.DocStatus = 'O' AND T5.DocDueDate >= GETDATE()
        ) Changes
        WHERE ChangeDate IS NOT NULL
        GROUP BY ChangeDate
        HAVING SUM(ChangeQty) + SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) > 0
        ORDER BY ChangeDate
    ), 
    CASE 
        WHEN SUM(T1.OnHand - T1.IsCommited + T1.OnOrder) > 0 THEN CONVERT(NVARCHAR(30), GETDATE(), 23)
        ELSE 'No stock available'
    END) AS NextAvailableDate
FROM OITM T0
LEFT JOIN OITW T1 ON T0.ItemCode = T1.ItemCode
WHERE T0.ItemCode = CASE WHEN '[%0]' = '' THEN T0.ItemCode ELSE '[%0]' END
GROUP BY T0.ItemCode, T0.ItemName

ORDER BY ItemCode, WarehouseCode; 
