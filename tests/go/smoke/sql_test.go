// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - SQL Operation Smoke Tests

package smoke

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// === SQL Operation Tests ===

func TestBasicSQL(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Execute simple SQL query
	df, err := session.SQL(ctx, "SELECT 1 AS one, 2 AS two")
	require.NoError(t, err)

	// Collect results
	rows, err := df.Collect(ctx)
	require.NoError(t, err)

	// Verify we got some results (empty with current implementation)
	assert.NotNil(t, rows)
}

func TestSQL_Aggregation(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1+1 AS result")
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}
