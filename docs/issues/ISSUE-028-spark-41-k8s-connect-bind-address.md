# ISSUE-028: Spark 4.1 K8s Connect Server missing binding address configuration

## Status
✅ **RESOLVED** - Added `spark.connect.grpc.binding.address=0.0.0.0`

## Workstream
WS-BUG-013

## Problem Description

Spark 4.1 Connect Server in K8s mode was missing the explicit `spark.connect.grpc.binding.address` configuration, which could cause similar issues as ISSUE-027 in Spark 3.5.

### Evidence

While Spark 4.1 has been running successfully in some deployments, the configuration was incomplete:
- Missing: `spark.connect.grpc.binding.address`
- Present: `spark.connect.grpc.binding.port=15002`
- Comparison with Spark 3.5 fix showed this was needed for consistent behavior

### Root Cause

The `spark.connect.grpc.binding.address` property explicitly tells the Spark Connect Server which network interface to bind to. Without it:
- Default behavior may vary between Spark versions
- Inconsistent behavior across different deployment modes
- Potential for health probe failures or connection issues

## Fix Applied

Added explicit binding address in `charts/spark-4.1/templates/spark-connect-configmap.yaml`:

```yaml
spark.connect.grpc.binding.address=0.0.0.0
spark.connect.grpc.binding.port=15002
```

### Why This Fix

1. **Explicit Configuration**: Makes the binding address clear and explicit
2. **Consistency**: Matches the fix applied to Spark 3.5 in ISSUE-027
3. **Best Practice**: Explicitly configuring network bindings is recommended for production deployments

## Related Issues

- **ISSUE-027**: Spark 3.5 K8s Connect Server binds to incorrect IP (resolved)
- **ISSUE-017**: Spark 4.1 properties file order (resolved)
- **ISSUE-026**: Spark 3.5 K8s driver host FQDN (resolved)

## Testing

1. ✅ Template validation passed (helm template)
2. ⏳ Full E2E test pending

## Next Steps

1. Deploy Spark 4.1 K8s mode to test namespace
2. Verify health probes pass
3. Run full E2E matrix test
