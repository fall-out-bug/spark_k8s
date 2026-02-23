# Idea: CI/CD Hardening (F29)

**Date:** 2026-02-13
**Source:** repo-audit-2026-02-13.md (DevOps Practices, items DO-2..DO-10)
**Priority:** High

## Problem

CI/CD workflows have bugs and missing best practices:
- security-scan.yml: typo `ubuntu-litted`, sarif filename mismatch
- 4 workflows use outdated actions/checkout@v3 (should be v4)
- No chart release pipeline (chart-releaser / OCI registry)
- No Dependabot/Renovate for dependency updates
- No CODEOWNERS file
- No `.dockerignore` files
- Docker images not pinned by SHA digest

## Solution

Fix bugs, modernize action versions, add chart-releaser, Dependabot, CODEOWNERS.

## Users Affected

- Maintainers (reliable CI, automated dependency updates)
- DevOps (reproducible builds with pinned images)

## Success Metrics

- 0 CI bugs
- All actions on latest versions
- Chart published to OCI registry
- Dependabot PRs created automatically
