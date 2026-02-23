# WS-CI-03: Security Fixes and Auto-Rollback

## Summary
Fix hardcoded credentials in security-scan.yml and add auto-rollback to deploy workflows.

## Scope
- Remove hardcoded MinIO credentials
- Add auto-rollback on smoke test failure
- Add retry logic for flaky operations

## Acceptance Criteria
- [ ] Hardcoded credentials removed from all workflows
- [ ] MINIO_ACCESS_KEY, MINIO_SECRET_KEY referenced from secrets
- [ ] Auto-rollback added to spark-job-deploy.yml
- [ ] Retry logic (nick-fields/retry@v3) added for E2E tests
- [ ] Slack alerting on rollback (optional)

## Technical Design

### Security Fix
```yaml
# BEFORE (security-scan.yml)
helm install minio minio/minio \
  --set accessKey=minioadmin,secretKey=minioadmin

# AFTER
helm install minio minio/minio \
  --set accessKey=${{ secrets.MINIO_ACCESS_KEY }} \
  --set secretKey=${{ secrets.MINIO_SECRET_KEY }}
```

### Auto-Rollback
```yaml
# spark-job-deploy.yml
- name: Run smoke tests
  run: ./scripts/cicd/smoke-test-job.sh --environment ${{ inputs.environment }}

- name: Rollback on failure
  if: failure()
  run: |
    ./scripts/cicd/rollback-job.sh \
      --environment ${{ inputs.environment }} \
      --previous \
      --wait

    # Alert team
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text": "🚨 Auto-rollback triggered in ${{ inputs.environment }}"}'
```

### Retry Logic
```yaml
- name: Run E2E tests with retry
  uses: nick-fields/retry@v3
  with:
    timeout_minutes: 45
    max_attempts: 3
    retry_wait_seconds: 60
    command: pytest tests/e2e/ -v --tb=short
```

## Files to Modify
- `.github/workflows/security-scan.yml`
- `.github/workflows/spark-job-deploy.yml`
- `.github/workflows/e2e-tests.yml`
- `.github/workflows/promote-to-prod.yml`
- `.github/workflows/promote-to-staging.yml`

## Definition of Done
- No hardcoded secrets in repository
- Auto-rollback tested manually
- Retry logic verified with flaky test

## Estimated Effort
Small (clear changes)

## Blocked By
None

## Blocks
None
