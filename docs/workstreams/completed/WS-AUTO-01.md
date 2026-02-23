# WS-AUTO-01: Metrics Collector for Autotuning

## Summary
Implement metrics collection from Prometheus for Spark autotuning analysis.

## Scope
- Prometheus queries for key Spark metrics
- History Server event log parsing
- Data aggregation and storage

## Acceptance Criteria
- [ ] Collector fetches metrics from Prometheus API
- [ ] Key metrics extracted: GC time, memory spill, task duration, shuffle bytes
- [ ] Event logs parsed from History Server (optional for MVP)
- [ ] Data stored in structured format (JSON/Parquet)
- [ ] Unit tests with mocked Prometheus responses
- [ ] CLI interface: `python -m autotuning.collector --app-id <id>`

## Technical Design

### Metrics to Collect

```yaml
prometheus_queries:
  gc_time:
    query: 'rate(jvm_gc_time_seconds_sum{job="spark-connect"}[5m])'
    aggregation: sum

  memory_spill:
    query: 'spark_executor_memory_bytes_spilled_total'
    aggregation: sum

  task_duration:
    query: 'histogram_quantile(0.99, rate(spark_task_duration_seconds_bucket[5m]))'
    aggregation: avg

  shuffle_read:
    query: 'spark_shuffle_read_bytes_total'
    aggregation: sum

  shuffle_write:
    query: 'spark_shuffle_write_bytes_total'
    aggregation: sum

  cpu_utilization:
    query: 'rate(process_cpu_seconds_total{job="spark-connect"}[5m])'
    aggregation: avg

  executor_memory:
    query: 'process_resident_memory_bytes{job="spark-connect"}'
    aggregation: avg
```

### File Structure
```
scripts/autotuning/
├── __init__.py
├── collector.py
├── config/
│   └── metrics.yaml
└── tests/
    └── test_collector.py
```

### Dependencies
- `prometheus-api-client` or `requests`
- `pyyaml`
- `pandas` (for data aggregation)

## Definition of Done
- Code reviewed and merged
- Tests passing (coverage >= 80%)
- Documentation in docstrings
- CLI works with `--help`

## Estimated Effort
Medium (rules-based, well-defined scope)

## Blocked By
None

## Blocks
- WS-AUTO-02 (Pattern Analyzer)
