## WS-012-01: History Server Template

### 🎯 Goal

**What should WORK after WS completion:**
- Spark History Server Deployment + Service deployed when `historyServer.enabled: true`
- History Server connects to S3 event logs and serves UI on port 18080
- Ingress rule added for History Server (optional host)

**Acceptance Criteria:**
- [ ] `helm template` renders history-server Deployment/Service when enabled
- [ ] History Server pod starts without errors (`kubectl logs`)
- [ ] UI accessible on port 18080 via port-forward
- [ ] `helm lint` passes

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

The `spark-standalone` chart configures Spark applications to write event logs to S3 (`spark.eventLog.enabled=true`), but there is no component to visualize these logs. This WS adds an optional Spark History Server deployment.

The `spark-custom` image already supports `SPARK_MODE=history` (see `docker/spark/entrypoint.sh` lines 112-128).

### Dependency

Independent (but logically follows F01: Spark Standalone)

### Input Files

- `charts/spark-standalone/values.yaml` — existing `historyServer` section (needs expansion)
- `charts/spark-standalone/templates/ingress.yaml` — add rule for history server
- `charts/spark-standalone/templates/_helpers.tpl` — reuse security context helpers
- `docker/spark/entrypoint.sh` — reference for `SPARK_MODE=history` env vars

### Steps

1. **Update `values.yaml`** — expand `historyServer` section:
   - Add `image` (default to `sparkMaster.image` or same `spark-custom:3.5.7`)
   - Add `service.port: 18080`
   - Add `resources` block
   - Add ingress host entry (`history.local`)

2. **Create `templates/history-server.yaml`**:
   - Conditional on `{{ if .Values.historyServer.enabled }}`
   - Deployment:
     - Use `SPARK_MODE=history`
     - Inject S3 credentials via `envFrom: secretRef`
     - Set `SPARK_HISTORY_LOG_DIR` (override default in entrypoint)
     - Apply PSS-compatible `securityContext` (reuse helpers)
     - Mount `emptyDir` for writable paths (`/tmp`)
   - Service:
     - Port 18080

3. **Update `templates/ingress.yaml`**:
   - Add conditional rule for History Server (`historyServer.enabled`)

4. **Validate**:
   - `helm lint charts/spark-standalone`
   - `helm template spark-sa charts/spark-standalone --set historyServer.enabled=true`

### Code

**values.yaml additions:**

```yaml
historyServer:
  enabled: false
  logDirectory: "s3a://spark-logs/events"
  url: ""
  image:
    repository: spark-custom
    tag: "3.5.7"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 18080
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

ingress:
  hosts:
    historyServer: "history.local"
```

**templates/history-server.yaml (skeleton):**

```yaml
{{- if .Values.historyServer.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark-standalone.fullname" . }}-history-server
  labels:
    app: spark-history-server
    {{- include "spark-standalone.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-history-server
      {{- include "spark-standalone.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app: spark-history-server
        {{- include "spark-standalone.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "spark-standalone.serviceAccountName" . }}
      {{- if .Values.security.podSecurityStandards }}
      securityContext:
        {{- include "spark-standalone.podSecurityContext" . | nindent 8 }}
      {{- end }}
      containers:
      - name: history-server
        image: "{{ .Values.historyServer.image.repository }}:{{ .Values.historyServer.image.tag }}"
        imagePullPolicy: {{ .Values.historyServer.image.pullPolicy }}
        {{- if .Values.security.podSecurityStandards }}
        securityContext:
          {{- include "spark-standalone.containerSecurityContext" . | nindent 10 }}
        {{- end }}
        ports:
        - name: http
          containerPort: 18080
          protocol: TCP
        env:
        - name: SPARK_MODE
          value: "history"
        - name: SPARK_HISTORY_LOG_DIR
          value: {{ .Values.historyServer.logDirectory | quote }}
        - name: S3_ENDPOINT
          value: {{ .Values.s3.endpoint | quote }}
        - name: HADOOP_USER_NAME
          value: "spark"
        envFrom:
        - secretRef:
            name: {{ include "spark-standalone.fullname" . }}-s3-credentials
        resources:
          {{- toYaml .Values.historyServer.resources | nindent 10 }}
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark-standalone.fullname" . }}-history-server
  labels:
    app: spark-history-server
    {{- include "spark-standalone.labels" . | nindent 4 }}
spec:
  type: {{ .Values.historyServer.service.type }}
  ports:
  - port: {{ .Values.historyServer.service.port }}
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: spark-history-server
    {{- include "spark-standalone.selectorLabels" . | nindent 4 }}
{{- end }}
```

**ingress.yaml addition (after mlflow block):**

```yaml
  {{- if .Values.historyServer.enabled }}
  - host: {{ .Values.ingress.hosts.historyServer | default "history.local" }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "spark-standalone.fullname" . }}-history-server
            port:
              number: {{ .Values.historyServer.service.port }}
  {{- end }}
```

### Expected Result

- New file: `charts/spark-standalone/templates/history-server.yaml`
- Modified: `charts/spark-standalone/values.yaml`
- Modified: `charts/spark-standalone/templates/ingress.yaml`

### Scope Estimate

- Files: 1 created + 2 modified
- Lines: ~130 (SMALL)
- Tokens: ~600

### Completion Criteria

```bash
# Lint
helm lint charts/spark-standalone

# Render (enabled)
helm template spark-sa charts/spark-standalone \
  --set historyServer.enabled=true \
  | grep -A 50 'kind: Deployment' | grep spark-history-server

# Render (Ingress)
helm template spark-sa charts/spark-standalone \
  --set historyServer.enabled=true \
  --set ingress.enabled=true \
  | grep -A 20 'history.local'
```

### Constraints

- DO NOT change existing Spark Master/Worker templates
- DO NOT add new dependencies (use existing S3 secret)
- MUST be compatible with PSS `restricted` when enabled
