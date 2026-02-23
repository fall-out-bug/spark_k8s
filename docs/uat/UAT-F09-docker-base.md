# UAT: F09 Phase 3 — Docker Base Layers

**Feature:** F09 - Phase 3 Docker Base Layers  
**Review Date:** 2026-02-10

---

## Overview

F09 provides three base Docker layers: JDK 17 (Eclipse Temurin), Python 3.10 (Alpine), and CUDA 12.1 (NVIDIA runtime + JDK 17). Each layer has a Dockerfile and test script. CUDA tests skip gracefully when no GPU is available.

---

## Prerequisites

- Docker (with BuildKit)
- ~5GB disk for images
- NVIDIA GPU + nvidia-docker (optional, for full CUDA tests)

---

## Quick Verification (5 minutes)

### Smoke Test

```bash
# Build all 3 base images
docker build -t spark-k8s-jdk-17:latest docker/docker-base/jdk-17/
docker build -t spark-k8s-python-3.10-base:latest docker/docker-base/python-3.10/
docker build -t spark-k8s-cuda-12.1-base:latest docker/docker-base/cuda-12.1/
# Expected: all build successfully

# Run tests
cd docker/docker-base/jdk-17 && bash test.sh
cd docker/docker-base/python-3.10 && bash test.sh
cd docker/docker-base/cuda-12.1 && bash test.sh
# Expected: all pass (CUDA GPU test skips if no GPU)
```

### Quick Check

```bash
# Syntax check
bash -n docker/docker-base/jdk-17/test.sh
bash -n docker/docker-base/python-3.10/test.sh
bash -n docker/docker-base/cuda-12.1/test.sh
# Expected: no output
```

---

## Detailed Scenarios

### Scenario 1: JDK 17

```bash
docker run --rm spark-k8s-jdk-17:latest java -version
docker run --rm spark-k8s-jdk-17:latest which bash curl
# Expected: Java 17, bash, curl
```

### Scenario 2: Python 3.10

```bash
docker run --rm spark-k8s-python-3.10-base:latest python --version
docker run --rm spark-k8s-python-3.10-base:latest pip list
# Expected: Python 3.10.x, pip packages
```

### Scenario 3: CUDA 12.1 (no GPU)

```bash
docker run --rm spark-k8s-cuda-12.1-base:latest java -version
docker run --rm spark-k8s-cuda-12.1-base:latest bash -c "ls /usr/local/cuda/lib64/libcudart.so* 2>/dev/null || true"
# Expected: Java 17, CUDA libs present
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | docker build fails | stderr | HIGH |
| 2 | test.sh fails | test output | HIGH |
| 3 | Image size exceeds target | docker images | MEDIUM |
| 4 | CUDA test fails when GPU present | test output | MEDIUM |

---

## Code Sanity Checks

```bash
# All Dockerfiles exist
ls docker/docker-base/jdk-17/Dockerfile docker/docker-base/python-3.10/Dockerfile docker/docker-base/cuda-12.1/Dockerfile
# Expected: 3 files

# All test scripts exist
ls docker/docker-base/*/test.sh
# Expected: 3 files
```

---

## Sign-off Checklist

- [ ] JDK 17 build + test pass
- [ ] Python 3.10 build + test pass
- [ ] CUDA 12.1 build + test pass (GPU skip if no GPU)
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-03-docker-base.md`
- Workstreams: `docs/workstreams/completed/00-009-01.md`, `docs/workstreams/backlog/00-009-02.md`, `00-009-03.md`
