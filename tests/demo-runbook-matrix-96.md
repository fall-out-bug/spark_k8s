# Matrix 96 Runbook (gpu=false, platform=k8s)

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud)
- `kubectl` configured
- `helm` installed
- Docker images: `spark-custom:3.5.7`, `spark-custom:3.5.8`, `spark-custom:4.1.0`, `spark-custom:4.1.1` (build via `scripts/build-all-matrix-images.sh all`)

## Run

```bash
./scripts/run-matrix-96.sh
```

## Expected

- **96 scenarios** (gpu=false, platform=k8s)
- **Levels:** deploy → smoke → e2e → load (with history validation)
- **Output:** `tests/results/scenario-*.json`, `tests/results/matrix-96-summary.json`

## Run Time

- **Per scenario:** ~5–15 min (deploy ~3–5 min, smoke ~1 min, e2e ~2 min, load ~3–5 min)
- **96 scenarios sequential:** ~8–24 hours (cluster-dependent)
- **Documented target:** 96/96 PASS

## Results Format

`matrix-96-summary.json`:

```json
{
  "filter": "gpu=false,platform=k8s",
  "expected": 96,
  "passed": 96,
  "failed": 0,
  "failed_ids": [],
  "duration_sec": 28800,
  "pass_rate_pct": 100.0
}
```

## Known Failures

Track in beads: `bd list --status=blocked` for scenarios requiring fixes (image, config, MinIO, chart).
