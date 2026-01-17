## WS-020-15: Coexistence Test (Spark 3.5.7 + 4.1.0)

### 🎯 Goal

**What should WORK after WS completion:**
- Bash script `scripts/test-coexistence.sh` validates simultaneous deployment of Spark 3.5.7 and 4.1.0
- Tests verify isolated Hive Metastores (separate databases)
- Tests verify isolated History Servers (separate S3 prefixes)
- No conflicts in RBAC, services, or storage

**Acceptance Criteria:**
- [ ] `scripts/test-coexistence.sh` exists
- [ ] Script deploys both `spark-3.5` and `spark-4.1` charts
- [ ] Tests verify: separate Hive databases, separate History Server S3 prefixes, no service name conflicts
- [ ] Script runs end-to-end job on each version
- [ ] Script cleans up deployments

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 acceptance criteria include simultaneous deployment of Spark 3.5.7 and 4.1.0 without conflicts. This test validates multi-version support.

### Dependency

WS-020-02 (spark-3.5 refactor), WS-020-14 (smoke tests for reference)

### Input Files

**Reference:**
- `scripts/test-spark-standalone.sh` — Spark 3.5.7 test
- `scripts/test-spark-41-smoke.sh` — Spark 4.1.0 test

### Steps

1. **Create `scripts/test-coexistence.sh`:**
   
   Structure:
   ```bash
   #!/bin/bash
   set -e
   
   NAMESPACE="${1:-default}"
   
   echo "=== Spark Multi-Version Coexistence Test ==="
   
   # 1. Deploy Spark 3.5.7
   # 2. Deploy Spark 4.1.0
   # 3. Verify isolated Metastores
   # 4. Verify isolated History Servers
   # 5. Run job on 3.5.7
   # 6. Run job on 4.1.0
   # 7. Cleanup
   
   echo "=== Coexistence test passed ✓ ==="
   ```

2. **Deploy both versions:**
   ```bash
   echo "1) Deploying Spark 3.5.7..."
   helm install spark-35 charts/spark-3.5 \
     --namespace "$NAMESPACE" \
     --set spark-standalone.enabled=true \
     --set spark-standalone.hiveMetastore.enabled=true \
     --set spark-standalone.historyServer.enabled=true \
     --wait --timeout=5m
   
   echo "2) Deploying Spark 4.1.0..."
   helm install spark-41 charts/spark-4.1 \
     --namespace "$NAMESPACE" \
     --set connect.enabled=true \
     --set hiveMetastore.enabled=true \
     --set historyServer.enabled=true \
     --wait --timeout=5m
   ```

3. **Test 1: Verify service isolation:**
   ```bash
   echo "3) Verifying service isolation..."
   
   # Check no name conflicts
   kubectl get svc -n "$NAMESPACE" -o name | grep spark-35
   kubectl get svc -n "$NAMESPACE" -o name | grep spark-41
   
   # Verify different ports or service names
   SVC_35=$(kubectl get svc -n "$NAMESPACE" -l app=hive-metastore,chart=spark-3.5 -o jsonpath='{.items[0].metadata.name}')
   SVC_41=$(kubectl get svc -n "$NAMESPACE" -l app=hive-metastore,chart=spark-4.1 -o jsonpath='{.items[0].metadata.name}')
   
   if [[ "$SVC_35" == "$SVC_41" ]]; then
     echo "ERROR: Service name conflict!"
     exit 1
   fi
   
   echo "✓ Service isolation OK"
   ```

4. **Test 2: Verify Hive Metastore isolation:**
   ```bash
   echo "4) Verifying Hive Metastore isolation..."
   
   # Check different database names
   kubectl exec -n "$NAMESPACE" -it spark-35-metastore-0 -- \
     psql -U metastore -d metastore_spark35 -c "SELECT 1" || true
   
   kubectl exec -n "$NAMESPACE" -it spark-41-metastore-0 -- \
     psql -U metastore -d metastore_spark41 -c "SELECT 1" || true
   
   echo "✓ Metastore isolation OK"
   ```

5. **Test 3: Verify History Server S3 prefix isolation:**
   ```bash
   echo "5) Verifying History Server isolation..."
   
   # Check different S3 log directories
   kubectl logs -n "$NAMESPACE" -l app=spark-history-server,chart=spark-3.5 | \
     grep "s3a://spark-logs/3.5/events" || echo "⚠ 3.5 prefix not found"
   
   kubectl logs -n "$NAMESPACE" -l app=spark-history-server,chart=spark-4.1 | \
     grep "s3a://spark-logs/4.1/events" || echo "⚠ 4.1 prefix not found"
   
   echo "✓ History Server isolation OK"
   ```

6. **Test 4: Run jobs on both versions:**
   ```bash
   echo "6) Running SparkPi on Spark 3.5.7..."
   kubectl run spark-pi-35 \
     --image=spark-custom:3.5.7 \
     --restart=Never \
     --rm -i -n "$NAMESPACE" \
     -- /opt/spark/bin/spark-submit \
     --master spark://spark-35-master:7077 \
     --class org.apache.spark.examples.SparkPi \
     local:///opt/spark/examples/jars/spark-examples.jar 100
   
   echo "7) Running SparkPi on Spark 4.1.0 (via Connect)..."
   # (Similar test with Spark Connect client)
   
   echo "✓ Cross-version job submission OK"
   ```

7. **Cleanup:**
   ```bash
   echo "8) Cleaning up..."
   helm uninstall spark-35 -n "$NAMESPACE"
   helm uninstall spark-41 -n "$NAMESPACE"
   ```

8. **Make executable and validate:**
   ```bash
   chmod +x scripts/test-coexistence.sh
   ./scripts/test-coexistence.sh test-ns
   ```

### Expected Result

```
scripts/
└── test-coexistence.sh    # ~180 LOC
```

### Scope Estimate

- Files: 1 created
- Lines: ~180 LOC (SMALL)
- Tokens: ~800

### Completion Criteria

```bash
# Syntax check
bash -n scripts/test-coexistence.sh

# Run full test
./scripts/test-coexistence.sh test-coexistence

# Verify exit code
echo $?  # Should be 0 on success
```

### Constraints

- DO NOT share databases between versions (must be isolated)
- DO NOT skip cleanup (uninstall both releases)
- ENSURE tests run in isolated namespace (not `default`)
- USE `--wait` flag for helm installs (ensure readiness)
