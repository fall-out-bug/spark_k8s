# UAT Guide: F03 - Spark History Server for Standalone Chart

**Feature:** F03 - Spark History Server for Standalone Chart  
**Workstreams:** WS-012-01, WS-012-02  
**Created:** 2026-01-16  
**Tester:** Human + Agent

---

## 1. Overview

This feature adds an optional **Spark History Server** component to the `spark-standalone` Helm chart. It allows developers to view details of completed Spark applications (stages, tasks, execution DAGs) by reading event logs from S3.

**Key capabilities:**
- Optional deployment controlled by `historyServer.enabled`
- Automatic S3 integration (reuses existing credentials)
- UI accessible via Service (port 18080) and Ingress
- PSS `restricted` compatible

---

## 2. Prerequisites

### Environment
- Minikube/k3s cluster running
- `kubectl` and `helm` installed
- `spark-custom:3.5.7` image available (or loaded into minikube)

### Commands
```bash
# Load spark-custom image (if needed)
minikube image load spark-custom:3.5.7

# Verify cluster
kubectl cluster-info
```

---

## 3. Quick Smoke Test (30 sec)

**Goal:** Verify History Server deploys and UI is accessible.

```bash
# 1. Deploy with History Server enabled
helm upgrade --install spark-sa charts/spark-standalone \
  -n spark-sa --create-namespace \
  --set historyServer.enabled=true

# 2. Wait for pods ready
kubectl wait --for=condition=ready pod \
  -l app=spark-history-server \
  -n spark-sa --timeout=120s

# 3. Check pod logs (should see "Starting Spark History Server")
kubectl logs -n spark-sa -l app=spark-history-server --tail=20

# 4. Port-forward to UI
kubectl port-forward -n spark-sa svc/spark-sa-spark-standalone-history-server 18080:18080 &

# 5. Open browser to http://localhost:18080
# Expected: History Server UI loads, shows empty application list

# 6. Cleanup port-forward
killall kubectl
```

**✅ Pass criteria:**
- Pod starts without errors
- UI loads at http://localhost:18080
- No crash loops in logs

---

## 4. Detailed Scenarios

### Scenario 1: Deploy and verify History Server

**Steps:**
1. Deploy chart with `historyServer.enabled=true`
2. Verify Deployment, Service, and Ingress created
3. Check pod logs for startup messages

**Commands:**
```bash
helm upgrade --install spark-sa charts/spark-standalone \
  -n spark-sa --create-namespace \
  --set historyServer.enabled=true

# Verify resources
kubectl get deployment,svc,ingress -n spark-sa -l app=spark-history-server

# Check logs
kubectl logs -n spark-sa -l app=spark-history-server --tail=50
```

**Expected results:**
- Deployment: `spark-sa-spark-standalone-history-server` (1/1 ready)
- Service: `spark-sa-spark-standalone-history-server` (ClusterIP, port 18080)
- Ingress rule: `history.local` → History Server service
- Logs: "Starting Spark History Server..." (no errors)

---

### Scenario 2: Run SparkPi and verify application appears in UI

**Steps:**
1. Run SparkPi job via spark-submit (creates event logs in S3)
2. Wait for History Server to parse logs (~30 seconds)
3. Query History Server API for applications
4. Verify application appears in UI

**Commands:**
```bash
# Run SparkPi
MASTER_POD=$(kubectl get pod -n spark-sa -l app=spark-master -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n spark-sa "$MASTER_POD" -- sh -lc "\
  POD_IP=\$(hostname -i) && \
  spark-submit --master spark://spark-sa-spark-standalone-master:7077 \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.driver.host=\$POD_IP \
    --conf spark.sql.catalogImplementation=in-memory \
    --class org.apache.spark.examples.SparkPi \
    /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10 \
"

# Wait for logs to be parsed
sleep 30

# Query API
kubectl port-forward -n spark-sa svc/spark-sa-spark-standalone-history-server 18080:18080 &
sleep 3
curl -s http://localhost:18080/api/v1/applications | python3 -m json.tool

# Cleanup
killall kubectl
```

**Expected results:**
- API returns JSON array with at least 1 application
- Application `name` contains "Spark Pi"
- Application `attempts[0].completed` is `true`

---

### Scenario 3: Run automated smoke test

**Steps:**
1. Run `test-spark-standalone.sh` with History Server enabled
2. Verify History Server check passes

**Commands:**
```bash
scripts/test-spark-standalone.sh spark-sa spark-sa
```

**Expected output:**
```
...
6) Checking History Server (if deployed)...
   History Server service found, waiting for pod...
   Port-forwarding to History Server...
   Querying History Server API...
   ✓ History Server shows 1 application(s)
   OK
...
=== Done ===
```

---

### Scenario 4: Verify History Server NOT deployed when disabled

**Steps:**
1. Deploy chart with `historyServer.enabled=false` (default)
2. Verify no History Server resources created
3. Run smoke test (should skip History Server check)

**Commands:**
```bash
helm upgrade --install spark-sa charts/spark-standalone \
  -n spark-sa --create-namespace \
  --set historyServer.enabled=false

# Verify no resources
kubectl get deployment,svc -n spark-sa -l app=spark-history-server
# Expected: No resources found

# Run smoke test
scripts/test-spark-standalone.sh spark-sa spark-sa | grep "History Server"
# Expected: "History Server not deployed (skipping)"
```

**Expected results:**
- No History Server Deployment/Service
- Smoke test skips History Server check
- No errors in test output

---

### Scenario 5: PSS `restricted` compatibility

**Steps:**
1. Create namespace with PSS `restricted` enforcement
2. Deploy chart with `security.podSecurityStandards=true`
3. Verify History Server pod starts without PSS violations

**Commands:**
```bash
# Create PSS-restricted namespace
kubectl create namespace spark-sa-pss
kubectl label namespace spark-sa-pss pod-security.kubernetes.io/enforce=restricted

# Deploy with PSS enabled
helm upgrade --install spark-sa charts/spark-standalone \
  -n spark-sa-pss \
  --set historyServer.enabled=true \
  --set security.podSecurityStandards=true

# Verify pod starts
kubectl wait --for=condition=ready pod \
  -l app=spark-history-server \
  -n spark-sa-pss --timeout=120s

# Check pod security context
kubectl get pod -n spark-sa-pss -l app=spark-history-server -o yaml | grep -A 10 "securityContext"
```

**Expected results:**
- Pod starts without PSS admission errors
- Pod has `runAsNonRoot: true`
- Container has `allowPrivilegeEscalation: false`
- Container has `readOnlyRootFilesystem: true`
- Container capabilities dropped: `ALL`

---

## 5. Red Flags (Signs of Problems)

| # | Red Flag | Severity | Action |
|---|----------|----------|--------|
| 1 | History Server pod CrashLoopBackOff | 🔴 HIGH | Check logs for S3 connection errors |
| 2 | "NoSuchBucketException: spark-logs" in logs | 🔴 HIGH | Verify MinIO bucket init job completed |
| 3 | API returns empty array after SparkPi | 🟡 MEDIUM | Wait longer (logs may not be parsed yet) |
| 4 | PSS admission error on pod creation | 🔴 HIGH | Check security contexts in template |
| 5 | History Server UI shows no applications | 🟡 MEDIUM | Verify SparkPi wrote event logs to S3 |
| 6 | "FileNotFoundException" in History Server logs | 🔴 HIGH | Check `historyServer.logDirectory` matches `spark.eventLog.dir` |

---

## 6. Code Sanity Checks

```bash
# 1. Helm lint passes
helm lint charts/spark-standalone
# Expected: 0 chart(s) failed

# 2. Template renders when enabled
helm template test charts/spark-standalone --set historyServer.enabled=true \
  | grep "spark-history-server" | wc -l
# Expected: > 0

# 3. Template does NOT render when disabled
helm template test charts/spark-standalone --set historyServer.enabled=false \
  | grep "spark-history-server" | wc -l
# Expected: 0

# 4. No TODOs in templates
grep -rn "TODO\|FIXME" charts/spark-standalone/templates/history-server.yaml
# Expected: empty

# 5. File size check
wc -l charts/spark-standalone/templates/history-server.yaml
# Expected: < 200 LOC

# 6. Git commits present
git log --oneline feature/history-server-sa --not main
# Expected: feat, test, docs commits

# 7. Bash syntax check
bash -n scripts/test-spark-standalone.sh
# Expected: no errors
```

---

## 7. Sign-off Checklist

**Tester:** _____________________ **Date:** _____

- [ ] Quick smoke test passed (Scenario 1)
- [ ] SparkPi application appears in UI (Scenario 2)
- [ ] Automated smoke test passes (Scenario 3)
- [ ] History Server NOT deployed when disabled (Scenario 4)
- [ ] PSS compatibility verified (Scenario 5)
- [ ] No red flags observed
- [ ] Code sanity checks passed

**Notes/Issues:**
```
(Add any observations or issues here)
```

**Verdict:**
- [ ] ✅ APPROVED (ready for production)
- [ ] ❌ CHANGES REQUESTED (describe issues above)

---

## 8. Cleanup

```bash
# Remove test deployment
helm uninstall spark-sa -n spark-sa
kubectl delete namespace spark-sa

# Remove PSS test namespace
kubectl delete namespace spark-sa-pss
```
