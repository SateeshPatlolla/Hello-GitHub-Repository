SELECT * FROM Region_table;
--------------------------------------------------------------------------------
SELECT COUNT(*) FROM Region_table;
--------------------------------------------------------------------------------
SELECT * FROM Country_table;
--------------------------------------------------------------------------------
SELECT COUNT(*) FROM Country_table;
--------------------------------------------------------------------------------
SELECT *
FROM Country_table AS ct
JOIN Region_table AS rt
USING(Region_ID) 
--------------------------------------------------------------------------------
SELECT * FROM Customer_table;
--------------------------------------------------------------------------------
SELECT * FROM Customer_table AS cst
INNER JOIN Country_table AS ct
ON cst.Country_ID = ct.Country_ID
INNER JOIN Region_table AS rt
ON rt.Region_ID = ct.Region_ID
--------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-- Determine the product category with the highest number of distinct products
SELECT * FROM Product_Category_table;

SELECT * FROM Product_table;

SELECT  pct.Product_Category,  COUNT(DISTINCT pt.Product_Name) AS No_Of_Distinct_Products
FROM Product_Category_table AS pct
INNER JOIN Product_table AS pt
ON pct.Product_Category_ID = pt.Product_Category_ID
GROUP BY pct.Product_Category
ORDER BY No_Of_Distinct_Products DESC
LIMIT 1;

-----------------------------------------------------------------------------------------



























































