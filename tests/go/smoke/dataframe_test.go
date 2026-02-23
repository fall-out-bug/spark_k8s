// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - DataFrame Operation Smoke Tests

package smoke

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// === DataFrame Operation Tests ===

func TestDataFrame_Count(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1 AS id")
	require.NoError(t, err)

	count, err := df.Count(ctx)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count, int64(0))
}

func TestDataFrame_Show(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1 AS num")
	require.NoError(t, err)

	err = df.Show(ctx)
	assert.NoError(t, err)
}

func TestDataFrame_Collect(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1 AS col")
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}
