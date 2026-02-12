# DataOps Persona Path

This guide provides a complete learning path for DataOps engineers working with Spark on Kubernetes.

## Overview

The DataOps persona is responsible for:
- Deploying and managing Spark workloads
- Implementing CI/CD pipelines
- Monitoring and observability
- Data quality and validation
- Backup and disaster recovery

## Learning Path

```
┌─────────────────────────────────────────────────────────────────┐
│                     DataOps Learning Path                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1-2: Spark on Kubernetes Fundamentals                     │
│  ├─ Architecture Overview                                      │
│  ├─ Deploying First Job                                        │
│  └─ Basic Troubleshooting                                     │
│                                                                 │
│  Day 3-4: Production Deployment                                │
│  ├─ Helm Charts and Values                                    │
│  ├─ Resource Sizing                                           │
│  ├─ Secrets and Configuration                                 │
│  └─ Multi-environment Setup                                   │
│                                                                 │
│  Day 5-6: CI/CD Integration                                    │
│  ├─ GitHub Actions Workflows                                  │
│  ├─ Automated Testing                                         │
│  ├─ Deployment Automation                                     │
│  └─ Rollback Procedures                                       │
│                                                                 │
│  Day 7-8: Monitoring & Observability                          │
│  ├─ Prometheus Metrics                                        │
│  ├─ Grafana Dashboards                                        │
│  ├─ Alerting                                                  │
│  └─ Log Aggregation                                          │
│                                                                 │
│  Day 9: Data Quality                                           │
│  ├─ Quality Gates                                             │
│  ├─ Great Expectations                                        │
│  ├─ Validation Rules                                         │
│  └─ Quarantine Procedures                                     │
│                                                                 │
│  Day 10: Backup & Disaster Recovery                           │
│  ├─ Backup Strategies                                         │
│  ├─ Recovery Procedures                                       │
│  ├─ DR Drills                                                │
│  └─ RTO/RPO Targets                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Part 1: Spark on Kubernetes Fundamentals (Days 1-2)

### 1.1 Architecture Overview

**Objectives:**
- Understand Spark Operator architecture
- Know key components and their roles
- Understand data flow in Spark on K8s

**Key Concepts:**
```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Spark Operator│  │    Driver    │  │   Executors   │     │
│  │   (Control)   │  │   (Pod #1)   │  │  (Pods #2-N)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                │
│                   ┌────────▼────────┐                      │
│                   │  Shared Storage │                      │
│                   │   (S3/GCS/ADLS) │                      │
│                   └─────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

**Hands-on:**
```bash
# Install Spark Operator
helm install spark-operator spark-operator \
  --namespace spark-operator --create-namespace

# Deploy first job
kubectl apply -f examples/spark-pi.yaml

# Watch execution
kubectl get sparkapplication -w

# View logs
kubectl logs -l spark-app-name=spark-pi,spark-role=driver --follow
```

### 1.2 Deploying Your First Job

**Exercise:** Deploy a sample ETL job

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: hello-world-etl
spec:
  type: Python
  mode: cluster
  image: spark:3.5.0
  mainApplicationFile: local:///app/hello.py
  sparkVersion: "3.5.0"
  driver:
    cores: 1
    memory: "1g"
  executor:
    cores: 1
    instances: 2
    memory: "1g"
```

### 1.3 Basic Troubleshooting

**Common issues:**
1. Pod pending → Check resource requests
2. OOM killed → Increase memory
3. Image pull error → Check registry credentials

**Debug commands:**
```bash
# Check pod status
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# View Spark UI
kubectl port-forward <driver-pod> 4040:4040
```

## Part 2: Production Deployment (Days 3-4)

### 2.1 Helm Charts

**Best practices:**
```yaml
# values.yaml per environment
environments:
  dev:
    replicas: 1
    resources:
      executor:
        memory: "2g"
        cores: 2

  prod:
    replicas: 3
    resources:
      executor:
        memory: "8g"
        cores: 4
```

### 2.2 Resource Sizing

**Formula:**
```
Executor Memory = (Data per partition) × (Partitions per core) × (Cores) + Overhead
```

**Tool:**
```bash
./scripts/operations/calculate-resources.sh \
  --data-size 1TB \
  --output resource-config.yaml
```

### 2.3 Secrets Management

**Pattern:**
```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: aws-credentials
  data:
    - secretKey: access-key-id
      remoteRef:
        key: prod/spark/access-key-id
```

## Part 3: CI/CD Integration (Days 5-6)

### 3.1 Pipeline Stages

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Build  │───▶│  Test   │───▶│ Deploy  │───▶│ Monitor │
│  Image  │    │  Stage  │    │  Prod   │    │  & Alert│
└─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### 3.2 Quality Gates

```yaml
# .github/workflows/deploy-spark-job.yml
name: Deploy Spark Job

on:
  push:
    paths:
      - 'jobs/my-job/**'

jobs:
  deploy:
    steps:
      - name: Lint
        run: ./scripts/cicd/lint-python.sh --dir jobs/my-job

      - name: Test
        run: pytest tests/jobs/test_my_job.py

      - name: Security Scan
        run: ./scripts/cicd/scan-dependencies.sh --project-dir jobs/my-job

      - name: Dry-run
        run: helm template my-job charts/spark-job --values values/prod.yaml

      - name: Deploy
        if: github.ref == 'refs/heads/main'
        run: helm upgrade --install my-job charts/spark-job --values values/prod.yaml
```

## Part 4: Monitoring & Observability (Days 7-8)

### 4.1 Key Metrics Dashboard

Create a dashboard showing:
- Job success rate
- Average duration
- Resource utilization
- Cost per job
- Data quality scores

### 4.2 Alerting Rules

```yaml
# Critical alerts
- alert: SparkJobFailed
  expr: spark_job_status == 2
  for: 1m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/job-failure.md"

# Warning alerts
- alert: HighGCTime
  expr: rate(jvm_gc_time_seconds[5m]) * 100 > 20
  for: 10m
  labels:
    severity: warning
```

## Part 5: Data Quality (Day 9)

### 5.1 Quality Gates

```python
# Quality gate in CI/CD
def quality_gate(spark, table_path):
    """Run data quality checks."""
    # 1. Row count check
    count = spark.read.parquet(table_path).count()
    assert count > 0, "Table is empty!"

    # 2. Schema validation
    schema = spark.read.parquet(table_path).schema
    assert "id" in schema.fieldNames(), "Missing id column"

    # 3. Null checks
    nulls = spark.read.parquet(table_path).filter(col("id").isNull()).count()
    assert nulls == 0, "Null IDs found!"

    # 4. Freshness check
    latest = spark.read.parquet(table_path).agg(max("timestamp")).collect()[0][0]
    age_hours = (datetime.now() - latest).total_seconds() / 3600
    assert age_hours < 24, f"Data is {age_hours}h old!"

    return True
```

### 5.2 Great Expectations

```python
import great_expectations as ge

# Define expectations
batch_kwargs = {"datasource": "spark_data", "path": "s3a://data/output"}
validator = context.get_validator(
    batch_kwargs=batch_kwargs,
    expectation_suite=suite
)

# Validate
results = validator.validate()

if not results["success"]:
    # Quarantine data
    quarantine_path = f"s3a://quarantine/{datetime.now().isoformat()}/"
    df.write.parquet(quarantine_path)
    raise Exception("Data quality validation failed")
```

## Part 6: Backup & Disaster Recovery (Day 10)

### 6.1 Backup Strategy

```yaml
# Daily backup of critical data
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: data-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: aws-cli:latest
            command:
            - /bin/bash
            - -c
            - |
              # Backup to another region
              aws s3 sync s3://prod-data/ s3://prod-data-backup/$(date +%Y%m%d)/ \
                --storage-class GLACIER
```

### 6.2 Recovery Procedures

```bash
# Restore from backup
./scripts/operations/disaster-recovery.sh \
  --backup-date 2024-01-15 \
  --target-namespace spark-prod-restored \
  --verify
```

### 6.3 DR Drills

**Monthly drill checklist:**
- [ ] Failover to backup region
- [ ] Verify data integrity
- [ ] Test all critical jobs
- [ ] Measure RTO/RPO
- [ ] Document lessons learned

## Skills Checklist

By the end of this path, you should be able to:

### Deployment
- [ ] Deploy Spark applications using Helm
- [ ] Configure resources appropriately
- [ ] Manage secrets securely
- [ ] Handle multi-environment deployments

### CI/CD
- [ ] Build deployment pipelines
- [ ] Implement quality gates
- [ ] Automate testing
- [ ] Handle rollback scenarios

### Monitoring
- [ ] Set up Prometheus metrics
- [ ] Create Grafana dashboards
- [ ] Configure alerts
- [ ] Troubleshoot common issues

### Data Quality
- [ ] Define quality expectations
- [ ] Implement validation rules
- [ ] Handle quarantine data
- [ ] Track quality metrics

### Backup/DR
- [ ] Design backup strategy
- [ ] Implement recovery procedures
- [ ] Conduct DR drills
- [ ] Meet RTO/RPO targets

## Resources

- [Deployment Guide](../deployment/index.md)
- [CI/CD Best Practices](../operations/procedures/cicd/)
- [Monitoring Setup](../guides/monitoring/setup-guide.md)
- [Data Quality Tutorial](../tutorials/workflows/data-quality.md)
- [Backup Procedures](../operations/procedures/disaster-recovery.md)

## Assessment

Complete these exercises to verify your knowledge:

1. **Deployment**: Deploy a sample job with proper resource sizing
2. **CI/CD**: Create a GitHub Actions workflow for your job
3. **Monitoring**: Set up a dashboard showing job metrics
4. **Quality**: Implement a quality gate for your data
5. **DR**: Simulate a failure and recover from backup

## Next Steps

After completing this path:
1. Explore [Advanced Workflows](./ws-019-08-advanced.md)
2. Learn [Cost Optimization](../tutorials/workflows/cost-optimization.md)
3. Study [Performance Tuning](../guides/performance/)
