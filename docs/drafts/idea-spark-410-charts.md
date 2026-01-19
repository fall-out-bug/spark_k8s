# Feature Draft: Apache Spark 4.1.0 Charts

**Status:** Draft  
**Created:** 2026-01-15  
**Feature ID:** F04 (tentative)

## 📋 Overview

Extend the repository with Helm charts for **Apache Spark 4.1.0**, supporting modern deployment patterns (Spark Connect, Kubernetes native executors, Spark Operator) while maintaining compatibility with existing Spark 3.5.7 LTS infrastructure.

**Inspiration:** This feature is inspired by patterns and best practices from [aagumin/spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes) repository.

## 🎯 Goals

1. **Multi-Version Support**: Enable simultaneous deployment of Spark 3.5.7 (LTS) and Spark 4.1.0 (latest) in the same cluster
2. **Modern Deployment Patterns**: Provide production-ready configurations for Spark Connect and Kubernetes native executors
3. **Modular Architecture**: Create reusable, composable chart components that share common infrastructure
4. **Optional Advanced Features**: Include Celeborn (disaggregated shuffle), Spark Operator as opt-in components
5. **Minimal Migration Friction**: Ensure existing `spark-platform` and `spark-standalone` charts remain functional

## 👥 Target Users

1. **Data Scientists**: Using Jupyter notebooks with Spark Connect (both 3.5.7 and 4.1.0)
2. **DataOps/Data Engineers**: Deploying production Spark applications via K8s native mode or Spark Operator
3. **Platform Engineers**: Managing multi-version Spark infrastructure

## 🏗️ Architecture

### Modular Chart Structure

```
charts/
├── spark-base/              # Shared components (RBAC, configs, MinIO, PostgreSQL)
│   ├── templates/
│   │   ├── rbac.yaml
│   │   ├── minio.yaml       # S3-compatible storage (optional)
│   │   ├── postgresql.yaml  # Metastore backend (optional)
│   │   └── _helpers.tpl     # Shared template functions
│   └── values.yaml
│
├── spark-3.5/               # Spark 3.5.7 LTS (existing + refactored)
│   ├── charts/
│   │   ├── spark-connect/   # Refactored from spark-platform
│   │   └── spark-standalone/ # Existing spark-standalone
│   ├── templates/
│   │   ├── hive-metastore.yaml  # Metastore 3.1.3
│   │   ├── history-server.yaml
│   │   └── jupyter.yaml         # Custom Jupyter with Spark 3.5.7
│   └── values.yaml
│
├── spark-4.1/               # Spark 4.1.0 (new)
│   ├── charts/
│   │   └── spark-connect/   # Spark Connect 4.1.0
│   ├── templates/
│   │   ├── hive-metastore.yaml  # Metastore 4.0.0
│   │   ├── history-server.yaml
│   │   ├── jupyter.yaml         # Official pyspark:4.1.0 + minimal config
│   │   └── celeborn.yaml        # Disaggregated shuffle (optional)
│   └── values.yaml
│
├── spark-operator/          # Kubernetes Operator (optional)
│   ├── templates/
│   │   ├── operator-deployment.yaml
│   │   ├── crds/
│   │   │   └── sparkapplications.yaml
│   │   └── rbac.yaml
│   └── values.yaml
│
└── values-common.yaml       # Shared values overlay (existing)
```

### Deployment Modes

| Mode | Spark Version | Use Case | Chart |
|------|---------------|----------|-------|
| **Spark Connect** | 3.5.7 | DS notebooks (stable) | `spark-3.5/charts/spark-connect` |
| **Spark Connect** | 4.1.0 | DS notebooks (latest) | `spark-4.1/charts/spark-connect` |
| **K8s Native** | 4.1.0 | Production jobs | `spark-4.1` + client config |
| **Spark Operator** | 4.1.0 | Declarative CRDs | `spark-operator` + `spark-4.1` |
| **Standalone** | 3.5.7 | Legacy pipelines | `spark-3.5/charts/spark-standalone` |

## 🧩 Component Versioning

### Version Matrix

| Component | Spark 3.5.7 | Spark 4.1.0 | Notes |
|-----------|-------------|-------------|-------|
| **Spark** | 3.5.7 | 4.1.0 | Both supported simultaneously |
| **Hive Metastore** | 3.1.3 | 4.0.0 | **Separate instances**, no migration |
| **Jupyter** | Custom image (`spark-custom:3.5.7`) | Official (`pyspark:4.1.0`) | Minimal customization for 4.1.0 |
| **History Server** | 3.5.7 (default) | 4.1.0 (default) | **Separate by default**, optional shared 4.1.0 if backward compatible |
| **PostgreSQL** | Shared | Shared | Single instance, different databases |
| **MinIO** | Shared | Shared | Single instance, version-specific buckets |
| **Celeborn** | N/A | 0.6.1+ | **Optional**, K8s native only |
| **Spark Operator** | N/A | v1beta2 API | **Optional**, supports 4.1.0 |

### History Server Strategy

**Default (recommended):**
- Separate History Servers per Spark version
- Each reads from version-specific S3 prefix (`s3a://spark-logs/3.5/events`, `s3a://spark-logs/4.1/events`)

**Optional (if backward compatible):**
- Single History Server 4.1.0 reading both prefixes
- Requires runtime validation (Acceptance Criteria: confirm compatibility)
- Document recommendations in operator guide

## 🔧 Key Technical Features

### 1. Spark Connect (4.1.0)

**Configuration highlights** (inspired by [spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes)):

```yaml
spark:
  master: "k8s://https://kubernetes.default.svc.cluster.local:443"
  connect:
    grpc:
      binding:
        port: 15002
  dynamicAllocation:
    enabled: true
    shuffleTracking:
      enabled: true
  kubernetes:
    executor:
      request:
        cores: "1"
      limit:
        cores: "2"
      podTemplateFile: "/opt/spark/conf/executor-pod-template.yaml"
```

**Features:**
- Dynamic allocation with shuffle tracking
- Executor pod templates for K8s native
- gRPC server for remote Spark sessions
- Support for `spark.jars.packages` dynamic loading

### 2. Kubernetes Native Executors

**Executor Pod Template:**
- Security contexts (PSS `restricted` compatible)
- Resource requests/limits
- Node affinity/tolerations
- Optional Istio sidecar injection (mTLS)

**Example:**
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 185
    fsGroup: 185
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: executor
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      readOnlyRootFilesystem: true
```

### 3. Apache Celeborn (Optional)

**Purpose:** Disaggregated shuffle service for improved stability and performance in large-scale jobs.

**Benefits:**
- ✅ Decouple shuffle data from executor lifecycle
- ✅ Reduce OOM and shuffle fetch failures
- ✅ Optimize skewed partitions
- ✅ Enable aggressive executor scaling (spot instances, dynamic allocation)

**Architecture:**
```yaml
celeborn:
  enabled: false  # Opt-in
  masters:
    replicas: 3
  workers:
    replicas: 3
    storage:
      size: "100Gi"
      storageClass: "standard"
```

**Use Cases:**
- Production jobs with >100GB shuffle
- Cost optimization with spot instances
- High-churn executor environments

**Skip for:**
- Dev/testing environments
- Small datasets (<10GB)
- Spark Standalone mode (use External Shuffle Service instead)

### 4. Spark Operator (Optional)

**CRD-based declarative management:**

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
spec:
  type: Scala
  mode: cluster
  image: "spark-custom:4.1.0"
  sparkVersion: "4.1.0"
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples.jar"
  driver:
    cores: 1
    memory: "512m"
  executor:
    cores: 1
    instances: 2
    memory: "512m"
```

**Features:**
- Automatic submission/monitoring
- TTL-based cleanup
- Webhook-based validation
- Integration with Celeborn

## 🐳 Docker Images

### Spark 4.1.0 Image

**Build strategy** (inspired by [spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes) Dockerfile):

**Multi-stage build:**
```dockerfile
# Stage 1: Builder
FROM eclipse-temurin:17 AS builder
ARG SPARK_VERSION=4.1.0

# Download and patch Spark
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}.tgz
# Apply patches (if needed for K8s executor fixes)
COPY patches/*.patch /tmp/
RUN cd spark-${SPARK_VERSION} && \
    patch -p1 < /tmp/spark-*.patch || true

# Build with profiles
RUN ./dev/make-distribution.sh \
    -Pconnect \
    -Pkubernetes \
    -Phadoop-3 \
    -Phadoop-cloud \
    -Phive

# Stage 2: Runtime
FROM python:3.10-slim-bookworm
COPY --from=builder /opt/spark /opt/spark

# Install dependencies via Maven/pip
COPY deps/pom.xml /tmp/
RUN mvn dependency:copy-dependencies -DoutputDirectory=/opt/spark/jars

COPY deps/requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

# Non-root user
RUN groupadd -g 185 spark && useradd -u 185 -g 185 spark
USER 185

ENTRYPOINT ["/opt/spark/bin/entrypoint.sh"]
```

**Dependencies (from `deps/pom.xml`):**
- `spark-connect_2.12:4.1.0`
- `celeborn-client-spark-3-shaded_2.12:0.6.1` (if enabled)
- `hadoop-aws:3.4.2`

### Jupyter Image (4.1.0)

**Approach:** Use official `apache/spark-py:4.1.0` as base, minimal customization:

```dockerfile
FROM apache/spark-py:4.1.0

# Add Jupyter
RUN pip install jupyterlab==4.0.0 pyspark==4.1.0

# Copy Spark Connect client config
COPY spark_config.py /opt/spark/conf/

USER 185
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser"]
```

## 🧪 Testing Strategy

### 1. Smoke Tests (Both Versions)

**Spark 3.5.7:**
```bash
scripts/test-spark-3.5-smoke.sh
```
- SparkPi job submission
- Hive table creation
- Jupyter notebook execution
- History Server API query

**Spark 4.1.0:**
```bash
scripts/test-spark-4.1-smoke.sh
```
- Spark Connect client connection
- K8s native executor launch
- Celeborn shuffle (if enabled)
- History Server event log parsing

### 2. Compatibility Tests

**Co-existence:**
```bash
scripts/test-coexistence.sh
```
- Deploy both 3.5.7 and 4.1.0 in same cluster
- Verify isolated Hive Metastores
- Verify separate History Servers
- Cross-version job submission (ensure no conflicts)

### 3. History Server Backward Compatibility

```bash
scripts/test-history-server-compat.sh
```
- Run Spark 3.5.7 job → write event logs
- Run Spark 4.1.0 job → write event logs
- Query 4.1.0 History Server for both logs
- Document compatibility status in `docs/guides/`

### 4. Performance Benchmarks

**TPC-DS subset (3.5.7 vs 4.1.0):**
```bash
scripts/benchmark-spark-versions.sh
```
- Query execution time
- Shuffle read/write metrics
- Memory usage
- With/without Celeborn comparison (4.1.0 only)

### 5. Integration Tests

**Combinations:**
- Spark Connect 4.1.0 + Jupyter
- Spark Connect 4.1.0 + Celeborn
- Spark Operator 4.1.0 + K8s native executors
- Spark Operator 4.1.0 + Celeborn

## 📚 Documentation

### Operator Guides (docs/guides/)

**English:**
- `SPARK-4.1-QUICKSTART.md` — Deploy Spark 4.1.0 in 5 minutes
- `SPARK-4.1-PRODUCTION.md` — Production best practices
- `SPARK-CONNECT-4.1.md` — Spark Connect setup and usage
- `CELEBORN-GUIDE.md` — When and how to use Celeborn
- `SPARK-OPERATOR-GUIDE.md` — CRD-based job management
- `MULTI-VERSION-DEPLOYMENT.md` — Running 3.5.7 and 4.1.0 together

**Russian:**
- `SPARK-4.1-QUICKSTART-RU.md`
- `SPARK-4.1-PRODUCTION-RU.md`
- (etc.)

### Values Overlays

**docs/examples/values-spark-4.1-minimal.yaml:**
```yaml
spark-4.1:
  enabled: true
  connect:
    enabled: true
  hiveMetastore:
    enabled: true
  historyServer:
    enabled: true
  jupyter:
    enabled: true

celeborn:
  enabled: false

spark-operator:
  enabled: false
```

**docs/examples/values-spark-4.1-production.yaml:**
```yaml
spark-4.1:
  enabled: true
  connect:
    replicas: 3
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"
      limits:
        memory: "8Gi"
        cpu: "4"
  
  celeborn:
    enabled: true
    workers:
      replicas: 5
      storage:
        size: "200Gi"
  
  security:
    podSecurityStandards: true
    mtls:
      enabled: true

spark-operator:
  enabled: true
```

### ADRs (Architectural Decision Records)

- `ADR-0004-spark-410-modular-architecture.md` — Why modular chart structure
- `ADR-0005-celeborn-disaggregated-shuffle.md` — Celeborn integration rationale
- `ADR-0006-spark-operator-optional.md` — Operator as opt-in component
- `ADR-0007-version-specific-metastores.md` — No automatic Hive migration

## 🚫 Out of Scope

1. **Automatic Data Migration**: No migration tools for Hive Metastore 3.1.3 → 4.0.0
2. **Multi-Tenancy**: No namespace isolation, RBAC quotas (future feature)
3. **Custom Jupyter Image Building**: No CI/CD for Jupyter images (use official + overlays)
4. **Monitoring/Observability**: No Prometheus exporters, Grafana dashboards (future feature)
5. **Spark 2.x Support**: Only 3.5.7 LTS and 4.1.0 latest

## ✅ Acceptance Criteria

### Functional
1. ✅ Spark 4.1.0 Spark Connect server deploys and accepts client connections
2. ✅ Kubernetes native executors launch and complete jobs
3. ✅ Celeborn shuffle service integrates with Spark 4.1.0 (optional)
4. ✅ Spark Operator deploys CRDs and manages SparkApplications (optional)
5. ✅ Jupyter with PySpark 4.1.0 connects to Spark Connect server
6. ✅ Hive Metastore 4.0.0 stores table metadata (isolated from 3.1.3)
7. ✅ History Server 4.1.0 parses event logs from S3
8. ✅ All smoke tests pass for 4.1.0 deployment

### Compatibility
1. ✅ Spark 3.5.7 and 4.1.0 coexist in same cluster without conflicts
2. ✅ Shared MinIO/PostgreSQL work for both versions (separate databases/buckets)
3. ✅ History Server backward compatibility validated (3.5.7 logs readable by 4.1.0 server, or separate instances recommended)

### Quality
1. ✅ `helm lint` passes for all new charts
2. ✅ `helm template` renders valid K8s manifests
3. ✅ PSS `restricted` compatible (OpenShift SCC emulation)
4. ✅ All documentation in EN + RU
5. ✅ Performance benchmarks show 4.1.0 parity or improvement vs 3.5.7

### Observability
1. ✅ All services expose health endpoints
2. ✅ Logs use structured JSON format
3. ✅ Integration tests cover failure scenarios (pod restarts, OOM, etc.)

## 📦 Deliverables

### Code
1. `charts/spark-base/` — Shared infrastructure components
2. `charts/spark-4.1/` — Spark 4.1.0 charts (Connect, K8s native, Celeborn)
3. `charts/spark-operator/` — Kubernetes Operator chart
4. `docker/spark-4.1/Dockerfile` — Multi-stage Spark 4.1.0 image
5. `docker/jupyter-4.1/Dockerfile` — Minimal Jupyter wrapper

### Scripts
1. `scripts/test-spark-4.1-smoke.sh` — Smoke tests
2. `scripts/test-coexistence.sh` — Multi-version compatibility
3. `scripts/test-history-server-compat.sh` — Backward compatibility validation
4. `scripts/benchmark-spark-versions.sh` — Performance comparison

### Documentation
1. `docs/guides/SPARK-4.1-QUICKSTART.md` (EN)
2. `docs/guides/SPARK-4.1-QUICKSTART-RU.md` (RU)
3. `docs/guides/CELEBORN-GUIDE.md` (EN)
4. `docs/guides/SPARK-OPERATOR-GUIDE.md` (EN)
5. `docs/guides/MULTI-VERSION-DEPLOYMENT.md` (EN + RU)
6. `docs/adr/ADR-0004-spark-410-modular-architecture.md`
7. `docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md`
8. `docs/examples/values-spark-4.1-*.yaml` — Copy-paste overlays

### Testing Artifacts
1. `docs/testing/F04-smoke-test-report.md`
2. `docs/testing/F04-compatibility-report.md`
3. `docs/testing/F04-performance-benchmark.md`
4. `docs/uat/UAT-F04-spark-410.md` — UAT guide

## 🔗 References

- [Apache Spark 4.1.0 Release Notes](https://spark.apache.org/releases/spark-release-4-1-0.html)
- [Spark on Kubernetes Guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [Apache Celeborn Documentation](https://celeborn.apache.org/)
- [Spark Operator Documentation](https://googlecloudplatform.github.io/spark-on-k8s-operator/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- **Inspiration:** [aagumin/spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes) — Reusable patterns for K8s native executors, Spark Connect configuration, Celeborn integration, and production-ready Dockerfiles

## 📝 Notes

- **Incremental Rollout**: Consider phased implementation (F04-01: base architecture, F04-02: Celeborn, F04-03: Operator)
- **Version Pinning**: Pin all image versions in `values.yaml` (no `latest` tags)
- **Backward Compatibility**: Existing `spark-platform` and `spark-standalone` charts remain functional, no breaking changes
- **License Consideration**: `spark-connect-kubernetes` repository has no explicit license; we acknowledge inspiration and reference it in documentation, but implement components independently

---

**Next Steps:**
1. Review and approve this draft
2. Run `/design idea-spark-410-charts` to decompose into workstreams
3. Estimate ~15-25 workstreams for complete implementation
