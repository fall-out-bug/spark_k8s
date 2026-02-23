# S3A Metrics Configuration Fragment
# Part of WS-025-12: S3A Metrics Export
# This fragment should be included when monitoring.s3aMetrics.enabled is true
# Note: This is a partial template - use with {{ include "spark-3.5.s3a-metrics" . }}

{{- define "spark-3.5.s3a-metrics" -}}
{{- if .Values.monitoring.s3aMetrics.enabled }}
    # S3A Metrics for Hadoop FileSystem
    # These metrics track S3 write operations and performance
    spark.metrics.conf.s3a.metricsystem=all
    spark.metrics.s3a.metricbyteswritten.interval=1s
    spark.metrics.s3a.metricbyteswritten.prefix=filesystem.s3a.byteswritten
{{- end }}
{{- end -}}
