-- Q3: Join with Filter
-- Validates join performance (self-join for comparison)
-- Compares trip distances between pickup locations

WITH trip_stats AS (
    SELECT
        PULocationID,
        COUNT(*) AS pickup_count,
        AVG(trip_distance) AS avg_distance
    FROM nyc_taxi
    WHERE total_amount > 0
    GROUP BY PULocationID
)
SELECT
    a.PULocationID,
    a.pickup_count,
    a.avg_distance,
    b.pickup_count AS dropoff_count,
    b.avg_distance AS dropoff_avg_distance
FROM trip_stats a
INNER JOIN trip_stats b ON a.PULocationID = b.DOLocationID
WHERE a.pickup_count > 100
  AND b.pickup_count > 100
ORDER BY a.pickup_count DESC
LIMIT 100
