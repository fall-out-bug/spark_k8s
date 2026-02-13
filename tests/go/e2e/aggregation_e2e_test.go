// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Aggregation Tests

package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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

	df, err := session.SQL(ctx, `
		SELECT COUNT(*) as total_rows
		FROM nyc_taxi
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}

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
