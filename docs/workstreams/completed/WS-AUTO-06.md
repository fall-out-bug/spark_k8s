# WS-AUTO-06: Integration Tests on NYC Taxi Pipeline

## Summary
End-to-end integration tests for autotuning MVP on real NYC Taxi ML pipeline.

## Scope
- Full pipeline test: collect → analyze → recommend → apply
- Regression detection
- Performance validation
- CLI integration tests

## Acceptance Criteria
- [ ] E2E test runs on NYC Taxi pipeline (14.2M records)
- [ ] Collector fetches real metrics from Prometheus
- [ ] Analyzer detects known issues (inject if needed)
- [ ] Recommender generates valid suggestions
- [ ] Applier creates valid Helm values
- [ ] Performance comparison: before vs after tuning
- [ ] All CLI commands tested
- [ ] Test coverage >= 80%

## Technical Design

### Test Scenarios

```python
TEST_SCENARIOS = [
    {
        "name": "gc_pressure_high",
        "setup": {
            "spark.executor.memory": "2g",  # Too low
            "spark.executor.cores": "4"
        },
        "expected_detections": ["gc_pressure", "memory_spill"],
        "expected_recommendations": ["increase_memory"],
        "validation": {
            "memory_increase_pct": (20, 100),
            "confidence": (0.7, 1.0)
        }
    },
    {
        "name": "low_cpu_utilization",
        "setup": {
            "spark.executor.memory": "16g",
            "spark.executor.cores": "8",  # Too many cores
            "spark.sql.shuffle.partitions": "50"
        },
        "expected_detections": ["low_cpu_util"],
        "expected_recommendations": ["reduce_cores"],
        "validation": {
            "cores_decrease": (1, 4),
            "confidence": (0.6, 0.9)
        }
    },
    {
        "name": "data_skew_detected",
        "setup": {
            "spark.executor.memory": "8g",
            "spark.executor.cores": "4",
            # Inject skewed data partition
        },
        "expected_detections": ["data_skew"],
        "expected_recommendations": ["enable_skew_join"],
        "validation": {
            "skew_join_enabled": True,
            "confidence": (0.7, 0.95)
        }
    },
    {
        "name": "optimal_config",
        "setup": {
            "spark.executor.memory": "20g",
            "spark.executor.cores": "4",
            "spark.sql.shuffle.partitions": "200",
            "spark.sql.adaptive.enabled": "true"
        },
        "expected_detections": [],
        "expected_recommendations": [],
        "validation": {
            "no_changes": True
        }
    }
]
```

### E2E Test Flow

```python
def test_autotuning_e2e_nyc_taxi():
    """End-to-end autotuning test on NYC Taxi pipeline."""

    # 1. Run baseline pipeline
    baseline_result = run_spark_job(
        job="dags/spark_jobs/taxi_feature_engineering.py",
        config=BASELINE_CONFIG
    )
    baseline_metrics = collect_metrics(baseline_result.app_id)

    # 2. Collect metrics
    collector = MetricsCollector(prometheus_url=PROMETHEUS_URL)
    metrics = collector.collect(app_id=baseline_result.app_id)

    # 3. Analyze
    analyzer = WorkloadAnalyzer()
    analysis = analyzer.analyze(metrics)
    assert analysis.workload_type == "etl_batch"

    # 4. Generate recommendations
    recommender = ConfigRecommender()
    recommendations = recommender.recommend(analysis)

    # 5. Apply recommendations
    applier = HelmValuesGenerator()
    tuned_config = applier.generate(recommendations, format="overlay")

    # 6. Run tuned pipeline
    tuned_result = run_spark_job(
        job="dags/spark_jobs/taxi_feature_engineering.py",
        config=tuned_config
    )
    tuned_metrics = collect_metrics(tuned_result.app_id)

    # 7. Validate improvement
    assert tuned_metrics.duration <= baseline_metrics.duration * 1.1  # Max 10% regression
    assert tuned_metrics.gc_ratio < baseline_metrics.gc_ratio or baseline_metrics.gc_ratio < 0.05

    # 8. Check safety bounds
    assert tuned_config.memory <= MAX_MEMORY
    assert tuned_config.cores <= MAX_CORES
```

### CLI Integration Tests

```python
class TestAutotuningCLI:
    """Test CLI commands."""

    def test_collector_cli(self):
        result = runner.invoke(
            cli,
            ["collect", "--app-id", "app-123", "--output", "/tmp/metrics.json"]
        )
        assert result.exit_code == 0
        assert Path("/tmp/metrics.json").exists()

    def test_analyzer_cli(self):
        result = runner.invoke(
            cli,
            ["analyze", "--metrics-file", "/tmp/metrics.json", "--output", "/tmp/analysis.json"]
        )
        assert result.exit_code == 0
        analysis = json.loads(Path("/tmp/analysis.json").read_text())
        assert "workload_type" in analysis
        assert "issues" in analysis

    def test_recommender_cli(self):
        result = runner.invoke(
            cli,
            ["recommend", "--analysis-file", "/tmp/analysis.json", "--output", "/tmp/recs.json"]
        )
        assert result.exit_code == 0
        recs = json.loads(Path("/tmp/recs.json").read_text())
        assert "recommendations" in recs
        assert "confidence" in recs

    def test_apply_cli(self):
        result = runner.invoke(
            cli,
            ["apply", "--recommendations-file", "/tmp/recs.json", "--output-dir", "/tmp/helm/"]
        )
        assert result.exit_code == 0
        assert Path("/tmp/helm/autotuned-values.yaml").exists()

    def test_full_pipeline_cli(self):
        result = runner.invoke(
            cli,
            ["full-pipeline", "--app-id", "app-123", "--output-dir", "/tmp/autotuning/"]
        )
        assert result.exit_code == 0
        assert Path("/tmp/autotuning/metrics.json").exists()
        assert Path("/tmp/autotuning/analysis.json").exists()
        assert Path("/tmp/autotuning/recommendations.json").exists()
        assert Path("/tmp/autotuning/values.yaml").exists()
```

### Performance Benchmarks

```python
PERFORMANCE_BENCHMARKS = {
    "collector_duration": 5.0,      # seconds, max
    "analyzer_duration": 1.0,       # seconds, max
    "recommender_duration": 0.5,    # seconds, max
    "applier_duration": 0.5,        # seconds, max
    "full_pipeline_duration": 10.0, # seconds, max
    "memory_usage": 512,            # MB, max
}
```

### File Structure
```
scripts/autotuning/
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_collector.py
│   ├── test_analyzer.py
│   ├── test_recommender.py
│   ├── test_applier.py
│   ├── test_cli.py
│   ├── test_e2e.py
│   └── fixtures/
│       ├── sample_metrics.json
│       ├── sample_analysis.json
│       └── sample_recommendations.json

tests/integration/
└── test_autotuning_nyc_taxi.py
```

### Test Data

```yaml
# tests/fixtures/autotuning_test_data.yaml
test_apps:
  - app_id: "app-20260222000000-0001"
    workload: "nyc_taxi_etl"
    records: 14200000
    duration_seconds: 45
    expected_workload_type: "etl_batch"
    expected_issues:
      - type: "low_cpu_util"
        severity: "warning"

  - app_id: "app-20260222000000-0002"
    workload: "nyc_taxi_ml"
    records: 14200000
    duration_seconds: 120
    expected_workload_type: "ml_training"
    expected_issues:
      - type: "gc_pressure"
        severity: "warning"
```

## Definition of Done
- Code reviewed and merged
- All tests passing
- E2E test runs on real pipeline
- Performance within benchmarks
- Coverage >= 80%

## Estimated Effort
Medium (comprehensive testing)

## Blocked By
- WS-AUTO-05 (Grafana Dashboard)

## Blocks
None (final workstream)
