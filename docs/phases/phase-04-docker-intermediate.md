# Phase 4: Docker Intermediate Layers (Updated)

> **Status:** Backlog
> **Priority:** P1 - Infrastructure
> **Feature:** F10
> **Estimated Workstreams:** 4
> **Estimated LOC:** ~1550

## Goal

Create intermediate Docker layers that extend custom Spark builds (compiled from source with Hadoop 3.4.2 for AWS SDK v2 compatibility).

## Current State

**Updated 2026-02-04** - Redesigned to use custom Spark builds instead of Apache distros.

- Custom Spark builds exist in `docker/spark-custom/` (3.5.7, 4.1.0 with Hadoop 3.4.2)
- Previous design incorrectly used Apache distros (Hadoop 3.3.x)
- Some intermediate layers partially created (JDBC, RAPIDS, Iceberg)
- Need to update to extend custom builds

## Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-010-01 | Custom Spark wrapper layers (2) + tests | SMALL (~300 LOC) | Independent | backlog |
| WS-010-02 | Python dependencies layer + test | MEDIUM (~400 LOC) | Independent | backlog |
| WS-010-03 | JDBC drivers layer update + test | SMALL (~250 LOC) | WS-010-01 | backlog |
| WS-010-04 | JARs layers (RAPIDS, Iceberg) + tests | MEDIUM (~600 LOC) | WS-010-01 | backlog |

## Design Decisions

### 1. Custom Spark Builds as Foundation

**Strategy:** Use existing custom builds compiled from source

| Image | Base | Hadoop | AWS SDK | Location |
|-------|------|--------|---------|----------|
| spark-3.5.7-hadoop3.4.2 | Ubuntu 22.04 | 3.4.2 | v2 | docker/spark-custom/Dockerfile.3.5.7 |
| spark-4.1.0-hadoop3.4.2 | Ubuntu 22.04 | 3.4.2 | v2 | docker/spark-custom/Dockerfile.4.1.0 |

**Custom build contents:**
- Spark compiled from source with Hadoop 3.4.2
- AWS SDK v2 bundle (2.29.52)
- JDBC drivers: PostgreSQL, Oracle, Vertica
- Python 3.11 with PySpark, pandas, numpy, pyarrow
- Kafka support (spark-sql-kafka-0-10)
- Kubernetes python client

### 2. Wrapper Layers (WS-010-01)

**Purpose:** Provide consistent naming for intermediate layers

| Layer | Base Image | Purpose |
|-------|-----------|---------|
| spark-3.5.7-custom | spark-k8s:3.5.7-hadoop3.4.2 | Reference wrapper for 3.5.7 |
| spark-4.1.0-custom | spark-k8s:4.1.0-hadoop3.4.2 | Reference wrapper for 4.1.0 |

**Note:** These are lightweight wrappers that verify and document the custom builds.

### 3. Python Dependencies (WS-010-02)

**Strategy:** Extend custom builds with optional GPU and Iceberg support

| Variant | Build Arg | Content |
|---------|-----------|---------|
| base | (default) | (Already in custom build) |
| gpu | BUILD_GPU_DEPS=true | cudf, cuml, cupy (RAPIDS) |
| iceberg | BUILD_ICEBERG_DEPS=true | pyiceberg, fsspec |
| gpu-iceberg | Both=true | All optional packages |

**Note:** Custom builds already include base Python packages (pyspark, pandas, numpy, pyarrow).

### 4. JDBC Drivers (WS-010-03)

**Strategy:** Add MySQL and MSSQL to existing drivers from custom build

| Driver | Version | Source | Location |
|--------|---------|--------|----------|
| PostgreSQL | 42.7.4 | From custom build | $SPARK_HOME/jars/ |
| Oracle | 23.5.0.24.07 | From custom build | $SPARK_HOME/jars/ |
| Vertica | 12.0.4-0 | From custom build | $SPARK_HOME/jars/ |
| MySQL | 9.1.0 | Added by this layer | $SPARK_HOME/jars/ |
| MSSQL | 12.4.2.jre11 | Added by this layer | $SPARK_HOME/jars/ |

**Convenience symlinks:** `/opt/jdbc/{mysql,mssql,postgresql,oracle,vertica}.jar`

### 5. JARs Layers (WS-010-04)

**Strategy:** Extend custom builds with RAPIDS and Iceberg JARs

| Layer | Content | Spark 3.5.7 | Spark 4.1.0 |
|-------|---------|------------|------------|
| jars-rapids | rapids-4-spark, cudf | Scala 2.12 | Scala 2.13 |
| jars-iceberg | iceberg-spark-runtime, iceberg-aws | Scala 2.12 | Scala 2.13 |

**Build scripts:** Separate for each Spark version (different Scala versions)

### 6. Version Coverage

| Spark Version | Custom Build | Wrapper | Support |
|--------------|--------------|---------|---------|
| 3.5.7 | Yes | Yes | Full |
| 4.1.0 | Yes | Yes | Full |
| 3.5.8 | No | No | Create if needed |
| 4.1.1 | No | No | Create if needed |

## Dependencies

- **Independent:** WS-010-01, WS-010-02 (can start immediately)
- **WS-010-01完成后:** WS-010-03, WS-010-04 (depend on wrapper layers)

## Dependency Graph

```
WS-010-01 (Custom Wrappers)
    │
    ├──────────────────────────────────┐
    │                                  │
    ▼                                  ▼
WS-010-03 (JDBC Drivers)          WS-010-04 (JARs Layers)
                            ┌──────────┴─────────┐
                            │                    │
                            ▼                    ▼
                      WS-010-02              (Parallel
                      (Python Deps)           execution OK)
```

## Execution Order

**Phase 1: Foundation**
- WS-010-01: Custom Spark wrapper layers

**Phase 2: Parallel execution (after WS-010-01)**
- WS-010-02: Python dependencies layer
- WS-010-03: JDBC drivers layer update
- WS-010-04: JARs layers (RAPIDS, Iceberg)

## Success Criteria

1. Custom wrapper layers created for 3.5.7 and 4.1.0
2. Python dependencies layer supports GPU and Iceberg variants
3. JDBC drivers layer adds MySQL and MSSQL
4. JARs layers support both Spark 3.5.7 and 4.1.0
5. All layers verify Hadoop 3.4.2 and AWS SDK v2 presence
6. Unit tests pass for all layers

## File Structure

```
docker/
├── spark-custom/                    # Custom builds (existing)
│   ├── Dockerfile.3.5.7             # Spark 3.5.7 + Hadoop 3.4.2
│   ├── Dockerfile.4.1.0             # Spark 4.1.0 + Hadoop 3.4.2
│   ├── Makefile
│   ├── build-and-load.sh
│   └── README.md
├── docker-intermediate/             # Intermediate layers (updated)
│   ├── spark-3.5.7-custom/          # NEW: Wrapper for 3.5.7
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── spark-4.1.0-custom/          # NEW: Wrapper for 4.1.0
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── python-deps/                 # UPDATED: Extends custom builds
│   │   ├── Dockerfile
│   │   ├── requirements-base.txt
│   │   ├── requirements-gpu.txt
│   │   ├── requirements-iceberg.txt
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── jdbc-drivers/                # UPDATED: Adds MySQL, MSSQL
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── jars-rapids/                 # UPDATED: Extends custom builds
│   │   ├── Dockerfile
│   │   ├── build-3.5.7.sh
│   │   ├── build-4.1.0.sh
│   │   ├── test.sh
│   │   └── README.md
│   └── jars-iceberg/                # UPDATED: Extends custom builds
│       ├── Dockerfile
│       ├── build-3.5.7.sh
│       ├── build-4.1.0.sh
│       ├── test.sh
│       └── README.md
└── docker-base/                     # REMOVED: spark-core directory
```

## Integration with Other Phases

- **Custom Spark builds:** Foundation for all intermediate layers
- **Phase 3 (F09):** Base images (JDK 17) used by custom builds
- **Phase 2 (F08):** Intermediate images used in smoke tests
- **Phase 5 (F11):** Runtime images built on top of intermediate layers

## Beads Integration

```bash
# Feature
spark_k8s-dc0 - F10: Phase 4 - Docker Intermediate Layers (P1)

# Workstreams
spark_k8s-abc - WS-010-01: Custom Spark wrapper layers (P1)
spark_k8s-def - WS-010-02: Python dependencies (P1)
spark_k8s-ghi - WS-010-03: JDBC drivers (P1)
spark_k8s-jkl - WS-010-04: JARs layers (P1)

# Dependencies
WS-010-03 depends on WS-010-01
WS-010-04 depends on WS-010-01
WS-010-02 independent (can run parallel)
```

## Key Changes from Original Design

| Aspect | Original | Updated |
|--------|----------|---------|
| Base Image | Apache distro | Custom build |
| Hadoop Version | 3.3.x | 3.4.2 |
| AWS SDK | v1 (incompatible) | v2 (compatible) |
| Spark Versions | 3.5.7, 3.5.8, 4.1.0, 4.1.1 | 3.5.7, 4.1.0 |
| Source | Download binary | Compile from source |
| JDBC | All 5 in layer | 3 in custom, 2 added |
| Python | All in layer | Base in custom, optional added |

## References

- [Redesign Summary](../workstreams/backlog/F10-REDESIGN-SUMMARY.md)
- [Custom Builds](../../docker/spark-custom/README.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [workstreams/backlog/WS-010-01.md](../workstreams/backlog/WS-010-01.md)
- [workstreams/backlog/WS-010-02.md](../workstreams/backlog/WS-010-02.md)
- [workstreams/backlog/WS-010-03.md](../workstreams/backlog/WS-010-03.md)
- [workstreams/backlog/WS-010-04.md](../workstreams/backlog/WS-010-04.md)
