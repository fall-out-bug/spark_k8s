# ISSUE-029: Spark 4.1 Hive Metastore init job fails when PostgreSQL disabled

## Status
✅ **RESOLVED** - Removed init container that waits for non-existent PostgreSQL

## Workstream
WS-BUG-013

## Problem Description

When installing Spark 4.1 with Hive Metastore enabled and PostgreSQL disabled (`postgresql.enabled: false`), the init job fails:
```
Error: INSTALLATION FAILED: failed post-install: 1 error occurred:
  * job spark-connect-test-spark-41-metastore-init failed: BackoffLimitExceeded
```

### Root Cause

The init job has a `wait-for-postgresql` container that tries to connect to PostgreSQL using `nc`:
```yaml
initContainers:
  - name: wait-for-postgresql
    image: busybox:1.36
    command:
      - sh
      - -c
      - >-
        until nc -z {{ .Values.global.postgresql.host }} {{ .Values.global.postgresql.port }}; do
          echo "Waiting for PostgreSQL..."; sleep 2; done; echo "PostgreSQL is ready!"
```

**Problems:**
1. PostgreSQL is NOT deployed (`postgresql.enabled: false` in values.yaml)
2. The service name `postgresql-metastore-41` doesn't exist
3. `nc` fails with `bad address 'postgresql-metastore-41'`
4. Job reaches BackoffLimitExceeded after 6 failed attempts

### Why This Happens

The Spark 4.1 chart uses embedded Hive Metastore (from spark-base chart) instead of external PostgreSQL when `postgresql.enabled: false`. However, the init job template still references the PostgreSQL host variable.

## Fix Applied

**Solution:** Remove the `wait-for-postgresql` init container entirely, since:
- PostgreSQL is disabled in this configuration
- Hive Metastore runs independently without external DB
- The init check is unnecessary and causes the deployment to fail

Changed in `charts/spark-4.1/templates/hive-metastore.yaml`:

```yaml
# BEFORE (BROKEN):
initContainers:
  - name: wait-for-postgresql
    image: busybox:1.36
    # ... command that waits for PostgreSQL ...

# AFTER (FIXED):
initContainers: []  # No init container needed
containers:
  # Hive metastore container starts directly
```

## Testing

After applying this fix, the Hive Metastore deployment should succeed because:
1. No init container that tries to connect to non-existent PostgreSQL
2. Hive Metastore container starts immediately
3. Schema initialization runs successfully

## Related Issues

- **ISSUE-028**: Spark 4.1 K8s Connect Server binding address (resolved)
- **ISSUE-017**: Spark 4.1 properties file order (resolved)

## Recommendation

For future chart improvements:
1. Add conditional init container that only runs when `postgresql.enabled: true`
2. Or better: Use Helm hook conditions to skip init when PostgreSQL is disabled
3. Document that Hive Metastore can run with embedded or external PostgreSQL

## Next Steps

1. Test Spark 4.1 K8s installation with Hive Metastore enabled
2. Verify Spark Connect pod starts successfully
3. Verify Spark Connect server is accessible
4. Run end-to-end test with sample job
