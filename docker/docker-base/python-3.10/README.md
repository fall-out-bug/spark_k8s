# Python 3.10 Base Layer

Minimal Alpine-based Docker image for Python 3.10 applications with essential build tools.

## Contents

- Python 3.10.x (Alpine-based)
- pip, setuptools, wheel
- Build tools: gcc, musl-dev, libffi-dev, openssl-dev
- Utilities: curl, ca-certificates, bash

## Build

```bash
docker build -t spark-k8s-python-3.10-base:latest .
```

## Test

```bash
./test.sh
```

## Image Size

Approximately 412MB (within 450MB limit).

## Usage

This is a base layer. Use it as a FROM in derived images:

```dockerfile
FROM spark-k8s-python-3.10-base:latest
# Install your application dependencies
```

## Notes

- Runs as root by design (security handled in derived images)
- Includes build tools for compiling Python extensions
- Uses Alpine Linux for minimal footprint
