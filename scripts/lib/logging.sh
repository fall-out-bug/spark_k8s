#!/bin/bash
# Common logging functions for# Usage: source scripts/lib/logging.sh

log_info() {
    echo -e "${GREEN:-}[INFO]${NC:-} $*"
}

log_warn() {
    echo -e "${YELLOW:-}[WARN]${NC:-} $*"
}

log_error() {
    echo -e "${RED:-}[ERROR]${NC:-} $*"
}
