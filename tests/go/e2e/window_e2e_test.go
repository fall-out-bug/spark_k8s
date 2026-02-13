// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Window Function Tests

package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

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
