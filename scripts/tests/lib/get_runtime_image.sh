#!/bin/bash
# get_runtime_image(spark_version, gpu, iceberg) → image tag for pyramid
# gpu=true → -gpu, iceberg=true → -iceberg, both → -gpu-iceberg
# Usage: get_runtime_image.sh 3.5.7 true false
# Returns: 3.5.7-gpu

set -euo pipefail

spark_version="${1:?spark_version required}"
gpu="${2:-false}"
iceberg="${3:-false}"

tag="$spark_version"
if [[ "$gpu" == "true" || "$gpu" == "1" || "$gpu" == "yes" ]]; then
    tag="${tag}-gpu"
fi
if [[ "$iceberg" == "true" || "$iceberg" == "1" || "$iceberg" == "yes" ]]; then
    tag="${tag}-iceberg"
fi
echo "$tag"
