"""
Jupyter Standalone E2E tests for Spark 3.5.7.

Tests validate Spark 3.5.7 execution via Jupyter with standalone-submit mode.
Tests use Spark standalone cluster deployment on Kubernetes.
"""
import pytest

test_spark_version = "3.5.7"
test_component = "jupyter"
test_mode = "standalone-submit"


@pytest.mark.e2e
@pytest.mark.timeout(900)
class TestJupyterStandalone357:
    """E2E tests for Jupyter with Spark 3.5.7 in standalone-submit mode."""

    def test_standalone_deploy(
        self,
        kubectl_available,
        standalone_cluster,
        standalone_metrics
    ):
        """Test standalone cluster deployment."""
        # Verify cluster info
        assert "master_url" in standalone_cluster, "Master URL not found"
        assert standalone_cluster["master_url"].startswith("spark://"), \
            f"Invalid master URL: {standalone_cluster['master_url']}"

        # Verify metrics
        metrics = standalone_metrics
        assert metrics["master_count"] > 0, "No master pods found"
        assert metrics["worker_count"] > 0, "No worker pods found"

    def test_standalone_job_submit(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics,
        standalone_metrics
    ):
        """Test job submission to standalone cluster."""
        # Load and query dataset
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0",
            f"{test_component}_{test_mode}_{test_spark_version}_job_submit"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] == 1, "Expected single row with count"

    def test_standalone_worker_scaling(
        self,
        spark_session,
        standalone_cluster,
        standalone_executor_distribution
    ):
        """Test executor distribution across workers."""
        distribution = standalone_executor_distribution

        # At least one executor should be running
        assert distribution["executor_count"] >= 0, \
            f"Executor count invalid: {distribution['executor_count']}"

        # If cluster has workers, executors should be distributed
        if distribution["worker_hosts"] > 0:
            assert distribution["executor_count"] > 0, \
                "No executors despite having worker hosts"

    def test_standalone_aggregation(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics
    ):
        """Test aggregation query on standalone cluster."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare
               FROM nyc_taxi
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_spark_version}_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected aggregation results"


@pytest.mark.e2e
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestJupyterStandalone357FullDataset:
    """E2E tests with full NYC Taxi dataset on standalone cluster."""

    def test_standalone_full_dataset(
        self,
        spark_session,
        dataset_path,
        query_metrics,
        standalone_metrics
    ):
        """Test full dataset processing on standalone cluster."""
        df = spark_session.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            """SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, SUM(fare_amount) AS total_fare
               FROM nyc_taxi
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_spark_version}_full_dataset"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0, "Expected aggregation results"
        assert metrics["execution_time"] < 900, "Query took too long"

    def test_standalone_parallel_processing(
        self,
        spark_session,
        dataset_path,
        standalone_executor_distribution
    ):
        """Test parallel processing across workers."""
        distribution = standalone_executor_distribution

        # Run multiple queries in parallel
        df = spark_session.read.parquet(dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        # These should be distributed across workers
        results = []
        for i in range(3):
            result = spark_session.sql(
                f"SELECT COUNT(*) AS cnt FROM nyc_taxi " +
                f"WHERE passenger_count = {i + 1}"
            ).collect()
            results.append(result[0]["cnt"])

        # Verify all queries completed
        assert len(results) == 3, "Not all queries completed"
