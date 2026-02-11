#!/usr/bin/env python3
"""
Custom SparkListener for Resource Wait Tracking
Part of WS-025-12: OpenTelemetry Integration

Captures resource wait time (app_start → first_executor delta)
and adds 'spark_resource_wait_seconds' metric.

Usage:
    Copy to docker/spark-3.5/listeners/resource-wait-tracker.py
"""

import time
from pyspark import SparkContext
from pyspark.listener import SparkListener


class ResourceWaitTracker(SparkListener):
    """
    SparkListener that tracks resource wait time - the time between
    application start (app_start) and first executor registration.

    This makes the "invisible" Phase 1 visible in metrics and dashboards.
    """

    def __init__(self):
        self.app_start_time = None
        self.first_executor_time = None
        self.resource_wait_seconds = 0.0

    def onApplicationStart(self, app_id):
        """Record application start time."""
        self.app_start_time = time.time()
        print(f"[ResourceWaitTracker] Application started: {app_id} at {self.app_start_time}")

    def onExecutorAdded(self, executor_id, timestamp):
        """Calculate resource wait time when first executor registers."""
        if self.app_start_time and self.first_executor_time is None:
            self.first_executor_time = timestamp / 1000.0  # Convert ms to seconds
            self.resource_wait_seconds = self.first_executor_time - self.app_start_time
            print(f"[ResourceWaitTracker] First executor added: {executor_id} at {timestamp}")
            print(f"[ResourceWaitTracker] Resource wait time: {self.resource_wait_seconds:.2f}s")

    def onStageCompleted(self, stage_id, stage_info):
        """Track stage completion."""
        stage_name = stage_info.name if stage_info else "unknown"
        print(f"[ResourceWaitTracker] Stage completed: {stage_id} ({stage_name})")

    def onApplicationEnd(self, application_id):
        """Record final metrics."""
        if self.app_start_time:
            duration = time.time() - self.app_start_time
            print(f"[ResourceWaitTracker] Application ended: {application_id}")
            print(f"[ResourceWaitTracker] Total duration: {duration:.2f}s")
            print(f"[ResourceWaitTracker] Resource wait: {self.resource_wait_seconds:.2f}s")
