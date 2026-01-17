## WS-020-16: History Server Backward Compatibility Test

### 🎯 Goal

**What should WORK after WS completion:**
- Bash script `scripts/test-history-server-compat.sh` validates History Server 4.1.0 reading Spark 3.5.7 logs
- Test runs jobs on both versions and queries 4.1.0 History Server
- Test documents compatibility status (supported/not supported)
- Results inform documentation recommendation (separate vs shared History Server)

**Acceptance Criteria:**
- [ ] `scripts/test-history-server-compat.sh` exists
- [ ] Test runs Spark 3.5.7 job → writes logs to S3
- [ ] Test runs Spark 4.1.0 job → writes logs to S3
- [ ] Test queries History Server 4.1.0 API for both application logs
- [ ] Test documents result in `docs/testing/history-server-compat-report.md`

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 draft mentions optional shared History Server 4.1.0 (reading both 3.5.7 and 4.1.0 logs) if backward compatible. This test validates that scenario.

### Dependency

WS-020-08 (History Server 4.1.0), WS-020-15 (coexistence test pattern)

### Input Files

**Reference:**
- `charts/spark-standalone/templates/history-server.yaml` — History Server 3.5.7
- `charts/spark-4.1/templates/history-server.yaml` — History Server 4.1.0

### Steps

1. **Create `scripts/test-history-server-compat.sh`:**
   
   Structure:
   ```bash
   #!/bin/bash
   set -e
   
   NAMESPACE="${1:-default}"
   RELEASE="${2:-spark-41-history-test}"
   
   echo "=== History Server Backward Compatibility Test ==="
   
   # 1. Deploy History Server 4.1.0 with multi-prefix config
   # 2. Run Spark 3.5.7 job (write logs to s3a://spark-logs/3.5/events)
   # 3. Run Spark 4.1.0 job (write logs to s3a://spark-logs/4.1/events)
   # 4. Query History Server 4.1.0 API
   # 5. Check if both jobs appear in UI
   # 6. Document result
   
   echo "=== Test complete ==="
   ```

2. **Deploy History Server with multi-prefix:**
   ```bash
   echo "1) Deploying History Server 4.1.0 (multi-prefix test)..."
   
   # Create custom values with multiple log dirs (if supported)
   cat > /tmp/history-multi-prefix.yaml <<EOF
   historyServer:
     enabled: true
     logDirectory: "s3a://spark-logs/**/events"  # Wildcard pattern
   EOF
   
   helm install ${RELEASE} charts/spark-4.1 \
     --namespace "$NAMESPACE" \
     -f /tmp/history-multi-prefix.yaml \
     --set connect.enabled=false \
     --set hiveMetastore.enabled=false \
     --wait
   ```

3. **Run Spark 3.5.7 job:**
   ```bash
   echo "2) Running Spark 3.5.7 job..."
   
   kubectl run spark-35-job \
     --image=spark-custom:3.5.7 \
     --restart=Never \
     --rm -i -n "$NAMESPACE" \
     --env="AWS_ACCESS_KEY_ID=minioadmin" \
     --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
     -- /opt/spark/bin/spark-submit \
     --master local[2] \
     --conf spark.eventLog.enabled=true \
     --conf spark.eventLog.dir=s3a://spark-logs/3.5/events \
     --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
     --class org.apache.spark.examples.SparkPi \
     local:///opt/spark/examples/jars/spark-examples.jar 100
   
   echo "✓ Spark 3.5.7 job complete"
   ```

4. **Run Spark 4.1.0 job:**
   ```bash
   echo "3) Running Spark 4.1.0 job..."
   
   kubectl run spark-41-job \
     --image=spark-custom:4.1.0 \
     --restart=Never \
     --rm -i -n "$NAMESPACE" \
     --env="AWS_ACCESS_KEY_ID=minioadmin" \
     --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
     -- /opt/spark/bin/spark-submit \
     --master local[2] \
     --conf spark.eventLog.enabled=true \
     --conf spark.eventLog.dir=s3a://spark-logs/4.1/events \
     --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
     --class org.apache.spark.examples.SparkPi \
     local:///opt/spark/examples/jars/spark-examples.jar 100
   
   echo "✓ Spark 4.1.0 job complete"
   ```

5. **Query History Server API:**
   ```bash
   echo "4) Querying History Server 4.1.0 API..."
   
   kubectl port-forward "svc/${RELEASE}-spark-41-history" 18080:18080 -n "$NAMESPACE" >/dev/null 2>&1 &
   PF_PID=$!
   sleep 5
   
   # Wait for log parsing
   echo "   Waiting for log parsing (30s)..."
   sleep 30
   
   # Query applications
   APPS=$(curl -s http://localhost:18080/api/v1/applications || echo "[]")
   APP_COUNT=$(echo "$APPS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
   
   echo "   History Server shows $APP_COUNT application(s)"
   echo "   Applications: $APPS"
   
   kill $PF_PID 2>/dev/null || true
   ```

6. **Document result:**
   ```bash
   echo "5) Documenting result..."
   
   if [[ "$APP_COUNT" -ge 2 ]]; then
     RESULT="✓ BACKWARD COMPATIBLE: History Server 4.1.0 can read Spark 3.5.7 logs"
     RECOMMENDATION="Shared History Server 4.1.0 is supported"
   else
     RESULT="✗ NOT BACKWARD COMPATIBLE: History Server 4.1.0 cannot read Spark 3.5.7 logs"
     RECOMMENDATION="Use separate History Servers (default)"
   fi
   
   cat > docs/testing/history-server-compat-report.md <<EOF
   # History Server Backward Compatibility Report
   
   **Test Date:** $(date)
   **History Server Version:** 4.1.0
   **Spark Versions Tested:** 3.5.7, 4.1.0
   
   ## Result
   
   $RESULT
   
   ## Recommendation
   
   $RECOMMENDATION
   
   ## Details
   
   - Applications found: $APP_COUNT
   - API response: \`$APPS\`
   
   EOF
   
   echo "$RESULT"
   echo "$RECOMMENDATION"
   ```

7. **Cleanup:**
   ```bash
   helm uninstall ${RELEASE} -n "$NAMESPACE"
   ```

8. **Make executable and validate:**
   ```bash
   chmod +x scripts/test-history-server-compat.sh
   ./scripts/test-history-server-compat.sh test-ns
   ```

### Expected Result

```
scripts/
└── test-history-server-compat.sh              # ~150 LOC

docs/testing/
└── history-server-compat-report.md            # ~30 LOC (generated)
```

### Scope Estimate

- Files: 2 created (script + report template)
- Lines: ~180 LOC (SMALL)
- Tokens: ~850

### Completion Criteria

```bash
# Syntax check
bash -n scripts/test-history-server-compat.sh

# Run full test
./scripts/test-history-server-compat.sh test-compat

# Check report generated
cat docs/testing/history-server-compat-report.md

# Verify exit code
echo $?  # Should be 0 on success (regardless of compat result)
```

### Constraints

- DO NOT fail test if backward compat not supported (document result only)
- DO NOT modify History Server code (pure validation)
- ENSURE test runs in isolated namespace
- USE sufficient wait time for log parsing (History Server needs time)
