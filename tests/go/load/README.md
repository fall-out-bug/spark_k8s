# Spark Connect Go Load Tests

> **Status:** ⏳ Not implemented - Depends on tests/go/client

## Purpose

Load and performance tests for Spark Connect Go client.

## Test Scenarios (8)

| Scenario | Spark Version | Load Pattern | Duration | Metric |
|----------|---------------|--------------|----------|--------|
| 1 | 3.5.8 | 1 query/sec | 30 min | Throughput |
| 2 | 4.1.1 | 1 query/sec | 30 min | Throughput |
| 3 | 3.5.8 | 2 concurrent | 30 min | Concurrent |
| 4 | 4.1.1 | 2 concurrent | 30 min | Concurrent |
| 5 | 3.5.8 | Heavy aggregation | 30 min | Latency |
| 6 | 4.1.1 | Heavy aggregation | 30 min | Latency |
| 7 | 3.5.8 | Memory stress | 30 min | Memory |
| 8 | 4.1.1 | Memory stress | 30 min | Memory |

## Metrics

- Throughput (queries/sec)
- Latency (avg, P50, P95, P99)
- Concurrent connections
- Memory/CPU profiling via pprof

## Dependencies

- `tests/go/client` - Spark Connect Go client
- NYC Taxi dataset

## Implementation

See WS-017-04 for full specification.
