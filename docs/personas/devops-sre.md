# Spark K8s for DevOps & SRE

Complete guide for DevOps and SRE to operate Apache Spark on Kubernetes in production.

## 🎯 Your Mission

You are a **DevOps Engineer** or **SRE** who needs to:
- Operate Spark data platforms in production
- Debug incidents effectively
- Set up observability and alerting
- Manage costs and resources
- Enable self-service for data teams

---

## 🚀 Quick Start (15 Minutes)

### Production Deployment

1. **Cloud Setup**: [Cloud Setup Guide](../getting-started/cloud-setup.md)
2. **Choose Preset**: See [Preset Selection](../getting-started/choose-preset.md)
3. **Production Checklist**: [Production Checklist](../operations/production-checklist.md)

---

## 📚 Operations Path

### Phase 1: Foundation (1 week)

**Goal:** Deploy stable Spark platform

1. [ ] Deploy Spark Connect with production preset
2. [ ] Configure resource limits and quotas
3. [ ] Set up basic monitoring (metrics, logs)
4. [ ] Create runbooks for common incidents
5. [ ] Test backup/restore procedures

**Resources:**
- [F18: Production Operations Suite](../drafts/feature-production-operations.md) — 50+ runbooks
- [Production Checklist](../operations/production-checklist.md)
- [Security Hardening](../recipes/security/hardening-guide.md)

### Phase 2: Observability (1-2 weeks)

**Goal:** Complete monitoring and alerting

1. [ ] Deploy metrics stack (Prometheus + Grafana)
2. [ ] Configure SLO/SLI monitoring
3. [ ] Set up alerting rules (PagerDuty integration)
4. [ ] Distributed tracing setup
5. [ ] Logging aggregation (Loki/ELK)

**Resources:**
- [F16: Observability](../drafts/feature-observability.md)
- [Alerting Guide](../operations/alert-configuration.md)
- [Grafana Dashboards](../guides/en/observability/)

### Phase 3: Operations Excellence (2-4 weeks)

**Goal:** Full incident response and automation

1. [ ] Implement incident response framework
2. [ ] Runbook execution automation
3. [ ] Cost attribution per job/team
4. [ ] Backup/DR automation
5. [ ] On-call rotation setup

**Resources:**
- [Incident Response Runbook](../operations/runbooks/incident-response.md)
- [Data Recovery Runbook](../operations/runbooks/data-recovery.md)
- [Scaling Procedures](../operations/runbooks/scaling.md)

---

## 🔧 Common Operations

### Scale Spark Cluster

```bash
# Scale up executors
kubectl scale statefulset spark-connect --replicas=10

# Auto-scaling (Cluster Autoscaler)
# Configure in preset or via values.yaml
```

### Check Cluster Health

```bash
# Check all Spark components
kubectl get pods -l app.kubernetes.io/part-of=spark-k8s

# Check resource usage
kubectl top pods -n spark
kubectl describe nodes
```

### Monitor Job Performance

```bash
# View Spark UI
kubectl port-forward svc/spark-history 18080:18080
open http://localhost:18080

# Check metrics in Grafana
kubectl port-forward svc/grafana 3000:3000
```

### Troubleshoot Incident

```bash
# Check recent failures
kubectl logs -f deployment/spark-connect --tail=100

# Check executor status
kubectl describe pod <executor-pod-name>

# Common issues:
# - Driver OOM: Increase driver memory
# - Executor lost: Check network, increase retries
# - Pod pending: Check resource requests vs node capacity
```

---

## 📊 SLO/SLI Examples

### Service Level Indicators (SLIs)

| SLI | Target | Measurement |
|-----|--------|------------|
| **Availability** | 99.9% | Uptime percentage |
| **Latency (p95)** | <5s | Job submission to start |
| **Throughput** | 100 jobs/hour | Jobs completed per hour |
| **Error Rate** | <1% | Failed jobs percentage |

### Service Level Objectives (SLOs)

| SLO | Target | Error Budget |
|-----|--------|-------------|
| **Monthly Uptime** | 99.9% | 43 minutes/month downtime |
| **Daily Failures** | <5 | Total failed jobs per day |

### Alerting Rules

```yaml
alerts:
  - alert: HighFailureRate
    expr: rate(spark_job_failed_total[5m]) > 0.05
    for: 10m
    annotations:
      severity: warning
      runbook: https://docs/operations/runbooks/high-failure-rate.md

  - alert: DriverOOM
    expr: rate(driver_pod_oom_killed_total[5m]) > 0
    for: 5m
    annotations:
      severity: critical
      runbook: https://docs/operations/runbooks/driver-oom.md
```

---

## 💰 Cost Management

### Cost Attribution

Track costs per job/team using labels:

```yaml
spark:
  tags:
    team: data-science
    project: etl-pipeline
    cost-center: analytics-123
```

### Optimization Strategies

1. **Spot Instances**: Use for fault-tolerant workloads
2. **Scaling Down**: Auto-scale to zero when idle
3. **Resource Limits**: Set sensible defaults
4. **Right Sizing**: Use [Executor Calculator](../scripts/tuning/calculate-executor-sizing.sh)

---

## 🆘 Support

### Incident Response

1. Check [Incident Response Runbook](../operations/runbooks/incident-response.md)
2. Check [Troubleshooting Guide](../operations/troubleshooting.md)
3. Escalate to on-call if needed

### Run Contributions

- [Contributor Guide](../community/contributing.md)
- [Good First Issues](https://github.com/fall-out-bug/spark_k8s/labels/good%20first%20issue)
- [Runbook Templates](../operations/runbooks/)

---

**Persona:** DevOps / SRE
**Experience Level:** Intermediate → Advanced
**Estimated Time to Production:** 2-4 weeks
**Last Updated:** 2026-02-04
