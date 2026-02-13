// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Complex Query Tests

package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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
