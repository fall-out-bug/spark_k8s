# Cluster Scaling Runbook

## Overview

This runbook covers cluster autoscaler operations for handling node-level scaling in Spark on Kubernetes deployments.

## Detection

### When to Scale Cluster

Monitor these metrics to determine if cluster scaling is needed:

```bash
# Check pending pods (nodes at capacity)
kubectl get pods -A | grep Pending

# Check node resource utilization
kubectl top nodes

# Check unschedulable pods
kubectl get pods -A --field-selector spec.nodeName="" | grep -v "Completed"

# Check cluster autoscaler status
kubectl get deployment cluster-autoscaler -n kube-system
kubectl logs -n kube-system deployment/cluster-autoscaler
```

### Indicators

- **Pods in Pending state** due to insufficient resources
- **Node CPU/Memory > 80%** sustained
- **Cluster autoscaler events** showing scale-up failures
- **Spark jobs failing** with "insufficient resources" errors
- **Long job queue times**

## Diagnosis

### Step 1: Check Node Status

```bash
# List all nodes with resource usage
kubectl top nodes

# Check node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[*].type}{"="}{.status.conditions[*].status}{"\n"}{end}'

# Check node capacity vs allocatable
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Step 2: Check Pending Pods

```bash
# Get pending pods with reasons
kubectl get pods -A --field-selector status.phase=Pending

# Describe specific pending pod to see scheduling failure
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events:"
```

### Step 3: Check Cluster Autoscaler

```bash
# Check CA deployment
kubectl get deployment cluster-autoscaler -n kube-system -o yaml

# Check CA logs
kubectl logs -n kube-system deployment/cluster-autoscaler --tail=100

# Check CA status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

### Step 4: Check Resource Quotas

```bash
# Check if resource quotas limit scaling
kubectl get resourcequota -A

# Describe quota
kubectl describe resourcequota <name> -n <namespace>
```

## Remediation

### Immediate Actions

#### 1. Manual Node Pool Scaling (Cloud Provider Specific)

**AWS EKS:**
```bash
# Scale node group
aws eks update-nodegroup-config \
  --cluster-name spark-prod \
  --nodegroup-name spark-compute \
  --scaling-config desiredSize=10

# Check status
aws eks describe-nodegroup \
  --cluster-name spark-prod \
  --nodegroup-name spark-compute
```

**Azure AKS:**
```bash
# Scale node pool
az aks nodepool scale \
  --resource-group spark-rg \
  --cluster-name spark-prod \
  --name compute \
  --node-count 10

# Check status
az aks nodepool show \
  --resource-group spark-rg \
  --cluster-name spark-prod \
  --name compute
```

**GCP GKE:**
```bash
# Resize node pool
gcloud container clusters resize spark-prod \
  --node-pool compute-pool \
  --num-nodes 10 \
  --region us-central1

# Check status
gcloud container node-pools describe compute-pool \
  --cluster spark-prod \
  --region us-central1
```

#### 2. Taint Existing Nodes for Critical Workloads

```bash
# Add taint for high-priority jobs
kubectl taint nodes node-1 spark.critical=true:NoSchedule

# Update job to tolerate taint
kubectl patch sparkapp <app-name> --type=json -p='[{"op":"add","path":"/spec/executor/tolerations","value":[{"key":"spark.critical","operator":"Exists","effect":"NoSchedule"}]}]'
```

#### 3. Enable Pod Priority

```bash
# Create priority class
kubectl apply -f - <<EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: spark-critical
value: 1000
globalDefault: false
description: "High priority for critical Spark jobs"
EOF

# Apply to job
kubectl patch sparkapp <app-name> --type=json -p='[{"op":"add","path":"/spec/priorityClassName","value":"spark-critical"}]'
```

### Long-term Solutions

#### 1. Configure Cluster Autoscaler

```bash
# Deploy/Update Cluster Autoscaler
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=3
        - --cloud-provider=aws  # or azure, gke
        - --nodes=2:10:spark-compute-node-group
        - --balance-similar-node-groups
        - --expander=priority
        - --skip-nodes-with-system-pods=false
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        env:
        - name: AWS_REGION  # For AWS
          value: us-east-1
        resources:
          requests:
            cpu: "100m"
            memory: "300Mi"
EOF
```

#### 2. Create Multiple Node Pools

```bash
# Spark executors (spot instances)
aws eks create-nodegroup \
  --cluster-name spark-prod \
  --nodegroup-name spark-spot \
  --node-role arn:aws:iam::ACCOUNT_ID:role/NodeInstanceRole \
  --subnets subnet-1 subnet-2 \
  --instance-types m5.xlarge m5.2xlarge \
  --scaling-config minSize=2,maxSize=20,desiredSize=5 \
  --capacity-type SPOT

# Spark drivers (on-demand instances)
aws eks create-nodegroup \
  --cluster-name spark-prod \
  --nodegroup-name spark-driver \
  --node-role arn:aws:iam::ACCOUNT_ID:role/NodeInstanceRole \
  --subnets subnet-1 subnet-2 \
  --instance-types m5.large \
  --scaling-config minSize=2,maxSize=10,desiredSize=3 \
  --capacity-type ON_DEMAND
```

#### 3. Configure Node Selectors for Workloads

```yaml
# Spark executors on spot nodes
spec:
  executor:
    nodeSelector:
      node-group: spark-spot
    tolerations:
    - key: "spotInstance"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

# Spark drivers on on-demand nodes
spec:
  driver:
    nodeSelector:
      node-group: spark-driver
```

## Prevention

### 1. Right-size Node Pools

```bash
# Calculate requirements
scripts/scaling/calculate-executor-sizing.sh --jobs 100 --parallelism 1000

# Result: ~100 vCPUs needed for executors
# With 2 vCPU per node = 50 nodes minimum
```

### 2. Set Appropriate Auto-scaling Bounds

```bash
# Minimum nodes: Baseline capacity (2-3 nodes)
# Maximum nodes: Budget limits (20-30 nodes)
# Scale-down delay: Prevent thrashing (10-15 minutes)
```

### 3. Use Spot Instances for Non-critical Workloads

```yaml
# Save up to 70% on compute costs
# Use for:
# - Development/testing
# - Non-urgent batch processing
# - Fault-tolerant workloads
```

### 4. Implement Pod Disruption Budgets

```bash
# Prevent CA from removing all pods during scale-down
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spark-executor-pdb
  namespace: spark-operations
spec:
  minAvailable: 50%
  selector:
    matchLabels:
      spark-role: executor
EOF
```

## Validation

```bash
# Verify cluster autoscaler is running
kubectl get deployment cluster-autoscaler -n kube-system

# Check CA is scaling up
kubectl logs -n kube-system deployment/cluster-autoscaler | grep "scale-up"

# Check CA is scaling down
kubectl logs -n kube-system deployment/cluster-autoscaler | grep "scale-down"

# Verify pods are being scheduled
kubectl get pods -A | grep Pending | wc -l  # Should be 0
```

## Troubleshooting

### Cluster Autoscaler Not Scaling Up

1. **Check max node limit**: May be at maxNodes
2. **Check node template**: Instance type may not be available
3. **Check quotas**: Cloud provider resource limits
4. **Check pod requirements**: Requests may exceed node capacity
5. **Check CA logs**: `kubectl logs -n kube-system deployment/cluster-autoscaler`

### Cluster Autoscaler Scaling Down Too Aggressively

1. **Increase scale-down-unneeded-time**: Default 10 minutes
2. **Increase scale-down-utilization-threshold**: Default 0.5
3. **Add PDBs**: Prevent critical pods from being removed
4. **Add annotations**: `cluster-autoscaler.kubernetes.io/scale-down-disabled: "true"`

### Nodes Not Provisioning

1. **Check cloud provider status**: Console outage or quota exceeded
2. **Check instance availability**: Requested type may be unavailable
3. **Check subnet capacity**: No available IPs in subnet
4. **Check IAM permissions**: Node role may lack permissions

## Monitoring

```bash
# Cluster autoscaler metrics
# Unschedulable pods
kubectl get --raw /apis/metrics.k8s.io/v1beta1 | jq '.items[] | select(.pods[] | .phase=="Pending")'

# Node resource utilization
kubectl top nodes

# Cluster autoscaler events
kubectl get events -n kube-system --field-selector involved.name=cluster-autoscaler
```

## Related Runbooks

- [Horizontal Pod Autoscaler](./horizontal-pod-autoscaler.md)
- [Spark Executor Scaling](./spark-executor-scaling.md)
- [Capacity Planning](../procedures/capacity/capacity-planning.md)

## References

- [Cluster Autoscaler Documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [EKS Cluster Autoscaler Setup](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html)
