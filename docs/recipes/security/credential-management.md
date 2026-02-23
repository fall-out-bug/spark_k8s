# Credential Management

This guide explains how to securely manage credentials in Spark K8s deployments.

## Overview

Default `values.yaml` files do **NOT** contain hardcoded credentials. All passwords and secrets must be provided at deploy time.

## Quick Start

### Option 1: Helm --set (Development)

```bash
helm install spark charts/spark-4.1 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set global.postgresql.password=hive123
```

### Option 2: values-override.yaml (Development)

Create a local file (DO NOT commit):

```yaml
# values-secrets.yaml (add to .gitignore)
global:
  s3:
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
  postgresql:
    password: "your-db-password"
```

```bash
helm install spark charts/spark-4.1 -f values-secrets.yaml
```

### Option 3: Kubernetes Secrets (Production)

Create a secret manually:

```bash
kubectl create secret generic spark-secrets \
  --from-literal=s3-access-key=your-access-key \
  --from-literal=s3-secret-key=your-secret-key \
  --from-literal=postgresql-password=your-db-password \
  -n spark-operations
```

Reference in values:

```yaml
global:
  s3:
    existingSecret: "spark-secrets"
  postgresql:
    existingSecret: "spark-secrets"
```

### Option 4: ExternalSecrets (Recommended for Production)

ExternalSecrets automatically syncs secrets from external secret stores.

#### AWS Secrets Manager

```yaml
secrets:
  externalSecrets:
    enabled: true
    provider: "aws"
    region: "us-east-1"
    prefix: "spark"
    aws:
      iamRole: "arn:aws:iam::123456789:role/spark-secrets-role"
```

Create secrets in AWS:

```bash
aws secretsmanager create-secret \
  --name spark/s3-credentials \
  --secret-string '{"accessKey":"xxx","secretKey":"yyy"}'
```

#### HashiCorp Vault

```yaml
secrets:
  vault:
    enabled: true
    address: "https://vault.example.com"
    path: "secret/data/spark"
    role: "spark-role"
```

### Option 5: SealedSecrets (GitOps)

```bash
# Create SealedSecret
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
```

## Required Credentials

| Secret | Keys | Description |
|--------|------|-------------|
| `global.s3` | `accessKey`, `secretKey` | MinIO/S3 credentials |
| `global.postgresql` | `password` | Hive Metastore DB |
| `hiveMetastore.postgresql` | `password` | Metastore DB (alternative) |
| `postgresql.auth` | `password` | Embedded PostgreSQL |

## Environment-Specific Configurations

### Development

```bash
# Quick dev setup with defaults (NOT for production!)
helm install spark charts/spark-4.1 \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set global.postgresql.password=dev123
```

### Staging

Use ExternalSecrets with staging secret store:

```yaml
secrets:
  externalSecrets:
    enabled: true
    provider: "aws"
    prefix: "spark/staging"
```

### Production

1. Use ExternalSecrets or Vault
2. Enable audit logging
3. Rotate credentials regularly
4. Use IAM roles (AWS) or Workload Identity (GKE)

## .env.example

Create `.env.example` in repo root (safe to commit):

```bash
# S3/MinIO Credentials
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_ENDPOINT=http://minio:9000

# PostgreSQL (Hive Metastore)
POSTGRESQL_HOST=postgresql-metastore
POSTGRESQL_PORT=5432
POSTGRESQL_USER=hive
POSTGRESQL_PASSWORD=
POSTGRESQL_DATABASE=metastore

# Airflow (if enabled)
AIRFLOW_FERNET_KEY=
AIRFLOW_SECRET_KEY=

# MLflow (if enabled)
MLFLOW_TRACKING_URI=
```

## Security Checklist

- [ ] No hardcoded credentials in values.yaml
- [ ] `.env` and `values-secrets.yaml` in `.gitignore`
- [ ] ExternalSecrets or Vault configured for production
- [ ] IAM roles / Workload Identity for cloud deployments
- [ ] Regular credential rotation schedule
- [ ] Audit logging enabled

## Troubleshooting

### Error: "S3 credentials not configured"

```bash
# Verify secrets exist
kubectl get secrets -n spark-operations

# Check secret content
kubectl describe secret spark-secrets -n spark-operations
```

### Error: "PostgreSQL authentication failed"

```bash
# Test connection
kubectl run pg-test --rm -it --image=postgres:15 -- \
  psql "postgresql://hive:password@postgresql-metastore:5432/metastore"
```

## References

- [ExternalSecrets Operator](https://external-secrets.io/)
- [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
