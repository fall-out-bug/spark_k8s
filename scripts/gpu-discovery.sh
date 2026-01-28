#!/bin/bash
#
# GPU Discovery Script for Spark on Kubernetes
#
# This script discovers GPU resources on Kubernetes nodes and reports them to Spark.
# It is used by Spark's resource discovery mechanism to allocate GPU resources to executors.
#
# Usage: This script is automatically called by Spark when gpu resources are requested.
#        Configure via: spark.executor.resource.gpu.discoveryScript
#
# Output format: {name="gpu", addresses=["0","1",...]}
#

set -e

# Path to GPU device directory
GPU_DEVICE_PATH="/dev"
GPU_ADDRESSES=()

# Check for NVIDIA GPUs
if command -v nvidia-smi &> /dev/null; then
    # Use nvidia-smi to get GPU count
    GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null || echo "0")

    if [[ "$GPU_COUNT" -gt 0 ]]; then
        # Generate GPU addresses [0, 1, 2, ...]
        for ((i=0; i<GPU_COUNT; i++)); do
            GPU_ADDRESSES+=("$i")
        done

        # Output in Spark resource format
        echo "{\"name\":\"gpu\",\"addresses\":[\"$(IFS=,; echo "${GPU_ADDRESSES[*]}")\"]}"
        exit 0
    fi
fi

# Fallback: Check for NVIDIA device files
NVIDIA_DEVICES=(/dev/nvidia*)
if [[ ${#NVIDIA_DEVICES[@]} -gt 0 && -e "${NVIDIA_DEVICES[0]}" ]]; then
    # Extract GPU numbers from device files
    for device in "${NVIDIA_DEVICES[@]}"; do
        if [[ "$device" =~ nvidia([0-9]+) ]]; then
            GPU_ADDRESSES+=("${BASH_REMATCH[1]}")
        fi
    done

    if [[ ${#GPU_ADDRESSES[@]} -gt 0 ]]; then
        echo "{\"name\":\"gpu\",\"addresses\":[\"$(IFS=,; echo "${GPU_ADDRESSES[*]}")\"]}"
        exit 0
    fi
fi

# Check for AMD GPUs (ROCm)
if command -v rocm-smi &> /dev/null; then
    GPU_COUNT=$(rocm-smi --showid --csv 2>/dev/null | wc -l || echo "0")

    if [[ "$GPU_COUNT" -gt 0 ]]; then
        for ((i=0; i<GPU_COUNT; i++)); do
            GPU_ADDRESSES+=("$i")
        done

        echo "{\"name\":\"gpu\",\"addresses\":[\"$(IFS=,; echo "${GPU_ADDRESSES[*]}")\"]}"
        exit 0
    fi
fi

# Check for Intel GPUs
if [[ -d "/dev/dri/by-path" ]]; then
    INTEL_DEVICES=(/dev/dri/renderD*)
    if [[ ${#INTEL_DEVICES[@]} -gt 0 ]]; then
        for i in "${!INTEL_DEVICES[@]}"; do
            GPU_ADDRESSES+=("$i")
        done

        echo "{\"name\":\"gpu\",\"addresses\":[\"$(IFS=,; echo "${GPU_ADDRESSES[*]}")\"]}"
        exit 0
    fi
fi

# No GPUs found - output empty resource
echo "{\"name\":\"gpu\",\"addresses\":[]}"

# Log GPU information for debugging
if [[ "${SPARK_GPU_DEBUG:-false}" == "true" ]]; then
    echo "GPU Discovery Debug:" >&2
    echo "  nvidia-smi available: $(command -v nvidia-smi &> /dev/null && echo 'yes' || echo 'no')" >&2
    echo "  rocm-smi available: $(command -v rocm-smi &> /dev/null && echo 'yes' || echo 'no')" >&2
    echo "  NVIDIA devices: ${NVIDIA_DEVICES[*]:-none}" >&2
    echo "  Intel devices: ${INTEL_DEVICES[*]:-none}" >&2
    echo "  GPU addresses: ${GPU_ADDRESSES[*]:-none}" >&2
fi
