## WS-020-11: Celeborn Chart (Disaggregated Shuffle Service)

### 🎯 Goal

**What should WORK after WS completion:**
- Helm chart `charts/celeborn/` exists with masters and workers StatefulSets
- Chart can be deployed standalone or as dependency of `spark-4.1`
- Workers use persistent storage for shuffle data
- `helm lint charts/celeborn` passes

**Acceptance Criteria:**
- [ ] `charts/celeborn/Chart.yaml` defines chart metadata
- [ ] `charts/celeborn/values.yaml` contains configuration (masters, workers, storage)
- [ ] `charts/celeborn/templates/master-statefulset.yaml` defines Celeborn master (3 replicas for HA)
- [ ] `charts/celeborn/templates/worker-statefulset.yaml` defines Celeborn workers with PVC
- [ ] `charts/celeborn/templates/configmap.yaml` contains Celeborn configuration
- [ ] `helm lint charts/celeborn` passes

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 includes Celeborn as optional disaggregated shuffle service for Spark 4.1.0. Celeborn improves stability and performance for large shuffle operations by decoupling shuffle data from executor lifecycle.

### Dependency

Independent (standalone chart)

### Input Files

**Reference:**
- [Apache Celeborn Documentation](https://celeborn.apache.org/docs/latest/)
- `/home/fall_out_bug/projects/spark-connect-kubernetes/charts/spark-connect/values.yaml` — Celeborn config example

### Steps

1. **Create directory:**
   ```bash
   mkdir -p charts/celeborn/templates
   ```

2. **Create `charts/celeborn/Chart.yaml`:**
   ```yaml
   apiVersion: v2
   name: celeborn
   version: 0.1.0
   appVersion: "0.6.1"
   description: Apache Celeborn - Disaggregated shuffle service for Apache Spark
   ```

3. **Create `charts/celeborn/values.yaml`:**
   ```yaml
   master:
     replicas: 3
     image:
       repository: apache/celeborn
       tag: "0.6.1"
       pullPolicy: IfNotPresent
     service:
       port: 9097
     resources:
       requests:
         memory: "1Gi"
         cpu: "500m"
       limits:
         memory: "2Gi"
         cpu: "1"
   
   worker:
     replicas: 3
     image:
       repository: apache/celeborn
       tag: "0.6.1"
       pullPolicy: IfNotPresent
     service:
       port: 9098
     storage:
       size: "100Gi"
       storageClass: "standard"
     resources:
       requests:
         memory: "2Gi"
         cpu: "1"
       limits:
         memory: "8Gi"
         cpu: "4"
   
   security:
     podSecurityStandards: false
   ```

4. **Create `charts/celeborn/templates/master-statefulset.yaml`:**
   ```yaml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: {{ include "celeborn.fullname" . }}-master
   spec:
     serviceName: {{ include "celeborn.fullname" . }}-master
     replicas: {{ .Values.master.replicas }}
     selector:
       matchLabels:
         app: celeborn-master
     template:
       metadata:
         labels:
           app: celeborn-master
       spec:
         containers:
         - name: master
           image: "{{ .Values.master.image.repository }}:{{ .Values.master.image.tag }}"
           command:
           - /opt/celeborn/sbin/start-master.sh
           ports:
           - containerPort: 9097
             name: rpc
           volumeMounts:
           - name: config
             mountPath: /opt/celeborn/conf
           resources:
             {{- toYaml .Values.master.resources | nindent 12 }}
         volumes:
         - name: config
           configMap:
             name: {{ include "celeborn.fullname" . }}-config
   ```

5. **Create `charts/celeborn/templates/worker-statefulset.yaml`:**
   ```yaml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: {{ include "celeborn.fullname" . }}-worker
   spec:
     serviceName: {{ include "celeborn.fullname" . }}-worker
     replicas: {{ .Values.worker.replicas }}
     selector:
       matchLabels:
         app: celeborn-worker
     template:
       metadata:
         labels:
           app: celeborn-worker
       spec:
         containers:
         - name: worker
           image: "{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag }}"
           command:
           - /opt/celeborn/sbin/start-worker.sh
           env:
           - name: CELEBORN_MASTER_ENDPOINTS
             value: "{{ include "celeborn.fullname" . }}-master-0:9097,{{ include "celeborn.fullname" . }}-master-1:9097,{{ include "celeborn.fullname" . }}-master-2:9097"
           ports:
           - containerPort: 9098
             name: rpc
           volumeMounts:
           - name: config
             mountPath: /opt/celeborn/conf
           - name: shuffle-data
             mountPath: /mnt/celeborn
           resources:
             {{- toYaml .Values.worker.resources | nindent 12 }}
         volumes:
         - name: config
           configMap:
             name: {{ include "celeborn.fullname" . }}-config
     volumeClaimTemplates:
     - metadata:
         name: shuffle-data
       spec:
         accessModes: ["ReadWriteOnce"]
         storageClassName: {{ .Values.worker.storage.storageClass }}
         resources:
           requests:
             storage: {{ .Values.worker.storage.size }}
   ```

6. **Create `charts/celeborn/templates/configmap.yaml`:**
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: {{ include "celeborn.fullname" . }}-config
   data:
     celeborn-defaults.conf: |
       celeborn.master.host 0.0.0.0
       celeborn.master.port 9097
       celeborn.worker.storage.dirs /mnt/celeborn
       celeborn.worker.monitor.disk.enabled true
   ```

7. **Create Services:**
   - Headless service for master StatefulSet
   - Headless service for worker StatefulSet

8. **Validate:**
   ```bash
   helm lint charts/celeborn
   helm template celeborn charts/celeborn
   ```

### Expected Result

```
charts/celeborn/
├── Chart.yaml                    # ~10 LOC
├── values.yaml                   # ~80 LOC
└── templates/
    ├── _helpers.tpl              # ~40 LOC
    ├── master-statefulset.yaml   # ~100 LOC
    ├── master-service.yaml       # ~30 LOC
    ├── worker-statefulset.yaml   # ~120 LOC
    ├── worker-service.yaml       # ~30 LOC
    └── configmap.yaml            # ~30 LOC
```

### Scope Estimate

- Files: 8 created
- Lines: ~440 LOC (MEDIUM)
- Tokens: ~1900

### Completion Criteria

```bash
# Lint
helm lint charts/celeborn

# Template render
helm template celeborn charts/celeborn

# Validate YAML
helm template celeborn charts/celeborn | kubectl apply --dry-run=client -f -

# Check StatefulSet PVCs
helm template celeborn charts/celeborn | grep "volumeClaimTemplates"
```

### Constraints

- DO NOT include Spark-specific config (handled in spark-4.1 chart)
- DO NOT create ClusterRole (namespace-scoped only)
- ENSURE workers use persistent storage (StatefulSet + PVC)
- USE headless services for StatefulSet DNS
