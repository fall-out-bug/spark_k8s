# Smoke Test Matrix

> **Source of truth**: [`scripts/tests/smoke/matrix/smoke-matrix.yaml`](../scripts/tests/smoke/matrix/smoke-matrix.yaml). This document is auto-generated. Do not edit by hand — run `python3 scripts/tests/smoke/matrix/generate-smoke-doc.py`.

Full smoke matrix: 3 components × 4 spark versions × 3 modes × 4 features = **144 scenarios**.

## Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Components | jupyter, airflow, spark-submit | 3 |
| Spark Versions | 3.5.7, 3.5.8, 4.1.0, 4.1.1 | 4 |
| Modes | k8s, standalone, connect | 3 |
| Features | baseline, gpu, iceberg, gpu-iceberg | 4 |

## Priority Tiers

| Tier | Purpose | Timeout | Components | Versions | Modes | Features | Scenarios |
|------|---------|---------|------------|----------|-------|----------|-----------|
| p0_pr | PR gate — fast feedback | 30m | 2 | 2 | 2 | 1 | **8** |
| p1_nightly | Nightly — full coverage of k8s/standalone | 240m | 3 | 4 | 2 | 4 | **96** |
| p2_weekly | Weekly — full matrix incl. connect mode | 1440m | 3 | 4 | 3 | 4 | **144** |

## MANDATORY Requirements (all scenarios)

All smoke tests MUST include:

1. **S3 for Event Log** — all Spark job logs persisted to S3
2. **History Server** — deployed, reads logs from S3
3. **MinIO** — S3-compatible storage for local testing

```yaml
global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"
    pathStyleAccess: true
    sslEnabled: false

connect:  # or jupyter, spark-submit
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/{version}/events"

historyServer:
  enabled: true
  provider: "s3"
  s3:
    endpoint: "http://minio:9000"
```

## Scenario Naming

Pattern: `{component}-{feature_suffix}{mode}-{spark_version_short}.sh`

Examples:
- `airflow-connect-k8s-357.sh` (airflow, baseline, k8s, 3.5.7)
- `jupyter-gpu-k8s-410.sh` (jupyter, gpu, k8s, 4.1.0)
- `spark-submit-iceberg-standalone-411.sh` (spark-submit, iceberg, standalone, 4.1.1)

## P0 (PR gate)

**8 scenarios** — fast feedback, baseline only.

## P1 (Nightly)

### P1 Nightly — 96 scenarios

Matrix slice: components (3) × spark_versions (4) × modes (2) × features (4) = 96.

#### jupyter

| Mode | 3.5.7 | 3.5.8 | 4.1.0 | 4.1.1 |
|------|------|------|------|------|
| `k8s` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |
| `standalone` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |

Features per cell: baseline, gpu, iceberg, gpu-iceberg

#### airflow

| Mode | 3.5.7 | 3.5.8 | 4.1.0 | 4.1.1 |
|------|------|------|------|------|
| `k8s` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |
| `standalone` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |

Features per cell: baseline, gpu, iceberg, gpu-iceberg

#### spark-submit

| Mode | 3.5.7 | 3.5.8 | 4.1.0 | 4.1.1 |
|------|------|------|------|------|
| `k8s` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |
| `standalone` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` | see `scripts/tests/smoke/scenarios/` |

Features per cell: baseline, gpu, iceberg, gpu-iceberg

## P2 (Weekly)

**144 scenarios** — full matrix incl. connect mode.

## Image Pyramid

`scripts/tests/lib/get_runtime_image.sh` resolves image tag:

```
spark-custom:3.5.7|3.5.8|4.1.0|4.1.1 (base)
  → spark-k8s-runtime:<short>-7-{image_suffix}
  → spark-k8s-jupyter:<short>-7-{image_suffix}
```

## CI Integration

| Tier | Workflow | Trigger |
|------|----------|---------|
| P0 | `.github/workflows/ci-matrix-p0.yml` | `pull_request` |
| P1 | `.github/workflows/ci-matrix-p1.yml` | `schedule: nightly` |
| P2 | `.github/workflows/ci-matrix-p2.yml` | `schedule: weekly` |

_Auto-generated from `smoke-matrix.yaml`. Last regenerated: see git blame._
