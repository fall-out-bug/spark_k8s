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
{{- $useBase := false -}}
{{- if .Values.global }}
{{- $useBase = (default false .Values.global.useSparkBaseHelpers) -}}
{{- end }}
{{- if $useBase -}}
{{- include "spark-base.labels" . }}
{{- else }}
helm.sh/chart: {{ include "spark-standalone.chart" . }}
{{ include "spark-standalone.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-standalone.selectorLabels" -}}
{{- $useBase := false -}}
{{- if .Values.global }}
{{- $useBase = (default false .Values.global.useSparkBaseHelpers) -}}
{{- end }}
{{- if $useBase -}}
{{- include "spark-base.selectorLabels" . }}
{{- else }}
app.kubernetes.io/name: {{ include "spark-standalone.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "spark-standalone.serviceAccountName" -}}
{{- $useBase := false -}}
{{- if .Values.global }}
{{- $useBase = (default false .Values.global.useSparkBaseHelpers) -}}
{{- end }}
{{- if $useBase -}}
{{- include "spark-base.serviceAccountName" . }}
{{- else }}
{{- if .Values.serviceAccount.create }}
{{- default "spark" .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
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
{{- $useBase := false -}}
{{- if .Values.global }}
{{- $useBase = (default false .Values.global.useSparkBaseHelpers) -}}
{{- end }}
{{- if $useBase -}}
{{- include "spark-base.podSecurityContext" . }}
{{- else }}
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
{{- end }}

{{/*
Container security context (PSS restricted compatible)
*/}}
{{- define "spark-standalone.containerSecurityContext" -}}
{{- $useBase := false -}}
{{- if .Values.global }}
{{- $useBase = (default false .Values.global.useSparkBaseHelpers) -}}
{{- end }}
{{- if $useBase -}}
{{- include "spark-base.containerSecurityContext" . }}
{{- else }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}
{{- end }}
