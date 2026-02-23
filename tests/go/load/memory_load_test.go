// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Memory Load Tests

package load

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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
