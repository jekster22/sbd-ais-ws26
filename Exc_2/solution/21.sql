-- 1. Create Table & Load Data
CREATE TABLE orders (
    customer_name VARCHAR(255),
    product_category VARCHAR(100),
    quantity INTEGER,
    price_per_unit NUMERIC(10, 2),
    order_date DATE,
    country VARCHAR(100)
);

/*
Result:
CREATE TABLE
*/

\copy orders FROM '/data/orders_1M.csv' WITH CSV HEADER;

/*
Result:
COPY 1000000
*/

-- 2. SQL Queries and Results

-- Query A: Which order has the highest price_per_unit?
SELECT * 
FROM orders 
ORDER BY price_per_unit DESC 
LIMIT 1;

/*
Result:
 customer_name | product_category | quantity | price_per_unit | order_date | country 
---------------+------------------+----------+----------------+------------+---------
 Emma Brown    | Automotive       |        3 |        2000.00 | 2024-10-11 | Italy
(1 row)
*/


-- Query B: What are the top 3 product categories with the highest total quantity sold?
SELECT product_category, SUM(quantity) AS total_quantity
FROM orders
GROUP BY product_category
ORDER BY total_quantity DESC
LIMIT 3;

/*
Result:
 product_category | total_quantity 
------------------+----------------
 Health & Beauty  |         300842
 Electronics      |         300804
 Toys             |         300598
(3 rows)
*/


-- Query C: What is the total revenue per product category?
SELECT product_category, SUM(price_per_unit * quantity) AS total_revenue
FROM orders
GROUP BY product_category
ORDER BY total_revenue DESC;

/*
Result:
 product_category | total_revenue 
------------------+---------------
 Automotive       |  306589798.86
 Electronics      |  241525009.45
 Home & Garden    |   78023780.09
 Sports           |   61848990.83
 Health & Beauty  |   46599817.89
 Office Supplies  |   38276061.64
 Fashion          |   31566368.22
 Toys             |   23271039.02
 Grocery          |   15268355.66
 Books            |   12731976.04
(10 rows)
*/


-- Query D: Who are the top 5 customers by total spending?
SELECT customer_name, COUNT(*) AS order_count, SUM(price_per_unit * quantity) AS total_spending
FROM orders
GROUP BY customer_name
ORDER BY total_spending DESC
LIMIT 5;

/*
Result:
 customer_name  | order_count | total_spending 
----------------+-------------+----------------
 Carol Taylor   |        1028 |      991179.18
 Nina Lopez     |         980 |      975444.95
 Daniel Jackson |        1033 |      959344.48
 Carol Lewis    |         943 |      947708.57
 Daniel Young   |         973 |      946030.14
(5 rows)
*/

/*
The top 5 customers have close order counts and total spending. 

I think this happened because in the code we use uniform distribution in random.choice() and random.uniform() to pick names, quantities, and prices evenly.
When you generate 1000000 rows using uniform probability, every customer naturally ends up averaging roughly 946 orders and similar total spend.

*/
