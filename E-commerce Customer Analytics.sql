

/*E-commerce Customer Analytics - SQL Analysis */

-- 1. Verify row counts
SELECT COUNT(*) AS customer_count FROM customers;
SELECT COUNT(*) AS order_count FROM orders;

-- 2. Check for duplicate orders
SELECT order_id, customer_id, order_date, total_amount, COUNT(*) AS cnt
FROM orders
GROUP BY order_id, customer_id, order_date, total_amount
HAVING COUNT(*) > 1;

-- 3. Remove duplicate orders (keep first occurrence)
WITH CTE_Duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, customer_id, order_date, total_amount
            ORDER BY order_id
        ) AS rn
    FROM orders
)
DELETE FROM CTE_Duplicates
WHERE rn > 1;

-- 4. Check missing values
SELECT 
    SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END) AS missing_payment,
    SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END) AS zero_quantity
FROM orders;

-- 5. Clean missing payment_method
UPDATE orders
SET payment_method = 'Unknown'
WHERE payment_method IS NULL;

-- 6. Remove invalid orders (zero quantity = data entry error)
DELETE FROM orders
WHERE quantity = 0;

-- 7. Clean city name formatting
UPDATE customers
SET city = TRIM(city);

-- 8. Standardize city casing
UPDATE customers
SET city = UPPER(LEFT(city,1)) + LOWER(SUBSTRING(city, 2, LEN(city)));

-- 9. Total revenue and order count by customer (base for RFM)
SELECT 
    customer_id,
    COUNT(order_id) AS frequency,
    SUM(total_amount) AS monetary,
    MAX(order_date) AS last_order_date
FROM orders
WHERE order_status = 'Delivered'
GROUP BY customer_id;

-- 10. RFM Analysis (Recency, Frequency, Monetary)
WITH RFM_Base AS (
    SELECT 
        customer_id,
        DATEDIFF(DAY, MAX(order_date), '2026-06-30') AS recency_days,
        COUNT(order_id) AS frequency,
        SUM(total_amount) AS monetary
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
RFM_Scores AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM RFM_Base
)
SELECT *,
    CASE 
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 2 THEN 'Loyal Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost/Churned'
        ELSE 'Potential Loyalist'
    END AS customer_segment
FROM RFM_Scores;

-- 11. Repeat purchase rate
SELECT 
    COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END) * 100.0 / COUNT(DISTINCT customer_id) AS repeat_purchase_rate_pct
FROM (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
) t;

-- 12. Monthly revenue trend
SELECT 
    FORMAT(order_date, 'yyyy-MM') AS month,
    SUM(total_amount) AS total_revenue,
    COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY FORMAT(order_date, 'yyyy-MM')
ORDER BY month;

-- 13. Top product categories by revenue
SELECT 
    product_category,
    SUM(total_amount) AS total_revenue,
    COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY product_category
ORDER BY total_revenue DESC;

-- 14. Revenue by acquisition channel
SELECT 
    c.acquisition_channel,
    SUM(o.total_amount) AS total_revenue,
    COUNT(DISTINCT o.customer_id) AS customers,
    COUNT(o.order_id) AS total_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.acquisition_channel
ORDER BY total_revenue DESC;

-- 15. Order status breakdown (cancellation/return rate)
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 16. Revenue by city (top 10)
SELECT TOP 10
    c.city,
    SUM(o.total_amount) AS total_revenue,
    COUNT(o.order_id) AS total_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city
ORDER BY total_revenue DESC;