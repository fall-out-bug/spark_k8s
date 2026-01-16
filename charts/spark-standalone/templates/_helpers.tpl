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
Service account name
*/}}
{{- define "spark-standalone.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default "spark-standalone" .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image name helper
*/}}
{{- define "spark-standalone.image" -}}
{{- $registry := .global.imageRegistry | default "" -}}
{{- $repository := .image.repository -}}
{{- $tag := .image.tag | default "latest" -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Pod security context (PSS restricted compatible)
*/}}
{{- define "spark-standalone.podSecurityContext" -}}
runAsNonRoot: true
{{- with .Values.security.runAsUser }}
runAsUser: {{ . }}
{{- end }}
{{- with .Values.security.runAsGroup }}
runAsGroup: {{ . }}
{{- end }}
{{- with .Values.security.fsGroup }}
fsGroup: {{ . }}
{{- end }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Container security context (PSS restricted compatible)
*/}}
{{- define "spark-standalone.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}
