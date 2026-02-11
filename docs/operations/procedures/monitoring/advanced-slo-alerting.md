# Advanced SLO Alerting Procedure

## Overview

This procedure defines advanced SLO-based alerting with multi-window burn rate alerts, anomaly detection, forecasting, and compliance reporting.

## Multi-Window Burn Rate Alerts

### Alert Configuration

Prometheus alert rules for multi-window burn rate detection:

```yaml
groups:
- name: slo_advanced_burn_rate
  rules:
  # 1-hour window (fast burn)
  - alert: SLOFastBurn1h
    expr: |
      (
        sum(rate(spark_connect_errors_total[1h]))
        /
        sum(rate(spark_connect_requests_total[1h]))
      ) > (1 - 0.999) / (30 * 24)  # 30x error budget in 1 hour
    for: 5m
    labels:
      severity: critical
      window: "1h"
    annotations:
      summary: "SLO error budget burning at >30x normal rate (1h window)"

  # 6-hour window (medium burn)
  - alert: SLOMediumBurn6h
    expr: |
      (
        sum(rate(spark_connect_errors_total[6h]))
        /
        sum(rate(spark_connect_requests_total[6h]))
      ) > (1 - 0.999) / (7 * 24)  # 7x error budget in 6 hours
    for: 15m
    labels:
      severity: warning
      window: "6h"
    annotations:
      summary: "SLO error budget burning at >7x normal rate (6h window)"

  # 24-hour window (slow burn)
  - alert: SLOSlowBurn24h
    expr: |
      (
        sum(rate(spark_connect_errors_total[24h]))
        /
        sum(rate(spark_connect_requests_total[24h]))
      ) > (1 - 0.999) / (2 * 24)  # 2x error budget in 24 hours
    for: 1h
    labels:
      severity: info
      window: "24h"
    annotations:
      summary: "SLO error budget burning at >2x normal rate (24h window)"
```

## SLO Forecasting

### Forecasting Script

```bash
# Generate SLO forecast
scripts/operations/monitoring/generate-slo-forecast.sh \
  --metric spark_connect_error_rate \
  --period 30d \
  --forecast-days 7 \
  --output slo-forecast.json
```

## Related Procedures

- [SLI/SLO Definitions](./sli-slo-definitions.md)

## References

- [Google SRE Workbook: Multi-Window Multi-Burn-Rate Alerting](https://sre.google/workbook/alerting-on-slos/)
