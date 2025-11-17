-- Migration: Add start_time_secs to trips table
-- Date: 2025-11-17 21:27:39 AEDT
-- Applied via: Supabase MCP (mcp__supabase__apply_migration)
-- Status: Applied successfully

-- Add start_time_secs column to trips table
-- This stores the seconds since midnight for the first departure of the trip
-- Needed to calculate actual departure times: start_time_secs + departure_offset_secs

ALTER TABLE trips
ADD COLUMN start_time_secs INTEGER;

COMMENT ON COLUMN trips.start_time_secs IS 'Seconds since midnight (00:00) for trip start time. Can be >= 86400 for trips starting after midnight.';

-- Create index for query performance
CREATE INDEX idx_trips_start_time ON trips(start_time_secs) WHERE start_time_secs IS NOT NULL;
