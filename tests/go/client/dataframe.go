// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - DataFrame

package spark

import (
	"context"
	"fmt"
)

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
