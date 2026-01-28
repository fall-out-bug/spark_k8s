# Development Environment

## Purpose
Development environment для experimentation и debugging.

## Configuration
- **Replicas:** 1 (minimal)
- **Resources:** 2-4Gi memory, 1-2 CPU cores
- **Dynamic Allocation:** Enabled (0-5 executors)
- **Debug:** Enabled (verbose logging)

## Usage
```bash
helm install spark-dev charts/spark-4.1 \
  -f charts/spark-4.1/environments/dev/values.yaml \
  -n spark-dev --create-namespace
```

## Differences from Production
- Lower resource limits
- Debug logging enabled
- No podDisruptionBudget
- Faster shuffle timeouts
