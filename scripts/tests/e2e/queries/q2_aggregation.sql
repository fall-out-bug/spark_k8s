-- Q2: Group By Aggregation
-- Validates aggregation performance
-- Groups by passenger count and calculates average fare

SELECT
    passenger_count,
    COUNT(*) AS trip_count,
    AVG(fare_amount) AS avg_fare,
    AVG(trip_distance) AS avg_distance,
    AVG(total_amount) AS avg_total
FROM nyc_taxi
WHERE passenger_count > 0
  AND passenger_count <= 10
  AND total_amount > 0
GROUP BY passenger_count
ORDER BY passenger_count
