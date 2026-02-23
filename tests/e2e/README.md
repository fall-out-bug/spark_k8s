# E2E Tests with Real K8s Deployment

## Overview

This guide explains how to run **real E2E tests** that:
1. Deploy Spark to a real Kubernetes cluster
2. Run actual Spark jobs
3. Test GPU workloads (if GPU nodes available)
4. Test Iceberg ACID operations (if S3/MinIO available)

## Prerequisites

### Option 1: Minikube (Recommended for local testing)

```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start with enough resources
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable GPU (if you have GPU on Linux)
minikube start --driver=nvidia --container-runtime=docker
```

### Option 2: Kind (Lightweight)

```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name spark-e2e
```

### Option 3: GKE/Cloud (Production-like)

```bash
# Configure kubectl for your cloud cluster
gcloud container clusters get-credentials <cluster-name> --region <region>
```

### Common Requirements

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | get_helm-3

# Verify
kubectl version --client
helm version
```

## Running E2E Tests

### Quick Start (Basic Tests Only)

```bash
# Run basic deployment and simple job
./scripts/run-e2e-tests.sh

# Or use pytest directly
python -m pytest tests/e2e/test_real_k8s_deployment.py::TestRealK8sDeployment -v -s
```

### With GPU Tests

```bash
# Requires GPU nodes in cluster
./scripts/run-e2e-tests.sh --gpu

# Or skip GPU if no nodes available
./scripts/run-e2e-tests.sh --skip-gpu
```

### With Iceberg Tests

```bash
# Requires S3/MinIO for data storage
./scripts/run-e2e-tests.sh --iceberg
```

### Full Matrix (All Tests)

```bash
# Run everything
./scripts/run-e2e-tests.sh --all
```

## What Gets Tested

### 1. Basic Deployment Test

- ✅ Helm install of Spark Connect
- ✅ Pods reach Ready state
- ✅ Spark Connect server accepts connections
- ✅ Simple Spark job (pi calculation) completes

### 2. GPU Workload Test

- ✅ GPU preset deployment
- ✅ GPU resources allocated to pods
- ✅ RAPIDS configuration active
- ✅ Spark job using GPU (cuDF) completes

**Expected output:**
```
GPU_JOB_SUCCESS
```

### 3. Iceberg Workload Test

- ✅ Iceberg preset deployment
- ✅ MinIO for S3-compatible storage
- ✅ Database and table creation
- ✅ INSERT (write data)
- ✅ SELECT (read data)
- ✅ UPDATE (ACID transaction)
- ✅ DELETE (ACID transaction)

**Expected output:**
```
ICEBERG_JOB_SUCCESS
```

### 4. Combined GPU + Iceberg Test

- ✅ Both GPU and Iceberg presets applied
- ✅ GPU-accelerated Iceberg operations
- ✅ End-to-end data pipeline

## Troubleshooting

### Minikube Issues

```bash
# Check status
minikube status

# View logs
minikube logs

# Increase resources
minikube stop
minikube start --cpus=6 --memory=12288

# Delete and recreate
minikube delete
minikube start
```

### Pod Issues

```bash
# Check pods
kubectl get pods -n spark-e2e-test

# Describe pod
kubectl describe pod <pod-name> -n spark-e2e-test

# View logs
kubectl logs <pod-name> -n spark-e2e-test
kubectl logs <pod-name> -c spark-connect -n spark-e2e-test

# Exec into pod
kubectl exec -it <pod-name> -n spark-e2e-test -- /bin/bash
```

### GPU Issues

```bash
# Check for GPU nodes
kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}'

# Check GPU in pods
kubectl describe pod <pod-name> -n spark-e2e-test | grep nvidia.com/gpu

# Check NVIDIA device plugin
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds
```

### MinIO/Storage Issues

```bash
# Check MinIO pod
kubectl get pods -n spark-e2e-test -l app=minio

# Port forward to MinIO console
kubectl port-forward -n spark-e2e-test svc/minio 9000:9000 9001:9001

# Access at http://localhost:9000
# Username: minioadmin
# Password: minioadmin
```

## Cleanup

```bash
# The script automatically cleans up, but manual cleanup:

# Uninstall releases
helm uninstall spark-e2e-dev -n spark-e2e-test
helm uninstall spark-e2e-gpu -n spark-e2e-test
helm uninstall spark-e2e-iceberg -n spark-e2e-test
helm uninstall minio -n spark-e2e-test

# Delete namespace
kubectl delete namespace spark-e2e-test
```

## CI/CD Integration

The E2E tests run automatically in GitHub Actions:

- **Basic tests** - On every PR to `dev` branch
- **GPU tests** - On PRs with `gpu` label (requires GPU runner)
- **Iceberg tests** - On every push to `dev`
- **Full matrix** - On merge to `main`

### Manual Trigger

```bash
# Via GitHub UI: Actions → E2E Tests → Run workflow

# Via gh CLI
gh workflow run e2e-tests.yml --repo fall-out-bug/spark_k8s
```

## Expected Test Times

| Test | Time (min) |
|------|-------------|
| Basic deployment | 5-10 |
| GPU workload | 10-15 |
| Iceberg workload | 10-15 |
| Combined | 15-20 |
| **Total (all)** | **30-45** |

## Success Criteria

✅ All Spark pods reach Ready state
✅ Spark Connect accepts connections
✅ Jobs complete without errors
✅ GPU resources allocated (if GPU available)
✅ Iceberg ACID operations work (if storage available)
