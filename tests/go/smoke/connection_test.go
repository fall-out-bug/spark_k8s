// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Connection Smoke Tests

package smoke

import (
	"context"
	"fmt"
	"net"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	spark "github.com/fall-out-bug/spark_k8s/tests/go/client"
)

// skipIfServerUnavailable skips test if Spark Connect server is not running
func skipIfServerUnavailable(t *testing.T) {
	t.Helper()
	address := fmt.Sprintf("%s:%s",
		getEnv("SPARK_CONNECT_HOST", "localhost"),
		getEnv("SPARK_CONNECT_PORT", "15002"),
	)
	conn, err := net.DialTimeout("tcp", address, 1*time.Second)
	if err != nil {
		t.Skip("Spark Connect server not available - skipping integration test")
	}
	conn.Close()
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEndpoint() string {
	host := getEnv("SPARK_CONNECT_HOST", "localhost")
	port := getEnv("SPARK_CONNECT_PORT", "15002")
	return fmt.Sprintf("%s:%s", host, port)
}

// === Connection Tests ===

func TestConnection_Spark357(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	endpoint := getEndpoint()
	client, err := spark.NewClient(ctx, endpoint)
	require.NoError(t, err, "Failed to connect to Spark Connect")
	defer client.Close()

	// Create session
	session, err := client.CreateSession(ctx)
	require.NoError(t, err, "Failed to create session")
	defer session.Close(ctx)

	// Verify session ID
	assert.NotEmpty(t, session.ID(), "Session ID should not be empty")
}

func TestConnection_Spark411(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	defer session.Close(ctx)

	assert.NotEmpty(t, session.ID())
}

func TestConnectionLifecycle(t *testing.T) {
	skipIfServerUnavailable(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	client, err := spark.NewClient(ctx, getEndpoint())
	require.NoError(t, err)
	defer client.Close()

	// Test multiple sessions
	session1, err := client.CreateSession(ctx)
	require.NoError(t, err)
	assert.NotEmpty(t, session1.ID())

	session2, err := client.CreateSession(ctx)
	require.NoError(t, err)
	assert.NotEmpty(t, session2.ID())

	// Sessions should have different IDs
	assert.NotEqual(t, session1.ID(), session2.ID())

	// Close first session
	err = session1.Close(ctx)
	require.NoError(t, err)

	// Second session should still work
	df, err := session2.SQL(ctx, "SELECT 1")
	require.NoError(t, err)
	assert.NotNil(t, df)
}
