#!/usr/bin/env bash
set -euo pipefail

# End-to-end "prod-like" smoke for Spark Standalone (SA):
# - Spark cluster health + spark-submit (SparkPi)
# - Airflow DAG runs (example + ETL)

NAMESPACE="${1:-spark-sa-prodlike}"
RELEASE="${2:-spark-prodlike}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

cd "${PROJECT_DIR}"

echo "=== SA prod-like ALL tests (${RELEASE} in ${NAMESPACE}) ==="

echo ""
echo "1) Spark Standalone E2E..."
./scripts/test-spark-standalone.sh "${NAMESPACE}" "${RELEASE}"

echo ""
echo "2) Airflow prod-like DAG tests..."
# Allow overrides via env:
# - TIMEOUT_SECONDS (default inside script: 900)
# - POLL_SECONDS (default inside script: 10)
./scripts/test-prodlike-airflow.sh "${NAMESPACE}" "${RELEASE}" example_bash_operator spark_etl_synthetic

echo ""
echo "=== ALL OK ==="

