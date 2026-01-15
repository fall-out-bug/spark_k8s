# JupyterHub with Spark 3.5.7, Hadoop 3.4, and all required connectors
FROM jupyter/datascience-notebook:latest

USER root

# Install system dependencies for JDBC drivers and native libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
    libaio1 \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Switch to jovyan user
USER ${NB_UID}

# Set working directory
WORKDIR /home/${NB_USER}

# Install Python packages
COPY --chown=${NB_UID}:${NB_GID} requirements-jupyter.txt /tmp/requirements-jupyter.txt
RUN pip install --no-cache-dir -r /tmp/requirements-jupyter.txt && \
    rm /tmp/requirements-jupyter.txt

# Install JupyterHub and spawners
RUN pip install --no-cache-dir \
    jupyterhub==4.0.0 \
    jupyterlab==4.0.0 \
    kubespawner==24.1.0 \
    dummyauthenticator==2.1.0

# Install JupyterLab extensions for better UX
# Note: Some extensions are installed via pip (see requirements-jupyter.txt)
# Server extensions are installed automatically with pip packages
RUN jupyter lab build --minimize=False || true && \
    jupyter lab clean || true

# Download and install Spark 3.5.7 with Hadoop 3.4
ENV SPARK_VERSION=3.5.7
ENV HADOOP_VERSION=3.4
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

RUN mkdir -p ${SPARK_HOME} && \
    cd /tmp && \
    wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}/* ${SPARK_HOME}/ && \
    rm -rf /tmp/spark-*

# Download JDBC drivers
RUN mkdir -p ${SPARK_HOME}/jars && \
    cd ${SPARK_HOME}/jars && \
    # PostgreSQL JDBC
    wget -q https://jdbc.postgresql.org/download/postgresql-42.7.1.jar && \
    # Oracle JDBC (ojdbc8)
    wget -q https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/23.3.0.23.09/ojdbc8-23.3.0.23.09.jar -O ojdbc8.jar && \
    # Vertica JDBC
    wget -q https://repo1.maven.org/maven2/com/vertica/jdbc/vertica-jdbc/24.1.0-0/vertica-jdbc-24.1.0-0.jar && \
    # Kafka (Spark SQL Kafka connector)
    wget -q https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/${SPARK_VERSION}/spark-sql-kafka-0-10_2.12-${SPARK_VERSION}.jar && \
    # AWS SDK and S3 connector
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

# Copy JupyterHub configuration files
COPY --chown=${NB_UID}:${NB_GID} jupyterhub_config.py /etc/jupyterhub/jupyterhub_config.py

# Copy IPython startup script for automatic Spark initialization
RUN mkdir -p /home/${NB_USER}/.ipython/profile_default/startup
COPY --chown=${NB_UID}:${NB_GID} startup/00-spark-init.py /home/${NB_USER}/.ipython/profile_default/startup/00-spark-init.py

# Configure JupyterLab as default and enable extensions
RUN mkdir -p /home/${NB_USER}/.jupyter && \
    echo "c.ServerApp.default_url = '/lab'" > /home/${NB_USER}/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.iopub_data_rate_limit = 100000000" >> /home/${NB_USER}/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.allow_origin = '*'" >> /home/${NB_USER}/.jupyter/jupyter_lab_config.py && \
    echo "c.LabApp.dev_mode = False" >> /home/${NB_USER}/.jupyter/jupyter_lab_config.py

# Enable JupyterLab extensions and settings
RUN mkdir -p /home/${NB_USER}/.jupyter/lab/user-settings && \
    echo '{"@jupyterlab/notebook-extension:tracker":{"kernelShutdown":{"confirm":false}}}' > /home/${NB_USER}/.jupyter/lab/user-settings/\@jupyterlab/notebook-extension/tracker.jupyterlab-settings && \
    echo '{"@jupyterlab/application-extension:shell":{"firstSessionId":"","lastSessionId":"","workspaces":{"ids":[],"labels":[]}}}' > /home/${NB_USER}/.jupyter/lab/user-settings/\@jupyterlab/application-extension/shell.jupyterlab-settings

# Set environment variables for Spark
ENV SPARK_MASTER_URL=spark://spark-master:7077
ENV SPARK_CONF_DIR=${SPARK_HOME}/conf

# Expose JupyterHub port
EXPOSE 8000

# Default command
CMD ["jupyterhub", "-f", "/etc/jupyterhub/jupyterhub_config.py"]

