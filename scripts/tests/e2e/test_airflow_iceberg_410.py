"""
Airflow Iceberg E2E tests for Spark 4.1.0.

Tests validate Apache Iceberg table operations via Airflow with Spark 4.1.0.
"""
import pytest

test_spark_version = "4.1.0"
test_component = "airflow"
test_mode = "connect-k8s"
test_feature = "iceberg"


@pytest.mark.e2e
@pytest.mark.iceberg
@pytest.mark.timeout(900)
class TestAirflowIceberg410:
    """E2E tests for Airflow with Iceberg on Spark 4.1.0."""

    def test_iceberg_create_table(
        self,
        spark_session,
        sample_dataset_path,
        iceberg_catalog,
        iceberg_metrics
    ):
        """Test Iceberg table creation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.nyc_taxi"

        df = spark_session.read.parquet(sample_dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        tables = spark_session.sql(f"SHOW TABLES IN {catalog_name}")
        assert tables.count() > 0

        metrics = iceberg_metrics
        assert metrics["snapshot_count"] >= 1

    def test_iceberg_read_table(
        self,
        spark_session,
        sample_dataset_path,
        iceberg_catalog
    ):
        """Test Iceberg table reading."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_read"

        df = spark_session.read.parquet(sample_dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count > 0

        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_insert_append(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg append operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_append"

        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) USING iceberg"
        )

        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"INSERT INTO {table_name} VALUES (3, 'c'), (4, 'd')")

        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count == 4

        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_update(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg UPDATE operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_update"

        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) USING iceberg"
        )
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"UPDATE {table_name} SET value = 'updated' WHERE id = 1")

        result = spark_session.sql(f"SELECT value FROM {table_name} WHERE id = 1")
        value = result.collect()[0]["value"]
        assert value == "updated"

        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_delete(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg DELETE operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_delete"

        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) USING iceberg"
        )
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b'), (3, 'c')")
        spark_session.sql(f"DELETE FROM {table_name} WHERE id = 2")

        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count == 2

        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_merge(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg MERGE operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_merge"
        source_name = f"{catalog_name}.test_merge_source"

        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) USING iceberg"
        )
        spark_session.sql(
            f"CREATE TABLE {source_name} (id INT, value STRING) USING iceberg"
        )

        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"INSERT INTO {source_name} VALUES (2, 'b_updated'), (3, 'c')")

        spark_session.sql(
            f"MERGE INTO {table_name} AS target "
            f"USING {source_name} AS source "
            f"ON target.id = source.id "
            f"WHEN MATCHED THEN UPDATE SET target.value = source.value "
            f"WHEN NOT MATCHED THEN INSERT *"
        )

        result = spark_session.sql(f"SELECT * FROM {table_name} ORDER BY id")
        rows = result.collect()
        assert len(rows) == 3

        spark_session.sql(f"DROP TABLE {table_name}")
        spark_session.sql(f"DROP TABLE {source_name}")

    def test_iceberg_time_travel(
        self,
        spark_session,
        iceberg_catalog,
        iceberg_table
    ):
        """Test Iceberg time travel queries."""
        table_name = iceberg_table["table_name"]

        spark_session.sql(f"INSERT INTO {table_name} SELECT * FROM {table_name} LIMIT 10")

        snapshots = spark_session.sql(f"SELECT * FROM {table_name}.snapshots")
        snapshot_count = snapshots.count()

        assert snapshot_count >= 2

    def test_iceberg_schema_evolution(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg schema evolution."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_schema"

        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) USING iceberg"
        )
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"ALTER TABLE {table_name} ADD COLUMN new_col INT")
        spark_session.sql(f"INSERT INTO {table_name} VALUES (3, 'c', 100)")

        result = spark_session.sql(f"DESCRIBE {table_name}")
        cols = [row["col_name"] for row in result.collect()]
        assert "new_col" in cols

        spark_session.sql(f"DROP TABLE {table_name}")
