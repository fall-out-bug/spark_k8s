# ISSUE-030: Spark 4.1 MinIO label "N/A" causes deployment failure

## Status
OPEN

## Severity
P0 - Blocks E2E tests

## Description

Spark 4.1 chart fails to deploy when MinIO is enabled. The error occurs due to an invalid label value "N/A" in the MinIO deployment and service metadata.

## Error Message

```
Error: 2 errors occurred:
	* Service "minio" is invalid: metadata.labels: Invalid value: "N/A": a valid label must be an empty string or consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character (e.g. 'MyValue',  or 'my_value',  or '12345', regex used for validation is '(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?')
	* Deployment.apps "minio" is invalid: metadata.labels: Invalid value: "N/A": a valid label must be an empty string or consist of alphanumeric characters, '-', '_' or '.', and must start and end with an alphanumeric character (e.g. 'MyValue',  or 'my_value',  or '12345', regex used for validation is '(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9_.]*)?[A-Za-z0-9])?')
```

## Reproduction

```bash
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set spark-base.minio.enabled=true
```

## Root Cause

The MinIO chart or values file contains a label with value "N/A" which is not a valid Kubernetes label value. Kubernetes labels must:
- Be empty or consist of alphanumeric characters, '-', '_' or '.'
- Start and end with an alphanumeric character

## Solution

Find and fix the "N/A" label in the MinIO configuration. Likely locations:
- `charts/spark-4.1/values.yaml` - MinIO section
- `charts/spark-4.1/templates/minio.yaml` - MinIO template

Fix options:
1. Remove the "N/A" label entirely
2. Replace with a valid value like "none" or "internal"
3. Use an empty string instead

## Impact

- Blocks all Spark 4.1 deployments with MinIO enabled
- Affects E2E tests
- Affects development environments

## Related

- E2E test execution on Minikube
- Spark 4.1 chart validation
