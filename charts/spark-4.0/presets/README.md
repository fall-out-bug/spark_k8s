# Spark 4.0 Presets

Values overlays for common deployment scenarios.

| Preset | Use Case |
|--------|----------|
| [dev.yaml](dev.yaml) | Local development (Minikube, Kind). MinIO + PostgreSQL + all components. |
| [prod.yaml](prod.yaml) | Production. HA Connect replicas, external S3/PostgreSQL. |

## Usage

```bash
# Dev (local)
helm template my-spark charts/spark-4.0 -f charts/spark-4.0/presets/dev.yaml

# Production
helm template my-spark charts/spark-4.0 -f charts/spark-4.0/presets/prod.yaml
```

## Shared Overlay

For multi-version deployment (Spark 3.5 + 4.0), see:
- [ADR-0004: Modular Chart Architecture](../../../docs/adr/ADR-0004-spark-410-modular-architecture.md)
- [ADR-0007: Version-Specific Metastores](../../../docs/adr/ADR-0007-version-specific-metastores.md)
- `charts/spark-3.5/presets/shared-infrastructure.yaml` (pattern for shared MinIO/PostgreSQL)
