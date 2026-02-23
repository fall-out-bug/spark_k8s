# jupyter-connect-k8s-410

> **Type:** `smoke` | **Estimated Time:** `5 min`

## Description

Smoke test for Jupyter + Spark Connect + K8s backend (Spark 4.1.0)

## Configuration

| Parameter | Value |
|-----------|-------|
| **Spark Version** | `4.1.0` |
| **Component** | `jupyter` |
| **Mode** | `connect-k8s` |
| **Features** | `[]` |
| **Chart** | `charts/spark-4.1` |
| **Preset** | `charts/spark-4.1/presets/test-baseline-values.yaml` |

## Tags

- `smoke`
- `jupyter`
- `connect-k8s`
- `4.1.0`

## Usage

```bash
# Run the test
/home/fall_out_bug/work/s7/spark_k8s/scripts/tests/smoke/scenarios/jupyter-connect-k8s-410.sh

# Or with parameters
/home/fall_out_bug/work/s7/spark_k8s/scripts/tests/smoke/scenarios/jupyter-connect-k8s-410.sh --version=4.1.0 --component=jupyter
```

## Prerequisites

- Kubernetes cluster with `kubectl` configured
- Helm 3.x installed
- Sufficient cluster resources (CPU, memory)

## What Is Tested

- ✅ Basic deployment of Spark components
- ✅ Pods reach Ready state
- ✅ Services are accessible
- ✅ Simple Spark job execution

## Success Criteria

1. All pods reach Ready state
2. All services respond to requests
3. Test jobs complete without errors
4. Resource limits respected
5. No unexpected pod restarts

## Cleanup

The test automatically cleans up resources on failure. On success, resources are preserved for inspection.

To manually clean up:

```bash
# List test namespaces
kubectl get namespaces | grep spark-test

# Delete specific namespace
kubectl delete namespace <namespace-name>
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n <namespace>
```

### View pod logs
```bash
kubectl logs -n <namespace> <pod-name>
```

### Describe pod for events
```bash
kubectl describe pod -n <namespace> <pod-name>
```

---

*Generated: 2026-02-01 18:22:05*
