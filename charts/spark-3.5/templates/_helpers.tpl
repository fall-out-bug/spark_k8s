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

{{/*
Airflow Webserver labels
*/}}
{{- define "spark-3.5.airflowWebserverLabels" -}}
{{ include "spark-3.5.labels" . }}
app.kubernetes.io/component: airflow-webserver
{{- end }}

{{/*
Airflow Scheduler labels
*/}}
{{- define "spark-3.5.airflowSchedulerLabels" -}}
{{ include "spark-3.5.labels" . }}
app.kubernetes.io/component: airflow-scheduler
{{- end }}

{{/*
Airflow PostgreSQL labels
*/}}
{{- define "spark-3.5.airflowPostgresqlLabels" -}}
{{ include "spark-3.5.labels" . }}
app.kubernetes.io/component: airflow-postgresql
{{- end }}

{{/*
Airflow DB host (internal or external)
*/}}
{{- define "spark-3.5.airflowDbHost" -}}
{{- if .Values.airflow.postgresql.enabled -}}
{{ .Release.Name }}-airflow-postgresql
{{- else -}}
{{ .Values.airflow.postgresql.externalHost | required "airflow.postgresql.externalHost required when postgresql.enabled=false" }}
{{- end -}}
{{- end }}

{{/*
Airflow DB port
*/}}
{{- define "spark-3.5.airflowDbPort" -}}
{{- if .Values.airflow.postgresql.enabled -}}
{{ .Values.airflow.postgresql.service.port }}
{{- else -}}
{{ .Values.airflow.postgresql.externalPort | default 5432 }}
{{- end -}}
{{- end }}

{{/*
Airflow SQLAlchemy connection string
*/}}
{{- define "spark-3.5.airflowDbConn" -}}
postgresql://{{ .Values.airflow.postgresql.auth.username }}:{{ .Values.airflow.postgresql.auth.password }}@{{ include "spark-3.5.airflowDbHost" . }}:{{ include "spark-3.5.airflowDbPort" . }}/{{ .Values.airflow.postgresql.auth.database }}
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
