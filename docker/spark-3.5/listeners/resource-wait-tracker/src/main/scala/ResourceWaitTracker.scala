package org.apache.spark.scheduler

import org.apache.spark.SparkContext
import org.apache.spark.metrics.source.{Source => MetricSource}
import com.codahale.metrics.MetricRegistry

/**
 * ResourceWaitTracker SparkListener
 *
 * Tracks the time gap between application start and first executor registration.
 * This metric represents Kubernetes scheduling delay and resource wait time.
 *
 * Metric exposed: spark_resource_wait_seconds
 */
class ResourceWaitTracker extends SparkListener {
  private var appStartTime: Long = 0L
  private var firstExecutorTime: Long = 0L
  private var resourceWaitSeconds: Double = 0.0
  private val metricRegistry = new MetricRegistry()

  override def onApplicationStart(applicationStart: SparkListenerApplicationStart): Unit = {
    appStartTime = System.currentTimeMillis()
    println(s"[ResourceWaitTracker] Application started at $appStartTime")
  }

  override def onExecutorAdded(executorAdded: SparkListenerExecutorAdded): Unit = {
    // Record only the first executor time
    if (firstExecutorTime == 0L && executorAdded.executorId != "driver") {
      firstExecutorTime = executorAdded.time
      resourceWaitSeconds = (firstExecutorTime - appStartTime) / 1000.0

      println(s"[ResourceWaitTracker] First executor registered at $firstExecutorTime")
      println(s"[ResourceWaitTracker] Resource wait time: $resourceWaitSeconds seconds")

      // Register metric
      metricRegistry.gauge("spark_resource_wait_seconds", () => resourceWaitSeconds)
    }
  }

  override def onApplicationEnd(applicationEnd: SparkListenerApplicationEnd): Unit = {
    println(s"[ResourceWaitTracker] Final resource wait time: $resourceWaitSeconds seconds")
  }
}
