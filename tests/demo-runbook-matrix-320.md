# Matrix 320 Runbook (all scenarios)

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud)
- `kubectl` configured
- `helm` installed
- Docker images: `spark-custom:*` for all combinations (build via `scripts/build-all-matrix-images.sh all`)

## Run

```bash
./scripts/run-matrix-320.sh
```

## Expected

- **320 scenarios** (all from tests/test-matrix.yaml)
- **Levels:** deploy → smoke → e2e → load (with history validation)
- **Output:** `tests/results/scenario-*.json`, `tests/results/matrix-320-summary.json`

## Run Time

- **Per scenario:** ~5–15 min
- **320 scenarios sequential:** ~27–80 hours (cluster-dependent)

## Results Format

`matrix-320-summary.json`:

```json
{
  "filter": "(all)",
  "expected": 320,
  "passed": 320,
  "failed": 0,
  "failed_ids": [],
  "duration_sec": 86400,
  "pass_rate_pct": 100.0
}
```

## Known Failures

Track in beads: `bd list --status=blocked` for scenarios requiring fixes.
