# Spark 4.1.0 Production Guide

This guide targets DataOps/Platform Engineers deploying Spark 4.1.0 in production.
It focuses on sizing, security, HA, storage, observability, and troubleshooting.

## Overview

Recommended baseline:

- Spark Connect server (3 replicas) with dynamic allocation
- External S3 for event logs and data
- External PostgreSQL for Hive Metastore
- History Server enabled
- Jupyter disabled (use dedicated JupyterHub)

## Resource Sizing

### Spark Connect

- **Replicas:** 3 (HA)
- **Requests:** 2 CPU / 4Gi
- **Limits:** 4 CPU / 8Gi

Executors (dynamic allocation):

- **Min/Max:** 2 / 50
- **Requests:** 2 CPU / 4Gi
- **Limits:** 4 CPU / 8Gi

### Hive Metastore

- **Requests:** 500m / 1Gi
- **Limits:** 2 CPU / 4Gi

### History Server

- **Requests:** 1 CPU / 2Gi
- **Limits:** 4 CPU / 8Gi
- Event log dir: `s3a://prod-spark-logs/4.1/events`

## Security (PSS Restricted)

Recommended settings:

- `security.podSecurityStandards=true`
- Run as non-root user (UID/GID 185)
- Drop all Linux capabilities
- `allowPrivilegeEscalation=false`
- `seccompProfile: RuntimeDefault`

RBAC:

- Spark Connect pods need permission to create executor pods.
- Use `rbac.create=true` and dedicated ServiceAccount.

Network:

- Prefer NetworkPolicies that allow:
  - Spark Connect → Kubernetes API
  - Spark Connect → S3 endpoint
  - Spark Connect → Hive Metastore
  - History Server → S3 endpoint

## High Availability

Spark Connect:

- Increase replicas to 3.
- Use readiness/liveness probes (already defined in chart).

Hive Metastore:

- Use external PostgreSQL with HA (managed service or primary/replica).

History Server:

- Event logs in S3; keep the server stateless.
- Optional: deploy multiple History Server replicas behind a Service.

## Storage

S3/MinIO:

- Use external S3 for production.
- Configure `global.s3.endpoint` and credentials via Secrets.
- Enable `pathStyleAccess` only if required by your S3 provider.

Event logs:

- Keep separate prefixes per version:
  - `s3a://prod-spark-logs/3.5/events`
  - `s3a://prod-spark-logs/4.1/events`

## Monitoring & Observability

Metrics:

- Spark Connect exposes metrics on port 4040/15002 (use sidecar or scrape via PodMonitor).
- History Server provides API on 18080.

Logging:

- Use centralized log collection (Fluent Bit / Vector).
- Keep Spark driver/executor logs accessible via Kubernetes logging.

## Troubleshooting

Common issues:

- **Executors not starting:** check RBAC and ServiceAccount.
- **History Server empty:** verify event log directory and S3 credentials.
- **Metastore errors:** verify PostgreSQL connectivity and DB name.
- **Jupyter disabled:** expected for production; use JupyterHub chart.

## Production Values Overlay

Use the provided overlay as a starting point:

```bash
helm upgrade --install spark-41 charts/spark-4.1 \
  -f docs/examples/values-spark-41-production.yaml
```

## Related Guides

- [Celeborn Integration](CELEBORN-GUIDE.md)
- [Spark Operator Guide](SPARK-OPERATOR-GUIDE.md)
