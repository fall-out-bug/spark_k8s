{{- /*==============================================*/ -}}
{{- /* Core Component Helper Templates            */ -}}
{{- /* Provides unified helpers for core          */ -}}
{{- /* infrastructure components                  */ -}}
{{- /*==============================================*/ -}}

{{- /* spark.core.enabled - Check if any core component is enabled */ -}}
{{- define "spark.core.enabled" -}}
{{- if .Values.core.minio.enabled | or .Values.core.postgresql.enabled | or .Values.core.hiveMetastore.enabled | or .Values.core.historyServer.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- /* spark.core.component.enabled - Check if specific component is enabled */ -}}
{{- define "spark.core.component.enabled" -}}
{{- $component := .component | default "minio" -}}
{{- if eq $component "minio" -}}
{{- .Values.core.minio.enabled | default false -}}
{{- else if eq $component "postgresql" -}}
{{- .Values.core.postgresql.enabled | default false -}}
{{- else if eq $component "hiveMetastore" -}}
{{- .Values.core.hiveMetastore.enabled | default false -}}
{{- else if eq $component "historyServer" -}}
{{- .Values.core.historyServer.enabled | default false -}}
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- /* spark.core.labels - Standard labels for core components */ -}}
{{- define "spark.core.labels" -}}
{{- if .Context -}}
{{- $root := .Context -}}
helm.sh/chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion }}
app.kubernetes.io/component: "{{ .Component | default "core" }}"
{{- else if .Chart -}}
{{- $root := . -}}
helm.sh/chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion }}
app.kubernetes.io/component: "{{ .Component | default "core" }}"
{{- end -}}
{{- end -}}

{{- /* spark.core.selectorLabels - Selector labels for core components */ -}}
{{- define "spark.core.selectorLabels" -}}
{{- if .Context -}}
{{- $root := .Context -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}-{{ .Component | default "core" }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- else if .Chart -}}
{{- $root := . -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}-{{ .Component | default "core" }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.fullname - Fullname for MinIO */ -}}
{{- define "spark.core.minio.fullname" -}}
{{- if .Values.core.minio.fullnameOverride -}}
{{- .Values.core.minio.fullnameOverride -}}
{{- else -}}
{{- printf "%s-minio" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- /* spark.core.postgresql.fullname - Fullname for PostgreSQL */ -}}
{{- define "spark.core.postgresql.fullname" -}}
{{- if .Values.core.postgresql.fullnameOverride -}}
{{- .Values.core.postgresql.fullnameOverride -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- /* spark.core.hiveMetastore.fullname - Fullname for Hive Metastore */ -}}
{{- define "spark.core.hiveMetastore.fullname" -}}
{{- if .Values.core.hiveMetastore.fullnameOverride -}}
{{- .Values.core.hiveMetastore.fullnameOverride -}}
{{- else -}}
{{- printf "%s-hive-metastore" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- /* spark.core.historyServer.fullname - Fullname for History Server */ -}}
{{- define "spark.core.historyServer.fullname" -}}
{{- if .Values.core.historyServer.fullnameOverride -}}
{{- .Values.core.historyServer.fullnameOverride -}}
{{- else -}}
{{- printf "%s-history-server" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- /* spark.core.commonAnnotations - Common annotations for core components */ -}}
{{- define "spark.core.commonAnnotations" -}}
{{- if .Values.commonAnnotations -}}
{{- toYaml .Values.commonAnnotations | nindent 0 -}}
{{- end -}}
{{- end -}}

{{- /* spark.core.podSecurityContext - Common security context */ -}}
{{- define "spark.core.podSecurityContext" -}}
{{- if .Values.security.podSecurityStandards -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- else if .Values.security -}}
runAsUser: {{ .Values.security.runAsUser | default 1000 }}
runAsGroup: {{ .Values.security.runAsGroup | default 1000 }}
fsGroup: {{ .Values.security.fsGroup | default 1000 }}
{{- end -}}
{{- end -}}
