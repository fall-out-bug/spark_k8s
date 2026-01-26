# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-26

### Added

#### Core Features
- **Spark 3.5.7 Helm charts**: Modular charts for Spark Connect and Spark Standalone
- **Spark 4.1.0 Helm chart**: Unified all-in-one chart with toggle-flags
- **Spark Connect Server**: Remote Spark execution via gRPC
- **Backend Modes**: K8s (dynamic executors), Standalone (fixed cluster), Operator (CRD-based)
- **Preset Configurations**: 11 ready-to-use values files for common scenarios
- **MinIO Integration**: S3-compatible object storage with auto-configuration
- **Jupyter Lab**: Remote Spark Connect with notebook templates
- **Hive Metastore**: Table metadata warehouse support
- **History Server**: Job monitoring and metrics visualization
- **Airflow Integration**: DAG scheduling for Spark jobs
- **MLflow Integration**: Experiment tracking for ML workflows

#### Documentation
- **Usage Guide** ([RU](docs/guides/ru/spark-k8s-constructor.md) / [EN](docs/guides/en/spark-k8s-constructor.md))
- **Quick Reference Card** ([RU](docs/guides/ru/quick-reference.md) / [EN](docs/guides/en/quick-reference.md))
- **Architecture Documentation**: System design and component relationships
- **23 Recipe Guides**: Operations, Troubleshooting, Deployment, Integration
- **7 Troubleshooting Scripts**: Diagnostics for common issues
- **5 Jupyter Notebooks**: Interactive troubleshooting notebooks

#### Testing & Validation
- **E2E Test Suite**: Minikube-validated end-to-end tests
- **Load Testing**: Support for synthetic and parquet data (11M+ records tested)
- **Preset Validation**: Automated Helm template validation
- **Policy-as-Code**: OPA/Conftest security policies for deployment validation

#### Tools & Scripts
- `scripts/load-nyt-parquet-data.sh` - Download and load parquet datasets
- `scripts/test-parquet-load.sh` - Parquet load testing
- `scripts/run-minikube-e2e.sh` - Unified E2E test runner
- `scripts/validate-presets.sh` - Preset validation
- `scripts/validate-policy.sh` - OPA policy validation

### Changed
- N/A (initial release)

### Fixed

#### Security & RBAC
- **ISSUE-031**: Auto-create `s3-credentials` secret for MinIO (spark-base chart)
- **ISSUE-033**: Add `configmaps` create permission to Spark Connect RBAC
- **ISSUE-033**: Add `watch` permission to Spark Connect RBAC

#### Dependencies
- **ISSUE-034**: Add `grpcio>=1.48.1` to Jupyter 4.1 Dockerfile
- **ISSUE-034**: Add `grpcio-status>=1.48.1` to Jupyter 4.1 Dockerfile
- **ISSUE-034**: Add `zstandard>=0.25.0` to Jupyter 4.1 Dockerfile

#### Quality
- **ISSUE-035**: Fix parquet data loader upload mechanism (use `mc pipe` instead of `kubectl cp`)

### Known Issues
- **ISSUE-030**: Helm "N/A" label validation error when installing spark-4.1 with spark-base enabled
  - **Workaround**: Install spark-base separately, then install spark-4.1 with `spark-base.enabled=false`
  - **Status**: Under investigation

### Tested On

| Platform | Status | Notes |
|----------|--------|-------|
| **Minikube** | ✅ Passed | E2E + load tests validated |
| **Kubernetes** | ✅ Prepared | Tested on v1.28.0 |
| **Python** | ✅ Tested | 3.10 |
| **Spark** | ✅ Tested | 3.5.7, 4.1.0 |

### Preset Catalog

| Scenario | Chart | Preset File | Backend |
|----------|-------|-------------|---------|
| Jupyter + Connect (K8s) | 4.1 | `values-scenario-jupyter-connect-k8s.yaml` | k8s |
| Jupyter + Connect (Standalone) | 4.1 | `values-scenario-jupyter-connect-standalone.yaml` | standalone |
| Airflow + Connect (K8s) | 4.1 | `values-scenario-airflow-connect-k8s.yaml` | k8s |
| Airflow + Connect (Standalone) | 4.1 | `values-scenario-airflow-connect-standalone.yaml` | standalone |
| Airflow + K8s Submit | 4.1 | `values-scenario-airflow-k8s-submit.yaml` | k8s |
| Airflow + Spark Operator | 4.1 | `values-scenario-airflow-operator.yaml` | operator |
| Jupyter + Connect (K8s) | 3.5 | `values-scenario-jupyter-connect-k8s.yaml` | k8s |
| Jupyter + Connect (Standalone) | 3.5 | `values-scenario-jupyter-connect-standalone.yaml` | standalone |
| Airflow + Connect | 3.5 | `values-scenario-airflow-connect.yaml` | standalone |
| Airflow + K8s Submit | 3.5 | `values-scenario-airflow-k8s-submit.yaml` | k8s |
| Airflow + Operator | 3.5 | `values-scenario-airflow-operator.yaml` | operator |

### Recipe Index

**Operations (3):**
- Configure event log for MinIO
- Enable event log (Spark 4.1)
- Initialize Hive Metastore

**Troubleshooting (10):**
- S3 connection failed
- History Server empty
- Spark properties syntax
- Zstandard library missing
- Driver not starting
- Driver host resolution
- Helm installation label validation
- S3 credentials secret missing
- Connect crashloop (RBAC)
- Jupyter Python dependencies

**Deployment (4):**
- Deploy Spark Connect for new team
- Migrate Standalone → K8s
- Add History Server HA
- Setup resource quotas

**Integration (5):**
- Airflow + Spark Connect
- MLflow experiment tracking
- External Hive Metastore (AWS Glue, EMR, HDInsight)
- Kerberos authentication
- Prometheus monitoring

### Migration from Previous Versions

This is the initial release. See [Migration Guide](docs/guides/MIGRATION.md) (planned for future releases).

### Contributors

- @fall-out-bug
- Claude (AI assistant)

### Links

- [Spark Documentation](https://spark.apache.org/docs/latest/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Project Issues](docs/issues/)

[0.1.0]: https://github.com/fall-out-bug/spark_k8s/releases/tag/v0.1.0
