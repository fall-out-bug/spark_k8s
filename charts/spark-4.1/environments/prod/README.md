# Production Environment

## Purpose
Production environment с maximum reliability и security.

## Configuration
- **Replicas:** 3 (high availability)
- **Resources:** 8-16Gi memory, 4-8 CPU cores
- **Dynamic Allocation:** Enabled (2-50 executors)
- **PDB:** minAvailable: 2
- **Security:** PSS restricted + NetworkPolicies

## Usage
```bash
helm install spark-prod charts/spark-4.1 \
  -f charts/spark-4.1/environments/prod/values.yaml \
  -n spark-prod --create-namespace
```

## Important
- Manual approval required для promotion
- All security settings enforced
- High availability configured
