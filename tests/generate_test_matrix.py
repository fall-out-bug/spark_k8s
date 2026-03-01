#!/usr/bin/env python3
"""
Generate complete test matrix for Lego-Spark
320 scenarios = 4 versions × (32 native + 8 standalone) × 2 platforms
"""

import yaml
import json
from itertools import product

# Dimensions
SPARK_VERSIONS = ["3.5.7", "3.5.8", "4.0.2", "4.1.1"]
CONNECT_MODES = [True, False]
K8S_MODES = ["native", "standalone"]
GPU_MODES = [True, False]
ICEBERG_MODES = [True, False]
SHUFFLE_MODES = [True, False]
OPENLINEAGE_MODES = [True, False]
PLATFORMS = ["k8s", "openshift"]

# Constraints
# GPU and Shuffle only apply to native K8s mode
# Standalone: GPU=N/A, Shuffle=N/A

def generate_scenarios():
    """Generate all 320 test scenarios"""
    scenarios = []
    scenario_id = 1
    
    for version in SPARK_VERSIONS:
        for connect in CONNECT_MODES:
            for k8s_mode in K8S_MODES:
                for platform in PLATFORMS:
                    if k8s_mode == "native":
                        # Native mode: all GPU/Iceberg/Shuffle/OpenLineage combinations
                        for gpu in GPU_MODES:
                            for iceberg in ICEBERG_MODES:
                                for shuffle in SHUFFLE_MODES:
                                    for openlineage in OPENLINEAGE_MODES:
                                        scenario = {
                                            "id": f"SCENARIO-{scenario_id:04d}",
                                            "spark_version": version,
                                            "connect": connect,
                                            "k8s_mode": k8s_mode,
                                            "gpu": gpu,
                                            "iceberg": iceberg,
                                            "shuffle_service": shuffle,
                                            "openlineage": openlineage,
                                            "platform": platform
                                        }
                                        scenario["name"] = generate_name(scenario)
                                        scenario["helm_values"] = generate_helm_values(scenario)
                                        scenarios.append(scenario)
                                        scenario_id += 1
                    else:
                        # Standalone mode: GPU=N/A, Shuffle=N/A
                        for iceberg in ICEBERG_MODES:
                            for openlineage in OPENLINEAGE_MODES:
                                scenario = {
                                    "id": f"SCENARIO-{scenario_id:04d}",
                                    "spark_version": version,
                                    "connect": connect,
                                    "k8s_mode": k8s_mode,
                                    "gpu": False,  # N/A
                                    "iceberg": iceberg,
                                    "shuffle_service": False,  # N/A
                                    "openlineage": openlineage,
                                    "platform": platform
                                }
                                scenario["name"] = generate_name(scenario)
                                scenario["helm_values"] = generate_helm_values(scenario)
                                scenarios.append(scenario)
                                scenario_id += 1
    
    return scenarios

def generate_name(s):
    """Generate human-readable scenario name"""
    parts = [
        s["spark_version"],
        "C" if s["connect"] else "NC",
        "N" if s["k8s_mode"] == "native" else "S",
        "GPU" if s["gpu"] else "CPU",
        "ICE" if s["iceberg"] else "NO-ICE",
        "SHUF" if s["shuffle_service"] else "NO-SHUF",
        "OL" if s["openlineage"] else "NO-OL",
        s["platform"].upper()
    ]
    return "-".join(parts)

def generate_helm_values(s):
    """Generate Helm values for this scenario"""
    values = []
    
    # Spark version
    values.append(f'spark.version="{s["spark_version"]}"')
    
    # Connect mode
    if s["connect"]:
        values.append("connect.enabled=true")
        if s["k8s_mode"] == "native":
            values.append("connect.backendMode=k8s")
        else:
            values.append("sparkStandalone.enabled=true")
    else:
        values.append("connect.enabled=false")
        values.append("sparkStandalone.enabled=true")
    
    # GPU
    if s["gpu"]:
        values.append("features.gpu.enabled=true")
    
    # Iceberg
    if s["iceberg"]:
        values.append("features.iceberg.enabled=true")
    
    # Shuffle service (only for native)
    if s["shuffle_service"] and s["k8s_mode"] == "native":
        values.append("spark.shuffle.service.enabled=true")
    
    # OpenLineage
    if s["openlineage"]:
        values.append("openlineage.enabled=true")
    
    # Platform-specific
    if s["platform"] == "openshift":
        values.append("openshift.enabled=true")
    
    # Always-on components
    values.append("monitoring.prometheus.enabled=true")
    values.append("monitoring.grafana.enabled=true")
    values.append("historyServer.enabled=true")
    values.append("core.hiveMetastore.enabled=true")
    values.append("core.minio.enabled=true")
    
    return " \\\n  --set ".join(values)

def main():
    scenarios = generate_scenarios()
    
    # Build test matrix structure
    test_matrix = {
        "metadata": {
            "name": "Lego-Spark Complete Test Matrix",
            "generated": "2026-03-01",
            "total_scenarios": len(scenarios),
            "total_test_runs": len(scenarios) * 3,  # smoke, e2e, load
            "dimensions": {
                "spark_versions": SPARK_VERSIONS,
                "connection_modes": ["connect", "standalone"],
                "k8s_modes": ["native", "standalone"],
                "gpu_modes": ["with-gpu", "without-gpu"],
                "iceberg_modes": ["with-iceberg", "without-iceberg"],
                "shuffle_service_modes": ["enabled", "disabled"],
                "openlineage_modes": ["enabled", "disabled"],
                "platforms": ["k8s", "openshift"]
            },
            "always_on": [
                "metrics (Prometheus + Grafana)",
                "history-server",
                "hive-metastore",
                "minio-s3"
            ]
        },
        "scenarios": scenarios,
        "test_types": {
            "smoke": {
                "duration": "10 min",
                "description": "Quick validation",
                "tests": ["helm-install", "pod-startup", "service-endpoints", "simple-job", "connect-server", "minio-s3", "metrics", "history-server"]
            },
            "e2e": {
                "duration": "25 min",
                "description": "End-to-end scenarios",
                "tests": ["spark-sql", "dataframe-ops", "ml-pipeline", "streaming", "s3-read-write", "iceberg-crud", "gpu-detection", "shuffle-service", "openlineage-tracking", "hive-metastore"]
            },
            "load": {
                "duration": "45 min",
                "description": "Performance tests",
                "tests": ["throughput-100k", "throughput-500k", "throughput-1m", "shuffle-50k", "sort-100k", "cache-test", "write-parquet"]
            }
        }
    }
    
    # Output YAML
    with open("tests/test-matrix-full.yaml", "w") as f:
        yaml.dump(test_matrix, f, default_flow_style=False, sort_keys=False)
    
    # Output summary
    print(f"Generated {len(scenarios)} scenarios")
    print(f"Total test runs: {len(scenarios) * 3}")
    
    # Count by version
    by_version = {}
    for s in scenarios:
        v = s["spark_version"]
        by_version[v] = by_version.get(v, 0) + 1
    
    print("\nBy Spark version:")
    for v, count in sorted(by_version.items()):
        print(f"  {v}: {count} scenarios")
    
    # Count by platform
    by_platform = {}
    for s in scenarios:
        p = s["platform"]
        by_platform[p] = by_platform.get(p, 0) + 1
    
    print("\nBy platform:")
    for p, count in sorted(by_platform.items()):
        print(f"  {p}: {count} scenarios")
    
    # First 5 scenarios
    print("\nFirst 5 scenarios:")
    for s in scenarios[:5]:
        print(f"  {s['id']}: {s['name']}")

if __name__ == "__main__":
    main()
