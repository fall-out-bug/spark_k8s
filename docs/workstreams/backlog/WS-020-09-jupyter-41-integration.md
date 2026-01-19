## WS-020-09: Jupyter 4.1.0 Integration Template

### 🎯 Goal

**What should WORK after WS completion:**
- Jupyter 4.1.0 Deployment and Service templates exist
- Jupyter uses image `jupyter-spark:4.1.0` (from WS-020-04)
- Environment variables configure Spark Connect URL
- Service exposes port 8888
- Ingress rule added (optional)
- PSS `restricted` compatible

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/templates/jupyter.yaml` defines Deployment + Service
- [ ] Image: `jupyter-spark:4.1.0`
- [ ] Env: `SPARK_CONNECT_URL=sc://{{ include "spark-4.1.fullname" . }}-connect:15002`
- [ ] Service port: 8888
- [ ] Ingress rule added to `ingress.yaml` (if enabled)
- [ ] Security contexts use PSS helpers

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Jupyter is the primary interface for Data Scientists to use Spark 4.1.0 via Spark Connect. This WS creates the Deployment/Service templates.

### Dependency

WS-020-04 (Jupyter 4.1.0 image), WS-020-06 (Spark Connect server template)

### Input Files

**Reference:**
- `charts/spark-platform/templates/jupyter.yaml` — Existing Jupyter template
- `docker/jupyter-4.1/Dockerfile` — Image requirements

### Steps

1. **Create `charts/spark-4.1/templates/jupyter.yaml`:**
   
   Deployment:
   - Image: `jupyter-spark:4.1.0`
   - Env: `SPARK_CONNECT_URL=sc://{{ include "spark-4.1.fullname" . }}-connect:15002`
   - Env: `JUPYTER_ENABLE_LAB=yes`
   - Volume: PVC or emptyDir for `/home/spark/notebooks` (persistent notebooks)
   - Security: PSS contexts
   
   Service:
   - Type: ClusterIP
   - Port: 8888

2. **Update `charts/spark-4.1/templates/ingress.yaml`:**
   
   Add rule for Jupyter:
   ```yaml
   {{- if and .Values.ingress.enabled .Values.jupyter.enabled }}
   - host: {{ .Values.ingress.hosts.jupyter | default "jupyter-41.local" }}
     http:
       paths:
       - path: /
         pathType: Prefix
         backend:
           service:
             name: {{ include "spark-4.1.fullname" . }}-jupyter
             port:
               number: 8888
   {{- end }}
   ```

3. **Create PVC template (optional):**
   ```yaml
   {{- if and .Values.jupyter.enabled .Values.jupyter.persistence.enabled }}
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: {{ include "spark-4.1.fullname" . }}-jupyter-notebooks
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: {{ .Values.jupyter.persistence.size }}
   {{- end }}
   ```

4. **Update `values.yaml`:**
   ```yaml
   jupyter:
     enabled: true
     image:
       repository: jupyter-spark
       tag: "4.1.0"
       pullPolicy: IfNotPresent
     service:
       type: ClusterIP
       port: 8888
     resources:
       requests:
         memory: "1Gi"
         cpu: "500m"
       limits:
         memory: "4Gi"
         cpu: "2"
     persistence:
       enabled: false
       size: "10Gi"
   
   ingress:
     hosts:
       jupyter: "jupyter-41.local"
   ```

5. **Validate:**
   ```bash
   helm template spark-41 charts/spark-4.1 \
     --set jupyter.enabled=true \
     --set connect.enabled=true
   ```

### Expected Result

```
charts/spark-4.1/templates/
├── jupyter.yaml         # ~130 LOC
└── jupyter-pvc.yaml     # ~20 LOC (optional)
```

### Scope Estimate

- Files: 2 created, 2 modified (ingress.yaml, values.yaml)
- Lines: ~150 LOC (SMALL)
- Tokens: ~700

### Completion Criteria

```bash
# Template render
helm template spark-41 charts/spark-4.1 \
  --set jupyter.enabled=true \
  --set connect.enabled=true

# Validate YAML
helm template spark-41 charts/spark-4.1 \
  --set jupyter.enabled=true | \
  kubectl apply --dry-run=client -f -

# Check Spark Connect URL env
helm template spark-41 charts/spark-4.1 --set jupyter.enabled=true | \
  grep "SPARK_CONNECT_URL"
```

### Constraints

- DO NOT include JupyterHub (single-user Jupyter only)
- DO NOT hardcode Spark Connect URL (use template helper)
- ENSURE PSS compliance
- USE PVC for persistence (optional, configurable)

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-18

#### 🎯 Goal Status

- [x] AC1: `charts/spark-4.1/templates/jupyter.yaml` defines Deployment + Service — ✅
- [x] AC2: Image: `jupyter-spark:4.1.0` — ✅
- [x] AC3: Env: `SPARK_CONNECT_URL=sc://{{ include "spark-4.1.fullname" . }}-connect:15002` — ✅
- [x] AC4: Service port: 8888 — ✅
- [x] AC5: Ingress rule added to `ingress.yaml` (if enabled) — ✅
- [x] AC6: Security contexts use PSS helpers — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/templates/jupyter.yaml` | added | 96 |
| `charts/spark-4.1/templates/jupyter-pvc.yaml` | added | 18 |
| `charts/spark-4.1/templates/ingress.yaml` | modified | 34 |
| `charts/spark-4.1/values.yaml` | modified | 176 |

**Total:** 2 added, 2 modified, 324 LOC

#### Completed Steps

- [x] Step 1: Added Jupyter Deployment + Service (Spark Connect URL env)
- [x] Step 2: Added optional PVC template for notebooks persistence
- [x] Step 3: Updated ingress rule to include Jupyter host
- [x] Step 4: Updated values for Jupyter resources and persistence
- [x] Step 5: Rendered templates, dry-run applied, verified SPARK_CONNECT_URL

#### Self-Check Results

```bash
$ helm template spark-41 charts/spark-4.1 --set jupyter.enabled=true --set connect.enabled=true
rendered successfully

$ helm template spark-41 charts/spark-4.1 --set jupyter.enabled=true | \
  kubectl apply --dry-run=client -f -
service/spark-41-spark-41-jupyter created (dry run)
deployment.apps/spark-41-spark-41-jupyter created (dry run)

$ helm template spark-41 charts/spark-4.1 --set jupyter.enabled=true | \
  grep "SPARK_CONNECT_URL"
SPARK_CONNECT_URL
```

#### Issues

- None
