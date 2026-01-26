# ISSUE-035: Parquet data loader upload mechanism fixed

## Status
FIXED

## Severity
P2 - Quality improvement

## Description

The `scripts/load-nyt-parquet-data.sh` script had an unreliable file upload mechanism to MinIO. The `kubectl cp` approach failed to copy files, and the fallback mechanism wasn't properly structured.

## Error

```
Files in MinIO (s3://test-data/nyc/):
[2026-01-26 18:34:54 UTC]     0B STANDARD /
```

Files were downloaded but not uploaded to MinIO.

## Root Cause

1. `kubectl cp` with trailing slash (`"${DATA_DIR}/"`) had issues
2. Fallback upload loop was inside an `|| { ... }` block that masked errors
3. No verification that files were actually uploaded

## Fix

Simplified to always use `mc pipe` with proper error handling:

```bash
UPLOADED=0
for file in "${DATA_DIR}"/*; do
  if [[ -f "${file}" ]]; then
    filename=$(basename "${file}")
    echo "  Uploading ${filename}..."
    if cat "${file}" | kubectl exec -i -n "${NAMESPACE}" "${MINIO_POD}" -- \
      mc pipe local/"${BUCKET}"/"${DATASET}"/"${filename}" >/dev/null 2>&1; then
      ((UPLOADED++))
    else
      echo "  ERROR: Failed to upload ${filename}"
    fi
  fi
done

if [[ ${UPLOADED} -eq 0 ]]; then
  echo "ERROR: No files uploaded successfully"
  exit 1
fi
```

## Test Results

After fix, successfully uploaded 3 NYC taxi parquet files (~181MB):

```
Files in MinIO (s3://test-data/nyc/):
[2026-01-26 18:38:57 UTC]  56MiB STANDARD yellow_tripdata_2025-01.parquet
[2026-01-26 18:38:59 UTC]  58MiB STANDARD yellow_tripdata_2025-02.parquet
[2026-01-26 18:39:00 UTC]  67MiB STANDARD yellow_tripdata_2025-03.parquet
```

### Load Test Performance

NYC Taxi dataset: 11,198,026 records

| Operation | Time |
|-----------|------|
| Load parquet | 0.00s (cached) |
| Aggregation | 3.99s |
| Filter | 4.13s |
| GroupBy | 4.75s |

Range mode (1M records):

| Operation | Iteration 1 | Iteration 2 |
|-----------|-------------|-------------|
| Create DataFrame | 0.00s | 0.00s |
| Aggregation | 2.00s | 1.28s |
| Filter | 1.26s | 0.78s |

## Impact

- Improves reliability of parquet data loading for testing
- Enables proper load testing with real datasets
- Better error messages for troubleshooting

## Related

- scripts/load-nyt-parquet-data.sh
- scripts/test-parquet-load.sh
- test-e2e-parquet testing
