// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Client

package spark

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// Client represents a Spark Connect client
type Client struct {
	conn      *grpc.ClientConn
	clientID  string
	sessionID string
	timeout   time.Duration
}

// ClientOption configures a Spark Connect client
type ClientOption func(*Client)

// WithTimeout sets request timeout
func WithTimeout(timeout time.Duration) ClientOption {
	return func(c *Client) {
		c.timeout = timeout
	}
}

// WithUserID sets the user ID for the session
func WithUserID(userID string) ClientOption {
	return func(c *Client) {
		c.clientID = userID
	}
}

// NewClient creates a new Spark Connect client
func NewClient(ctx context.Context, endpoint string, opts ...ClientOption) (*Client, error) {
	// Validate endpoint format (host:port)
	if endpoint == "" {
		return nil, fmt.Errorf("endpoint cannot be empty")
	}

	client := &Client{
		clientID: "go-client",
		timeout:  30 * time.Second,
	}

	// Apply options
	for _, opt := range opts {
		opt(client)
	}

	// Create gRPC connection (lazy - established on first RPC)
	creds := credentials.NewTLS(&tls.Config{
		InsecureSkipVerify: true, // For development
	})

	conn, err := grpc.DialContext(ctx, endpoint,
		grpc.WithTransportCredentials(creds),
		// No WithBlock() - connection established lazily on first request
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Spark Connect: %w", err)
	}

	client.conn = conn

	return client, nil
}

// Close closes client connection
func (c *Client) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}
