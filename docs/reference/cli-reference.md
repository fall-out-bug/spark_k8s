# CLI Reference

Reference for Spark on Kubernetes command-line tools.

## kubectl-spark

The `kubectl-spark` plugin provides convenient commands for managing Spark applications.

### Installation

```bash
# Install the plugin
kubectl krew index add spark-operator \
  https://github.com/GoogleCloudPlatform/spark-on-k8s-operator/releases/latest/download/krew-index.yaml

kubectl krew install spark-operator
```

### Commands

#### Submit Application

```bash
kubectl spark submit \
  --namespace spark-prod \
  --class org.apache.spark.examples.SparkPi \
  --driver-memory 2g \
  --executor-memory 4g \
  --executor-cores 2 \
  --num-executors 5 \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar
```

#### List Applications

```bash
kubectl spark list --namespace spark-prod
```

#### Describe Application

```bash
kubectl spark describe spark-app my-app --namespace spark-prod
```

#### Delete Application

```bash
kubectl spark delete spark-app my-app --namespace spark-prod
```

## spark-submit

Native Spark submit commands adapted for Kubernetes.

### Basic Syntax

```bash
bin/spark-submit \
  --master k8s://https://<k8s-apiserver>:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=<spark-image> \
  --conf spark.kubernetes.namespace=spark-prod \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar
```

### Common Options

#### Master

```bash
--master k8s://https://<kubernetes-apiserver>:443
```

Or use in-cluster config:

```bash
--master k8s://https://kubernetes.default.svc
```

#### Deploy Mode

```bash
--deploy-mode cluster    # Run executors in cluster (required for K8s)
--deploy-mode client     # Run driver locally, executors in cluster
```

#### Application Name

```bash
--name my-application
```

#### Image

```bash
--conf spark.kubernetes.container.image=my-registry/spark:3.5.0
```

#### Namespace

```bash
--conf spark.kubernetes.namespace=spark-prod
```

#### Service Account

```bash
--conf spark.kubernetes.authenticate.driver.serviceAccountName=spark
--conf spark.kubernetes.authenticate.executor.serviceAccountName=spark
```

#### Resource Configuration

```bash
# Driver
--conf spark.driver.memory=4g
--conf spark.driver.cores=2
--conf spark.kubernetes.driver.limit.cores=2

# Executors
--conf spark.executor.memory=8g
--conf spark.executor.cores=4
--conf spark.executor.instances=10
--conf spark.kubernetes.executor.limit.cores=4
```

#### Dynamic Allocation

```bash
--conf spark.dynamicAllocation.enabled=true
--conf spark.dynamicAllocation.minExecutors=2
--conf spark.dynamicAllocation.maxExecutors=20
--conf spark.dynamicAllocation.initialExecutors=5
--conf spark.shuffle.service.enabled=true
```

#### Volumes

```bash
# Persistent volume claim
--conf spark.kubernetes.driver.volumes.persistentVolumeClaim=my-pvc-data
--conf spark.kubernetes.driver.volumes.persistentVolumeClaim.mount.path=/data

# ConfigMap
--conf spark.kubernetes.driver.volumes.configMap=my-config
--conf spark.kubernetes.driver.volumes.configMap.mount.path=/etc/config
```

#### Dependencies

```bash
# JARs
--jars local:///app/lib/utils.jar,s3a://bucket/lib.jar

# Packages
--packages com.amazonaws:aws-java-sdk:1.11.375

# Repositories
--repositories https://repo.maven.apache.org/maven2/

# Python files
--py-files local:///app/deps.zip

# Python packages
--py-files s3a://bucket/deps.zip
--conf spark.kubernetes.fileUploader.pathType=s3a
```

### Python Applications

```bash
bin/spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode cluster \
  --name my-python-app \
  --conf spark.executor.instances=5 \
  --conf spark.kubernetes.container.image=my-registry/spark-py:3.5.0 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  local:///app/jobs/my_job.py \
  --input s3a://data/input \
  --output s3a://data/output
```

### R Applications

```bash
bin/spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode cluster \
  --name my-r-app \
  --conf spark.kubernetes.container.image=my-registry/spark-r:3.5.0 \
  local:///app/jobs/my_job.R
```

### Using Client Mode

```bash
# Run driver locally, executors in K8s
bin/spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  --conf spark.executor.instances=5 \
  --conf spark.kubernetes.container.image=my-registry/spark:3.5.0 \
  my_job.jar
```

### Proxy Configuration

```bash
# If behind a proxy
--conf spark.kubernetes.driver.podTemplateFile=driver-template.yaml
--conf spark.kubernetes.executor.podTemplateFile=executor-template.yaml
```

### Timeouts

```bash
# Submission timeout
--conf spark.kubernetes.submission.waitTimeout=60s

# App wait timeout
--conf spark.kubernetes.appWaitTimeout=60m
```

### Examples

#### Submit Python Streaming Job

```bash
spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode cluster \
  --name streaming-job \
  --conf spark.executor.instances=10 \
  --conf spark.executor.memory=8g \
  --conf spark.executor.cores=4 \
  --conf spark.streaming.backpressure.enabled=true \
  --conf spark.kubernetes.container.image=spark:3.5.0 \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  local:///app/streaming.py
```

#### Submit with GPU Support

```bash
spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode cluster \
  --name ml-training \
  --conf spark.executor.resource.gpu.amount=1 \
  --conf spark.task.resource.gpu.amount=1 \
  --conf spark.kubernetes.container.image=spark-gpu:3.5.0 \
  local:///app/ml_training.py
```

## spark-shell

Interactive shell for development.

```bash
spark-shell \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=spark:3.5.0
```

## pyspark

Python interactive shell.

```bash
pyspark \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=spark:3.5.0 \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0
```

## spark-sql

Interactive SQL shell.

```bash
spark-sql \
  --master k8s://https://kubernetes.default.svc \
  --deploy-mode client \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=spark:3.5.0
```

## Common Issues

### Authentication

```bash
# For out-of-cluster access
export KUBECONFIG=/path/to/kubeconfig

spark-submit \
  --master k8s://https://kubernetes.default.svc \
  --conf spark.kubernetes.authenticate.caCertFile=/path/to/ca.crt \
  --conf spark.kubernetes.authenticate.clientCertFile=/path/to/client.crt \
  --conf spark.kubernetes.authenticate.clientKeyFile=/path/to/client.key \
  my_job.jar
```

### Image Pull Secrets

```bash
spark-submit \
  --conf spark.kubernetes.container.image.pullSecrets=my-registry-secret \
  my_job.jar
```

### Networking

```bash
# For custom DNS
spark-submit \
  --conf spark.kubernetes.driver.dnsPolicy=ClusterFirst \
  --conf spark.kubernetes.executor.dnsPolicy=ClusterFirst \
  my_job.jar
```

## Related

- [Helm Values Reference](./values-reference.md)
- [Configuration Reference](./config-reference.md)
