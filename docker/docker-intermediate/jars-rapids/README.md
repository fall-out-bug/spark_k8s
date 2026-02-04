# RAPIDS JARs Intermediate Layer

Docker intermediate layer that adds NVIDIA RAPIDS GPU acceleration JARs to Apache Spark images.

## Overview

This layer provides:
- RAPIDS 4 Spark plugin (version 24.10.0)
- CUDA cuDF library JAR
- Pre-configured for GPU-accelerated Spark operations

## Spark Version Compatibility

| Spark Version | Scala Version | RAPIDS Version | Status |
|---------------|---------------|----------------|--------|
| 3.5.7         | 2.12          | 24.10.0        | Tested |
| 3.5.8         | 2.12          | 24.10.0        | Compatible |
| 4.1.0         | 2.13          | 24.10.0        | Compatible (use scala 2.13 build) |
| 4.1.1         | 2.13          | 24.10.0        | Compatible (use scala 2.13 build) |

## Build

### Build for Spark 3.5.7 (default)

```bash
cd docker/docker-intermediate/jars-rapids
docker build -t spark-k8s-jars-rapids:latest .
```

### Build for different Spark versions

```bash
# Spark 3.5.8
docker build \
    --build-arg BASE_IMAGE=apache/spark:3.5.8-scala2.12-java17-ubuntu \
    --build-arg RAPIDS_VERSION=24.10.0 \
    -t spark-k8s-jars-rapids:3.5.8 \
    .

# Spark 4.1.0 (Scala 2.13)
docker build \
    --build-arg BASE_IMAGE=apache/spark:4.1.0-scala2.13-java17-ubuntu \
    --build-arg RAPIDS_VERSION=24.10.0 \
    --build-arg SCALA_VERSION=2.13 \
    -t spark-k8s-jars-rapids:4.1.0 \
    .
```

### Build and test

```bash
./test.sh
```

## Testing

Run tests manually:

```bash
# Using default image name
../../test-jars.sh rapids

# Using custom image name
../../test-jars.sh rapids my-rapids-jars:latest
```

### Test Coverage

The test script verifies:
1. Image builds successfully
2. SPARK_HOME is set correctly
3. JARs directory exists
4. RAPIDS plugin JAR is present
5. CUDA cuDF JAR is present
6. JAR files are valid archives
7. Environment variables are set
8. Image size is under limit (800MB)

## Usage

### As base image

```dockerfile
FROM spark-k8s-jars-rapids:latest

# Add your application-specific configurations
```

### In Kubernetes

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: spark-driver
    image: spark-k8s-jars-rapids:latest
    resources:
      limits:
        nvidia.com/gpu: 1
```

### Spark Configuration

When submitting Spark jobs with RAPIDS:

```bash
spark-submit \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.explain=ALL \
    --conf spark.rapids.memory.gpu.allocFraction=0.8 \
    --conf spark.rapids.memory.gpu.minAllocFraction=0 \
    ...
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SPARK_RAPIDS_VERSION` | RAPIDS plugin version (e.g., 24.10.0) |
| `SPARK_RAPIDS_JAR` | Full path to RAPIDS plugin JAR |
| `SPARK_HOME` | Spark installation directory |

## JARs Installed

| JAR | Location |
|-----|----------|
| rapids-4-spark_2.12-24.10.0.jar | `${SPARK_HOME}/jars/` |
| cudf-24.10.0.jar | `${SPARK_HOME}/jars/` |

## GPU Requirements

- NVIDIA GPU with Compute Capability 7.0+
- CUDA 12.0+ runtime
- nvidia-docker runtime for Kubernetes

## Image Size

Approximately 600-800MB (includes RAPIDS JARs with native libraries).

## Official Sources

- [RAPIDS Accelerator for Apache Spark](https://nvidia.github.io/spark-rapids/)
- [Maven Central - RAPIDS](https://repo1.maven.org/maven2/com/nvidia/rapids-4-spark_2.12/)
- [Maven Central - cuDF](https://repo1.maven.org/maven2/ai/rapids/cudf/)

## Maintenance

### Update RAPIDS version

1. Update `RAPIDS_VERSION` build arg in Dockerfile
2. Update test expectations if needed
3. Run full test suite
4. Update README compatibility table

### Troubleshooting

**GPU not detected**: Ensure nvidia-docker runtime is configured

**JAR not loading**: Check SPARK_RAPIDS_JAR environment variable

**ClassNotFound errors**: Verify Scala version matches your Spark distribution
