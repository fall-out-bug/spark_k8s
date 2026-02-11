# Spark Connect Go E2E Tests

> **Status:** ⏳ Not implemented - Depends on tests/go/client

## Purpose

End-to-end tests for Spark Connect Go client using NYC Taxi dataset.

## Test Scenarios (16)

| Scenario | Spark Version | Query Type | Dataset |
|----------|---------------|-------------|---------|
| 1 | 3.5.7 | COUNT aggregation | NYC Taxi |
| 2 | 3.5.8 | GROUP BY aggregation | NYC Taxi |
| 3 | 4.1.0 | JOIN with filter | NYC Taxi |
| 4 | 4.1.1 | Window function | NYC Taxi |
| 5 | 3.5.7 | Complex multi-step | NYC Taxi |
| 6 | 3.5.8 | Subquery | NYC Taxi |
| 7 | 4.1.0 | UNION | NYC Taxi |
| 8 | 4.1.1 | CTE (WITH clause) | NYC Taxi |
| 9-12 | Various | Performance tests | NYC Taxi |
| 13-16 | Various | Error handling | NYC Taxi |

## Dependencies

- `tests/go/client` - Spark Connect Go client
- NYC Taxi dataset (11GB)

## Implementation

See WS-017-03 for full specification.
