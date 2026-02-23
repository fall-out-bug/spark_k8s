"""
Airflow Iceberg E2E tests for Spark 3.5.7.

Tests validate Apache Iceberg table operations via Airflow with Spark 3.5.7.
"""
import pytest
from datetime import datetime, timedelta

test_spark_version = "3.5.7"
test_component = "airflow"
test_mode = "connect-k8s"
test_feature = "iceberg"


@pytest.mark.e2e
@pytest.mark.iceberg
@pytest.mark.timeout(900)
class TestAirflowIceberg357:
    """E2E tests for Airflow with Iceberg on Spark 3.5.7."""

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

        # Create Iceberg table
        df = spark_session.read.parquet(sample_dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        # Verify table exists
        tables = spark_session.sql(f"SHOW TABLES IN {catalog_name}")
        assert tables.count() > 0, "No tables created"

        # Get metrics
        metrics = iceberg_metrics
        assert metrics["snapshot_count"] >= 1, "No snapshots created"

    def test_iceberg_read_table(
        self,
        spark_session,
        sample_dataset_path,
        iceberg_catalog
    ):
        """Test Iceberg table reading."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_read"

        # Create table
        df = spark_session.read.parquet(sample_dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        # Read from table
        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count > 0, "Table is empty"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_insert_append(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg append operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_append"

        # Create table with sample data
        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) " +
            f"USING iceberg LOCATION '{iceberg_catalog['warehouse']}/test_append'"
        )

        # Insert data
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"INSERT INTO {table_name} VALUES (3, 'c'), (4, 'd')")

        # Verify count
        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count == 4, f"Expected 4 rows, got {count}"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_update(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg UPDATE operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_update"

        # Create table
        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) " +
            f"USING iceberg"
        )

        # Insert initial data
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")

        # Update data
        spark_session.sql(f"UPDATE {table_name} SET value = 'updated' WHERE id = 1")

        # Verify update
        result = spark_session.sql(f"SELECT value FROM {table_name} WHERE id = 1")
        value = result.collect()[0]["value"]
        assert value == "updated", f"Update failed, got {value}"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_delete(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg DELETE operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_delete"

        # Create table
        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) " +
            f"USING iceberg"
        )

        # Insert data
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b'), (3, 'c')")

        # Delete data
        spark_session.sql(f"DELETE FROM {table_name} WHERE id = 2")

        # Verify delete
        result = spark_session.sql(f"SELECT COUNT(*) AS cnt FROM {table_name}")
        count = result.collect()[0]["cnt"]
        assert count == 2, f"Expected 2 rows after delete, got {count}"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")

    def test_iceberg_merge(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg MERGE (upsert) operation."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_merge"
        source_name = f"{catalog_name}.test_merge_source"

        # Create tables
        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) " +
            f"USING iceberg"
        )
        spark_session.sql(
            f"CREATE TABLE {source_name} (id INT, value STRING) " +
            f"USING iceberg"
        )

        # Insert initial data
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")
        spark_session.sql(f"INSERT INTO {source_name} VALUES (2, 'b_updated'), (3, 'c')")

        # Merge
        spark_session.sql(
            f"MERGE INTO {table_name} AS target " +
            f"USING {source_name} AS source " +
            f"ON target.id = source.id " +
            f"WHEN MATCHED THEN UPDATE SET target.value = source.value " +
            f"WHEN NOT MATCHED THEN INSERT *"
        )

        # Verify merge
        result = spark_session.sql(f"SELECT * FROM {table_name} ORDER BY id")
        rows = result.collect()
        assert len(rows) == 3, f"Expected 3 rows after merge, got {len(rows)}"

        # Cleanup
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

        # Get initial snapshot
        initial = spark_session.sql(f"SELECT * FROM {table_name} LIMIT 1")

        # Perform modification (creates new snapshot)
        spark_session.sql(f"INSERT INTO {table_name} SELECT * FROM {table_name} LIMIT 10")

        # Get current snapshot count
        snapshots = spark_session.sql(f"SELECT * FROM {table_name}.snapshots")
        snapshot_count = snapshots.count()

        assert snapshot_count >= 2, f"Expected at least 2 snapshots, got {snapshot_count}"

    def test_iceberg_schema_evolution(
        self,
        spark_session,
        iceberg_catalog
    ):
        """Test Iceberg schema evolution (ADD COLUMN)."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.test_schema"

        # Create table
        spark_session.sql(
            f"CREATE TABLE {table_name} (id INT, value STRING) " +
            f"USING iceberg"
        )

        # Insert data
        spark_session.sql(f"INSERT INTO {table_name} VALUES (1, 'a'), (2, 'b')")

        # Add column
        spark_session.sql(f"ALTER TABLE {table_name} ADD COLUMN new_col INT")

        # Insert with new column
        spark_session.sql(f"INSERT INTO {table_name} VALUES (3, 'c', 100)")

        # Verify schema evolution
        result = spark_session.sql(f"DESCRIBE {table_name}")
        cols = [row["col_name"] for row in result.collect()]
        assert "new_col" in cols, "New column not added"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")


@pytest.mark.e2e
@pytest.mark.iceberg
@pytest.mark.slow
@pytest.mark.timeout(1200)
class TestAirflowIceberg357FullDataset:
    """E2E tests with full NYC Taxi dataset using Iceberg."""

    def test_iceberg_full_table_operations(
        self,
        spark_session,
        dataset_path,
        iceberg_catalog,
        iceberg_metrics
    ):
        """Test Iceberg operations with full dataset."""
        catalog_name = iceberg_catalog["catalog_name"]
        table_name = f"{catalog_name}.nyc_taxi_full"

        # Create table from full dataset
        df = spark_session.read.parquet(dataset_path)
        df.writeTo(table_name).using("iceberg").create()

        # Perform aggregation
        result = spark_session.sql(
            f"SELECT passenger_count, COUNT(*) AS cnt " +
            f"FROM {table_name} " +
            f"WHERE passenger_count > 0 " +
            f"GROUP BY passenger_count"
        )

        assert result.count() > 0, "Aggregation failed"

        # Cleanup
        spark_session.sql(f"DROP TABLE {table_name}")
