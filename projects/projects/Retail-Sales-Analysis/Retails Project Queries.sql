CREATE DATABASE RETAIL_NOVA

-- Indexes for faster joins and filters
CREATE INDEX idx_sales_customer ON sales_cleaned(Customer_Id);
CREATE INDEX idx_sales_product ON sales_cleaned(Product_Id);
CREATE INDEX idx_sales_store ON sales_cleaned(Store_Id);
CREATE INDEX idx_sales_order_date ON sales_cleaned(Order_Date);

CREATE INDEX idx_returns_order ON returns_cleaned(Order_Id);
CREATE INDEX idx_customers_region ON customers_cleaned(Region);
CREATE INDEX idx_products_category ON products_cleaned(Category);
CREATE INDEX idx_stores_region ON stores_cleaned(Region);

-- SALES Table: Link to CUSTOMERS
ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_customer
FOREIGN KEY (Customer_Id)
REFERENCES customers_cleaned(Customer_Id);

-- SALES Table: Link to PRODUCTS
ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_product
FOREIGN KEY (Product_Id)
REFERENCES products_cleaned(Product_Id);

-- SALES Table: Link to STORES
ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_store
FOREIGN KEY (Store_Id)
REFERENCES stores_cleaned(Store_Id);

-- RETURNS Table: Link to SALES
ALTER TABLE returns_cleaned
ADD CONSTRAINT fk_returns_order
FOREIGN KEY (Order_Id)
REFERENCES sales_cleaned(Order_Id);


--1. What is the total revenue generated in the last 12 months?

SELECT 
    SUM(Total_Amount) AS Total_Revenue_Last_12_Months
FROM sales_cleaned
WHERE Order_Date >= DATEADD(MONTH, -12, GETDATE());

--2. Which are the top 5 best-selling products by quantity? 

SELECT TOP 5
    P.Product_Id,
    P.Product_Name,
    SUM(S.Quantity) AS Total_Quantity_Sold
FROM sales_cleaned S
JOIN products_cleaned P ON S.Product_Id = P.Product_Id
GROUP BY P.Product_Id, P.Product_Name
ORDER BY Total_Quantity_Sold DESC;

--3. How many customers are from each region? 

SELECT 
    Region,
    COUNT(*) AS Customer_Count
FROM customers_cleaned
GROUP BY Region
ORDER BY Customer_Count DESC;

--4. Which store has the highest profit in the past year? 

SELECT TOP 1
    st.Store_Id,st.Store_Name,st.Region,st.City,
    ROUND(SUM((s.Unit_Price - p.Cost_Price) * s.Quantity * (1 - s.Discount_Pct)), 2) AS Total_Profit
FROM sales_cleaned s
JOIN products_cleaned p ON s.Product_Id = p.Product_Id
JOIN stores_cleaned st ON s.Store_Id = st.Store_Id
WHERE s.Order_Date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY st.Store_Id, st.Store_Name, st.Region, st.City
ORDER BY Total_Profit DESC;


--5. What is the return rate by product category? 

SELECT 
    p.Category,
    COUNT(DISTINCT r.Order_Id) AS Returned_Orders,
    COUNT(DISTINCT s.Order_Id) AS Total_Orders,
    ROUND(CAST(COUNT(DISTINCT r.Order_Id) AS FLOAT) / COUNT(DISTINCT s.Order_Id) * 100, 2) AS Return_Rate_Percent
FROM products_cleaned p
JOIN sales_cleaned s ON p.Product_Id = s.Product_Id
LEFT JOIN returns_cleaned r ON s.Order_Id = r.Order_Id
GROUP BY p.Category
ORDER BY Return_Rate_Percent DESC;

--6. What is the average revenue per customer by age group?

SELECT 
    c.Age_Group,
    COUNT(DISTINCT c.Customer_Id) AS Unique_Customers,
    ROUND(SUM(s.Total_Amount), 2) AS Total_Revenue,
    ROUND(SUM(s.Total_Amount) / COUNT(DISTINCT c.Customer_Id), 2) AS Avg_Revenue_Per_Customer
FROM customers_cleaned c
JOIN sales_cleaned s ON c.Customer_Id = s.Customer_Id
GROUP BY c.Age_Group
ORDER BY Avg_Revenue_Per_Customer DESC;

--7. Which sales channel (Online vs In-Store) is more profitable on average? 

SELECT 
    s.Sales_Channel,
    COUNT(DISTINCT s.Order_Id) AS Total_Orders,
    ROUND(SUM((s.Unit_Price - p.Cost_Price) * s.Quantity * (1 - s.Discount_Pct)), 2) AS Total_Profit,
    ROUND(SUM((s.Unit_Price - p.Cost_Price) * s.Quantity * (1 - s.Discount_Pct)) / COUNT(DISTINCT s.Order_Id), 2) AS Avg_Profit_Per_Order
FROM sales_cleaned s
JOIN products_cleaned p ON s.Product_Id = p.Product_Id
GROUP BY s.Sales_Channel
ORDER BY Avg_Profit_Per_Order DESC;

--8. How has monthly profit changed over the last 2 years by region? 

SELECT 
    FORMAT(s.Order_Date, 'yyyy-MM') AS Order_Month,
    st.Region,
    ROUND(SUM((s.Unit_Price - p.Cost_Price) * s.Quantity * (1 - s.Discount_Pct)), 2) AS Total_Profit
FROM sales_cleaned s
JOIN products_cleaned p ON s.Product_Id = p.Product_Id
JOIN stores_cleaned st ON s.Store_Id = st.Store_Id
WHERE s.Order_Date >= DATEADD(YEAR, -2, CAST(GETDATE() AS DATE))
GROUP BY FORMAT(s.Order_Date, 'yyyy-MM'), st.Region
ORDER BY Order_Month, st.Region;


--9. Identify the top 3 products with the highest return rate in each category. 

WITH Product_Stats AS (
    SELECT p.Category,p.Product_Name,
        COUNT(s.Order_Id) AS Total_Sales,
        COUNT(r.Return_Id) AS Total_Returns,
        ROUND(CAST(COUNT(r.Return_Id) AS FLOAT) / NULLIF(COUNT(s.Order_Id), 0), 4) AS Return_Rate
    FROM products_cleaned p
    JOIN sales_cleaned s ON p.Product_Id = s.Product_Id
    LEFT JOIN returns_cleaned r ON s.Order_Id = r.Order_Id
    GROUP BY p.Category, p.Product_Name
),
Ranked_Products AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Return_Rate DESC) AS rank
    FROM Product_Stats
)
SELECT Category, Product_Name, Return_Rate
FROM Ranked_Products
WHERE rank <= 3
ORDER BY Category, rank;

--10. Which 5 customers have contributed the most to total profit, and what is their tenure with the company?

SELECT TOP 5
    c.Customer_Id,
    c.First_Name + ' ' + c.Last_Name AS Customer_Name,
    ROUND(SUM((s.Unit_Price - p.Cost_Price) * s.Quantity * (1 - s.Discount_Pct)), 2) AS Total_Profit,
    DATEDIFF(YEAR, c.Signup_Date, GETDATE()) AS Tenure_Years
FROM sales_cleaned s
JOIN customers_cleaned c ON s.Customer_Id = c.Customer_Id
JOIN products_cleaned p ON s.Product_Id = p.Product_Id
GROUP BY c.Customer_Id, c.First_Name, c.Last_Name, c.Signup_Date
ORDER BY Total_Profit DESC;

