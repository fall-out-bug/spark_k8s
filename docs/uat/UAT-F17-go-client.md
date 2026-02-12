# UAT Guide: F17 — Spark Connect Go Client

**Feature:** F17  
**Date:** 2026-02-10  

---

## Overview

F17 delivers a Spark Connect Go client library and tests (smoke, E2E, load). Connects to Spark Connect server via gRPC, executes SQL and DataFrame operations.

---

## Prerequisites

- [ ] Go 1.23+
- [ ] Spark Connect server running (port 15002)
- [ ] `go mod tidy` executed

---

## Quick Verification (30 seconds)

### Go module

```bash
cd tests/go
go mod tidy
go build ./...
# Expected: no packages to build (client not implemented)
```

### When implemented

```bash
go test ./... -v -count=1
```

---

## Detailed Scenarios

### Scenario 1: Client connection

```go
client, err := spark.NewClient(ctx, "spark-connect:15002")
// defer client.Close()
```

### Scenario 2: SQL execution

```go
result, err := client.ExecuteSQL(ctx, "SELECT 1")
```

### Scenario 3: Smoke tests

```bash
go test ./smoke/... -v
```

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | No .go files | 🔴 HIGH |
| 2 | go test fails | 🔴 HIGH |
| 3 | Spark Connect Go reference 404 | 🟡 MEDIUM |

---

## Sign-off

- [ ] go.mod valid
- [ ] Client library implemented
- [ ] Smoke tests pass
- [ ] CI runs go test

---

**Human tester:** Complete UAT before F17 deployment.
