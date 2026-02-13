// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client Tests
// TDD Red Phase: Failing tests before implementation

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

// AC5: Session management работает
func TestCreateSession(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)
	require.NotNil(t, session)

	assert.NotEmpty(t, session.ID())
	assert.NotNil(t, session.config)
}

// AC5: Session close
func TestCloseSession(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	err = session.Close(ctx)
	assert.NoError(t, err)
}

// AC3: SQL query execution работает
func TestSessionSQL(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1 AS test_column")
	require.NoError(t, err)
	require.NotNil(t, df)

	assert.NotNil(t, df.session)
	assert.NotEmpty(t, df.plan)
}

// AC4: DataFrame collect работает
func TestDataFrameCollect(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1 AS num, 'hello' AS str")
	require.NoError(t, err)

	rows, err := df.Collect(ctx)
	require.NoError(t, err)
	require.NotNil(t, rows)
}

// AC4: DataFrame show
func TestDataFrameShow(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)

	err = df.Show(ctx)
	assert.NoError(t, err)
}

// AC4: DataFrame count
func TestDataFrameCount(t *testing.T) {
	ctx := context.Background()

	client, err := NewClient(ctx, "localhost:15002")
	require.NoError(t, err)
	defer client.Close()

	session, err := client.CreateSession(ctx)
	require.NoError(t, err)

	df, err := session.SQL(ctx, "SELECT 1")
	require.NoError(t, err)

	count, err := df.Count(ctx)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count, int64(0))
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

// AC6: Error handling - SQL without session
func TestSQLWithoutSession(t *testing.T) {
	ctx := context.Background()

	// DataFrame with nil session should handle error
	df := &DataFrame{session: nil, plan: ""}
	rows, err := df.Collect(ctx)
	assert.Error(t, err)
	assert.Nil(t, rows)
}

// AC6: Row GetInt with missing column
func TestRowGetIntMissingColumn(t *testing.T) {
	row := Row{values: map[string]interface{}{}}

	val, err := row.GetInt("nonexistent")
	assert.Error(t, err)
	assert.ErrorContains(t, err, "column nonexistent not found")
	assert.Equal(t, int32(0), val)
}

// AC6: Row GetString with wrong type
func TestRowGetStringWrongType(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"num": 123,
	}}

	val, err := row.GetString("num")
	// Should return string representation, not error
	assert.NoError(t, err)
	assert.Equal(t, "123", val)
}

// AC6: Row GetFloat with wrong type
func TestRowGetFloatWrongType(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"num": int32(42),
	}}

	val, err := row.GetFloat("num")
	assert.NoError(t, err)
	assert.Equal(t, float64(42), val)
}

// AC6: Row String method
func TestRowString(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"name": "test",
		"num":  42,
	}}

	str := row.String()
	assert.Contains(t, str, "test")
	assert.Contains(t, str, "42")
}

// AC6: Row GetInt with float64 value
func TestRowGetIntFromFloat(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"num": float64(42.5),
	}}

	val, err := row.GetInt("num")
	assert.NoError(t, err)
	assert.Equal(t, int32(42), val)
}

// AC6: Row GetFloat with invalid type
func TestRowGetFloatInvalidType(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"obj": map[string]int{},
	}}

	val, err := row.GetFloat("obj")
	assert.Error(t, err)
	assert.ErrorContains(t, err, "is not a float")
	assert.Equal(t, 0.0, val)
}

// AC6: Row GetString fallback for non-string
func TestRowGetStringFallback(t *testing.T) {
	row := Row{values: map[string]interface{}{
		"num": 123,
	}}

	val, err := row.GetString("num")
	assert.NoError(t, err)
	assert.Equal(t, "123", val)
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
