"""
Airflow k8s-submit E2E tests for Spark 3.5.8.

Tests validate Spark 3.5.8 execution via Airflow DAG with k8s-submit mode.
"""
import pytest
from pathlib import Path

test_spark_version = "3.5.8"
test_component = "airflow"
test_mode = "k8s-submit"


@pytest.mark.e2e
@pytest.mark.timeout(600)
class TestAirflowK8s358:
    """E2E tests for Airflow with Spark 3.5.8 in k8s-submit mode."""

    def test_q1_count(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q1: Count query via Airflow DAG."""
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
        """Test Q2: Group By aggregation via Airflow DAG."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, AVG(total_amount) AS avg_total
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
        """Test Q3: Join with filter via Airflow DAG."""
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
        """Test Q4: Window function via Airflow DAG."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, fare_amount,
               AVG(fare_amount) OVER (PARTITION BY passenger_count
                   ORDER BY fare_amount DESC
                   ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) AS rolling_avg
            FROM nyc_taxi
            WHERE passenger_count = 1 AND total_amount > 0 AND fare_amount > 0
            LIMIT 1000""",
            f"{test_component}_{test_mode}_{test_spark_version}_q4_window"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] <= 1000
        assert metrics["execution_time"] < 600
