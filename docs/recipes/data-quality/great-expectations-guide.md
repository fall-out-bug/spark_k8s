# Great Expectations Quick Start for Spark K8s

This guide demonstrates Great Expectations integration with Spark on Kubernetes for data quality validation.

## Quick Start

### 1. Validate a DataFrame

```python
from pyspark.sql import SparkSession
import great_expectations as gx
from great_expectations.datasource import SparkDFDatasource

spark = SparkSession.builder.appName("GE Demo").getOrCreate()

# Create sample dataframe
df = spark.createDataFrame([
    (1, "Alice", 100.0),
    (2, "Bob", 200.0),
    (3, "Charlie", None),
], ["id", "name", "amount"])

# Create GE context
context = gx.get_context()

# Add Spark datasource
datasource = context.data_sources.add_spark("my_spark_datasource")

# Add data asset
data_asset = datasource.add_dataframe_asset(name="my_asset")

# Create expectation suite
suite = context.suites.add_expectation_suite("my_suite")

# Create validator
validator = context.get_validator(
    batch=SparkDFDatasource(df, data_asset),
    expectation_suite=suite
)

# Add expectations
validator.expect_column_values_to_not_be_null("id")
validator.expect_column_values_to_not_be_null("name")
validator.expect_column_values_to_be_between("amount", min_value=0, max_value=1000)

# Validate
results = validator.validate()

print(f"Success: {results.success}")
```

### 2. Airflow Integration

```python
from airflow import DAG
from great_expectations_provider.operators.great_expectations import GreatExpectationsOperator
from datetime import datetime

with DAG("ge_validation", start_date=datetime(2024, 1, 1)) as dag:

    validate_sales = GreatExpectationsOperator(
        task_id="validate_sales_data",
        expectation_suite_name="sales_expectations",
        batch_kwargs={"datapoint_name": "sales_data"},
        ge_root_dir="/usr/local/airflow/dags/great_expectations"
    )
```

### 3. Validation Modes

Configure validation mode via environment:

```yaml
# values.yaml
validation:
  mode: "production_only"  # always | skip | production_only | scheduled
```

Modes:
- `always`: Run on every execution
- `skip`: Skip validation
- `production_only`: Only in production
- `scheduled`: Only on scheduled runs (not manual)

## Expectation Suite Templates

### Sales Data Expectations

```python
# expectations/sales_expectations.json
{
  "expectation_suite_name": "sales",
  "expectations": [
    {
      "expectation_type": "expect_column_to_exist",
      "kwargs": {"column": "order_id"}
    },
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": {"column": "order_id"}
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "amount",
        "min_value": 0,
        "max_value": 1000000
      }
    }
  ]
}
```

### Customer Data Expectations

```python
{
  "expectation_suite_name": "customers",
  "expectations": [
    {
      "expectation_type": "expect_column_values_to_match_regex",
      "kwargs": {
        "column": "email",
        "regex": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
      }
    }
  ]
}
```

## Configuration

### Great Expectations Config

```yaml
# great_expectations.yml
config_version: 3.0
datasources: {}
stores:
  expectations_store:
    class_name: ExpectationsStore
    store_backend:
      class_name: TupleFilesystemStoreBackend
      base_directory: expectations/

  validations_store:
    class_name: ValidationsStore
    store_backend:
      class_name: TupleFilesystemStoreBackend
      base_directory: uncommitted/validations/

  evaluation_parameter_store:
    class_name: EvaluationParameterStore
```

## Best Practices

1. **Start simple**: Begin with null checks and type validation
2. **Version control**: Store expectation suites in git
3. **Fail fast**: Block pipeline on critical data quality issues
4. **Document**: Add descriptions to expectations
5. **Review**: Regularly review and update suites

## Further Reading

- [Great Expectations Docs](https://docs.greatexpectations.io/)
- [Spark Integration](https://docs.greatexpectations.io/docs/guides/integrations/spark/)
