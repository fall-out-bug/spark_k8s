# Lego-Spark Test Suite

This directory contains comprehensive tests for the Lego-Spark project.

## Directory Structure

```
tests/
├── smoke/              # Quick validation tests
│   └── run-smoke-tests.sh
├── e2e/               # End-to-end scenario tests
│   └── run-e2e-tests.sh
├── load/              # Performance and load tests
│   └── run-load-tests.sh
├── results/           # Test results and reports
│   └── test-report-*.md
└── run-all-tests.sh   # Main test runner
```

## Quick Start

Run all tests:
```bash
./tests/run-all-tests.sh
```

Run specific test suite:
```bash
# Smoke tests (5-10 minutes)
./tests/smoke/run-smoke-tests.sh

# E2E tests (15-30 minutes)
./tests/e2e/run-e2e-tests.sh

# Load tests (30-60 minutes)
./tests/load/run-load-tests.sh
```

## Test Suites

### 1. Smoke Tests (`tests/smoke/`)

Quick validation tests to verify basic functionality:
- Kubernetes connectivity
- Pod health (master, workers)
- Service endpoints
- Spark UI accessibility
- Basic spark-submit
- Monitoring resources (dashboards, alerts)

**Duration**: 5-10 minutes
**Requirements**: Minimal (1 worker sufficient)

### 2. E2E Tests (`tests/e2e/`)

Full scenario tests covering:
- Preset validation (helm lint)
- Preset template rendering
- Example script syntax
- Spark SQL operations
- DataFrame operations
- ML pipeline
- Streaming (file source)
- S3/MinIO storage
- Monitoring integration

**Duration**: 15-30 minutes
**Requirements**: 2+ workers recommended

### 3. Load Tests (`tests/load/`)

Performance and scalability tests:
- Throughput test (1M rows)
- Shuffle test (heavy joins)
- Sort test (large datasets)
- Cache test (repeated access)
- Write test (Parquet)
- ML training test

**Duration**: 30-60 minutes
**Requirements**: 3+ workers with 4+ CPU each

## Configuration

Set environment variables:
```bash
export K8S_NAMESPACE=spark-airflow
export HELM_RELEASE=airflow-sc
export TEST_TIMEOUT=300
```

## Results

Test results are saved to `tests/results/`:
- `all-tests-*.log` - Full test output
- `e2e-history.csv` - E2E test history
- `load-test-*.csv` - Load test metrics
- `test-report-*.md` - Human-readable reports
- `*.log` - Individual test logs

## Prerequisites

1. Kubernetes cluster with Spark deployed
2. `kubectl` configured with cluster access
3. `helm` installed
4. Python 3.6+ with PySpark (for local validation)
5. `bc` calculator (for load tests)

## CI/CD Integration

For CI/CD pipelines:
```bash
# Run smoke tests (fast feedback)
./tests/smoke/run-smoke-tests.sh
if [ $? -ne 0 ]; then
    echo "Smoke tests failed"
    exit 1
fi

# Run E2E tests (full validation)
./tests/e2e/run-e2e-tests.sh
if [ $? -ne 0 ]; then
    echo "E2E tests failed"
    exit 1
fi

# Optional: Run load tests (performance gate)
# ./tests/load/run-load-tests.sh
```

## Troubleshooting

### Test fails with "pod not found"
- Check namespace: `kubectl get pods -n spark-airflow`
- Verify labels: `kubectl get pods -n spark-airflow --show-labels`

### Test fails with "timeout"
- Increase timeout: `export TEST_TIMEOUT=600`
- Check cluster resources: `kubectl top nodes`
- Check pod resources: `kubectl describe pod <pod-name>`

### Load tests fail with "executor timeout"
- Add more workers
- Increase worker resources
- Check worker logs: `kubectl logs <worker-pod>`

### E2E tests skip monitoring tests
- Enable monitoring: `monitoring.grafanaDashboards.enabled=true`
- Enable alerts: `monitoring.alerts.enabled=true`

## Writing New Tests

1. Create test file in appropriate directory
2. Follow existing patterns for logging:
   ```bash
   log_pass "test-name"
   log_fail "test-name"
   log_skip "test-name"
   ```
3. Save results to `$RESULTS_DIR`
4. Add to main test runner if needed
