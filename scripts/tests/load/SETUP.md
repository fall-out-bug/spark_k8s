# Load Testing Setup Guide

Part of WS-013-11: CI/CD Integration & Documentation

## Prerequisites

### Required Tools

- **Docker**: Container runtime
- **Minikube**: Local Kubernetes cluster
- **kubectl**: Kubernetes CLI
- **helm**: Kubernetes package manager
- **Python 3.11+**: For test scripts
- **argo**: Argo Workflows CLI (optional, for workflow submission)

### Verify Installation

```bash
# Check versions
minikube version
kubectl version --client
helm version
python3 --version

# Check Docker
docker ps
```

## Quick Start (5 Minutes)

### 1. Start Minikube

```bash
minikube start \
  --cpus=8 \
  --memory=16384 \
  --disk-size=524288 \
  --driver=docker
```

### 2. Run Setup Script

```bash
./scripts/local-dev/setup-minikube-load-tests.sh
```

This script will:
- Deploy Minio (S3-compatible storage)
- Deploy Postgres (database backend)
- Deploy Hive Metastore (metadata catalog)
- Deploy Spark History Server (event log analysis)
- Generate and upload test data

### 3. Verify Setup

```bash
./scripts/local-dev/verify-load-test-env.sh
```

Expected output:
```
[CHECK] Checking kubectl access
  ✓ kubectl can access cluster
[CHECK] Checking load-testing namespace
  ✓ load-testing namespace exists
[CHECK] Checking Minio deployment
  ✓ Minio deployment exists
  ✓ Minio pods are running
...
```

## Installation Steps

### Option 1: Automated Setup (Recommended)

```bash
./scripts/local-dev/setup-minikube-load-tests.sh \
  --recreate \
  --cpus 8 \
  --memory 16384 \
  --disk 524288
```

### Option 2: Manual Setup

#### Step 1: Deploy Minio

```bash
helm repo add minio https://charts.min.io/
helm install minio minio/minio \
  --namespace load-testing \
  --create-namespace \
  --set rootUser=minioadmin \
  --set rootPassword=minioadmin \
  --set persistence.size=20Gi
```

#### Step 2: Deploy Postgres

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql \
  --namespace load-testing \
  --set auth.database=spark_db \
  --set auth.password=sparktest
```

#### Step 3: Deploy History Server

```bash
kubectl apply -f scripts/tests/load/infrastructure/history-server.yaml
```

#### Step 4: Generate Test Data

```bash
python3 scripts/tests/load/data/generate-nyc-taxi.py --size 1gb --upload
python3 scripts/tests/load/data/generate-nyc-taxi.py --size 11gb --upload
```

## Troubleshooting

### Minikube Issues

**Problem**: Minikube fails to start
```bash
# Solution: Recreate Minikube cluster
minikube delete
minikube start --cpus=8 --memory=16384 --driver=docker
```

**Problem**: Insufficient resources
```bash
# Solution: Increase resource allocation
minikube config set cpus 8
minikube config set memory 16384
minikube start
```

### Pod Issues

**Problem**: Pods stuck in Pending state
```bash
# Solution: Check resource availability
kubectl describe pod <pod-name> -n load-testing

# Solution: Check node resources
kubectl top nodes
```

**Problem**: Pods failing with CrashLoopBackOff
```bash
# Solution: Check pod logs
kubectl logs <pod-name> -n load-testing

# Solution: Check pod events
kubectl get events -n load-testing
```

### Data Issues

**Problem**: Test data not uploaded to Minio
```bash
# Solution: Verify Minio connection
kubectl port-forward -n load-testing svc/minio 9000:9000

# Solution: Check buckets
mc alias set local http://localhost:9000 minioadmin minioadmin
mc ls local/
```

### Common Setup Issues

| Issue | Solution |
|-------|----------|
| Port 9000 already in use | Change Minikube tunnel port or stop conflicting service |
| Out of memory | Increase Minikube memory allocation |
| DNS resolution failures | Restart Minikube DNS: `minikube ssh -- sudo systemctl restart dnsmasq` |
| Image pull errors | Preload images: `docker pull <image>` |

## Verification Steps

### 1. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -n load-testing
```

### 2. Verify Services

```bash
kubectl get svc -n load-testing
```

Expected services:
- minio
- postgres-load-testing
- hive-metastore
- spark-history-server

### 3. Verify Connectivity

```bash
# Port-forward Minio
kubectl port-forward -n load-testing svc/minio 9000:9000

# Test connection
curl http://localhost:9000/minio/health/live

# Port-forward History Server
kubectl port-forward -n load-testing svc/spark-history-server 18080:18080

# Test connection
curl http://localhost:18080/api/v1/applications
```

### 4. Verify Test Data

```bash
# List Minio buckets
mc alias set local http://localhost:9000 minioadmin minioadmin
mc ls local/test-data/
```

Expected:
```
[2025-01-01 00:00:00 UTC]      0B nyc-taxi/
```

## Next Steps

After setup is complete:

1. **Run a quick smoke test**:
   ```bash
   ./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke --watch
   ```

2. **View results**:
   ```bash
   python scripts/tests/load/metrics/report_generator.py \
     --results-dir scripts/tests/output/results \
     --output-dir /tmp/reports
   ```

3. **Read the user guide**: `docs/guides/load-testing-guide.md`
