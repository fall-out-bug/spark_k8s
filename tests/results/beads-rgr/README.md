# Beads RGR Scenario Artifacts

Artifacts and notes from beads backlog RGR (Red-Green-Refactor) scenario runs.

## Summary

| Result | Count | Notes |
|--------|-------|-------|
| PASS | 6 | 0072, 0075, 0076, 0079, 0080 (3.5.7 standalone) |
| SKIP | 12 | Connect scenarios - run-matrix uses spark-standalone only |
| FAIL | 4 | 0093 (ImagePullBackOff), 0133/134/135 (3.5.8 image load timeout) |

## Run-matrix changes

- `--skip-demo-check`: run when demo scaled down
- Connect scenarios: skip (require spark-3.5 chart)
- Minikube: load non-3.5.7 images before deploy
- Pre-load 3.5.8: `minikube image load spark-custom:3.5.8`
