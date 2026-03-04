#!/bin/bash
# Wrapper: delegates to scripts/operations/scaling/calculate-executor-sizing.sh
exec "$(dirname "$0")/../operations/scaling/calculate-executor-sizing.sh" "$@"
