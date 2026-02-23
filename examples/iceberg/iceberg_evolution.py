#!/usr/bin/env python3
"""Iceberg schema evolution and time travel examples."""


def time_travel_example(spark):
    """Demonstrate Iceberg time travel feature."""
    print("=== Time Travel Example ===")

    # Get current snapshot
    snapshots = spark.sql("""
        SELECT snapshot_id, committed_at
        FROM iceberg.db_examples.users.snapshots
        ORDER BY committed_at DESC
    """).collect()

    if len(snapshots) > 1:
        prev_snapshot = snapshots[1]["snapshot_id"]
        # Query previous snapshot
        spark.sql(f"""
            SELECT * FROM iceberg.db_examples.users
            VERSION AS OF {prev_snapshot}
        """).show()


def schema_evolution_add_column(spark):
    """Add a new column without rewriting data."""
    spark.sql("""
        ALTER TABLE iceberg.db_examples.users
        ADD COLUMNS (phone STRING)
    """)


def schema_evolution_rename_column(spark):
    """Rename a column."""
    spark.sql("""
        ALTER TABLE iceberg.db_examples.users
        RENAME COLUMN phone TO phone_number
    """)


def partition_evolution(spark):
    """Evolve partition spec."""
    spark.sql("""
        ALTER TABLE iceberg.db_examples.users
        DROP PARTITION FIELD days(created_at)
    """)


def rollback_procedures(spark):
    """Rollback to a previous snapshot."""
    snapshots = spark.sql("""
        SELECT snapshot_id, committed_at
        FROM iceberg.db_examples.users.snapshots
        ORDER BY committed_at DESC
        LIMIT 5
    """).collect()

    if snapshots:
        prev_snapshot = snapshots[-1]["snapshot_id"]
        spark.sql(f"""
            CALL iceberg.system.rollback_to_snapshot(
                'iceberg.db_examples.users', {prev_snapshot}
            )
        """)
