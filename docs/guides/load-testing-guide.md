# Load Testing User Guide

Part of WS-013-11: CI/CD Integration & Documentation

## When to Run Load Tests

### Before Merging Code
- **P0 Smoke Tests**: Run automatically on PRs (64 combinations, ~30 min)
- Validates core functionality across versions
- Blocks merge if tests fail

### Daily Validation
- **P1 Core Tests**: Run nightly (384 combinations, ~4 hours)
- Catches regressions early
- Tests across modes and extensions

### Weekly Comprehensive Testing
- **P2 Full Matrix**: Run weekly (1280 combinations, ~48 hours)
- Complete test coverage
- Updates baselines for comparison

### Manual Testing
Run load tests manually when:
- Deploying to new environment
- Upgrading Spark version
- Changing infrastructure
- Optimizing configurations

## Running Load Tests Locally

### Quick Start

```bash
# 1. Setup environment (first time only)
./scripts/local-dev/setup-minikube-load-tests.sh

# 2. Run smoke tests
./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke --watch

# 3. View results
python scripts/tests/load/metrics/report_generator.py \
  --results-dir scripts/tests/output/results \
  --output-dir /tmp/reports
```

### Running Different Tiers

```bash
# P0 Smoke (64 combinations, 30 min)
./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke

# P1 Core (384 combinations, 4 hours)
./scripts/tests/load/orchestrator/submit-workflow.sh p1_core

# P2 Full (1280 combinations, 48 hours)
./scripts/tests/load/orchestrator/submit-workflow.sh p2_full
```

### Running Specific Combinations

```bash
# Generate custom matrix
python scripts/tests/load/matrix/generators/generate-matrix.py \
  --tier p0_smoke \
  --output-dir scripts/tests/output

# Edit generated scenario script
vim scripts/tests/output/scenarios/p0_350_connect_kubernetes_none_read_1gb.sh

# Run directly
./scripts/tests/output/scenarios/p0_350_connect_kubernetes_none_read_1gb.sh
```

## Interpreting Test Results

### Result Files

Results are stored in JSONL format:
```json
{
  "test_name": "p0_350_connect_kubernetes_none_read_1gb",
  "spark_version": "3.5.0",
  "operation": "read",
  "duration_sec": 45.2,
  "throughput": 46250,
  "tier1_stability": {
    "pod_restarts": 0,
    "failed_tasks": 0
  },
  "tier2_efficiency": {
    "cpu_usage_pct": 75.2,
    "memory_usage_pct": 82.1
  },
  "tier3_performance": {
    "duration_sec": 45.2,
    "throughput": 46250,
    "latency_p95_ms": 1250
  }
}
```

### Report Layers

#### Layer 1: Executive Summary
Quick overview for stakeholders:
- Total tests run
- Pass/fail count
- Regressions detected
- Average duration

#### Layer 2: Technical Report (HTML)
Detailed analysis for engineers:
- Per-test breakdown
- Performance metrics
- Resource utilization
- Comparison charts

#### Layer 3: Detailed Report (Markdown)
Complete documentation:
- Test-by-test results
- Stability metrics
- Efficiency metrics
- Performance metrics

#### Layer 4: Raw Data (JSONL)
Full data for custom analysis:
- All metrics
- Time series data
- For custom reporting

## Acting on Regressions

### Detecting Regressions

```bash
# Compare current results to baseline
python scripts/tests/load/metrics/regression_detector.py detect \
  --test-name p0_350_connect_kubernetes_none_read_1gb \
  --baseline '[45.0, 44.5, 46.0]' \
  --current '[52.0, 51.5, 53.0]'
```

### Regression Thresholds

- **Duration**: >20% increase is regression
- **Throughput**: >20% decrease is regression
- **Statistical significance**: p < 0.05

### Response Process

1. **Verify regression**:
   ```bash
   # Re-run test
   ./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke --watch
   ```

2. **Check for confounding factors**:
   - Cluster resource availability
   - Network issues
   - Data corruption

3. **Investigate changes**:
   - Recent code changes
   - Dependency updates
   - Configuration changes

4. **Create issue** if regression confirmed:
   ```bash
   gh issue create \
     --title "Performance regression in test X" \
     --body "Regression detected..."
   ```

5. **Fix regression**:
   - Rollback change
   - Optimize code
   - Update baseline (if improvement)

## Baseline Management

### Creating Baselines

```bash
# Create baseline from 5 runs
python scripts/tests/load/metrics/baseline_manager.py create \
  --test-name p0_350_connect_kubernetes_none_read_1gb \
  --results-dir /tmp/load-test-results \
  --sample-size 5
```

### Updating Baselines

```bash
# Update baseline with new data
python scripts/tests/load/metrics/baseline_manager.py update \
  --test-name p0_350_connect_kubernetes_none_read_1gb \
  --results-dir /tmp/load-test-results
```

### Comparing to Baseline

```bash
# Compare current run to baseline
python scripts/tests/load/metrics/baseline_manager.py compare \
  --test-name p0_350_connect_kubernetes_none_read_1gb \
  --metrics-file current-metrics.json
```

### Listing Baselines

```bash
# List all available baselines
python scripts/tests/load/metrics/baseline_manager.py list
```

## Customizing Test Matrix

### Modifying Priority Matrix

Edit `scripts/tests/load/matrix/priority-matrix.yaml`:

```yaml
matrix:
  priority_tiers:
    p0_smoke:
      spark_versions: ["3.5.0", "4.1.0"]
      orchestrators: ["connect"]
      modes: ["kubernetes"]
      extensions: ["none"]
      operations: ["read", "aggregate"]  # Add aggregate
      data_sizes: ["1gb"]
```

### Adding Custom Operations

1. Create workload script:
   ```bash
   vim scripts/tests/load/workloads/custom_op.py
   ```

2. Update matrix:
   ```yaml
   operations:
     - name: "custom"
       description: "Custom operation"
       script: "custom_op.py"
   ```

3. Regenerate artifacts:
   ```bash
   python scripts/tests/load/matrix/generators/generate-matrix.py \
     --tier p0_smoke
   ```

## Common Workflows

### Validate Before PR

```bash
# Run smoke tests locally
./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke --watch

# Check for regressions
python scripts/tests/load/metrics/regression_detector.py analyze \
  --results-dir scripts/tests/output/results
```

### Investigate Performance Issue

```bash
# Run specific test
./scripts/tests/output/scenarios/p0_350_connect_kubernetes_none_read_1gb.sh

# View detailed metrics
python scripts/tests/load/metrics/collector.py collect \
  --test-name p0_350_connect_kubernetes_none_read_1gb \
  --output-dir /tmp/metrics

# Generate report
python scripts/tests/load/metrics/report_generator.py \
  --results-dir /tmp/metrics \
  --output-dir /tmp/reports
```

### Compare Spark Versions

```bash
# Generate comparison matrix
python scripts/tests/load/matrix/generators/generate-matrix.py \
  --tier p0_smoke

# Run tests for each version
./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke

# Compare results in report
open /tmp/reports/technical-report.html
```

## Best Practices

### Resource Management
- Start with P0 smoke tests for quick feedback
- Use P1 core tests for nightly validation
- Reserve P2 full matrix for weekly runs
- Monitor cluster resources during execution

### Baseline Management
- Create baselines from at least 5 runs
- Update baselines after infrastructure changes
- Document reasons for baseline updates
- Keep baselines in version control

### Regression Response
- Always verify regressions with re-run
- Check cluster health before investigating
- Consider resource trade-offs
- Create issues for confirmed regressions

### CI/CD Integration
- Block PRs on P0 smoke test failures
- Automate nightly P1 core tests
- Schedule P2 full matrix during low-traffic periods
- Configure Slack/webhook notifications

## Additional Resources

- **Setup Guide**: `scripts/tests/load/SETUP.md`
- **Architecture**: `scripts/tests/load/ARCHITECTURE.md`
- **Troubleshooting**: `scripts/tests/load/TROUBLESHOOTING.md`
- **Matrix Reference**: `scripts/tests/load/matrix/priority-matrix.yaml`
