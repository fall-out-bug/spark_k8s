// SPDX-License-Identifier: Apache-2.0
// Spark Connect Go Client - Session

package spark

import (
	"context"
	"fmt"
	"time"
)

// Session represents a Spark session
type Session struct {
	client    *Client
	sessionID string
	config    map[string]string
}

// CreateSession creates a new Spark session
func (c *Client) CreateSession(ctx context.Context) (*Session, error) {
	// NOTE: Full gRPC CreateSessionRequest to be implemented in WS-017-02
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
