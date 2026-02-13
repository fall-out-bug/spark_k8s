// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - E2E Test Helpers

package e2e

import (
	"fmt"
	"net"
	"os"
	"testing"
	"time"
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
		t.Skip("Spark Connect server not available - skipping E2E test")
	}
	conn.Close()
}

// skipIfDatasetNotAvailable skips test if NYC Taxi dataset is not loaded
func skipIfDatasetNotAvailable(t *testing.T) {
	t.Helper()
	// Check if dataset should be available (env var or skip flag)
	if os.Getenv("SKIP_E2E_DATASET_TESTS") != "" {
		t.Skip("E2E dataset tests skipped via env var")
	}
}

// getEnv gets env variable or default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEndpoint returns Spark Connect endpoint string
func getEndpoint() string {
	host := getEnv("SPARK_CONNECT_HOST", "localhost")
	port := getEnv("SPARK_CONNECT_PORT", "15002")
	return fmt.Sprintf("%s:%s", host, port)
}
