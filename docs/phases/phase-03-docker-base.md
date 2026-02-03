# Phase 3: Docker Base Layers

> **Status:** Backlog
> **Priority:** P1 - Инфраструктура
> **Feature:** F09
> **Estimated Workstreams:** 3
> **Estimated LOC:** ~1050

## Goal

Создать базовые Docker слои (JDK 17, Python 3.10, CUDA 12.1) с unit тестами для оптимизированных Spark образов.

## Current State

**Не реализовано** — Phase 3 только начинается.

## Updated Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-009-01 | JDK 17 base layer + test | SMALL (~300 LOC) | None | backlog |
| WS-009-02 | Python 3.10 base layer + test | SMALL (~250 LOC) | None | backlog |
| WS-009-03 | CUDA 12.1 base layer + test | MEDIUM (~500 LOC) | WS-009-01 | backlog |

## Design Decisions

### 1. Base Images Selection

| Layer | Base Image | Rationale |
|-------|-----------|-----------|
| JDK 17 | eclipse-temurin:17-jre-alpine | OpenJDK, Alpine for minimal size |
| Python 3.10 | python:3.10-alpine | Official Python, Alpine for minimal size |
| CUDA 12.1 | nvidia/cuda:12.1.0-runtime-ubuntu22.04 | NVIDIA official, Ubuntu for compatibility |

### 2. Image Size Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| JDK 17 | < 200MB | JRE-only + Alpine |
| Python 3.10 | < 300MB | Alpine + build deps |
| CUDA 12.1 | < 4GB | Runtime + JDK (Ubuntu unavoidable) |

### 3. Testing Strategy

**GPU Testing:**
- CUDA tests skip gracefully when no GPU available
- Use `nvidia-smi` detection for skip logic
- CI: run with GPU emulation or skip

**Unit Tests:**
- Each layer has its own test.sh
- Tests verify: installation, version, utilities, size
- All tests must pass for WS completion

### 4. Common Components

**Shared across all layers:**
- bash (default shell)
- curl (for health checks)
- ca-certificates (for HTTPS)
- HEALTHCHECK instruction

**Layer-specific:**
- JDK: java, javac
- Python: python, pip, setuptools
- CUDA: nvidia-smi, CUDA libraries

### 5. Build Optimization

**Multi-stage builds:**
- Use for JDK (build with JDK, runtime with JRE)
- Not needed for Python (already minimal)
- Not needed for CUDA (runtime-only)

**Layer caching:**
- Order Dockerfile commands by change frequency
- COPY requirements.txt before source code
- Use --mount for pip cache (BuildKit)

## Dependencies

- **WS-009-01:** None (can start immediately)
- **WS-009-02:** None (parallel with WS-009-01)
- **WS-009-03:** WS-009-01 (extends JDK base)

## Success Criteria

1. ⏳ 3 base Dockerfiles созданы
2. ⏳ 3 unit теста проходят
3. ⏳ Размер образов оптимизирован (<200MB JDK, <300MB Python, <4GB CUDA)
4. ⏳ Образы используются в Stage 4 (Spark images)

## File Structure

```
docker/
├── docker-base/
│   ├── jdk-17/
│   │   ├── Dockerfile
│   │   ├── test.sh
│   │   └── README.md
│   ├── python-3.10/
│   │   ├── Dockerfile
│   │   ├── test.sh
│   │   └── README.md
│   └── cuda-12.1/
│       ├── Dockerfile
│       ├── test.sh
│       └── README.md
└── spark-3.5.7-jdk17/
    ├── Dockerfile  # uses spark-k8s-jdk-17:latest
    └── ...
```

## Integration with Other Phases

- **Phase 0 (F06):** Base images referenced in chart values
- **Phase 2 (F08):** Used in smoke tests for GPU scenarios
- **Phase 4:** Spark runtime images built on top of these bases
- **Phase 5:** Optimized images use base layers

## Beads Integration

```bash
# Feature
spark_k8s-nxo - F09: Phase 3 - Docker Base Layers (P1)

# Workstreams
spark_k8s-fl6 - WS-009-01: JDK 17 base layer (P1)
spark_k8s-w8l - WS-009-02: Python 3.10 base layer (P1)
spark_k8s-4ll - WS-009-03: CUDA 12.1 base layer (P1)

# Dependencies
WS-009-03 depends on WS-009-01
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [workstreams/backlog/00-009-01.md](../workstreams/backlog/00-009-01.md)
- [workstreams/backlog/00-009-02.md](../workstreams/backlog/00-009-02.md)
- [workstreams/backlog/00-009-03.md](../workstreams/backlog/00-009-03.md)
