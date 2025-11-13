# Checkpoint 3: Supabase Schema Migration

## Goal
Create pattern model tables with PostGIS spatial indexing in Supabase. Execute migration SQL to create 9 tables: agencies, routes, stops (w/ geography), patterns, pattern_stops, trips, calendar, calendar_dates, gtfs_metadata. Add RPC for complex pattern queries.

## Approach

### Backend Implementation
- Create SQL migration file with full schema
- Files to create:
  - `schemas/migrations/001_initial_schema.sql` - Complete schema DDL
- Files to modify: None
- Critical pattern: PostGIS geography type (lon,lat order!), auto-populate trigger, GIN/GIST indexes

### Implementation Details

**Schema Structure:**

1. **agencies** - Transit agencies (Sydney Trains, NSW TrainLink, etc.)
   - agency_id TEXT PRIMARY KEY
   - agency_name TEXT NOT NULL
   - agency_url TEXT
   - agency_timezone TEXT DEFAULT 'Australia/Sydney'

2. **routes** - Transit routes (T1, T2, 333 bus, etc.)
   - route_id TEXT PRIMARY KEY
   - agency_id TEXT REFERENCES agencies
   - route_short_name TEXT
   - route_long_name TEXT
   - route_type INTEGER NOT NULL (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
   - route_color TEXT
   - route_text_color TEXT

3. **stops** - Physical stops/stations
   - stop_id TEXT PRIMARY KEY
   - stop_code TEXT
   - stop_name TEXT NOT NULL
   - stop_desc TEXT
   - stop_lat REAL NOT NULL
   - stop_lon REAL NOT NULL
   - **location geography(Point, 4326)** - Auto-populated via trigger
   - location_type INTEGER DEFAULT 0
   - parent_station TEXT
   - wheelchair_boarding INTEGER
   - platform_code TEXT
   - **Indexes:** GIST(location), GIN(stop_name gin_trgm_ops)

4. **patterns** - Unique stop sequences
   - pattern_id TEXT PRIMARY KEY
   - route_id TEXT REFERENCES routes
   - direction_id INTEGER NOT NULL
   - pattern_name TEXT (e.g., "T1 Central → Penrith via North Shore")

5. **pattern_stops** - Stop sequences with offsets
   - pattern_id TEXT REFERENCES patterns
   - stop_sequence INTEGER NOT NULL
   - stop_id TEXT REFERENCES stops
   - arrival_offset_secs INTEGER NOT NULL (seconds from trip start)
   - departure_offset_secs INTEGER NOT NULL
   - **PRIMARY KEY (pattern_id, stop_sequence)**
   - **Index:** B-tree on (pattern_id, stop_sequence)

6. **trips** - Individual trips
   - trip_id TEXT PRIMARY KEY
   - route_id TEXT REFERENCES routes
   - service_id TEXT NOT NULL
   - pattern_id TEXT REFERENCES patterns
   - trip_headsign TEXT
   - trip_short_name TEXT
   - direction_id INTEGER
   - block_id TEXT
   - wheelchair_accessible INTEGER
   - **Index:** B-tree on (service_id), (pattern_id)

7. **calendar** - Regular service schedules
   - service_id TEXT PRIMARY KEY
   - monday BOOLEAN
   - tuesday BOOLEAN
   - wednesday BOOLEAN
   - thursday BOOLEAN
   - friday BOOLEAN
   - saturday BOOLEAN
   - sunday BOOLEAN
   - start_date DATE
   - end_date DATE

8. **calendar_dates** - Service exceptions
   - service_id TEXT
   - date DATE
   - exception_type INTEGER (1=added, 2=removed)
   - **PRIMARY KEY (service_id, date)**

9. **gtfs_metadata** - Feed version tracking
   - feed_version TEXT PRIMARY KEY
   - feed_start_date DATE
   - feed_end_date DATE
   - processed_at TIMESTAMP DEFAULT NOW()
   - stops_count INTEGER
   - routes_count INTEGER
   - patterns_count INTEGER
   - trips_count INTEGER

**PostGIS Setup:**
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- For text search
```

**Auto-populate Trigger:**
```sql
CREATE OR REPLACE FUNCTION update_stop_location()
RETURNS TRIGGER AS $$
BEGIN
  NEW.location := ST_SetSRID(ST_MakePoint(NEW.stop_lon, NEW.stop_lat), 4326)::geography;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stop_location_trigger
BEFORE INSERT OR UPDATE ON stops
FOR EACH ROW
EXECUTE FUNCTION update_stop_location();
```

**Indexes:**
```sql
-- Spatial index for nearby queries
CREATE INDEX idx_stops_location ON stops USING GIST (location);

-- Text search index for stop names
CREATE INDEX idx_stops_name_trgm ON stops USING GIN (stop_name gin_trgm_ops);

-- Pattern/service lookups
CREATE INDEX idx_trips_service_id ON trips (service_id);
CREATE INDEX idx_trips_pattern_id ON trips (pattern_id);
CREATE INDEX idx_pattern_stops_pattern_id ON pattern_stops (pattern_id, stop_sequence);
```

**RPC for Pattern Queries:**
```sql
CREATE OR REPLACE FUNCTION exec_raw_sql(query text, params jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Execute parameterized query
  EXECUTE query INTO result USING params;
  RETURN result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Query execution failed: %', SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION exec_raw_sql TO authenticated, anon;
```

## Design Constraints
- **PostGIS coordinate order:** ST_MakePoint(lon, lat) - longitude first!
- **Geography type:** Use `geography(Point, 4326)` (not geometry) for accurate distance calculations in meters
- **Trigger must run BEFORE INSERT/UPDATE:** Ensures location populated before constraints checked
- **RPC security:** SECURITY DEFINER allows anon role to execute, but parameterized queries prevent injection
- **Text search:** GIN trigram index for fuzzy search (handles "Circula" → "Circular Quay")
- Follow DATA_ARCHITECTURE.md:Section 6 schema exactly (table names, column types)

## Risks
- **PostGIS not installed:** Check Supabase free tier supports PostGIS
  - Mitigation: CREATE EXTENSION IF NOT EXISTS (safe if already installed)
- **NULL locations after trigger:** Trigger might fail silently
  - Mitigation: Validate in Checkpoint 4 (SELECT COUNT(*) WHERE location IS NULL = 0)
- **RPC security risk:** exec_raw_sql could be abused
  - Mitigation: Phase 6 will add RLS policies, for now only backend calls it
- **Index creation slow:** ~15k stops + spatial index
  - Mitigation: Acceptable for one-time migration (~30s)

## Validation
```sql
-- User executes in Supabase SQL Editor:

-- Check tables created
SELECT table_name FROM information_schema.tables
WHERE table_schema='public'
ORDER BY table_name;
-- Expected: agencies, calendar, calendar_dates, gtfs_metadata, pattern_stops, patterns, routes, stops, trips (9 tables)

-- Check PostGIS installed
SELECT PostGIS_version();
-- Expected: "3.x USE_GEOS=1 USE_PROJ=1 USE_STATS=1" or similar

-- Check trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'stop_location_trigger';
-- Expected: stop_location_trigger

-- Check RPC function exists
SELECT proname FROM pg_proc WHERE proname = 'exec_raw_sql';
-- Expected: exec_raw_sql

-- Check indexes created
SELECT indexname FROM pg_indexes WHERE tablename = 'stops';
-- Expected: stops_pkey, idx_stops_location, idx_stops_name_trgm
```

## References for Subagent
- Exploration report: `key_decisions[1]` - PostGIS spatial indexes rationale
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.1 (database patterns)
- Architecture: DATA_ARCHITECTURE.md:Section 6 (complete schema)
- PostGIS: PHASE_1:L176-199 (lon,lat order warning!)
- RPC: PHASE_1:L419-425 (exec_raw_sql pattern)
- Existing SQL: .phase-logs/phase-1/supabase-rpc.sql (similar RPC example)

## Estimated Complexity
**moderate** - SQL DDL straightforward, but PostGIS setup, trigger logic, indexes require careful attention to details (coordinate order, geography vs geometry)
