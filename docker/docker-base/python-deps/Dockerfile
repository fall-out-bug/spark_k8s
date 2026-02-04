# Python Dependencies Intermediate Layer
# Installs common Python packages for PySpark applications
FROM spark-k8s-python-3.10-base:latest

LABEL maintainer="spark-k8s-platform"
LABEL description="Python dependencies intermediate layer with PySpark packages"
LABEL version="1.0"

# Build metadata
LABEL build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
LABEL vcs_ref="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

# Store build info for debugging
RUN echo "image_name=spark-k8s-python-deps" > /etc/image-build-info && \
    echo "build_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> /etc/image-build-info && \
    echo "base_image=spark-k8s-python-3.10-base" >> /etc/image-build-info && \
    echo "vcs_ref=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" >> /etc/image-build-info

# Install system dependencies for building Python packages
# grpcio requires compiler and some runtime libraries
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    libcurl \
    ca-certificates

# Copy requirements file
COPY requirements.txt /tmp/requirements.txt

# Install Python packages
# Use --no-cache-dir to keep image small
# Compile with optimization for better performance
# Note: grpcio on Alpine requires specific environment variables
RUN GRPC_PYTHON_BUILD_SYSTEM_ZLIB=true \
    GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=true \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt && \
    rm -rf /root/.cache /tmp/*

# Verify installation
RUN pip list && \
    python -c "import pandas, numpy, pyarrow, pyspark, grpcio, grpcio_status" && \
    echo "All packages installed successfully"

# Set working directory
WORKDIR /app

# Default command
CMD ["python3"]
