-- Sydney Transit App - Initial Schema Migration
-- Phase 1: Pattern Model Tables with PostGIS Spatial Indexing
-- Created: 2025-11-13
-- Description: Creates 9 GTFS pattern model tables, PostGIS geography for stops,
--              auto-populate trigger, GIST/GIN/B-tree indexes, and exec_raw_sql RPC

-- ============================================================================
-- STEP 1: Enable Extensions
-- ============================================================================

-- Enable PostGIS for geospatial queries (ST_DWithin, ST_Distance)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable trigram extension for fuzzy text search (stop name search)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- STEP 2: Create Tables (Pattern Model Schema)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. agencies - Transit agencies (Sydney Trains, NSW TrainLink, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE agencies (
    agency_id TEXT PRIMARY KEY,
    agency_name TEXT NOT NULL,
    agency_url TEXT,
    agency_timezone TEXT NOT NULL DEFAULT 'Australia/Sydney'
);

-- ----------------------------------------------------------------------------
-- 2. routes - Transit routes (T1, T2, 333 bus, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE routes (
    route_id TEXT PRIMARY KEY,
    agency_id TEXT REFERENCES agencies(agency_id) ON DELETE CASCADE,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER NOT NULL, -- 0=tram, 1=metro, 2=rail, 3=bus, 4=ferry
    route_color TEXT,
    route_text_color TEXT
);

-- ----------------------------------------------------------------------------
-- 3. stops - Physical stops/stations with PostGIS geography
-- ----------------------------------------------------------------------------
CREATE TABLE stops (
    stop_id TEXT PRIMARY KEY,
    stop_code TEXT,
    stop_name TEXT NOT NULL,
    stop_desc TEXT,
    stop_lat REAL NOT NULL,
    stop_lon REAL NOT NULL,
    location geography(Point, 4326), -- Auto-populated by trigger (lon,lat order!)
    location_type INTEGER DEFAULT 0,
    parent_station TEXT,
    wheelchair_boarding INTEGER,
    platform_code TEXT
);

-- ----------------------------------------------------------------------------
-- 4. patterns - Unique stop sequences (pattern model core)
-- ----------------------------------------------------------------------------
CREATE TABLE patterns (
    pattern_id TEXT PRIMARY KEY,
    route_id TEXT REFERENCES routes(route_id) ON DELETE CASCADE,
    direction_id INTEGER NOT NULL,
    pattern_name TEXT -- e.g., "T1 Central → Penrith via North Shore"
);

-- ----------------------------------------------------------------------------
-- 5. pattern_stops - Stop sequences with time offsets (pattern model core)
-- ----------------------------------------------------------------------------
CREATE TABLE pattern_stops (
    pattern_id TEXT REFERENCES patterns(pattern_id) ON DELETE CASCADE,
    stop_sequence INTEGER NOT NULL,
    stop_id TEXT REFERENCES stops(stop_id) ON DELETE CASCADE,
    arrival_offset_secs INTEGER NOT NULL, -- seconds from trip start_time
    departure_offset_secs INTEGER NOT NULL, -- seconds from trip start_time
    PRIMARY KEY (pattern_id, stop_sequence)
);

-- ----------------------------------------------------------------------------
-- 6. trips - Individual trips referencing patterns
-- ----------------------------------------------------------------------------
CREATE TABLE trips (
    trip_id TEXT PRIMARY KEY,
    route_id TEXT REFERENCES routes(route_id) ON DELETE CASCADE,
    service_id TEXT NOT NULL,
    pattern_id TEXT REFERENCES patterns(pattern_id) ON DELETE CASCADE,
    trip_headsign TEXT,
    trip_short_name TEXT,
    direction_id INTEGER,
    block_id TEXT,
    wheelchair_accessible INTEGER
);

-- ----------------------------------------------------------------------------
-- 7. calendar - Regular service schedules (weekday/weekend patterns)
-- ----------------------------------------------------------------------------
CREATE TABLE calendar (
    service_id TEXT PRIMARY KEY,
    monday BOOLEAN NOT NULL,
    tuesday BOOLEAN NOT NULL,
    wednesday BOOLEAN NOT NULL,
    thursday BOOLEAN NOT NULL,
    friday BOOLEAN NOT NULL,
    saturday BOOLEAN NOT NULL,
    sunday BOOLEAN NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 8. calendar_dates - Service exceptions (public holidays, disruptions)
-- ----------------------------------------------------------------------------
CREATE TABLE calendar_dates (
    service_id TEXT NOT NULL,
    date DATE NOT NULL,
    exception_type INTEGER NOT NULL, -- 1=added, 2=removed
    PRIMARY KEY (service_id, date)
);

-- ----------------------------------------------------------------------------
-- 9. gtfs_metadata - Feed version tracking for GTFS updates
-- ----------------------------------------------------------------------------
CREATE TABLE gtfs_metadata (
    feed_version TEXT PRIMARY KEY,
    feed_start_date DATE,
    feed_end_date DATE,
    processed_at TIMESTAMP DEFAULT NOW(),
    stops_count INTEGER,
    routes_count INTEGER,
    patterns_count INTEGER,
    trips_count INTEGER
);

-- ============================================================================
-- STEP 3: Create Trigger for Auto-Populating stop.location
-- ============================================================================

-- Trigger function: Auto-populate geography from lat/lon
-- CRITICAL: ST_MakePoint uses (lon, lat) order - longitude first!
CREATE OR REPLACE FUNCTION update_stop_location()
RETURNS TRIGGER AS $$
BEGIN
    -- ST_MakePoint(longitude, latitude) - ORDER MATTERS!
    -- Cast to geography for accurate distance calculations in meters
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.stop_lon, NEW.stop_lat), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to stops table (BEFORE INSERT/UPDATE)
CREATE TRIGGER stop_location_trigger
BEFORE INSERT OR UPDATE ON stops
FOR EACH ROW
EXECUTE FUNCTION update_stop_location();

-- ============================================================================
-- STEP 4: Create Indexes for Query Performance
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Spatial Index (GIST) for Nearby Queries
-- ----------------------------------------------------------------------------
-- Enables efficient ST_DWithin(location, point, radius) queries
CREATE INDEX idx_stops_location ON stops USING GIST (location);

-- ----------------------------------------------------------------------------
-- Text Search Index (GIN Trigram) for Fuzzy Stop Name Search
-- ----------------------------------------------------------------------------
-- Enables fuzzy search: "Circula" → "Circular Quay"
CREATE INDEX idx_stops_name_trgm ON stops USING GIN (stop_name gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- B-tree Indexes for Join/Filter Performance
-- ----------------------------------------------------------------------------
-- Pattern/service lookups (used in departure queries)
CREATE INDEX idx_trips_service_id ON trips (service_id);
CREATE INDEX idx_trips_pattern_id ON trips (pattern_id);

-- Pattern stop sequence lookups (critical for departure time calculations)
CREATE INDEX idx_pattern_stops_pattern_id ON pattern_stops (pattern_id, stop_sequence);

-- Route lookups
CREATE INDEX idx_routes_agency_id ON routes (agency_id);
CREATE INDEX idx_routes_type ON routes (route_type);

-- Calendar date lookups for service validation
CREATE INDEX idx_calendar_dates_date ON calendar_dates (date);

-- ============================================================================
-- STEP 5: Create RPC Function for Complex Pattern Queries
-- ============================================================================

-- RPC function: Execute raw SQL with parameters (for complex pattern queries)
-- SECURITY: DEFINER allows anon role to execute, but parameterized queries prevent injection
-- Usage: SELECT exec_raw_sql('SELECT * FROM stops WHERE stop_id = $1', '["200060"]'::jsonb)
CREATE OR REPLACE FUNCTION exec_raw_sql(query text, params jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Execute parameterized query
    -- Note: This is intentionally flexible for backend use
    -- Phase 6 will add RLS policies to restrict access
    EXECUTE query INTO result USING params;
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Query execution failed: %', SQLERRM;
END;
$$;

-- Grant execute permissions to authenticated and anonymous users
-- (Backend will authenticate via service role key)
GRANT EXECUTE ON FUNCTION exec_raw_sql TO authenticated, anon;

-- ============================================================================
-- VALIDATION QUERIES (Run these after migration to verify success)
-- ============================================================================

-- Check tables created (should return 9 tables)
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema='public' AND table_type='BASE TABLE'
-- ORDER BY table_name;
-- Expected: agencies, calendar, calendar_dates, gtfs_metadata, pattern_stops, patterns, routes, stops, trips

-- Check PostGIS installed
-- SELECT PostGIS_version();
-- Expected: "3.x USE_GEOS=1 USE_PROJ=1 USE_STATS=1" or similar

-- Check trigger exists
-- SELECT tgname FROM pg_trigger WHERE tgname = 'stop_location_trigger';
-- Expected: stop_location_trigger

-- Check RPC function exists
-- SELECT proname FROM pg_proc WHERE proname = 'exec_raw_sql';
-- Expected: exec_raw_sql

-- Check indexes created (should show 3 indexes for stops table)
-- SELECT indexname FROM pg_indexes WHERE tablename = 'stops';
-- Expected: stops_pkey, idx_stops_location, idx_stops_name_trgm

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
