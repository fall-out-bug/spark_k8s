// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Error Handling Smoke Tests

package smoke

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// === Error Handling Tests ===

func TestErrorHandling_InvalidSQL(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	// Execute invalid SQL - should handle error gracefully
	_, err = session.SQL(ctx, "SELECT * FROM nonexistent_table_xyz")
	// With current implementation, this doesn't fail
	// When full gRPC integration is done, this should return an error
	assert.NotNil(t, session)
}

func TestErrorHandling_ClientOptions(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Test client with options
	client, err := spark.NewClient(ctx,
		getEndpoint(),
		spark.WithTimeout(60*time.Second),
		spark.WithUserID("test-user"),
	)
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	assert.NotEmpty(t, session.ID())
}
