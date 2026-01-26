# ISSUE-031: Spark 4.1 MinIO secret "s3-credentials" not created

## Status
OPEN

## Severity
P0 - Blocks E2E tests

## Description

When deploying Spark 4.1 chart with MinIO enabled, the `s3-credentials` secret is not automatically created. This causes all MinIO pods to fail with:

```
Error: secret "s3-credentials" not found
```

The MinIO deployment references this secret in environment variables:
- `MINIO_ROOT_USER` from `s3-credentials/access-key`
- `MINIO_ROOT_PASSWORD` from `s3-credentials/secret-key`

## Error Message

```
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Warning  Failed     71s (x12 over 3m27s)  kubelet            spec.containers{minio}: Error: secret "s3-credentials" not found
```

## Reproduction

```bash
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set spark-base.enabled=true \
  --set spark-base.minio.enabled=true \
  --set spark-base.postgresql.enabled=false
```

Then check pods:
```bash
kubectl get pods -n spark
kubectl describe pod/minio-xxx -n spark
```

## Root Cause

The spark-base MinIO template (charts/spark-base/templates/minio.yaml) references the `s3-credentials` secret:

```yaml
env:
- name: MINIO_ROOT_USER
  valueFrom:
    secretKeyRef:
      name: s3-credentials
      key: access-key
- name: MINIO_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: s3-credentials
      key: secret-key
```

However, the spark-base chart does NOT include a Secret resource definition to create this secret automatically.

The Spark 3.5 charts handle this differently - they have a mechanism to create S3 credentials.

## Solution

**Option 1: Auto-create secret in spark-base**

Add a Secret resource definition in `charts/spark-base/templates/minio.yaml`:

```yaml
{{- if not .Values.s3.existingSecret }}
apiVersion: v1
kind: Secret
metadata:
  name: s3-credentials
type: Opaque
stringData:
  access-key: {{ .Values.s3.accessKey | default "minioadmin" }}
  secret-key: {{ .Values.s3.secretKey | default "minioadmin" }}
{{- end }}
```

Add to values.yaml:
```yaml
s3:
  accessKey: "minioadmin"
  secretKey: "minioadmin"
  existingSecret: ""  # Set to use existing secret
```

**Option 2: Create secret in install script**

Update E2E test scripts to create the secret before installing:

```bash
kubectl create secret generic s3-credentials \
  -n spark \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key=minioadmin
```

**Option 3: Make secret optional**

Update MinIO deployment to use default values if secret doesn't exist (not recommended for production).

## Impact

- Blocks all Spark 4.1 deployments with MinIO
- Affects E2E tests
- Users must manually create secret before deployment

## Related

- ISSUE-030: Spark 4.1 MinIO label "N/A" error
- Spark 4.1 chart validation
- MinIO deployment templates
