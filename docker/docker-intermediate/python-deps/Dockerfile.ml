# ML-enabled Spark image extending spark-custom:3.5.7-new
# Adds scikit-learn for ML training

ARG BASE_IMAGE=spark-custom:3.5.7-new
FROM ${BASE_IMAGE}

USER root

# Install ML dependencies with specific versions to avoid hash issues
RUN pip3 install --no-cache-dir \
    scipy==1.11.4 \
    scikit-learn==1.3.2 \
    joblib==1.3.2 \
    boto3==1.34.0

# Verify installation
RUN python3 -c "import sklearn; print(f'sklearn {sklearn.__version__} OK')" && \
    python3 -c "import boto3; print(f'boto3 {boto3.__version__} OK')"

USER 185

WORKDIR /opt/spark/work-dir
