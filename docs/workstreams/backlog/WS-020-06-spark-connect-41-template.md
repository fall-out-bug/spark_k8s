## WS-020-06: Spark Connect 4.1.0 Template + ConfigMaps

### 🎯 Goal

**What should WORK after WS completion:**
- Spark Connect 4.1.0 server Deployment and Service templates exist
- ConfigMaps for spark-properties.conf and executor-pod-template.yaml are created
- Configuration supports K8s native executors, dynamic allocation, Celeborn (optional)
- `helm template` renders valid K8s manifests
- Deployment uses PSS `restricted` compatible security contexts

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/templates/spark-connect.yaml` defines Deployment + Service
- [ ] `charts/spark-4.1/templates/spark-connect-configmap.yaml` defines spark-properties ConfigMap
- [ ] `charts/spark-4.1/templates/executor-pod-template-configmap.yaml` defines executor pod template
- [ ] Templates support `.Values.connect.enabled`, `.Values.celeborn.enabled`
- [ ] Security contexts use `{{ include "spark-base.podSecurityContext" . }}`
- [ ] `helm template` renders successfully with various value combinations

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 core component: Spark Connect 4.1.0 server that Data Scientists connect to from Jupyter. This WS implements the Deployment, Service, and configuration based on patterns from [aagumin/spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes).

### Dependency

WS-020-05 (chart skeleton must exist)

### Input Files

**Reference (from external repo):**
- `/home/fall_out_bug/projects/spark-connect-kubernetes/charts/spark-connect/templates/deployment.yaml`
- `/home/fall_out_bug/projects/spark-connect-kubernetes/charts/spark-connect/templates/spark-properties-cm.yaml`
- `/home/fall_out_bug/projects/spark-connect-kubernetes/charts/spark-connect/templates/executor-pod-template-cm.yaml`

**Reference (internal):**
- `charts/spark-platform/templates/spark-connect.yaml` — Existing Spark Connect 3.5.7 template
- `charts/spark-standalone/templates/_helpers.tpl` — Security context helpers

### Steps

1. **Create `charts/spark-4.1/templates/spark-connect.yaml`:**
   
   Deployment:
   - Container: `spark-custom:4.1.0`
   - Env: `SPARK_MODE=connect`, `SPARK_CONNECT_URL=sc://0.0.0.0:15002`
   - Env: S3 credentials (from spark-base Secret)
   - Env: `SPARK_CONF_DIR=/opt/spark/conf-k8s` (mount from ConfigMap)
   - Volume: ConfigMap mount for spark-properties.conf
   - Volume: ConfigMap mount for executor-pod-template.yaml
   - Security: `{{ include "spark-base.podSecurityContext" . }}`
   - Readiness probe: `grpc:15002` (if supported) or TCP probe
   
   Service:
   - Type: ClusterIP
   - Port: 15002 (gRPC)

2. **Create `charts/spark-4.1/templates/spark-connect-configmap.yaml`:**
   
   ConfigMap containing `spark-properties.conf`:
   ```properties
   spark.master=k8s://https://kubernetes.default.svc.cluster.local:443
   spark.connect.grpc.binding.port=15002
   
   # K8s executor config
   spark.kubernetes.namespace={{ .Release.Namespace }}
   spark.kubernetes.executor.podTemplateFile=/opt/spark/conf-k8s/executor-pod-template.yaml
   spark.kubernetes.executor.request.cores={{ .Values.connect.executor.cores }}
   spark.kubernetes.executor.limit.cores={{ .Values.connect.executor.coresLimit }}
   spark.kubernetes.executor.request.memory={{ .Values.connect.executor.memory }}
   spark.kubernetes.container.image=spark-custom:4.1.0
   
   # Dynamic allocation
   spark.dynamicAllocation.enabled={{ .Values.connect.dynamicAllocation.enabled }}
   spark.dynamicAllocation.shuffleTracking.enabled=true
   spark.dynamicAllocation.minExecutors={{ .Values.connect.dynamicAllocation.minExecutors }}
   spark.dynamicAllocation.maxExecutors={{ .Values.connect.dynamicAllocation.maxExecutors }}
   
   # Event log (for History Server)
   spark.eventLog.enabled=true
   spark.eventLog.dir=s3a://spark-logs/4.1/events
   
   {{- if .Values.celeborn.enabled }}
   # Celeborn shuffle
   spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager
   spark.celeborn.master.endpoints={{ .Values.celeborn.masterEndpoints }}
   spark.celeborn.push.replicate.enabled=true
   spark.celeborn.client.spark.shuffle.writer=hash
   {{- end }}
   
   # S3 config
   spark.hadoop.fs.s3a.endpoint={{ .Values.global.s3.endpoint }}
   spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID}
   spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY}
   spark.hadoop.fs.s3a.path.style.access=true
   ```

3. **Create `charts/spark-4.1/templates/executor-pod-template-configmap.yaml`:**
   
   ConfigMap containing `executor-pod-template.yaml`:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     labels:
       app: spark-executor
       spark-version: "4.1.0"
   spec:
     {{- if .Values.security.podSecurityStandards }}
     securityContext:
       {{- include "spark-base.podSecurityContext" . | nindent 6 }}
     {{- end }}
     serviceAccountName: {{ include "spark-base.serviceAccountName" . }}
     containers:
     - name: executor
       {{- if .Values.security.podSecurityStandards }}
       securityContext:
         {{- include "spark-base.containerSecurityContext" . | nindent 8 }}
       {{- end }}
       resources:
         requests:
           memory: {{ .Values.connect.executor.memory }}
           cpu: {{ .Values.connect.executor.cores }}
         limits:
           memory: {{ .Values.connect.executor.memoryLimit }}
           cpu: {{ .Values.connect.executor.coresLimit }}
       volumeMounts:
       - name: tmp
         mountPath: /tmp
       - name: spark-local
         mountPath: /opt/spark/work
     volumes:
     - name: tmp
       emptyDir: {}
     - name: spark-local
       emptyDir: {}
   ```

4. **Update `charts/spark-4.1/values.yaml` with connect section:**
   ```yaml
   connect:
     enabled: true
     replicas: 1
     image:
       repository: spark-custom
       tag: "4.1.0"
       pullPolicy: IfNotPresent
     service:
       type: ClusterIP
       port: 15002
     resources:
       requests:
         memory: "2Gi"
         cpu: "1"
       limits:
         memory: "4Gi"
         cpu: "2"
     executor:
       cores: "1"
       coresLimit: "2"
       memory: "1Gi"
       memoryLimit: "2Gi"
     dynamicAllocation:
       enabled: true
       minExecutors: 0
       maxExecutors: 10
   ```

5. **Validate:**
   ```bash
   helm template spark-41 charts/spark-4.1 \
     --set connect.enabled=true \
     --set spark-base.enabled=true
   
   # Check Celeborn config conditional
   helm template spark-41 charts/spark-4.1 \
     --set connect.enabled=true \
     --set celeborn.enabled=true \
     --set celeborn.masterEndpoints="celeborn-master:9097"
   ```

### Expected Result

```
charts/spark-4.1/templates/
├── spark-connect.yaml                    # ~180 LOC
├── spark-connect-configmap.yaml          # ~100 LOC
└── executor-pod-template-configmap.yaml  # ~80 LOC
```

### Scope Estimate

- Files: 3 created, 1 modified (values.yaml)
- Lines: ~360 new LOC (MEDIUM)
- Tokens: ~1800

### Completion Criteria

```bash
# Template render
helm template spark-41 charts/spark-4.1 --set connect.enabled=true

# Validate YAML
helm template spark-41 charts/spark-4.1 --set connect.enabled=true | kubectl apply --dry-run=client -f -

# Check ConfigMap content
helm template spark-41 charts/spark-4.1 --set connect.enabled=true | \
  grep -A 50 "kind: ConfigMap" | grep "spark.master"
```

### Constraints

- DO NOT hardcode credentials (use Secret references)
- DO NOT include Hive config here (separate template in WS-020-07)
- ENSURE PSS compliance (security contexts, emptyDir volumes)
- USE envsubst pattern for dynamic property injection (as in external repo)

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-18

#### 🎯 Goal Status

- [x] AC1: `charts/spark-4.1/templates/spark-connect.yaml` defines Deployment + Service — ✅
- [x] AC2: `charts/spark-4.1/templates/spark-connect-configmap.yaml` defines spark-properties ConfigMap — ✅
- [x] AC3: `charts/spark-4.1/templates/executor-pod-template-configmap.yaml` defines executor pod template — ✅
- [x] AC4: Templates support `.Values.connect.enabled`, `.Values.celeborn.enabled` — ✅
- [x] AC5: Security contexts use `{{ include "spark-base.podSecurityContext" . }}` — ✅
- [x] AC6: `helm template` renders successfully with value combinations — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/templates/spark-connect.yaml` | added | 104 |
| `charts/spark-4.1/templates/spark-connect-configmap.yaml` | added | 44 |
| `charts/spark-4.1/templates/executor-pod-template-configmap.yaml` | added | 45 |
| `charts/spark-4.1/values.yaml` | modified | 158 |

**Total:** 3 added, 1 modified, 351 LOC

#### Completed Steps

- [x] Step 1: Added `spark-connect.yaml` Deployment + Service with envsubst flow
- [x] Step 2: Added `spark-connect-configmap.yaml` with spark-properties template
- [x] Step 3: Added executor pod template ConfigMap (PSS + emptyDir)
- [x] Step 4: Updated `values.yaml` connect/executor/dynamicAllocation and global s3
- [x] Step 5: Rendered templates for default and Celeborn-enabled configs

#### Self-Check Results

```bash
$ helm template spark-41 charts/spark-4.1 --set connect.enabled=true --set spark-base.enabled=true
rendered successfully

$ helm template spark-41 charts/spark-4.1 --set connect.enabled=true \
  --set celeborn.enabled=true --set celeborn.masterEndpoints="celeborn-master:9097"
rendered successfully

$ helm template spark-41 charts/spark-4.1 --set connect.enabled=true | \
  kubectl apply --dry-run=client -f -
configmap/spark-41-spark-41-executor-pod-template created (dry run)
configmap/spark-41-spark-41-connect-config created (dry run)
service/spark-41-spark-41-connect created (dry run)
deployment.apps/spark-41-spark-41-connect created (dry run)
```

#### Issues

- None
