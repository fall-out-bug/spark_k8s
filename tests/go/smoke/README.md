# Spark Connect Go Smoke Tests

> **Status:** ⏳ Not implemented - Depends on tests/go/client

## Purpose

Basic smoke tests for Spark Connect Go client across Spark versions:
- 3.5.7, 3.5.8, 4.1.0, 4.1.1

## Test Scenarios (12)

| Scenario | Spark Version | Mode | Test Type |
|----------|---------------|------|-----------|
| 1 | 3.5.7 | connect-k8s | Connection |
| 2 | 3.5.8 | connect-k8s | Connection |
| 3 | 4.1.0 | connect-k8s | Connection |
| 4 | 4.1.1 | connect-k8s | Connection |
| 5 | 3.5.7 | connect-k8s | SQL operations |
| 6 | 3.5.8 | connect-k8s | SQL operations |
| 7 | 4.1.0 | connect-k8s | SQL operations |
| 8 | 4.1.1 | connect-k8s | SQL operations |
| 9 | 3.5.7 | connect-k8s | DataFrame |
| 10 | 3.5.8 | connect-k8s | DataFrame |
| 11 | 4.1.0 | connect-k8s | DataFrame |
| 12 | 4.1.1 | connect-k8s | DataFrame |

## Dependencies

- `tests/go/client` - Spark Connect Go client

## Implementation

See WS-017-02 for full specification.
