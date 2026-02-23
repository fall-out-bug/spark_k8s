{{- define "spark-3.5.fullname" -}}
{{- .Release.Name }}-spark-35
{{- end }}

{{- define "spark-3.5.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "spark-3.5.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "spark-3.5.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccountName }}
{{- .Values.rbac.serviceAccountName }}
{{- else if .Values.rbac.create }}
{{- include "spark-3.5.fullname" . }}
{{- else }}
{{- include "spark-base.serviceAccountName" (dict "Values" (index .Values "spark-base") "Release" .Release "Chart" .Chart) }}
{{- end }}
{{- end }}
