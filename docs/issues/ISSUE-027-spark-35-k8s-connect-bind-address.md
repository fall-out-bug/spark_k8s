# ISSUE-027: Spark 3.5 K8s Connect Server binds to incorrect IP (0:0:0:0:0:0:0:0%0)

## Status
🔴 **CRITICAL** - Spark 3.5 K8s mode non-functional

## Workstream
WS-BUG-013

## Problem Description

When Spark 3.5 Connect Server runs in K8s mode, it binds to an incorrect IP address:
- **Expected**: `<POD_IP>:15002` (e.g., `10.244.7.213:15002`)
- **Actual**: `0:0:0:0:0:0:0:0%0:15002` (all-zeros IPv6-like address)

This causes:
1. Health probes fail (liveness/readiness probes cannot connect to port 15002)
2. Spark Connect clients cannot connect
3. Pod enters CrashLoopBackOff state

### Evidence

From `kubectl logs -n minimal-spark-35 spark-connect-xxx`:
```
26/01/24 19:14:06 INFO SparkConnectServer: Spark Connect server started at: 0:0:0:0:0:0:0:0%0:15002
```

From `kubectl describe pod` (same pod):
```
Liveness:   tcp-socket :15002 delay=60s timeout=1s period=30s #success=1 #failure=3
Readiness:  tcp-socket :15002 delay=30s timeout=1s period=10s #success=1 #failure=3
```

Health probe errors:
```
Liveness probe failed: dial tcp 10.244.7.213:15002: i/o timeout
Readiness probe failed: dial tcp 10.244.7.213:15002: connect: connection refused
```

### Current Configuration

In `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml`:
```yaml
# Driver Configuration for K8s
spark.driver.bindAddress=0.0.0.0
spark.driver.host={{ default (printf "%s-connect" (include "spark-platform.fullname" .)) .Values.sparkConnect.driver.host }}
spark.driver.port=7078
spark.driver.blockManager.port=7079
```

In `charts/spark-3.5/charts/spark-connect/values.yaml`:
```yaml
driver:
  host: "spark-connect"
  port: 7078
  blockManagerPort: 7079
```

Expected FQDN: `spark-connect.<namespace>.svc.cluster.local`

### Why This Fails

The IP address `0:0:0:0:0:0:0:0%0` indicates:
1. Spark cannot resolve `spark-driver.host` to an IP address
2. Falls back to all-zeros IPv6 representation
3. Port 15002 may not be bound to the correct interface

## Root Cause Analysis

### Hypothesis 1: DNS Resolution Issue

Spark tries to resolve `spark-driver.host` at startup, but:
- DNS lookup may fail if service doesn't exist yet
- Service DNS may not resolve from inside the pod
- Spark expects a FQDN that includes namespace and cluster suffix

### Hypothesis 2: Wrong Configuration Property

In K8s mode, we should use:
- `spark.driver.bindAddress` = `0.0.0.0` (listen on all interfaces) ✅ Already set
- `spark.driver.host` = FQDN of driver service (for external connections) ✅ Set in ISSUE-026
- **BUT**: For Connect Server, we need `spark.connect.grpc.binding.address` instead of driver.host

### Hypothesis 3: Missing spark.connect.grpc Configuration

Spark 3.5 Connect Server uses:
- `spark.connect.grpc.binding.port` = 15002 ✅ Set
- `spark.connect.grpc.binding.address` (optional, default = bindAddress)

But we may need to explicitly set:
```conf
spark.connect.grpc.binding.address=0.0.0.0
```

### Hypothesis 4: Pod Startup Race Condition

The Spark Connect service may not be ready when the pod starts:
- DNS resolution fails → fallback to invalid IP
- Service creates later → but pod already has wrong IP

## Comparison with Standalone Mode

In **Standalone mode** (which works):
- `spark.master=spark://<master-service>:7077`
- `spark.driver.host` is NOT used for Connect Server binding
- Connect server binds to pod IP automatically

In **K8s mode** (which fails):
- `spark.master=k8s://https://kubernetes.default.svc:443`
- Dynamic executor pods need `spark.driver.host` for driver registration
- Connect server should bind to pod IP, but gets wrong IP

## Proposed Solutions

### Solution 1: Use spark.connect.grpc.binding.address (RECOMMENDED)

Add explicit Connect Server configuration:
```yaml
# In configmap.yaml
spark.connect.grpc.binding.address=0.0.0.0
spark.connect.grpc.binding.port=15002
```

This ensures Connect Server listens on all interfaces, similar to driver.bindAddress.

### Solution 2: Remove spark.driver.host for Connect Server

For Connect Server-only deployments, remove or comment out:
```yaml
# spark.driver.host=...
```

Because:
- Connect Server doesn't use driver.host for binding
- Driver host is only needed for executor registration
- Connect Server in local[*] mode doesn't register with K8s master

### Solution 3: Use Downward API for Pod IP

Set spark.driver.host via Kubernetes Downward API:
```yaml
env:
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
```

Then in configmap:
```yaml
spark.driver.host=${POD_IP}
```

### Solution 4: Add init container to wait for service

Create init container that waits for DNS resolution:
```yaml
initContainers:
  - name: wait-for-service
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        for i in $(seq 1 30); do
          if getent hosts spark-connect.${POD_NAMESPACE}.svc.cluster.local; then
            exit 0
          fi
          echo "Waiting for DNS..."
          sleep 2
        done
        exit 1
```

## Testing Strategy

1. Test Solution 1 (add `spark.connect.grpc.binding.address=0.0.0.0`)
2. Verify logs show: `Spark Connect server started at: 0.0.0.0:15002`
3. Verify health probes pass (pod stays Running)
4. Test client connection: `sc://spark-connect.minimal-spark-35.svc.cluster.local:15002`
5. If Solution 1 fails, try Solution 2 (remove spark.driver.host)
6. If both fail, try Solution 3 (use Downward API for POD_IP)

## Related Issues

- **ISSUE-026**: Spark 3.5 K8s driver host FQDN (resolved, but not tested)
- **ISSUE-017**: Spark 4.1 properties file order (resolved)
- **ISSUE-013-025**: Various Spark Connect issues (resolved)

## Next Steps

1. Implement Solution 1 in `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml`
2. Test with minimal deployment (`test-spark-35-connect-minimal.yaml`)
3. Verify health probes pass
4. Update ISSUE-026 with fix
5. Run full E2E matrix test

## References

- Spark Connect Server configuration: https://spark.apache.org/docs/latest/connect.html#server-configuration
- Kubernetes driver configuration: https://spark.apache.org/docs/latest/running-on-kubernetes.html#cluster-mode
