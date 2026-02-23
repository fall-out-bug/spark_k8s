# Spark Load Test Report

**Generated:** {{TIMESTAMP}}
**Dataset:** {{DATASET_SIZE}} NYC Taxi
**Spark Version:** {{SPARK_VERSION}}
**Date:** {{TEST_DATE}}

## Executive Summary

{{SUMMARY}}

## Test Environment

| Parameter | Value |
|-----------|--------|
| Kubernetes Distribution | {{K8S_DIST}} |
| Minikube Resources | {{MINIKUBE_RESOURCES}} |
| Spark Image | {{SPARK_IMAGE}} |
| Executors | {{EXECUTOR_COUNT}} |
| Cores per Executor | {{CORES_PER_EXECUTOR}} |
| Memory per Executor | {{MEMORY_PER_EXECUTOR}} |

## Test Scenarios

### Scenario 1: {{SCENARIO_1_NAME}}

**Backend Mode:** {{SCENARIO_1_BACKEND}}
**Preset:** {{SCENARIO_1_PRESET}}

| Operation | Status | Duration | Peak Memory | Shuffle Read | Shuffle Write | GC Time |
|-----------|--------|----------|--------------|---------------|---------------|----------|
| Read Parquet | {{OP1_STATUS}} | {{OP1_DURATION}} | {{OP1_MEMORY}} | {{OP1_SHUFFLE_R}} | {{OP1_SHUFFLE_W}} | {{OP1_GC}} |
| GroupBy/Agg | {{OP2_STATUS}} | {{OP2_DURATION}} | {{OP2_MEMORY}} | {{OP2_SHUFFLE_R}} | {{OP2_SHUFFLE_W}} | {{OP2_GC}} |
| Join | {{OP3_STATUS}} | {{OP3_DURATION}} | {{OP3_MEMORY}} | {{OP3_SHUFFLE_R}} | {{OP3_SHUFFLE_W}} | {{OP3_GC}} |
| Window | {{OP4_STATUS}} | {{OP4_DURATION}} | {{OP4_MEMORY}} | {{OP4_SHUFFLE_R}} | {{OP4_SHUFFLE_W}} | {{OP4_GC}} |
| Write Parquet | {{OP5_STATUS}} | {{OP5_DURATION}} | {{OP5_MEMORY}} | {{OP5_SHUFFLE_R}} | {{OP5_SHUFFLE_W}} | {{OP5_GC}} |
| **Total Pipeline** | **{{SC1_TOTAL_STATUS}}** | **{{SC1_TOTAL_DURATION}}** | **{{SC1_MAX_MEMORY}}** | **{{SC1_TOTAL_SHUFFLE_R}}** | **{{SC1_TOTAL_SHUFFLE_W}}** | **{{SC1_TOTAL_GC}}** |

### Scenario 2: {{SCENARIO_2_NAME}}

**Backend Mode:** {{SCENARIO_2_BACKEND}}
**Preset:** {{SCENARIO_2_PRESET}}

| Operation | Status | Duration | Peak Memory | Shuffle Read | Shuffle Write | GC Time |
|-----------|--------|----------|--------------|---------------|---------------|----------|
| Read Parquet | {{OP1_STATUS}} | {{OP1_DURATION}} | {{OP1_MEMORY}} | {{OP1_SHUFFLE_R}} | {{OP1_SHUFFLE_W}} | {{OP1_GC}} |
| GroupBy/Agg | {{OP2_STATUS}} | {{OP2_DURATION}} | {{OP2_MEMORY}} | {{OP2_SHUFFLE_R}} | {{OP2_SHUFFLE_W}} | {{OP2_GC}} |
| Join | {{OP3_STATUS}} | {{OP3_DURATION}} | {{OP3_MEMORY}} | {{OP3_SHUFFLE_R}} | {{OP3_SHUFFLE_W}} | {{OP3_GC}} |
| Window | {{OP4_STATUS}} | {{OP4_DURATION}} | {{OP4_MEMORY}} | {{OP4_SHUFFLE_R}} | {{OP4_SHUFFLE_W}} | {{OP4_GC}} |
| Write Parquet | {{OP5_STATUS}} | {{OP5_DURATION}} | {{OP5_MEMORY}} | {{OP5_SHUFFLE_R}} | {{OP5_SHUFFLE_W}} | {{OP5_GC}} |
| **Total Pipeline** | **{{SC2_TOTAL_STATUS}}** | **{{SC2_TOTAL_DURATION}}** | **{{SC2_MAX_MEMORY}}** | **{{SC2_TOTAL_SHUFFLE_R}}** | **{{SC2_TOTAL_SHUFFLE_W}}** | **{{SC2_TOTAL_GC}}** |

### Scenario 3: {{SCENARIO_3_NAME}}

**Backend Mode:** {{SCENARIO_3_BACKEND}}
**Preset:** {{SCENARIO_3_PRESET}}

| Operation | Status | Duration | Peak Memory | Shuffle Read | Shuffle Write | GC Time |
|-----------|--------|----------|--------------|---------------|---------------|----------|
| Read Parquet | {{OP1_STATUS}} | {{OP1_DURATION}} | {{OP1_MEMORY}} | {{OP1_SHUFFLE_R}} | {{OP1_SHUFFLE_W}} | {{OP1_GC}} |
| GroupBy/Agg | {{OP2_STATUS}} | {{OP2_DURATION}} | {{OP2_MEMORY}} | {{OP2_SHUFFLE_R}} | {{OP2_SHUFFLE_W}} | {{OP2_GC}} |
| Join | {{OP3_STATUS}} | {{OP3_DURATION}} | {{OP3_MEMORY}} | {{OP3_SHUFFLE_R}} | {{OP3_SHUFFLE_W}} | {{OP3_GC}} |
| Window | {{OP4_STATUS}} | {{OP4_DURATION}} | {{OP4_MEMORY}} | {{OP4_SHUFFLE_R}} | {{OP4_SHUFFLE_W}} | {{OP4_GC}} |
| Write Parquet | {{OP5_STATUS}} | {{OP5_DURATION}} | {{OP5_MEMORY}} | {{OP5_SHUFFLE_R}} | {{OP5_SHUFFLE_W}} | {{OP5_GC}} |
| **Total Pipeline** | **{{SC3_TOTAL_STATUS}}** | **{{SC3_TOTAL_DURATION}}** | **{{SC3_MAX_MEMORY}}** | **{{SC3_TOTAL_SHUFFLE_R}}** | **{{SC3_TOTAL_SHUFFLE_W}}** | **{{SC3_TOTAL_GC}}** |

### Scenario 4: {{SCENARIO_4_NAME}}

**Backend Mode:** {{SCENARIO_4_BACKEND}}
**Preset:** {{SCENARIO_4_PRESET}}

| Operation | Status | Duration | Peak Memory | Shuffle Read | Shuffle Write | GC Time |
|-----------|--------|----------|--------------|---------------|---------------|----------|
| Read Parquet | {{OP1_STATUS}} | {{OP1_DURATION}} | {{OP1_MEMORY}} | {{OP1_SHUFFLE_R}} | {{OP1_SHUFFLE_W}} | {{OP1_GC}} |
| GroupBy/Agg | {{OP2_STATUS}} | {{OP2_DURATION}} | {{OP2_MEMORY}} | {{OP2_SHUFFLE_R}} | {{OP2_SHUFFLE_W}} | {{OP2_GC}} |
| Join | {{OP3_STATUS}} | {{OP3_DURATION}} | {{OP3_MEMORY}} | {{OP3_SHUFFLE_R}} | {{OP3_SHUFFLE_W}} | {{OP3_GC}} |
| Window | {{OP4_STATUS}} | {{OP4_DURATION}} | {{OP4_MEMORY}} | {{OP4_SHUFFLE_R}} | {{OP4_SHUFFLE_W}} | {{OP4_GC}} |
| Write Parquet | {{OP5_STATUS}} | {{OP5_DURATION}} | {{OP5_MEMORY}} | {{OP5_SHUFFLE_R}} | {{OP5_SHUFFLE_W}} | {{OP5_GC}} |
| **Total Pipeline** | **{{SC4_TOTAL_STATUS}}** | **{{SC4_TOTAL_DURATION}}** | **{{SC4_MAX_MEMORY}}** | **{{SC4_TOTAL_SHUFFLE_R}}** | **{{SC4_TOTAL_SHUFFLE_W}}** | **{{SC4_TOTAL_GC}}** |

## Comparative Analysis: K8s vs Standalone

### Total Pipeline Duration

| Scenario | Backend Mode | Total Duration | vs Baseline |
|----------|--------------|----------------|--------------|
| {{SCENARIO_1_NAME}} | {{SCENARIO_1_BACKEND}} | {{SC1_TOTAL_DURATION}} | {{SC1_VS_BASELINE}} |
| {{SCENARIO_2_NAME}} | {{SCENARIO_2_BACKEND}} | {{SC2_TOTAL_DURATION}} | {{SC2_VS_BASELINE}} |
| {{SCENARIO_3_NAME}} | {{SCENARIO_3_BACKEND}} | {{SC3_TOTAL_DURATION}} | {{SC3_VS_BASELINE}} |
| {{SCENARIO_4_NAME}} | {{SCENARIO_4_BACKEND}} | {{SC4_TOTAL_DURATION}} | {{SC4_VS_BASELINE}} |

### Performance Comparison

| Metric | K8s Mode | Standalone Mode | Delta |
|--------|-----------|-----------------|--------|
| Average Pipeline Duration | {{K8S_AVG_DURATION}} | {{STANDALONE_AVG_DURATION}} | {{DURATION_DELTA}} |
| Peak Memory Usage | {{K8S_PEAK_MEMORY}} | {{STANDALONE_PEAK_MEMORY}} | {{MEMORY_DELTA}} |
| Total Shuffle Read | {{K8S_SHUFFLE_READ}} | {{STANDALONE_SHUFFLE_READ}} | {{SHUFFLE_READ_DELTA}} |
| Total Shuffle Write | {{K8S_SHUFFLE_WRITE}} | {{STANDALONE_SHUFFLE_WRITE}} | {{SHUFFLE_WRITE_DELTA}} |
| Total GC Time | {{K8S_GC_TIME}} | {{STANDALONE_GC_TIME}} | {{GC_DELTA}} |

### Findings

{{FINDINGS}}

**Key Observations:**
- {{OBSERVATION_1}}
- {{OBSERVATION_2}}
- {{OBSERVATION_3}}

**Recommendations:**
- {{RECOMMENDATION_1}}
- {{RECOMMENDATION_2}}

## Grafana Dashboard Validation

### Spark Overview Dashboard
- {{OVERVIEW_VALIDATION}}
- Screenshots: {{OVERVIEW_SCREENSHOTS}}

### Executor Metrics Dashboard
- {{EXECUTOR_VALIDATION}}
- Screenshots: {{EXECUTOR_SCREENSHOTS}}

### Job Performance Dashboard
- {{JOB_PERF_VALIDATION}}
- Screenshots: {{JOB_PERF_SCREENSHOTS}}

### Job Phase Timeline Dashboard
- {{PHASE_TIMELINE_VALIDATION}}
- Screenshots: {{PHASE_TIMELINE_SCREENSHOTS}}

### Spark Profiling Dashboard
- {{PROFILING_VALIDATION}}
- Screenshots: {{PROFILING_SCREENSHOTS}}

## Dynamic Allocation Behavior

### K8s Mode Scale-Up
- **Initial Executors:** {{INITIAL_EXECUTORS}}
- **Peak Executors:** {{PEAK_EXECUTORS}}
- **Scale-Up Time:** {{SCALE_UP_TIME}}
- **Observations:** {{SCALE_UP_OBSERVATIONS}}

### K8s Mode Scale-Down
- **Idle Timeout:** {{IDLE_TIMEOUT}}
- **Scale-Down Time:** {{SCALE_DOWN_TIME}}
- **Final Executors:** {{FINAL_EXECUTORS}}
- **Observations:** {{SCALE_DOWN_OBSERVATIONS}}

## Issues Encountered

{{ISSUES}}

| Issue | Severity | Resolution |
|--------|-----------|-------------|
| {{ISSUE_1_DESC}} | {{ISSUE_1_SEVERITY}} | {{ISSUE_1_RESOLUTION}} |
| {{ISSUE_2_DESC}} | {{ISSUE_2_SEVERITY}} | {{ISSUE_2_RESOLUTION}} |

## Conclusion

{{CONCLUSION}}

## Appendix: Test Logs

- Spark Driver Logs: `{{DRIVER_LOG_PATH}}`
- Spark Executor Logs: `{{EXECUTOR_LOG_PATH}}`
- Prometheus Metrics: `{{PROMETHEUS_EXPORT_PATH}}`
- MinIO Data: `{{MINIO_DATA_PATH}}`

---

*Report template for WS-025-11: Load Tests with 10GB NYC Taxi Dataset*
