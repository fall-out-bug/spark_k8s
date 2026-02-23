# UAT: F11 Phase 5 — Docker Final Images

**Feature:** F11 - Phase 5 Docker Final Images  
**Review Date:** 2026-02-10

---

## Overview

F11 provides Spark 3.5/4.1 runtime images (baseline, GPU, Iceberg, GPU+Iceberg) and Jupyter runtime images. All extend custom Spark builds. Build scripts support 3.5.7, 3.5.8, 4.1.0, 4.1.1 (subject to base image availability).

---

## Prerequisites

- Docker (with BuildKit)
- Custom Spark base images (docker/spark-custom)
- F10 intermediate layers (jars-rapids, jars-iceberg)
- ~50GB disk for full image set

---

## Quick Verification (5 minutes)

### Smoke Test

```bash
# 1. Build custom Spark base (required)
cd docker/spark-custom
docker build -f Dockerfile.3.5.7 -t spark-k8s:3.5.7-hadoop3.4.2 .
# Or: make build-3.5.7

# 2. Build Spark runtime (one variant)
cd docker/runtime/spark
./build-3.5.sh
# Or single: docker build --build-arg ENABLE_GPU=false --build-arg ENABLE_ICEBERG=false -t spark-k8s-runtime:3.5-3.5.7-baseline .

# 3. Build Jupyter (one variant)
cd docker/runtime/jupyter
./build-3.5.sh
# Requires Spark runtime images first
```

### Quick Check

```bash
# Syntax check
bash -n docker/runtime/spark/build-3.5.sh
bash -n docker/runtime/spark/build-4.1.sh
bash -n docker/runtime/jupyter/build-3.5.sh
bash -n docker/runtime/jupyter/build-4.1.sh
bash -n docker/runtime/tests/test-spark-runtime.sh
bash -n docker/runtime/tests/test-jupyter-runtime.sh
# Expected: no output
```

---

## Detailed Scenarios

### Scenario 1: Spark Runtime Baseline

```bash
docker run --rm spark-k8s-runtime:3.5-3.5.7-baseline /opt/spark/bin/spark-submit --version
# Expected: Spark 3.5.7
```

### Scenario 2: Spark Runtime GPU

```bash
docker run --rm spark-k8s-runtime:3.5-3.5.7-gpu ls /opt/spark/jars/rapids*.jar
# Expected: RAPIDS JAR present
```

### Scenario 3: Jupyter Runtime

```bash
docker run --rm -p 8888:8888 spark-k8s-jupyter:3.5-3.5.7-baseline jupyter lab --version
# Expected: JupyterLab version
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | Base image not found | build stderr | HIGH |
| 2 | Spark runtime fails to start | docker run | HIGH |
| 3 | Jupyter not on port 8888 | expose/config | MEDIUM |

---

## Code Sanity Checks

```bash
# All files exist
ls docker/runtime/spark/Dockerfile docker/runtime/spark/build-3.5.sh docker/runtime/spark/build-4.1.sh
ls docker/runtime/jupyter/Dockerfile docker/runtime/jupyter/build-3.5.sh docker/runtime/jupyter/build-4.1.sh
ls docker/runtime/tests/test-spark-runtime.sh docker/runtime/tests/test-jupyter-runtime.sh
# Expected: 7 files
```

---

## Sign-off Checklist

- [ ] Spark runtime builds (baseline at minimum)
- [ ] Jupyter runtime builds (after Spark)
- [ ] test-spark-runtime.sh, test-jupyter-runtime.sh syntax valid
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-05-docker-final.md`
- Workstreams: `docs/workstreams/completed/00-011-01.md`, `00-011-02.md`, `00-011-03.md`
