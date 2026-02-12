# Spark Connect Go Client

> **NOTE:** As of February 2026, official Apache Spark Connect Go client
> does NOT exist at `github.com/apache/spark/connect/client/go` (returns 404).
>
> This implementation builds from gRPC protobuf definitions directly.
>
> **Verification:** https://github.com/apache/spark/tree/master/connector/connect

## Purpose

Go client library for Apache Spark Connect gRPC API.

## API Reference

- [Spark Connect Protocol](https://spark.apache.org/docs/latest/api/connect/)
- Proto definitions: `connector/connect/common/src/main/resources/spark/connect/connect.proto`

## Status

⏳ **Under development** - Building from gRPC protobuf definitions

## Implementation Approach

1. Generate Go protobuf from Spark Connect proto definitions
2. gRPC connection to Spark Connect server (default port: 15002)
3. Execute SQL queries via ExecutePlanRequest with Relation.SQL
4. Parse OutputBatches with Arrow data using Arrow readers
5. Session management via CreateSessionRequest/CloseSessionRequest
