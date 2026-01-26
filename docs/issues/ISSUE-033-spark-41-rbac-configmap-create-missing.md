# ISSUE-033: Spark 4.1 RBAC missing configmaps create permission

## Status
FOUND ROOT CAUSE - Blocking ISSUE-032

## Severity
P0 - Blocks Spark 4.1 E2E tests

## Description

Spark 4.1 Connect server crashes because ServiceAccount `spark-41` lacks permission to create ConfigMaps. Spark Connect needs to create a ConfigMap for executor configuration.

## Root Cause Error

```
configmaps is forbidden: User "system:serviceaccount:spark-test:spark-41" cannot create resource "configmaps" in API group "" in the namespace "spark-test".
```

Stack trace:
```
at org.apache.spark.scheduler.cluster.k8s.KubernetesClusterSchedulerBackend.setUpExecutorConfigMap(KubernetesClusterSchedulerBackend.scala:92)
at org.apache.spark.scheduler.cluster.k8s.KubernetesClusterSchedulerBackend.start(KubernetesClusterSchedulerBackend.scala:116)
```

## Why This Happens

Spark Connect on Kubernetes backend mode creates a ConfigMap to share configuration with executor pods. This is standard behavior for Spark on K8s. The ServiceAccount running Spark Connect needs:
- `create` permission on `configmaps`
- `get`, `list`, `watch` permissions on `pods`
- `create` permission on `pods`

## Current RBAC (Insufficient)

The current RBAC in `charts/spark-4.1/templates/rbac.yaml` only provides:
- `create`, `get`, `list`, `watch` on `pods`
- Missing: `create` on `configmaps`

## Solution

Update `charts/spark-4.1/templates/rbac.yaml` to add configmaps permission:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spark-41
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]  # Add configmaps here
  verbs: ["get", "list", "watch", "create"]
```

Or if using Role (namespace-scoped):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-41
  namespace: {{ .Release.Namespace }}
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]  # Add configmaps here
  verbs: ["get", "list", "watch", "create"]
```

## Verification

After fix, verify permissions:

```bash
kubectl auth can-i create configmaps -n spark \
  --as=system:serviceaccount:spark:spark-41

# Should return: yes
```

## Impact

- Blocks ALL Spark 4.1 deployments with K8s backend mode
- Affects all E2E tests
- This is a critical RBAC permission missing from the chart

## Related

- ISSUE-032: Spark 4.1 Connect crashloop (caused by this issue)
- charts/spark-4.1/templates/rbac.yaml
- Spark 4.1 K8s scheduler backend
