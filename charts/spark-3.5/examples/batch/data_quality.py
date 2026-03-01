"""
Data Quality Validation Example
===============================

Demonstrates data quality checks and validation patterns:
1. Schema validation
2. Null value checks
3. Data type validation
4. Business rule validation
5. Statistical checks
6. Anomaly detection

Run:
    spark-submit --master spark://master:7077 data_quality.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, when, isnull, isnan, min, max, avg, stddev, approx_count_distinct
from pyspark.sql.types import IntegerType, DoubleType, DateType, TimestampType
import os

S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://minio-spark-35:9000")
S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY", "minioadmin")
S3_SECRET_KEY = os.getenv("S3_SECRET_KEY", "minioadmin")


def create_spark_session():
    return (
        SparkSession.builder.appName("DataQuality")
        .master("spark://airflow-sc-standalone-master:7077")
        .config("spark.hadoop.fs.s3a.endpoint", S3_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", S3_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", S3_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )


class DataQualityChecker:
    def __init__(self, df, table_name="table"):
        self.df = df
        self.table_name = table_name
        self.results = []
        self.total_count = df.count()

    def check_nulls(self, columns, threshold=0.05):
        for col_name in columns:
            null_count = self.df.filter(col(col_name).isNull()).count()
            null_pct = null_count / self.total_count if self.total_count > 0 else 0
            passed = null_pct <= threshold

            self.results.append(
                {
                    "check": "null_check",
                    "column": col_name,
                    "value": null_count,
                    "pct": null_pct,
                    "threshold": threshold,
                    "passed": passed,
                }
            )
        return self

    def check_duplicates(self, columns):
        total = self.total_count
        distinct = self.df.select(*columns).distinct().count()
        dup_count = total - distinct
        passed = dup_count == 0

        self.results.append(
            {
                "check": "duplicate_check",
                "column": ", ".join(columns),
                "value": dup_count,
                "pct": dup_count / total if total > 0 else 0,
                "threshold": 0,
                "passed": passed,
            }
        )
        return self

    def check_range(self, column, min_val, max_val):
        out_of_range = self.df.filter((col(column) < min_val) | (col(column) > max_val)).count()
        passed = out_of_range == 0

        self.results.append(
            {
                "check": "range_check",
                "column": column,
                "value": out_of_range,
                "expected": f"[{min_val}, {max_val}]",
                "passed": passed,
            }
        )
        return self

    def check_distinct_values(self, column, min_expected=1, max_expected=None):
        distinct_count = self.df.select(column).distinct().count()
        passed = distinct_count >= min_expected
        if max_expected:
            passed = passed and distinct_count <= max_expected

        self.results.append(
            {
                "check": "distinct_count",
                "column": column,
                "value": distinct_count,
                "min_expected": min_expected,
                "max_expected": max_expected,
                "passed": passed,
            }
        )
        return self

    def check_pattern(self, column, pattern):
        invalid_count = self.df.filter(~col(column).rlike(pattern)).count()
        passed = invalid_count == 0

        self.results.append(
            {
                "check": "pattern_check",
                "column": column,
                "pattern": pattern,
                "invalid_count": invalid_count,
                "passed": passed,
            }
        )
        return self

    def check_freshness(self, column, max_age_hours=24):
        from pyspark.sql.functions import current_timestamp, hour

        max_time = self.df.agg(max(col(column))).collect()[0][0]
        if max_time:
            age_df = self.df.withColumn("age_hours", hour(current_timestamp() - col(column)))
            stale_count = age_df.filter(col("age_hours") > max_age_hours).count()
            passed = stale_count == 0
        else:
            stale_count = self.total_count
            passed = False

        self.results.append(
            {
                "check": "freshness_check",
                "column": column,
                "stale_count": stale_count,
                "max_age_hours": max_age_hours,
                "passed": passed,
            }
        )
        return self

    def get_report(self):
        passed = sum(1 for r in self.results if r["passed"])
        total = len(self.results)

        return {
            "table": self.table_name,
            "total_records": self.total_count,
            "checks_total": total,
            "checks_passed": passed,
            "checks_failed": total - passed,
            "pass_rate": passed / total if total > 0 else 0,
            "details": self.results,
        }

    def print_report(self):
        report = self.get_report()

        print("\n" + "=" * 70)
        print(f"DATA QUALITY REPORT: {report['table']}")
        print("=" * 70)
        print(f"Total records: {report['total_records']:,}")
        print(f"Checks: {report['checks_passed']}/{report['checks_total']} passed")
        print(f"Pass rate: {report['pass_rate']:.1%}")
        print("-" * 70)

        print(f"\n{'Check':<20} {'Column':<20} {'Status':<10} {'Details'}")
        print("-" * 70)

        for r in self.results:
            status = "✓ PASS" if r["passed"] else "✗ FAIL"
            details = ""
            if r["check"] == "null_check":
                details = f"{r['value']} nulls ({r['pct']:.1%})"
            elif r["check"] == "duplicate_check":
                details = f"{r['value']} duplicates"
            elif r["check"] == "range_check":
                details = f"{r['value']} out of range"
            elif r["check"] == "distinct_count":
                details = f"{r['value']} distinct values"
            elif r["check"] == "pattern_check":
                details = f"{r['invalid_count']} invalid"

            print(f"{r['check']:<20} {r['column']:<20} {status:<10} {details}")

        return report


def generate_test_data(spark, n=10000):
    from pyspark.sql.functions import rand, when, lit

    return spark.range(n).select(
        col("id").alias("customer_id"),
        (rand() * 100).cast("int").alias("age"),
        when(rand() > 0.95, None).otherwise(when(rand() > 0.5, "M").otherwise("F")).alias("gender"),
        (rand() * 100000).alias("income"),
        when(rand() > 0.1, "US").when(rand() > 0.05, "UK").when(rand() > 0.025, "DE").otherwise(None).alias("country"),
        (rand() * 1000).alias("purchase_amount"),
    )


def main():
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"Spark version: {spark.version}")

    df = generate_test_data(spark, n=10000)

    print(f"\nGenerated test data: {df.count()} records")
    df.printSchema()

    checker = DataQualityChecker(df, "customers")

    checker.check_nulls(["customer_id", "age", "income", "purchase_amount"], threshold=0.0)
    checker.check_nulls(["gender", "country"], threshold=0.1)

    checker.check_duplicates(["customer_id"])

    checker.check_range("age", min_val=0, max_val=120)
    checker.check_range("income", min_val=0, max_val=10000000)
    checker.check_range("purchase_amount", min_val=0, max_val=100000)

    checker.check_distinct_values("gender", min_expected=2, max_expected=3)
    checker.check_distinct_values("country", min_expected=1)

    checker.check_pattern("gender", "^[MF]$")

    report = checker.print_report()

    if report["checks_failed"] > 0:
        print(f"\n⚠️  {report['checks_failed']} quality checks failed!")
    else:
        print("\n✓ All quality checks passed!")

    spark.stop()


if __name__ == "__main__":
    main()
