{{/*
Expand the name of the chart.
*/}}
{{- define "spark-standalone.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "spark-standalone.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spark-standalone.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark-standalone.labels" -}}
helm.sh/chart: {{ include "spark-standalone.chart" . }}
{{ include "spark-standalone.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-standalone.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-standalone.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Spark Master labels
*/}}
{{- define "spark-standalone.masterLabels" -}}
{{ include "spark-standalone.labels" . }}
app.kubernetes.io/component: spark-master
{{- end }}

{{/*
Spark Master selector labels
*/}}
{{- define "spark-standalone.masterSelectorLabels" -}}
{{ include "spark-standalone.selectorLabels" . }}
app.kubernetes.io/component: spark-master
{{- end }}

{{/*
Spark Worker labels
*/}}
{{- define "spark-standalone.workerLabels" -}}
{{ include "spark-standalone.labels" . }}
app.kubernetes.io/component: spark-worker
{{- end }}

{{/*
Spark Worker selector labels
*/}}
{{- define "spark-standalone.workerSelectorLabels" -}}
{{ include "spark-standalone.selectorLabels" . }}
app.kubernetes.io/component: spark-worker
{{- end }}

{{/*
Airflow Webserver labels
*/}}
{{- define "spark-standalone.airflowWebserverLabels" -}}
{{ include "spark-standalone.labels" . }}
app.kubernetes.io/component: airflow-webserver
{{- end }}

{{/*
Airflow Scheduler labels
*/}}
{{- define "spark-standalone.airflowSchedulerLabels" -}}
{{ include "spark-standalone.labels" . }}
app.kubernetes.io/component: airflow-scheduler
{{- end }}

{{/*
Airflow PostgreSQL labels
*/}}
{{- define "spark-standalone.airflowPostgresqlLabels" -}}
{{ include "spark-standalone.labels" . }}
app.kubernetes.io/component: airflow-postgresql
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spark-standalone.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spark-standalone.fullname" . ) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
