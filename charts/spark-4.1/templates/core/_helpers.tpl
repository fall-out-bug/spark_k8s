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

{{- /* spark.core.historyServer.deployment - Include deployment template */ -}}
{{- define "spark.core.historyServer.deployment" -}}
{{- if .Values.core.historyServer.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark.core.historyServer.fullname" . }}
  labels:
    {{- include "spark.core.labels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: spark-history-server
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "spark.core.selectorLabels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 6 }}
      app.kubernetes.io/name: spark-history-server
  template:
    metadata:
      labels:
        {{- include "spark.core.labels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 8 }}
        app.kubernetes.io/name: spark-history-server
      {{- with .Values.core.historyServer.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      serviceAccountName: {{ include "spark-4.1.serviceAccountName" . }}
      {{- if .Values.security.podSecurityStandards }}
      securityContext:
        {{- include "spark.core.podSecurityContext" . | nindent 8 }}
      {{- end }}
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: history-server
          image: "{{ .Values.core.historyServer.image.repository }}:{{ .Values.core.historyServer.image.tag }}"
          imagePullPolicy: {{ .Values.core.historyServer.image.pullPolicy }}
          {{- if .Values.security.podSecurityStandards }}
          securityContext:
            {{- include "spark.base.containerSecurityContext" . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: 18080
              protocol: TCP
          env:
            - name: SPARK_MODE
              value: "history"
            - name: SPARK_HISTORY_OPTS
              value: "-Dspark.history.fs.logDirectory={{ .Values.core.historyServer.logDirectory }}"
            {{- if .Values.global.s3 }}
            - name: S3_ENDPOINT
              value: {{ .Values.global.s3.endpoint | quote }}
            - name: S3_PATH_STYLE_ACCESS
              value: {{ .Values.global.s3.pathStyleAccess | quote }}
            - name: S3_SSL_ENABLED
              value: {{ .Values.global.s3.sslEnabled | quote }}
            {{- if .Values.global.s3.existingSecret }}
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.global.s3.existingSecret }}
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.global.s3.existingSecret }}
                  key: secret-key
            {{- else }}
            - name: AWS_ACCESS_KEY_ID
              value: {{ .Values.global.s3.accessKey | quote }}
            - name: AWS_SECRET_ACCESS_KEY
              value: {{ .Values.global.s3.secretKey | quote }}
            {{- end }}
            {{- end }}
            - name: HADOOP_USER_NAME
              value: "spark"
          resources:
            {{- toYaml .Values.core.historyServer.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: spark-conf
              mountPath: /opt/spark/conf
              readOnly: true
      volumes:
        - name: tmp
          emptyDir: {}
        - name: spark-conf
          configMap:
            name: {{ include "spark.core.historyServer.fullname" . }}-config
            items:
              - key: spark-defaults.conf
                path: spark-defaults.conf
{{- end -}}
{{- end -}}

{{- /* spark.core.historyServer.service - Include service template */ -}}
{{- define "spark.core.historyServer.service" -}}
{{- if .Values.core.historyServer.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark.core.historyServer.fullname" . }}
  labels:
    {{- include "spark.core.labels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: spark-history-server
spec:
  type: {{ .Values.core.historyServer.service.type }}
  ports:
    - port: {{ .Values.core.historyServer.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "spark.core.selectorLabels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: spark-history-server
{{- end -}}
{{- end -}}

{{- /* spark.core.historyServer.configmap - Include configmap template */ -}}
{{- define "spark.core.historyServer.configmap" -}}
{{- if .Values.core.historyServer.enabled -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "spark.core.historyServer.fullname" . }}-config
  labels:
    {{- include "spark.core.labels" (dict "Component" "history-server" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: spark-history-server
data:
  spark-defaults.conf: |
    # Spark History Server Configuration
    spark.history.fs.logDirectory {{ .Values.core.historyServer.logDirectory }}
    spark.history.fs.update.interval {{ .Values.core.historyServer.updateInterval | default "10s" }}
    spark.history.provider {{ .Values.core.historyServer.provider | default "org.apache.spark.deploy.history.FsHistoryProvider" }}

    {{- if .Values.global.s3 }}
    # S3 Configuration for Event Logs
    spark.hadoop.fs.s3a.endpoint {{ .Values.global.s3.endpoint }}
    spark.hadoop.fs.s3a.path.style.access {{ .Values.global.s3.pathStyleAccess | default "true" }}
    spark.hadoop.fs.s3a.connection.ssl.enabled {{ .Values.global.s3.sslEnabled | default "false" }}
    spark.hadoop.fs.s3a.impl {{ .Values.core.historyServer.s3aImpl | default "org.apache.hadoop.fs.s3a.S3AFileSystem" }}
    spark.hadoop.fs.s3a.aws.credentials.provider {{ .Values.core.historyServer.credentialsProvider | default "com.amazonaws.auth.SimpleAWSCredentialsProvider" }}

    # S3 credentials (from config for History Server compatibility)
    spark.hadoop.fs.s3a.access.key {{ .Values.global.s3.accessKey }}
    spark.hadoop.fs.s3a.secret.key {{ .Values.global.s3.secretKey }}

    # S3 connection settings
    spark.hadoop.fs.s3a.connection.maximum {{ .Values.core.historyServer.s3ConnectionMax | default "200" }}
    spark.hadoop.fs.s3a.connection.timeout {{ .Values.core.historyServer.s3ConnectionTimeout | default "200000" }}
    {{- end }}

    # History Server UI Settings
    spark.history.ui.port {{ .Values.core.historyServer.service.port | default "18080" }}
    spark.history.ui.maxApplications {{ .Values.core.historyServer.maxApplications | default "1000" }}

    {{- with .Values.core.historyServer.sparkConf }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.secret - Include secret template */ -}}
{{- define "spark.core.minio.secret" -}}
{{- if and .Values.core.minio.enabled (not .Values.global.s3.existingSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "spark.core.minio.fullname" . }}-credentials
  labels:
    {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
type: Opaque
stringData:
  access-key: {{ .Values.global.s3.accessKey | default "minioadmin" }}
  secret-key: {{ .Values.global.s3.secretKey | default "minioadmin" }}
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.deployment - Include deployment template */ -}}
{{- define "spark.core.minio.deployment" -}}
{{- if .Values.core.minio.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark.core.minio.fullname" . }}
  labels:
    {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "spark.core.selectorLabels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 6 }}
      app.kubernetes.io/name: minio
  template:
    metadata:
      labels:
        {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 8 }}
        app.kubernetes.io/name: minio
    spec:
      {{- if .Values.security.podSecurityStandards }}
      securityContext:
        {{- include "spark.core.podSecurityContext" . | nindent 8 }}
      {{- end }}
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: minio
        {{- if .Values.security.podSecurityStandards }}
        securityContext:
          {{- include "spark.base.containerSecurityContext" . | nindent 10 }}
          runAsUser: 1000
          runAsGroup: 1000
        {{- end }}
        image: "{{ .Values.core.minio.image.repository }}:{{ .Values.core.minio.image.tag }}"
        imagePullPolicy: {{ .Values.core.minio.image.pullPolicy }}
        args:
        - server
        - /data
        - --console-address
        - ":{{ .Values.core.minio.service.consolePort }}"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: {{ .Values.global.s3.existingSecret | default (printf "%s-credentials" (include "spark.core.minio.fullname" .)) }}
              key: access-key
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.global.s3.existingSecret | default (printf "%s-credentials" (include "spark.core.minio.fullname" .)) }}
              key: secret-key
        ports:
        - name: api
          containerPort: {{ .Values.core.minio.service.port }}
        - name: console
          containerPort: {{ .Values.core.minio.service.consolePort }}
        volumeMounts:
        - name: data
          mountPath: /data
        - name: tmp
          mountPath: /tmp
        resources:
          {{- toYaml .Values.core.minio.resources | nindent 10 }}
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: {{ .Values.core.minio.service.port }}
          initialDelaySeconds: 10
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: {{ .Values.core.minio.service.port }}
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: data
        {{- if .Values.core.minio.persistence.enabled }}
        persistentVolumeClaim:
          claimName: {{ include "spark.core.minio.fullname" . }}-pvc
        {{- else }}
        emptyDir: {}
        {{- end }}
      - name: tmp
        emptyDir: {}
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.service - Include service template */ -}}
{{- define "spark.core.minio.service" -}}
{{- if .Values.core.minio.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark.core.minio.fullname" . }}
  labels:
    {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: minio
spec:
  ports:
  - name: api
    port: {{ .Values.core.minio.service.port }}
    targetPort: {{ .Values.core.minio.service.port }}
  - name: console
    port: {{ .Values.core.minio.service.consolePort }}
    targetPort: {{ .Values.core.minio.service.consolePort }}
  selector:
    {{- include "spark.core.selectorLabels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
    app.kubernetes.io/name: minio
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.pvc - Include PVC template */ -}}
{{- define "spark.core.minio.pvc" -}}
{{- if and .Values.core.minio.enabled .Values.core.minio.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "spark.core.minio.fullname" . }}-pvc
  labels:
    {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  {{- if .Values.core.minio.persistence.storageClass }}
  storageClassName: {{ .Values.core.minio.persistence.storageClass | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ .Values.core.minio.persistence.size }}
{{- end -}}
{{- end -}}

{{- /* spark.core.minio.bucketInit - Include bucket initialization job template */ -}}
{{- define "spark.core.minio.bucketInit" -}}
{{- if .Values.core.minio.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "spark.core.minio.fullname" . }}-init-buckets
  labels:
    {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: 10
  template:
    metadata:
      labels:
        {{- include "spark.core.labels" (dict "Component" "minio" "Chart" .Chart "Release" .Release) | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      {{- if .Values.security.podSecurityStandards }}
      securityContext:
        {{- include "spark.core.podSecurityContext" . | nindent 8 }}
      {{- end }}
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: mc
        {{- if .Values.security.podSecurityStandards }}
        securityContext:
          {{- include "spark.base.containerSecurityContext" . | nindent 10 }}
          runAsUser: 1000
          runAsGroup: 1000
        {{- end }}
        image: quay.io/minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          echo "Waiting for MinIO to be ready..."
          for i in $(seq 1 30); do
            if mc alias set myminio http://{{ include "spark.core.minio.fullname" . }}:{{ .Values.core.minio.service.port }} $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD; then
              echo "MinIO is ready!"
              break
            fi
            echo "Attempt $i: MinIO not ready yet, waiting..."
            sleep 5
          done

          {{- range .Values.core.minio.buckets }}
          mc mb --ignore-existing myminio/{{ . }}
          {{- end }}

          {{- if has "spark-logs" .Values.core.minio.buckets }}
          echo "" | mc pipe myminio/spark-logs/events/.keep
          echo "" | mc pipe myminio/spark-logs/4.1/events/.keep
          {{- end }}
          {{- if has "spark-standalone-logs" .Values.core.minio.buckets }}
          echo "" | mc pipe myminio/spark-standalone-logs/events/.keep
          {{- end }}

          echo "Buckets created successfully"
          mc ls myminio/
        env:
        - name: HOME
          value: /tmp
        - name: MC_CONFIG_DIR
          value: /tmp/.mc
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: {{ .Values.global.s3.existingSecret | default (printf "%s-credentials" (include "spark.core.minio.fullname" .)) }}
              key: access-key
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.global.s3.existingSecret | default (printf "%s-credentials" (include "spark.core.minio.fullname" .)) }}
              key: secret-key
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
{{- end -}}
{{- end -}}
