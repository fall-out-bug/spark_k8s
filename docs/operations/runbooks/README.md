# Operations Runbooks

Step-by-step procedures for common operational tasks and incident response.

## 🚨 Critical Incidents

| Runbook | When to Use | Time to Resolve |
|---------|-------------|-----------------|
| [Job Failures](job-failures.md) | Jobs failing or pods crashing | 15-30 min |
| [Performance Tuning](performance.md) | Jobs slower than expected | 30-60 min |

## 📋 Operational Procedures

| Procedure | Description | Frequency |
|-----------|-------------|-----------|
| [Health Check](../../scripts/diagnostics/spark-health-check.sh) | Quick cluster diagnostics | As needed |
| [Scaling](scaling.md) | Add/remove executor capacity | On demand |
| [Backup/Recovery](data-recovery.md) | Restore from backup | Emergency |

## 🔧 Quick Actions

### Check Cluster Health
```bash
./scripts/diagnostics/spark-health-check.sh
```

### Access Spark UI
```bash
kubectl port-forward svc/spark-history 18080:18080
open http://localhost:18080
```

### View Recent Logs
```bash
kubectl logs -f deployment/spark-connect --tail=100
```

### Restart Spark Connect
```bash
kubectl rollout restart deployment/spark-connect
```

## 📖 Related Resources

- [Troubleshooting Guide](../troubleshooting.md) — Decision trees for common issues
- [Production Checklist](../production-checklist.md) — Go-live requirements
- [Alert Configuration](../alert-configuration.md) — Monitoring setup

---

**Last Updated:** 2026-02-04
**Part of:** [F18: Production Operations Suite](../../drafts/feature-production-operations.md)
