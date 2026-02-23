"""Rightsizing calculator core logic."""

from dataclasses import dataclass
from typing import Dict, Optional


@dataclass
class ExecutorConfig:
    """Executor configuration."""

    name: str
    cores: int
    memory: str
    memory_mb: int
    memory_overhead: str
    cores_limit: str
    memory_limit: str
    description: str


@dataclass
class SizingRecommendation:
    """Rightsizing recommendation."""

    executor_count: int
    executor_config: ExecutorConfig
    driver_memory: str
    driver_cores: str
    total_memory_gb: float
    total_cores: int
    cost_estimate: str
    justification: str


EXECUTOR_PRESETS: Dict[str, ExecutorConfig] = {
    "small": ExecutorConfig(
        name="Small",
        cores=1,
        memory="1G",
        memory_mb=1024,
        memory_overhead="256m",
        cores_limit="1",
        memory_limit="2G",
        description="Low-memory workloads, testing, development",
    ),
    "medium": ExecutorConfig(
        name="Medium",
        cores=2,
        memory="4G",
        memory_mb=4096,
        memory_overhead="512m",
        cores_limit="2",
        memory_limit="8G",
        description="General-purpose workloads",
    ),
    "large": ExecutorConfig(
        name="Large",
        cores=4,
        memory="8G",
        memory_mb=8192,
        memory_overhead="1G",
        cores_limit="4",
        memory_limit="16G",
        description="Memory-intensive workloads",
    ),
    "xlarge": ExecutorConfig(
        name="XLarge",
        cores=8,
        memory="16G",
        memory_mb=16384,
        memory_overhead="2G",
        cores_limit="8",
        memory_limit="32G",
        description="Large-scale data processing",
    ),
}


def parse_data_size(size_str: str) -> int:
    """Parse data size string to MB."""
    size_str = size_str.upper().strip()
    if size_str.endswith("TB"):
        return int(size_str[:-2]) * 1024 * 1024
    if size_str.endswith("GB"):
        return int(size_str[:-2]) * 1024
    if size_str.endswith("MB"):
        return int(size_str[:-2])
    return int(size_str)


def calculate_cores_needed(data_size_mb: int, cores_per_executor: int) -> int:
    """Calculate executor cores needed based on data size."""
    parallelism = max(200, data_size_mb // 128)
    cores_needed = parallelism // cores_per_executor
    return max(1, cores_needed)


def calculate_memory_needed(data_size_mb: int, executor_memory_mb: int) -> int:
    """Calculate executor count based on memory requirements."""
    total_memory_needed = data_size_mb * 3
    executors = total_memory_needed // executor_memory_mb
    return max(1, executors)


def calculate_recommendation(
    data_size_mb: int,
    executor_preset: str = "medium",
    cluster_cores: Optional[int] = None,
    cluster_memory_gb: Optional[int] = None,
    spot_instances: bool = False,
) -> SizingRecommendation:
    """Calculate optimal sizing recommendation."""
    executor_config = EXECUTOR_PRESETS.get(executor_preset, EXECUTOR_PRESETS["medium"])
    cores_based = calculate_cores_needed(data_size_mb, executor_config.cores)
    memory_based = calculate_memory_needed(data_size_mb, executor_config.memory_mb)
    executor_count = max(cores_based, memory_based)
    if cluster_cores:
        max_executors = cluster_cores // executor_config.cores
        executor_count = min(executor_count, max_executors)
    if cluster_memory_gb:
        executor_memory_gb = executor_config.memory_mb / 1024
        max_executors = int(cluster_memory_gb / executor_memory_gb)
        executor_count = min(executor_count, max_executors)
    min_executors = max(1, executor_count // 4)
    driver_memory = f"{max(1, executor_config.memory_mb // 1024)}G"
    driver_cores = str(min(4, executor_config.cores * 2))
    total_memory_gb = (
        executor_count * executor_config.memory_mb / 1024
        + executor_config.memory_mb / 1024
    )
    total_cores = executor_count * executor_config.cores
    cost_per_hour = f"${total_memory_gb * 0.01:.2f} - ${total_memory_gb * 0.03:.2f}"
    if spot_instances:
        cost_per_hour += " (spot: 70% discount)"
    justification = (
        f"Data size: {data_size_mb / 1024 / 1024:.1f}TB requires "
        f"{cores_based} executors for parallelism and {memory_based} for memory. "
        f"Using {executor_config.name} executors ({executor_config.description}). "
    )
    if cluster_cores or cluster_memory_gb:
        justification += "Limited by cluster resources. "
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
        justification=justification,
    )
