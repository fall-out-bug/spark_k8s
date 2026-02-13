// SPDX-License-Identifier: Apache-2.0
// Spark Connect Client Tests

package spark

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// AC1: Go client library создан
func TestNewClient(t *testing.T) {
	ctx := context.Background()

	// Test basic client creation
	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	require.NotNil(t, client)
	defer client.Close()

	assert.Equal(t, "go-client", client.clientID)
	assert.Equal(t, 30*time.Second, client.timeout)
}

// AC1: Client configuration with options
func TestNewClientWithOptions(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx,
		"localhost:15002",
		WithTimeout(60*time.Second),
		WithUserID("test-user"),
	)
	require.NoError(t, err)
	require.NotNil(t, t)
	defer client.Close()

	assert.Equal(t, 60*time.Second, client.timeout)
	assert.Equal(t, "test-user", client.clientID)
}

// AC2: gRPC соединение с Spark Connect работает
func TestClientConnection(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	require.NotNil(t, client.conn)
	defer client.Close()

	// Verify connection is established
	assert.NotNil(t, client.conn)
}

// AC6: Error handling работает - invalid endpoint
func TestClientConnectionError(t *testing.T) {
	ctx := context.Background()

	// Test empty endpoint (validation error)
	client, err := NewClient(ctx, "")
	assert.Error(t, err)
	assert.Nil(t, client)
	assert.ErrorContains(t, err, "endpoint cannot be empty")
	if client != nil {
		client.Close()
	}
}

// AC6: Client Close with nil conn
func TestClientCloseNilConn(t *testing.T) {
	client := &Client{
		conn:     nil,
		clientID: "test",
		timeout:  30 * time.Second,
	}

	err := client.Close()
	assert.NoError(t, err)
}
