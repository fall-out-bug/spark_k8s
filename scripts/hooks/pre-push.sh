#!/bin/sh
set -e

echo "Pre-push: helm lint + template tests..."

helm lint charts/spark-3.5 >/dev/null 2>&1
helm lint charts/spark-4.1 >/dev/null 2>&1

if command -v pytest >/dev/null 2>&1; then
    pytest tests/integration/ tests/security/ -q --tb=line --no-header -x
fi

echo "Pre-push passed"
