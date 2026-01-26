package spark_values

import future.keywords.contains

# Deny pods with privileged containers
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[i]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' must not run as privileged", [container.name])
}

# Deny containers without resource limits
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[i]
  not container.resources.limits
  msg := sprintf("Container '%s' must have resource limits defined", [container.name])
}

# Deny containers where memory request exceeds limit
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[i]
  has_memory_resources(container.resources)
  request_mi := parse_memory(container.resources.requests.memory)
  limit_mi := parse_memory(container.resources.limits.memory)
  request_mi > limit_mi
  msg := sprintf("Container '%s': memory request (%s) exceeds limit (%s)", [
    container.name,
    container.resources.requests.memory,
    container.resources.limits.memory
  ])
}

# Deny Spark pods without S3 credentials when S3 is configured
deny[msg] {
  input.kind == "Pod"
  has_s3_env_vars(input)
  not has_s3_credentials_volume(input)
  msg := "Pod uses S3 but missing S3 credentials volume mount"
}

# Helper: check if pod has S3 environment variables
has_s3_env_vars(pod) {
  some i, j
  pod.spec.containers[i].env[j].name == "AWS_ACCESS_KEY_ID"
}

has_s3_env_vars(pod) {
  some i, j
  pod.spec.containers[i].env[j].name == "SPARK_S3_ACCESS_KEY"
}

has_s3_env_vars(pod) {
  some i, j
  pod.spec.containers[i].env[j].name == "MINIO_ACCESS_KEY"
}

# Helper: check if pod has S3 credentials volume
has_s3_credentials_volume(pod) {
  some i, j
  pod.spec.volumes[i].name == "s3-credentials"
  pod.spec.containers[j].volumeMounts[k].name == "s3-credentials"
}

has_s3_credentials_volume(pod) {
  some i, j
  pod.spec.volumes[i].name == "minio-credentials"
  pod.spec.containers[j].volumeMounts[k].name == "minio-credentials"
}

# Helper: check if container has memory resources defined
has_memory_resources(resources) {
  resources.requests.memory
  resources.limits.memory
}

# Helper: parse memory string to Mi (megabytes)
parse_memory(mem_str) {
  num := to_number(replace(mem_str, "Mi", ""))
  num
}

parse_memory(mem_str) {
  num := to_number(replace(mem_str, "Gi", ""))
  num * 1024
}

parse_memory(mem_str) {
  num := to_number(replace(mem_str, "Ei", ""))
  num * 1024 * 1024
}
