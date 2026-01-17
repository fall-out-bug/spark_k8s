## WS-020-20: Production Guide EN + RU

### 🎯 Goal

**What should WORK after WS completion:**
- English guide `docs/guides/SPARK-4.1-PRODUCTION.md` exists with production best practices
- Russian guide `docs/guides/SPARK-4.1-PRODUCTION-RU.md` exists
- Guides cover: resource sizing, HA, security (PSS), monitoring, troubleshooting
- Example production values overlay provided

**Acceptance Criteria:**
- [ ] `docs/guides/SPARK-4.1-PRODUCTION.md` exists (~300 LOC)
- [ ] `docs/guides/SPARK-4.1-PRODUCTION-RU.md` exists (~300 LOC)
- [ ] Guides include: resource recommendations, security hardening (PSS), HA considerations, observability
- [ ] `docs/examples/values-spark-41-production.yaml` overlay provided
- [ ] Guides link to Celeborn and Operator guides

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 targets DataOps/Platform Engineers deploying Spark 4.1.0 to production. This guide provides best practices and configurations.

### Dependency

WS-020-19 (quickstart guides for reference)

### Input Files

**Reference:**
- `docs/guides/SPARK-STANDALONE-PRODUCTION.md` — Existing production guide
- `docs/examples/values-spark-standalone-prodlike.yaml` — Production values pattern

### Steps

1. **Create `docs/guides/SPARK-4.1-PRODUCTION.md`:**
   
   Sections:
   - Overview
   - Resource Sizing (Spark Connect, executors, Hive Metastore, History Server)
   - Security (PSS `restricted`, RBAC, network policies)
   - High Availability (multiple Spark Connect replicas, Hive Metastore backup)
   - Storage (S3 for event logs, PVC for History Server cache)
   - Monitoring (metrics endpoints, logging)
   - Troubleshooting (common issues)

2. **Create `docs/guides/SPARK-4.1-PRODUCTION-RU.md`:**
   
   Russian translation with same structure.

3. **Create `docs/examples/values-spark-41-production.yaml`:**
   ```yaml
   # Production values for Spark 4.1.0
   
   spark-base:
     enabled: true
     rbac:
       create: true
     minio:
       enabled: false  # Use external S3
     postgresql:
       enabled: false  # Use external PostgreSQL
     security:
       podSecurityStandards: true
   
   global:
     s3:
       endpoint: "https://s3.amazonaws.com"
     postgresql:
       host: "postgres.prod.svc.cluster.local"
       user: "spark"
       password: "changeme"  # Use Sealed Secrets in prod
   
   connect:
     enabled: true
     replicas: 3  # HA
     resources:
       requests:
         memory: "4Gi"
         cpu: "2"
       limits:
         memory: "8Gi"
         cpu: "4"
     executor:
       cores: "2"
       coresLimit: "4"
       memory: "4Gi"
       memoryLimit: "8Gi"
     dynamicAllocation:
       enabled: true
       minExecutors: 2
       maxExecutors: 50
   
   hiveMetastore:
     enabled: true
     resources:
       requests:
         memory: "1Gi"
         cpu: "500m"
       limits:
         memory: "4Gi"
         cpu: "2"
   
   historyServer:
     enabled: true
     logDirectory: "s3a://prod-spark-logs/4.1/events"
     resources:
       requests:
         memory: "2Gi"
         cpu: "1"
       limits:
         memory: "8Gi"
         cpu: "4"
   
   jupyter:
     enabled: false  # Use dedicated JupyterHub in prod
   
   ingress:
     enabled: true
     hosts:
       historyServer: "spark-history-41.prod.company.com"
   ```

4. **Update README.md:**
   ```markdown
   - [Spark 4.1.0 Production Guide (EN)](docs/guides/SPARK-4.1-PRODUCTION.md)
   - [Spark 4.1.0 Production Guide (RU)](docs/guides/SPARK-4.1-PRODUCTION-RU.md)
   ```

### Expected Result

```
docs/guides/
├── SPARK-4.1-PRODUCTION.md       # ~300 LOC
└── SPARK-4.1-PRODUCTION-RU.md    # ~300 LOC

docs/examples/
└── values-spark-41-production.yaml  # ~100 LOC
```

### Scope Estimate

- Files: 3 created, 1 modified (README.md)
- Lines: ~700 LOC (MEDIUM)
- Tokens: ~3200

### Completion Criteria

```bash
# Check guides exist
ls docs/guides/SPARK-4.1-PRODUCTION*.md

# Validate production values
helm lint charts/spark-4.1 -f docs/examples/values-spark-41-production.yaml

# Test template render
helm template spark-41-prod charts/spark-4.1 \
  -f docs/examples/values-spark-41-production.yaml
```

### Constraints

- DO NOT include beginner content (refer to quickstart)
- DO NOT hardcode production credentials (use placeholders + notes)
- ENSURE all recommendations are tested
- USE realistic resource values (based on production workloads)
