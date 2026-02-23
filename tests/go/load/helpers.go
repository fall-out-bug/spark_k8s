// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Load Test Helpers

package load

import (
	"context"
	"fmt"
	"net"
	"os"
	"sync"
	"testing"
	"time"

	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

func skipIfServerUnavailable(t *testing.T) {
	t.Helper()
	address := fmt.Sprintf("%s:%s",
		getEnv("SPARK_CONNECT_HOST"),
		getEnv("SPARK_CONNECT_PORT"))
	conn, err := net.DialTimeout("tcp", address, 1*time.Second)
	if err != nil {
		t.Skip("Spark Connect server not available - skipping load test")
	}
	conn.Close()
}

func getEnv(key string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return ""
}

func getEndpoint() string {
	host := getEnv("SPARK_CONNECT_HOST")
	if host == "" {
		host = "localhost"
	}
	port := getEnv("SPARK_CONNECT_PORT")
	if port == "" {
		port = "15002"
	}
	return fmt.Sprintf("%s:%s", host, port)
}

func runSustainedLoad(ctx context.Context, t *testing.T, session *spark.Session, duration, interval time.Duration) *LoadTestMetrics {
	return runSustainedLoadWithQuery(ctx, t, session, duration, interval, "SELECT passenger_count, COUNT(*) as trip_count, AVG(fare_amount) as avg_fare FROM nyc_taxi WHERE passenger_count > 0 GROUP BY passenger_count ORDER BY passenger_count LIMIT 10")
}

func runSustainedLoadWithQuery(ctx context.Context, t *testing.T, session *spark.Session, duration, interval time.Duration, query string) *LoadTestMetrics {
	startTime := time.Now()
	endTime := startTime.Add(duration)
	metrics := &LoadTestMetrics{QueriesTotal: 0, QueriesSuccess: 0, QueriesFailed: 0}
	var latencies []time.Duration
	var mu sync.Mutex

	for time.Now().Before(endTime) {
		queryStart := time.Now()
		df, err := session.SQL(ctx, query)
		if err != nil {
			metrics.QueriesFailed++
			metrics.QueriesTotal++
			time.Sleep(interval)
			continue
		}
		_, err = df.Collect(ctx)
		queryEnd := time.Now()
		latency := queryEnd.Sub(queryStart)

		mu.Lock()
		if err != nil {
			metrics.QueriesFailed++
		} else {
			metrics.QueriesSuccess++
			latencies = append(latencies, latency)
		}
		metrics.QueriesTotal++
		mu.Unlock()

		elapsed := time.Since(queryStart)
		if elapsed < interval {
			time.Sleep(interval - elapsed)
		}
	}
	metrics.Duration = time.Since(startTime)
	latencyMetrics := calculateLatencyMetrics(latencies)
	metrics.AvgLatency = latencyMetrics.AvgLatency
	metrics.P50Latency = latencyMetrics.P50Latency
	metrics.P95Latency = latencyMetrics.P95Latency
	metrics.P99Latency = latencyMetrics.P99Latency
	metrics.ThroughputQPS = float64(metrics.QueriesSuccess) / metrics.Duration.Seconds()
	return metrics
}
