// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Aggregation Load Tests

package load

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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
			AVG(fare_amount) as avg_fare,
			STDDEV(fare_amount) as stddev_fare
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
