#!/usr/bin/env python3
"""
Spark Rightsizing Calculator CLI

Usage:
    python scripts/rightsizing_calculator.py --data-size 100TB --executor-memory 4G
"""

import argparse
import sys

from rightsizing_core import (
    EXECUTOR_PRESETS,
    SizingRecommendation,
    parse_data_size,
    calculate_recommendation,
)


def print_recommendation(recommendation: SizingRecommendation) -> None:
    """Print recommendation in a formatted way."""
    print("=" * 70)
    print("SPARK RIGHTSIZE CALCULATOR")
    print("=" * 70)
    print(f"\nExecutor Configuration: {recommendation.executor_config.name}")
    print(f"  Description: {recommendation.executor_config.description}")
    print("\nRecommended Settings:")
    print(f"  Executors: {recommendation.executor_count}")
    print(f"  Min Executors: {max(1, recommendation.executor_count // 4)}")
    print(f"  Max Executors: {recommendation.executor_count * 2}")
    print("\nExecutor Resources:")
    print(f"  Cores: {recommendation.executor_config.cores}")
    print(f"  Memory: {recommendation.executor_config.memory}")
    print(f"  Memory Overhead: {recommendation.executor_config.memory_overhead}")
    print(f"  Cores Limit: {recommendation.executor_config.cores_limit}")
    print(f"  Memory Limit: {recommendation.executor_config.memory_limit}")
    print("\nDriver Resources:")
    print(f"  Cores: {recommendation.driver_cores}")
    print(f"  Memory: {recommendation.driver_memory}")
    print("\nTotal Resources:")
    print(f"  Memory: {recommendation.total_memory_gb:.1f} GB")
    print(f"  Cores: {recommendation.total_cores}")
    print(f"\nEstimated Cost: {recommendation.cost_estimate}")
    print(f"\nJustification: {recommendation.justification}")
    print("\n" + "=" * 70)


def print_helm_values(recommendation: SizingRecommendation) -> None:
    """Print Helm values snippet."""
    print("\n# Helm Values")
    print("-" * 70)
    print(f"""
connect:
  executor:
    cores: "{recommendation.executor_config.cores}"
    coresLimit: "{recommendation.executor_config.cores_limit}"
    memory: "{recommendation.executor_config.memory}"
    memoryLimit: "{recommendation.executor_config.memory_limit}"
  dynamicAllocation:
    enabled: true
    minExecutors: {max(1, recommendation.executor_count // 4)}
    maxExecutors: {recommendation.executor_count * 2}
    initialExecutors: {recommendation.executor_count // 2}
  resources:
    requests:
      memory: "{recommendation.driver_memory}"
      cpu: "{recommendation.driver_cores}"
    limits:
      memory: "{int(recommendation.driver_memory.replace('G', '')) * 2}G"
      cpu: "{int(recommendation.driver_cores) * 2}"
  sparkConf:
    "spark.executor.memory": "{recommendation.executor_config.memory}"
    "spark.executor.cores": "{recommendation.executor_config.cores}"
    "spark.memory.fraction": "0.8"
    "spark.memory.storageFraction": "0.3"
""")
    print("-" * 70)


def main() -> int:
    """Main CLI entry point."""
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
