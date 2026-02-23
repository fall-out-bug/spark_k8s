{{/*
Expand the name of the chart.
*/}}
{{- define "spark-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "spark-base.fullname" -}}
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
{{- define "spark-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark-base.labels" -}}
helm.sh/chart: {{ include "spark-base.chart" . }}
{{ include "spark-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spark-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "spark-base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default "spark" .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Pod security context (PSS restricted compatible)

Note: runAsUser/runAsGroup are set per-container to allow init containers
to run as root (needed for Alpine apk). fsGroup is set here as it only
affects volume ownership, not process execution.
*/}}
{{- define "spark-base.podSecurityContext" -}}
runAsNonRoot: false
{{- with .Values.security.fsGroup }}
fsGroup: {{ . }}
{{- end }}
{{- if .Values.security.podSecurityStandards }}
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}

{{/*
Container security context (PSS restricted compatible)
*/}}
{{- define "spark-base.containerSecurityContext" -}}
{{- if .Values.security.podSecurityStandards }}
allowPrivilegeEscalation: false
{{- with .Values.security.runAsUser }}
runAsUser: {{ . }}
{{- end }}
{{- with .Values.security.runAsGroup }}
runAsGroup: {{ . }}
{{- end }}
{{- if hasKey .Values.security "readOnlyRootFilesystem" }}
readOnlyRootFilesystem: {{ .Values.security.readOnlyRootFilesystem }}
{{- end }}
capabilities:
  drop:
    - ALL
{{- end }}
{{- end }}

{{/*
Init container security context (relaxed for Alpine apk compatibility)

Init containers using Alpine require root for apk operations.
This is acceptable as init containers are ephemeral and run before main containers.
*/}}
{{- define "spark-base.initContainerSecurityContext" -}}
{{- if .Values.security.podSecurityStandards }}
allowPrivilegeEscalation: false
{{- if hasKey .Values.security "readOnlyRootFilesystem" }}
readOnlyRootFilesystem: {{ .Values.security.readOnlyRootFilesystem }}
{{- end }}
capabilities:
  drop:
    - ALL
{{- end }}
{{- end }}
