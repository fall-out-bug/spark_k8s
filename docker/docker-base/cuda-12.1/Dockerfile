# CUDA 12.1 Runtime + JDK 17
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

LABEL maintainer="spark-k8s-platform"
LABEL description="CUDA 12.1 runtime with JDK 17 for Spark GPU"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install JDK 17 and utilities
RUN apt-get update && apt-get install -y \
    openjdk-17-jre-headless \
    curl \
    ca-certificates \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify CUDA installation (may fail in non-GPU environments)
RUN nvidia-smi || echo "GPU not available in build environment"

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
