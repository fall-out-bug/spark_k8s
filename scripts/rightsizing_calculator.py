#!/usr/bin/env python3
"""
Spark Rightsizing Calculator

This script helps calculate optimal executor sizing for Spark workloads based on:
- Cluster resources
- Data size
- Worker type configurations

Usage:
    python scripts/rightsizing_calculator.py --data-size 100TB --executor-memory 4G
"""

import argparse
import sys
from dataclasses import dataclass
from typing import Dict, List


@dataclass
class ExecutorConfig:
    """Executor configuration"""
    name: str
    cores: int
    memory: str
    memory_mb: int
    memory_overhead: str
    cores_limit: int
    memory_limit: str
    description: str


@dataclass
class SizingRecommendation:
    """Rightsizing recommendation"""
    executor_count: int
    executor_config: ExecutorConfig
    driver_memory: str
    driver_cores: str
    total_memory_gb: float
    total_cores: int
    cost_estimate: str
    justification: str


# Common executor configurations
EXECUTOR_PRESETS: Dict[str, ExecutorConfig] = {
    "small": ExecutorConfig(
        name="Small",
        cores=1,
        memory="1G",
        memory_mb=1024,
        memory_overhead="256m",
        cores_limit="1",
        memory_limit="2G",
        description="Low-memory workloads, testing, development"
    ),
    "medium": ExecutorConfig(
        name="Medium",
        cores=2,
        memory="4G",
        memory_mb=4096,
        memory_overhead="512m",
        cores_limit="2",
        memory_limit="8G",
        description="General-purpose workloads"
    ),
    "large": ExecutorConfig(
        name="Large",
        cores=4,
        memory="8G",
        memory_mb=8192,
        memory_overhead="1G",
        cores_limit="4",
        memory_limit="16G",
        description="Memory-intensive workloads"
    ),
    "xlarge": ExecutorConfig(
        name="XLarge",
        cores=8,
        memory="16G",
        memory_mb=16384,
        memory_overhead="2G",
        cores_limit="8",
        memory_limit="32G",
        description="Large-scale data processing"
    ),
}


def parse_data_size(size_str: str) -> int:
    """Parse data size string to MB"""
    size_str = size_str.upper().strip()
    if size_str.endswith("TB"):
        return int(size_str[:-2]) * 1024 * 1024
    elif size_str.endswith("GB"):
        return int(size_str[:-2]) * 1024
    elif size_str.endswith("MB"):
        return int(size_str[:-2])
    else:
        return int(size_str)


def calculate_cores_needed(data_size_mb: int, cores_per_executor: int) -> int:
    """
    Calculate executor cores needed based on data size.

    Rule of thumb: 1 core per 100-200MB of data (parallelism)
    """
    parallelism = max(200, data_size_mb // 128)  # 128MB per partition default
    cores_needed = parallelism // cores_per_executor
    return max(1, cores_needed)


def calculate_memory_needed(data_size_mb: int, executor_memory_mb: int) -> int:
    """
    Calculate executor count based on memory requirements.

    Rule of thumb: 3x data size in memory for shuffles
    """
    total_memory_needed = data_size_mb * 3
    executors = total_memory_needed // executor_memory_mb
    return max(1, executors)


def calculate_recommendation(
    data_size_mb: int,
    executor_preset: str = "medium",
    cluster_cores: int = None,
    cluster_memory_gb: int = None,
    spot_instances: bool = False
) -> SizingRecommendation:
    """Calculate optimal sizing recommendation"""

    executor_config = EXECUTOR_PRESETS.get(executor_preset, EXECUTOR_PRESETS["medium"])

    # Calculate based on both cores and memory
    cores_based = calculate_cores_needed(data_size_mb, executor_config.cores)
    memory_based = calculate_memory_needed(data_size_mb, executor_config.memory_mb)

    # Use the higher value
    executor_count = max(cores_based, memory_based)

    # Apply cluster limits if provided
    if cluster_cores:
        max_executors = cluster_cores // executor_config.cores
        executor_count = min(executor_count, max_executors)

    if cluster_memory_gb:
        executor_memory_gb = executor_config.memory_mb / 1024
        max_executors = int(cluster_memory_gb / executor_memory_gb)
        executor_count = min(executor_count, max_executors)

    # Add buffer for dynamic allocation
    min_executors = max(1, executor_count // 4)
    max_executors = executor_count * 2

    # Driver sizing (typically 1-2 executors worth)
    driver_memory = f"{max(1, executor_config.memory_mb // 1024)}G"
    driver_cores = str(min(4, executor_config.cores * 2))

    # Calculate totals
    total_memory_gb = (executor_count * executor_config.memory_mb / 1024) + (executor_config.memory_mb / 1024)
    total_cores = executor_count * executor_config.cores

    # Cost estimation (rough)
    cost_per_hour = f"${total_memory_gb * 0.01:.2f} - ${total_memory_gb * 0.03:.2f}"
    if spot_instances:
        cost_per_hour += " (spot: 70% discount)"

    justification = (
        f"Data size: {data_size_mb / 1024 / 1024:.1f}TB requires "
        f"{cores_based} executors for parallelism and {memory_based} for memory. "
        f"Using {executor_config.name} executors ({executor_config.description}). "
    )
    if cluster_cores or cluster_memory_gb:
        justification += f"Limited by cluster resources. "
    if spot_instances:
        justification += "Spot instances configured for cost savings."

    return SizingRecommendation(
        executor_count=executor_count,
        executor_config=executor_config,
        driver_memory=driver_memory,
        driver_cores=driver_cores,
        total_memory_gb=total_memory_gb,
        total_cores=total_cores,
        cost_estimate=cost_per_hour,
        justification=justification
    )


def print_recommendation(recommendation: SizingRecommendation):
    """Print recommendation in a formatted way"""
    print("=" * 70)
    print("SPARK RIGHTSIZE CALCULATOR")
    print("=" * 70)
    print(f"\nExecutor Configuration: {recommendation.executor_config.name}")
    print(f"  Description: {recommendation.executor_config.description}")
    print(f"\nRecommended Settings:")
    print(f"  Executors: {recommendation.executor_count}")
    print(f"  Min Executors: {max(1, recommendation.executor_count // 4)}")
    print(f"  Max Executors: {recommendation.executor_count * 2}")
    print(f"\nExecutor Resources:")
    print(f"  Cores: {recommendation.executor_config.cores}")
    print(f"  Memory: {recommendation.executor_config.memory}")
    print(f"  Memory Overhead: {recommendation.executor_config.memory_overhead}")
    print(f"  Cores Limit: {recommendation.executor_config.cores_limit}")
    print(f"  Memory Limit: {recommendation.executor_config.memory_limit}")
    print(f"\nDriver Resources:")
    print(f"  Cores: {recommendation.driver_cores}")
    print(f"  Memory: {recommendation.driver_memory}")
    print(f"\nTotal Resources:")
    print(f"  Memory: {recommendation.total_memory_gb:.1f} GB")
    print(f"  Cores: {recommendation.total_cores}")
    print(f"\nEstimated Cost: {recommendation.cost_estimate}")
    print(f"\nJustification: {recommendation.justification}")
    print("\n" + "=" * 70)


def print_helm_values(recommendation: SizingRecommendation):
    """Print Helm values snippet"""
    print("\n# Helm Values")
    print("-" * 70)
    print("""
connect:
  executor:
    cores: "{cores}"
    coresLimit: "{cores_limit}"
    memory: "{memory}"
    memoryLimit: "{memory_limit}"
  dynamicAllocation:
    enabled: true
    minExecutors: {min_executors}
    maxExecutors: {max_executors}
    initialExecutors: {initial_executors}
  resources:
    requests:
      memory: "{driver_memory}"
      cpu: "{driver_cores}"
    limits:
      memory: "{driver_memory_limit}"
      cpu: "{driver_cores_limit}"
  sparkConf:
    "spark.executor.memory": "{memory}"
    "spark.executor.cores": "{cores}"
    "spark.memory.fraction": "0.8"
    "spark.memory.storageFraction": "0.3"
""".format(
        cores=recommendation.executor_config.cores,
        cores_limit=recommendation.executor_config.cores_limit,
        memory=recommendation.executor_config.memory,
        memory_limit=recommendation.executor_config.memory_limit,
        min_executors=max(1, recommendation.executor_count // 4),
        max_executors=recommendation.executor_count * 2,
        initial_executors=recommendation.executor_count // 2,
        driver_memory=recommendation.driver_memory,
        driver_cores=recommendation.driver_cores,
        driver_memory_limit=f"{int(recommendation.driver_memory.replace('G', '')) * 2}G",
        driver_cores_limit=str(int(recommendation.driver_cores) * 2)
    ))
    print("-" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Calculate optimal Spark executor sizing"
    )
    parser.add_argument(
        "--data-size",
        type=str,
        required=True,
        help="Data size to process (e.g., 100TB, 500GB, 1000MB)"
    )
    parser.add_argument(
        "--executor-preset",
        type=str,
        choices=list(EXECUTOR_PRESETS.keys()),
        default="medium",
        help="Executor configuration preset"
    )
    parser.add_argument(
        "--cluster-cores",
        type=int,
        help="Maximum CPU cores available in cluster"
    )
    parser.add_argument(
        "--cluster-memory",
        type=int,
        help="Maximum memory available in cluster (GB)"
    )
    parser.add_argument(
        "--spot",
        action="store_true",
        help="Calculate for spot instances"
    )
    parser.add_argument(
        "--helm-values",
        action="store_true",
        help="Output Helm values snippet"
    )

    args = parser.parse_args()

    data_size_mb = parse_data_size(args.data_size)
    recommendation = calculate_recommendation(
        data_size_mb=data_size_mb,
        executor_preset=args.executor_preset,
        cluster_cores=args.cluster_cores,
        cluster_memory_gb=args.cluster_memory,
        spot_instances=args.spot
    )

    print_recommendation(recommendation)
    if args.helm_values:
        print_helm_values(recommendation)

    return 0


if __name__ == "__main__":
    sys.exit(main())
