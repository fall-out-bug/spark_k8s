# Data Quality Tutorial

Learn to implement data quality checks in your Spark pipelines.

## Overview

This tutorial covers:
1. Defining data quality expectations
2. Validating data at scale
3. Handling quality failures
4. Monitoring quality metrics

## Prerequisites

- Great Expectations configured
- S3 or similar storage for checkpoints

## Tutorial: ETL with Data Quality Checks

### Step 1: Define Quality Expectations

```python
# quality/transaction_expectations.py
from great_expectations.core import ExpectationSuite, ExpectationConfiguration

def get_transaction_expectations():
    """Define quality expectations for transaction data."""
    suite = ExpectationSuite(expectation_suite_name="transaction_quality")

    # Schema expectations
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_to_exist",
            kwargs={"column": "transaction_id"}
        )
    )
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_to_exist",
            kwargs={"column": "amount"}
        )
    )

    # Value expectations
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_not_be_null",
            kwargs={"column": "transaction_id"}
        )
    )
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_be_between",
            kwargs={"column": "amount", "min_value": 0, "max_value": 1000000}
        )
    )
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_be_in_set",
            kwargs={"column": "currency", "value_set": ["USD", "EUR", "GBP"]}
        )
    )

    # Uniqueness
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_be_unique",
            kwargs={"column": "transaction_id"}
        )
    )

    # Row count
    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_table_row_count_to_be_between",
            kwargs={"min_value": 1, "max_value": 10000000}
        )
    )

    return suite
```

### Step 2: Create Validation Function

```python
# quality/validator.py
from pyspark.sql import DataFrame
import great_expectations as ge
from great_expectations DataContext
from great_expectations.checkpoint import SimpleCheckpoint

class DataQualityValidator:
    def __init__(self, context_path="s3a://great-expectations/"):
        """Initialize validator."""
        self.context = DataContext(context_root_dir=context_path)

    def validate_spark_df(self, df: DataFrame, expectation_suite):
        """Validate a Spark DataFrame."""
        # Convert to GE dataset
        ge_df = ge.dataset.SparkDFDataset(df)

        # Get the suite
        suite = self.context.get_expectation_suite(expectation_suite)
        if not suite:
            suite = get_transaction_expectations()
            self.context.add_expectation_suite(suite)

        # Validate
        validation_result = ge_df.validate(
            expectation_suite=suite,
            result_format="COMPLETE"
        )

        return validation_result

    def handle_validation_result(self, result, table_name):
        """Handle validation results."""
        if not result["success"]:
            # Log failed expectations
            for result in result["results"]:
                if not result["success"]:
                    print(f"❌ Failed: {result['expectation']['expectation_type']}")
                    print(f"   {result['expectation']['kwargs']}")

            # Write failure details
            failure_path = f"s3a://data-quality/failures/{table_name}/{int(time.time())}.json"
            # Save validation result for review

            return False
        else:
            print(f"✅ All validations passed for {table_name}")
            return True

# Create checkpoint for automated validation
def create_quality_checkpoint(context, suite_name):
    """Create a Great Expectations checkpoint."""
    return SimpleCheckpoint(
        name=f"{suite_name}_checkpoint",
        context=context,
        config={
            "class_name": "SimpleCheckpoint",
            "run_name_template": "%Y%m%d-%H%M%S-my-run-name-template",
        }
    )
```

### Step 3: Integrate into ETL Pipeline

```python
# etl_jobs/etl_with_quality.py
from pyspark.sql import SparkSession
from quality.validator import DataQualityValidator
import sys

def main():
    spark = SparkSession.builder \
        .appName("etl-with-quality") \
        .getOrCreate()

    validator = DataQualityValidator()

    try:
        # Read source data
        raw_df = spark.read.parquet("s3a://raw-data/transactions/")

        # Quality check on raw data
        print("Validating raw data...")
        raw_validation = validator.validate_spark_df(
            raw_df,
            "transaction_quality"
        )

        if not validator.handle_validation_result(raw_validation, "raw_transactions"):
            raise ValueError("Raw data quality check failed")

        # Transform data
        transformed_df = raw_df \
            .filter(col("status") == "completed") \
            .withColumn("amount_usd", convert_to_usd(col("amount"), col("currency"))) \
            .withColumn("processing_date", current_date())

        # Quality check on transformed data
        print("Validating transformed data...")
        transformed_suite = get_transformed_expectations()
        transformed_validation = validator.validate_spark_df(
            transformed_df,
            "transformed_transaction_quality"
        )

        if not validator.handle_validation_result(transformed_validation, "transformed_transactions"):
            raise ValueError("Transformed data quality check failed")

        # Write validated data
        output_path = "s3a://data-warehouse/transactions/"
        transformed_df.write \
            .mode("overwrite") \
            .partitionBy("processing_date") \
            .format("parquet") \
            .save(output_path)

        print(f"✅ ETL completed with quality checks passed")

    except Exception as e:
        print(f"❌ ETL failed: {str(e)}")
        sys.exit(1)
    finally:
        spark.stop()

def get_transformed_expectations():
    """Define expectations for transformed data."""
    suite = ExpectationSuite(expectation_suite_name="transformed_transaction_quality")

    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_to_exist",
            kwargs={"column": "amount_usd"}
        )
    )

    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_not_be_null",
            kwargs={"column": "amount_usd"}
        )
    )

    suite.add_expectation(
        ExpectationConfiguration(
            expectation_type="expect_column_values_to_be_between",
            kwargs={"column": "amount_usd", "min_value": 0}
        )
    )

    return suite

if __name__ == "__main__":
    main()
```

### Step 4: Automated Quality Gates

```yaml
# manifests/quality-gate-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: etl-with-quality-gates
  namespace: spark-prod
spec:
  type: Python
  mode: cluster
  image: your-registry/spark-with-quality:latest
  mainApplicationFile: local:///app/etl_jobs/etl_with_quality.py
  restartPolicy: OnFailure

  # Fail the job on quality check failure
  sparkConf:
    spark.python.worker.reuse: "true"

  driver:
    cores: 2
    memory: "4g"
    serviceAccount: spark
    env:
      - name: GE_DATA_CONTEXT_DIR
        value: "s3a://great-expectations/"

  executor:
    cores: 4
    instances: 10
    memory: "8g"

  deps:
    pyPackages:
      - great-expectations==0.17.0
      - boto3
```

### Step 5: Quality Metrics Dashboard

```python
# quality/metrics_collector.py
from pyspark.sql import SparkSession
from prometheus_client import Counter, Gauge, start_http_server

class QualityMetrics:
    def __init__(self):
        """Initialize quality metrics."""
        self.validations_total = Counter(
            'quality_validations_total',
            'Total quality validations',
            ['table', 'status']
        )
        self.expectations_total = Counter(
            'quality_expectations_total',
            'Total expectations checked',
            ['table', 'status']
        )
        self.data_quality_score = Gauge(
            'quality_score',
            'Data quality score',
            ['table']
        )

    def record_validation(self, table_name, validation_result):
        """Record validation metrics."""
        total = len(validation_result["results"])
        passed = sum(1 for r in validation_result["results"] if r["success"])
        failed = total - passed

        # Update counters
        if validation_result["success"]:
            self.validations_total.labels(table=table_name, status="passed").inc()
        else:
            self.validations_total.labels(table=table_name, status="failed").inc()

        self.expectations_total.labels(table=table_name, status="passed").inc(passed)
        self.expectations_total.labels(table=table_name, status="failed").inc(failed)

        # Calculate score
        score = (passed / total * 100) if total > 0 else 0
        self.data_quality_score.labels(table=table_name).set(score)

        return score

# Start metrics server
start_http_server(9091)
```

## Quality Dimensions

| Dimension | Checks | Impact |
|-----------|--------|--------|
| **Completeness** | Null checks, row count | Missing data |
| **Accuracy** | Range checks, format validation | Wrong values |
| **Consistency** | Referential integrity, cross-field | Data conflicts |
| **Timeliness** | Freshness, SLA checks | Stale data |
| **Uniqueness** | Duplicate detection | Duplicate records |
| **Validity** | Type checks, pattern matching | Invalid format |

## Handling Quality Failures

```python
def handle_quality_failure(validation_result, table_name):
    """Handle data quality failures."""
    # Quarantine failed data
    quarantine_path = f"s3a://quarantine/{table_name}/{int(time.time())}/"
    failed_df.write.parquet(quarantine_path)

    # Notify team
    send_slack_alert(
        f"❌ Data quality failure in {table_name}\n"
        f"Failed expectations: {sum(1 for r in validation_result['results'] if not r['success'])}\n"
        f"Quarantine location: {quarantine_path}"
    )

    # Create ticket
    create_quality_ticket(
        title=f"Data quality failure: {table_name}",
        description=validation_result.to_json(),
        priority="high"
    )
```

## Best Practices

1. **Validate early**: Check at ingestion, not just before storage
2. **Fail fast**: Stop processing on critical failures
3. **Quarantine bad data**: Don't delete, investigate
4. **Track metrics**: Monitor quality trends over time
5. **Document expectations**: Keep validation specs in version control

## Next Steps

- [ ] Set up automated quality reports
- [ ] Implement data quality alerts
- [ ] Create data quality dashboard
- [ ] Add data profiling tools

## Related

- [Data Quality Gates](../../docs/operations/procedures/cicd/data-quality-gates.md)
- [Great Expectations Docs](https://docs.greatexpectations.io/)
