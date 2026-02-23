# OpenShift Presets for Spark 3.5

This directory contains OpenShift-specific configuration presets for deploying Spark 3.5 on OpenShift clusters.

## Presets

### restricted.yaml

**Recommended for production use**

Configures Spark 3.5 with:
- Pod Security Standards (PSS) `restricted` profile
- Security Context Constraints (SCC) `restricted`
- OpenShift-specific UID ranges (1000000000+)
- External S3 and PostgreSQL (no embedded services)

**Usage:**
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/openshift/restricted.yaml \
  -n spark-openshift \
  --create-namespace
```

### anyuid.yaml

**For edge cases only**

Configures Spark 3.5 with:
- Pod Security Standards (PSS) **disabled** (anyuid SCC bypasses PSS)
- Security Context Constraints (SCC) `anyuid`
- OpenShift-specific UID ranges (1000000000+)
- External S3 and PostgreSQL (no embedded services)

**Warning:** Only use this preset when absolutely necessary (e.g., legacy workloads that require root access).

**Usage:**
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/openshift/anyuid.yaml \
  -n spark-openshift \
  --create-namespace
```

## Prerequisites

### Cluster Requirements

- OpenShift 4.x cluster
- SCC `restricted` available (for restricted.yaml)
- SCC `anyuid` available (for anyuid.yaml)

### External Services

Both presets require external services:

- **S3-compatible storage:** MinIO, AWS S3, Ceph Object Gateway, etc.
- **PostgreSQL:** For Hive Metastore

### Required Secrets

Create S3 credentials secret:
```bash
kubectl create secret generic s3-credentials \
  --from-literal=accessKey='YOUR_ACCESS_KEY' \
  --from-literal=secretKey='YOUR_SECRET_KEY' \
  -n spark-openshift
```

## Configuration

### External S3

Override the S3 endpoint:
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/openshift/restricted.yaml \
  --set global.s3.endpoint='https://s3.example.com' \
  -n spark-openshift
```

### External PostgreSQL

Override PostgreSQL connection:
```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/openshift/restricted.yaml \
  --set hiveMetastore.postgresql.host='postgresql.example.com' \
  --set hiveMetastore.postgresql.username='hive' \
  --set hiveMetastore.postgresql.password='hive123' \
  --set hiveMetastore.postgresql.database='metastore_spark35' \
  -n spark-openshift
```

## Verification

After deployment, verify SCC assignment:

```bash
# Check pod SCC annotation
kubectl get pod -n spark-openshift -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}'

# For restricted.yaml, should show: restricted
# For anyuid.yaml, should show: anyuid
```

## Troubleshooting

### Pod fails with "cannot assign capacity"

The SCC may not be available. Check available SCCs:
```bash
oc get scc
```

### Pod fails with "no matching pods"

Check the pod's security context:
```bash
oc describe pod <pod-name> -n spark-openshift
```

### PSS labels not applied

Verify namespace labels:
```bash
kubectl get namespace spark-openshift -o yaml | grep pod-security
```

## Resources

- [OpenShift Security Context Constraints](https://docs.openshift.com/container-platform/4.13/authentication/managing-security-context-constraints.html)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
