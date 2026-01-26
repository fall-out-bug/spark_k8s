# ISSUE-032: Spark 4.1 Connect server crashes with Kubernetes client exception

## Status
OPEN

## Severity
P0 - Blocks E2E tests

## Description

Spark 4.1 Connect server pod enters CrashLoopBackOff state after repeated restarts. The logs show a Kubernetes client exception:

```
io.fabric8.kubernetes.client.KubernetesClientException: ...
at io.fabric8.kubernetes.client.vertx.VertxHttpRequest.lambda$consumeBytes$1
```

The container repeatedly crashes (5+ restarts) and never becomes ready.

## Error Message

```
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Warning  BackOff    2m58s (x7 over 4m20s)  kubelet            Back-off restarting failed container
```

Pod state:
```
test-spark-spark-41-connect-f98d9c985-j99jk    0/1     CrashLoopBackOff   5 (39s ago)
```

## Reproduction

```bash
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set spark-base.minio.enabled=true \
  --set spark-base.postgresql.enabled=false

kubectl get pods -n spark
kubectl logs -n spark <connect-pod> --tail=100
```

## Root Cause (Investigation needed)

Possible causes:
1. Kubernetes API server connection issues from within the pod
2. Missing/incorrect RBAC permissions for Spark Connect to create pods
3. ServiceAccount token mounting issues
4. Network policies blocking API server access
5. Incompatibility between Spark 4.1 and Kubernetes client library

## Diagnosis Steps

1. Check RBAC permissions:
   ```bash
   kubectl auth can-i create pods -n spark \
     --as=system:serviceaccount:spark:spark-41
   ```

2. Check ServiceAccount exists:
   ```bash
   kubectl get sa -n spark spark-41
   ```

3. Check pod can reach API server:
   ```bash
   kubectl exec -n spark <connect-pod> -- \
     curl -k https://kubernetes.default.svc/api/
   ```

4. Check pod service account token:
   ```bash
   kubectl exec -n spark <connect-pod) -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
   ```

## Solution

**To be determined after diagnosis.**

Potential fixes:
1. Ensure proper RBAC is configured (ClusterRole/RoleBinding)
2. Verify ServiceAccount is properly created
3. Check if network policies allow API server access
4. Review Spark Connect configuration for K8s backend mode

## Workaround

None currently. Connect server cannot start.

## Impact

- Blocks all Spark 4.1 E2E tests
- Cannot use Spark Connect with K8s backend mode
- Affects development workflow

## Related

- ISSUE-030: Spark 4.1 MinIO label "N/A" error
- ISSUE-031: Spark base MinIO secret missing
- Spark 4.1 RBAC configuration
- test-e2e-jupyter-connect.sh script
