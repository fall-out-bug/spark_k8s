# Spark K8s Compatibility Matrix

Auto-generated compatibility matrix for Spark versions and Kubernetes platforms.

## Overview

This matrix shows tested combinations of Spark, Kubernetes, and Python versions.

## Test Matrix

| Spark Version | Python 3.8 | Python 3.9 | Python 3.10 | Python 3.11 |
|---------------|------------|------------|-------------|-------------|
| 3.5.7 | ✅ | ✅ | ✅ | ⚠️ |
| 3.5-latest | ✅ | ✅ | ✅ | ✅ |
| 4.1.0 | ❌ | ❌ | ✅ | ✅ |
| 4.1-latest | ❌ | ❌ | ✅ | ✅ |

Legend:
- ✅ Fully tested and supported
- ⚠️ Supported with caveats
- ❌ Not supported

## Kubernetes Platforms

| Platform | 3.5.7 | 3.5-latest | 4.1.0 | 4.1-latest |
|----------|-------|-------------|--------|-------------|
| Kubernetes 1.24 | ✅ | ✅ | ✅ | ✅ |
| Kubernetes 1.25 | ✅ | ✅ | ✅ | ✅ |
| Kubernetes 1.26 | ✅ | ✅ | ✅ | ✅ |
| Kubernetes 1.27 | ✅ | ✅ | ✅ | ✅ |
| Kubernetes 1.28 | ✅ | ✅ | ✅ | ✅ |
| Kubernetes 1.29 | ✅ | ✅ | ⚠️ | ⚠️ |

## Container Runtimes

| Runtime | 3.5.x | 4.1.x |
|---------|-------|-------|
| Docker | ✅ | ✅ |
| containerd | ✅ | ✅ |
| CRI-O | ✅ | ✅ |

## Breaking Changes

### Spark 4.0 → 4.1

- Removed: `spark.sql.caseSensitive` (default is now true)
- Changed: Default shuffle manager from sort to tungsten-sort
- Removed: Python 3.8 support

### Spark 3.5 → 4.0

- Removed: `spark.sql.legacy.allowNegativeScaleOfDecimal`
- Changed: DataFrameWriterV2 API
- Removed: Support for Scala 2.12

## Migration Guide

### 3.5 → 4.1

1. Update Python version to 3.10+
2. Review deprecated configs
3. Test shuffle performance
4. Verify schema evolution
5. Update UDFs for Pandas API changes

## Testing

Run compatibility tests:

```bash
# Test all versions
python tests/compatibility/test_matrix.py

# Test specific version
python tests/compatibility/test_spark_4_1.py
```
