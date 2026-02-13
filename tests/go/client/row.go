// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Row

package spark

import (
	"fmt"
)

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
