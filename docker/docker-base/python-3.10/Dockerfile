# Python 3.10 Base Layer - Alpine Linux
# Minimal base image for Python 3.10 applications
FROM python:3.10-alpine

LABEL maintainer="spark-k8s-platform"
LABEL description="Python 3.10 base layer with build tools"

# Install minimal build dependencies and upgrade pip in one layer
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    curl \
    ca-certificates \
    bash \
    && pip install --no-cache-dir --upgrade pip setuptools wheel \
    && rm -rf /root/.cache /tmp/*

# Set working directory
WORKDIR /app

# Default command
CMD ["python3"]
