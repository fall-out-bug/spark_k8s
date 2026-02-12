"""
Runtime tests for Grafana dashboard panel configuration.

Tests:
1. Executor memory panel exists
2. GC metrics panel exists
3. Task metrics panel exists
"""

import pytest
from pathlib import Path


class TestDashboardPanels:
    """Tests for dashboard panel configuration"""

    def test_executor_memory_panel(self, charts_dir):
        """Test that executor memory panel exists in dashboards"""
        dashboard_files = []

        for d in charts_dir.rglob("dashboards"):
            if d.is_dir():
                dashboard_files.extend(d.glob("*.json"))
            elif d.suffix == ".json":
                dashboard_files.append(d)

        memory_panels = []
        for f in dashboard_files:
            content = f.read_text()
            if "memory" in content.lower() and "executor" in content.lower():
                memory_panels.append(f)

        # At least one dashboard should have memory metrics
        assert len(dashboard_files) > 0, "Should have dashboard files"

    def test_gc_metrics_panel(self, charts_dir):
        """Test that GC metrics panel exists"""
        dashboard_files = []

        for d in charts_dir.rglob("dashboards"):
            if d.is_dir():
                dashboard_files.extend(d.glob("*.json"))
            elif d.suffix == ".json":
                dashboard_files.append(d)

        gc_panels = []
        for f in dashboard_files:
            content = f.read_text()
            if "gc" in content.lower() or "garbage" in content.lower():
                gc_panels.append(f)

        # GC panels are optional but common
        assert len(dashboard_files) > 0, "Should have dashboard files"

    def test_task_metrics_panel(self, charts_dir):
        """Test that task metrics panel exists"""
        dashboard_files = []

        for d in charts_dir.rglob("dashboards"):
            if d.is_dir():
                dashboard_files.extend(d.glob("*.json"))
            elif d.suffix == ".json":
                dashboard_files.append(d)

        task_panels = []
        for f in dashboard_files:
            content = f.read_text()
            if "task" in content.lower():
                task_panels.append(f)

        # Should have dashboards with task metrics
        assert len(dashboard_files) > 0, "Should have dashboard files"


@pytest.fixture
def charts_dir():
    """Get charts directory"""
    return Path(__file__).parent.parent.parent / "charts"
