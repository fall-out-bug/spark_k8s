# Image Versioning Strategy

## Tag Format

| Format | Example | Use |
|--------|---------|-----|
| Spark version | `4.1.0`, `3.5.7` | Primary tags, sync with Apache Spark |
| Patch | `4.1.0-1` | Rebuild with same Spark, different deps |
| `latest` | — | Not used; prefer explicit versions |

## Sync with Spark Versions

- **4.1.0** — Apache Spark 4.1.0
- **3.5.7** — Apache Spark 3.5.7 (when added)

## Deprecation Policy

- Old versions remain available for 6 months after next minor release
- Security patches: new patch tag (e.g. 4.1.0-2)
- Deprecation announced in CHANGELOG

## Override in Helm

```yaml
connect:
  image:
    repository: ghcr.io/fall-out-bug/spark-k8s-spark-custom
    tag: "4.1.0"  # Pin to specific version
```
