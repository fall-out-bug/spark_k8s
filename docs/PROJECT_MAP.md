# Project Map

High-level map of this repository: what lives where and what to use for common tasks.

## Repository Structure

```
spark_k8s/
├── charts/              # Helm charts
│   ├── spark-platform/  # Spark Connect (legacy platform)
│   └── spark-standalone/ # Spark Standalone (master/workers + optional services)
├── docker/              # Docker images (Spark, Jupyter, etc.)
├── k8s/                 # Raw Kubernetes manifests (legacy/optional)
├── scripts/             # Smoke/E2E test scripts
├── docs/                # Documentation
│   ├── guides/          # Operator guides (EN/RU)
│   ├── drafts/         # SDP: idea drafts
│   ├── workstreams/     # SDP: workstreams (backlog/completed)
│   ├── adr/             # SDP: Architecture Decision Records
│   ├── issues/          # SDP: issue reports
│   └── uat/             # SDP: UAT guides
└── hooks/               # SDP: Git hooks for validation
```

## Charts

| Chart | Purpose | Components |
|-------|---------|------------|
| `charts/spark-platform` | Spark Connect (gRPC server + dynamic K8s executors) | Spark Connect, JupyterHub, History Server, MinIO, Hive Metastore |
| `charts/spark-standalone` | Spark Standalone (master/workers) | Spark Master/Workers, Shuffle Service, Airflow, MLflow, MinIO, Hive Metastore (all optional) |

**Shared values:** `charts/values-common.yaml` (S3/MinIO/SA/RBAC defaults)

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/test-spark-standalone.sh` | E2E smoke for Spark Standalone (master UI, worker registration, SparkPi) |
| `scripts/test-prodlike-airflow.sh` | Airflow DAG trigger+wait (example + ETL) |
| `scripts/test-sa-prodlike-all.sh` | Combined smoke (Spark E2E + Airflow DAGs) |
| `scripts/build-images.sh` | Build Docker images |
| `scripts/load-nyc-taxi-data.sh` | Load sample data (optional) |

## Documentation

- **Operator guides:** `docs/guides/` (EN + RU)
- **SDP artifacts:** `docs/drafts/`, `docs/workstreams/`, `docs/adr/`, `docs/issues/`, `docs/uat/`
- **This map:** `docs/PROJECT_MAP.md`

## Quick Navigation

**I want to...**
- **Deploy Spark Standalone** → `docs/guides/en/charts/spark-standalone.md` or `docs/guides/ru/charts/spark-standalone.md`
- **Deploy Spark Connect** → `docs/guides/en/charts/spark-platform.md` or `docs/guides/ru/charts/spark-platform.md`
- **Validate deployment** → `docs/guides/en/validation.md` or `docs/guides/ru/validation.md`
- **Understand OpenShift constraints** → `docs/guides/en/openshift-notes.md` or `docs/guides/ru/openshift-notes.md`
- **See SDP workflow** → `README.md` (SDP section) + `https://github.com/fall-out-bug/sdp`

## Testing Status

- **Tested on:** Minikube
- **Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`), with explicit caveats (see OpenShift notes)
