#!/bin/bash
# Forecast Spark infrastructure costs based on historical trends
#
# Usage:
#   ./forecast-cost.sh --period <monthly|quarterly> --months <n>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
PERIOD=${PERIOD:-"monthly"}
MONTHS=${MONTHS:-3}  # Forecast period
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --period)
            PERIOD="$2"
            shift 2
            ;;
        --months)
            MONTHS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "=== Cost Forecast ==="
log_info "Period: ${PERIOD}"
log_info "Forecast horizon: ${MONTHS} months"

# Get historical cost data
log_info "Gathering historical cost data..."

case "$PERIOD" in
    monthly)
        # Get last 12 months of data
        HISTORICAL_QUERY="increase(spark_job_cost_total[30d])"
        HISTORICAL_MONTHS=12
        ;;
    quarterly)
        # Get last 8 quarters of data
        HISTORICAL_QUERY="increase(spark_job_cost_total[90d])"
        HISTORICAL_MONTHS=24
        ;;
    *)
        log_error "Invalid period: ${PERIOD}"
        exit 1
        ;;
esac

# Fetch historical costs
declare -a COSTS
for ((i=1; i<=HISTORICAL_MONTHS; i++)); do
    OFFSET=$((i * 30))
    QUERY="increase(spark_job_cost_total[${OFFSET}d])"

    COST=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${QUERY}" | jq -r '.data.result[0].value[1]' || echo "0")

    if [[ "$COST" != "null" && -n "$COST" ]]; then
        COSTS+=("$COST")
    fi
done

# Calculate statistics
COUNT=${#COSTS[@]}

if [[ $COUNT -lt 2 ]]; then
    log_error "Insufficient historical data for forecasting"
    exit 1
fi

# Simple linear regression using bash
SUM_Y=0
SUM_X=0
SUM_YY=0
SUM_XX=0
SUM_XY=0

for i in "${!COSTS[@]}"; do
    X=$((i + 1))
    Y=${COSTS[$i]}

    SUM_X=$((SUM_X + X))
    SUM_Y=$(echo "$SUM_Y + $Y" | bc)
    SUM_XX=$(echo "$SUM_XX + $X * $X" | bc)
    SUM_XY=$(echo "$SUM_XY + $X * $Y" | bc)
done

# Calculate slope and intercept
N=$COUNT
SLOPE=$(echo "scale=4; ($N * $SUM_XY - $SUM_X * $SUM_Y) / ($N * $SUM_XX - $SUM_X * $SUM_X)" | bc)
INTERCEPT=$(echo "scale=2; ($SUM_Y - $SLOPE * $SUM_X) / $N" | bc)

# Forecast
log_info "=== Forecast ==="

LAST_COST=${COSTS[$COUNT-1]}
GROWTH_RATE=$(echo "scale=4; $SLOPE * 100 / $LAST_COST" | bc)

log_info "Current monthly cost: \$${LAST_COST}"
log_info "Growth rate: ${GROWTH_RATE}% per month"

echo ""
echo "Forecast for next ${MONTHS} months:"

FORECAST_TOTAL=0
for ((i=1; i<=$MONTHS; i++); do
    X=$((COUNT + i))
    FORECAST=$(echo "scale=2; $SLOPE * $X + $INTERCEPT" | bc)
    FORECAST_TOTAL=$(echo "$FORECAST_TOTAL + $FORECAST" | bc)

    MONTH_OFFSET=$((i))
    FORECAST_DATE=$(date -d "$MONTH_OFFSET months" +%Y-%m)

    echo "  ${FORECAST_DATE}: \$${FORECAST}"
done

echo ""
echo "Total forecasted cost: \$${FORECAST_TOTAL}"
echo "Average monthly cost: \$$(echo "scale=2; $FORECAST_TOTAL / $MONTHS" | bc)"

# Export as JSON
cat <<EOF
{
  "period": "${PERIOD}",
  "forecast_months": ${MONTHS},
  "historical_months": ${HISTORICAL_MONTHS},
  "current_cost": ${LAST_COST},
  "growth_rate_percent": ${GROWTH_RATE},
  "slope": ${SLOPE},
  "intercept": ${INTERCEPT},
  "forecast": [
EOF

for ((i=1; i<=$MONTHS; i++)); do
    X=$((COUNT + i))
    FORECAST=$(echo "scale=2; $SLOPE * $X + $INTERCEPT" | bc)
    MONTH_OFFSET=$((i))
    FORECAST_DATE=$(date -d "$MONTH_OFFSET months" +%Y-%m)

    echo "    {\"date\": \"${FORECAST_DATE}\", \"cost\": ${FORECAST}},"
done | sed '$ s/,$//' >> /tmp/forecast.json

cat <<EOF
  ]
}
EOF

cat /tmp/forecast.json
rm -f /tmp/forecast.json

exit 0
