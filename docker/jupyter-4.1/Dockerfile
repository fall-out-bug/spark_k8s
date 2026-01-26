FROM apache/spark:4.1.0-python3

# Install JupyterLab
USER root
RUN pip install --no-cache-dir \
    jupyterlab==4.0.0 \
    pyspark==4.1.0 \
    "grpcio>=1.48.1" \
    "grpcio-status>=1.48.1" \
    "zstandard>=0.25.0" \
    pandas>=2.0.0 \
    pyarrow>=10.0.0 \
    matplotlib \
    seaborn

# Copy Spark Connect client config
COPY spark_config.py /opt/spark/conf/

# Copy example notebooks
COPY notebooks/ /home/spark/notebooks/

# Set working directory
WORKDIR /home/spark/notebooks

# Switch to non-root user
USER 185

# Expose JupyterLab port
EXPOSE 8888

# Start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''"]
