# S3 Credentials Secret Missing

**Related Issues:** ISSUE-031

## Symptoms

```
Events:
  Type     Reason     Age   From    Message
  ----     ------     ----  ----    -------
  Warning  Failed     30s   kubelet  spec.containers{minio}: Error: secret "s3-credentials" not found
```

MinIO pods fail to start with error about missing `s3-credentials` secret.

## Diagnosis

```bash
# Проверить существует ли secret
kubectl get secret s3-credentials -n <namespace>

# Проверить какие секреты есть в namespace
kubectl get secrets -n <namespace>

# Посмотреть на ошибки pod
kubectl describe pod -n <namespace> <minio-pod>
```

## Root Cause

Spark Connect/MinIO deployment references `s3-credentials` secret for:
- MINIO_ROOT_USER
- MINIO_ROOT_PASSWORD

But the secret is not automatically created by the chart.

## Solution

### Автоматическое создание (Spark 4.1)

В `charts/spark-base/values.yaml`:

```yaml
s3:
  accessKey: "minioadmin"
  secretKey: "minioadmin"
  endpoint: ""
  existingSecret: ""  # Оставить пустым для автосоздания
```

Secret будет создан автоматически при установке.

### Ручное создание

```bash
kubectl create secret generic s3-credentials \
  -n <namespace> \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key=minioadmin

# Или использовать существующий secret
helm upgrade spark charts/spark-4.1 -n <namespace> \
  --set spark-base.s3.existingSecret=my-s3-secret \
  --reuse-values
```

### Использование внешних credentials

Для AWS S3:

```bash
kubectl create secret generic s3-credentials \
  -n <namespace> \
  --from-literal=access-key=$AWS_ACCESS_KEY_ID \
  --from-literal=secret-key=$AWS_SECRET_ACCESS_KEY
```

## Verification

```bash
# Проверить что secret создан
kubectl get secret s3-credentials -n <namespace> -o yaml

# Проверить что pod может его использовать
kubectl get pod -n <namespace> -l app=minio

# Подождать пока MinIO станет ready
kubectl wait --for=condition=ready pod -n <namespace> -l app=minio --timeout=120s
```

## Related

- ISSUE-031: Spark base MinIO secret missing
- s3-connection-failed.md: Проблемы с S3 подключением
