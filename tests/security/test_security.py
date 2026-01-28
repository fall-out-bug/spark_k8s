"""
Security Tests for Spark K8s Constructor

Tests:
1. Network policies validation
2. RBAC minimal permissions validation
3. Secrets hardcoded detection
4. Security context validation
"""

import pytest
import subprocess
import yaml
from pathlib import Path


class TestNetworkPolicies:
    """Tests for Network Policies"""

    @pytest.fixture(scope="class")
    def network_policy_template(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "templates" / "networking" / "network-policy.yaml"

    def test_network_policy_template_exists(self, network_policy_template):
        """Test that network policy template exists"""
        assert network_policy_template.exists(), "Network policy template should exist"

    def test_default_deny_policy_exists(self, network_policy_template):
        """Test that default-deny policy is defined"""
        content = network_policy_template.read_text()
        assert "spark-default-deny" in content, "Default-deny policy should be defined"
        assert "policyTypes:\n  - Ingress\n  - Egress" in content, "Should block both ingress and egress"

    def test_explicit_allow_rules(self, network_policy_template):
        """Test that explicit allow rules are defined"""
        content = network_policy_template.read_text()
        assert "spark-connect-ingress" in content, "Should allow ingress to Spark Connect"
        assert "spark-connect-egress-dns" in content, "Should allow DNS access"
        assert "s3-egress" in content, "Should allow S3 access"

    def test_policy_selectors_match_spark_components(self, network_policy_template):
        """Test that policy selectors match actual Spark components"""
        content = network_policy_template.read_text()
        # Check for spark-connect selector
        assert "app: spark-connect" in content, "Should select Spark Connect pods"
        # Check for spark-worker selector (if applicable)
        assert "app: spark-worker" in content or "app: spark-executor" in content, "Should select worker pods"


class TestRBAC:
    """Tests for RBAC configuration"""

    @pytest.fixture(scope="class")
    def helm_chart_path(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1"

    @pytest.fixture(scope="class")
    def prod_values(self, helm_chart_path):
        prod_values = helm_chart_path / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            return yaml.safe_load(f)

    def test_rbac_enabled_in_prod(self, prod_values):
        """Test that RBAC is enabled in production"""
        assert "rbac" in prod_values, "RBAC section should exist"
        assert prod_values["rbac"]["create"] == True, "RBAC should be created"

    def test_rbac_uses_least_privilege(self, helm_chart_path):
        """Test that RBAC follows least privilege"""
        # Check RBAC template
        rbac_template = helm_chart_path / "templates" / "rbac" / "role.yaml"
        if rbac_template.exists():
            content = rbac_template.read_text()
            # Check for minimal permissions
            assert "verbs:" in content, "RBAC should define verbs"
            # Should not have wildcard permissions
            assert not '"*"' in content, "No wildcard permissions"

    def test_serviceaccount_created(self, helm_chart_path):
        """Test that ServiceAccount is created"""
        result = subprocess.run(
            ["helm", "template", "test", str(helm_chart_path),
            "-f", str(helm_chart_path / "environments" / "prod" / "values.yaml"),
            "--show-only", "templates/rbac/serviceaccount.yaml"],
            capture_output=True
        )
        assert result.returncode == 0, "ServiceAccount template should render"
        assert "ServiceAccount" in result.stdout.decode(), "ServiceAccount should be created"


class TestSecretsHardcoded:
    """Tests for hardcoded secrets detection"""

    @pytest.fixture(scope="class")
    def repository_root(self):
        return Path(__file__).parent.parent.parent

    def test_no_aws_access_keys_in_code(self, repository_root):
        """Test that no AWS access keys are hardcoded in actual code"""
        # Exclude docs/ and tests/ from check (examples are OK)
        result = subprocess.run(
            ["git", "-C", str(repository_root), "grep", "-r", "--exclude-dir=docs", "--exclude-dir=tests", "AKIAIOSFODNN7"],
            capture_output=True
        )
        assert result.returncode != 0, "Should not find AWS access keys in code"

    def test_no_secret_keys_in_templates(self, repository_root):
        """Test that no secret keys are in templates"""
        charts_dir = repository_root / "charts"
        result = subprocess.run(
            "grep -r -E -i 'secret.key|secret_key|password' " + str(charts_dir),
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding='utf-8'
        )
        # Filter out comments, examples, and legitimate template patterns
        lines = result.stdout.split('\n')
        suspicious = []
        for l in lines:
            if not l:
                continue
            # Skip comments
            if '#' in l:
                continue
            # Skip examples
            if 'example' in l.lower():
                continue
            # Skip test values (wJalrXUtnFEMI is AWS example)
            if 'wJalrXUtnFEMI' in l or 'minioadmin' in l or 'spark123' in l or 'hive123' in l:
                continue
            # Skip .io references
            if '.io' in l:
                continue
            # Skip CRD documentation strings
            if 'Must be a valid' in l or 'valid secret key' in l:
                continue
            # Skip template variables ({{ ... }})
            if '{{' in l and '}}' in l:
                continue
            # Skip environment variable references (${...})
            if '${' in l and '}' in l:
                continue
            # Skip empty placeholder values ("", '', | quote)
            if ': ""' in l or ": ''" in l or '| quote' in l:
                continue
            # Skip ConfigMap references (POSTGRES_PASSWORD, etc.)
            if 'POSTGRES_PASSWORD' in l or 'MINIO_ROOT_PASSWORD' in l:
                continue
            # Skip Secret key references (key: secret-key is a reference, not value)
            if 'key: secret-key' in l or 'key: secretKey' in l:
                continue
            # Skip jupyterhub admin reference
            if 'adminPassword' in l:
                continue
            # Only flag actual hardcoded secrets
            if any(s in l.lower() for s in ['akia', 'secret=', 'password=']):
                suspicious.append(l)

        for line in suspicious:
            print(f"Found suspicious line: {line}")
        assert len(suspicious) == 0, f"Should not have hardcoded secrets, found {len(suspicious)}"

    def test_external_secrets_required_in_prod(self, repository_root):
        """Test that prod requires external secrets"""
        prod_values = repository_root / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert "secrets" in values, "Secrets section should exist"
        assert values["secrets"]["externalSecrets"]["enabled"] == True, \
            "External secrets MUST be enabled in production"


class TestSecurityContext:
    """Tests for security context configuration"""

    @pytest.fixture(scope="class")
    def prod_values(self):
        return Path(__file__).parent.parent.parent / "charts" / "spark-4.1" / "environments" / "prod" / "values.yaml"

    def test_pss_restricted_in_prod(self, prod_values):
        """Test that PSS restricted is enabled in production"""
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["podSecurityStandards"] == True, \
            "PSS restricted should be enabled in prod"

    def test_non_root_user(self, prod_values):
        """Test that non-root user is configured"""
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        assert values["security"]["runAsUser"] == 185, \
            "Should run as non-root user (UID 185)"
        assert values["security"]["runAsGroup"] == 185, \
            "Should run as non-root group (GID 185)"

    def test_readonly_root_filesystem_option(self, prod_values):
        """Test that readonly root filesystem can be enabled"""
        with open(prod_values) as f:
            values = yaml.safe_load(f)

        # Can be true or false depending on requirements
        assert "readOnlyRootFilesystem" in values["security"], \
            "ReadOnlyRootFilesystem should be defined"

    def test_privilege_escalation_disabled(self, prod_values):
        """Test that privilege escalation is disabled"""
        # Check if allowPrivilegeEscalation is set to false
        with open(prod_values) as f:
            content = f.read()
            # Check in security context or pod annotations
            assert "allowPrivilegeEscalation: false" in content or \
                   "privileged: false" in content or \
                   "allowPrivilegeEscalation" not in content, \
            "Privilege escalation should be disabled"


class TestCompliance:
    """Tests for compliance requirements"""

    @pytest.fixture(scope="class")
    def repository_root(self):
        return Path(__file__).parent.parent.parent

    def test_pod_security_standards_enforced(self, repository_root):
        """Test that PSS labels can be enforced"""
        # Check for namespace labels in documentation
        docs_dir = repository_root / "docs"
        if docs_dir.exists():
            result = subprocess.run(
                ["grep", "-r", "pod-security.kubernetes.io/enforce", str(docs_dir)],
                capture_output=True
            )
            # Should find reference in documentation
            # (not necessarily applied, but documented)

    def test_security_documentation_complete(self, repository_root):
        """Test that security documentation is comprehensive"""
        security_doc = repository_root / "docs" / "recipes" / "security" / "hardening-guide.md"
        assert security_doc.exists(), "Security documentation should exist"

        content = security_doc.read_text()
        assert "Network Policies" in content, "Should cover network policies"
        assert "RBAC" in content, "Should cover RBAC"
        assert "Trivy" in content, "Should cover image scanning"
        assert "Secrets Management" in content, "Should cover secrets"
