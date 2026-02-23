# Idea: Code Quality A* (F27)

**Date:** 2026-02-13
**Source:** repo-audit-2026-02-13.md (Code Quality, items CQ-1..CQ-6)
**Priority:** Medium

## Problem

Quality gate defined in `quality-gate.toml` but not enforced in practice:
- 13 test files exceed 200 LOC (up to 443 LOC)
- 3 Python scripts exceed 200 LOC (up to 395 LOC)
- No unified linter config (pyproject.toml) in repo root
- Coverage line commented out in pytest.ini
- No `.pre-commit-config.yaml` for automated checks
- No `requirements.txt` / `pyproject.toml` for dependencies

## Solution

Create pyproject.toml as single source of truth for tooling, enforce coverage, split oversized files, add pre-commit hooks.

## Users Affected

- All contributors (consistent DX)
- CI/CD (reliable quality gates)

## Success Metrics

- 0 files > 200 LOC
- Coverage ≥80% enforced
- Pre-commit catches issues before push
