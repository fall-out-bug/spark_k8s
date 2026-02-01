# jupyter-k8s-358

> **Type:** `smoke` | **Estimated Time:** `5 min`

## Description

Smoke test for Jupyter + K8s submit mode (Spark 3.5.8)

## Configuration

| Parameter | Value |
|-----------|-------|
| **Spark Version** | `3.5.8` |
| **Component** | `jupyter` |
| **Mode** | `k8s-submit` |
| **Features** | `[]` |
| **Chart** | `charts/spark-3.5` |
| **Preset** | `charts/spark-3.5/presets/test-baseline-358-values.yaml` |

## Tags

- `smoke`
- `jupyter`
- `k8s-submit`
- `3.5.8`

## Usage

```bash
# Run the test
/home/fall_out_bug/work/s7/spark_k8s/scripts/tests/smoke/scenarios/jupyter-k8s-358.sh

# Or with parameters
/home/fall_out_bug/work/s7/spark_k8s/scripts/tests/smoke/scenarios/jupyter-k8s-358.sh --version=3.5.8 --component=jupyter
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

*Generated: 2026-02-01 18:23:35*
