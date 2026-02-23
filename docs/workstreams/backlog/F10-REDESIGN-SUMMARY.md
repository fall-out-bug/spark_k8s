# F10 Redesign Summary: Custom Spark Build Architecture

## Overview

This document summarizes the redesign of Feature F10 (Phase 4 - Docker Intermediate Layers) to use existing custom Spark builds instead of Apache distros.

## Problem Statement

### Original Design (Incorrect)
- Used Apache Spark distros with Hadoop 3.3.x
- Downloaded from Apache mirrors
- **Issue**: Hadoop 3.3.x includes AWS SDK v1, incompatible with modern S3 requirements
- Created intermediate layers in `docker/docker-base/spark-core/`

### Custom Builds (Already Exist)
- Located in `docker/spark-custom/`
- Spark 3.5.7 and 4.1.0 compiled from source with Hadoop 3.4.2
- Include AWS SDK v2 bundle for S3 compatibility
- Monolithic: include JDBC drivers, Python deps, Kafka support

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    docker/spark-custom/                         │
│  ┌────────────────────┐  ┌────────────────────┐                │
│  │ Dockerfile.3.5.7   │  │ Dockerfile.4.1.0   │                │
│  │ (Hadoop 3.4.2)     │  │ (Hadoop 3.4.2)     │                │
│  │ - Spark source     │  │ - Spark source     │                │
│  │ - AWS SDK v2       │  │ - AWS SDK v2       │                │
│  │ - JDBC (3 drivers) │  │ - JDBC (3 drivers) │                │
│  │ - Python deps      │  │ - Python deps      │                │
│  │ - Kafka support    │  │ - Kafka support    │                │
│  └────────────────────┘  └────────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Extended by
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              docker/docker-intermediate/                        │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │ WS-010-01        │  │ WS-010-03        │                    │
│  │ Wrapper Layers   │  │ JDBC Drivers     │                    │
│  │ (3.5.7, 4.1.0)   │  │ (+MySQL, MSSQL)  │                    │
│  └──────────────────┘  └──────────────────┘                    │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │ WS-010-02        │  │ WS-010-04        │                    │
│  │ Python Deps      │  │ JARs Layers      │                    │
│  │ (GPU, Iceberg)   │  │ (RAPIDS, Iceberg)│                    │
│  └──────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## Cleanup Commands

### Remove Incorrect Implementation

```bash
# Remove incorrect Apache distro implementation
rm -rf /home/fall_out_bug/work/s7/spark_k8s/docker/docker-base/spark-core/

# Verify cleanup
ls -la /home/fall_out_bug/work/s7/spark_k8s/docker/docker-base/
```

## Updated Workstreams

### WS-010-01: Custom Spark Core Wrapper Layers
**Status:** Backlog (to be executed)

**Changes:**
- Removes `docker/docker-base/spark-core/`
- Creates wrapper layers that reference custom builds
- Provides consistent naming for intermediate layers

**Output:**
- `docker/docker-intermediate/spark-3.5.7-custom/`
- `docker/docker-intermediate/spark-4.1.0-custom/`

### WS-010-02: Python Dependencies Layer
**Status:** Backlog (to be executed)

**Changes:**
- Now extends custom Spark builds (not JDK base)
- Adds optional GPU (cudf, cuml) and Iceberg (pyiceberg) support
- Base Python deps already in custom builds

**Output:**
- `docker/docker-intermediate/python-deps/`
  - requirements-base.txt
  - requirements-gpu.txt
  - requirements-iceberg.txt
  - Dockerfile (with variant build args)

### WS-010-03: JDBC Drivers Layer
**Status:** Backlog (update existing)

**Changes:**
- Updates existing layer to extend custom builds
- Removes dependency on JDK base image
- Adds MySQL and MSSQL (PostgreSQL, Oracle, Vertica already in custom build)

**Output:**
- `docker/docker-intermediate/jdbc-drivers/` (updated)

### WS-010-04: JARs Layers (RAPIDS, Iceberg)
**Status:** Backlog (update existing)

**Changes:**
- Updates both layers to extend custom builds
- Separate build scripts for Spark 3.5.7 (Scala 2.12) and 4.1.0 (Scala 2.13)
- Preserves Hadoop 3.4.2 and AWS SDK v2 from custom builds

**Output:**
- `docker/docker-intermediate/jars-rapids/` (updated)
- `docker/docker-intermediate/jars-iceberg/` (updated)

## Version Coverage

### Supported
| Spark Version | Hadoop | Scala | Custom Build | Wrapper Layer |
|--------------|--------|-------|--------------|---------------|
| 3.5.7 | 3.4.2 | 2.12 | Yes | Yes |
| 4.1.0 | 3.4.2 | 2.13 | Yes | Yes |

### Not Supported
| Spark Version | Hadoop | Status |
|--------------|--------|--------|
| 3.5.8 | 3.4.2 | No custom build (create if needed) |
| 4.1.1 | 3.4.2 | No custom build (create if needed) |

**Recommendation:** Use 3.5.7 and 4.1.0 only. If newer versions are needed, create new Dockerfile in `docker/spark-custom/`.

## Dependency Graph

```
WS-010-01 (Custom Wrappers)
    │
    ├───────────────────────────────┐
    │                               │
    ▼                               ▼
WS-010-03 (JDBC)              WS-010-04 (JARs)
                            ┌───────┴────────┐
                            │                │
                            ▼                ▼
                      WS-010-02        (can run
                      (Python Deps)     in parallel)
```

## Execution Order

1. **WS-010-01** (must be first) - Creates wrapper layers
2. **Parallel:** WS-010-02, WS-010-03, WS-010-04
   - All depend on custom builds being referenced
   - Can run simultaneously after WS-010-01

## Directory Structure (After Completion)

```
docker/
├── spark-custom/                    # Custom builds (existing)
│   ├── Dockerfile.3.5.7
│   ├── Dockerfile.4.1.0
│   ├── Makefile
│   └── README.md
├── docker-intermediate/             # Updated intermediate layers
│   ├── spark-3.5.7-custom/          # NEW - wrapper layer
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── spark-4.1.0-custom/          # NEW - wrapper layer
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── python-deps/                 # UPDATED
│   │   ├── Dockerfile
│   │   ├── requirements-*.txt
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── jdbc-drivers/                # UPDATED
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   ├── test.sh
│   │   └── README.md
│   ├── jars-rapids/                 # UPDATED
│   │   ├── Dockerfile
│   │   ├── build-3.5.7.sh
│   │   ├── build-4.1.0.sh
│   │   ├── test.sh
│   │   └── README.md
│   └── jars-iceberg/                # UPDATED
│       ├── Dockerfile
│       ├── build-3.5.7.sh
│       ├── build-4.1.0.sh
│       ├── test.sh
│       └── README.md
└── docker-base/                     # Cleaned up
    └── (spark-core removed)
```

## Key Changes Summary

| Aspect | Original Design | Updated Design |
|--------|----------------|----------------|
| Base Image | Apache distro (Hadoop 3.3.x) | Custom build (Hadoop 3.4.2) |
| AWS SDK | v1 (incompatible) | v2 (compatible) |
| JDBC Drivers | All 5 in layer | 3 in custom, 2 added |
| Python Deps | All in layer | Base in custom, optional in layer |
| Spark Versions | 3.5.7, 3.5.8, 4.1.0, 4.1.1 | 3.5.7, 4.1.0 only |
| Source Code | Download binary | Compile from source |

## Testing Strategy

### Unit Tests (per layer)
1. Image exists and runs
2. SPARK_HOME correctly set
3. Custom build contents verified (Hadoop 3.4.2, AWS SDK v2)
4. Layer-specific content verified (JDBC, JARs, Python)
5. Spark integration works (spark-submit --version)

### Integration Tests
1. Intermediate layers build successfully
2. Final runtime images can be built
3. Smoke tests pass (Phase 2)

## Next Steps

1. Execute `@build WS-010-01` - Create wrapper layers
2. Execute in parallel:
   - `@build WS-010-02` - Python dependencies
   - `@build WS-010-03` - JDBC drivers update
   - `@build WS-010-04` - JARs layers update
3. Update `docs/phases/phase-04-docker-intermediate.md`
4. Run smoke tests to verify integration

## References

- Custom Spark builds: `docker/spark-custom/`
- Workstream specifications: `docs/workstreams/backlog/WS-010-*.md`
- Phase documentation: `docs/phases/phase-04-docker-intermediate.md`
- Project map: `docs/PROJECT_MAP.md`
