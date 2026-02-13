# Pre-built Docker Images (GHCR)

spark_k8s provides pre-built Docker images via GitHub Container Registry (GHCR) to eliminate build friction.

## Image Locations

| Image | GHCR Path | Architectures |
|-------|-----------|----------------|
| spark-custom | `ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.0` | amd64, arm64 |
| jupyter-spark | `ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:4.1.0` | amd64, arm64 |

Charts default to these images. Override `image.repository` and `image.tag` for custom builds. On arm64 (e.g. Apple Silicon), Docker/Kubernetes auto-selects the correct manifest.

## Pull Instructions

```bash
# Pull images (no auth required for public)
docker pull ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.0
docker pull ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:4.1.0
```

## Helm Override

Charts default to GHCR images. To override (e.g. custom build):

```yaml
connect:
  image:
    repository: myregistry.io/my-spark-custom
    tag: "4.1.0"
jupyter:
  image:
    repository: myregistry.io/my-jupyter-spark
    tag: "4.1.0"
```

## CI/CD Authentication

Push to GHCR uses `GITHUB_TOKEN` (automatic in GitHub Actions). For external CI:

1. Create a Personal Access Token (PAT) with `write:packages`
2. Login: `echo $PAT | docker login ghcr.io -u USERNAME --password-stdin`
3. Push: `docker push ghcr.io/fall-out-bug/spark-k8s-spark-custom:4.1.0`

## Package Visibility

Packages are **public** — no authentication required for pull.
