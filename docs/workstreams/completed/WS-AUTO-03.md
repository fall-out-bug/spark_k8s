# WS-AUTO-03: Rule-based Recommender

## Summary
Generate Spark configuration recommendations based on analysis results.

## Scope
- Rule engine for config recommendations
- Workload-specific tuning profiles
- Safety bounds enforcement
- Confidence scoring

## Acceptance Criteria
- [ ] Recommender takes AnalysisResult as input
- [ ] Generates specific Spark config changes
- [ ] Applies workload-specific profiles (ETL, interactive, ML)
- [ ] Enforces safety bounds (max/min values)
- [ ] Calculates confidence score for each recommendation
- [ ] Provides rationale for each change
- [ ] Unit tests with various analysis scenarios
- [ ] CLI interface: `python -m autotuning.recommender --analysis-file <path>`

## Technical Design

### Recommendation Rules

```python
RECOMMENDATION_RULES = {
    "increase_memory": {
        "condition": "gc_pressure or memory_spill",
        "action": {
            "spark.executor.memory": "current * 1.2",
            "spark.executor.memoryOverhead": "current * 1.2"
        },
        "max_increase_pct": 100,
        "confidence_factor": 0.9
    },

    "reduce_cores": {
        "condition": "low_cpu_util and not data_skew",
        "action": {
            "spark.executor.cores": "max(current - 1, 1)"
        },
        "min_value": 1,
        "confidence_factor": 0.7
    },

    "increase_shuffle_partitions": {
        "condition": "high_shuffle_bytes and large_partition_size",
        "action": {
            "spark.sql.shuffle.partitions": "min(current * 2, 1000)"
        },
        "max_value": 1000,
        "confidence_factor": 0.8
    },

    "enable_skew_join": {
        "condition": "data_skew",
        "action": {
            "spark.sql.adaptive.skewJoin.enabled": "true",
            "spark.sql.adaptive.skewJoin.skewedPartitionFactor": "5"
        },
        "confidence_factor": 0.85
    },

    "adjust_broadcast_threshold": {
        "condition": "small_table_join_detected",
        "action": {
            "spark.sql.autoBroadcastJoinThreshold": "104857600"  # 100MB
        },
        "confidence_factor": 0.75
    }
}
```

### Workload Profiles

```yaml
profiles:
  etl_batch:
    base_config:
      spark.sql.adaptive.enabled: "true"
      spark.sql.adaptive.coalescePartitions.enabled: "true"
      spark.memory.fraction: "0.7"
      spark.memory.storageFraction: "0.3"
    priority_params:
      - spark.executor.memory
      - spark.sql.shuffle.partitions
      - spark.sql.adaptive.advisoryPartitionSizeInBytes

  interactive:
    base_config:
      spark.sql.adaptive.enabled: "true"
      spark.sql.adaptive.localShuffleReader.enabled: "true"
      spark.sql.adaptive.coalescePartitions.initialPartitionNum: "50"
    priority_params:
      - spark.executor.cores
      - spark.sql.autoBroadcastJoinThreshold

  ml_training:
    base_config:
      spark.sql.adaptive.enabled: "true"
      spark.sql.execution.arrow.pyspark.enabled: "true"
      spark.memory.storageFraction: "0.6"
    priority_params:
      - spark.executor.memory
      - spark.driver.maxResultSize

  streaming:
    base_config:
      spark.sql.streaming.stateStore.providerClass: "org.apache.spark.sql.execution.streaming.RocksDBStateStoreProvider"
      spark.streaming.backpressure.enabled: "true"
    priority_params:
      - spark.executor.memory
      - spark.sql.shuffle.partitions
```

### Safety Bounds

```yaml
safety_bounds:
  spark.executor.memory:
    min: "1Gi"
    max: "32Gi"
    max_increase_pct: 100

  spark.executor.cores:
    min: 1
    max: 8
    max_increase_pct: 50

  spark.executor.instances:
    min: 1
    max: 100
    max_increase_pct: 100

  spark.sql.shuffle.partitions:
    min: 10
    max: 2000
    max_increase_pct: 200

  spark.sql.autoBroadcastJoinThreshold:
    min: "10MB"
    max: "500MB"
```

### Output Format

```python
@dataclass
class Recommendation:
    parameter: str
    current_value: str
    recommended_value: str
    change_pct: float
    confidence: float  # 0.0 - 1.0
    rationale: str
    safety_check: str  # "pass", "warning", "blocked"

@dataclass
class RecommendationSet:
    app_id: str
    workload_type: str
    recommendations: List[Recommendation]
    overall_confidence: float
    safety_issues: List[str]
    generated_at: datetime
```

### File Structure
```
scripts/autotuning/
├── recommender.py
├── config/
│   ├── rules.yaml
│   ├── profiles.yaml
│   └── bounds.yaml
└── tests/
    ├── test_recommender.py
    └── fixtures/
        └── sample_analysis.json
```

## Definition of Done
- Code reviewed and merged
- Tests passing (coverage >= 80%)
- All profiles implemented
- Safety bounds enforced
- Documentation in docstrings

## Estimated Effort
Medium (rule engine with multiple profiles)

## Blocked By
- WS-AUTO-02 (Pattern Analyzer)

## Blocks
- WS-AUTO-04 (Helm Values Generator)
