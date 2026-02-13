// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Sustained Load Tests

package load

import (
	"context"
	"fmt"
	"net"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// skipIfServerUnavailable skips test if Spark Connect server is not running
func skipIfServerUnavailable(t *testing.T) {
	t.Helper()
	address := fmt.Sprintf("%s:%s",
		getEnv("SPARK_CONNECT_HOST", "localhost"),
		getEnv("SPARK_CONNECT_PORT", "15002"),
	)
	conn, err := net.DialTimeout("tcp", address, 1*time.Second)
	if err != nil {
		t.Skip("Spark Connect server not available - skipping load test")
	}
	conn.Close()
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEndpoint() string {
	host := getEnv("SPARK_CONNECT_HOST", "localhost")
	port := getEnv("SPARK_CONNECT_PORT", "15002")
	return fmt.Sprintf("%s:%s", host, port)
}

func TestLoad_SustainedQueryRate_358(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Run sustained load test for 1 minute
	metrics := runSustainedLoad(ctx, t, session, 1*time.Minute, 1*time.Second)

	t.Logf("Sustained load test completed:")
	t.Logf("  Queries: %d success, %d failed",
		metrics.QueriesSuccess, metrics.QueriesFailed)

	assert.Equal(t, 0, metrics.QueriesFailed, "Should have no failed queries")
	assert.Greater(t, metrics.QueriesSuccess, 0, "Should have successful queries")
}

func TestLoad_SustainedQueryRate_411(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	metrics := runSustainedLoad(ctx, t, session, 30*time.Second, 500*time.Millisecond)

	t.Logf("Quick sustained load test (4.1.1): %d queries in %v",
		metrics.QueriesSuccess, metrics.Duration)
	assert.Equal(t, 0, metrics.QueriesFailed)
}

// runSustainedLoad executes queries at specified interval
func runSustainedLoad(ctx context.Context, t *testing.T, session *spark.Session, duration, interval time.Duration) *LoadTestMetrics {
	query := `
		SELECT
			passenger_count,
			COUNT(*) as trip_count,
			AVG(fare_amount) as avg_fare
		FROM nyc_taxi
		WHERE passenger_count > 0
		GROUP BY passenger_count
		ORDER BY passenger_count
		LIMIT 10
	`
	return runSustainedLoadWithQuery(ctx, t, session, duration, interval, query)
}

// runSustainedLoadWithQuery executes custom query at interval
func runSustainedLoadWithQuery(ctx context.Context, t *testing.T, session *spark.Session, duration, interval time.Duration, query string) *LoadTestMetrics {
	startTime := time.Now()
	endTime := startTime.Add(duration)

	metrics := &LoadTestMetrics{
		QueriesTotal:   0,
		QueriesSuccess: 0,
		QueriesFailed:  0,
	}

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
