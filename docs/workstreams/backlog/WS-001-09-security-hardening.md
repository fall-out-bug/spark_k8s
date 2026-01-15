## WS-001-09: Security Hardening

### Goal

**What should WORK after WS completion:**
- All pods run as non-root user
- SecurityContext applied to all containers
- Chart deployable in PSS `restricted` namespace
- Compatible with OpenShift SCC `restricted`

**Acceptance Criteria:**
- [ ] All pods have `runAsNonRoot: true`
- [ ] All containers have `allowPrivilegeEscalation: false`
- [ ] All containers have `readOnlyRootFilesystem: true`
- [ ] All containers drop ALL capabilities
- [ ] Writable directories mounted as emptyDir
- [ ] Chart deploys in namespace with PSS `restricted` label
- [ ] No pods fail due to security violations
- [ ] `seccompProfile: RuntimeDefault` set on all pods

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

OpenShift uses SCC `restricted` by default. To ensure compatibility, all pods must run with restricted security settings. We emulate this in k3s/minikube using Pod Security Standards (PSS). This affects all components: Spark, Airflow, MLflow.

### Dependency

WS-001-07 (MLflow) — all components must exist before hardening

### Input Files

- `docker/spark/Dockerfile` — already uses non-root user 185
- `charts/spark-standalone/templates/*.yaml` — all deployment files
- `docs/drafts/idea-spark-standalone-chart.md` — security requirements

### Steps

1. Create `charts/spark-standalone/templates/namespace.yaml` with PSS labels
2. Add podSecurityContext to all Deployments/DaemonSets
3. Add containerSecurityContext to all containers
4. Add emptyDir volumes for writable directories
5. Update values.yaml with security section
6. Test in PSS restricted namespace

### Code

```yaml
# namespace.yaml (optional, for PSS enforcement)
{{- if .Values.security.createNamespace }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Release.Namespace }}
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
{{- end }}
```

```yaml
# _helpers.tpl - add security context helpers
{{- define "spark-standalone.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .Values.security.runAsUser | default 1000 }}
runAsGroup: {{ .Values.security.runAsGroup | default 1000 }}
fsGroup: {{ .Values.security.fsGroup | default 1000 }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "spark-standalone.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
{{- end }}
```

```yaml
# Example: master.yaml with security context
spec:
  template:
    spec:
      securityContext:
        {{- include "spark-standalone.podSecurityContext" . | nindent 8 }}
      containers:
      - name: spark-master
        securityContext:
          {{- include "spark-standalone.containerSecurityContext" . | nindent 10 }}
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: spark-work
          mountPath: /opt/spark/work-dir
        - name: spark-logs
          mountPath: /opt/spark/logs
      volumes:
      - name: tmp
        emptyDir: {}
      - name: spark-work
        emptyDir: {}
      - name: spark-logs
        emptyDir: {}
```

```yaml
# values.yaml - security section
security:
  podSecurityStandards: true
  createNamespace: false  # Set true to create namespace with PSS labels
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  # Writable directories (mounted as emptyDir)
  writablePaths:
    spark:
      - /tmp
      - /opt/spark/work-dir
      - /opt/spark/logs
    airflow:
      - /tmp
      - /opt/airflow/logs
    mlflow:
      - /tmp
      - /home/mlflow
```

### Expected Result

- All deployments updated with security contexts
- Namespace can be created with PSS labels
- Chart works in restricted namespace

### Scope Estimate

- Files: 1 created + 8 modified (all deployment files)
- Lines: ~400 (MEDIUM)
- Tokens: ~1200

### Completion Criteria

```bash
# Create namespace with PSS restricted
kubectl create namespace spark-test
kubectl label namespace spark-test \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted

# Deploy to restricted namespace
helm upgrade --install spark-sa charts/spark-standalone -n spark-test

# Check all pods running
kubectl get pods -n spark-test
# All pods should be Running, no security violations

# Verify security context
kubectl get pod -n spark-test -l app=spark-master -o yaml | grep -A20 securityContext

# Check no root processes
kubectl exec -n spark-test deploy/spark-sa-master -- id
# Should show uid=1000 or similar non-root

# Verify readOnlyRootFilesystem
kubectl exec -n spark-test deploy/spark-sa-master -- touch /test 2>&1 || echo "Read-only works"
```

### Constraints

- DO NOT change functionality — only add security
- DO NOT break existing features
- Spark image already uses non-root user 185 — may need adjustment
- Airflow image uses user 50000 (airflow) — verify compatibility
- MLflow image may need verification
