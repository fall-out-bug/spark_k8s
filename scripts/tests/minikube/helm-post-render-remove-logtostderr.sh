#!/usr/bin/env bash
# Helm post-renderer: remove deprecated flags from prometheus-operator deployment.
# Chart 9.3.2 passes flags removed in Operator v0.52+:
#   -logtostderr, -config-reloader-image, -config-reloader-cpu, -config-reloader-memory
# Usage: helm upgrade --install ... --post-renderer ./helm-post-render-remove-logtostderr.sh
set -euo pipefail
sed -e '/[[:space:]]*-[[:space:]]*--logtostderr=true/d' \
    -e '/[[:space:]]*-[[:space:]]*--config-reloader-image=/d' \
    -e '/[[:space:]]*-[[:space:]]*--config-reloader-cpu=/d' \
    -e '/[[:space:]]*-[[:space:]]*--config-reloader-memory=/d'
