// SPDX-License-Identifier: Apache-2.0
// Spark Connect Row Tests

package spark

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

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
