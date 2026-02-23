# Feature F24: Pre-built Docker Images

> **Feature ID:** F24  
> **Beads:** spark_k8s-ds8  
> **Source:** docs/plans/2026-02-04-product-branding-strategy.md Product-Led Growth

## Goal

Push `spark-custom:4.1.0` and `jupyter-spark:4.1.0` to GitHub Container Registry (GHCR). Eliminate image build friction for users.

**Impact:** Reduces time-to-value from 15 min to <2 min (Product-Led Growth target).

## Context

From Product & Community Strategy Phase 1:
- "Pre-build Docker images" (2h) — Remove friction
- Extends F11 (Docker Runtime Images)

## Scope

| Component | Description |
|-----------|-------------|
| GHCR setup | Registry config, permissions, pull instructions |
| spark-custom build | GitHub Action, multi-stage, Trivy scan |
| jupyter-spark build | GitHub Action, Spark Connect client, notebooks |
| Multi-arch | amd64, arm64 (buildx) |
| Version tagging | Sync with Spark versions, semantic versioning |
| Chart updates | values.yaml default to ghcr.io images |

## Dependencies

- F11 (Docker Runtime Images) — existing Dockerfiles
- docker/spark-4.1/, docker/jupyter-4.1/ (or equivalent)

## Out of Scope

- Spark 3.5 images (can extend later)
- Docker Hub migration (if not used)
