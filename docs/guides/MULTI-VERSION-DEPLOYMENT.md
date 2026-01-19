# Multi-Version Spark Deployment (3.5.7 + 4.1.0)

This guide explains how to run Spark 3.5.7 (LTS) and 4.1.0 (latest)
in the same Kubernetes cluster.

## Overview

Use cases:

- Gradual migration to Spark 4.1.0
- Version-specific features
- Team isolation (DS on 4.1.0, legacy pipelines on 3.5.7)

## Isolation Strategy

Components that MUST be isolated:

| Component | Isolation Method | Rationale |
|-----------|------------------|-----------|
| Hive Metastore | Separate databases (`metastore_spark35`, `metastore_spark41`) | Schema incompatibility |
| History Server | Separate S3 prefixes (`/3.5/events`, `/4.1/events`) | Log format differences |
| Services | Different release names (`spark-35`, `spark-41`) | Avoid conflicts |
| RBAC | Separate ServiceAccounts | Permission isolation |

Components that CAN be shared:

- PostgreSQL (different databases)
- MinIO (different buckets/prefixes)
- Namespace (OK for dev/test, use separate in prod)

## Deployment

### Option 1: Same Namespace (Dev/Test)

```bash
# Spark 3.5.7 Standalone
helm install spark-35 charts/spark-3.5 \
  --namespace spark \
  --set spark-standalone.enabled=true \
  --set spark-standalone.hiveMetastore.enabled=true \
  --set spark-standalone.historyServer.enabled=true \
  --set spark-standalone.historyServer.logDirectory="s3a://spark-logs/3.5/events" \
  --wait

# Spark 4.1.0 Connect
helm install spark-41 charts/spark-4.1 \
  --namespace spark \
  --set connect.enabled=true \
  --set hiveMetastore.enabled=true \
  --set hiveMetastore.database.name="metastore_spark41" \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory="s3a://spark-logs/4.1/events" \
  --wait
```

### Option 2: Separate Namespaces (Production)

```bash
kubectl create namespace spark-35
kubectl create namespace spark-41

helm install spark-35 charts/spark-3.5 \
  --namespace spark-35 \
  --set spark-standalone.enabled=true \
  --wait

helm install spark-41 charts/spark-4.1 \
  --namespace spark-41 \
  --set connect.enabled=true \
  --wait
```

## Verification

### 1) Service isolation

```bash
kubectl get svc -n spark | grep -E "(spark-35|spark-41)"
```

### 2) Metastore isolation

Verify DB names are different (see chart env vars):

```bash
kubectl get deploy -n spark -l app=hive-metastore -o jsonpath='{.items[*].spec.template.spec.containers[0].env}'
```

### 3) History Server isolation

```bash
kubectl logs -n spark -l app=spark-history-server | grep "s3a://spark-logs"
```

### 4) Run coexistence test

```bash
./scripts/test-coexistence.sh spark
```

## Migration Strategy (Phased)

### Phase 1: Parallel Deployment

1. Deploy Spark 4.1.0 alongside 3.5.7
2. Keep production on 3.5.7
3. Run smoke tests on 4.1.0

### Phase 2: Pilot Migration

1. Migrate 1-2 low-risk jobs to 4.1.0
2. Compare performance (use benchmark script)
3. Monitor for stability issues

### Phase 3: Gradual Rollout

1. Migrate 20% of jobs per week
2. Keep 3.5.7 running for rollback
3. Track job KPIs via History Server

### Phase 4: Decommission 3.5.7

1. Migrate remaining jobs
2. Run final coexistence test
3. Uninstall `spark-35`

## Common Pitfalls

### Service name conflict

**Symptom:** `helm install` fails with "service already exists".

**Fix:** Use different release names (`spark-35`, `spark-41`).

### Shared metastore database

**Symptom:** schema errors or missing tables.

**Fix:** Use separate databases:

- 3.5.7: `metastore_spark35`
- 4.1.0: `metastore_spark41`

### History Server reads wrong logs

**Symptom:** logs from one version appear in the other.

**Fix:** Separate S3 prefixes:

- 3.5.7: `s3a://spark-logs/3.5/events`
- 4.1.0: `s3a://spark-logs/4.1/events`

## Best Practices

1. Use separate namespaces in production.
2. Track Spark version per job (e.g., in Airflow metadata).
3. Keep 3.5.7 for rollback until 4.1.0 is stable.
4. Avoid automatic Hive Metastore migration (out of scope).

## Example Values Overlay

Use the provided overlay for a shared namespace setup:

- `docs/examples/values-multi-version.yaml`

```bash
helm install spark-35 charts/spark-3.5 -f docs/examples/values-multi-version.yaml
helm install spark-41 charts/spark-4.1 -f docs/examples/values-multi-version.yaml
```

## References

- [Coexistence Test Script](../../scripts/test-coexistence.sh)
- [Spark 3.5.7 Production Guide](SPARK-STANDALONE-PRODUCTION.md)
- [Spark 4.1.0 Production Guide](SPARK-4.1-PRODUCTION.md)
