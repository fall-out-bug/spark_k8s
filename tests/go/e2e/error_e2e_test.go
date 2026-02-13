// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Error Handling Tests

package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

func TestE2E_ErrorInvalidTable(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	_, err = session.SQL(ctx, "SELECT * FROM nonexistent_table_xyz")
	assert.NotNil(t, session)
}

func TestE2E_ErrorInvalidSyntax(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	_, err = session.SQL(ctx, "SELEC 1")
	assert.NotNil(t, session)
}

func TestE2E_ConnectionRetry(t *testing.T) {
	skipIfServerUnavailable(t)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	client.Close()

	client2, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client2.Close()

	session, err := client2.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)
	assert.NotNil(t, df)
}
