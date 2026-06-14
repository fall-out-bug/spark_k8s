# Observability References: Spark + Airflow + S3 on K8s

Curated list of ready-to-install dashboards, exporters, profiling tools, and reference architectures for extending spark_k8s observability stack (Prometheus + Grafana + Loki + Jaeger + MinIO).

Last updated: 2026-06-14.

---

## Already in this repo (do NOT re-add)

**Grafana dashboards** (`charts/observability/grafana/dashboards/`):
- `spark-overview.json`, `demo-spark-overview.json`
- `cost-breakdown.json`, `cost-by-job.json`, `cost-by-team.json`, `cost-trends.json`
- `slo-forecast.json`, `incident-metrics.json`, `performance-analysis.json`
- `spark-job-anatomy.json`, `budget-status.json`, `backup-status.json`
- `rto-rpo.json`, `chaos-metrics.json`

**Per-chart dashboards** (`charts/spark-3.5/templates/monitoring/`):
- `grafana-dashboard-{executor-metrics,jmx,job-performance,ml-training,nyc-taxi,spark-overview,autotuning,streaming,profiling,job-phase-timeline}.yaml`

**Datasources**: Prometheus, Loki, Jaeger (no CloudWatch, no MinIO-native).

---

## 1. Spark dashboards & exporters

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 1.1 | Spark Performance Metrics (Grafana #7890) | https://grafana.com/grafana/dashboards/7890-spark-performance-metrics/ | Apache-2.0 | Driver/executor JVM via JMX exporter, GC/thread panels complementing existing `executor-metrics.yaml` |
| 1.2 | JVM Overview (Grafana #7727) | https://grafana.com/grafana/dashboards/7727-jvm-overview/ | Apache-2.0 | Heap/non-heap, GC (ParNew/CMS/G1), thread states, universal JVM companion |
| 1.3 | CERN Spark Dashboard | https://github.com/cerndb/spark-dashboard | Apache-2.0 | Spark on K8s focused: active tasks, I/O, shuffle, executor lifecycle. `/metrics/prometheus` source. |
| 1.4 | hammerlab/grafana-spark-dashboards | https://github.com/hammerlab/grafana-spark-dashboards | MIT | Per-executor drilldowns, stage runtime |
| 1.5 | Delight (DataMechanics) | https://github.com/datamechanics/delight | Apache-2.0 | SHS replacement, sidecar reading event logs from MinIO. Spark 3.x/4.x. |
| 1.6 | sparkMeasure (LucaCanali) | https://github.com/LucaCanali/sparkmeasure | Apache-2.0 | Stage/task metrics via `--packages ch.cern.sparkmeasure:spark-measure_2.12:0.25`. GA, recommended. |
| 1.7 | Spark-Operator Scale Test (Grafana #23032) | https://grafana.com/grafana/dashboards/23032-spark-operator-scale-test-dashboard/ | Apache-2.0 | Submit count, driver/executor launch latency, SparkApplication state. v2 metrics. |

**Sparklens (Qubole)** — **retired**, last release Spark 2.x only. Use sparkMeasure instead.

---

## 2. GPU / RAPIDS Spark

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 2.1 | NVIDIA DCGM Exporter (Helm) | https://github.com/NVIDIA/dcgm-exporter | Apache-2.0 | `helm install dcgm-exporter gpu-helm-charts/dcgm-exporter`. Node-level DaemonSet. Metrics: `DCGM_FI_DEV_GPU_UTIL`, `DCGM_FI_DEV_MEM_COPY_UTIL`, `DCGM_FI_DEV_FB_USED`, `DCGM_FI_DEV_POWER_USAGE`. |
| 2.2 | DCGM Exporter Dashboard (Grafana #12239) | https://grafana.com/grafana/dashboards/12239 | Apache-2.0 | Per-GPU util/mem/power/temp, PCIe throughput |
| 2.3 | NVIDIA DCGM Exporter Dashboard (Grafana #24450) | https://grafana.com/grafana/dashboards/24450-nvidia-dcgm-exporter-dashboard/ | Apache-2.0 | Newer, more detailed |
| 2.4 | NVIDIA MIG DCGM (Grafana #23382) | https://grafana.com/grafana/dashboards/23382-nvidia-mig-dcgm/ | Apache-2.0 | For MIG-partitioned GPUs |
| 2.5 | spark-rapids-tools | https://github.com/NVIDIA/spark-rapids-tools | Apache-2.0 | Qualification + Profiling tools for event logs. `pip install spark-rapids-user-tools`. |
| 2.6 | RAPIDS Self Profiler | https://docs.nvidia.com/spark-rapids/user-guide/latest/self-profiler.html | Apache-2.0 | Built-in Nsight Systems `.nsys-rep` output |

---

## 3. Airflow dashboards & exporters

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 3.1 | Airflow statsd-exporter (built-in subchart) | https://artifacthub.io/packages/helm/apache-airflow/airflow | Apache-2.0 | `statsd.enabled: true` in Helm values. Sidecar scrapes DogStatsD, exposes Prometheus. |
| 3.2 | Airflow Cluster Dashboard (Grafana #20994) | https://grafana.com/grafana/dashboards/20994-airflow-cluster-dashboard/ | Apache-2.0 | DAG runs, task state, scheduler heartbeat, executor slots, queue depth |
| 3.3 | Airflow StatsD (Grafana #14451) | https://grafana.com/grafana/dashboards/14451 | Apache-2.0 | DAG run duration, task duration by operator, failures |
| 3.4 | Airflow Detailed (Grafana #14550) | https://grafana.com/grafana/dashboards/14550 | Apache-2.0 | Per-DAG p50/p95, slot pool usage, task instance counts |
| 3.5 | Astronomer Cosmos | https://github.com/astronomer/astronomer-cosmos | Apache-2.0 | dbt + Airflow integration, dbt model as observable task |
| 3.6 | OpenLineage provider | https://airflow.apache.org/docs/apache-airflow-providers-openlineage/stable/ | Apache-2.0 | Lineage: DAG run → task → downstream Spark run. Pairs with OpenLineage Spark integration. |

---

## 4. Profiling tools

### 4.1 JVM

| Tool | URL | License | Output | Notes |
|------|-----|---------|--------|-------|
| async-profiler | https://github.com/async-profiler/async-profiler | Apache-2.0 | JFR, folded stacks, SVG, HTML | Top pick. Bake `libasyncProfiler.so` into executor image, attach via `asprof` or `-agentpath:`. <1% overhead, GA. |
| JFR + JDK Mission Control | https://github.com/openjdk/jmc | GPL-2.0+CE | `.jfr` binary → flame via `jfr2flame` | Built into JDK 11+. Zero deps. Cryostat (https://cryostat.io) automates K8s collection. |
| Grafana Pyroscope | https://github.com/grafana/pyroscope | AGPL-3.0 | Continuous flame graphs in Grafana | Java agent + server. LucaCanali guide: https://github.com/LucaCanali/Miscellaneous/blob/master/Spark_Notes/Tools_Spark_Pyroscope_FlameGraph.md |

### 4.2 Python / PySpark

| Tool | URL | License | Output | Notes |
|------|-----|---------|--------|-------|
| py-spy | https://github.com/benfred/py-spy | MIT | flame SVG, speedscope JSON | Top pick for UDF profiling. Static binary, `kubectl exec` into executor, needs `SYS_PTRACE`. |
| Scalene | https://github.com/plasma-umass/scalene | Apache-2.0 | HTML heatmap, memory + GPU | Less K8s-friendly (launch-under), better for Jupyter dev |
| cProfile | CPython stdlib | PSF | pstats | Wrap UDF body, convert via `pyprof2calltree` or `snakeviz` |

### 4.3 GPU

- **Nsight Systems** (`.nsys-rep`) — via RAPIDS Self Profiler (see §2.6)
- **DCGM Exporter** — Prometheus metrics (see §2.1)
- **Nsight Compute** — kernel-level, too invasive for prod

### 4.4 Flame graph viewers

| Tool | URL | License | Use |
|------|-----|---------|-----|
| FlameGraph.pl | https://github.com/brendangregg/FlameGraph | CDDL-1.0 | Classic CLI, folded stacks → SVG |
| speedscope | https://github.com/jlfwong/speedscope | MIT | Interactive web UI, reads py-spy/async-profiler `.json` |
| Pyroscope UI | https://github.com/grafana/pyroscope | AGPL-3.0 | Continuous, server-side, Grafana-native |

---

## 5. S3 / MinIO analytics

### 5.1 MinIO native

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 5.1.1 | MinIO Audit Log Webhook | https://docs.min.io/minio/baremetal/audit-logging.html | AGPLv3 | Every S3 API call: GET/PUT, user, bucket, latency, status, bytes. Pipe to Loki via Promtail. |
| 5.1.2 | MinIO Prometheus metrics | https://github.com/minio/minio/blob/master/docs/metrics/prometheus/README.md | AGPLv3 | `/minio/v2/metrics/{cluster,bucket,resource}`. Bucket endpoint = cost-analytics goldmine. |
| 5.1.3 | MinIO Overview (Grafana #10946 / #13502) | https://grafana.com/grafana/dashboards/13502-minio-overview/ | Apache-2.0 | Cluster-wide |
| 5.1.4 | MinIO Bucket Dashboard (Grafana #19237) | https://grafana.com/grafana/dashboards/19237-minio-bucket-dashboard/ | Apache-2.0 | Per-bucket cost, objects, GET/PUT rate |
| 5.1.5 | MinIO Replication (Grafana #15305) | https://grafana.com/grafana/dashboards/15305-minio-replication-dashboard/ | Apache-2.0 | Replication lag, failures |

### 5.2 AWS S3 (migration path)

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 5.2.1 | AWS S3 CloudWatch dashboard (Grafana #22632) | https://grafana.com/grafana/dashboards/22632-aws-s3-cloudwatch/ | Apache-2.0 | Request rates, errors, transfer bytes |
| 5.2.2 | Grafana Alloy CloudWatch exporter | https://grafana.com/docs/alloy/latest/reference/components/prometheus/prometheus.exporter.cloudwatch/ | Apache-2.0 | CloudWatch → Prometheus |
| 5.2.3 | monitoringartist/grafana-aws-cloudwatch-dashboards | https://github.com/monitoringartist/grafana-aws-cloudwatch-dashboards | Apache-2.0 | 50+ AWS service dashboards including S3 |

### 5.3 Iceberg

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 5.3.1 | Apache Iceberg MetricsReporter | https://iceberg.apache.org/docs/latest/metrics-reporting/ | Apache-2.0 | `ScanReport` + `CommitReport` SPI. Implement custom reporter → Prometheus Pushgateway. ~200 LOC. Iceberg 1.4.1+. |
| 5.3.2 | AWS Prescriptive Guidance (Iceberg monitoring) | https://docs.aws.amazon.com/prescriptive-guidance/latest/apache-iceberg-on-aws/monitoring.html | - | Walkthrough for Prometheus reporter |

---

## 6. End-to-end observability references

### 6.1 OpenTelemetry

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 6.1.1 | godatadriven/spot | https://github.com/godatadriven/spot | Apache-2.0 | Spark → OTel Collector via OTLP. pip-install. |
| 6.1.2 | Airflow Traces (native, 2.10+) | https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/traces.html | Apache-2.0 | OTLP export of DAG-run/task spans |
| 6.1.3 | ByteDoodle walkthrough | https://blog.bytedoodle.com/distributed-tracing-a-powerful-approach-to-debugging-complex-systems/ | - | Full Airflow + Spark + Jaeger example with W3C TraceContext |
| 6.1.4 | AWS Spark-Iceberg + Jaeger | https://aws.plainenglish.io/monitor-your-spark-iceberg-pipelines-with-opentelemetry-and-jaeger-hands-on-observability-59111f940ec7 | - | Concrete config |
| 6.1.5 | OpenLineage Spark integration | https://github.com/OpenLineage/OpenLineage/tree/main/integration/spark | Apache-2.0 | Lineage events with `ParentRunFacet` linking Airflow → Spark |

**Pattern**: pass `traceparent` from Airflow SparkSubmitOperator env → Spark driver → executor. Single Tempo/Jaeger trace contains both DAG task span and Spark stage spans.

### 6.2 Commercial reference architectures (educational)

| # | Resource | URL | Notes |
|---|----------|-----|-------|
| 6.2.1 | Datadog Data Observability | https://docs.datadoghq.com/data_observability/jobs_monitoring/kubernetes/ | Per-stage duration, executor GC, spill, shuffle skew, task failure rate, cost-per-DAG-run |
| 6.2.2 | Datadog on Spark (podcast) | https://datadogon.datadoghq.com/episodes/datadog-on-spark/ | Internal Datadog 10T+/day alert taxonomy |
| 6.2.3 | NewRelic Spark quickstart | https://newrelic.com/instant-observability/spark | "Metrics that matter" list for executors |
| 6.2.4 | Lightbend Telemetry (Cinnamon) | https://doc.akka.io/libraries/akka-insights/2.18.x/instrumentations/instrumentations.html | Commercial, bytecode-instrumented. Spark Structured Streaming + Akka. |

### 6.3 Uber open-source

| # | Resource | URL | License | Notes |
|---|----------|-----|---------|-------|
| 6.3.1 | Uber M3 | https://www.uber.com/us/en/blog/m3/ | Apache-2.0 | Prometheus-compatible scalable TSDB. Multi-tenant, downsampling, long-term. |
| 6.3.2 | Uber JVM Profiler | https://www.uber.com/us/en/blog/jvm-profiler/ | Apache-2.0 | Single JAR, attaches to driver/executor, ships to Kafka/HTTP |
| 6.3.3 | Uber I/O observability | https://www.uber.com/us/en/blog/i-o-observability-for-ubers-massive-petabyte-scale-data-lake/ | - | S3A/HDFS I/O attribution per task — applicable to cost-by-job on MinIO |

### 6.4 Apache Spark official

- **Spark Monitoring & Instrumentation** — https://spark.apache.org/docs/latest/monitoring.html
- Dropwizard Metrics, `MetricsSystem`, REST `/metrics/json`, PrometheusServlet (Spark 3+)
- Authoritative metric list — align alert thresholds here before adopting third-party taxonomies

---

## Recommended install order (for this repo)

### Tier 1 — Quick wins, no new infra

1. **Grafana #23032** (Spark-Operator) — fills biggest operator-metrics gap
2. **Grafana #7890 + #7727** (Spark JVM + JVM Overview) — strengthens JVM coverage beyond `executor-metrics.yaml`
3. **Grafana #20994 + #14451** (Airflow) — after enabling `statsd.enabled: true` in Airflow subchart
4. **CERN spark-dashboard** — copy JSONs into ConfigMap, no new exporter

### Tier 2 — Adds exporters

5. **DCGM Exporter Helm chart + Grafana #12239/#24450** — unblocks RAPIDS UAT
6. **MinIO ServiceMonitor** — `/minio/v2/metrics/bucket` + Grafana #19237 (Bucket Dashboard)
7. **Delight sidecar** — event logs already land in MinIO; deploy as pod

### Tier 3 — Lineage + traces

8. **OpenLineage provider + Spark integration** — DAG → Spark run correlation
9. **godatadriven/spot + Airflow Traces (2.10+)** — end-to-end OTel, single Jaeger trace
10. **Pyroscope** — continuous JVM flame graphs in Grafana

### Tier 4 — Iceberg metrics

11. **Custom Iceberg MetricsReporter** — ~200 LOC, push to Prometheus Pushgateway. Track upstream: https://github.com/apache/iceberg/issues/16661

### Tier 5 — Profiling tools (per-executor)

12. **async-profiler** baked into base image + `SYS_PTRACE` flag (JVM)
13. **py-spy** static binary + `SYS_PTRACE` (Python UDFs)
14. **sparkMeasure** as `--packages` arg or listener

---

## Gaps in current repo (call-to-action)

| Gap | Solution |
|-----|----------|
| No SparkOperator dashboard | Install Grafana #23032 |
| No GPU/DCGM coverage | DCGM Exporter Helm + Grafana #12239 |
| No Iceberg metrics | Custom MetricsReporter (Tier 4 above) |
| No MinIO Prometheus scrape | ServiceMonitor + Grafana #19237 |
| No MinIO audit-log → Loki | Webhook sink + Promtail |
| No Airflow ↔ Spark trace propagation | OpenLineage or godatadriven/spot + W3C TraceContext |

---

## Sources

- [Apache Spark Monitoring](https://spark.apache.org/docs/latest/monitoring.html)
- [MinIO Prometheus metrics](https://github.com/minio/minio/blob/master/docs/metrics/prometheus/README.md)
- [MinIO Audit Logging](https://docs.min.io/minio/baremetal/audit-logging.html)
- [Apache Iceberg Metrics Reporting](https://iceberg.apache.org/docs/latest/metrics-reporting/)
- [Airflow Traces (OTel)](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/traces.html)
- [OpenLineage Spark integration](https://github.com/OpenLineage/OpenLineage/tree/main/integration/spark)
- [godatadriven/spot (Spark + OTel)](https://github.com/godatadriven/spot)
- [LucaCanali sparkMeasure](https://github.com/LucaCanali/sparkmeasure)
- [async-profiler](https://github.com/async-profiler/async-profiler)
- [py-spy](https://github.com/benfred/py-spy)
- [NVIDIA DCGM Exporter](https://github.com/NVIDIA/dcgm-exporter)
- [Datadog Data Observability for Spark on K8s](https://docs.datadoghq.com/data_observability/jobs_monitoring/kubernetes/)
- [Uber I/O observability for data lake](https://www.uber.com/us/en/blog/i-o-observability-for-ubers-massive-petabyte-scale-data-lake/)
