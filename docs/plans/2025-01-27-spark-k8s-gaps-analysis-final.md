# Spark K8s Constructor — Final Design Decisions

> **Status:** Design complete, ready for workstream creation
> **Date:** 2025-01-27
> **Source:** Brainstorming sessions + gaps analysis

---

## Executive Summary

Проведён brainstorming для всех 10 проблем, выявленных в gaps analysis. Для каждой проблемы приняты **финальные архитектурные решения** с учётом user preferences и pragmatic constraints.

**Ключевые изменения от initial recommendations:**

| Область | Initial Recommendation | Final Decision | Причина изменения |
|---------|----------------------|----------------|-------------------|
| Observability | Prometheus + Loki + Tempo | **Prometheus + Grafana + Tempo** | Loki — overengineering, отложен до Phase 3 |
| Data Quality | Soda Core | **Great Expectations** | User preference, Spark-native |
| DS Experience | lakeFS + MLflow serving | **GPU (RAPIDS) + Iceberg** | GPU + ACID приоритетнее, MLflow docs отложены |
| DataOps | OpenMetadata | **Только рекомендации и docs** | Future feature, пока не нужно |
| Upgrades | Blue-green major | **Side-by-side + CI matrix testing** | Команды сами решают когда мигрировать |
| DR | Multi-cluster active-passive | **S3 backups + CronJob** | Basic RTO/RPO достаточно |

---

## Table of Contents

1. [Decisions Summary](#decisions-summary)
2. [1. Multi-Environment Support](#1-multi-environment-support)
3. [2. Observability & Monitoring](#2-observability--monitoring)
4. [3. Resource Management & Cost](#3-resource-management--cost)
5. [4. Security & Compliance](#4-security--compliance)
6. [5. Data Scientist Experience](#5-data-scientist-experience)
7. [6. Data Engineer Workflows](#6-data-engineer-workflows)
8. [7. DataOps & Governance](#7-dataops--governance)
9. [8. Upgradability & Maintenance](#8-upgradability--maintenance)
10. [9. Disaster Recovery](#9-disaster-recovery)
11. [10. Onboarding & Developer Experience](#10-onboarding--developer-experience)
12. [Implementation Roadmap](#implementation-roadmap)

---

## Decisions Summary

| Область | Priority | Key Decision | Complexity | Timeline |
|---------|----------|--------------|------------|----------|
| Multi-Environment | P0 | Flat structure, secrets-agnostic templates | Medium | Phase 1 |
| Observability | P0 | Prometheus + Grafana + Tempo (NO Loki) | Medium | Phase 1 |
| Resource Management | P1 | Auto-scaling (optional) + rightsizing calculator | Low-Medium | Phase 2 |
| Security | P0 | Comprehensive (External Secrets + NetworkPolicies + Scanning) | High | Phase 1 |
| DS Experience | P1 | GPU (RAPIDS) + Iceberg | Medium | Phase 2 |
| DE Workflows | P1 | Great Expectations + Iceberg schema management | Medium | Phase 2 |
| DataOps & Governance | P1 | **Только документация** (Ranger/DataHub future) | Low | Phase 1 |
| Upgradability | P2 | CI compatibility matrix + side-by-side | Medium | Phase 3 |
| Disaster Recovery | P1 | S3 backups + CronJob (basic) | Low | Phase 2 |
| Onboarding | P1 | Platform Engineer focus + Spark internals для DevOps | Medium | Phase 2 |

---

## 1. Multi-Environment Support

### Final Decision

**Flat structure + secrets-agnostic templates + semi-automatic promotion**

```
charts/spark-4.1/
  environments/
    dev/values.yaml
    staging/values.yaml
    prod/values.yaml
  templates/secrets/
    external-secrets.yaml      # External Secrets Operator
    sealed-secrets.yaml        # SealedSecrets
    vault-secrets.yaml         # Vault Agent
    aws-secrets.yaml           # AWS Secrets Manager
    azure-secrets.yaml         # Azure Key Vault
    gcp-secrets.yaml           # GCP Secret Manager
    ibm-secrets.yaml           # IBM Cloud Secrets Manager
```

**Key Features:**
- Flat structure (no inheritance complexity)
- Templates для всех major secret providers
- GitHub Actions workflow для promotion (PR-based)
- Copy-on-write promotion pattern

**Promotion Flow:**
```bash
# Dev → Staging (automatic PR)
gh pr create --title "Promote to staging: ..."
gh pr merge --auto

# Staging → Prod (manual approval)
gh pr create --title "Promote to prod: ...")
# Manual review + approval required
```

---

## 2. Observability & Monitoring

### Final Decision

**Prometheus + Grafana + Tempo (NO Loki — overengineering)**

**Components:**
| Компонент | Purpose | Notes |
|-----------|---------|-------|
| Prometheus | Metrics collection | ServiceMonitor/PodMonitor templates |
| Grafana | Visualization | Pre-built dashboards (Spark operations) |
| Tempo | Distributed tracing | OpenTelemetry integration |
| AlertManager | Alerting | Phase 2 (deferred) |
| ~~Loki~~ | ~~Log aggregation~~ | **REJECTED** — overengineering for Phase 1 |

**Structured Logging:**
```properties
# log4j2.properties
appender.console.type = Console
appender.console.layout.type = JsonLayout
```

**Phase 1:** Prometheus + Grafana dashboards + Tempo tracing
**Phase 2:** AlertManager rules (SLO-based)
**Phase 3:** Loki (если потребуется)

---

## 3. Resource Management & Cost

### Final Decision

**Auto-scaling + rightsizing calculator (all optional)**

**Components:**
| Component | Purpose | Opt-in |
|-----------|---------|--------|
| Spark Dynamic Allocation | Executor-level scaling | Default |
| Cluster Autoscaler | Node-level scaling | Optional |
| KEDA | Event-driven scaling | Optional |
| Rightsizing Calculator | Sizing recommendations | Script |
| Cost-Optimized Presets | Spot instances | Optional |

**Rightsizing Calculator:**
```bash
./scripts/calculate-resources.sh \
  --dataset-size 1TB \
  --transformations join,aggregate \
  --target-duration 15m

# Output:
# Recommended: 10 executors, 8GB each, 2 cores
# Estimated cost: $5.40 (on-demand), $1.60 (spot)
```

**Cost-Optimized Preset:**
```yaml
# values-scenario-cost-optimized.yaml
connect:
  nodeSelector:
    instance-type: "spot"
  tolerations:
  - key: "spot"
    effect: "NoSchedule"
  dynamicAllocation:
    minExecutors: 0  # Scale to zero
    maxExecutors: 20
```

**Philosophy:** Все компоненты optional — не нужно, не включают.

---

## 4. Security & Compliance

### Final Decision

**Comprehensive security stack (not incremental)**

**Components:**
| Component | Purpose | Priority |
|-----------|---------|----------|
| External Secrets Operator | Secrets management | P0 |
| Network Policies | Default-deny + allow rules | P0 |
| Trivy Scanning | Image vulnerability scanning | P0 |
| RBAC Hardening | Least privilege | P1 |
| Pod Security Admission | PSS enforcement | P1 |

**Secret Providers Supported:**
- AWS Secrets Manager
- HashiCorp Vault
- SealedSecrets (git-native)
- Azure Key Vault
- GCP Secret Manager
- IBM Cloud Secrets Manager

**Network Policy Pattern:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: spark-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**User Feedback:** "Агенты все сами сделают, некритично" — comprehensive implementation, time не limited.

---

## 5. Data Scientist Experience

### Final Decision

**GPU (RAPIDS) + Iceberg (MLflow guides deferred)**

**Components:**
| Component | Purpose | Phase |
|-----------|---------|-------|
| RAPIDS (cuDF) | GPU-accelerated ETL | 1 |
| TensorFlow/PyTorch | GPU training | 1 |
| Apache Iceberg | Dataset versioning, time travel | 1 |
| ~~MLflow guides~~ | ~~ML integration~~ | **Deferred to Phase 3** |

**GPU Support:**
```yaml
# values-scenario-gpu.yaml
connect:
  nodeSelector:
    nvidia.com/gpu: "true"
  resources:
    limits:
      nvidia.com/gpu: "1"
  sparkConf:
    spark.rapids.sql.python.enabled: "true"
    spark.executor.resource.gpu.amount: "1"
```

**Iceberg Integration:**
```python
# Time travel
df = spark.read \
    .format("iceberg") \
    .load("prod.db.table.version_as_of<timestamp>")
```

**User Feedback:** "MLflow лучше послать читать доки, чем пытаться у себя нагородить"

---

## 6. Data Engineer Workflows

### Final Decision

**Great Expectations + Iceberg schema management**

**Components:**
| Component | Purpose | Notes |
|-----------|---------|-------|
| Great Expectations | Data quality validation | Expectations в git |
| Iceberg | Schema evolution | Already in Problem 5 |
| Backfill preset | Automated backfill | Optional |
| Validation modes | Flexible DQ enforcement | Optional |

**Validation Modes:**
```yaml
# Option 1: Always validate
validation_mode: "always"

# Option 2: Skip validation
validation_mode: "skip"

# Option 3: Production only
validation_mode: "production_only"

# Option 4: Scheduled
validation_mode: "scheduled"
validation_schedule: "0 6 * * *"
```

**Great Expectations Structure:**
```
dags/expectations/
  sales_suite.json
  orders_suite.json
  customers_suite.json
```

**User Feedback:** "A+B классика. Может, great expectations как пример возьмем?" — data quality + schema drift — классические проблемы.

---

## 7. DataOps & Governance

### Final Decision

**Только рекомендации и документация (Ranger/DataHub future)**

**Documentation Recipes:**
1. `data-access-control.md` — Hive ACLs + Ranger future reference
2. `data-lineage.md` — Manual lineage patterns + DataHub future
3. `naming-conventions.md` — Standard naming conventions
4. `audit-logging.md` — Airflow + Spark event logs

**Dataset README Template:**
```markdown
# Dataset: prod_sales_orders

**Owner:** @data-team-sales
**Criticality:** High
**PII:** No
**Update Frequency:** Daily

## Schema
| Column | Type | Description | PII |
|--------|------|-------------|-----|
| order_id | bigint | Primary key | No |
| customer_email | string | Customer contact | Yes |

## Lineage
**Source:** s3a://raw/orders/
**Transformation:** jobs/sales_etl.py
**Dependents:** prod_analytics_daily_summary

## Access Control
```sql
GRANT SELECT ON TABLE prod_sales_orders TO ROLE analytics_team;
```
```

**User Feedback:** "Только рекомендации и docs" — ничего не implement, только guide.

---

## 8. Upgradability & Maintenance

### Final Decision

**CI compatibility matrix + side-by-side deployment**

**Components:**
| Component | Purpose | Notes |
|-----------|---------|-------|
| CI/CD Matrix | Test on 3.5.7, 3.5-latest, 4.1.0, 4.1-latest | GitHub Actions |
| Backward Compatibility Tests | Existing jobs testing | pytest suite |
| API Breaking Changes Tests | PySpark API validation | pytest suite |
| Performance Regression | Benchmark comparison | Auto-fail if >10% slower |
| Compatibility Matrix | Auto-generated docs | Updated on each run |

**Side-by-Side:**
```yaml
# Spark 3.5 and 4.1 can coexist
spark-35:
  enabled: true
  image.tag: "3.5.7"

spark-41:
  enabled: true
  image.tag: "4.1.0"
```

**User Feedback:** "Как хотят команды. Если надо остаться на 3.5.0, так тому и быть. А мы только проверяем, все ли работает"

---

## 9. Disaster Recovery

### Final Decision

**S3/MinIO backups + Kubernetes CronJob (basic RTO/RPO)**

**Components:**
| Component | Purpose | Notes |
|-----------|---------|-------|
| CronJob | Daily backups at 2 AM | pg_dump → S3 |
| S3/MinIO Storage | Backup storage | Same cloud (simple) |
| Restore Job | Manual restore | kubectl apply -f restore-job.yaml |
| Documentation | Disaster scenarios | Step-by-step runbooks |

**Backup Targets:**
- Hive Metastore PostgreSQL
- Airflow PostgreSQL

**NOT in scope:**
- MLflow (future)
- S3 datasets (use replication)

**CronJob Schedule:**
```yaml
schedule: "0 2 * * *"  # 2 AM daily
retention: 30  # days
```

**RTO/RPO:**
- RTO: 1-4 hours (basic)
- RPO: 24 hours (daily backup)

**User Feedback:** "Basic (daily backups)" — простая стратегия, без multi-cluster complexity.

---

## 10. Onboarding & Developer Experience

### Final Decision

**Platform Engineer primary focus + Spark internals для DevOps**

**Components:**
| Component | Purpose | Format |
|-----------|---------|--------|
| Quick Start Guide | 15-minute first deployment | Markdown |
| Interactive Tutorials | Learn by doing | Jupyter notebooks |
| Spark Internals Guide | Spark для DevOps (не blackbox) | Markdown + diagrams |
| Custom Image Building | Build custom Spark images | Docker examples |
| Troubleshooting Guide | Common issues + fixes | Playbook |
| Code Examples | All personas | GitHub examples |

**Tutorials:**
```
tutorials/
├── 01-quick-start.ipynb           # Первый Spark job
├── 02-spark-internals.ipynb       # Как Spark работает (для DevOps!)
├── 03-k8s-integration.ipynb       # Spark + K8s integration
├── 04-custom-images.ipynb         # Building custom images
├── 05-troubleshooting.ipynb       # Common issues
└── 06-tuning-basics.ipynb         # Resource tuning
```

**Spark Internals для DevOps:**
- Lazy Evaluation (DAG)
- Shuffle (expensive operation)
- Memory Management (execution vs storage)
- Driver vs Executor roles

**User Feedback:** "Spark для девопса блэкбокс" — нужно объяснить как Spark работает внутри.

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-8) — P0 Critical

**Goal:** Устранить критические пробелы безопасности и multi-environment поддержки

| Week | Workstreams | Deliverables |
|------|-------------|--------------|
| 1-2 | WS-ENV-001, WS-ENV-002 | Environment structure + secrets templates |
| 3-4 | WS-SEC-001, WS-SEC-002 | External Secrets + Network Policies |
| 5-6 | WS-OBS-001, WS-OBS-002 | ServiceMonitors + Grafana dashboards |
| 7-8 | WS-OBS-003, WS-DOP-001 | Tempo tracing + governance docs |

**Delivery:** End of Week 8 — dev/staging/prod environments с isolated secrets

---

### Phase 2: Production Readiness (Weeks 9-16) — P1 High Priority

**Goal:** Production-grade observability, cost optimization, data workflows

| Week | Workstreams | Deliverables |
|------|-------------|--------------|
| 9-10 | WS-RES-001, WS-RES-002 | Auto-scaling + rightsizing calculator |
| 11-12 | WS-DS-001, WS-DS-002 | GPU support + Iceberg integration |
| 13-14 | WS-DE-001, WS-DE-002 | Great Expectations + schema management |
| 15-16 | WS-DR-001, WS-ONB-001 | Backup automation + quick start guides |

**Delivery:** End of Week 16 — production-ready для 80% enterprise use cases

---

### Phase 3: Advanced Features (Weeks 17-24) — P2 Nice-to-Have

**Goal:** Advanced capabilities для сложных сценариев

| Week | Workstreams | Deliverables |
|------|-------------|--------------|
| 17-18 | WS-OBS-004, WS-UPG-001 | AlertManager + compatibility matrix |
| 19-20 | WS-ONB-002, WS-ONB-003 | Interactive tutorials + troubleshooting |
| 21-22 | WS-DS-003, WS-DE-003 | MLflow guides + backfill automation |
| 23-24 | WS-SEC-003, polish | RBAC hardening + documentation polish |

**Delivery:** End of Week 24 — enterprise-grade platform для 95% use cases

---

## Next Steps

1. **Create workstreams** для всех 10 проблем (WS-ENV-*, WS-OBS-*, etc.)
2. **Create ADRs** для ключевых архитектурных решений
3. **Execute Phase 1** starting with WS-ENV-001 (Multi-Environment)

---

**Status:** Ready for workstream execution
**Next Action:** Create individual workstream files
