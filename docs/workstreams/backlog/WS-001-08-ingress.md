## WS-001-08: Ingress

### Goal

**What should WORK after WS completion:**
- Ingress routes to Spark Master UI, Airflow UI, MLflow UI
- Configurable hostnames for each service
- TLS optional (for production)

**Acceptance Criteria:**
- [ ] Ingress resource created with rules for all UIs
- [ ] `spark.local` routes to Spark Master UI (8080)
- [ ] `airflow.local` routes to Airflow Webserver (8080)
- [ ] `mlflow.local` routes to MLflow Server (5000)
- [ ] Ingress class configurable via values
- [ ] TLS configuration optional
- [ ] All UIs accessible via configured hostnames

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Ingress provides external access to Web UIs without port-forward. Supports multiple hostnames for different services. For local development, use `/etc/hosts` or nip.io. For production, configure proper DNS.

### Dependency

WS-001-06 (Airflow), WS-001-07 (MLflow) — services must exist

### Input Files

- `k8s/optional/mlflow/deployment.yaml` — Ingress example
- `charts/spark-standalone/values.yaml` — ingress section

### Steps

1. Create `charts/spark-standalone/templates/ingress.yaml`
2. Update values.yaml with ingress section
3. Test access via hostnames

### Code

```yaml
# ingress.yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "spark-standalone.fullname" . }}-ingress
  labels:
    {{- include "spark-standalone.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
  # Spark Master UI
  {{- if .Values.sparkMaster.enabled }}
  - host: {{ .Values.ingress.hosts.sparkMaster | default "spark.local" }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "spark-standalone.fullname" . }}-master
            port:
              number: 8080
  {{- end }}
  # Airflow UI
  {{- if .Values.airflow.enabled }}
  - host: {{ .Values.ingress.hosts.airflow | default "airflow.local" }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "spark-standalone.fullname" . }}-airflow-webserver
            port:
              number: 8080
  {{- end }}
  # MLflow UI
  {{- if .Values.mlflow.enabled }}
  - host: {{ .Values.ingress.hosts.mlflow | default "mlflow.local" }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "spark-standalone.fullname" . }}-mlflow
            port:
              number: 5000
  {{- end }}
{{- end }}
```

```yaml
# values.yaml - ingress section
ingress:
  enabled: true
  className: ""  # nginx, traefik, etc.
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    sparkMaster: "spark.local"
    airflow: "airflow.local"
    mlflow: "mlflow.local"
  tls: []
  #  - secretName: spark-tls
  #    hosts:
  #      - spark.local
  #      - airflow.local
  #      - mlflow.local
```

### Expected Result

- `charts/spark-standalone/templates/ingress.yaml` created
- All UIs accessible via hostnames

### Scope Estimate

- Files: 1 created + 1 modified
- Lines: ~120 (SMALL)
- Tokens: ~400

### Completion Criteria

```bash
# Deploy with Ingress
helm upgrade --install spark-sa charts/spark-standalone

# Check Ingress
kubectl get ingress
kubectl describe ingress spark-sa-ingress

# Add to /etc/hosts (for local testing)
echo "127.0.0.1 spark.local airflow.local mlflow.local" | sudo tee -a /etc/hosts

# Test access (with port-forward to ingress controller)
# Or use NodePort if available
curl -H "Host: spark.local" http://localhost/
curl -H "Host: airflow.local" http://localhost/
curl -H "Host: mlflow.local" http://localhost/
```

### Constraints

- DO NOT configure complex routing — simple path-based is sufficient
- DO NOT add TLS certificates — just support TLS config
- DO NOT add security contexts — that's WS-001-09
- Ingress must be optional (enabled: true/false)
