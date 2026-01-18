# Spark Platform на Kubernetes

Apache Spark 3.5.7 Helm charts для Kubernetes: Spark Connect (gRPC) и Spark Standalone (master/workers) с опциональными Airflow, MLflow, MinIO, Hive Metastore.

## Testing Status

- **Tested on:** Minikube
- **Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`), with explicit caveats (see [OpenShift notes](docs/guides/en/openshift-notes.md))

## Quick Navigation

### Charts

| Chart | Description | Guide |
|-------|-------------|-------|
| `charts/spark-platform` | Spark Connect (gRPC server + dynamic K8s executors) + JupyterHub | [EN](docs/guides/en/charts/spark-platform.md) / [RU](docs/guides/ru/charts/spark-platform.md) |
| `charts/spark-standalone` | Spark Standalone (master/workers) + optional Airflow/MLflow | [EN](docs/guides/en/charts/spark-standalone.md) / [RU](docs/guides/ru/charts/spark-standalone.md) |

### Documentation

- **Operator guides:** [`docs/guides/`](docs/guides/README.md) (EN + RU)
- **Spark 4.1.0 quickstart:** [EN](docs/guides/SPARK-4.1-QUICKSTART.md) / [RU](docs/guides/SPARK-4.1-QUICKSTART-RU.md)
- **Repository map:** [`docs/PROJECT_MAP.md`](docs/PROJECT_MAP.md)
- **Validation:** [`docs/guides/en/validation.md`](docs/guides/en/validation.md) / [`docs/guides/ru/validation.md`](docs/guides/ru/validation.md)
- **OpenShift notes:** [`docs/guides/en/openshift-notes.md`](docs/guides/en/openshift-notes.md) / [`docs/guides/ru/openshift-notes.md`](docs/guides/ru/openshift-notes.md)

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/test-spark-standalone.sh` | E2E smoke for Spark Standalone |
| `scripts/test-prodlike-airflow.sh` | Airflow DAG trigger+wait |
| `scripts/test-sa-prodlike-all.sh` | Combined smoke (Spark + Airflow) |

### Spec-Driven Protocol (SDP)

Работа в этом репозитории ведётся по **Spec-Driven Protocol (SDP)**: идеи → workstreams → build → review → deploy.

- SDP репозиторий: `https://github.com/fall-out-bug/sdp`
- Артефакты по фичам:
  - `docs/drafts/` — драфты требований
  - `docs/workstreams/` — workstreams (backlog/in_progress/completed)
  - `docs/adr/` — ADR
  - `docs/issues/` — issue-отчёты по проблемам
  - `docs/uat/` — UAT гайды

---

## Detailed Documentation

For detailed guides, see [`docs/guides/`](docs/guides/README.md):

- **Architecture & Components:** See chart guides
- **Quickstart:** See chart guides (Minikube tested)
- **Configuration:** See chart guides + overlays
- **Usage:** See chart guides
- **Monitoring & Troubleshooting:** See [validation guide](docs/guides/en/validation.md) / [RU](docs/guides/ru/validation.md)

---

## Repository Structure

See [`docs/PROJECT_MAP.md`](docs/PROJECT_MAP.md) for a complete map of what lives where.

---

## License

MIT License
