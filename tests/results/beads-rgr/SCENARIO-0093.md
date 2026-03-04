# SCENARIO-0093 (spark_k8s-sayb)

**Name:** 3.5.8-C-N-CPU-NO-ICE-SHUF-OL-K8S
**Result:** SKIP (connect mode)
**Date:** 2026-03-04

## Root cause: Test/chart scope
- run-matrix uses spark-standalone chart only (master+worker)
- Connect scenarios (C) require spark-3.5 chart with connect.enabled
- Added skip in run-matrix for connect=true scenarios
