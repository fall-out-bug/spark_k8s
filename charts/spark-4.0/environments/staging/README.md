# Staging Environment

## Purpose
Staging environment для pre-production testing.

## Configuration
- **Replicas:** 2 (high availability)
- **Resources:** 4-8Gi memory, 2-4 CPU cores
- **Dynamic Allocation:** Enabled (2-20 executors)
- **Debug:** Disabled

## Usage
```bash
helm install spark-staging charts/spark-4.0 \
  -f charts/spark-4.0/environments/staging/values.yaml \
  -n spark-staging --create-namespace
```

## Differences from Production
- Lower resource limits (prod: 8-16Gi)
- Smaller executor range
- Testing security settings
