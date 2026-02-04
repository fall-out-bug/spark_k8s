# Spark Connect Go Client (Testing & Load)

> **Status:** Backlog
> **Priority:** P1 - Go client support
> **Feature:** F17
> **Estimated Workstreams:** 4
> **Estimated LOC:** ~2800

## Goal

Создать Spark Connect Go client для тестирования и нагрузочных пайплайнов. Покрыть smoke tests, E2E tests и load tests для Go клиента.

## Current State

**Не реализовано** — Feature только начинается. Design Decisions требуют approval.

## Proposed Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-017-01 | Spark Connect Go client library | MEDIUM (~800 LOC) | F06, F11 | backlog |
| WS-017-02 | Go smoke tests | MEDIUM (~600 LOC) | WS-017-01 | backlog |
| WS-017-03 | Go E2E tests | MEDIUM (~700 LOC) | WS-017-01 | backlog |
| WS-017-04 | Go load tests | MEDIUM (~700 LOC) | WS-017-01 | backlog |

**Total Workstreams:** 4

## Design Decisions (Pending Approval)

### 1. Go Client Architecture

**Based on official spark-connect-go:**
- Use Apache Spark Connect gRPC client for Go
- Supports Spark 3.5+ with Connect protocol
- Reuse existing connection patterns

**Client features:**
- Connect to Spark Connect server (port 15002)
- Execute SQL queries
- Read/write DataFrames
- Session management

### 2. Smoke Tests for Go

**Test scenarios (12):**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × connect-k8s
- Basic SQL operations
- DataFrame operations
- Connection lifecycle

**Format:**
- Go test framework (`go test`)
- Table-driven tests
- Testcontainers for K8s (optional)

### 3. E2E Tests for Go

**Test scenarios (16):**
- Full dataset queries (NYC Taxi)
- Complex aggregations
- JOIN operations
- Window functions
- Error handling

**Format:**
- Go test framework
- Integration with existing test framework
- Reuse existing queries

### 4. Load Tests for Go

**Test scenarios (8):**
- Sustained load (30 min)
- Concurrent connections
- Query throughput
- Memory/CPU profiling

**Format:**
- Go test with benchmark (`go test -bench`)
- Custom load test framework
- Metrics collection

## Dependencies

- **F06 (Core Components + Presets):** Helm charts deployed
- **F11 (Docker Final Images):** Spark Connect images available
- **F08 (Smoke Tests):** Smoke test patterns
- **F12 (E2E Tests):** E2E test patterns
- **F13 (Load Tests):** Load test patterns

## Success Criteria

1. ⏳ Spark Connect Go client работает
2. ⏳ 12 smoke test сценариев для Go
3. ⏳ 16 E2E test сценариев для Go
4. ⏳ 8 load test сценариев для Go
5. ⏳ Integration с существующими test frameworks
6. ⏳ Performance сравним с Python client
7. ⏳ Documentation для Go client

## File Structure

```
tests/go/
├── client/
│   ├── go.mod
│   ├── go.sum
│   ├── connect.go              # Main Spark Connect client
│   ├── session.go              # Session management
│   ├── dataframe.go            # DataFrame operations
│   └── types.go                # Common types
├── smoke/
│   ├── connect_test.go         # Connection tests
│   ├── sql_test.go             # SQL operation tests
│   ├── dataframe_test.go       # DataFrame tests
│   └── scenarios_test.go       # Scenario-based tests
├── e2e/
│   ├── queries_test.go         # E2E query tests
│   ├── nyc_taxi_test.go        # NYC Taxi dataset tests
│   └── performance_test.go     # Performance comparisons
├── load/
│   ├── sustained_test.go       # Sustained load tests
│   ├── concurrent_test.go      # Concurrent connection tests
│   └── benchmark_test.go       # Go benchmarks
└── scripts/
    ├── setup_go_env.sh         # Go environment setup
    └── run_go_tests.sh         # Test runner

docs/
└── go-client/
    ├── README.md               # Go client documentation
    ├── examples.md             # Usage examples
    └── api.md                  # API reference
```

## Integration with Other Features

- **F06 (Core Components + Presets):** Charts provide Spark Connect deployment
- **F11 (Docker Final Images):** Spark Connect server images
- **F08 (Smoke Tests):** Smoke test patterns
- **F12 (E2E Tests):** E2E test framework
- **F13 (Load Tests):** Load test framework

## Spark Connect Go API

```go
package spark

import (
    "context"
    "google.golang.org/grpc"
)

// Client represents a Spark Connect client
type Client struct {
    conn   *grpc.ClientConn
    client connect.SparkConnectClient
    sessionID string
}

// NewClient creates a new Spark Connect client
func NewClient(ctx context.Context, endpoint string, opts ...ClientOption) (*Client, error) {
    conn, err := grpc.DialContext(ctx, endpoint, opts...)
    if err != nil {
        return nil, err
    }

    client := connect.NewSparkConnectClient(conn)
    return &Client{
        conn:   conn,
        client: client,
    }, nil
}

// Session represents a Spark session
type Session struct {
    client *Client
    id     string
}

// CreateSession creates a new Spark session
func (c *Client) CreateSession(ctx context.Context) (*Session, error) {
    resp, err := c.client.CreateSession(ctx, &connect.CreateSessionRequest{
        UserContext: &connect.UserContext{
            UserId: "go-client",
        },
    })
    if err != nil {
        return nil, err
    }

    return &Session{
        client: c,
        id:     resp.SessionId,
    }, nil
}

// SQL executes a SQL query
func (s *Session) SQL(ctx context.Context, query string) (*DataFrame, error) {
    resp, err := s.client.client.ExecutePlan(ctx, &connect.ExecutePlanRequest{
        SessionId: s.id,
        Plan: &connect.Plan{
            Op: &connect.Plan_Sql{
                Sql: query,
            },
        },
    })
    if err != nil {
        return nil, err
    }

    return &DataFrame{
        session: s,
        id:      resp.SessionId,
    }, nil
}

// DataFrame represents a Spark DataFrame
type DataFrame struct {
    session *Session
    id      string
}

// Collect collects all rows from the DataFrame
func (df *DataFrame) Collect(ctx context.Context) ([]Row, error) {
    resp, err := df.session.client.client.ExecutePlan(ctx, &connect.ExecutePlanRequest{
        SessionId: df.session.id,
        Plan: &connect.Plan{
            Op: &connect.Plan_Relation{
                Relation: df.toRelation(),
            },
        },
    })
    if err != nil {
        return nil, err
    }

    return parseRows(resp), nil
}

// Row represents a single row
type Row struct {
    values []interface{}
}

// Get gets a value by column index
func (r *Row) Get(i int) interface{} {
    return r.values[i]
}
```

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F17: Spark Connect Go Client (P1)

# Workstreams
spark_k8s-xxx - WS-017-01: Spark Connect Go client library (P1)
spark_k8s-xxx - WS-017-02: Go smoke tests (P1)
spark_k8s-xxx - WS-017-03: Go E2E tests (P1)
spark_k8s-xxx - WS-017-04: Go load tests (P1)

# Dependencies
WS-017-02 depends on WS-017-01
WS-017-03 depends on WS-017-01
WS-017-04 depends on WS-017-01
All WS depend on F06, F11
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [Spark Connect Go](https://github.com/apache/spark/blob/master/connect/client/go/README.md)
- [Spark Connect Protocol](https://spark.apache.org/docs/latest/api/python/user_guide/python_client/spark_connect.html)
