"""
NYC Taxi dataset schema definition.

This module defines the schema for the NYC Taxi dataset used in E2E tests.
"""
from typing import Dict, List


NYC_TAXI_SCHEMA: Dict[str, str] = {
    "VendorID": "bigint",
    "tpep_pickup_datetime": "timestamp",
    "tpep_dropoff_datetime": "timestamp",
    "passenger_count": "bigint",
    "trip_distance": "double",
    "RatecodeID": "bigint",
    "store_and_fwd_flag": "string",
    "PULocationID": "bigint",
    "DOLocationID": "bigint",
    "payment_type": "bigint",
    "fare_amount": "double",
    "extra": "double",
    "mta_tax": "double",
    "tip_amount": "double",
    "tolls_amount": "double",
    "improvement_surcharge": "double",
    "total_amount": "double"
}

NYC_TAXI_COLUMN_NAMES: List[str] = list(NYC_TAXI_SCHEMA.keys())


def get_sql_type(pyspark_type: str) -> str:
    """Convert PySpark type string to SQL type string."""
    type_mapping = {
        "bigint": "BIGINT",
        "double": "DOUBLE",
        "string": "STRING",
        "timestamp": "TIMESTAMP"
    }
    return type_mapping.get(pyspark_type, "STRING")


def get_create_table_sql(table_name: str = "nyc_taxi") -> str:
    """Generate CREATE TABLE SQL statement for NYC Taxi schema."""
    columns = []
    for col_name, col_type in NYC_TAXI_SCHEMA.items():
        sql_type = get_sql_type(col_type)
        columns.append(f"    {col_name} {sql_type}")

    return f"""CREATE TABLE IF NOT EXISTS {table_name} (
{',\n'.join(columns)}
) USING PARQUET"""


def get_sample_row() -> Dict[str, any]:
    """Get a sample row for testing."""
    return {
        "VendorID": 1,
        "tpep_pickup_datetime": "2023-01-01 12:00:00",
        "tpep_dropoff_datetime": "2023-01-01 12:15:00",
        "passenger_count": 2,
        "trip_distance": 2.5,
        "RatecodeID": 1,
        "store_and_fwd_flag": "N",
        "PULocationID": 142,
        "DOLocationID": 236,
        "payment_type": 1,
        "fare_amount": 15.0,
        "extra": 0.5,
        "mta_tax": 0.5,
        "tip_amount": 3.0,
        "tolls_amount": 0.0,
        "improvement_surcharge": 0.3,
        "total_amount": 19.3
    }
