# Multi-Environment Setup

## Overview

Spark K8s Constructor поддерживает multiple environments (dev/staging/prod) с изолированными конфигурациями и secrets.

## Architecture

```
charts/spark-4.1/
  environments/
    dev/     → Development (minimal resources, debug enabled)
    staging/ → Pre-production testing (moderate resources)
    prod/    → Production (maximum resources, HA, security)
  templates/secrets/
    external-secrets.yaml  → AWS/GCP/Azure/IBM Secrets Manager
    sealed-secrets.yaml    → Git-native encryption
    vault-secrets.yaml     → HashiCorp Vault
```

## Quick Start

### 1. Development Environment

```bash
# Deploy to dev
helm install spark-dev charts/spark-4.1 \
  -f charts/spark-4.1/environments/dev/values.yaml \
  -n spark-dev --create-namespace

# Verify
kubectl get pods -n spark-dev
kubectl port-forward -n spark-dev svc/jupyter 8888:8888
```

**Dev Configuration:**
- 1 replica, 2-4Gi memory, 1-2 CPU
- Dynamic allocation: 0-5 executors
- Debug logging enabled
- No security restrictions

### 2. Staging Environment

```bash
# Deploy to staging
helm install spark-staging charts/spark-4.1 \
  -f charts/spark-4.1/environments/staging/values.yaml \
  -n spark-staging --create-namespace
```

**Staging Configuration:**
- 2 replicas, 4-8Gi memory, 2-4 CPU
- Dynamic allocation: 1-20 executors
- Production-like configuration
- Security enabled (test mode)

### 3. Production Environment

```bash
# Deploy to production (MANUAL APPROVAL REQUIRED)
helm install spark-prod charts/spark-4.1 \
  -f charts/spark-4.1/environments/prod/values.yaml \
  -n spark-prod --create-namespace
```

**Production Configuration:**
- 3 replicas, 8-16Gi memory, 4-8 CPU
- Dynamic allocation: 2-50 executors
- Pod Disruption Budget (minAvailable: 2)
- External secrets REQUIRED
- Network policies enabled
- High availability configured

## Secret Management

### Option 1: External Secrets Operator (AWS, GCP, Azure, IBM)

```yaml
# values.yaml
secrets:
  externalSecrets:
    enabled: true
    provider: "aws"  # or "gcp", "azure", "ibm"
    region: "us-east-1"
    prefix: "prod"
```

**AWS Setup:**
```bash
# Create IAM role for external-secrets
kubectl create sa -n spark-prod spark-external-secrets-sa
kubectl annotate sa -n spark-prod spark-external-secrets-sa \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/spark-secrets-role

# Store secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name prod/s3-credentials \
  --secret-string '{"access_key":"...","secret_key":"..."}'
```

### Option 2: SealedSecrets (Git-Native)

```yaml
# values.yaml
secrets:
  sealedSecrets:
    enabled: true
```

**Encrypt secrets:**
```bash
# Create secret manifest
cat > s3-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: s3-credentials
type: Opaque
data:
  access-key: $(echo -n "YOUR_ACCESS_KEY" | base64)
  secret-key: $(echo -n "YOUR_SECRET_KEY" | base64)
EOF

# Encrypt with kubeseal
kubeseal -f s3-credentials.yaml -w charts/spark-4.1/environments/prod/sealed-secrets.yaml

# Commit encrypted secret to git
git add charts/spark-4.1/environments/prod/sealed-secrets.yaml
git commit -m "Add sealed secrets for production"
```

### Option 3: HashiCorp Vault

```yaml
# values.yaml
secrets:
  vault:
    enabled: true
    address: "https://vault.example.com:8200"
    role: "spark-connect"
```

**Vault setup:**
```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Create role for Spark
vault write auth/kubernetes/role/spark-connect \
  bound_service_account_names=spark-vault-auth \
  bound_service_account_namespaces=spark-prod \
  policies=spark-policy \
  ttl=24h
```

## Promotion Workflow

### Dev → Staging (Automatic)

```bash
# Trigger promotion workflow
gh workflow run promote-to-staging.yml -f commit_sha=$(git rev-parse HEAD)

# Or push to dev branch
git checkout dev
# Make changes...
git push origin dev
```

**Workflow:**
1. Validate dev configuration
2. Validate staging configuration
3. Create staging branch
4. Copy dev values to staging
5. Update staging-specific settings
6. Commit and push

### Staging → Production (Manual Approval Required)

```bash
# Trigger promotion workflow (requires approval)
gh workflow run promote-to-prod.yml -f commit_sha=$(git_staging_sha)
```

**Workflow:**
1. Validate staging configuration
2. Validate production configuration
3. **Wait for manual approval**
4. Create production promotion branch
5. Copy staging values to production
6. Update production-specific settings
7. Create pull request to main
8. **Manual review required**
9. Merge to main
10. Deploy to production

## Validation

### Pre-Deployment Validation

```bash
# Lint chart
helm lint charts/spark-4.1 \
  -f charts/spark-4.1/environments/dev/values.yaml

# Template render
helm template test charts/spark-4.1 \
  -f charts/spark-4.1/environments/dev/values.yaml \
  --debug

# Dry-run
helm upgrade --install spark-dev charts/spark-4.1 \
  -f charts/spark-4.1/environments/dev/values.yaml \
  -n spark-dev --dry-run --debug
```

### Post-Deployment Validation

```bash
# Check pods
kubectl get pods -n spark-dev

# Check services
kubectl get svc -n spark-dev

# Check logs
kubectl logs -n spark-dev deploy/spark-connect

# Test Spark Connect
kubectl exec -n spark-dev deploy/spark-connect -- \
  spark-submit --version
```

## Troubleshooting

### Issue: External Secrets Not Syncing

**Symptoms:**
- ExternalSecret shows `SecretNotFound`
- S3 credentials secret not created

**Diagnosis:**
```bash
# Check ExternalSecret status
kubectl get externalsecret s3-credentials -n spark-prod -o yaml

# Check SecretStore
kubectl get secretstore spark-secret-store -n spark-prod -o yaml

# Check controller logs
kubectl logs -n external-secrets deploy/external-secrets-operator
```

**Fix:**
1. Verify secret exists in external secret manager
2. Check IAM permissions for service account
3. Verify correct prefix/secret name

### Issue: Promotion Workflow Fails

**Symptoms:**
- Workflow fails at validation step
- PR not created

**Diagnosis:**
```bash
# Check workflow logs
gh run view --log

# Validate locally
helm lint charts/spark-4.1 \
  -f charts/spark-4.1/environments/prod/values.yaml
```

**Fix:**
1. Fix validation errors
2. Re-run workflow
3. Manual promotion if workflow fails

### Issue: Production Resources Insufficient

**Symptoms:**
- Pods in Pending state
- Insufficient memory/CPU

**Diagnosis:**
```bash
# Check pod status
kubectl describe pod -n spark-prod <pod-name>

# Check node resources
kubectl describe nodes
```

**Fix:**
1. Increase node capacity
2. Adjust resource requests/limits
3. Enable cluster autoscaler

## Best Practices

1. **Always validate before deploying**
   ```bash
   helm lint && helm template --debug
   ```

2. **Never commit secrets to git**
   - Use External Secrets Operator
   - Or SealedSecrets for git-native encryption

3. **Test in staging before production**
   - Staging should mirror production configuration
   - Run full E2E tests

4. **Use manual approval for production**
   - Never auto-promote to production
   - Require code review

5. **Monitor environment drift**
   - GitOps ensures desired state
   - Regular audits of deployed resources

## References

- External Secrets Operator: https://external-secrets.io/
- SealedSecrets: https://github.com/bitnami-labs/sealed-secrets
- Vault: https://www.vaultproject.io/
- Helm Best Practices: https://helm.sh/docs/chart_best_practices/
