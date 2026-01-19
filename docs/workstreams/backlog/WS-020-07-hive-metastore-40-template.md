## WS-020-07: Hive Metastore 4.0.0 Template

### 🎯 Goal

**What should WORK after WS completion:**
- Hive Metastore 4.0.0 Deployment and Service templates exist for Spark 4.1.0
- Metastore uses PostgreSQL backend (from spark-base or external)
- Configuration is isolated from Spark 3.5.7 Metastore (separate database)
- PSS `restricted` compatible
- `helm template` renders valid manifests

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/templates/hive-metastore.yaml` defines Deployment + Service
- [ ] Metastore image: `apache/hive:4.0.0` (or custom if needed)
- [ ] PostgreSQL database name: `metastore_spark41` (isolated from 3.5.7)
- [ ] Service exposes port 9083
- [ ] Init job creates schema (`schematool -dbType postgres -initSchema`)
- [ ] Security contexts use `{{ include "spark-base.podSecurityContext" . }}`

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Spark 4.1.0 requires Hive Metastore 4.0.0 for table metadata. This must be isolated from the Spark 3.5.7 Metastore (3.1.3) to avoid version conflicts. No automatic migration is provided.

### Dependency

WS-020-05 (chart skeleton)

### Input Files

**Reference:**
- `charts/spark-standalone/templates/hive-metastore.yaml` — Existing Metastore 3.1.3 template
- `charts/spark-standalone/templates/postgresql-metastore.yaml` — PostgreSQL pattern

### Steps

1. **Create `charts/spark-4.1/templates/hive-metastore.yaml`:**
   
   Deployment:
   - Image: `apache/hive:4.0.0`
   - Env: `DB_DRIVER=postgres`, `SERVICE_NAME=metastore`
   - Env: PostgreSQL connection (`POSTGRES_HOST`, `POSTGRES_DB=metastore_spark41`)
   - Volume: ConfigMap mount for `hive-site.xml`
   - Security: PSS compliance
   
   Service:
   - Port: 9083

   Init Job (Helm hook `post-install,post-upgrade`):
   - Run `schematool -dbType postgres -initSchema` (idempotent with `--ifNotExists`)

2. **Create ConfigMap for `hive-site.xml`:**
   ```xml
   <configuration>
     <property>
       <name>hive.metastore.warehouse.dir</name>
       <value>s3a://spark-data/warehouse/4.1</value>
     </property>
     <property>
       <name>hive.metastore.uris</name>
       <value>thrift://{{ include "spark-4.1.fullname" . }}-metastore:9083</value>
     </property>
     <property>
       <name>javax.jdo.option.ConnectionURL</name>
       <value>jdbc:postgresql://{{ .Values.global.postgresql.host }}/metastore_spark41</value>
     </property>
     <property>
       <name>javax.jdo.option.ConnectionDriverName</name>
       <value>org.postgresql.Driver</value>
     </property>
     <property>
       <name>javax.jdo.option.ConnectionUserName</name>
       <value>{{ .Values.global.postgresql.user }}</value>
     </property>
     <property>
       <name>javax.jdo.option.ConnectionPassword</name>
       <value>{{ .Values.global.postgresql.password }}</value>
     </property>
   </configuration>
   ```

3. **Update `values.yaml`:**
   ```yaml
   hiveMetastore:
     enabled: true
     image:
       repository: apache/hive
       tag: "4.0.0"
       pullPolicy: IfNotPresent
     service:
       type: ClusterIP
       port: 9083
     resources:
       requests:
         memory: "512Mi"
         cpu: "200m"
       limits:
         memory: "2Gi"
         cpu: "1000m"
     database:
       name: "metastore_spark41"
   ```

4. **Validate:**
   ```bash
   helm template spark-41 charts/spark-4.1 \
     --set hiveMetastore.enabled=true \
     --set spark-base.postgresql.enabled=true
   ```

### Expected Result

```
charts/spark-4.1/templates/
├── hive-metastore.yaml          # ~150 LOC
└── hive-metastore-configmap.yaml # ~60 LOC
```

### Scope Estimate

- Files: 2 created, 1 modified (values.yaml)
- Lines: ~210 LOC (SMALL)
- Tokens: ~900

### Completion Criteria

```bash
# Template render
helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true

# Validate YAML
helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true | \
  kubectl apply --dry-run=client -f -

# Check database isolation
helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true | \
  grep "metastore_spark41"
```

### Constraints

- DO NOT include migration scripts (out of scope per F04 draft)
- DO NOT reuse Spark 3.5.7 database (must be isolated: `metastore_spark41`)
- ENSURE init job is idempotent (`--ifNotExists` flag for schematool)
- USE PSS-compatible security contexts

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-18

#### 🎯 Goal Status

- [x] AC1: `charts/spark-4.1/templates/hive-metastore.yaml` defines Deployment + Service — ✅
- [x] AC2: Metastore image: `apache/hive:4.0.0` — ✅
- [x] AC3: PostgreSQL database name: `metastore_spark41` — ✅
- [x] AC4: Service exposes port 9083 — ✅
- [x] AC5: Init job creates schema (`schematool -dbType postgres -initSchema --ifNotExists`) — ✅
- [x] AC6: Security contexts use `{{ include "spark-base.podSecurityContext" . }}` — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/templates/hive-metastore.yaml` | added | 170 |
| `charts/spark-4.1/templates/hive-metastore-configmap.yaml` | added | 67 |
| `charts/spark-4.1/values.yaml` | modified | 165 |

**Total:** 2 added, 1 modified, 402 LOC

#### Completed Steps

- [x] Step 1: Added Hive Metastore Deployment + Service with init Job hook
- [x] Step 2: Added hive-site.xml ConfigMap template
- [x] Step 3: Updated values with metastore DB isolation (`metastore_spark41`) and global postgres
- [x] Step 4: Rendered templates and dry-run applied manifests

#### Self-Check Results

```bash
$ helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true --set spark-base.postgresql.enabled=true
rendered successfully

$ helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true | \
  kubectl apply --dry-run=client -f -
secret/spark-41-spark-41-metastore-db created (dry run)
configmap/spark-41-spark-41-hive-metastore-config created (dry run)
service/spark-41-spark-41-metastore created (dry run)
deployment.apps/spark-41-spark-41-metastore created (dry run)
job.batch/spark-41-spark-41-metastore-init created (dry run)

$ helm template spark-41 charts/spark-4.1 --set hiveMetastore.enabled=true | grep metastore_spark41
... metastore_spark41 ...
```

#### Issues

- None
