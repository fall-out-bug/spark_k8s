## WS-020-12: Spark Operator Chart (CRDs + Operator Deployment)

### 🎯 Goal

**What should WORK after WS completion:**
- Helm chart `charts/spark-operator/` exists with CRD and operator deployment
- Operator manages `SparkApplication` CRDs
- Operator supports Spark 4.1.0 images
- `helm lint charts/spark-operator` passes

**Acceptance Criteria:**
- [ ] `charts/spark-operator/Chart.yaml` defines chart metadata
- [ ] `charts/spark-operator/values.yaml` contains operator configuration
- [ ] `charts/spark-operator/templates/crds/sparkapplication-crd.yaml` defines SparkApplication CRD
- [ ] `charts/spark-operator/templates/operator-deployment.yaml` defines operator Deployment
- [ ] `charts/spark-operator/templates/rbac.yaml` defines operator RBAC (ClusterRole for CRD management)
- [ ] `helm lint charts/spark-operator` passes

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 includes Spark Operator as optional component for declarative Spark job management via Kubernetes CRDs. This enables DataOps to define Spark jobs as YAML manifests.

### Dependency

Independent (standalone chart)

### Input Files

**Reference:**
- [Spark Operator Documentation](https://googlecloudplatform.github.io/spark-on-k8s-operator/)
- [Spark Operator Helm Chart](https://github.com/googlecloudplatform/spark-on-k8s-operator/tree/master/charts/spark-operator-chart)

### Steps

1. **Create directory:**
   ```bash
   mkdir -p charts/spark-operator/templates/crds
   ```

2. **Create `charts/spark-operator/Chart.yaml`:**
   ```yaml
   apiVersion: v2
   name: spark-operator
   version: 0.1.0
   appVersion: "v1beta2-1.3.8-3.1.1"
   description: Kubernetes Operator for Apache Spark
   ```

3. **Create `charts/spark-operator/values.yaml`:**
   ```yaml
   image:
     repository: gcr.io/spark-operator/spark-operator
     tag: "v1beta2-1.3.8-3.1.1"
     pullPolicy: IfNotPresent
   
   replicas: 1
   
   sparkJobNamespace: "default"
   
   webhook:
     enable: true
     port: 8080
   
   resources:
     requests:
       memory: "256Mi"
       cpu: "100m"
     limits:
       memory: "512Mi"
       cpu: "500m"
   
   rbac:
     create: true
   ```

4. **Create `charts/spark-operator/templates/crds/sparkapplication-crd.yaml`:**
   
   Download official CRD from Spark Operator repository:
   ```bash
   curl -o charts/spark-operator/templates/crds/sparkapplication-crd.yaml \
     https://raw.githubusercontent.com/googlecloudplatform/spark-on-k8s-operator/master/charts/spark-operator-chart/crds/sparkoperator.k8s.io_sparkapplications.yaml
   ```
   
   Add Helm conditional:
   ```yaml
   {{- if .Values.rbac.create }}
   # ... CRD content ...
   {{- end }}
   ```

5. **Create `charts/spark-operator/templates/operator-deployment.yaml`:**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: {{ include "spark-operator.fullname" . }}
   spec:
     replicas: {{ .Values.replicas }}
     selector:
       matchLabels:
         app: spark-operator
     template:
       metadata:
         labels:
           app: spark-operator
       spec:
         serviceAccountName: {{ include "spark-operator.serviceAccountName" . }}
         containers:
         - name: spark-operator
           image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
           args:
           - -v=2
           - -namespace={{ .Values.sparkJobNamespace }}
           - -enable-webhook={{ .Values.webhook.enable }}
           - -webhook-svc-name={{ include "spark-operator.fullname" . }}-webhook
           - -webhook-svc-namespace={{ .Release.Namespace }}
           ports:
           - containerPort: 10254
             name: metrics
           {{- if .Values.webhook.enable }}
           - containerPort: {{ .Values.webhook.port }}
             name: webhook
           {{- end }}
           resources:
             {{- toYaml .Values.resources | nindent 12 }}
   ```

6. **Create `charts/spark-operator/templates/rbac.yaml`:**
   
   ClusterRole (operator needs cluster-wide permissions for CRDs):
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: {{ include "spark-operator.fullname" . }}
   rules:
   - apiGroups: [""]
     resources: ["pods", "services", "configmaps"]
     verbs: ["create", "get", "list", "watch", "delete", "update", "patch"]
   - apiGroups: ["sparkoperator.k8s.io"]
     resources: ["sparkapplications", "scheduledsparkapplications"]
     verbs: ["create", "get", "list", "watch", "delete", "update", "patch"]
   - apiGroups: ["sparkoperator.k8s.io"]
     resources: ["sparkapplications/status", "scheduledsparkapplications/status"]
     verbs: ["update", "patch"]
   ```

7. **Create webhook Service (if enabled):**
   ```yaml
   {{- if .Values.webhook.enable }}
   apiVersion: v1
   kind: Service
   metadata:
     name: {{ include "spark-operator.fullname" . }}-webhook
   spec:
     ports:
     - port: 443
       targetPort: {{ .Values.webhook.port }}
     selector:
       app: spark-operator
   {{- end }}
   ```

8. **Validate:**
   ```bash
   helm lint charts/spark-operator
   helm template spark-operator charts/spark-operator
   ```

### Expected Result

```
charts/spark-operator/
├── Chart.yaml                              # ~10 LOC
├── values.yaml                             # ~60 LOC
└── templates/
    ├── _helpers.tpl                        # ~40 LOC
    ├── crds/
    │   └── sparkapplication-crd.yaml       # ~500 LOC (from upstream)
    ├── operator-deployment.yaml            # ~120 LOC
    ├── rbac.yaml                           # ~100 LOC
    └── webhook-service.yaml                # ~30 LOC
```

### Scope Estimate

- Files: 7 created
- Lines: ~860 LOC (MEDIUM, but most is CRD YAML from upstream)
- Tokens: ~3500

### Completion Criteria

```bash
# Lint
helm lint charts/spark-operator

# Template render
helm template spark-operator charts/spark-operator

# Validate YAML
helm template spark-operator charts/spark-operator | kubectl apply --dry-run=client -f -

# Check CRD exists
helm template spark-operator charts/spark-operator | grep "kind: CustomResourceDefinition"
```

### Constraints

- DO NOT modify upstream CRD (use official version)
- DO NOT create namespace-scoped Role (operator needs ClusterRole)
- ENSURE webhook is optional (configurable)
- USE official Spark Operator image (no custom build)
