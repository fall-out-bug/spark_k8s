# Security Hardening Guide

## Overview

Этот guide описывает security measures для Spark K8s Constructor deployment в production.

## Network Policies

### Default-Deny Policy

По умолчанию весь ingress/egress трафик блокируется. Явные allow rules добавляются для каждого компонента.

```yaml
# Enable network policies
security:
  networkPolicies:
    enabled: true
```

**Политики создаются автоматически:**
- `spark-default-deny` — блокирует весь трафик
- `spark-connect-ingress` — разрешает входящий на порт 15002
- `spark-connect-egress-*` — разрешает доступ к Kubernetes API, DNS, MinIO, PostgreSQL

### Custom Allow Rules

```yaml
# Добавить custom allow rule через values.yaml
security:
  networkPolicies:
    customRules:
      - name: allow-external-api
        podSelector:
          app: spark-connect
        egress:
          - to:
              - namespaceSelector:
                  matchLabels:
                    name: external-api
            ports:
              - protocol: TCP
                port: 443
```

## RBAC

### Minimal RBAC

Spark Connect использует minimal ServiceAccount с ограниченными правами:

```yaml
rbac:
  create: true
  serviceAccountName: "spark-41"

# Permissions (minimal):
# - pods: get, list, watch, create, delete
# - configmaps: get, create, update, delete
# - secrets: get (only read from s3-credentials)
```

### Adding Custom Permissions

```yaml
# Если нужны дополнительные права
rbac:
  customRules:
    - apiGroups: [""]
      resources: ["persistentvolumeclaims"]
      verbs: ["get", "list", "watch"]
```

## Image Vulnerability Scanning

### Trivy Integration в CI/CD

Automated сканирование всех Docker images:

```yaml
# .github/workflows/docker-build.yml
name: Build and Scan Images

on:
  push:
    branches: [main, dev, staging]
    paths:
      - 'docker/**'

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Spark image
        run: |
          docker buildx build \
            --build-arg SPARK_VERSION=4.1.0 \
            --tag spark-k8s:4.1.0 \
            --cache-from type=local,src=/tmp/.buildx-cache \
            --load \
            docker/spark-4.1/

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: spark-k8s:4.1.0
          severity: HIGH,CRITICAL
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

### Local Scanning

```bash
# Scan image locally
trivy image spark-k8s:4.1.0 --severity HIGH,CRITICAL

# Scan with custom policy
trivy image --config .trivy.yaml spark-k8s:4.1.0
```

### Trivy Policy

```yaml
# .trivy.yaml
severity:
  - HIGH
  - CRITICAL

vulnerabilities:
  ignore-unfixed: false

output:
  format: table
```

## Secrets Management

### NEVER Commit Secrets to Git

❌ **Wrong:**
```yaml
# values.yaml
s3:
  accessKey: "AKIAIOSFODNN7EXAMPLE"
  secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

✅ **Right:**
```yaml
# values.yaml
s3:
  accessKey: ""  # Filled by ExternalSecrets
  secretKey: ""  # Filled by ExternalSecrets
```

### External Secrets Operator

```bash
# AWS Secrets Manager
helm upgrade spark charts/spark-4.1 -n spark \
  --set secrets.externalSecrets.enabled=true \
  --set secrets.externalSecrets.provider=aws \
  --set secrets.externalSecrets.region=us-east-1 \
  --set secrets.externalSecrets.prefix=prod

# Verify
kubectl get externalsecret s3-credentials -n spark -o yaml
```

### SealedSecrets (Git-Native)

```bash
# Create secret
kubectl create secret docker-registry s3-credentials \
  --from-literal=access-key="YOUR_KEY" \
  --from-literal=secret-key="YOUR_SECRET"

# Encrypt
kubeseal -f <secret.yaml> -w <sealed-secret.yaml>

# Commit encrypted secret
git add <sealed-secret.yaml>
git commit -m "Add sealed secrets"
```

## Pod Security Standards

### Enforcing PSS Restricted

```yaml
# Label namespace для PSS enforcement
kubectl label namespace spark \
  pod-security.kubernetes.io/enforce=restricted
```

### Security Context

```yaml
security:
  podSecurityStandards: true
  runAsUser: 185  # Non-root user
  runAsGroup: 185
  fsGroup: 185
  readOnlyRootFilesystem: false  # Set to true for maximum security
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

## Security Checklist

### Pre-Deployment

- [ ] Network policies enabled
- [ ] External secrets configured (NOT hardcoded)
- [ ] RBAC follows least privilege
- [ ] PSS enforced
- [ ] Security context hardened

### Post-Deployment

- [ ] Verify no secrets in git: `git grep -r "AKIA\|secret_key\|password" charts/`
- [ ] Check network policies: `kubectl get networkpolicy -n spark`
- [ ] Verify RBAC: `kubectl auth can-i list pods -n spark`
- [ ] Scan images: `trivy image spark-k8s:4.1.0`

### Ongoing

- [ ] Regular security updates (Spark patches)
- [ ] Rotate secrets quarterly
- [ ] Audit access logs monthly
- [ ] Review Trivy reports weekly

## References

- Kubernetes Network Policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Trivy: https://aquasecurity.github.io/trivy/
- External Secrets Operator: https://external-secrets.io/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

**Security Status:** Template created. Follow this guide for production deployment.
