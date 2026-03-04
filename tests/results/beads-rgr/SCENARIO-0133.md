# SCENARIO-0133 (spark_k8s-g9f8)

**Name:** 3.5.8-NC-N-CPU-NO-ICE-SHUF-OL-K8S
**Result:** FAIL (302s - deploy/smoke timeout)
**Date:** 2026-03-04

## Notes
- 3.5.8 image load into minikube adds ~3min; total run hit timeout
- Pre-load before batch: `minikube image load spark-custom:3.5.8`
