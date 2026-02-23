# Test Datasets

This directory contains utility scripts for generating test datasets used in smoke tests.

## Generate Dataset

```bash
# Small dataset (1000 rows, ~100KB)
bash scripts/tests/data/generate-dataset.sh small

# Medium dataset (10000 rows, ~1MB)
bash scripts/tests/data/generate-dataset.sh medium

# Large dataset (100000 rows, ~10MB)
bash scripts/tests/data/generate-dataset.sh large
```

## Requirements

The dataset generator requires Python 3 with the following packages:

- pandas
- numpy
- pyarrow (for Parquet format)

### Install dependencies

```bash
pip install pandas numpy pyarrow
```

Or use the PySpark environment (includes pyarrow):

```bash
pip install pyspark
```

## Dataset Details

**NYC Taxi Sample Dataset** (synthetic data):

- Format: Apache Parquet
- Columns: 19 (VendorID, pickup/dropoff times, passenger_count, trip_distance, etc.)
- Sizes:
  - small: 1,000 rows (~100KB)
  - medium: 10,000 rows (~1MB)
  - large: 100,000 rows (~10MB)

## Usage in Smoke Tests

```bash
export DATASET_PATH="$(pwd)/scripts/tests/data/nyc-taxi-sample.parquet"
```

Then use in Spark jobs:

```python
df = spark.read.parquet(os.environ.get('DATASET_PATH'))
df.show()
```

## .gitignore

Generated datasets are excluded from git to keep repository size small.
