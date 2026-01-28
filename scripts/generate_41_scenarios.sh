#!/bin/bash
# Generate complete scenario matrix for Spark 4.1

set -e

CHART_DIR="charts/spark-4.1"
BASE_JUPYTER="$CHART_DIR/values-scenario-jupyter-connect-k8s.yaml"
BASE_AIRFLOW="$CHART_DIR/values-scenario-airflow-connect-k8s.yaml"

# Read base files
JUPYTER_BASE=$(cat "$BASE_JUPYTER")
AIRFLOW_BASE=$(cat "$BASE_AIRFLOW")

# Generate Jupyter scenarios
for mode in connect-k8s connect-standalone k8s-submit operator; do
  for feature in "" gpu iceberg gpu-iceberg; do
    if [ -z "$feature" ]; then
      name="jupyter-$mode"
    else
      name="jupyter-$feature-$mode"
    fi

    file="$CHART_DIR/values-scenario-$name.yaml"

    # Skip if exists
    if [ -f "$file" ]; then
      echo "SKIP: $file (exists)"
      continue
    fi

    echo "CREATE: $file"
    cp "$BASE_JUPYTER" "$file"
  done
done

# Generate Airflow scenarios
for mode in connect-k8s connect-standalone k8s-submit operator; do
  for feature in "" gpu iceberg gpu-iceberg; do
    if [ -z "$feature" ]; then
      name="airflow-$mode"
    else
      name="airflow-$feature-$mode"
    fi

    file="$CHART_DIR/values-scenario-$name.yaml"

    # Skip if exists
    if [ -f "$file" ]; then
      echo "SKIP: $file (exists)"
      continue
    fi

    echo "CREATE: $file"
    cp "$BASE_AIRFLOW" "$file"
  done
done

echo "Generated $(find $CHART_DIR -name 'values-scenario-*.yaml' | wc -l) scenario files"
