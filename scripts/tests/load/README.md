# Load Tests

Sustained load tests for Spark on Kubernetes deployment.

## Overview

Load tests validate Spark performance under sustained workloads (30 minutes per test).
Each category contains 4 scenarios testing different Spark versions and configurations.

## Test Categories

### Baseline (`baseline/`)
Standard SELECT and JOIN queries at 1 qps.

- `test_baseline_select_358.py` - Spark 3.5.8, SELECT + aggregation
- `test_baseline_select_411.py` - Spark 4.1.1, SELECT + aggregation
- `test_baseline_join_358.py` - Spark 3.5.8, JOIN + filter
- `test_baseline_join_411.py` - Spark 4.1.1, JOIN + filter

### GPU (`gpu/`)
GPU-accelerated queries with RAPIDS at 0.5 qps.

- `test_gpu_aggregation_410.py` - Spark 4.1.0, heavy aggregation
- `test_gpu_aggregation_411.py` - Spark 4.1.1, heavy aggregation
- `test_gpu_window_410.py` - Spark 4.1.0, window functions
- `test_gpu_window_411.py` - Spark 4.1.1, window functions

### Iceberg (`iceberg/`)
Iceberg table operations at 5-10 ops/sec.

- `test_iceberg_insert_358.py` - Spark 3.5.8, INSERT at 10/s
- `test_iceberg_insert_411.py` - Spark 4.1.1, INSERT at 10/s
- `test_iceberg_merge_358.py` - Spark 3.5.8, MERGE at 5/s
- `test_iceberg_merge_411.py` - Spark 4.1.1, MERGE at 5/s

### Comparison (`comparison/`)
Version comparison tests (3.5.8 vs 4.1.1).

- `test_comparison_select.py` - SELECT + aggregation comparison
- `test_comparison_join.py` - JOIN + filter comparison
- `test_comparison_window.py` - Window function comparison
- `test_comparison_mixed.py` - Mixed workload comparison

### Security (`security/`)
Security policy stability under load at 1 qps.

- `test_security_pss_restricted.py` - PSS restricted mode
- `test_security_scc_anyuid.py` - SCC anyuid mode
- `test_security_openshift_restricted.py` - OpenShift restricted-v2
- `test_security_baseline_seccomp.py` - Custom baseline with seccomp

## Prerequisites

1. **Spark Connect deployment** running and accessible
2. **Test data** loaded (nyc_taxi table)
3. **Python dependencies** installed:
   ```bash
   pip install pytest pytest-timeout pyspark kubernetes
   ```

## Configuration

Set environment variables before running tests:

```bash
# Spark Connect URL
export SPARK_CONNECT_URL="sc://localhost:15002"

# Test namespace
export TEST_NAMESPACE="spark-load-test"

# Load test duration (default: 1800s = 30 min)
export LOAD_TEST_DURATION="1800"

# Load test interval (default: 1s)
export LOAD_TEST_INTERVAL="1.0"

# Metrics output directory
export METRICS_OUTPUT_DIR="./scripts/tests/load/results"
```

For version comparison tests:

```bash
# Enable both versions
export SPARK_358_ENABLED="true"
export SPARK_411_ENABLED="true"
export SPARK_358_CONNECT_URL="sc://spark-358:15002"
export SPARK_411_CONNECT_URL="sc://spark-411:15002"
```

## Running Tests

### Run all load tests
```bash
cd /home/fall_out_bug/work/s7/spark_k8s/scripts/tests/load
pytest -v
```

### Run specific category
```bash
pytest baseline/ -v
pytest gpu/ -v
pytest iceberg/ -v
pytest comparison/ -v
pytest security/ -v
```

### Run specific test
```bash
pytest baseline/test_baseline_select_358.py -v
```

### Run with marker
```bash
pytest -m baseline -v
pytest -m gpu -v
pytest -m iceberg -v
pytest -m comparison -v
pytest -m security -v
```

## Expected Duration

| Category | Tests | Duration per test | Total |
|----------|-------|-------------------|-------|
| Baseline | 4 | 40 min | 2.5 hours |
| GPU | 4 | 40 min | 2.5 hours |
| Iceberg | 4 | 40 min | 2.5 hours |
| Comparison | 4 | 80 min | 5 hours |
| Security | 4 | 40 min | 2.5 hours |

## Metrics

Each test outputs:
- **Throughput** (queries/second)
- **Latency percentiles** (p50, p95, p99)
- **Error rate**
- **Success/failure counts**
- **GPU metrics** (for GPU tests)
- **Policy violations** (for security tests)

## Acceptance Criteria

### Baseline
- Throughput >= 0.9 qps
- Error rate < 1%
- >= 1700 successful queries

### GPU
- Throughput >= 0.4 qps
- Error rate < 1%
- GPU utilization > 60%
- GPU memory < 80%
- >= 800 successful queries

### Iceberg (INSERT)
- Throughput >= 9.0 ops/sec
- Error rate < 1%
- < 1000 snapshots
- >= 16000 successful inserts

### Iceberg (MERGE)
- Throughput >= 4.5 ops/sec
- Error rate < 1%
- >= 8000 successful merges

### Comparison
- No regressions > 20%
- Both versions stable

### Security
- Throughput >= 0.9 qps
- Error rate < 1%
- Zero policy violations

## Results

Results are saved to `./results/` as JSONL files:
```
results/20240206_123045_metrics.jsonl
```

Each line contains a metrics object with timestamp.
