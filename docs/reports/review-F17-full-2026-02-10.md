# F17 Review Report

**Feature:** F17 — Spark Connect Go Client  
**Review Date:** 2026-02-10  
**Reviewer:** Cursor Composer  

---

## Executive Summary

**VERDICT: ❌ CHANGES REQUESTED**

Feature not implemented. Skeleton exists (tests/go/go.mod, client/, smoke/, e2e/, load/ with READMEs). No Go code. Spec/design gaps must be resolved before implementation.

---

## 1. Workstreams Review

### Deliverables Status

| WS ID | Title | Expected | Exists | Status |
|-------|-------|----------|--------|--------|
| 00-017-01 | Go client library | connect.go, gRPC, SQL, Session | ❌ No .go files | Not started |
| 00-017-02 | Go smoke tests | 12 scenarios | ❌ No tests | Not started |
| 00-017-03 | Go E2E tests | 16 scenarios | ❌ No tests | Not started |
| 00-017-04 | Go load tests | 8 scenarios | ❌ No tests | Not started |

### Skeleton (Partial)

| Item | Exists |
|------|--------|
| tests/go/go.mod | ✅ (module: github.com/fall-out-bug/spark_k8s/tests/go) |
| tests/go/client/ | ✅ (README only) |
| tests/go/smoke/ | ✅ (README only) |
| tests/go/e2e/ | ✅ (README only) |
| tests/go/load/ | ✅ (README only) |
| Any *.go file | ❌ |


---

## 2. Spec & Design Gaps (Nedodelki)

### 2.1 Apache Spark Connect Go Client — 404

**Reference:** `https://github.com/apache/spark/blob/master/connect/client/go/README.md` returns 404.

**Impact:** Unclear whether official Spark Connect Go client exists or whether we need to build from gRPC protobuf.

**Action:** Verify current Spark Connect Go/Proto source before WS-017-01.

### 2.2 Import Paths in WS Docs

**00-017-02/03/04:** Use `spark "github.com/fall-out-bug/spark_k8s/tests/go/client"` — matches go.mod. ✅ Resolved.

**00-017-01:** Code template uses `google.golang.org/grpc`; no proto import. Proto definitions TBD.

### 2.3 API Mismatches in 00-017-01 Template

- `CreateServerSideSession` vs feature spec `CreateSession`
- `connect.Plan_Relation` vs `connect.Plan_Sql` — structure may differ from actual Spark Connect proto
- `Row.values` type: `*connect.Expression_Literal` vs `[]interface{}`

**Action:** Align WS-017-01 template with actual Spark Connect gRPC/proto before coding.

### 2.4 CI Integration

No `.github/workflows` or Makefile targets for `go test`. Feature spec mentions `go test` but no CI.

**Action:** Add Go test step to CI (after WS-017-02).

### 2.5 F11 Dependency

INDEX: WS-017-01 depends on F06, F11. F11 (Docker Final Images) is completed per INDEX. ✅ Unblocked.

---

## 3. Acceptance Criteria Verification

### WS-00-017-01: Go client library

| AC | Status |
|----|--------|
| AC1: Go client library создан | ❌ |
| AC2–AC6: gRPC, SQL, DataFrame, Session, Error handling | ❌ |

**Goal Achieved:** ❌ NO

### WS-00-017-02: Go smoke tests

| AC | Status |
|----|--------|
| AC1: 12 smoke scenarios | ❌ |
| AC2–AC6: Connection, SQL, DataFrame, Error, All pass | ❌ |

**Goal Achieved:** ❌ NO

### WS-00-017-03: Go E2E tests

**Goal Achieved:** ❌ NO

### WS-00-017-04: Go load tests

**Goal Achieved:** ❌ NO

---

## 4. Blockers & Nedodelki

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | CRITICAL | No implementation | Execute WS-017-01..04 |
| 2 | HIGH | Spark Connect Go source 404 | Verify proto/gRPC source before coding |
| 3 | HIGH | API template may not match proto | Align WS-017-01 with actual Spark Connect API |
| 4 | MEDIUM | No CI for go test | Add Go test step to workflows |
| 5 | LOW | client/README notes "awaiting official client" | Clarify build-from-proto vs wait |

---

## 5. Next Steps

1. Verify Spark Connect Go/Proto source (Apache Spark repo).
2. Align WS-017-01 template with actual API.
3. Implement WS-017-01 (Go client library).
4. Implement WS-017-02, 03, 04 (tests).
5. Add Go test step to CI.
6. Re-run `/review F17` after implementation.

---

## 6. Monitoring Checklist

- [ ] Metrics collected (N/A)
- [ ] Alerts configured (N/A)
- [ ] Dashboard updated (N/A)

---

**Report ID:** review-F17-full-2026-02-10
