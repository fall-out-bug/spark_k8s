# CUDA 12.1 Base Image

Base Docker image for Spark applications requiring GPU support with CUDA 12.1 runtime.

## Overview

This image provides:
- CUDA 12.1 runtime (from nvidia/cuda:12.1.0-runtime-ubuntu22.04)
- OpenJDK 17 JRE (headless)
- Essential utilities: curl, ca-certificates, bash

## Image Details

- **Base Image**: nvidia/cuda:12.1.0-runtime-ubuntu22.04
- **Maintainer**: spark-k8s-platform
- **Working Directory**: /workspace
- **Target Size**: < 4GB

## Building

### Build the image

```bash
# From the cuda-12.1 directory
cd docker/docker-base/cuda-12.1

# Build with default tag
docker build -t spark-k8s-cuda-12.1-base:latest .

# Or with custom tag
IMAGE_NAME=spark-k8s-cuda-12.1-base IMAGE_TAG=v1.0 docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
```

## Testing

### Run tests

```bash
# From the cuda-12.1 directory
cd docker/docker-base/cuda-12.1

# Run all tests
./test.sh

# Run with custom image name
IMAGE_NAME=my-cuda-base IMAGE_TAG=test ./test.sh
```

### Test Coverage

The test script verifies:
1. Image builds successfully
2. CUDA 12.1 runtime is available (nvidia-smi)
3. Java 17 is installed
4. curl, bash, and ca-certificates are present
5. Image size is under 4GB
6. CUDA runtime libraries exist
7. Working directory is /workspace
8. nvidia-smi works with GPU access (if GPU available)

**Note**: GPU tests will gracefully skip if no GPU is available.

## GPU Requirements

This image requires NVIDIA GPU support to run CUDA workloads:

### With GPU (recommended)

```bash
# Run with GPU access
docker run --rm --gpus all spark-k8s-cuda-12.1-base:latest nvidia-smi
```

### Without GPU (limited functionality)

```bash
# Run without GPU (CUDA libraries present but no device access)
docker run --rm spark-k8s-cuda-12.1-base:latest java -version
```

## Usage Examples

### Interactive shell

```bash
docker run --rm -it --gpus all spark-k8s-cuda-12.1-base:latest /bin/bash
```

### Check CUDA version

```bash
docker run --rm spark-k8s-cuda-12.1-base:latest nvidia-smi
```

### Check Java version

```bash
docker run --rm spark-k8s-cuda-12.1-base:latest java -version
```

## Security

This image follows security best practices:
- Runs as non-root user (when specified in child images)
- Minimal installed packages (JRE headless, essential utilities only)
- Cleaned apt cache to reduce image size
- No sensitive data included

## Maintenance

### Update base image

When NVIDIA releases a new CUDA version:

1. Update FROM line in Dockerfile
2. Update version in description label
3. Update test expectations if needed
4. Run full test suite

### Troubleshooting

**nvidia-smi fails**: Ensure Docker has GPU access enabled with `--gpus all`

**Java not found**: Verify openjdk-17-jre-headless package installed

**Image too large**: Check for unnecessary packages or cached files
