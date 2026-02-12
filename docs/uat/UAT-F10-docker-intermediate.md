# UAT: F10 Phase 4 — Docker Intermediate Layers

**Feature:** F10 - Phase 4 Docker Intermediate Layers  
**Review Date:** 2026-02-10

---

## Overview

F10 provides intermediate Docker layers extending custom Spark builds: python-deps (base/GPU/Iceberg), jdbc-drivers (MySQL, MSSQL + existing), jars-rapids, jars-iceberg. All extend `localhost/spark-k8s:3.5.7-hadoop3.4.2` or `4.1.0-hadoop3.4.2` from docker/spark-custom.

---

## Prerequisites

- Docker (with BuildKit)
- Custom Spark images built first: `cd docker/spark-custom && make build-3.5.7`
- ~10GB disk for intermediate images

---

## Quick Verification (5 minutes)

### Smoke Test

```bash
# 1. Build custom Spark base (required)
cd docker/spark-custom
docker build -f Dockerfile.3.5.7 -t localhost/spark-k8s:3.5.7-hadoop3.4.2 .
# Or: make build-3.5.7

# 2. Build intermediate layers
cd docker/docker-intermediate/jars-rapids
bash build-3.5.7.sh

cd ../jars-iceberg
bash build-3.5.7.sh

cd ../jdbc-drivers
bash build.sh

cd ../python-deps
bash build.sh
# Expected: all build successfully (or fail if base image missing)
```

### Quick Check

```bash
# Syntax check
bash -n docker/docker-intermediate/python-deps/test.sh
bash -n docker/docker-intermediate/jdbc-drivers/test.sh
bash -n docker/docker-intermediate/jars-rapids/test.sh
bash -n docker/docker-intermediate/jars-iceberg/test.sh
bash -n docker/docker-intermediate/test-jars.sh
# Expected: no output
```

---

## Detailed Scenarios

### Scenario 1: JARs Layers (RAPIDS)

```bash
# Requires custom Spark base
docker/docker-intermediate/jars-rapids/build-3.5.7.sh
docker run --rm spark-k8s-jars-rapids:3.5.7 ls -la /opt/spark/jars/rapids*.jar
```

### Scenario 2: JARs Layers (Iceberg)

```bash
docker/docker-intermediate/jars-iceberg/build-3.5.7.sh
docker run --rm spark-k8s-jars-iceberg:3.5.7 ls -la /opt/spark/jars/iceberg*.jar
```

### Scenario 3: JDBC Drivers

```bash
# jdbc-drivers extends custom Spark (has PostgreSQL, Oracle, Vertica)
# Adds MySQL, MSSQL
docker/docker-intermediate/jdbc-drivers/build.sh
docker run --rm spark-k8s-jdbc-drivers:latest ls -la /opt/jdbc/
```

### Scenario 4: Python Dependencies

```bash
docker/docker-intermediate/python-deps/build.sh
docker run --rm spark-k8s-python-deps:latest pip list | grep -E "pyspark|pandas"
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | Base image not found | build stderr | HIGH |
| 2 | JARs missing in image | docker run ls | HIGH |
| 3 | test.sh fails | test output | MEDIUM |

---

## Code Sanity Checks

```bash
# All layers exist
ls docker/docker-intermediate/python-deps/Dockerfile
ls docker/docker-intermediate/jdbc-drivers/Dockerfile
ls docker/docker-intermediate/jars-rapids/Dockerfile
ls docker/docker-intermediate/jars-iceberg/Dockerfile
# Expected: 4 files

# Build scripts
ls docker/docker-intermediate/jars-rapids/build-3.5.7.sh
ls docker/docker-intermediate/jars-rapids/build-4.1.0.sh
# Expected: exists
```

---

## Sign-off Checklist

- [ ] Custom Spark base built
- [ ] jars-rapids, jars-iceberg build
- [ ] jdbc-drivers, python-deps build
- [ ] Red flags absent

---

## Related Documents

- Phase spec: `docs/phases/phase-04-docker-intermediate.md`
- Workstreams: `docs/workstreams/completed/WS-010-*.md`, `WS-00-010-03-jdbc-drivers-layer.md`
