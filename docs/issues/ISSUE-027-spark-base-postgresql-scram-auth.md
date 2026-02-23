# ISSUE-027: PostgreSQL SCRAM-SHA-256 Authentication Incompatibility

## Status
FIXED

## Resolution
Modified `charts/spark-base/templates/core/postgresql-configmap.yaml` to:
1. Set `password_encryption = 'md5'` via `ALTER SYSTEM` at PostgreSQL startup
2. Explicitly set `SET password_encryption = 'md5'` before creating hive user

## Severity
P1 - High (Blocks Hive Metastore startup)

## Component
charts/spark-base/templates/core/postgresql-configmap.yaml

## Description
Hive Metastore fails to connect to PostgreSQL with error:
```
The authentication type 10 is not supported. Check that you have configured the pg_hba.conf file
```

PostgreSQL 14+ uses SCRAM-SHA-256 as the default password encryption method (`password_encryption = scram-sha-256`). The Hive Metastore JDBC driver (postgresql-x.x.jar) does not support this authentication method.

## Root Cause
The init script creates the `hive` user without explicitly setting password encryption to `md5`:
```sql
CREATE USER hive WITH PASSWORD 'hive123';
```

When `password_encryption = scram-sha-256` (default in PG 14+), the password is stored in SCRAM format, which the old JDBC driver cannot authenticate against.

## Solution
Modify the PostgreSQL init ConfigMap to:
1. Set `password_encryption = 'md5'` before creating users
2. Or use `ALTER SYSTEM` to persist the setting

## Files to Modify
- `charts/spark-base/templates/core/postgresql-configmap.yaml`

## Workaround (Manual)
```bash
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  env PGPASSWORD=postgres psql -U postgres -c "ALTER SYSTEM SET password_encryption = 'md5';"
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  env PGPASSWORD=postgres psql -U postgres -c "SELECT pg_reload_conf();"
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- \
  env PGPASSWORD=postgres psql -U postgres -c "SET password_encryption = 'md5'; CREATE USER hive WITH PASSWORD 'hive123';"
```

## Test Case
1. Deploy spark-infra chart
2. Verify Hive Metastore pod starts without CrashLoopBackOff
3. Verify Metastore can connect to PostgreSQL

## References
- PostgreSQL 14 Release Notes: SCRAM-SHA-256 is now default
- PostgreSQL JDBC Driver compatibility matrix
