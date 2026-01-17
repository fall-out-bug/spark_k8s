## WS-020-08: History Server 4.1.0 Template

### 🎯 Goal

**What should WORK after WS completion:**
- History Server 4.1.0 Deployment and Service templates exist
- History Server reads event logs from S3 prefix `s3a://spark-logs/4.1/events`
- Service exposes port 18080
- PSS `restricted` compatible
- Ingress rule added for History Server UI (optional)

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/templates/history-server.yaml` defines Deployment + Service
- [ ] Image: `spark-custom:4.1.0` with `SPARK_MODE=history`
- [ ] Env: `SPARK_HISTORY_LOG_DIR=s3a://spark-logs/4.1/events`
- [ ] Service port: 18080
- [ ] Ingress rule added to `charts/spark-4.1/templates/ingress.yaml` (if enabled)
- [ ] Security contexts use PSS helpers

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 includes History Server 4.1.0 to view Spark application logs. By default, separate History Servers for 3.5.7 and 4.1.0 are recommended (separate S3 prefixes). Optional backward compatibility testing happens in WS-020-16.

### Dependency

WS-020-03 (Spark 4.1.0 image with `history` mode support)

### Input Files

**Reference:**
- `charts/spark-standalone/templates/history-server.yaml` — Existing History Server template (F03)
- `docker/spark-4.1/entrypoint.sh` — Verify `history` mode support

### Steps

1. **Create `charts/spark-4.1/templates/history-server.yaml`:**
   
   Deployment:
   - Image: `spark-custom:4.1.0`
   - Env: `SPARK_MODE=history`
   - Env: `SPARK_HISTORY_LOG_DIR={{ .Values.historyServer.logDirectory }}`
   - Env: S3 credentials (from spark-base Secret)
   - Env: `HADOOP_USER_NAME=spark` (PSS compliance)
   - Volume: `emptyDir` for `/tmp`
   - Security: PSS contexts
   
   Service:
   - Type: ClusterIP
   - Port: 18080

2. **Create/Update `charts/spark-4.1/templates/ingress.yaml`:**
   
   Add rule for History Server:
   ```yaml
   {{- if and .Values.ingress.enabled .Values.historyServer.enabled }}
   - host: {{ .Values.ingress.hosts.historyServer | default "history-41.local" }}
     http:
       paths:
       - path: /
         pathType: Prefix
         backend:
           service:
             name: {{ include "spark-4.1.fullname" . }}-history
             port:
               number: 18080
   {{- end }}
   ```

3. **Update `values.yaml`:**
   ```yaml
   historyServer:
     enabled: true
     logDirectory: "s3a://spark-logs/4.1/events"
     image:
       repository: spark-custom
       tag: "4.1.0"
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
     enabled: false
     hosts:
       historyServer: "history-41.local"
   ```

4. **Validate:**
   ```bash
   helm template spark-41 charts/spark-4.1 \
     --set historyServer.enabled=true \
     --set ingress.enabled=true
   ```

### Expected Result

```
charts/spark-4.1/templates/
├── history-server.yaml    # ~120 LOC
└── ingress.yaml           # ~80 LOC (created or updated)
```

### Scope Estimate

- Files: 2 created/modified, 1 modified (values.yaml)
- Lines: ~200 LOC (SMALL)
- Tokens: ~850

### Completion Criteria

```bash
# Template render
helm template spark-41 charts/spark-4.1 --set historyServer.enabled=true

# Validate YAML
helm template spark-41 charts/spark-4.1 --set historyServer.enabled=true | \
  kubectl apply --dry-run=client -f -

# Check S3 prefix isolation
helm template spark-41 charts/spark-4.1 --set historyServer.enabled=true | \
  grep "s3a://spark-logs/4.1/events"
```

### Constraints

- DO NOT read from Spark 3.5.7 logs by default (separate prefix: `/4.1/events`)
- DO NOT test backward compatibility here (dedicated WS-020-16 for that)
- ENSURE PSS compliance (readOnlyRootFilesystem requires /tmp emptyDir)
- USE same S3 credentials as Spark Connect (from spark-base Secret)
