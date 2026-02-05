"""
Airflow GPU+Iceberg E2E tests for Spark 4.1.1.

Tests validate combined RAPIDS GPU acceleration with Apache Iceberg
table operations via Airflow with Spark 4.1.1.
"""
import pytest

test_spark_version = "4.1.1"
test_component = "airflow"
test_mode = "connect-k8s"
test_feature = "gpu_iceberg"


@pytest.fixture(scope="function")
def spark_session_with_gpu_and_iceberg(
    spark_session,
    gpu_available,
    iceberg_catalog
):
    """Create Spark session with both GPU and Iceberg enabled."""
    # Enable RAPIDS GPU acceleration
    spark_session.conf.set("spark.rapids.sql.enabled", "true")
    spark_session.conf.set("spark.rapids.sql.incompatibleOps.enabled", "true")
    spark_session.conf.set("spark.rapids.sql.castFloatToString.enabled", "true")

    # Iceberg is already configured via iceberg_catalog fixture
    return spark_session


@pytest.fixture(scope="function")
def gpu_iceberg_table(
    spark_session_with_gpu_and_iceberg,
    iceberg_catalog,
    sample_dataset_path
):
    """Create Iceberg table with GPU support enabled."""
    catalog_name = iceberg_catalog["catalog_name"]
    table_name = f"{catalog_name}.nyc_taxi_gpu"

    # Load and create table
    df = spark_session_with_gpu_and_iceberg.read.parquet(sample_dataset_path)
    df.writeTo(table_name).using("iceberg").create()

    return {
        "table_name": table_name,
        "catalog_name": catalog_name
    }


@pytest.mark.e2e
@pytest.mark.gpu
@pytest.mark.iceberg
@pytest.mark.timeout(900)
class TestAirflowGpuIceberg411:
    """E2E tests for Airflow with GPU+Iceberg on Spark 4.1.1."""

    def test_gpu_iceberg_aggregation(
        self,
        spark_session_with_gpu_and_iceberg,
        gpu_iceberg_table,
        query_metrics,
        gpu_metrics
    ):
        """Test GPU-accelerated aggregation on Iceberg table."""
        table_name = gpu_iceberg_table["table_name"]

        metrics = query_metrics(
            f"""SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, AVG(trip_distance) AS avg_distance
               FROM {table_name}
               WHERE passenger_count > 0 AND passenger_count <= 10
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_aggregation"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0

    def test_gpu_iceberg_join(
        self,
        spark_session_with_gpu_and_iceberg,
        gpu_iceberg_table,
        query_metrics,
        gpu_metrics
    ):
        """Test GPU-accelerated join on Iceberg table."""
        table_name = gpu_iceberg_table["table_name"]

        metrics = query_metrics(
            f"""WITH trip_stats AS (
               SELECT PULocationID, COUNT(*) AS pickup_count, AVG(trip_distance) AS avg_distance
               FROM {table_name} WHERE total_amount > 0 GROUP BY PULocationID
            )
            SELECT a.PULocationID, a.pickup_count, a.avg_distance,
                   b.pickup_count AS dropoff_count
            FROM trip_stats a
            INNER JOIN trip_stats b ON a.PULocationID = b.DOLocationID
            WHERE a.pickup_count > 10
            ORDER BY a.pickup_count DESC
            LIMIT 100""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_join"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"

    def test_gpu_iceberg_time_travel(
        self,
        spark_session_with_gpu_and_iceberg,
        gpu_iceberg_table
    ):
        """Test time travel with GPU queries."""
        table_name = gpu_iceberg_table["table_name"]

        initial = spark_session_with_gpu_and_iceberg.sql(
            f"SELECT COUNT(*) AS cnt FROM {table_name}"
        ).collect()[0]["cnt"]

        spark_session_with_gpu_and_iceberg.sql(
            f"INSERT INTO {table_name} SELECT * FROM {table_name} LIMIT 10"
        )

        snapshots = spark_session_with_gpu_and_iceberg.sql(
            f"SELECT * FROM {table_name}.snapshots"
        )
        assert snapshots.count() >= 2

    def test_gpu_iceberg_sort(
        self,
        spark_session_with_gpu_and_iceberg,
        gpu_iceberg_table,
        query_metrics,
        gpu_metrics
    ):
        """Test GPU-accelerated sort on Iceberg table."""
        table_name = gpu_iceberg_table["table_name"]

        metrics = query_metrics(
            f"""SELECT passenger_count, fare_amount, total_amount
            FROM {table_name}
            WHERE total_amount > 0 AND fare_amount > 0
            ORDER BY fare_amount DESC
            LIMIT 1000""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_sort"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] <= 1000


@pytest.mark.e2e
@pytest.mark.gpu
@pytest.mark.iceberg
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestAirflowGpuIceberg411FullDataset:
    """E2E tests with full NYC Taxi dataset using GPU+Iceberg."""

    def test_gpu_iceberg_full_aggregation(
        self,
        spark_session_with_gpu_and_iceberg,
        iceberg_catalog,
        dataset_path,
        query_metrics,
        gpu_metrics
    ):
        """Test GPU-accelerated aggregation with full dataset."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.nyc_taxi_full_gpu"

        df = spark_session_with_gpu_and_iceberg.read.parquet(dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        metrics = query_metrics(
            f"""SELECT passenger_count, COUNT(*) AS trip_count,
               AVG(fare_amount) AS avg_fare, SUM(fare_amount) AS total_fare
               FROM {table_name}
               WHERE passenger_count > 0 AND total_amount > 0
               GROUP BY passenger_count
               ORDER BY passenger_count""",
            f"{test_component}_{test_mode}_{test_feature}_{test_spark_version}_full_agg"
        )

        assert metrics["success"], f"Query failed: {metrics.get('error')}"
        assert metrics["row_count"] > 0

        spark_session_with_gpu_and_iceberg.sql(f"DROP TABLE {table_name}")
