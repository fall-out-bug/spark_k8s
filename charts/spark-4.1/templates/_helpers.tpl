{{- define "spark-4.1.fullname" -}}
{{- .Release.Name }}-spark-41
{{- end }}

{{- define "spark-4.1.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "spark-4.1.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "spark-4.1.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- default (include "spark-4.1.fullname" .) .Values.rbac.serviceAccountName }}
{{- else }}
{{- include "spark-base.serviceAccountName" (dict "Values" (index .Values "spark-base") "Release" .Release "Chart" .Chart) }}
{{- end }}
{{- end }}
