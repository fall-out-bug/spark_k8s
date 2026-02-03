# Phase 4: Docker Intermediate Layers

> **Status:** Backlog
> **Priority:** P1 - Инфраструктура
> **Feature:** F10
> **Estimated Workstreams:** 4
> **Estimated LOC:** ~2500

## Goal

Создать промежуточные Docker слои (Spark core, Python deps, JDBC drivers, JARs) с unit тестами для оптимизированных Spark образов.

## Current State

**Не реализовано** — Phase 4 только начинается.

## Updated Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-010-01 | Spark core layers (4) + tests | MEDIUM (~800 LOC) | Phase 3 (F09) | backlog |
| WS-010-02 | Python dependencies layer + test | MEDIUM (~600 LOC) | Phase 3 (F09) | backlog |
| WS-010-03 | JDBC drivers layer + test | SMALL (~500 LOC) | Phase 3 (F09) | backlog |
| WS-010-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~700 LOC) | Phase 3 (F09), WS-010-01 | backlog |

## Design Decisions

### 1. Spark Core Layers

**Strategy:** One layer per Spark version

| Image | Base | Content | Size Target |
|-------|------|---------|-------------|
| spark-3.5.7-core | jdk-17 | Spark 3.5.7 binary | < 1GB |
| spark-3.5.8-core | jdk-17 | Spark 3.5.8 binary | < 1GB |
| spark-4.1.0-core | jdk-17 | Spark 4.1.0 binary | < 1GB |
| spark-4.1.1-core | jdk-17 | Spark 4.1.1 binary | < 1GB |

**Download Source:** Apache mirrors
**Caching:** Layer caching enabled for fast rebuilds

### 2. Python Dependencies

**Strategy:** Single Dockerfile with build args for variants

| Variant | Build Arg | Content |
|---------|-----------|---------|
| base | (default) | pandas, numpy, pyarrow, pyspark |
| gpu | BUILD_GPU_DEPS=true | + cudf, cuml, cupy |
| iceberg | BUILD_ICEBERG_DEPS=true | + pyiceberg, fsspec |

**Requirements Files:**
- `requirements-base.txt` — core data science libraries
- `requirements-gpu.txt` — RAPIDS GPU libraries
- `requirements-iceberg.txt` — Iceberg support

### 3. JDBC Drivers

**Strategy:** Single layer with multiple drivers

| Driver | Version | Source | Required |
|--------|---------|--------|----------|
| PostgreSQL | 42.7.1 | postgresql.org | Yes |
| MySQL | 8.2.0 | Maven Central | Yes |
| Oracle | 21.11.0.0 | Maven Central | Yes |
| MSSQL | 12.4.2.jre11 | Maven Central | Yes |
| Vertica | 12.0.4-0 | Maven Central | Yes |

**Classpath:** All JARs added to CLASSPATH environment variable

### 4. JARs Layers

**Strategy:** Separate layers for RAPIDS and Iceberg

| Layer | Content | Spark Jars Location |
|-------|---------|---------------------|
| jars-rapids | rapids-4-spark, cudf | $SPARK_HOME/jars/ |
| jars-iceberg | iceberg-spark-runtime, iceberg-aws | $SPARK_HOME/jars/ |

**Download Sources:**
- RAPIDS: NVIDIA Maven repository
- Iceberg: Apache Maven repository

### 5. Layer Reuse Strategy

**Multi-stage builds with --from=**

```dockerfile
# Final runtime image
FROM spark-k8s-jdk-17:latest as base
FROM spark-k8s-python-3.10:latest as python
FROM spark-k8s-spark-3.5.7-core:latest as spark
FROM spark-k8s-python-deps:latest as deps
FROM spark-k8s-jdbc-drivers:latest as jdbc
FROM spark-k8s-jars-rapids:latest as jars-rapids

# Combine layers
FROM spark
COPY --from=python /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=deps /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=jdbc /opt/jdbc /opt/jdbc
COPY --from=jars-rapids $SPARK_HOME/jars/rapids*.jar $SPARK_HOME/jars/
```

### 6. Download Caching

**Strategy:** Use BuildKit cache mounts

```dockerfile
# --mount=type=cache for pip
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# wget downloads cached by Docker layer
RUN wget -q https://downloads.apache.org/spark/...
```

## Dependencies

- **Phase 3 (F09):** All base layers (JDK 17, Python 3.10, CUDA 12.1)
- **WS-010-01:** Requires WS-009-01 (JDK 17 base)
- **WS-010-02:** Requires WS-009-02 (Python 3.10 base)
- **WS-010-03:** Requires WS-009-01 (JDK 17 base)
- **WS-010-04:** Requires WS-010-01 (Spark core layers)

## Success Criteria

1. ⏳ 7 intermediate Dockerfiles созданы
2. ⏳ 4 unit теста проходят
3. ⏳ Слои переиспользуются правильно (multi-stage builds)
4. ⏳ JARs скачиваются и кешируются
5. ⏳ Размер образов оптимизирован

## File Structure

```
docker/
├── docker-intermediate/
│   ├── spark-3.5.7-core/
│   │   ├── Dockerfile
│   │   └── test.sh
│   ├── spark-3.5.8-core/
│   │   ├── Dockerfile
│   │   └── test.sh
│   ├── spark-4.1.0-core/
│   │   ├── Dockerfile
│   │   └── test.sh
│   ├── spark-4.1.1-core/
│   │   ├── Dockerfile
│   │   └── test.sh
│   ├── python-deps/
│   │   ├── Dockerfile
│   │   ├── requirements-base.txt
│   │   ├── requirements-gpu.txt
│   │   ├── requirements-iceberg.txt
│   │   └── test.sh
│   ├── jdbc-drivers/
│   │   ├── Dockerfile
│   │   └── test.sh
│   ├── jars-rapids/
│   │   ├── Dockerfile
│   │   └── test.sh
│   └── jars-iceberg/
│       ├── Dockerfile
│       └── test.sh
└── runtime/
    ├── spark-3.5.7-jdk17/
    │   └── Dockerfile  # uses intermediate layers
    └── ...
```

## Integration with Other Phases

- **Phase 3 (F09):** Base images used as FROM sources
- **Phase 2 (F08):** Intermediate images used in smoke tests
- **Phase 5:** Runtime images built on top of intermediate layers

## Beads Integration

```bash
# Feature
spark_k8s-dc0 - F10: Phase 4 - Docker Intermediate Layers (P1)

# Workstreams
spark_k8s-3vr - WS-010-01: Spark core layers (P1)
spark_k8s-89o - WS-010-02: Python dependencies (P1)
spark_k8s-ch5 - WS-010-03: JDBC drivers (P1)
spark_k8s-7cv - WS-010-04: JARs layers (P1)

# Dependencies
WS-010-01 depends on F09 (WS-009-01)
WS-010-02 depends on F09 (WS-009-02)
WS-010-03 depends on F09 (WS-009-01)
WS-010-04 depends on WS-010-01
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [workstreams/backlog/00-010-01.md](../workstreams/backlog/00-010-01.md)
- [workstreams/backlog/00-010-02.md](../workstreams/backlog/00-010-02.md)
- [workstreams/backlog/00-010-03.md](../workstreams/backlog/00-010-03.md)
- [workstreams/backlog/00-010-04.md](../workstreams/backlog/00-010-04.md)
