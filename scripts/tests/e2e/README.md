# E2E Tests for Spark on Kubernetes

End-to-end tests for validating Spark functionality on Kubernetes with production-scale data.

## Test Structure

```
scripts/tests/e2e/
├── conftest.py                  # Pytest fixtures and configuration
├── pytest.ini                   # Pytest configuration
├── queries/                     # SQL query modules
│   ├── q1_count.sql
│   ├── q2_aggregation.sql
│   ├── q3_join.sql
│   └── q4_window.sql
├── data/
│   └── nyc-taxi/               # NYC Taxi dataset fixtures
│       ├── schema.py
│       └── fixtures.py
└── test_*.py                   # Test modules
    ├── test_jupyter_k8s_357.py
    ├── test_jupyter_k8s_358.py
    ├── test_jupyter_connect_k8s_357.py
    ├── test_jupyter_connect_k8s_358.py
    ├── test_airflow_k8s_357.py
    ├── test_airflow_k8s_358.py
    ├── test_airflow_connect_k8s_357.py
    └── test_airflow_connect_k8s_358.py
```

## Test Matrix

| Component | Mode | Spark Version | Scenarios |
|-----------|------|---------------|-----------|
| Jupyter | k8s-submit | 3.5.7 | 4 (Q1-Q4) |
| Jupyter | k8s-submit | 3.5.8 | 4 (Q1-Q4) |
| Jupyter | connect-k8s | 3.5.7 | 4 (Q1-Q4) |
| Jupyter | connect-k8s | 3.5.8 | 4 (Q1-Q4) |
| Airflow | k8s-submit | 3.5.7 | 4 (Q1-Q4) |
| Airflow | k8s-submit | 3.5.8 | 4 (Q1-Q4) |
| Airflow | connect-k8s | 3.5.7 | 4 (Q1-Q4) |
| Airflow | connect-k8s | 3.5.8 | 4 (Q1-Q4) |

**Total:** 32 scenarios (8 modules × 4 queries)

## Queries

- **Q1 (COUNT)**: Basic row count query - validates basic functionality
- **Q2 (GROUP BY)**: Aggregation query - validates aggregation performance
- **Q3 (JOIN)**: Self-join with filter - validates join performance
- **Q4 (Window)**: Window functions - validates complex query performance

## Dataset

The tests use NYC Taxi dataset in Parquet format:

- **Sample dataset**: 10,000 rows (~1MB) - for fast testing
- **Full dataset**: ~100 million rows (~11GB) - for production validation

### Dataset Setup

```bash
# Generate sample dataset
bash scripts/tests/data/generate-dataset.sh large

# Set environment variable for custom dataset location
export NYC_TAXI_SAMPLE_PATH=/path/to/nyc-taxi-sample.parquet
export NYC_TAXI_FULL_PATH=/path/to/nyc-taxi-full.parquet
```

## Running Tests

### Prerequisites

- Python 3.10+
- PySpark installed (`pip install pyspark`)
- pytest with plugins (`pip install pytest pytest-timeout pytest-cov`)
- NYC Taxi dataset available

### Run All E2E Tests

```bash
# Run all E2E tests (uses sample dataset)
cd /home/fall_out_bug/work/s7/spark_k8s
pytest scripts/tests/e2e/ -v --timeout=1200

# Run with coverage
pytest scripts/tests/e2e/ -v --timeout=1200 --cov=scripts.tests.e2e --cov-report=html
```

### Run Specific Test Suite

```bash
# Run only Jupyter tests
pytest scripts/tests/e2e/test_jupyter_*.py -v

# Run only Airflow tests
pytest scripts/tests/e2e/test_airflow_*.py -v

# Run only Spark 3.5.7 tests
pytest scripts/tests/e2e/test_*_357.py -v

# Run only Spark Connect tests
pytest scripts/tests/e2e/test_*connect*.py -v
```

### Run Specific Query Test

```bash
# Run only Q1 tests
pytest scripts/tests/e2e/ -v -k "q1_count"

# Run only window function tests
pytest scripts/tests/e2e/ -v -k "q4_window"
```

### Run Full Dataset Tests (Slow)

```bash
# Run tests with full 11GB dataset (requires NYC_TAXI_FULL_PATH set)
pytest scripts/tests/e2e/ -v --timeout=1200 -m slow
```

## Test Markers

- `e2e`: Marks test as E2E test (all tests)
- `slow`: Marks test as using full dataset (11GB)
- `gpu`: Marks test as requiring GPU (future)
- `iceberg`: Marks test as requiring Iceberg (future)

## Metrics Collection

Tests automatically collect and store metrics:

- `execution_time`: Query execution time in seconds
- `memory_used_bytes`: Memory used during query execution
- `row_count`: Number of rows returned
- `throughput_rows_per_sec`: Query throughput (when applicable)
- `success`: Whether query succeeded

Metrics are stored in `/tmp/e2e_results/` as JSON files.

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: E2E Tests
on: [push, pull_request]
jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: pip install pyspark pytest pytest-timeout pytest-cov
      - name: Generate sample dataset
        run: bash scripts/tests/data/generate-dataset.sh large
      - name: Run E2E tests
        run: pytest scripts/tests/e2e/ -v --timeout=1200
```

## Troubleshooting

### Tests Skip with "Dataset not found"

- Generate sample dataset: `bash scripts/tests/data/generate-dataset.sh large`
- Or set `NYC_TAXI_SAMPLE_PATH` environment variable

### Tests Timeout

- Increase timeout: `pytest --timeout=1800`
- Use sample dataset instead of full dataset

### PySpark Import Error

- Install PySpark: `pip install pyspark`
- Ensure JAVA_HOME is set correctly

## Future Enhancements

- GPU E2E tests (WS-00-012-02)
- Iceberg E2E tests (WS-00-012-03)
- GPU+Iceberg E2E tests (WS-00-012-04)
- Standalone E2E tests (WS-00-012-05)
- Library compatibility tests (WS-00-012-06)
