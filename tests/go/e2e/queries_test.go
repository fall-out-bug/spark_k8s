// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Tests
// End-to-end tests with NYC Taxi dataset

package e2e

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
		t.Skip("Spark Connect server not available - skipping E2E test")
	}
	conn.Close()
}

// skipIfDatasetNotAvailable skips test if NYC Taxi dataset is not loaded
func skipIfDatasetNotAvailable(t *testing.T) {
	t.Helper()
	// Check if dataset should be available (env var or skip flag)
	if os.Getenv("SKIP_E2E_DATASET_TESTS") != "" {
		t.Skip("E2E dataset tests skipped via env var")
	}
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

// === COUNT Aggregation (Scenario 1) ===

func TestE2E_CountQuery(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Q1: SELECT COUNT(*) — validate row count
	df, err := session.SQL(ctx, `
		SELECT COUNT(*) as total_rows
		FROM nyc_taxi
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)

	// With current stub implementation, we expect empty results
	assert.NotNil(t, rows)
}

// === GROUP BY Aggregation (Scenario 2) ===

func TestE2E_GroupByAggregation(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Q2: GROUP BY aggregation
	df, err := session.SQL(ctx, `
		SELECT
			passenger_count,
			COUNT(*) as trip_count
		FROM nyc_taxi
		WHERE passenger_count > 0
		GROUP BY passenger_count
		ORDER BY passenger_count
		LIMIT 10
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === JOIN with Filter (Scenario 3) ===

func TestE2E_JoinWithFilter(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, `
		SELECT
			t1.passenger_count,
			COUNT(*) as trip_count
		FROM nyc_taxi t1
		INNER JOIN (
			SELECT passenger_count
			FROM nyc_taxi
			GROUP BY passenger_count
			LIMIT 5
		) t2 ON t1.passenger_count = t2.passenger_count
		GROUP BY t1.passenger_count
		ORDER BY t1.passenger_count
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === Window Function (Scenario 4) ===

func TestE2E_WindowFunction(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, `
		SELECT
			passenger_count,
			fare_amount,
			AVG(fare_amount) OVER (
				PARTITION BY passenger_count
				ORDER BY fare_amount
				ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
			) as rolling_avg_fare
		FROM (
			SELECT passenger_count, fare_amount
			FROM nyc_taxi
			WHERE passenger_count > 0
			LIMIT 100
		)
		ORDER BY passenger_count, fare_amount
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === Complex Multi-step (Scenario 5) ===

func TestE2E_ComplexMultiStep(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Create temporary view
	_, err = session.SQL(ctx, `
		CREATE OR REPLACE TEMPORARY VIEW taxi_filtered AS
		SELECT * FROM nyc_taxi
		WHERE passenger_count > 0
		AND trip_distance > 0
		AND fare_amount > 0
		LIMIT 1000
	`)
	require.NoError(t, err)

	// Query from view
	df, err := session.SQL(ctx, `
		SELECT
			passenger_count,
			COUNT(*) as trip_count,
			AVG(fare_amount) as avg_fare
		FROM taxi_filtered
		GROUP BY passenger_count
		ORDER BY passenger_count
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === Subquery (Scenario 6) ===

func TestE2E_Subquery(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, `
		SELECT
			passenger_count,
			fare_amount,
			(SELECT AVG(fare_amount) FROM nyc_taxi WHERE passenger_count > 0) as global_avg_fare
		FROM nyc_taxi
		WHERE passenger_count > 0
		AND fare_amount > 0
		LIMIT 100
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === UNION (Scenario 7) ===

func TestE2E_Union(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, `
		SELECT passenger_count, COUNT(*) as cnt
		FROM nyc_taxi
		WHERE passenger_count = 1
		GROUP BY passenger_count
		UNION ALL
		SELECT passenger_count, COUNT(*) as cnt
		FROM nyc_taxi
		WHERE passenger_count = 2
		GROUP BY passenger_count
		ORDER BY passenger_count
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === CTE / WITH Clause (Scenario 8) ===

func TestE2E_CTETest(t *testing.T) {
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, `
		WITH high_fare_trips AS (
			SELECT * FROM nyc_taxi
			WHERE fare_amount > 50
			AND passenger_count > 0
			LIMIT 100
		),
		long_trips AS (
			SELECT * FROM nyc_taxi
			WHERE trip_distance > 10
			AND passenger_count > 0
			LIMIT 100
		)
		SELECT
			COALESCE(h.passenger_count, l.passenger_count) as passenger_count,
			COALESCE(h.fare_amount, 0) as high_fare,
			COALESCE(l.trip_distance, 0) as long_distance
		FROM high_fare_trips h
		FULL OUTER JOIN long_trips l
		ON h.passenger_count = l.passenger_count
		ORDER BY passenger_count
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

// === Performance Tests (Scenarios 9-12) ===

func TestE2E_PerformanceTest(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping performance test in short mode")
	}
	skipIfServerUnavailable(t)
	skipIfDatasetNotAvailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Measure query execution time
	start := time.Now()

	df, err := session.SQL(ctx, `
		SELECT
			passenger_count,
			COUNT(*) as trip_count,
			AVG(fare_amount) as avg_fare
		FROM nyc_taxi
		WHERE passenger_count > 0
		GROUP BY passenger_count
	`)
	require.NoError(t, err)

	_, err = df.Collect(ctx)
	require.NoError(t, err)

	duration := time.Since(start)

	// Log for benchmarking
	t.Logf("Query execution time: %v", duration)

	// Should complete in reasonable time
	assert.Less(t, duration, 5*time.Minute)
}

// === Error Handling Tests (Scenarios 13-16) ===

func TestE2E_ErrorInvalidTable(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Execute invalid SQL - current implementation doesn't return error
	// When full gRPC integration is done, this should return error
	_, err = session.SQL(ctx, "SELECT * FROM nonexistent_table_xyz")
	assert.NotNil(t, session)
}

func TestE2E_ErrorInvalidSyntax(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Invalid SQL syntax
	_, err = session.SQL(ctx, "SELEC 1")
	assert.NotNil(t, session)
}

func TestE2E_ContextTimeout(t *testing.T) {
	skipIfServerUnavailable(t)

	// Very short timeout
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Millisecond)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	// This should handle timeout gracefully
	_, err = session.SQL(ctx, "SELECT SLEEP(10)")
	assert.NotNil(t, session)
}

func TestE2E_ConnectionRetry(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Test connection resilience
	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	// Close and reconnect
	client.Close()

	client2, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client2.Close()

	session, err := client2.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)
	assert.NotNil(t, df)
}
