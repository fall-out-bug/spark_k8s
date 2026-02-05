"""
Jupyter connect-k8s E2E tests for Spark 3.5.8.

Tests validate Spark 3.5.8 execution via Jupyter with Spark Connect in k8s mode.
"""
import pytest
from pathlib import Path

test_spark_version = "3.5.8"
test_component = "jupyter"
test_mode = "connect-k8s"


@pytest.mark.e2e
@pytest.mark.timeout(600)
class TestJupyterConnectK8s358:
    """E2E tests for Jupyter with Spark 3.5.8 in connect-k8s mode."""

    def test_q1_count(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q1: Count query via Spark Connect."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0 AND trip_distance > 0",
            f"{test_component}_{test_mode}_{test_spark_version}_q1_count"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] == 1
        assert metrics["execution_time"] < 300

    def test_q2_aggregation(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q2: Group By aggregation via Spark Connect."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare
               FROM nyc_taxi
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_spark_version}_q2_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0
        assert metrics["execution_time"] < 300

    def test_q3_join(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q3: Join with filter via Spark Connect."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """WITH trip_stats AS (
               SELECT PULocationID, COUNT(*) AS pickup_count
               FROM nyc_taxi WHERE total_amount > 0 GROUP BY PULocationID
            )
            SELECT a.PULocationID, a.pickup_count
            FROM trip_stats a
            INNER JOIN trip_stats b ON a.PULocationID = b.DOLocationID
            WHERE a.pickup_count > 10
            ORDER BY a.pickup_count DESC
            LIMIT 100""",
            f"{test_component}_{test_mode}_{test_spark_version}_q3_join"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["execution_time"] < 600

    def test_q4_window(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q4: Window function via Spark Connect."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, fare_amount,
               SUM(fare_amount) OVER (PARTITION BY passenger_count
                   ORDER BY fare_amount DESC
                   ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) AS rolling_sum
            FROM nyc_taxi
            WHERE passenger_count BETWEEN 1 AND 2 AND total_amount > 0 AND fare_amount > 0
            LIMIT 1000""",
            f"{test_component}_{test_mode}_{test_spark_version}_q4_window"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] <= 1000
        assert metrics["execution_time"] < 600
