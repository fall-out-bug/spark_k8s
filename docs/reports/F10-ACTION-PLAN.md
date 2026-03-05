# F10 Action Plan: Redesign to Use Custom Spark Builds

## Quick Start

```bash
# 1. Cleanup incorrect implementation
./scripts/cleanup-incorrect-f10.sh

# 2. Execute workstreams
@build WS-010-01  # Creates wrapper layers (must be first)
@build WS-010-02  # Python dependencies (can run in parallel)
@build WS-010-03  # JDBC drivers update (can run in parallel)
@build WS-010-04  # JARs layers update (can run in parallel)
```

## Executive Summary

**Problem:** Previous F10 design used Apache Spark distros with Hadoop 3.3.x, which includes AWS SDK v1 (incompatible with modern S3).

**Solution:** Redesign F10 to use existing custom Spark builds that have Hadoop 3.4.2 with AWS SDK v2.

**Impact:**
- 4 workstreams redesigned (WS-010-01 through WS-010-04)
- Incorrect implementation removed (`docker/docker-base/spark-core/`)
- Intermediate layers now extend custom builds
- Version coverage reduced to 3.5.7 and 4.1.0 (no 3.5.8, 4.1.1)

## Files Created/Updated

### Workstream Specifications
1. `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/WS-010-01.md`
   - Custom Spark wrapper layers
   - Removes incorrect `docker/docker-base/spark-core/`
   - Creates wrappers for 3.5.7 and 4.1.0

2. `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/WS-010-02.md`
   - Python dependencies layer
   - GPU and Iceberg variants
   - Extends custom builds

3. `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/WS-010-03.md`
   - JDBC drivers layer update
   - Adds MySQL and MSSQL
   - PostgreSQL, Oracle, Vertica already in custom build

4. `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/WS-010-04.md`
   - JARs layers (RAPIDS, Iceberg) update
   - Separate build scripts for 3.5.7 (Scala 2.12) and 4.1.0 (Scala 2.13)
   - Extends custom builds

### Documentation
5. `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/F10-REDESIGN-SUMMARY.md`
   - Detailed redesign summary
   - Architecture diagrams
   - Before/after comparison

6. `/home/fall_out_bug/work/s7/spark_k8s/docs/phases/phase-04-docker-intermediate.md`
   - Updated phase documentation
   - Reflects custom build architecture

### Scripts
7. `/home/fall_out_bug/work/s7/spark_k8s/scripts/cleanup-incorrect-f10.sh`
   - Cleanup script for incorrect implementation
   - Removes `docker/docker-base/spark-core/`

## Cleanup Commands

```bash
# Option 1: Use the cleanup script
./scripts/cleanup-incorrect-f10.sh

# Option 2: Manual cleanup
rm -rf /home/fall_out_bug/work/s7/spark_k8s/docker/docker-base/spark-core/

# Verify cleanup
ls -la /home/fall_out_bug/work/s7/spark_k8s/docker/docker-base/
```

## Workstream Execution

### WS-010-01: Custom Spark Wrapper Layers (MUST BE FIRST)
```bash
@build WS-010-01
```
- Removes incorrect `docker/docker-base/spark-core/`
- Creates `docker/docker-intermediate/spark-3.5.7-custom/`
- Creates `docker/docker-intermediate/spark-4.1.0-custom/`
- ~300 LOC (SMALL)

### WS-010-02: Python Dependencies Layer (PARALLEL)
```bash
@build WS-010-02
```
- Creates `docker/docker-intermediate/python-deps/`
- Support for GPU (cudf, cuml) and Iceberg (pyiceberg) variants
- ~400 LOC (MEDIUM)

### WS-010-03: JDBC Drivers Layer (PARALLEL)
```bash
@build WS-010-03
```
- Updates existing `docker/docker-intermediate/jdbc-drivers/`
- Adds MySQL and MSSQL (others in custom build)
- ~250 LOC (SMALL)

### WS-010-04: JARs Layers (PARALLEL)
```bash
@build WS-010-04
```
- Updates `docker/docker-intermediate/jars-rapids/`
- Updates `docker/docker-intermediate/jars-iceberg/`
- Separate build scripts for 3.5.7/4.1.0
- ~600 LOC (MEDIUM)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                 docker/spark-custom/                        │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ Dockerfile.3.5.7 │  │ Dockerfile.4.1.0 │               │
│  │ Hadoop 3.4.2     │  │ Hadoop 3.4.2     │               │
│  │ AWS SDK v2       │  │ AWS SDK v2       │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ Extended by
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              docker/docker-intermediate/                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ WS-010-01    │  │ WS-010-03    │  │ WS-010-04    │     │
│  │ Wrappers     │  │ JDBC (+MySQL)│  │ JARs         │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐                                        │
│  │ WS-010-02    │                                        │
│  │ Python Deps  │                                        │
│  └──────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## Version Matrix

| Spark | Hadoop | Scala | Custom Build | Wrapper | Support |
|-------|--------|-------|--------------|---------|---------|
| 3.5.7 | 3.4.2 | 2.12 | Yes | Yes | Full |
| 4.1.0 | 3.4.2 | 2.13 | Yes | Yes | Full |
| 3.5.8 | 3.4.2 | 2.12 | No | No | Create if needed |
| 4.1.1 | 3.4.2 | 2.13 | No | No | Create if needed |

## Answer to Analysis Questions

### 1. How should WS-010-01 work now?
**Answer:** Option A - Document existing custom builds + create lightweight wrapper layers

- Custom builds already exist in `docker/spark-custom/`
- WS-010-01 creates wrapper Dockerfiles that reference these builds
- Provides consistent naming: `spark-3.5.7-custom`, `spark-4.1.0-custom`
- Verifies Hadoop 3.4.2 and AWS SDK v2 presence
- ~300 LOC (SMALL)

### 2. How do intermediate layers extend custom builds?
**Answer:** Update Dockerfiles to use `FROM custom_build_image`

- JDBC layer: `FROM localhost/spark-k8s:3.5.7-hadoop3.4.2`
- RAPIDS layer: `FROM localhost/spark-k8s:3.5.7-hadoop3.4.2`
- Iceberg layer: `FROM localhost/spark-k8s:3.5.7-hadoop3.4.2`
- Python layer: `FROM localhost/spark-k8s:3.5.7-hadoop3.4.2`

### 3. What about Spark 3.5.8 and 4.1.1?
**Answer:** Drop these versions (no custom builds exist)

- Custom builds only have 3.5.7 and 4.1.0
- If newer versions are needed, create new Dockerfiles in `docker/spark-custom/`
- Example: `docker/spark-custom/Dockerfile.3.5.8`
- Recommendation: Use 3.5.7 and 4.1.0 for now

## Next Steps

1. **Immediate:**
   - Review workstream specifications
   - Run cleanup script: `./scripts/cleanup-incorrect-f10.sh`

2. **Execution:**
   - `@build WS-010-01` (must be first)
   - `@build WS-010-02`, `@build WS-010-03`, `@build WS-010-04` (parallel)

3. **Verification:**
   - Build custom Spark images first
   - Build intermediate layers
   - Run unit tests
   - Run smoke tests

## Custom Spark Build Commands

```bash
# Build custom images first
cd docker/spark-custom

# Spark 3.5.7
docker build -f Dockerfile.3.5.7 -t localhost/spark-k8s:3.5.7-hadoop3.4.2 .

# Spark 4.1.0
docker build -f Dockerfile.4.1.0 -t localhost/spark-k8s:4.1.0-hadoop3.4.2 .

# Or use Makefile
make build-3.5.7
make build-4.1.0
```

## Testing

```bash
# Verify custom build
docker run --rm localhost/spark-k8s:3.5.7-hadoop3.4.2 \
  bash -c "ls /opt/spark/jars/hadoop-*.jar /opt/spark/jars/aws-sdk*.jar"

# Should show:
# - hadoop-common-3.4.2.jar
# - aws-sdk-java-v2-bundle.jar
```

## References

- Custom builds: `/home/fall_out_bug/work/s7/spark_k8s/docker/spark-custom/`
- Workstreams: `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/WS-010-*.md`
- Redesign summary: `/home/fall_out_bug/work/s7/spark_k8s/docs/workstreams/backlog/F10-REDESIGN-SUMMARY.md`
- Cleanup script: `/home/fall_out_bug/work/s7/spark_k8s/scripts/cleanup-incorrect-f10.sh`
