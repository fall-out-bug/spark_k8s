#!/usr/bin/env bash
# Build Spark distribution from source and save to dist/
# Run once, then use dist/*.tgz in Docker builds (no runtime Maven)
#
# Usage:
#   ./scripts/build-spark-dist.sh [3.5.7|3.5.8|4.1.0|4.1.1]
#   ./scripts/build-spark-dist.sh all
#
# Output: dist/spark-{version}-bin-custom-hadoop-{hadoop}.tgz
#
# NOTE: the canonical docker/spark-custom/Dockerfile.<ver> images currently
# self-build Spark inside Docker and do NOT consume these tarballs; dist/ is
# an optional local cache used by some CI workflows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${DIST_DIR}/build"
HADOOP_VERSION="${HADOOP_VERSION:-3.4.2}"
MAVEN_OPTS="${MAVEN_OPTS:--Xmx4g -Dmaven.wagon.http.retryHandler.count=5}"

build_spark() {
  local version="$1"
  local scala_ver="2.12"
  [[ "$version" == 4.* ]] && scala_ver="2.13"

  echo "=== Building Spark ${version} (Hadoop ${HADOOP_VERSION}, Scala ${scala_ver}) ==="
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  if [ ! -d "spark-${version}" ]; then
    git clone --branch "v${version}" --depth 1 https://github.com/apache/spark.git "spark-${version}"
  fi

  cd "spark-${version}"
  export MAVEN_OPTS
  ./dev/make-distribution.sh \
    --name "custom-hadoop-${HADOOP_VERSION}" \
    --tgz \
    -Dhadoop.version="${HADOOP_VERSION}" \
    -Phadoop-3 \
    -Pkubernetes \
    -Phadoop-cloud \
    -Phive-thriftserver \
    -Pconnect \
    -DskipTests

  local tgz="spark-${version}-bin-custom-hadoop-${HADOOP_VERSION}.tgz"
  mkdir -p "$DIST_DIR"
  mv "$tgz" "$DIST_DIR/"
  echo "Saved: $DIST_DIR/$tgz"
}

main() {
  local versions=("${1:-3.5.7}")
  [[ "${1:-}" = "all" ]] && versions=(3.5.7 3.5.8 4.1.0 4.1.1)

  for v in "${versions[@]}"; do
    build_spark "$v"
  done

  echo "=== Done. Distributions in $DIST_DIR ==="
  ls -lh "$DIST_DIR"/*.tgz 2>/dev/null || true
}

main "$@"
