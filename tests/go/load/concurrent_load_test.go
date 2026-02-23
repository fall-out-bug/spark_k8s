// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Concurrent Load Tests

package load

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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
			metrics := runSustainedLoadWithQuery(ctx, t, session, 1*time.Minute, 500*time.Millisecond, query)
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
