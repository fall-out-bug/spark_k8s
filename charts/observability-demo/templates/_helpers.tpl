{{/*
observability-demo chart labels
*/}}
{{- define "observability-demo.name" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "observability-demo.labels" -}}
helm.sh/chart: {{ include "observability-demo.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
