# Python Dependencies Intermediate Layer

Docker intermediate layer for PySpark applications with GPU and Iceberg variant support.

## Variants

| Variant | Build Arg | Content |
|---------|-----------|---------|
| base | (default) | pyspark, pandas, numpy, pyarrow |
| gpu | BUILD_GPU_DEPS=true | + cudf, cuml, cupy (RAPIDS) |
| iceberg | BUILD_ICEBERG_DEPS=true | + pyiceberg, fsspec |

## Compatible Base Images

- `localhost/spark-k8s:3.5.7-hadoop3.4.2`
- `localhost/spark-k8s:4.1.0-hadoop3.4.2`
- `apache/spark:3.5.7-scala2.12-java17-python3-ubuntu`
- `localhost/spark-k8s-jdk-17:latest`

## Build

```bash
# Base variant
./build.sh

# GPU variant
BUILD_GPU_DEPS=true ./build.sh

# Iceberg variant
BUILD_ICEBERG_DEPS=true ./build.sh

# Custom base image
BASE_IMAGE=apache/spark:3.5.7-scala2.12-java17-python3-ubuntu ./build.sh
```

## Test

```bash
./test.sh

# GPU variant
IMAGE_NAME=spark-k8s-python-deps:latest-gpu BUILD_GPU_DEPS=true ./test.sh

# Iceberg variant
IMAGE_NAME=spark-k8s-python-deps:latest-iceberg BUILD_ICEBERG_DEPS=true ./test.sh
```

## Test Coverage

1. Image builds successfully
2. PySpark is installed and importable
3. Core packages (pandas, numpy, pyarrow) installed
4. GPU/Iceberg packages installed (for respective variants)
5. Spark integration works
6. Non-root user execution
7. Working directory correct
8. Image size under 2GB limit

## Package Versions

| Package | Version | Variant |
|---------|---------|---------|
| pyspark | >=3.5.0 | base |
| pandas | >=2.0.0 | base |
| numpy | >=1.24.0 | base |
| pyarrow | >=14.0.0 | base |
| cudf-cu12 | >=24.10.0 | gpu |
| cuml-cu12 | >=24.10.0 | gpu |
| cupy-cuda12x | >=13.0.0 | gpu |
| pyiceberg | >=0.6.0 | iceberg |
| fsspec | >=2024.0.0 | iceberg |

## Image Size

- Base: ~1.1-1.2 GB
- GPU: ~4-5 GB (RAPIDS libraries)
- Iceberg: ~1.1-1.2 GB

## Notes

- Custom Spark builds already include base Python deps
- GPU variant requires CUDA runtime
- PyIceberg provides Python API (separate from Spark JARs)

## Official Sources

- [Apache PySpark](https://pypi.org/project/pyspark/)
- [NVIDIA RAPIDS](https://rapids.ai/)
- [Apache Iceberg Python](https://iceberg.apache.org/python/)
