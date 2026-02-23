# WS-AUTO-05: Autotuning Grafana Dashboard

## Summary
Create Grafana dashboard for visualizing autotuning recommendations and insights.

## Scope
- Recommendations panel with current vs recommended values
- Metrics history with tuning annotations
- Confidence indicators
- Workload classification display

## Acceptance Criteria
- [ ] Dashboard shows current vs recommended config
- [ ] Displays confidence score for each recommendation
- [ ] Shows workload type classification
- [ ] Metrics history with tuning event annotations
- [ ] Links to apply recommendations
- [ ] Works with Grafana sidecar provisioning
- [ ] Dashboard as ConfigMap in Helm chart

## Technical Design

### Dashboard Panels

```json
{
  "panels": [
    {
      "id": 1,
      "title": "Autotuning Recommendations",
      "type": "table",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "targets": [
        {
          "datasource": {"type": "prometheus", "uid": "prometheus"},
          "expr": "spark_autotuning_recommendation_current",
          "format": "table",
          "instant": true
        }
      ],
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {"Time": true, "__name__": true},
            "indexByName": {"parameter": 0, "current": 1, "recommended": 2, "confidence": 3}
          }
        },
        {
          "id": "color",
          "options": {
            "mode": "thresholds",
            "thresholds": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 0.7},
              {"color": "green", "value": 0.85}
            ]
          }
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {"align": "left"}
        },
        "overrides": [
          {
            "matcher": {"id": "byName", "options": "confidence"},
            "properties": [
              {"id": "unit", "value": "percentunit"},
              {"id": "decimals", "value": 2}
            ]
          },
          {
            "matcher": {"id": "byName", "options": "change_pct"},
            "properties": [
              {"id": "unit", "value": "percent"},
              {"id": "decimals", "value": 1}
            ]
          }
        ]
      }
    },
    {
      "id": 2,
      "title": "Workload Classification",
      "type": "stat",
      "gridPos": {"h": 4, "w": 4, "x": 12, "y": 0},
      "targets": [
        {
          "expr": "spark_autotuning_workload_type",
          "legendFormat": "{{type}}"
        }
      ]
    },
    {
      "id": 3,
      "title": "Overall Confidence",
      "type": "gauge",
      "gridPos": {"h": 4, "w": 4, "x": 16, "y": 0},
      "targets": [
        {
          "expr": "spark_autotuning_overall_confidence",
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "max": 1,
          "min": 0,
          "unit": "percentunit",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 0.7},
              {"color": "green", "value": 0.85}
            ]
          }
        }
      }
    },
    {
      "id": 4,
      "title": "Metrics History with Tuning Events",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
      "targets": [
        {
          "expr": "rate(jvm_gc_time_seconds_sum[5m])",
          "legendFormat": "GC Time"
        },
        {
          "expr": "process_resident_memory_bytes",
          "legendFormat": "Memory"
        },
        {
          "expr": "spark_executor_cpu_utilization",
          "legendFormat": "CPU"
        }
      ],
      "annotations": [
        {
          "datasource": {"type": "prometheus", "uid": "prometheus"},
          "expr": "spark_autotuning_applied_total",
          "titleFormat": "Tuning Applied",
          "step": "1h"
        }
      ]
    },
    {
      "id": 5,
      "title": "Detected Issues",
      "type": "alertlist",
      "gridPos": {"h": 4, "w": 8, "x": 12, "y": 4},
      "options": {
        "viewMode": "list",
        "groupMode": "default",
        "sortBy": "time_desc"
      },
      "targets": [
        {
          "expr": "ALERTS{alertstate=\"firing\",category=\"autotuning\"}"
        }
      ]
    }
  ]
}
```

### Prometheus Metrics Required

```yaml
# Custom metrics from autotuner
metrics:
  spark_autotuning_recommendation_current:
    type: Gauge
    labels: [parameter, current, recommended, confidence, app_id]
    help: Current autotuning recommendation for a parameter

  spark_autotuning_workload_type:
    type: Gauge
    labels: [type, app_id]
    help: Detected workload type (1 = match)

  spark_autotuning_overall_confidence:
    type: Gauge
    labels: [app_id]
    help: Overall confidence score for recommendations

  spark_autotuning_applied_total:
    type: Counter
    labels: [app_id, parameter]
    help: Number of recommendations applied
```

### File Structure
```
charts/spark-3.5/templates/monitoring/
└── grafana-dashboard-autotuning.yaml
```

### ConfigMap Template

```yaml
{{- if .Values.monitoring.grafanaDashboards.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "spark-3.5.fullname" . }}-dashboard-autotuning
  namespace: {{ .Values.monitoring.grafanaDashboards.namespace | default .Release.Namespace }}
  labels:
    grafana_dashboard: "1"
    app: spark-connect
    app.kubernetes.io/name: spark-3.5
    app.kubernetes.io/instance: {{ .Release.Name }}
data:
  spark-autotuning.json: |
    {
      "annotations": {"list": []},
      "editable": true,
      "title": "Spark Autotuning",
      "uid": "spark-autotuning",
      "tags": ["spark", "autotuning", "optimization"],
      "panels": [...]
    }
{{- end }}
```

## Definition of Done
- Code reviewed and merged
- Dashboard loads in Grafana
- All panels display correctly
- Provisioning via ConfigMap works
- Documentation in chart README

## Estimated Effort
Small (dashboard JSON, straightforward)

## Blocked By
- WS-AUTO-04 (Helm Values Generator)

## Blocks
- WS-AUTO-06 (Integration Tests)
