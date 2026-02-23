# WS-AUTO-02: Pattern Analyzer for Autotuning

## Summary
Implement pattern detection to identify tuning opportunities from collected metrics.

## Scope
- GC pressure detection
- Memory spill detection
- Data skew detection
- CPU utilization analysis
- Query pattern classification

## Acceptance Criteria
- [ ] Analyzer processes metrics from collector
- [ ] Detects GC pressure (ratio > 10%)
- [ ] Detects memory spill (any bytes > 0)
- [ ] Detects data skew (p99/p50 ratio > 3.0)
- [ ] Detects low/high CPU utilization
- [ ] Classifies workload type (ETL, interactive, ML)
- [ ] Returns structured analysis with severity levels
- [ ] Unit tests with sample metrics data
- [ ] CLI interface: `python -m autotuning.analyzer --metrics-file <path>`

## Technical Design

### Detection Rules

```python
DETECTION_RULES = {
    "gc_pressure": {
        "metric": "gc_time_ratio",
        "condition": "> 0.10",
        "severity": {
            "warning": (0.10, 0.20),
            "critical": (0.20, float('inf'))
        },
        "recommendation": "increase_memory"
    },

    "memory_spill": {
        "metric": "bytes_spilled",
        "condition": "> 0",
        "severity": {
            "warning": (1, 1_000_000_000),  # 1GB
            "critical": (1_000_000_000, float('inf'))
        },
        "recommendation": "increase_memory_or_reduce_storage_fraction"
    },

    "data_skew": {
        "metric": "task_skew_ratio",  # p99/p50
        "condition": "> 3.0",
        "severity": {
            "warning": (3.0, 5.0),
            "critical": (5.0, float('inf'))
        },
        "recommendation": "enable_skew_join_or_salting"
    },

    "low_cpu_util": {
        "metric": "cpu_utilization",
        "condition": "< 0.60",
        "severity": {
            "warning": (0.40, 0.60),
            "critical": (0.0, 0.40)
        },
        "recommendation": "reduce_cores_or_increase_parallelism"
    },

    "high_cpu_util": {
        "metric": "cpu_utilization",
        "condition": "> 0.95",
        "severity": {
            "warning": (0.95, 0.99),
            "critical": (0.99, 1.0)
        },
        "recommendation": "add_executors_or_reduce_parallelism"
    }
}
```

### Workload Classification

```python
WORKLOAD_PATTERNS = {
    "etl_batch": {
        "indicators": ["high_shuffle_bytes", "multiple_stages", "stable_task_duration"],
        "typical_duration": "> 5 min"
    },
    "interactive": {
        "indicators": ["low_shuffle_bytes", "single_stage", "sub_second_latency"],
        "typical_duration": "< 30 sec"
    },
    "ml_training": {
        "indicators": ["high_memory_usage", "cache_hits", "iterative_stages"],
        "typical_duration": "> 10 min"
    },
    "streaming": {
        "indicators": ["continuous_processing", "micro_batch_pattern"],
        "typical_duration": "continuous"
    }
}
```

### File Structure
```
scripts/autotuning/
├── analyzer.py
├── config/
│   └── rules.yaml
└── tests/
    ├── test_analyzer.py
    └── fixtures/
        └── sample_metrics.json
```

### Output Format

```python
@dataclass
class AnalysisResult:
    app_id: str
    timestamp: datetime
    workload_type: str  # etl_batch, interactive, ml_training, streaming
    issues: List[DetectedIssue]
    metrics_summary: Dict[str, float]
    duration_seconds: float

@dataclass
class DetectedIssue:
    issue_type: str  # gc_pressure, memory_spill, data_skew, etc.
    severity: str    # warning, critical
    metric_value: float
    threshold: float
    recommendation: str
```

## Definition of Done
- Code reviewed and merged
- Tests passing (coverage >= 80%)
- All detection rules implemented
- Documentation in docstrings

## Estimated Effort
Medium (well-defined rules, moderate complexity)

## Blocked By
- WS-AUTO-01 (Metrics Collector)

## Blocks
- WS-AUTO-03 (Rule-based Recommender)
