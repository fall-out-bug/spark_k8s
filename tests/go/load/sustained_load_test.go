// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Sustained Load Tests

package load

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// TestLoad_SustainedQueryRate_358 tests sustained load at 1 qps
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

	metrics := runSustainedLoad(ctx, t, session, 2*time.Minute, 1*time.Second)

	t.Logf("Sustained load test:")
	t.Logf("  Duration: %v", metrics.Duration)
	t.Logf("  Queries: %d total, %d success, %d failed",
		metrics.QueriesTotal, metrics.QueriesSuccess, metrics.QueriesFailed)
	t.Logf("  Throughput: %.2f qps", metrics.ThroughputQPS)

	// Assertions
	assert.Equal(t, 0, metrics.QueriesFailed, "Should have no failed queries")
	assert.Greater(t, metrics.QueriesSuccess, 0, "Should have successful queries")
}
