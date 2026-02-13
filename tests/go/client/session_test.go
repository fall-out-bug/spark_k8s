// SPDX-License-Identifier: Apache-2.0
// Spark Connect Session Tests

package spark

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

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

// AC6: Error handling - SQL without session
func TestSQLWithoutSession(t *testing.T) {
	ctx := context.Background()

	// DataFrame with nil session should handle error
	df := &DataFrame{session: nil, plan: ""}
	rows, err := df.Collect(ctx)
	assert.Error(t, err)
	assert.Nil(t, rows)
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
