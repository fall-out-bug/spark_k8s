"""
Jupyter GPU E2E tests for Spark 4.1.1.

Tests validate Spark 4.1.1 execution via Jupyter with GPU acceleration (RAPIDS).
Tests use Spark 4.1.1 which includes native GPU support.
"""
import pytest

test_spark_version = "4.1.1"
test_component = "jupyter"
test_mode = "connect-k8s"
test_feature = "gpu"


@pytest.mark.e2e
@pytest.mark.gpu
@pytest.mark.timeout(900)
class TestJupyterGPU411:
    """E2E tests for Jupyter with GPU acceleration on Spark 4.1.1."""

    def test_gpu_q1_count(self, spark_session_with_gpu, sample_dataset_path, query_metrics, gpu_metrics):
        """Test Q1: Count query with GPU acceleration."""
        df = spark_session_with_gpu.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0 AND trip_distance > 0",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_q1_count"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] == 1, "Expected single row with count"
        assert metrics["execution_time"] < 300, "Query took too long"

    def test_gpu_q2_aggregation(self, spark_session_with_gpu, sample_dataset_path, query_metrics, gpu_metrics):
        """Test Q2: Group By aggregation with GPU acceleration."""
        df = spark_session_with_gpu.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, AVG(trip_distance) AS avg_distance,
               AVG(total_amount) AS avg_total
               FROM nyc_taxi
               WHERE passenger_count > 0 AND passenger_count <= 10 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_q2_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected multiple passenger groups"
        assert metrics["execution_time"] < 300, "Query took too long"

    def test_gpu_q3_join(self, spark_session_with_gpu, sample_dataset_path, query_metrics, gpu_metrics):
        """Test Q3: Join query with GPU acceleration."""
        df = spark_session_with_gpu.read.parquet(sample_dataset_path)
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
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_q3_join"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["execution_time"] < 600, "Join query took too long"

    def test_gpu_q4_sort(self, spark_session_with_gpu, sample_dataset_path, query_metrics, gpu_metrics):
        """Test Q4: Sort operation with GPU acceleration."""
        df = spark_session_with_gpu.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, fare_amount, total_amount, trip_distance
            FROM nyc_taxi
            WHERE total_amount > 0 AND fare_amount > 0
            ORDER BY fare_amount DESC, total_amount DESC
            LIMIT 1000""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_q4_sort"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] <= 1000, "Sort returned too many rows"


@pytest.mark.e2e
@pytest.mark.gpu
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestJupyterGPU411FullDataset:
    """E2E tests with full NYC Taxi dataset using GPU acceleration."""

    def test_gpu_full_q1_count(self, spark_session_with_gpu, dataset_path, query_metrics, gpu_metrics):
        """Test Q1 with full dataset and GPU."""
        df = spark_session_with_gpu.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_full_q1_count"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        result = spark_session_with_gpu.sql("SELECT * FROM nyc_taxi LIMIT 1").collect()
        assert len(result) > 0, "Dataset is empty"

    def test_gpu_full_q2_aggregation(self, spark_session_with_gpu, dataset_path, query_metrics, gpu_metrics):
        """Test Q2 with full dataset and GPU."""
        df = spark_session_with_gpu.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, SUM(fare_amount) AS total_fare
               FROM nyc_taxi
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_full_q2_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected aggregation results"
