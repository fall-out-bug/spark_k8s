"""
Jupyter k8s-submit E2E tests for Spark 3.5.7.

Tests validate Spark 3.5.7 execution via Jupyter notebook with k8s-submit mode.
"""
import pytest
from pathlib import Path

test_spark_version = "3.5.7"
test_component = "jupyter"
test_mode = "k8s-submit"


@pytest.mark.e2e
@pytest.mark.timeout(600)
class TestJupyterK8s357:
    """E2E tests for Jupyter with Spark 3.5.7 in k8s-submit mode."""

    def test_q1_count(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q1: Count query."""
        # Load dataset
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        # Execute query
        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0 AND trip_distance > 0",
            f"{test_component}_{test_mode}_{test_spark_version}_q1_count"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] == 1, "Expected single row with count"
        assert metrics["execution_time"] < 300, "Query took too long"

    def test_q2_aggregation(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q2: Group By aggregation."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, AVG(trip_distance) AS avg_distance,
               AVG(total_amount) AS avg_total
               FROM nyc_taxi
               WHERE passenger_count > 0 AND passenger_count <= 10 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_spark_version}_q2_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected multiple passenger groups"
        assert metrics["execution_time"] < 300, "Query took too long"

    def test_q3_join(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q3: Join with filter."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """WITH trip_stats AS (
               SELECT PULocationID, COUNT(*) AS pickup_count, AVG(trip_distance) AS avg_distance
               FROM nyc_taxi WHERE total_amount > 0 GROUP BY PULocationID
            )
            SELECT a.PULocationID, a.pickup_count, a.avg_distance,
                   b.pickup_count AS dropoff_count
            FROM trip_stats a
            INNER JOIN trip_stats b ON a.PULocationID = b.DOLocationID
            WHERE a.pickup_count > 10 AND b.pickup_count > 10
            ORDER BY a.pickup_count DESC
            LIMIT 100""",
            f"{test_component}_{test_mode}_{test_spark_version}_q3_join"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["execution_time"] < 600, "Join query took too long"

    def test_q4_window(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test Q4: Window function."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, tpep_pickup_datetime, fare_amount,
               SUM(fare_amount) OVER (PARTITION BY passenger_count
                   ORDER BY tpep_pickup_datetime
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
            FROM nyc_taxi
            WHERE passenger_count BETWEEN 1 AND 2
              AND total_amount > 0 AND fare_amount > 0
            LIMIT 1000""",
            f"{test_component}_{test_mode}_{test_spark_version}_q4_window"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] <= 1000, "Window function returned too many rows"
        assert metrics["execution_time"] < 600, "Window query took too long"


@pytest.mark.e2e
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestJupyterK8s357FullDataset:
    """E2E tests with full NYC Taxi dataset (11GB)."""

    @pytest.fixture(autouse=True)
    def requires_full_dataset(self, dataset_path):
        """Skip if full dataset not available."""
        if not Path(dataset_path).exists():
            pytest.skip("Full dataset not available")

    def test_full_dataset_q1_count(
        self,
        spark_session,
        dataset_path,
        query_metrics
    ):
        """Test Q1 with full dataset."""
        df = spark_session.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0",
            f"{test_component}_{test_mode}_{test_spark_version}_full_q1_count"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        # Full dataset should have many more rows
        result = spark_session.sql("SELECT * FROM nyc_taxi LIMIT 1").collect()
        assert len(result) > 0, "Dataset is empty"

    def test_full_dataset_q2_aggregation(
        self,
        spark_session,
        dataset_path,
        query_metrics
    ):
        """Test Q2 with full dataset."""
        df = spark_session.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare
               FROM nyc_taxi
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_spark_version}_full_q2_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected aggregation results"
        assert metrics["execution_time"] < 900, "Full dataset aggregation took too long"
