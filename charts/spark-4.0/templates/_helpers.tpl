{{- define "spark-4.0.fullname" -}}
{{- .Release.Name }}-spark-40
{{- end }}

{{- define "spark-4.0.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "spark-4.0.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "spark-4.0.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccountName }}
{{- .Values.rbac.serviceAccountName }}
{{- else if .Values.rbac.create }}
{{- include "spark-4.0.fullname" . }}
{{- else }}
{{- include "spark-base.serviceAccountName" (dict "Values" (index .Values "spark-base") "Release" .Release "Chart" .Chart) }}
{{- end }}
{{- end }}

# GPU Helper Templates
# These templates provide conditional logic for GPU resource allocation and scheduling

{{- define "spark.gpu.nodeSelector" -}}
{{- if and .Values.connect.executor.gpu .Values.connect.executor.gpu.enabled }}
{{- toYaml .Values.connect.executor.gpu.nodeSelector | nindent 0 }}
{{- else }}
{{- with .Values.connect.nodeSelector }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "spark.gpu.tolerations" -}}
{{- if and .Values.connect.executor.gpu .Values.connect.executor.gpu.enabled }}
{{- toYaml .Values.connect.executor.gpu.tolerations | nindent 0 }}
{{- else }}
{{- with .Values.connect.tolerations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "spark.gpu.resources" -}}
resources:
  {{- if and .Values.connect.executor.gpu .Values.connect.executor.gpu.enabled }}
  limits:
    cpu: {{ .Values.connect.resources.limits.cpu | default "2" }}
    memory: {{ .Values.connect.resources.limits.memory | default "4Gi" }}
    {{ .Values.connect.executor.gpu.vendor }}: {{ .Values.connect.executor.gpu.count | quote }}
  requests:
    cpu: {{ .Values.connect.resources.requests.cpu | default "1" }}
    memory: {{ .Values.connect.resources.requests.memory | default "2Gi" }}
  {{- else }}
  {{- with .Values.connect.resources }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- end }}
{{- end }}

{{- define "spark.gpu.sparkConf" -}}
{{- if and .Values.connect.features .Values.connect.features.gpu .Values.connect.features.gpu.enabled }}
# RAPIDS GPU Configuration
spark.plugins: "com.nvidia.spark.SQLPlugin"
spark.rapids.sql.enabled: "true"
spark.rapids.sql.python.gpu.enabled: "true"
spark.rapids.sql.fallback.enabled: "true"
spark.rapids.memory.gpu.allocFraction: "0.8"
spark.rapids.memory.gpu.maxAllocFraction: "0.9"
spark.rapids.memory.gpu.minAllocFraction: "0.3"
spark.rapids.shuffle.enabled: "true"
spark.rapids.sql.format.parquet.read.enabled: "true"
spark.rapids.sql.format.parquet.write.enabled: "true"
spark.rapids.sql.format.orc.read.enabled: "true"
spark.rapids.sql.format.csv.read.enabled: "true"
spark.rapids.sql.format.json.read.enabled: "true"
spark.executor.resource.gpu.amount: {{ .Values.connect.executor.gpu.count | default "1" | quote }}
spark.task.resource.gpu.amount: "0.25"
{{- end }}
{{- end }}

{{- define "spark.gpu.jupyterResources" -}}
resources:
  {{- if and .Values.jupyter.resources .Values.connect.features .Values.connect.features.gpu .Values.connect.features.gpu.enabled }}
  limits:
    cpu: {{ .Values.jupyter.resources.limits.cpu | default "2" }}
    memory: {{ .Values.jupyter.resources.limits.memory | default "8Gi" }}
    {{ .Values.connect.executor.gpu.vendor }}: "1"
  requests:
    cpu: {{ .Values.jupyter.resources.requests.cpu | default "500m" }}
    memory: {{ .Values.jupyter.resources.requests.memory | default "2Gi" }}
    {{ .Values.connect.executor.gpu.vendor }}: "1"
  {{- else }}
  {{- with .Values.jupyter.resources }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- end }}
{{- end }}

# Iceberg Helper Templates
# These templates provide conditional logic for Apache Iceberg support

{{- define "spark.iceberg.sparkConf" -}}
{{- if and .Values.connect.features .Values.connect.features.iceberg .Values.connect.features.iceberg.enabled }}
# Iceberg Configuration
spark.sql.extensions: "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
spark.sql.catalog.spark_catalog: "org.apache.iceberg.spark.SparkSessionCatalog"
spark.sql.catalog.spark_catalog.type: {{ .Values.connect.features.iceberg.catalogType | default "hadoop" }}
spark.sql.catalog.iceberg: "org.apache.iceberg.spark.SparkCatalog"
spark.sql.catalog.iceberg.type: {{ .Values.connect.features.iceberg.catalogType | default "hadoop" }}
spark.sql.catalog.iceberg.warehouse: {{ .Values.connect.features.iceberg.warehouse | default "s3a://warehouse/iceberg" }}
spark.sql.catalog.iceberg.io-impl: {{ .Values.connect.features.iceberg.ioImpl | default "org.apache.iceberg.hadoop.HadoopFileIO" }}
{{- if eq .Values.connect.features.iceberg.catalogType "hive" }}
spark.sql.catalog.iceberg.uri: {{ .Values.hiveMetastore.service.host | default "hive-metastore" }}:9083
{{- end }}
spark.sql.iceberg.vectorization.enabled: "true"
spark.sql.iceberg.v2.enabled: "true"
spark.sql.iceberg.delete-planning.enabled: "true"
spark.sql.iceberg.deletes.enabled: "true"
{{- end }}
{{- end }}

{{- define "spark.iceberg.env" -}}
{{- if and .Values.connect.features .Values.connect.features.iceberg .Values.connect.features.iceberg.enabled }}
- name: SPARK_CATALOG_ICEBERG_TYPE
  value: {{ .Values.connect.features.iceberg.catalogType | default "hadoop" | quote }}
- name: SPARK_CATALOG_ICEBERG_WAREHOUSE
  value: {{ .Values.connect.features.iceberg.warehouse | default "s3a://warehouse/iceberg" | quote }}
{{- end }}
{{- end }}

{{- define "spark.iceberg.jupyterEnv" -}}
{{- if and .Values.connect.features .Values.connect.features.iceberg .Values.connect.features.iceberg.enabled }}
PYSPARK_PYTHON: "/opt/conda/bin/python"
PYSPARK_DRIVER_PYTHON: "/opt/conda/bin/python"
SPARK_CATALOG_ICEBERG_TYPE: {{ .Values.connect.features.iceberg.catalogType | default "hadoop" | quote }}
SPARK_CATALOG_ICEBERG_WAREHOUSE: {{ .Values.connect.features.iceberg.warehouse | default "s3a://warehouse/iceberg" | quote }}
{{- end }}
{{- end }}
