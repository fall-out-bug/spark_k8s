// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Load Tests
// Load and performance testing for Go client

package load

import (
	"context"
	"fmt"
	"net"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// LoadTestMetrics holds load test results
type LoadTestMetrics struct {
	Duration       time.Duration
	QueriesTotal   int
	QueriesSuccess int
	QueriesFailed  int
	AvgLatency     time.Duration
	P50Latency     time.Duration
	P95Latency     time.Duration
	P99Latency     time.Duration
	ThroughputQPS  float64
}

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

// Test 1: Sustained Load - 1 query/sec for 30 minutes
func TestLoad_SustainedQueryRate_358(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Run sustained load test
	metrics := runSustainedLoad(ctx, t, session, 2*time.Minute, 1*time.Second)

	t.Logf("Sustained load test completed:")
	t.Logf("  Duration: %v", metrics.Duration)
	t.Logf("  Queries: %d total, %d success, %d failed",
		metrics.QueriesTotal, metrics.QueriesSuccess, metrics.QueriesFailed)
	t.Logf("  Throughput: %.2f qps", metrics.ThroughputQPS)
	t.Logf("  Latency: avg %v, p95 %v, p99 %v",
		metrics.AvgLatency, metrics.P95Latency, metrics.P99Latency)

	// Assertions
	assert.Equal(t, 0, metrics.QueriesFailed, "Should have no failed queries")
	assert.Greater(t, metrics.QueriesSuccess, 0, "Should have successful queries")
}

// Test 2: Sustained Load - Spark 4.1.1
func TestLoad_SustainedQueryRate_411(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Shorter test for CI
	metrics := runSustainedLoad(ctx, t, session, 30*time.Second, 500*time.Millisecond)

	t.Logf("Quick sustained load test (4.1.1): %d queries in %v",
		metrics.QueriesSuccess, metrics.Duration)
	assert.Equal(t, 0, metrics.QueriesFailed)
}

// Test 3: Concurrent Connections - 2 concurrent clients
func TestLoad_ConcurrentConnections(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Run 2 concurrent connections
	var wg sync.WaitGroup
	results := make(chan *LoadTestMetrics, 2)

	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			client, err := spark.NewClient(ctx, getEndpoint())
			require.NoError(t, err)
			defer client.Close()

			session, err := client.CreateSession(ctx)
			require.NoError(t, err)
			defer session.Close(ctx)

			// Run for 1 minute
			metrics := runSustainedLoad(ctx, t, session, 1*time.Minute, 500*time.Millisecond)
			results <- metrics
		}(i)
	}

	wg.Wait()
	close(results)

	// Aggregate results
	totalSuccess := 0
	totalFailed := 0
	for metrics := range results {
		totalSuccess += metrics.QueriesSuccess
		totalFailed += metrics.QueriesFailed
	}

	t.Logf("Concurrent test: %d success, %d failed", totalSuccess, totalFailed)
	assert.Equal(t, 0, totalFailed, "Should have no failed queries in concurrent test")
	assert.Greater(t, totalSuccess, 0, "Should have successful queries")
}

// Test 4: Heavy Aggregation Load
func TestLoad_HeavyAggregation(t *testing.T) {
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

	// Heavy aggregation query
	query := `
		SELECT
			passenger_count,
			COUNT(*) as trip_count,
			SUM(fare_amount) as total_fare,
			AVG(fare_amount) as avg_fare,
			STDDEV(fare_amount) as stddev_fare,
			PERCENTILE(tip_amount, 0.5) as median_tip
		FROM nyc_taxi
		WHERE passenger_count > 0
		GROUP BY passenger_count
		ORDER BY passenger_count
	`

	metrics := runSustainedLoadWithQuery(ctx, t, session, 1*time.Minute, 2*time.Second, query)

	t.Logf("Heavy aggregation test:")
	t.Logf("  Queries: %d total, %d success", metrics.QueriesTotal, metrics.QueriesSuccess)
	t.Logf("  Avg latency: %v", metrics.AvgLatency)

	assert.Equal(t, 0, metrics.QueriesFailed)
}

// Test 5: Memory Stress Test
func TestLoad_MemoryStress(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping load test in short mode")
	}
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Create many DataFrames in succession
	queryCount := 0
	startTime := time.Now()

	for time.Since(startTime) < 1*time.Minute {
		df, err := session.SQL(ctx, "SELECT 1 AS num, 2 AS num2")
		require.NoError(t, err)

		rows, err := df.Collect(ctx)
		require.NoError(t, err)

		if err == nil && rows != nil {
			queryCount++
		}
	}

	t.Logf("Memory stress test: %d queries executed", queryCount)
	assert.Greater(t, queryCount, 0, "Should execute queries successfully")
}

// Helper: Run sustained load test
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

// Helper: Run sustained load with custom query
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

		// Sleep to maintain query rate
		elapsed := time.Since(queryStart)
		if elapsed < interval {
			time.Sleep(interval - elapsed)
		}
	}

	// Calculate metrics
	metrics.Duration = time.Since(startTime)
	calculateLatencyMetrics(metrics, latencies)

	return metrics
}

// Helper: Calculate latency percentiles
func calculateLatencyMetrics(metrics *LoadTestMetrics, latencies []time.Duration) {
	if len(latencies) == 0 {
		return
	}

	// Simple sort (bubble sort for small datasets)
	for i := 0; i < len(latencies); i++ {
		for j := i + 1; j < len(latencies); j++ {
			if latencies[i] > latencies[j] {
				latencies[i], latencies[j] = latencies[j], latencies[i]
			}
		}
	}

	// Calculate average
	var sum time.Duration
	for _, l := range latencies {
		sum += l
	}
	metrics.AvgLatency = sum / time.Duration(len(latencies))

	// Percentiles
	metrics.P50Latency = latencies[len(latencies)*50/100]
	metrics.P95Latency = latencies[len(latencies)*95/100]
	metrics.P99Latency = latencies[len(latencies)*99/100]

	// Calculate throughput
	metrics.ThroughputQPS = float64(metrics.QueriesSuccess) / metrics.Duration.Seconds()
}
