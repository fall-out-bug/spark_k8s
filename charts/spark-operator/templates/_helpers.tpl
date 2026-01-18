{{- define "spark-operator.fullname" -}}
{{- printf "%s-spark-operator" .Release.Name -}}
{{- end }}

{{- define "spark-operator.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "spark-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "spark-operator.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- include "spark-operator.fullname" . }}
{{- else }}
default
{{- end }}
{{- end }}
