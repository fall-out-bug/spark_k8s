#!/usr/bin/env python3
"""
HTML metrics calculation for test reports.

This module handles metrics calculation from aggregated test results.
"""

from typing import Dict, Any


def calculate_metrics(aggregated: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate test metrics from aggregated results.

    Args:
        aggregated: Dictionary with test results (total, passed, failed, skipped)

    Returns:
        Dictionary with calculated metrics (pass_rate, duration_minutes, status)
    """
    total = aggregated["total"]
    passed = aggregated["passed"]
    failed = aggregated["failed"]
    skipped = aggregated["skipped"]

    # Calculate pass rate
    pass_rate = (passed / total * 100) if total > 0 else 0

    # Get duration if available
    duration = aggregated.get("duration", 0)
    duration_minutes = duration / 60 if duration else 0

    # Determine overall status
    if failed == 0:
        status_color = "#d4edda"
        status_text = "PASSED"
    else:
        status_color = "#f8d7da"
        status_text = "FAILED"

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "pass_rate": pass_rate,
        "duration_minutes": duration_minutes,
        "status_color": status_color,
        "status_text": status_text,
    }
