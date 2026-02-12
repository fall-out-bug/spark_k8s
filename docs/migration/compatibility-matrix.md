# Compatibility Matrix

This document provides a comprehensive compatibility matrix for Spark on Kubernetes.

## Spark Version Support

| Spark Version | Release Date | EOL Date | Kubernetes Tested | Python | Scala |
|--------------|-------------|----------|-------------------|--------|-------|
| 3.3.x | Aug 2022 | Aug 2024 | 1.24 - 1.28 | 3.8-3.11 | 2.12 |
| 3.4.x | Jun 2023 | Jun 2025 | 1.25 - 1.29 | 3.8-3.11 | 2.12 |
| 3.5.x | Jan 2024 | Jan 2026 | 1.26 - 1.29 | 3.9-3.12 | 2.12, 2.13 |
| 4.0.x | Apr 2024 | Apr 2026 | 1.27 - 1.30 | 3.10-3.12 | 2.13 |
| 4.1.x | Nov 2024 | Nov 2026 | 1.28 - 1.31 | 3.10-3.13 | 2.13 |

## Kubernetes Version Compatibility

| K8s Version | Spark 3.3.x | Spark 3.4.x | Spark 3.5.x | Spark 4.0.x | Spark 4.1.x |
|-------------|------------|------------|------------|------------|------------|
| 1.24 | ✓ | ✓ | ⚠️ | ❌ | ❌ |
| 1.25 | ✓ | ✓ | ✓ | ⚠️ | ❌ |
| 1.26 | ✓ | ✓ | ✓ | ✓ | ⚠️ |
| 1.27 | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1.28 | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1.29 | ⚠️ | ✓ | ✓ | ✓ | ✓ |
| 1.30 | ❌ | ⚠️ | ✓ | ✓ | ✓ |
| 1.31 | ❌ | ❌ | ⚠️ | ✓ | ✓ |

Legend:
- ✓: Fully supported and tested
- ⚠️: Compatible with caveats
- ❌: Not compatible

## Spark Operator Compatibility

| Spark Operator | Spark 3.3.x | Spark 3.4.x | Spark 3.5.x | Spark 4.0.x | Spark 4.1.x |
|----------------|------------|------------|------------|------------|------------|
| v1beta2-1.4.x | ✓ | ✓ | ❌ | ❌ | ❌ |
| v1beta2-1.5.x | ✓ | ✓ | ✓ | ❌ | ❌ |
| v1beta2-1.6.x | ⚠️ | ✓ | ✓ | ⚠️ | ❌ |
| v1beta2-1.7.x | ❌ | ⚠️ | ✓ | ✓ | ⚠️ |
| v1beta2-1.8.x | ❌ | ❌ | ⚠️ | ✓ | ✓ |

## Python Version Support

| Python | Spark 3.3.x | Spark 3.4.x | Spark 3.5.x | Spark 4.0.x | Spark 4.1.x |
|--------|------------|------------|------------|------------|------------|
| 3.8 | ✓ | ✓ | ⚠️ | ❌ | ❌ |
| 3.9 | ✓ | ✓ | ✓ | ⚠️ | ❌ |
| 3.10 | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3.11 | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3.12 | ❌ | ⚠️ | ✓ | ✓ | ✓ |
| 3.13 | ❌ | ❌ | ⚠️ | ⚠️ | ✓ |

## Storage System Compatibility

| Storage | Spark 3.3.x | Spark 3.4.x | Spark 3.5.x | Spark 4.0.x | Spark 4.1.x | Notes |
|---------|------------|------------|------------|------------|------------|-------|
| S3 | ✓ | ✓ | ✓ | ✓ | ✓ | Use S3A connector |
| GCS | ✓ | ✓ | ✓ | ✓ | ✓ | Use GCS connector |
| Azure Data Lake | ✓ | ✓ | ✓ | ✓ | ✓ | Use WASB/ABFS |
| HDFS | ✓ | ✓ | ✓ | ⚠️ | ⚠️ | Persistent volumes |
| Delta Lake | ✓ | ✓ | ✓ | ✓ | ✓ | All versions supported |
| Iceberg | ⚠️ | ✓ | ✓ | ✓ | ✓ | 3.3+ has limited support |
| Hudi | ✓ | ✓ | ✓ | ✓ | ✓ | All versions supported |

## Catalog Compatibility

| Catalog | Spark 3.3.x | Spark 3.4.x | Spark 3.5.x | Spark 4.0.x | Spark 4.1.x |
|---------|------------|------------|------------|------------|------------|
| Hive Metastore | ✓ | ✓ | ✓ | ✓ | ✓ |
| AWS Glue | ✓ | ✓ | ✓ | ✓ | ✓ |
| Unity Catalog | ⚠️ | ⚠️ | ✓ | ✓ | ✓ |
| AWS Lake Formation | ⚠️ | ✓ | ✓ | ✓ | ✓ |
| Google Catalog | ❌ | ⚠️ | ⚠️ | ✓ | ✓ |
| Azure Purview | ⚠️ | ✓ | ✓ | ✓ | ✓ |

## Cloud Provider Compatibility

| Cloud | Managed Service | Spark Operator Support | Notes |
|-------|----------------|----------------------|-------|
| AWS | EKS | Full | IRSA for S3 access |
| GCP | GKE | Full | Workload Identity for GCS |
| Azure | AKS | Full | AAD Pod Identity for ADLS |
| Other | Self-managed | Full | Requires manual config |

## Feature Compatibility Matrix

### Core Features

| Feature | 3.3.x | 3.4.x | 3.5.x | 4.0.x | 4.1.x |
|---------|-------|-------|-------|-------|-------|
| AQE | ✓ | ✓ | ✓ | ✓ | ✓ |
| Adaptive Skew Join | ⚠️ | ✓ | ✓ | ✓ | ✓ |
| Python UDF | ✓ | ✓ | ✓ | ✓ | ✓ |
| Scala UDF | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pandas UDF | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ | ✓ |
| Structured Streaming | ✓ | ✓ | ✓ | ✓ | ✓ |
| MLlib | ✓ | ✓ | ✓ | ✓ | ✓ |
| GraphX | ✓ | ✓ | ✓ | ❌ | ❌ |
| Spark Connect | ❌ | ❌ | ✓ | ✓ | ✓ |

### Kubernetes Features

| Feature | 3.3.x | 3.4.x | 3.5.x | 4.0.x | 4.1.x |
|---------|-------|-------|-------|-------|-------|
| Dynamic Allocation | ✓ | ✓ | ✓ | ✓ | ✓ |
| Shuffle Service | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pod Template | ✓ | ✓ | ✓ | ✓ | ✓ |
| Driver/Executor Pods | ✓ | ✓ | ✓ | ✓ | ✓ |
| Local Storage | ✓ | ✓ | ✓ | ✓ | ✓ |
| PVCs | ✓ | ✓ | ✓ | ✓ | ✓ |
| Node Selector | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tolerations | ✓ | ✓ | ✓ | ✓ | ✓ |
| Affinity Rules | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resource Requests | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resource Limits | ✓ | ✓ | ✓ | ✓ | ✓ |

## Upgrade Recommendations

### Current Stable Combinations

| K8s | Spark | Operator | Python | Scala |
|------|-------|-----------|--------|-------|
| 1.29 | 3.5.2 | 1.7.0 | 3.11 | 2.13 |
| 1.29 | 4.1.0 | 1.8.0 | 3.12 | 2.13 |

### Production Recommended

| Environment | K8s | Spark | Operator |
|-------------|------|-------|----------|
| Production (stable) | 1.28 | 3.5.2 | 1.7.0 |
| Production (latest) | 1.29 | 4.1.0 | 1.8.0 |
| Development | 1.30 | 4.1.0 | 1.8.0 |

### Upgrade Paths

**Safe to upgrade:**
- 3.3.x → 3.5.x
- 3.4.x → 3.5.x
- 3.5.x → 4.0.x (requires testing)
- 4.0.x → 4.1.x

**Requires migration:**
- 3.3.x → 4.0.x
- 3.4.x → 4.0.x
- 3.5.x → 4.1.x (minor changes)

## Breaking Changes

### 3.5.x Breaking Changes
- `spark.sql.caseSensitive` default changed
- Python 3.8 support deprecated

### 4.0.x Breaking Changes
- Python 3.8 and 3.9 removed
- Scala 2.12 removed
- Legacy SQL configs removed

### 4.1.x Breaking Changes
- Kubernetes API older than 1.28 not supported
- Some deprecated features removed

## Support Timeline

```
Current: Feb 2026

3.3.x  ████████████░░░░░░░░ (EOL: Aug 2024) ❌
3.4.x  ████████████████████░░ (EOL: Jun 2025) ⚠️
3.5.x  ████████████████████████ (EOL: Jan 2026) ✓
4.0.x  ██████████████████████████ (EOL: Apr 2026) ✓
4.1.x  ██████████████████████████ (EOL: Nov 2026) ✓
```

## Related

- [Version Upgrade Guide](./version-upgrade.md)
- [Platform Migration Guides](./index.md)
