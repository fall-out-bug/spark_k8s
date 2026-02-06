-- Postgres initialization script for load testing
-- Part of WS-013-06: Minikube Auto-Setup Infrastructure

-- Create test schemas
CREATE SCHEMA IF NOT EXISTS test_schema;

-- Create test tables
CREATE TABLE IF NOT EXISTS test_schema.taxi_trips (
    trip_id BIGSERIAL PRIMARY KEY,
    pickup_datetime TIMESTAMP NOT NULL,
    dropoff_datetime TIMESTAMP NOT NULL,
    passenger_count INTEGER,
    trip_distance FLOAT,
    pickup_longitude FLOAT,
    pickup_latitude FLOAT,
    dropoff_longitude FLOAT,
    dropoff_latitude FLOAT,
    fare_amount FLOAT,
    tip_amount FLOAT,
    total_amount FLOAT
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_taxi_trips_pickup ON test_schema.taxi_trips(pickup_datetime);
CREATE INDEX IF NOT EXISTS idx_taxi_trips_passenger ON test_schema.taxi_trips(passenger_count);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA test_schema TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_schema TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA test_schema TO postgres;

-- Create sample aggregate table for testing
CREATE TABLE IF NOT EXISTS test_schema.trip_summary (
    summary_date DATE PRIMARY KEY,
    total_trips INTEGER,
    total_passengers INTEGER,
    avg_distance FLOAT,
    avg_fare FLOAT
);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_schema TO postgres;
