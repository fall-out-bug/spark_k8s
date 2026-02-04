# Spark K8s for Platform Engineers

Complete guide for platform engineers to build and maintain internal developer platforms with Apache Spark on Kubernetes.

## 🎯 Your Mission

### Who Is This For?

You are a **Platform Engineer** who needs to:
- Build internal developer platforms for data teams
- Enable self-service Spark deployments
- Maintain platform reliability and security
- Govern multi-tenant environments
- Balance developer velocity with operational excellence

---

## 🚀 Quick Start (15 Minutes)

### Platform Setup

1. **Understand Architecture**: [Architecture Overview](../architecture/spark-k8s-charts.md)
2. **Choose Preset**: [Preset Selection](../getting-started/choose-preset.md)
3. **Production Deployment**: [Production Checklist](../operations/production-checklist.md)

---

## 📚 Platform Engineering Path

### Phase 1: Platform Foundation (1-2 weeks)

**Goal:** Deploy stable multi-tenant Spark platform

1. [ ] Deploy Spark Connect with production preset
2. [ ] Configure namespace isolation and RBAC
3. [ ] Set up resource quotas per team
4. [ ] Implement network policies
5. [ ] Configure ingress and TLS

**Resources:**
- [Platform Engineering Guide](../guides/en/platform-engineering.md)
- [Security Hardening](../recipes/security/hardening-guide.md)
- [Multi-tenancy Guide](../recipes/security/multi-tenancy.md)

### Phase 2: Developer Experience (2-3 weeks)

**Goal:** Enable self-service for data teams

1. [ ] Create preset catalog for common patterns
2. [ ] Implement approval workflows (if needed)
3. [ ] Set up service mesh (optional)
4. [ ] Configure observability per tenant
5. [ ] Build internal documentation portal

**Resources:**
- [Preset Catalog](../guides/en/presets/)
- [Developer Portal Setup](../guides/en/developer-portal.md)
- [Service Integration](../recipes/integration/service-mesh.md)

### Phase 3: Governance & Operations (3-4 weeks)

**Goal:** Full platform governance at scale

1. [ ] Implement policy-as-code (OPA Gatekeeper)
2. [ ] Cost attribution and chargeback
3. [ ] Compliance monitoring and reporting
4. [ ] Automated backup/DR
5. [ ] Platform metrics and SLO tracking

**Resources:**
- [Governance Framework](../guides/en/governance.md)
- [Cost Attribution](../recipes/cost-optimization/cost-attribution.md)
- [Platform Metrics](../guides/en/observability/platform-metrics.md)

---

## 🎓 Key Skills

### Required Skills

| Skill | Why Important | Resources |
|-------|---------------|------------|
| **Kubernetes Advanced** | Multi-tenancy, RBAC, policies | [K8s Hardening](https://kubernetes.io/docs/concepts/security/) |
| **Helm Charts** | Package distribution | [Helm Best Practices](https://helm.sh/docs/chart_best_practices/) |
| **Platform Design** | IDP concepts, golden paths | [Platform Engineering](https://platformengineering.org/) |
| **Service Mesh** | Traffic management, security | [Istio Docs](https://istio.io/latest/docs/) |

### Nice to Have

- Policy-as-Code (OPA)
- GitOps (ArgoCD, Flux)
- Service mesh expertise
- FinOps practices

---

## 🔧 Common Operations

### Onboard a New Team

```bash
# Create team namespace
kubectl create namespace data-team-alpha

# Apply resource quota
kubectl apply -f config/teams/data-team-alpha/quota.yaml

# Grant team access
kubectl apply -f config/teams/data-team-alpha/rbac.yaml

# Share preset values
cp presets/team-default.yaml config/teams/data-team-alpha/
```

### Configure Multi-tenancy

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-data-science
  labels:
    tenant: data-science
    environment: production

---
# resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: tenant-data-science
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    persistentvolumeclaims: "20"
```

### Implement Policy-as-Code

```rego
# Constraint: Spark jobs must have resource limits
package spark.k8s.resource_limits

deny[msg] {
  input.review.kind.kind == "StatefulSet"
  input.review.object.metadata.labels["app.kubernetes.io/component"] == "spark-driver"
  not input.review.object.spec.template.spec.containers[_].resources.limits
  msg := "Spark driver must have resource limits"
}
```

### Monitor Platform Health

```bash
# Check all tenant namespaces
kubectl get namespaces -l tenant

# Check resource usage across tenants
kubectl top pods -A | grep spark

# Check quota compliance
kubectl get resourcequota -A

# View platform metrics
kubectl port-forward svc/grafana 3000:3000
```

---

## 🏗️ Platform Patterns

### Golden Path: ETL Pipeline

```yaml
# preset-etl.yaml
spark:
  mode: connect
  resources:
    driver:
      memory: "4g"
      cpu: "2"
    executor:
      instances: 10
      memory: "8g"
      cpu: "4"
  monitoring:
    enabled: true
    prometheus:
      enabled: true
  logging:
    enabled: true
    loki:
      enabled: true
```

### Golden Path: ML Training

```yaml
# preset-ml.yaml
spark:
  mode: connect
  resources:
    driver:
      memory: "8g"
      cpu: "4"
    executor:
      instances: 5
      memory: "16g"
      cpu: "8"
      gpu:
        enabled: true
        count: 1
  mlflow:
    enabled: true
```

### Golden Path: Streaming

```yaml
# preset-streaming.yaml
spark:
  mode: connect
  streaming:
    enabled: true
    checkpointLocation: "s3a://checkpoints"
  kafka:
    enabled: true
    bootstrapServers: "kafka:9092"
```

---

## 📊 Platform SLOs

### Service Level Objectives

| SLO | Target | Measurement |
|-----|--------|------------|
| **Platform Availability** | 99.9% | Uptime percentage |
| **Deployment Latency** | <30s | Time to first pod running |
| **Self-Service Success** | >95% | Deployments without platform ticket |
| **Resource Efficiency** | >70% | Cluster utilization |

### Platform Metrics

```yaml
# Key metrics to track
metrics:
  platform:
    - cluster_utilization
    - tenant_resource_usage
    - deployment_success_rate
    - error_rate_by_tenant
  developer_experience:
    - time_to_first_job
    - support_tickets_per_team
    - preset_usage_by_type
```

---

## 💰 Cost Management

### Chargeback Model

```yaml
# Cost attribution per team
cost_attribution:
  team_alpha:
    cpu_cost: $0.05/hour
    memory_cost: $0.01/GiB/hour
    storage_cost: $0.10/GiB/month
  billing:
    cadence: monthly
    report: s3://billing-reports/
```

### Optimization Strategies

1. **Right Sizing**: Enforce resource limits based on actual usage
2. **Spot Instances**: Use for non-critical workloads
3. **Auto-scaling**: Scale to zero when idle
4. **Quota Enforcement**: Prevent overspending

---

## 🔐 Governance

### Policy Enforcement

```yaml
policies:
  security:
    - deny_privileged: true
    - require_network_policy: true
    - enforce_image_scan: true
  compliance:
    - data_residency: "eu-west-1"
    - audit_logging: true
    - retention_policy: "90d"
  operations:
    - max_job_duration: "24h"
    - require_resource_limits: true
    - enforce_naming_convention: true
```

### Approval Workflows

```yaml
workflows:
  production_deploy:
    approval: required
    approvers:
      - platform-lead
      - security-team
  preset_customization:
    approval: auto
    conditions:
      - resource_limits_within_quota
      - compliance_check_passed
```

---

## 🆘 Support

### Platform Issues

1. Check [Platform Runbooks](../operations/runbooks/platform-issues.md)
2. Review [Troubleshooting Guide](../operations/troubleshooting.md)
3. Escalate to platform team

### Developer Support

- [Internal Developer Portal](https://internal.platform.spark)
- [Team Documentation](../teams/)
- [Platform Slack](https://slack.platform.internal)

---

## 📖 Learn More

- [Platform Engineering Guide](../guides/en/platform-engineering.md) — Complete platform design
- [Governance Framework](../guides/en/governance.md) — Policy and compliance
- [Multi-tenancy Guide](../recipes/security/multi-tenancy.md) — Tenant isolation
- [Architecture](../architecture/) — System design

---

**Persona:** Platform Engineer
**Experience Level:** Advanced
**Estimated Time to Production:** 4-8 weeks
**Last Updated:** 2026-02-04
