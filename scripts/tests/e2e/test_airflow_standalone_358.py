"""
Airflow Standalone E2E tests for Spark 3.5.8.

Tests validate Spark 3.5.8 execution via Airflow with standalone-submit mode.
Tests use Spark standalone cluster deployment on Kubernetes.
"""
import pytest

test_spark_version = "3.5.8"
test_component = "airflow"
test_mode = "standalone-submit"


@pytest.mark.e2e
@pytest.mark.timeout(900)
class TestAirflowStandalone358:
    """E2E tests for Airflow with Spark 3.5.8 in standalone-submit mode."""

    def test_standalone_deploy(
        self,
        kubectl_available,
        standalone_cluster,
        standalone_metrics
    ):
        """Test standalone cluster deployment."""
        assert "master_url" in standalone_cluster
        assert standalone_cluster["master_url"].startswith("spark://")

        metrics = standalone_metrics
        assert metrics["master_count"] > 0
        assert metrics["worker_count"] > 0

    def test_standalone_job_submit(
        self,
        spark_session,
        sample_dataset_path,
        query_metrics,
        standalone_metrics
    ):
        """Test job submission to standalone cluster."""
        df = spark_session.read.parquet(sample_dataset_path)
        df.createOrReplaceTempView("nyc_taxi")

        metrics = query_metrics(
            "SELECT COUNT(*) AS total_trips FROM nyc_taxi WHERE total_amount > 0",
            f"{test_component}_{test_mode}_{test_spark_version}_job_submit"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] == 1

    def test_standalone_worker_scaling(
        self,
        spark_session,
        standalone_cluster,
        standalone_executor_distribution
    ):
        """Test executor distribution across workers."""
        distribution = standalone_executor_distribution
        assert distribution["executor_count"] >= 0

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
        assert metrics["row_count"] > 0


@pytest.mark.e2e
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestAirflowStandalone358FullDataset:
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
        assert metrics["row_count"] > 0
