// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E JOIN Tests

package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

func TestE2E_JoinWithFilter(t *testing.T) {
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
			t1.passenger_count,
			COUNT(*) as trip_count
		FROM nyc_taxi t1
		INNER JOIN (
			SELECT passenger_count
			FROM nyc_taxi
			GROUP BY passenger_count
			LIMIT 5
		) t2 ON t1.passenger_count = t2.passenger_count
		GROUP BY t1.passenger_count
		ORDER BY t1.passenger_count
	`)
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	assert.NotNil(t, rows)
}
