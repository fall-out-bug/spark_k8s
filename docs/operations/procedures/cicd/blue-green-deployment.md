# Blue-Green Deployment

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Job CI/CD Pipeline](./job-cicd-pipeline.md), [A/B Testing](./ab-testing.md)

## Overview

Blue-green deployment maintains two identical production environments. New deployments go to the "green" environment while the "blue" environment continues serving traffic. Once validated, traffic switches to green.

## Architecture

```
                    Load Balancer
                         |
            +------------+------------+
            |                         |
         Blue Env                 Green Env
         (current)              (new version)
            |                         |
        Spark Jobs               Spark Jobs
```

## Deployment Procedure

### Phase 1: Deploy Green Environment

```bash
# 1. Deploy new version to green namespace
helm install spark-green ./charts/spark-4.1 \
  --namespace spark-green \
  --values values/spark-job-v2.yaml

# 2. Verify deployment
kubectl wait --for=condition=ready pod -l spark-role=driver -n spark-green --timeout=5m

# 3. Run smoke tests
./scripts/cicd/smoke-test-job.sh --namespace spark-green --release spark-green
```

### Phase 2: Validate Green Environment

```bash
# 1. Check application health
kubectl get pods -n spark-green

# 2. Verify metrics
curl -s http://spark-green-ui:4040/api/v1/applications

# 3. Run integration tests
./tests/integration/test-spark-job.sh --env green
```

### Phase 3: Switch Traffic

```bash
# 1. Update load balancer / service selector
kubectl patch service spark-production \
  -n spark-production \
  -p '{"spec":{"selector":{"version":"green"}}}'

# 2. Verify traffic switched
kubectl get endpoints spark-production -n spark-production

# 3. Monitor for errors
kubectl logs -f -n spark-green -l spark-role=driver --tail=100
```

### Phase 4: Decommission Blue Environment

```bash
# 1. Keep blue running for rollback (24 hours)

# 2. Scale down blue after validation period
kubectl scale deployment spark-blue --replicas=0 -n spark-blue

# 3. Uninstall blue after retention period
helm uninstall spark-blue --namespace spark-blue
```

## Kubernetes Configuration

### Service Selector Switch

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spark-production
spec:
  selector:
    version: blue  # Switch to 'green' to activate
  ports:
    - port: 4040
      targetPort: 4040
```

### Blue/Green Deployments

```yaml
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-blue
spec:
  selector:
    matchLabels:
      app: spark
      version: blue
  template:
    metadata:
      labels:
        app: spark
        version: blue
---
# Green deployment (identical structure, different version tag)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-green
spec:
  selector:
    matchLabels:
        app: spark
        version: green
  template:
    metadata:
      labels:
        app: spark
        version: green
```

## Rollback Procedure

### Immediate Rollback

```bash
# 1. Switch traffic back to blue
kubectl patch service spark-production \
  -n spark-production \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# 2. Verify blue is healthy
kubectl get pods -n spark-blue

# 3. Scale up blue if needed
kubectl scale deployment spark-blue --replicas=3 -n spark-blue
```

### Automated Rollback on Failure

```yaml
# Kubernetes readiness probe for rollback
readinessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      # Check for errors in logs
      if kubectl logs -l spark-role=driver --tail=10 | grep -q "ERROR"; then
        exit 1
      fi
      exit 0
  initialDelaySeconds: 60
  periodSeconds: 30
  failureThreshold: 3
```

## Comparison with A/B Testing

| Aspect | Blue-Green | A/B Testing |
|--------|-------------|-------------|
| **Traffic split** | 100% to one version | Split between versions |
| **Switch speed** | Instant (DNS/LB change) | Gradual (percentage) |
| **Rollback** | Instant (switch back) | Gradual (reduce percentage) |
| **Use case** | Deployments with high confidence | Testing new features |
| **Complexity** | Low | Medium |

## Service Mesh Integration

### Istio Virtual Service

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: spark-jobs
spec:
  http:
  - match:
    - headers:
        x-env:
          exact: production
    route:
    - destination:
        host: spark-blue
      weight: 100
```

### Switch Traffic with Istio

```bash
# Switch to green
istioctl rewrite-service-to-version spark-jobs blue green --namespace spark

# Verify split
istioctl proxy-config routes <pod> -n spark
```

## Monitoring

### Deployment Metrics

Track during blue-green deployment:
- Pod health (ready/total)
- Request success rate
- Response latency
- Error rate by version

### Grafana Dashboard

```json
{
  "title": "Blue-Green Deployment",
  "panels": [
    {
      "title": "Traffic Split",
      "targets": [
        {
          "expr": "rate(http_requests_total{version=\"blue\"}[5m])",
          "legendFormat": "Blue"
        },
        {
          "expr": "rate(http_requests_total{version=\"green\"}[5m])",
          "legendFormat": "Green"
        }
      ]
    }
  ]
}
```

## Best Practices

1. **Test green thoroughly:** Run full test suite before switching
2. **Keep blue ready:** Don't scale down blue immediately
3. **Monitor closely:** Watch metrics after traffic switch
4. **Document rollbacks:** Have clear rollback procedures
5. **Automate where possible:** Use automated traffic switching

## References

- [A/B Testing](./ab-testing.md)
- [Job CI/CD Pipeline](./job-cicd-pipeline.md)
- [Smoke Tests](../../tests/README.md)
