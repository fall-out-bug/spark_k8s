#!/usr/bin/env python3
"""Iceberg delete operations and main entry point."""

from pyspark.sql.functions import col


def delete_operations(spark):
    """Demonstrate Iceberg delete operations."""
    print("=== Delete Operations ===")

    # Delete by condition
    spark.sql("""
        DELETE FROM iceberg.db_examples.users
        WHERE id = 3
    """)

    # Update with condition
    spark.sql("""
        UPDATE iceberg.db_examples.users
        SET email = 'alice.new@example.com'
        WHERE id = 1
    """)

    # Show results
    spark.sql("SELECT * FROM iceberg.db_examples.users").show()


def run_all_examples():
    """Run all Iceberg examples."""
    from iceberg_setup import (
        create_spark_session, setup_database,
        create_iceberg_table, insert_initial_data
    )
    from iceberg_evolution import (
        time_travel_example, schema_evolution_add_column,
        schema_evolution_rename_column, partition_evolution,
        rollback_procedures
    )

    print("=" * 80)
    print("Apache Iceberg Examples")
    print("=" * 80)

    spark = create_spark_session()
    print(f"\nSpark Version: {spark.version}")

    # Setup
    setup_database(spark)
    create_iceberg_table(spark)
    insert_initial_data(spark)

    # Evolution
    time_travel_example(spark)
    schema_evolution_add_column(spark)
    schema_evolution_rename_column(spark)
    partition_evolution(spark)

    # Operations
    delete_operations(spark)
    rollback_procedures(spark)

    print("\n" + "=" * 80)
    print("All examples completed!")
    spark.stop()


if __name__ == "__main__":
    run_all_examples()
