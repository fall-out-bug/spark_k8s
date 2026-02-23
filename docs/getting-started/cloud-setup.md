# Cloud Setup: EKS, GKE, AKS, OpenShift

Deploy Spark to your favorite cloud platform in 15 minutes.

## Prerequisites

- Cloud account (AWS/GCP/Azure/RedHat)
- kubectl configured for your cluster
- helm v3.12+

## AWS EKS

### 1. Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name spark-eks
```

### 2. Create Namespace

```bash
kubectl create namespace spark
```

### 3. Deploy Spark

```bash
helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s
helm install spark spark-k8s/spark-connect \
  --namespace spark \
  --set spark.connect.mode.k8s.backend=kubernetes
```

### 4. Verify

```bash
kubectl get pods -n spark
```

---

## Google Cloud GKE

### 1. Get Credentials

```bash
gcloud container clusters get-credentials spark-gke \
    --region us-central1 \
    --zone us-central1-a
```

### 2. Deploy Spark

```bash
helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s
helm install spark spark-k8s/spark-connect \
  --set spark.connect.mode.k8s.backend=kubernetes
```

---

## Azure AKS

### 1. Get Credentials

```bash
az aks get-credentials --resource-group spark-rg --name spark-aks
```

### 2. Deploy Spark

```bash
helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s
helm install spark spark-k8s/spark-connect \
  --set spark.connect.mode.k8s.backend=kubernetes
```

---

## OpenShift

### 1. Login to OpenShift

```bash
oc login https://api.sandbox.x8s6g4.cluster.x8s6g4.contrail-plane.com:6443
```

### 2. Create Project

```bash
oc new-project spark
```

### 3. Deploy Spark

```bash
helm repo add spark-k8s-openshift https://fall-out-bug.github.io/spark_k8s-openshift
helm install spark spark-k8s-openshift/spark-connect \
  --namespace spark \
  --set securityContext.enabled=false
```

> **Note:** OpenShift requires additional security context configuration. See [OpenShift Guide](../recipes/security/openshift-hardening.md) for PSS restricted setup.

---

## Production Considerations

### Resource Limits

```yaml
# Recommended for production
resources:
  limits:
    memory: "8Gi"
    cpu: "4"
  requests:
    memory: "4Gi"
    cpu: "2"
```

### Service Accounts

```yaml
# For production workloads
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/SparkRole
```

### Storage

```yaml
# For S3 on EKS
hadoop.fs.s3a.aws.credentials.provider: com.amazonaws.auth.InstanceProfileCredentialsProvider
```

---

## Next Steps

- [Choose Your Backend](choose-backend.md) — K8s vs Standalone vs Operator
- [Production Checklist](../operations/production-checklist.md) — Before going live

---

**Time:** 15 minutes
**Difficulty:** Intermediate
**Last Updated:** 2026-02-04
