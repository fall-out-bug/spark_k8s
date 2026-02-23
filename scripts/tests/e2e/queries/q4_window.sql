-- Q4: Window Function
-- Validates complex query performance
-- Calculates running statistics by passenger count

SELECT
    passenger_count,
    tpep_pickup_datetime,
    fare_amount,
    SUM(fare_amount) OVER (
        PARTITION BY passenger_count
        ORDER BY tpep_pickup_datetime
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_fare_total,
    AVG(fare_amount) OVER (
        PARTITION BY passenger_count
        ORDER BY tpep_pickup_datetime
        ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_fare,
    ROW_NUMBER() OVER (
        PARTITION BY passenger_count
        ORDER BY fare_amount DESC
    ) AS fare_rank
FROM nyc_taxi
WHERE passenger_count BETWEEN 1 AND 4
  AND total_amount > 0
  AND fare_amount > 0
QUALIFY fare_rank <= 100
ORDER BY passenger_count, fare_rank
