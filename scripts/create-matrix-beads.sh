#!/bin/bash
# Create beads for each test matrix scenario with Red-Green-Refactor plan
# Usage: ./scripts/create-matrix-beads.sh [--dry-run] [--filter "gpu=false"]
# Requires: bd (beads), python3, pyyaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_MATRIX="$PROJECT_ROOT/tests/test-matrix.yaml"
DRY_RUN=false
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --filter) FILTER="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_ROOT"

scenarios_json=$(python3 << PYEOF
import yaml
import json

with open("$TEST_MATRIX", "r") as f:
    matrix = yaml.safe_load(f)

scenarios = matrix['scenarios']
filter_str = "$FILTER"

if filter_str:
    filters = filter_str.split(',')
    for f in filters:
        key, value = f.split('=', 1)
        if value.lower() == 'true':
            scenarios = [s for s in scenarios if s.get(key) == True]
        elif value.lower() == 'false':
            scenarios = [s for s in scenarios if s.get(key) == False]
        else:
            scenarios = [s for s in scenarios if str(s.get(key, '')).lower() == value.lower()]

print(json.dumps(scenarios))
PYEOF
)

count=$(echo "$scenarios_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
echo "Creating beads for $count scenarios (dry_run=$DRY_RUN)"

for scenario in $(echo "$scenarios_json" | python3 -c "
import json,sys
for s in json.load(sys.stdin):
    print(s['id'] + '|' + s['name'])
"); do
    id="${scenario%%|*}"
    name="${scenario#*|}"
    title="[${id}] RGR: ${name}"
    body="## Red-Green-Refactor Plan

**Requirement:** Deploy + Smoke + E2E + Load + Metrics (event logs → History Server)

**Red:** Test fails when requirement not met (e.g. wrong image, missing S3 config)

**Green:** Minimal fix (config, image, chart) to pass

**Refactor:** Simplify without changing behavior

**Scenario:** ${id} — ${name}
"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would create: $title"
    else
        bd create "$title" --description "$body" --labels "test-matrix,tdd,scenario" 2>/dev/null || echo "bd create failed for $id"
    fi
done

echo "Done."
