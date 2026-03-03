#!/bin/bash
set -e

helm upgrade --install grafana grafana/grafana \
  -n observability \
  --set adminPassword=admin \
  --set service.type=NodePort \
  --set service.nodePort=30030 \
  --set persistence.enabled=false \
  --set sidecar.dashboards.enabled=true \
  --set sidecar.dashboards.label=grafana_dashboard \
  --set sidecar.dashboards.labelValue=1 \
  --set sidecar.dashboards.searchNamespace=ALL \
  --set-json 'datasources.datasources.yaml={"apiVersion":1,"datasources":[{"name":"Prometheus","type":"prometheus","uid":"PBFA97CFB590B2093","access":"proxy","url":"http://prometheus.observability.svc.cluster.local:9090","isDefault":true}]}' \
  --wait --timeout 180s
