-- Q1: Count Query
-- Validates basic row count functionality
-- Returns total number of taxi trips in dataset

SELECT COUNT(*) AS total_trips
FROM nyc_taxi
WHERE total_amount > 0
  AND trip_distance > 0
