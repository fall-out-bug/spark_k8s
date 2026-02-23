# Idea: Data Engineering Patterns (F30)

**Date:** 2026-02-13
**Source:** repo-audit-2026-02-13.md (Data Engineering Practices, items DE-1..DE-8)
**Priority:** Medium

## Problem

Missing essential data engineering patterns and integrations:
- No data lineage (OpenLineage/Marquez)
- No data quality framework integration (Great Expectations / Deequ)
- Airflow DAGs are examples, not production-ready templates
- No Structured Streaming examples
- No Iceberg best practices documentation (partitioning, compaction, snapshot expiry)
- Observability charts not integrated with main chart as dependencies

## Solution

Add OpenLineage integration, production DAG templates, DQ framework, Iceberg guide.

## Users Affected

- Data Engineer (lineage, quality, production patterns)
- Data Scientist (Iceberg best practices)
- Platform Engineer (observability integration)

## Success Metrics

- OpenLineage preset functional
- Production DAG templates with retry, SLA, idempotency
- Iceberg best practices documented
