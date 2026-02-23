# Phase 5: Docker Final Images

> **Status:** Completed
> **Priority:** P1 - Инфраструктура для GPU/Iceberg
> **Feature:** F11
> **Estimated Workstreams:** 3
> **Estimated LOC:** ~3900

## Goal

Создать финальные Docker образы (Spark 3.5/4.1 × baseline/GPU/Iceberg/GPU+Iceberg + Jupyter) с integration тестами для production-ready Spark K8s deployments.

## Current State

**F11 completed** — 16 runtime images created (Spark 8 + Jupyter 12), all tests passed (60/60 per F11-F12-review-report).

## Updated Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-011-01 | Spark 3.5 images (8) + tests | LARGE (~1200 LOC) | Phase 4 (F10) | completed |
| WS-011-02 | Spark 4.1 images (8) + tests | LARGE (~1200 LOC) | Phase 4 (F10) | completed |
| WS-011-03 | Jupyter images (12) + tests | LARGE (~1500 LOC) | Phase 4 (F10) | completed |

## Design Decisions

### 1. Image Variants Strategy

**Single Dockerfile with Build Args**

```dockerfile
# docker/runtime/spark/Dockerfile
ARG BASE_IMAGE=spark-k8s-spark-3.5.7-core:latest
FROM ${BASE_IMAGE} as spark

# Optional layers
ARG ENABLE_GPU=false
ARG ENABLE_ICEBERG=false

# GPU layer
FROM spark-k8s-jars-rapids:latest as jars-rapids
FROM spark-k8s-jars-iceberg:latest as jars-iceberg

# Combine layers
FROM spark
COPY --from=jars-rapids $SPARK_HOME/jars/rapids*.jar $SPARK_HOME/jars/ || true
COPY --from=jars-iceberg $SPARK_HOME/jars/iceberg*.jar $SPARK_HOME/jars/ || true
```

**Build targets:**
```bash
# Baseline
docker build --target spark -t spark-k8s-spark-3.5.7:latest .

# GPU
docker build --build-arg ENABLE_GPU=true -t spark-k8s-spark-3.5.7-gpu:latest .

# Iceberg
docker build --build-arg ENABLE_ICEBERG=true -t spark-k8s-spark-3.5.7-iceberg:latest .

# GPU+Iceberg
docker build --build-arg ENABLE_GPU=true --build-arg ENABLE_ICEBERG=true \
    -t spark-k8s-spark-3.5.7-gpu-iceberg:latest .
```

### 2. Image Matrix

**Spark 3.5.x Images (8 total):**

| Variant | 3.5.7 | 3.5.8 |
|--------|-------|-------|
| Baseline | spark-3.5.7 | spark-3.5.8 |
| GPU | spark-3.5.7-gpu | spark-3.5.8-gpu |
| Iceberg | spark-3.5.7-iceberg | spark-3.5.8-iceberg |
| GPU+Iceberg | spark-3.5.7-gpu-iceberg | spark-3.5.8-gpu-iceberg |

**Spark 4.1.x Images (8 total):**

| Variant | 4.1.0 | 4.1.1 |
|--------|-------|-------|
| Baseline | spark-4.1.0 | spark-4.1.1 |
| GPU | spark-4.1.0-gpu | spark-4.1.1-gpu |
| Iceberg | spark-4.1.0-iceberg | spark-4.1.1-iceberg |
| GPU+Iceberg | spark-4.1.0-gpu-iceberg | spark-4.1.1-gpu-iceberg |

**Jupyter Images (12 total):**

| Variant | 3.5.7 | 3.5.8 | 4.1.0 | 4.1.1 |
|--------|-------|-------|-------|-------|
| Baseline | jupyter-3.5.7 | jupyter-3.5.8 | jupyter-4.1.0 | jupyter-4.1.1 |
| GPU | jupyter-3.5.7-gpu | jupyter-3.5.8-gpu | jupyter-4.1.0-gpu | jupyter-4.1.1-gpu |
| Iceberg | jupyter-3.5.7-iceberg | jupyter-3.5.8-iceberg | jupyter-4.1.0-iceberg | jupyter-4.1.1-iceberg |
| GPU+Iceberg | - | - | jupyter-4.1.0-gpu-iceberg | jupyter-4.1.1-gpu-iceberg |

### 3. Layer Composition

**Baseline Spark Image:**
```
FROM spark-k8s-jdk-17:latest
+ spark-k8s-spark-X.X.X-core:latest
+ spark-k8s-python-deps:latest
+ spark-k8s-jdbc-drivers:latest
```

**GPU Spark Image:**
```
FROM spark-k8s-jdk-17:latest
+ spark-k8s-spark-X.X.X-core:latest
+ spark-k8s-python-deps:latest (GPU variant)
+ spark-k8s-jdbc-drivers:latest
+ spark-k8s-jars-rapids:latest
+ spark-k8s-cuda-12.1:latest
```

**Iceberg Spark Image:**
```
FROM spark-k8s-jdk-17:latest
+ spark-k8s-spark-X.X.X-core:latest
+ spark-k8s-python-deps:latest (Iceberg variant)
+ spark-k8s-jdbc-drivers:latest
+ spark-k8s-jars-iceberg:latest
```

### 4. Build Optimization

**Multi-stage builds for 60-80% size reduction:**

```dockerfile
# Build stage
FROM spark-k8s-spark-3.5.7-core:latest as builder

# Install build-time dependencies only
RUN apk add --no-cache gcc musl-dev

# Build Python extensions
RUN pip install --no-cache-dir --requirement /tmp/requirements-build.txt

# Runtime stage (smaller)
FROM spark-k8s-jdk-17:latest
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
```

**Expected size reduction:**
- Baseline: ~2GB → ~800MB (60% reduction)
- GPU: ~4GB → ~1.5GB (62% reduction)
- Iceberg: ~2.5GB → ~1GB (60% reduction)

### 5. Integration Testing

**Test scenarios per image:**

| Test | Baseline | GPU | Iceberg | GPU+Iceberg |
|------|----------|-----|---------|-------------|
| spark-shell --version | ✅ | ✅ | ✅ | ✅ |
| spark-submit pi.py | ✅ | ✅ | ✅ | ✅ |
| python -c "import pyspark" | ✅ | ✅ | ✅ | ✅ |
| GPU detection (nvidia-smi) | skip | ✅ | skip | ✅ |
| Iceberg catalog | skip | skip | ✅ | ✅ |
| RAPIDS import (cudf) | skip | ✅ | skip | ✅ |

### 6. Build Script

**Parallel build orchestration:**

```bash
#!/bin/bash
# docker/runtime/build-all.sh

set -e

VERSIONS="3.5.7 3.5.8 4.1.0 4.1.1"
VARIANTS="baseline gpu iceberg gpu-iceberg"

build_image() {
    local version="$1"
    local variant="$2"

    echo "Building spark-${version}-${variant}..."

    docker build \
        --build-arg SPARK_VERSION="${version}" \
        --build-arg ENABLE_GPU="$([ "$variant" = "gpu" ] || [ "$variant" = "gpu-iceberg" ] && echo true || echo false)" \
        --build-arg ENABLE_ICEBERG="$([ "$variant" = "iceberg" ] || [ "$variant" = "gpu-iceberg" ] && echo true || echo false)" \
        -t "spark-k8s-spark-${version}-${variant}:latest" \
        -f Dockerfile.spark .

    echo "✅ Built spark-${version}-${variant}"
}

export -f build_image
parallel --jobs 4 build_image ::: "${VERSIONS[@]}" ::: "${VARIANTS[@]}"
```

## Dependencies

- **Phase 4 (F10):** All intermediate layers required
- **WS-011-01:** Requires WS-010-01, WS-010-02, WS-010-03, WS-010-04
- **WS-011-02:** Requires WS-010-01, WS-010-02, WS-010-03, WS-010-04
- **WS-011-03:** Requires WS-011-01, WS-011-02, WS-009-02 (Python base)

## Success Criteria

1. ⏳ 28 final Dockerfiles созданы (Spark 16 + Jupyter 12)
2. ⏳ Integration тесты проходят для всех вариантов
3. ⏳ Размер образов уменьшен на 60-80% vs monolithic
4. ⏳ GPU, Iceberg, GPU+Iceberg варианты работают корректно
5. ⏳ Build script выполняет параллельную сборку
6. ⏳ Все образы проходят smoke тесты из Phase 2

## File Structure

```
docker/
├── runtime/
│   ├── spark/
│   │   ├── Dockerfile
│   │   ├── build-all.sh
│   │   └── test-all.sh
│   ├── jupyter/
│   │   ├── Dockerfile
│   │   ├── build-all.sh
│   │   └── test-all.sh
│   └── tests/
│       ├── test-spark-baseline.sh
│       ├── test-spark-gpu.sh
│       ├── test-spark-iceberg.sh
│       └── test-jupyter-*.sh
└── images/
    └── README.md  # image catalog
```

## Integration with Other Phases

- **Phase 3 (F09):** Base images used as foundation
- **Phase 4 (F10):** Intermediate layers combined via multi-stage builds
- **Phase 2 (F08):** Images validated by smoke tests
- **Phase 0 (F06):** Chart values reference final image tags

## Beads Integration

```bash
# Feature
spark_k8s-3hr - F11: Phase 5 - Docker Final Images (P1)

# Workstreams
spark_k8s-hbc - WS-011-01: Spark 3.5 images (P1)
spark_k8s-ehu - WS-011-02: Spark 4.1 images (P1)
spark_k8s-2dg - WS-011-03: Jupyter images (P1)

# Dependencies
All WS depend on F10 (Phase 4)
WS-011-03 depends on WS-011-01, WS-011-02
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-03-docker-base.md](./phase-03-docker-base.md)
- [phase-04-docker-intermediate.md](./phase-04-docker-intermediate.md)
