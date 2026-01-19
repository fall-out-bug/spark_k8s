# Spark Operator Guide (Spark 4.1.0)

This guide covers installing Spark Operator and running SparkApplications
for Spark 4.1.0, with examples, best practices, and troubleshooting.

## Overview

Spark Operator enables declarative management of Spark applications via
Kubernetes CRDs.

Benefits:

- GitOps-friendly job definitions
- Automatic submission, monitoring, cleanup
- Webhook-based validation
- TTL cleanup for completed jobs

## Installation

### 1) Deploy Operator

```bash
helm install spark-operator charts/spark-operator \
  --set sparkJobNamespace=default \
  --set webhook.enable=true \
  --wait
```

### 2) Verify CRDs

```bash
kubectl get crd sparkapplications.sparkoperator.k8s.io
```

## SparkApplication CRD

Basic structure:

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: my-spark-job
spec:
  type: Scala | Python | Java | R
  mode: cluster
  image: "spark-custom:4.1.0"
  sparkVersion: "4.1.0"
  mainClass: <class-name>  # Scala/Java
  mainApplicationFile: <file-path>
  arguments: [...]
  sparkConf:
    spark.eventLog.enabled: "true"
  driver:
    cores: 1
    memory: "512m"
    serviceAccount: spark-41
  executor:
    cores: 1
    instances: 2
    memory: "512m"
  restartPolicy:
    type: OnFailure | Never | Always
```

## Examples

### Example 1: Simple Batch Job

File: `docs/examples/spark-pi-basic.yaml`

```bash
kubectl apply -f docs/examples/spark-pi-basic.yaml

# Check status
kubectl get sparkapplication spark-pi

# View driver logs
kubectl logs spark-pi-driver
```

### Example 2: Scheduled Job

File: `docs/examples/spark-pi-scheduled.yaml`

```bash
kubectl apply -f docs/examples/spark-pi-scheduled.yaml
kubectl get scheduledsparkapplication spark-pi-cron
```

### Example 3: PySpark with Celeborn

File: `docs/examples/spark-pyspark-celeborn.yaml`

```bash
kubectl apply -f docs/examples/spark-pyspark-celeborn.yaml
kubectl get sparkapplication pyspark-celeborn
```

## Best Practices

### Resource Management

- Set explicit `cores` and `memory`.
- Prefer fixed `executor.instances` for predictable costs.

### Image Management

- Pin image tags (never use `:latest`).
- Use `imagePullSecrets` for private registries.

### Logging & Monitoring

- Always enable event logs:
  `spark.eventLog.enabled=true`
- Use History Server for completed jobs.

### Cleanup (TTL)

```yaml
spec:
  restartPolicy:
    type: Never
    onFailureRetries: 3
    onFailureRetryInterval: 10
    onSubmissionFailureRetries: 1
  timeToLiveSeconds: 86400
```

## Troubleshooting

### SparkApplication stuck in "NEW"

Cause: Operator not running or webhook misconfigured.

```bash
kubectl logs -l app=spark-operator
kubectl get validatingwebhookconfigurations
```

### Driver pod fails with "403 Forbidden"

Cause: Missing RBAC permissions.

```bash
kubectl describe role spark-role
```

### Executors not created

Cause: Insufficient cluster resources.

```bash
kubectl describe node | grep -A5 "Allocated resources"
```

## Integration Tests

Run the integration suite:

- `scripts/test-spark-41-integrations.sh`

## References

- [Spark Operator Docs](https://googlecloudplatform.github.io/spark-on-k8s-operator/)
- [SparkApplication API Spec](https://github.com/googlecloudplatform/spark-on-k8s-operator/blob/master/docs/api-docs.md)
