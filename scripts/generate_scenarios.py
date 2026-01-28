#!/usr/bin/env python3
"""Generate complete matrix of scenario files."""

import yaml
from pathlib import Path


def deep_merge(base, overlay):
    """Deep merge two dictionaries."""
    result = base.copy()
    for key, value in overlay.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


GPU_FEATURES = {
    "connect": {
        "image": {"tag": "4.1.0-gpu"},
        "nodeSelector": {"nvidia.com/gpu.present": "true"},
        "tolerations": [{"key": "nvidia.com/gpu", "operator": "Exists", "effect": "NoSchedule"}],
        "executor": {
            "cores": "4", "coresLimit": "8",
            "memory": "8Gi", "memoryLimit": "16G",
            "gpu": {"enabled": True, "count": "1", "vendor": "nvidia.com/gpu"}
        },
        "sparkConf": {
            "spark.executor.resource.gpu.amount": "1",
            "spark.plugins": "com.nvidia.spark.SQLPlugin",
            "spark.rapids.sql.enabled": "true"
        }
    }
}

ICEBERG_FEATURES = {
    "connect": {
        "sparkConf": {
            "spark.sql.extensions": "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
            "spark.sql.catalog.iceberg": "org.apache.iceberg.spark.SparkCatalog"
        }
    }
}

# Generate all combinations
versions = ["4.1"]
components = ["jupyter", "airflow"]
features = ["", "gpu", "iceberg", "gpu-iceberg"]
modes = ["connect-k8s", "connect-standalone", "k8s-submit", "operator"]

for v in versions:
    for c in components:
        for f in features:
            for m in modes:
                parts = [c]
                if f:
                    parts.append(f)
                parts.append(m)
                name = "-".join(parts)
                print(f"charts/spark-{v}/values-scenario-{name}.yaml")
