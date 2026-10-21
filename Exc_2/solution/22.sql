-- Step 1: Create Smaller Tables & Measure Growth
CREATE TABLE people_50k  AS SELECT * FROM people_big WHERE id <= 50000;
CREATE TABLE people_100k AS SELECT * FROM people_big WHERE id <= 100000;
CREATE TABLE people_200k AS SELECT * FROM people_big WHERE id <= 200000;

-- Measure the naive self-joins
SELECT COUNT(*) FROM people_50k p1 JOIN people_50k p2 ON p1.country = p2.country;
/*
   count   
----------
 27501822
(1 row)
*/

SELECT COUNT(*) FROM people_100k p1 JOIN people_100k p2 ON p1.country = p2.country;
/*
   count   
-----------
 109946508
(1 row)
*/

SELECT COUNT(*) FROM people_200k p1 JOIN people_200k p2 ON p1.country = p2.country;
/*
   count   
-----------
 439395606
(1 row)
*/

/*
What the numbers show:
Every time we doubled the number of rows, the total pairs and the time it took roughly multiplied by 4. This happens because the query is literally matching every single person with everyone else in their country. 

Since 1 million is 10 times bigger than 100k, the workload will grow by 100x. This means the full table will generate around 11 billion rows and likely take over 10 minutes to finish.
*/


-- Step 2: Does an index help?
CREATE INDEX idx_people_100k_country ON people_100k(country);
ANALYZE people_100k;

EXPLAIN ANALYZE 
SELECT COUNT(*) 
FROM people_100k p1 
JOIN people_100k p2 ON p1.country = p2.country;

/*
The index didn't help because indexes are great for looking up one specific user ID. But  we aren't filtering anything we have to look at every single row anyway so the database realized the index was useless for this and just scanned the whole table. The real problem is the CPU struggling to calculate 11 billion matches in memory.
*/



-- Step 3: Rewrite It
-- Instead of matching everyone one by one I just count how many people are in each country and square that number.

SELECT SUM(k * k) AS total_pairs
FROM (
    SELECT CAST(COUNT(*) AS BIGINT) AS k
    FROM people_big
    GROUP BY country
) subquery;

/*
   total_pairs   
-------------
 10983941260
(1 row)

This changes the whole approach from a massive matching game into a simple math problem. Instead of taking 10 minutes to match rows, it just groups the countries and calculates the math instantly which gives us the exact same answer 10.98 billion pairs.
*/


-- Step 4: Discussion & Business Implications
/*
1  You can't just throw bigger more expensive servers at a badly written query I mean you technically can but at one point it will be too expensive and because the database grows the query will just crash again. Fixing the logic behind the code is the only way to make it scale.

2. What if the business actually needs to see all 11 billion pairs?
   If they actually need the raw data fixing the SQL won't be enough because the database still has to generate 11 billion rows and a normal database would choke on this. We'd have to use some of the heavy-duty data warehouse like Snowflake or BigQuery just to handle that much output.

3. Don't run heavy analytics on a live database:
   Running massive queries like this one on our main Postgres is a terrible idea because it hogs the CPU and memory, which means regular users trying to use the app will experience huge delays or crashes. So for this kind of heavy lifting we should always move the query to a separate database meant for analytics.
*/
