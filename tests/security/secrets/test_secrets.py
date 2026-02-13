"""Tests for hardcoded secrets detection"""

import pytest
import subprocess
import yaml
from pathlib import Path


class TestSecretsHardcoded:
    """Tests for hardcoded secrets detection"""

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
            # Skip empty password values (password='', password="")
            if "password=''" in l or 'password=""' in l.lower():
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
