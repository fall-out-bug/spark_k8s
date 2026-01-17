## WS-020-10: RBAC + Service Templates for spark-4.1

### 🎯 Goal

**What should WORK after WS completion:**
- RBAC templates (ServiceAccount, Role, RoleBinding) exist for Spark 4.1.0
- Permissions allow Spark Connect to create/delete executor pods
- Templates reference `spark-base` ServiceAccount or create dedicated one
- `helm template` renders valid K8s manifests

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/templates/rbac.yaml` defines ServiceAccount, Role, RoleBinding
- [ ] Role includes permissions: `pods` (create, get, list, delete), `services` (create, get, list, delete), `configmaps` (get, list)
- [ ] Templates conditionally use `spark-base.serviceAccountName` or create new ServiceAccount
- [ ] All Spark 4.1.0 pods reference correct ServiceAccount

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Spark Connect 4.1.0 requires RBAC permissions to dynamically create executor pods in Kubernetes native mode. This WS ensures proper RBAC configuration.

### Dependency

WS-020-01 (spark-base with ServiceAccount helper)

### Input Files

**Reference:**
- `charts/spark-base/templates/rbac.yaml` — Base RBAC template
- `charts/spark-standalone/templates/rbac.yaml` — Existing RBAC patterns

### Steps

1. **Create `charts/spark-4.1/templates/rbac.yaml`:**
   
   ServiceAccount (conditional):
   ```yaml
   {{- if .Values.rbac.create }}
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: {{ include "spark-4.1.serviceAccountName" . }}
   {{- end }}
   ```
   
   Role:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: {{ include "spark-4.1.fullname" . }}-spark-role
   rules:
   - apiGroups: [""]
     resources: ["pods"]
     verbs: ["create", "get", "list", "watch", "delete"]
   - apiGroups: [""]
     resources: ["services"]
     verbs: ["create", "get", "list", "delete"]
   - apiGroups: [""]
     resources: ["configmaps"]
     verbs: ["get", "list"]
   ```
   
   RoleBinding:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: {{ include "spark-4.1.fullname" . }}-spark-rolebinding
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: Role
     name: {{ include "spark-4.1.fullname" . }}-spark-role
   subjects:
   - kind: ServiceAccount
     name: {{ include "spark-4.1.serviceAccountName" . }}
     namespace: {{ .Release.Namespace }}
   ```

2. **Add helper to `_helpers.tpl`:**
   ```
   {{- define "spark-4.1.serviceAccountName" -}}
   {{- if .Values.rbac.create }}
   {{- default (include "spark-4.1.fullname" .) .Values.rbac.serviceAccountName }}
   {{- else }}
   {{- default "default" .Values.rbac.serviceAccountName }}
   {{- end }}
   {{- end }}
   ```

3. **Update all Deployment templates to reference ServiceAccount:**
   
   In `spark-connect.yaml`, `history-server.yaml`, `jupyter.yaml`:
   ```yaml
   spec:
     serviceAccountName: {{ include "spark-4.1.serviceAccountName" . }}
   ```

4. **Update `values.yaml`:**
   ```yaml
   rbac:
     create: true
     serviceAccountName: "spark-41"
   ```

5. **Validate:**
   ```bash
   helm template spark-41 charts/spark-4.1 \
     --set rbac.create=true
   ```

### Expected Result

```
charts/spark-4.1/templates/
├── rbac.yaml                        # ~80 LOC
└── (updated: spark-connect.yaml, history-server.yaml, jupyter.yaml)
```

### Scope Estimate

- Files: 1 created, 4 modified (templates + _helpers.tpl)
- Lines: ~80 new + ~20 modified = ~100 LOC (SMALL)
- Tokens: ~450

### Completion Criteria

```bash
# Template render
helm template spark-41 charts/spark-4.1 --set rbac.create=true

# Validate YAML
helm template spark-41 charts/spark-4.1 --set rbac.create=true | \
  kubectl apply --dry-run=client -f -

# Check ServiceAccount reference in all pods
helm template spark-41 charts/spark-4.1 --set rbac.create=true | \
  grep "serviceAccountName: spark-41" | wc -l
# Should be >= 3 (connect, history, jupyter)
```

### Constraints

- DO NOT create ClusterRole (use Role scoped to namespace)
- DO NOT grant excessive permissions (principle of least privilege)
- ENSURE all pods use ServiceAccount (executor pod template inherits from driver)
- USE conditional creation (allow users to provide existing ServiceAccount)
