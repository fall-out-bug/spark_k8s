{{- /*==============================================*/ -}}
{{- /* GPU Feature Helper Templates               */ -}}
{{- /* Provides GPU resource allocation and       */ -}}
{{- /* scheduling helpers for NVIDIA/AMD GPUs    */ -}}
{{- /*==============================================*/ -}}

{{- /* spark.gpu.enabled - Check if GPU feature is enabled */ -}}
{{- define "spark.gpu.enabled" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- /* spark.gpu.resources - GPU resource requests/limits */ -}}
{{- define "spark.gpu.resources" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled -}}
resources:
  limits:
    {{ .Values.connect.executor.gpu.vendor }}: {{ .Values.connect.executor.gpu.count | quote }}
{{- end -}}
{{- end -}}

{{- /* spark.gpu.nodeSelector - Node selector for GPU nodes */ -}}
{{- define "spark.gpu.nodeSelector" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled .Values.connect.executor.gpu.nodeSelector -}}
nodeSelector:
{{- toYaml .Values.connect.executor.gpu.nodeSelector | nindent 2 }}
{{- end -}}
{{- end -}}

{{- /* spark.gpu.tolerations - Tolerations for GPU node taints */ -}}
{{- define "spark.gpu.tolerations" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled .Values.connect.executor.gpu.tolerations -}}
tolerations:
{{- toYaml .Values.connect.executor.gpu.tolerations | nindent 2 }}
{{- end -}}
{{- end -}}

{{- /* spark.gpu.sparkConf - RAPIDS GPU configuration for Spark */ -}}
{{- define "spark.gpu.sparkConf" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled -}}
# RAPIDS GPU Acceleration Configuration
spark.plugins: {{ .Values.features.gpu.rapids.plugins | default "com.nvidia.spark.SQLPlugin" | quote }}
spark.rapids.sql.enabled: {{ .Values.features.gpu.rapids.sql.enabled | default "true" | quote }}
spark.rapids.sql.python.gpu.enabled: {{ .Values.features.gpu.rapids.python.enabled | default "true" | quote }}
spark.rapids.sql.fallback.enabled: {{ .Values.features.gpu.rapids.fallback.enabled | default "true" | quote }}
spark.rapids.memory.gpu.allocFraction: {{ .Values.features.gpu.rapids.memory.allocFraction | default "0.8" | quote }}
spark.rapids.memory.gpu.maxAllocFraction: {{ .Values.features.gpu.rapids.memory.maxAllocFraction | default "0.9" | quote }}
spark.rapids.memory.gpu.minAllocFraction: {{ .Values.features.gpu.rapids.memory.minAllocFraction | default "0.3" | quote }}
spark.rapids.shuffle.enabled: {{ .Values.features.gpu.rapids.shuffle.enabled | default "true" | quote }}
# RAPIDS format support
spark.rapids.sql.format.parquet.read.enabled: {{ .Values.features.gpu.rapids.format.parquet.read | default "true" | quote }}
spark.rapids.sql.format.parquet.write.enabled: {{ .Values.features.gpu.rapids.format.parquet.write | default "true" | quote }}
spark.rapids.sql.format.orc.read.enabled: {{ .Values.features.gpu.rapids.format.orc.read | default "true" | quote }}
spark.rapids.sql.format.csv.read.enabled: {{ .Values.features.gpu.rapids.format.csv.read | default "true" | quote }}
spark.rapids.sql.format.json.read.enabled: {{ .Values.features.gpu.rapids.format.json.read | default "true" | quote }}
# GPU resource allocation
spark.executor.resource.gpu.amount: {{ .Values.connect.executor.gpu.count | default "1" | quote }}
spark.task.resource.gpu.amount: {{ .Values.features.gpu.taskResourceAmount | default "0.25" | quote }}
{{- end -}}
{{- end -}}

{{- /* spark.gpu.jars - RAPIDS jar configuration */ -}}
{{- define "spark.gpu.jars" -}}
{{- if and .Values.features.gpu.enabled .Values.features.gpu.rapids.jars.enabled -}}
{{- range .Values.features.gpu.rapids.jars.urls }}
{{ . }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* spark.gpu.env - Environment variables for GPU support */ -}}
{{- define "spark.gpu.env" -}}
{{- if and .Values.features.gpu.enabled .Values.connect.executor.gpu.enabled -}}
- name: NVIDIA_VISIBLE_DEVICES
  value: {{ .Values.features.gpu.nvidiaVisibleDevices | default "all" | quote }}
{{- if .Values.features.gpu.cudaVersion -}}
- name: CUDA_VERSION
  value: {{ .Values.features.gpu.cudaVersion | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
