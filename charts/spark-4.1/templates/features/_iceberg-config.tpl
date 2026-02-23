{{- /*
Iceberg Feature Templates
These templates provide Apache Iceberg support for Spark

Usage in spark-properties.conf:
{{- include "spark.iceberg.sparkConf" . | nindent 4 }}

Usage in environment variables:
{{- include "spark.iceberg.env" . }}
*/ -}}

{{- define "spark.iceberg.sparkConf" }}
spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog
spark.sql.catalog.spark_catalog.type={{ .Values.features.iceberg.catalogType | default "hadoop" }}
spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.iceberg.type={{ .Values.features.iceberg.catalogType | default "hadoop" }}
spark.sql.catalog.iceberg.warehouse={{ .Values.features.iceberg.warehouse | default "s3a://warehouse/iceberg" }}
spark.sql.catalog.iceberg.io-impl={{ .Values.features.iceberg.ioImpl | default "org.apache.iceberg.hadoop.HadoopFileIO" }}
{{- if eq .Values.features.iceberg.catalogType "hive" }}
spark.sql.catalog.iceberg.uri={{ .Values.hiveMetastore.service.host | default "hive-metastore" }}:9083
{{- end }}
{{- if eq .Values.features.iceberg.catalogType "rest" }}
spark.sql.catalog.iceberg.uri={{ .Values.features.iceberg.restCatalogUri | required "restCatalogUri required when catalogType is 'rest'" }}
spark.sql.catalog.iceberg.token={{ .Values.features.iceberg.restCatalogToken | default "" }}
{{- end }}
spark.sql.iceberg.vectorization.enabled=true
spark.sql.iceberg.v2.enabled=true
spark.sql.iceberg.delete-planning.enabled=true
spark.sql.iceberg.deletes.enabled=true
{{- end }}

{{- define "spark.iceberg.env" }}
- name: SPARK_CATALOG_ICEBERG_TYPE
  value: {{ .Values.features.iceberg.catalogType | default "hadoop" | quote }}
- name: SPARK_CATALOG_ICEBERG_WAREHOUSE
  value: {{ .Values.features.iceberg.warehouse | default "s3a://warehouse/iceberg" | quote }}
{{- end }}

{{- define "spark.iceberg.jupyterEnv" }}
PYSPARK_PYTHON: "/opt/conda/bin/python"
PYSPARK_DRIVER_PYTHON: "/opt/conda/bin/python"
SPARK_CATALOG_ICEBERG_TYPE: {{ .Values.features.iceberg.catalogType | default "hadoop" | quote }}
SPARK_CATALOG_ICEBERG_WAREHOUSE: {{ .Values.features.iceberg.warehouse | default "s3a://warehouse/iceberg" | quote }}
{{- end }}

{{- define "spark.iceberg.jars" }}
org.apache.iceberg:iceberg-spark-runtime-4.1:1.6.1
{{- end }}
