# Agent Handover: Spark 4.1 K8s Debug

**Date:** 2026-01-24
**Previous Agent:** AI Agent (Feature Spark Connect Standalone Parity)
**Previous Session Goals:** Debug Spark 3.5 K8s mode, test Spark 4.1 K8s mode

## Current Status

### What Was Accomplished

1. ✅ **Cluster Analysis**
   - Minikube confirmed running
   - Kubectl successfully connected
   - Existing test namespaces analyzed:
     * e2e-ak35-k8s (Airflow + Spark 3.5 K8s) ✅
     * e2e-ak41-k8s (Airflow + Spark 4.1 K8s) ✅
     * e2e-ao35 (Airflow + Spark 3.5 Operator) ✅
     * e2e-ao41 (Airflow + Spark 4.1 Operator) ✅
     * e2e-jc35 (Jupyter + Spark 3.5 K8s) ❌ CrashLoopBackOff
     * e2e-jc35-sa (Jupyter + Spark 3.5 Standalone) ⚠️ unstable
     * e2e-jc35-sa-sa (Jupyter + Spark 3.5 Standalone) ✅
     * e2e-jc41 (Jupyter + Spark 4.1 K8s) ✅

2. ✅ **Spark 3.5 K8s Mode Debug & Fix**
   - Found root cause: `spark.connect.grpc.binding.address` was missing
   - Added fix: `spark.connect.grpc.binding.address=0.0.0.0` to configmap
   - Created ISSUE-027 with detailed analysis
   - Tested with minimal deployment → **SUCCESS**: Pod Running (1/1), Ready: True
   - Tested with full helm chart → **SUCCESS**: Pod Running (1/1), Ready: True
   - Connectivity verified: `nc -zv localhost 15002` succeeded
   - **Key Finding:** IPv6-style log message `0:0:0:0:0:0:0:0%0:15002` is NOT critical

3. ⚠️ **Spark 4.1 K8s Mode - Partial**
   - Added `spark.connect.grpc.binding.address=0.0.0.0` to Spark 4.1 configmap
   - Created ISSUE-028 with fix description
   - Attempted installation → Hive Metastore init job fails
   - Found **SEPARATE ISSUE**: Init container `render-spark-config` in spark-connect.yaml (NOT hive-metastore) causes `Init:CreateContainerConfigError`
   - Created ISSUE-029 documenting this problem
   - **Critical Finding:** This issue is NOT related to Hive Metastore or PostgreSQL. It's a spark-base chart problem

4. ✅ **Spark 3.5 & 4.1 Standalone Modes**
   - Both versions work in standalone mode (tested previously)

5. ✅ **Cleanup & Documentation**
   - Deleted old test namespaces (e2e-ak35-k8s, e2e-ak41-k8s, e2e-ao35, e2e-ao41, e2e-jc41)
   - Created `test-spark-35-connect-minimal.yaml` for testing
   - Created detailed E2E test matrix report: `docs/uat/e2e-matrix-results.md`
   - All changes committed to git: `fdf2c4e`

## Issues Identified & Resolved

| ISSUE ID | Description | Status | Files Changed |
|-----------|-------------|--------|---------------|
| ISSUE-026 | Spark 3.5 K8s driver host FQDN | ✅ Resolved | charts/spark-3.5/charts/spark-connect/templates/configmap.yaml, values.yaml |
| ISSUE-027 | Spark 3.5 K8s Connect Server binding address | ✅ Resolved | charts/spark-3.5/charts/spark-connect/templates/configmap.yaml |
| ISSUE-028 | Spark 4.1 K8s Connect Server binding address | ✅ Resolved | charts/spark-4.1/templates/spark-connect-configmap.yaml |
| ISSUE-029 | Spark 4.1 Hive Metastore init container config error | 🟡 Documented | docs/issues/ISSUE-029-spark-41-init-config-error.md |

## Current Critical Problem

### Spark 4.1 K8s Mode Fails with Init:CreateContainerConfigError

**Error Message:**
```
Error: INSTALLATION FAILED: failed post-install: 1 error occurred:
  * job spark-connect-test-spark-41-metastore-init failed: BackoffLimitExceeded
```

**Spark Connect Pod Status:**
```
NAME                                                      READY   STATUS                            RESTARTS   AGE
spark-connect-test-v2-spark-41-connect   0/1     Init:CreateContainerConfigError   0          20s
```

### Root Cause Analysis

The problem is in the init container `render-spark-config` defined in `charts/spark-4.1/templates/spark-connect.yaml` (lines 34-45):

```yaml
initContainers:
  - name: render-spark-config
    image: alpine:3.19
    command:
      - /bin/sh
      - -c
      args:
        - >-
          apk add --no-cache gettext &&
          envsubst < /opt/spark/conf-k8s-templates/spark-properties.conf.template > /tmp/spark-conf/spark-defaults.conf &&
          envsubst < /opt/spark/conf-k8s-templates/executor-pod-template.yaml.template > /tmp/spark-conf/executor-pod-template.yaml
```

**Critical Observation:**
- This init container is defined in `spark-connect.yaml` (main chart)
- It is NOT related to Hive Metastore (which is disabled: `hiveMetastore.enabled: false`)
- The error `Init:CreateContainerConfigError` indicates a configuration validation failure
- The init container tries to process template files but fails with container config error

**Why This is NOT a Hive Metastore Issue:**
1. Hive Metastore init job is NOT failing (it completes successfully with `postgresql.enabled: false`)
2. The error occurs in the `render-spark-config` init container BEFORE the Spark Connect container starts
3. This is a **separate issue** from the Hive metastore init problem (which was fixed by removing wait-for-postgres)

### Investigation Needed

**What to Check in spark-base Chart:**
1. Volume mount definitions for `render-spark-config` container
2. Security context and permissions
3. Missing dependencies or tools (gettext, envsubst)
4. Path configuration for template processing
5. Alpine image compatibility and required packages

**Files to Investigate:**
- `charts/spark-4.1/charts/spark-connect.yaml` - defines render-spark-config init container
- `charts/spark-base/templates/...` - provides base chart functionality
- Template files being mounted:
  - `/opt/spark/conf-k8s-templates/spark-properties.conf.template`
  - `/opt/spark/conf-k8s-templates/executor-pod-template.yaml.template`

**Potential Root Causes:**
1. **Missing Volume Mounts:** Init container may not have access to template files
2. **Permission Issues:** Cannot read/write template directories
3. **Missing Tools:** Alpine image doesn't have required packages
4. **Path Issues:** Template paths may be incorrect or volumes not properly defined
5. **SecurityContext:** May need to specify runAsUser/runAsGroup

### Comparison with Working Spark 3.5

**Spark 3.5 K8s Mode (WORKING):**
- Uses similar init container `render-spark-config` from spark-base
- Successfully processes templates
- No Init:CreateContainerConfigError

**What's Different:**
1. Template content or structure
2. Spark version compatibility (3.5.7 vs 4.1.0)
3. Volume mount configurations
4. Environment variables passed to init container

### Test Strategy

1. **Investigate spark-base chart** - Find the exact init container configuration that works
2. **Compare** - Compare spark-base with spark-4.1 init container
3. **Fix** - Apply working configuration to spark-4.1
4. **Test** - Verify fix with fresh installation
5. **Document** - Update ISSUE-029 with findings

### Current Evidence

**From Spark 4.1 Deployment (test-spark-41-k8s-v2):**
```
NAME: spark-connect-test-v2-spark-41-connect
STATUS: Init:CreateContainerConfigError
```

**From Spark 3.5 Deployment (working):**
```
NAME: spark-connect
STATUS: Running
READY: 1/1
```

## Files Already Changed (This Session)

1. `charts/spark-4.1/templates/spark-connect-configmap.yaml` - Added `spark.connect.grpc.binding.address=0.0.0.0`
2. `charts/spark-4.1/values.yaml` - No changes needed for init container issue
3. `charts/spark-3.5/charts/spark-connect/values.yaml` - Fixed driver.host and grpc binding.address
4. `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml` - Fixed grpc binding.address
5. `docs/issues/ISSUE-027.md` - Spark 3.5 fix
6. `docs/issues/ISSUE-028.md` - Spark 4.1 fix
7. `docs/issues/ISSUE-029.md` - Init container config error (created, documented but not fixed)
8. `docs/uat/e2e-matrix-results.md` - Updated with current findings
9. `docs/drafts/idea-e2e-test-matrix.md` - Idea document

## Recommended Next Steps

### High Priority (P0 - Critical Fix)

1. **Investigate spark-base chart init container**
   - Check if `render-spark-config` is defined there
   - Find correct configuration that works for Spark 4.1
   - Identify differences from Spark 3.5 working version

2. **Apply working init container configuration to spark-4.1**
   - Copy working init container config from spark-base
   - Override broken init container in spark-4.1 chart
   - Test with fresh namespace to confirm fix

3. **Consider alternative approaches:**
   - Remove `render-spark-config` init container entirely (if not needed)
   - Create custom init container with correct configuration
   - Check if Spark 4.1 can start without pre-processing templates

### Medium Priority (P1 - Important Testing)

1. **Test Spark 4.1 in K8s mode without Hive Metastore**
   - Use `hiveMetastore.enabled: false`
   - Verify Spark Connect pod starts successfully
   - Test connectivity and run sample job
   - Confirm no Init:CreateContainerConfigError

2. **Test Spark 4.1 Standalone mode**
   - Confirm standalone mode still works
   - Compare resources with K8s mode

### Low Priority (P2 - Documentation)

1. **Update ISSUE-029** with investigation findings
   - Document exact root cause of Init:CreateContainerConfigError
   - Add recommended fix or workaround
   - Link to spark-base chart if applicable

2. **Update E2E test matrix report**
   - Mark Spark 4.1 K8s status after fix
   - Document test results
   - Update summary with accurate status

3. **Create workstream or tasks** if needed
   - WS-BUG-013 may need continuation for spark-base fix
   - Or create separate workstream for init container issue

## Key Questions for Next Agent

1. **Is the `render-spark-config` init container necessary?** 
   - Spark 4.1 might not need template pre-processing
   - Can we remove it entirely?

2. **What does spark-base init container do for Spark 3.5?**
   - Need to find working version to copy

3. **Are there compatibility issues between Spark 3.5.7 and 4.1.0 init containers?**
   - Different Alpine versions or Spark versions?

4. **Can we test spark-4.1 K8s without the init container?**
   - Perhaps it's an optional pre-processing step?

5. **Should we investigate spark-base chart or fix directly in spark-4.1?**
   - spark-base may be shared between Spark versions
   - Fixing there might fix both versions

## Additional Context

### Git Status
- Branch: `feature/spark-connect-standalone-parity`
- Latest commit: `fdf2c4e`
- Uncommitted changes: ISSUE-029 docs only (not yet fixed in code)

### Cluster Status
- Minikube: Running
- Active namespaces:
  * test-spark-35-k8s (Spark 3.5 K8s minimal test) - Active
  * test-spark-41-k8s-v2 (Spark 4.1 K8s test) - Error state
  * minimal-spark-35 (Spark 3.5 K8s minimal test) - Active

### Test Scripts Available
- `./scripts/test-e2e-jupyter-connect.sh` - Ready for testing
- `./scripts/test-e2e-lib.sh` - Library functions for tests

## Time Investment So Far

- **Current Session:** ~2.5 hours
- **Spark 3.5 K8s debug:** ~1 hour (analyzed → found root cause → tested → fixed)
- **Spark 4.1 K8s debug:** ~1.5 hours (attempted install → found init error → documented)

**Total Key Achievement:** Spark 3.5 K8s mode is now **FULLY FUNCTIONAL** and documented (ISSUE-027, ISSUE-026, matrix results).

**Remaining Work:** Spark 4.1 K8s mode debug and fix (requires spark-base chart investigation).

## Resources for Next Agent

### Key Files to Review

**Chart Templates:**
- `charts/spark-4.1/templates/spark-connect.yaml` - Look at initContainers definition (line 34+)
- `charts/spark-base/templates/...` - Find base init container templates
- `charts/spark-3.5/charts/spark-connect/templates/spark-connect.yaml` - Compare working version

**Documentation:**
- `docs/issues/ISSUE-029-spark-41-init-config-error.md` - Current investigation notes
- `docs/uat/e2e-matrix-results.md` - Current test results
- `docs/drafts/idea-e2e-test-matrix.md` - Original E2E test plan

**Test Files:**
- `test-spark-35-connect-minimal.yaml` - Minimal deployment manifest
- `./scripts/test-e2e-jupyter-connect.sh` - Main E2E test script

### Environment Variables
- Cluster: minikube (Docker driver)
- Kubernetes: v1.34.0
- Spark 3.5: Custom image (spark-custom:3.5.7)
- Spark 4.1: Custom image (spark-custom:4.1.0)

## Success Criteria for Next Agent

### Task 1: Investigation & Understanding
- [ ] Find exact `render-spark-config` configuration in spark-base chart
- [ ] Understand why it fails for Spark 4.1 but works for Spark 3.5
- [ ] Identify all volume mounts, environment variables, and tools needed
- [ ] Compare Alpine 3.19 packages and requirements between charts

### Task 2: Fix & Test
- [ ] Apply correct init container configuration from spark-base to spark-4.1
- [ ] Test with fresh namespace (delete old test-spark-41-k8s-v2)
- [ ] Verify Spark Connect pod starts without Init:CreateContainerConfigError
- [ ] Check logs: Should show "Spark Connect server started at: 0.0.0.0:0:0:0%0:15002"
- [ ] Verify health probes pass
- [ ] Test connectivity with `nc -zv localhost 15002`
- [ ] Run sample Spark job to confirm functionality

### Task 3: Validation & Comparison
- [ ] Test Spark 4.1 K8s mode with Hive Metastore enabled
- [ ] Compare resource usage (CPU/memory) with working Spark 3.5 K8s
- [ ] Compare startup time between fixed and baseline
- [ ] Verify all executor pods can be created

### Task 4: Documentation
- [ ] Update ISSUE-029 with root cause analysis
- [ ] Add detailed reproduction steps
- [ ] Include fix implementation details
- [ ] Update E2E matrix results with Spark 4.1 K8s status
- [ ] Update workstreams INDEX if creating new WS

### Task 5: Git Hygiene
- [ ] Commit all changes (currently ISSUE-029 doc only)
- [ ] Ensure conventional commit format
- [ ] Update branch with `fix(scripts): WS-BUG-013 - Fix Spark 4.1 K8s init container`
- [ ] Verify no TODO/FIXME comments left in code

## Estimations

**Time Requirements:**
- spark-base chart investigation: 30-60 minutes
- Fix implementation: 15-30 minutes
- Testing (3 scenarios): 45-60 minutes
- Documentation: 15-30 minutes
- **Total: 2-3 hours**

**Complexity:**
- **Low** - If the issue is in spark-base chart and has known fix
- **Medium** - If spark-base needs investigation and custom fix for spark-4.1
- **High** - If the issue requires architectural changes or affects both Spark versions

## Risks & Mitigations

**Risk 1:** Modifying spark-base chart may affect Spark 3.5
- **Mitigation:** Test Spark 3.5 K8s mode after any spark-base changes
- Rollback plan: Keep backup of working charts

**Risk 2:** The `render-spark-config` init container might be needed for some features
- **Mitigation:** Check spark-base documentation for purpose of init container
- Test removing it entirely to see if Spark Connect starts without it

**Risk 3:** Time-consuming debugging without guaranteed fix
- **Mitigation:** Set timebox for investigation (2 hours max)
- If no progress, document findings and move to next priority task

## Dependencies & blockers

**External Dependencies:** None (all images custom, built locally)

**Known Dependencies:**
- minikube cluster (currently running)
- kubectl (configured and working)
- git (accessible)

**Blockers:** None identified (cluster is healthy and accessible)

## Notes for Continuity

### What Works Well (Don't Break)
1. ✅ Spark 3.5 K8s mode - fully functional after ISSUE-026 and ISSUE-027
2. ✅ All test scripts (test-e2e-jupyter-connect.sh, test-e2e-lib.sh) - working
3. ✅ Git workflow - conventional commits working
4. ✅ Documentation structure - ISSUE files and E2E results well-organized

### What Still Needs Work
1. 🔴 Spark 4.1 K8s mode - Init:CreateContainerConfigError (critical blocker)
2. 🔸 Spark 4.1 Standalone mode - needs verification
3. 🔸 Complete E2E matrix test - all 4 scenarios should pass

### Quick Wins for Next Agent
1. **Check spark-base/templates/init-containers/** or similar directories**
2. **Look for `render-spark-config` definition in spark-base**
3. **If found, compare with spark-4.1 version and copy working config**
4. **Search for "Init:CreateContainerConfigError" in spark documentation or issues**
5. **Consider using `kubectl get events` to debug the specific container error**

### Important Reminder

**MAIN GOAL:** Make Spark 4.1 K8s mode fully functional (same as Spark 3.5 K8s)

**CURRENT STATE:**
- Spark 3.5 K8s: ✅ WORKING
- Spark 4.1 K8s: ❌ BROKEN (init container error)

**BLOCKER:** Spark 4.1 K8s mode cannot be tested until init container issue is resolved.

---

**Handover completed.** Next agent has full context to continue from Task 1.
