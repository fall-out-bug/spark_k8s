"""
JupyterHub configuration for Kubernetes deployment.
Supports both KubeSpawner (production) and LocalProcessSpawner (local dev).
"""
from __future__ import annotations

import os
from typing import Any

# Determine spawner based on environment
if os.getenv("JUPYTERHUB_SPAWNER", "kubernetes") == "local":
    from jupyterhub.spawner import LocalProcessSpawner as Spawner
else:
    from kubespawner import KubeSpawner as Spawner

# JupyterHub configuration
c = get_config()  # noqa: F821

# Spawner configuration
c.JupyterHub.spawner_class = Spawner

# Server configuration
c.JupyterHub.ip = "0.0.0.0"
c.JupyterHub.port = 8000
c.JupyterHub.hub_ip = "0.0.0.0"

# Authentication (simple for local dev, should be configured for production)
c.Authenticator.admin_users = {"admin"}
c.JupyterHub.authenticator_class = "dummyauthenticator.DummyAuthenticator"

if Spawner.__name__ == "KubeSpawner":
    # Kubernetes-specific configuration
    c.KubeSpawner.namespace = os.getenv("JUPYTERHUB_NAMESPACE", "dataops")
    c.KubeSpawner.image = os.getenv(
        "JUPYTERHUB_IMAGE",
        "jupyterhub-spark:latest"
    )
    
    # Resource limits
    c.KubeSpawner.cpu_guarantee = 1.0
    c.KubeSpawner.cpu_limit = 2.0
    c.KubeSpawner.mem_guarantee = "2G"
    c.KubeSpawner.mem_limit = "4G"
    
    # Security context
    c.KubeSpawner.uid = 1000
    c.KubeSpawner.gid = 1000
    c.KubeSpawner.fs_gid = 1000
    
    # Command to start JupyterLab (default interface)
    c.KubeSpawner.cmd = ["jupyter", "labhub"]
    
    # Environment variables for Spark, S3, MLflow
    c.KubeSpawner.environment = {
        "SPARK_MASTER_URL": os.getenv("SPARK_MASTER_URL", "spark://spark-master:7077"),
        "SPARK_HOME": "/opt/spark",
        "S3_ENDPOINT_URL": os.getenv("S3_ENDPOINT_URL", "http://minio:9000"),
        "S3_ACCESS_KEY_ID": os.getenv("S3_ACCESS_KEY_ID", "minioadmin"),
        "S3_SECRET_ACCESS_KEY": os.getenv("S3_SECRET_ACCESS_KEY", "minioadmin"),
        "AWS_S3_SIGNATURE_VERSION": os.getenv("AWS_S3_SIGNATURE_VERSION", "s3v4"),
        "MLFLOW_TRACKING_URI": os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000"),
        "PYSPARK_PYTHON": "python3",
        "PYSPARK_DRIVER_PYTHON": "python3",
        # JupyterLab settings
        "JUPYTER_ENABLE_LAB": "yes",
        "JUPYTERLAB_SETTINGS_DIR": "/home/jovyan/.jupyter/lab/user-settings",
    }
    
    # Volume mounts (optional PVC for persistent home)
    # c.KubeSpawner.volumes = [
    #     {
    #         "name": "user-home",
    #         "persistentVolumeClaim": {
    #             "claimName": "jupyterhub-user-{username}"
    #         }
    #     }
    # ]
    # c.KubeSpawner.volume_mounts = [
    #     {
    #         "name": "user-home",
    #         "mountPath": "/home/jovyan/work"
    #     }
    # ]
    
    # Health checks (IPython startup script will handle Spark initialization)
    
    # Service account
    c.KubeSpawner.service_account = os.getenv("JUPYTERHUB_SERVICE_ACCOUNT", "jupyterhub")
    
else:
    # LocalProcessSpawner configuration (for docker-compose)
    c.LocalProcessSpawner.cmd = ["jupyter", "labhub"]
    c.LocalProcessSpawner.environment = {
        "SPARK_MASTER_URL": os.getenv("SPARK_MASTER_URL", "spark://spark-master:7077"),
        "SPARK_HOME": "/opt/spark",
        "S3_ENDPOINT_URL": os.getenv("S3_ENDPOINT_URL", "http://minio:9000"),
        "S3_ACCESS_KEY_ID": os.getenv("S3_ACCESS_KEY_ID", "minioadmin"),
        "S3_SECRET_ACCESS_KEY": os.getenv("S3_SECRET_ACCESS_KEY", "minioadmin"),
        "AWS_S3_SIGNATURE_VERSION": os.getenv("AWS_S3_SIGNATURE_VERSION", "s3v4"),
        "MLFLOW_TRACKING_URI": os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000"),
        "PYSPARK_PYTHON": "python3",
        "PYSPARK_DRIVER_PYTHON": "python3",
        "JUPYTER_ENABLE_LAB": "yes",
    }

# Logging
c.JupyterHub.log_level = "INFO"

