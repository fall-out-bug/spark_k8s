// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client
// gRPC-based client for Apache Spark Connect

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

// Session represents a Spark session
type Session struct {
	client    *Client
	sessionID string
	config    map[string]string
}

// CreateSession creates a new Spark session
func (c *Client) CreateSession(ctx context.Context) (*Session, error) {
	// NOTE: Full gRPC CreateSessionRequest to be implemented in WS-017-02 (smoke tests)
	// Current implementation generates local session ID
	// Request contains UserContext with userId, userName, appName
	sessionID := fmt.Sprintf("go-session-%d", time.Now().UnixNano())

	return &Session{
		client:    c,
		sessionID: sessionID,
		config:    make(map[string]string),
	}, nil
}

// ID returns session ID
func (s *Session) ID() string {
	return s.sessionID
}

// Close closes the session
func (s *Session) Close(ctx context.Context) error {
	// NOTE: Full gRPC CloseSessionRequest to be implemented in WS-017-02
	return nil
}

// DataFrame represents a Spark DataFrame
type DataFrame struct {
	session *Session
	plan    string
}

// SQL executes a SQL query and returns a DataFrame
func (s *Session) SQL(ctx context.Context, query string) (*DataFrame, error) {
	// NOTE: Full protobuf Plan with Relation.SQL to be implemented in WS-017-03
	// Current: JSON string placeholder
	// Plan.Relation = {sql: {query: "..."}}
	plan := fmt.Sprintf(`{"relation": {"sql": {"query": "%s"}}}`, query)

	return &DataFrame{
		session: s,
		plan:    plan,
	}, nil
}

// Collect collects all rows from the DataFrame
func (df *DataFrame) Collect(ctx context.Context) ([]Row, error) {
	// Validate session
	if df == nil || df.session == nil {
		return nil, fmt.Errorf("DataFrame has no active session")
	}
	// NOTE: Full ExecutePlanRequest and Arrow parsing to be implemented in WS-017-03
	// Current: Returns empty rows
	// Response contains batches with row data in Arrow format
	return make([]Row, 0), nil
}

// Show prints first 20 rows
func (df *DataFrame) Show(ctx context.Context) error {
	// NOTE: Full Show implementation to be done in WS-017-03
	fmt.Printf("DataFrame: %s\n", df.plan)
	return nil
}

// Count returns number of rows
func (df *DataFrame) Count(ctx context.Context) (int64, error) {
	// NOTE: Full Count implementation to be done in WS-017-03
	return 0, nil
}

// Row represents a single row from Spark Connect response (Arrow format)
type Row struct {
	values map[string]interface{}
}

// String returns a string representation of row
func (r *Row) String() string {
	return fmt.Sprint(r.values)
}

// GetInt gets an int value at column name (Arrow type: int32)
func (r *Row) GetInt(col string) (int32, error) {
	val, ok := r.values[col]
	if !ok {
		return 0, fmt.Errorf("column %s not found", col)
	}
	switch v := val.(type) {
	case int32:
		return v, nil
	case int:
		return int32(v), nil
	case float64:
		return int32(v), nil
	default:
		return 0, fmt.Errorf("column %s is not an int", col)
	}
}

// GetString gets a string value at column name (Arrow type: large_string/string)
func (r *Row) GetString(col string) (string, error) {
	val, ok := r.values[col]
	if !ok {
		return "", fmt.Errorf("column %s not found", col)
	}
	if s, ok := val.(string); ok {
		return s, nil
	}
	return fmt.Sprintf("%v", val), nil
}

// GetFloat gets a float value at column name (Arrow type: float64/double)
func (r *Row) GetFloat(col string) (float64, error) {
	val, ok := r.values[col]
	if !ok {
		return 0.0, fmt.Errorf("column %s not found", col)
	}
	switch v := val.(type) {
	case float64:
		return v, nil
	case int:
		return float64(v), nil
	case int32:
		return float64(v), nil
	default:
		return 0.0, fmt.Errorf("column %s is not a float", col)
	}
}
