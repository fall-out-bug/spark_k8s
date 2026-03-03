"""
Observability smoke tests — config validation for PR gate.

Runs without K8s cluster. Validates:
- YAML configs parse
- Grafana dashboard JSON valid
- Prometheus config valid
- Key files exist

Marker: pytest -m observability
"""

import json
from pathlib import Path

import pytest
import yaml

OBSERVABILITY_DIR = Path(__file__).parent
REPO_ROOT = OBSERVABILITY_DIR.parent.parent


@pytest.mark.observability
class TestObservabilityConfigs:
    """Validate observability config files."""

    def test_prometheus_config_valid_yaml(self) -> None:
        """Prometheus config must be valid YAML."""
        config_path = OBSERVABILITY_DIR / "prometheus-demo.yaml"
        if not config_path.exists():
            pytest.skip("prometheus-demo.yaml not found")
        with open(config_path) as f:
            docs = list(yaml.safe_load_all(f))
        assert len(docs) >= 1
        configmaps = [d for d in docs if isinstance(d, dict) and d.get("kind") == "ConfigMap"]
        cm = next((c for c in configmaps if "prometheus.yml" in str(c.get("data", {}))), None)
        assert cm is not None, "Prometheus config must contain prometheus.yml"

    def test_loki_config_valid_yaml(self) -> None:
        """Loki config must be valid YAML."""
        config_path = OBSERVABILITY_DIR / "loki.yaml"
        if not config_path.exists():
            pytest.skip("loki.yaml not found")
        with open(config_path) as f:
            docs = list(yaml.safe_load_all(f))
        assert len(docs) >= 1

    def test_promtail_config_valid_yaml(self) -> None:
        """Promtail config must be valid YAML."""
        config_path = OBSERVABILITY_DIR / "promtail.yaml"
        if not config_path.exists():
            pytest.skip("promtail.yaml not found")
        with open(config_path) as f:
            docs = list(yaml.safe_load_all(f))
        assert len(docs) >= 1

    def test_grafana_dashboard_tech_lead_valid_json(self) -> None:
        """Tech Lead dashboard JSON must be valid."""
        config_path = OBSERVABILITY_DIR / "grafana-dashboard-tech-lead.yaml"
        if not config_path.exists():
            pytest.skip("grafana-dashboard-tech-lead.yaml not found")
        with open(config_path) as f:
            data = yaml.safe_load(f)
        cm_data = data.get("data", {})
        for key, val in cm_data.items():
            if key.endswith(".json"):
                json.loads(val)
                break

    def test_grafana_dashboard_logs_explorer_valid_json(self) -> None:
        """Logs Explorer dashboard JSON must be valid."""
        config_path = OBSERVABILITY_DIR / "grafana-dashboard-logs-explorer.yaml"
        if not config_path.exists():
            pytest.skip("grafana-dashboard-logs-explorer.yaml not found")
        with open(config_path) as f:
            data = yaml.safe_load(f)
        cm_data = data.get("data", {})
        for key, val in cm_data.items():
            if key.endswith(".json"):
                json.loads(val)
                break

    def test_inventory_exists(self) -> None:
        """INVENTORY.md must exist (from WS-031-01)."""
        inv_path = REPO_ROOT / "docs" / "observability" / "INVENTORY.md"
        assert inv_path.exists(), "docs/observability/INVENTORY.md must exist"

    def test_deploy_script_exists(self) -> None:
        """deploy-observability.sh must exist."""
        script_path = REPO_ROOT / "scripts" / "tests" / "minikube" / "deploy-observability.sh"
        assert script_path.exists(), "scripts/tests/minikube/deploy-observability.sh must exist"
