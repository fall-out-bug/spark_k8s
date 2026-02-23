// SPDX-License-Identifier: Apache-2.0
// Spark Connect DataFrame Tests

package spark

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// AC4: DataFrame collect работает
func TestDataFrameCollect(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1 AS num, 'hello' AS str")
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	require.NotNil(t, rows)
}

// AC4: DataFrame show
func TestDataFrameShow(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)

	err = df.Show(ctx)
	assert.NoError(t, err)
}

// AC4: DataFrame count
func TestDataFrameCount(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)

	count, err := df.Count(ctx)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count, int64(0))
}
