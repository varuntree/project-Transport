## 6. ✅ Database Schema Design (ORACLE REVIEWED)

### Overview

Complete **pattern-model schema** for Supabase PostgreSQL optimized for <400 MB, read-heavy workload, geospatial queries, and <200ms p95 response times.

### Core GTFS Pattern Schema

```sql
-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Agencies (dimension, small)
CREATE TABLE agencies (
  agency_pk SMALLSERIAL PRIMARY KEY,
  agency_id TEXT NOT NULL UNIQUE,
  agency_name TEXT NOT NULL,
  agency_timezone TEXT NOT NULL
);

-- Routes (dimension, small)
CREATE TABLE routes (
  route_pk SMALLSERIAL PRIMARY KEY,
  route_id TEXT NOT NULL UNIQUE,
  agency_pk SMALLINT REFERENCES agencies(agency_pk),
  route_short_name TEXT,
  route_long_name TEXT,
  route_type SMALLINT NOT NULL,  -- GTFS standard values
  route_color CHAR(6),
  route_text_color CHAR(6)
);
CREATE INDEX idx_routes_route_id ON routes(route_id);

-- Stops (geospatial, ~2K Sydney)
CREATE TABLE stops (
  stop_pk SERIAL PRIMARY KEY,
  stop_id TEXT NOT NULL UNIQUE,
  stop_name TEXT NOT NULL,
  stop_lat DOUBLE PRECISION NOT NULL,
  stop_lon DOUBLE PRECISION NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,  -- PostGIS for ST_DWithin + KNN
  location_type SMALLINT NOT NULL DEFAULT 0,
  parent_station_pk INT REFERENCES stops(stop_pk) ON DELETE SET NULL,
  wheelchair_boarding SMALLINT NOT NULL DEFAULT 0
);
CREATE INDEX idx_stops_location ON stops USING GIST(location);  -- Essential for Q1
CREATE INDEX idx_stops_stop_id ON stops(stop_id);

-- Calendar (service patterns)
CREATE TABLE calendar (
  service_pk SMALLSERIAL PRIMARY KEY,
  service_id TEXT NOT NULL UNIQUE,
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

-- Calendar Exceptions
CREATE TABLE calendar_dates (
  service_pk SMALLINT NOT NULL REFERENCES calendar(service_pk) ON DELETE CASCADE,
  date DATE NOT NULL,
  exception_type SMALLINT NOT NULL,  -- 1=added, 2=removed
  PRIMARY KEY (service_pk, date)
);

-- Patterns (trip pattern dimension)
CREATE TABLE patterns (
  pattern_id SERIAL PRIMARY KEY,
  route_pk SMALLINT NOT NULL REFERENCES routes(route_pk) ON DELETE CASCADE,
  direction_id SMALLINT,
  shape_id TEXT
);

-- Pattern Stops (factored stop times)
CREATE TABLE pattern_stops (
  pattern_id INT NOT NULL REFERENCES patterns(pattern_id) ON DELETE CASCADE,
  seq SMALLINT NOT NULL,
  stop_pk INT NOT NULL REFERENCES stops(stop_pk) ON DELETE RESTRICT,
  offset_secs INT NOT NULL CHECK (offset_secs BETWEEN 0 AND 172800),
  timepoint BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (pattern_id, seq)
);
CREATE INDEX idx_pattern_stops_stop ON pattern_stops(stop_pk);  -- For Q2

-- Trips (compact, references patterns)
CREATE TABLE trips (
  trip_pk SERIAL PRIMARY KEY,
  trip_id TEXT NOT NULL UNIQUE,
  pattern_id INT NOT NULL REFERENCES patterns(pattern_id) ON DELETE CASCADE,
  service_pk SMALLINT NOT NULL REFERENCES calendar(service_pk) ON DELETE CASCADE,
  start_time_secs INT NOT NULL CHECK (start_time_secs BETWEEN 0 AND 172800),
  headsign TEXT
);
CREATE INDEX idx_trips_pattern_svc_time ON trips(pattern_id, service_pk, start_time_secs);  -- For Q2

-- Shapes (simplified, encoded, rail/metro/ferry/LR only)
CREATE TABLE shapes (
  shape_pk SERIAL PRIMARY KEY,
  shape_id TEXT NOT NULL UNIQUE,
  geom GEOMETRY(LineString, 4326) NOT NULL,
  length_m DOUBLE PRECISION
);
CREATE INDEX idx_shapes_geom ON shapes USING GIST(geom);

-- Service Active Dates (precomputed, 90-day rolling window)
CREATE TABLE service_active_dates (
  service_pk SMALLINT NOT NULL REFERENCES calendar(service_pk) ON DELETE CASCADE,
  service_date DATE NOT NULL,
  PRIMARY KEY (service_pk, service_date)
);

-- Route Representative Trips (materialized view)
CREATE MATERIALIZED VIEW route_representative_trips AS
SELECT r.route_pk, t.direction_id,
       (SELECT t2.trip_pk FROM trips t2
        JOIN pattern_stops ps2 ON ps2.pattern_id = t2.pattern_id
        WHERE t2.route_pk = r.route_pk
          AND (t2.direction_id IS NOT DISTINCT FROM t.direction_id)
        GROUP BY t2.trip_pk ORDER BY COUNT(*) DESC, t2.trip_pk LIMIT 1) AS representative_trip_pk
FROM routes r
LEFT JOIN trips t ON t.route_pk = r.route_pk
GROUP BY r.route_pk, t.direction_id;

CREATE UNIQUE INDEX idx_rep_trip_unique
  ON route_representative_trips (route_pk, COALESCE(direction_id, -1));

-- Route Stops (derived from representative trips)
CREATE MATERIALIZED VIEW route_stops AS
SELECT rrt.route_pk, rrt.direction_id, ps.seq, ps.stop_pk
FROM route_representative_trips rrt
JOIN pattern_stops ps ON ps.pattern_id = (SELECT pattern_id FROM trips WHERE trip_pk = rrt.representative_trip_pk);

CREATE INDEX idx_route_stops_route_dir_seq
  ON route_stops (route_pk, direction_id, seq);
```

### User Data Schema (RLS Protected)

```sql
-- User Profiles
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Favorites
CREATE TABLE favorites (
  favorite_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('stop','route')),
  stop_pk INT,
  route_pk SMALLINT,
  entity_id TEXT,
  display_order SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT favorites_stop_or_route CHECK (
    (entity_type='stop' AND stop_pk IS NOT NULL) OR
    (entity_type='route' AND route_pk IS NOT NULL)
  )
);
CREATE INDEX idx_favorites_user ON favorites(user_id, display_order);

-- Saved Trips
CREATE TABLE saved_trips (
  saved_trip_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  from_stop_pk INT NOT NULL REFERENCES stops(stop_pk) ON DELETE RESTRICT,
  to_stop_pk INT NOT NULL REFERENCES stops(stop_pk) ON DELETE RESTRICT,
  label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notification Preferences
CREATE TABLE notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  apns_token TEXT,
  alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on user tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- RLS Policies (users manage own data)
CREATE POLICY "Users manage own profile" ON user_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own favorites" ON favorites FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own trips" ON saved_trips FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own preferences" ON notification_preferences FOR ALL USING (auth.uid() = user_id);
```

### Critical Queries (Optimized)

**Q1: Nearby stops (<100ms p95)**
```sql
SELECT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon
FROM stops s
WHERE ST_DWithin(s.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::GEOGRAPHY, 500)
ORDER BY s.location <-> ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::GEOGRAPHY
LIMIT 20;
```
*Uses GiST spatial index + KNN (`<->`); ~2K stops = single-digit ms.*

**Q2: Next 5 departures for stop (<200ms p95)**
```sql
SELECT t.trip_id, r.route_short_name, t.headsign,
       (t.start_time_secs + ps.offset_secs) AS dep_secs
FROM pattern_stops ps
JOIN trips t ON t.pattern_id = ps.pattern_id
JOIN routes r ON r.route_pk = (SELECT route_pk FROM patterns WHERE pattern_id = ps.pattern_id)
JOIN service_active_dates sad ON sad.service_pk = t.service_pk AND sad.service_date = :today
WHERE ps.stop_pk = :stop_pk
  AND (t.start_time_secs + ps.offset_secs) >= :current_secs
ORDER BY dep_secs LIMIT 5;
```
*Uses composite index on `idx_trips_pattern_svc_time`; service_active_dates is tiny helper table.*

**Q3: Route details (stops for map) (<120-300ms)**
```sql
SELECT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon, rs.seq
FROM route_stops rs
JOIN routes r ON r.route_pk = rs.route_pk
JOIN stops s ON s.stop_pk = rs.stop_pk
WHERE r.route_id = :route_id
  AND (:direction_id IS NULL OR rs.direction_id = :direction_id)
ORDER BY rs.seq;
```
*Uses precomputed MV route_stops (representative trip per route+direction).*

**Q4: User favorites with next departure (<200ms)**
```sql
SELECT f.favorite_id, s.stop_id, s.stop_name, nd.*
FROM favorites f
JOIN stops s ON s.stop_pk = f.stop_pk
LEFT JOIN LATERAL (
  SELECT t.trip_id, r.route_short_name, t.headsign,
         (t.start_time_secs + ps.offset_secs) AS dep_secs
  FROM pattern_stops ps
  JOIN trips t ON t.pattern_id = ps.pattern_id
  JOIN routes r ON r.route_pk = (SELECT route_pk FROM patterns WHERE pattern_id = ps.pattern_id)
  JOIN service_active_dates sad ON sad.service_pk = t.service_pk AND sad.service_date = :today
  WHERE ps.stop_pk = f.stop_pk
    AND (t.start_time_secs + ps.offset_secs) >= :current_secs
  ORDER BY dep_secs LIMIT 1
) nd ON true
WHERE f.user_id = :user_id AND f.entity_type = 'stop'
ORDER BY f.display_order;
```
*LATERAL runs index scan per favorite (5-10 stops typically); stays <200ms.*

### Size Estimates

| Component              | Rows      | Data Size | Indexes | Total   |
|-----------------------|----------:|----------:|--------:|--------:|
| agencies              | ~10       | <5 KB     | negl.   | <5 KB   |
| stops                 | ~2,000    | ~480 KB   | ~0.5 MB | ~1 MB   |
| routes                | ~500      | ~110 KB   | ~200 KB | ~0.3 MB |
| calendar              | 100-300   | ~24 KB    | negl.   | ~24 KB  |
| calendar_dates        | ~500      | ~20 KB    | negl.   | ~20 KB  |
| patterns              | ~5,000    | ~1 MB     | ~0.5 MB | ~1.5 MB |
| pattern_stops         | ~150K     | ~9 MB     | ~5 MB   | ~14 MB  |
| trips                 | ~50,000   | ~6 MB     | ~5 MB   | ~11 MB  |
| shapes                | ~500      | ~3-8 MB   | ~1 MB   | ~9 MB   |
| service_active_dates  | ~3K       | <0.5 MB   | negl.   | ~0.5 MB |
| route_* MVs           | ~2K       | <1 MB     | <1 MB   | ~2 MB   |
| **GTFS subtotal**     |           | ~22 MB    | ~13 MB  | **~35 MB** |
| User data (10K users) |           | ~10 MB    | ~5 MB   | ~15 MB  |
| **Grand total**       |           | ~32 MB    | ~18 MB  | **~50 MB** |

**Well under 500 MB free tier**; leaves ~450 MB headroom.

### Maintenance Tasks

**Daily (post-GTFS load):**
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY route_representative_trips;
REFRESH MATERIALIZED VIEW CONCURRENTLY route_stops;
ANALYZE;
```

**Optional (after bulk reloads):**
```sql
CLUSTER pattern_stops USING idx_pattern_stops_pattern_seq;  -- Improves locality
```

### Write Protection (GTFS Tables)

```sql
-- Prevent accidental RT writes to GTFS static
CREATE OR REPLACE FUNCTION app.assert_gtfs_sync()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('app.gtfs_sync', true) IS NULL THEN
    RAISE EXCEPTION 'GTFS tables are read-only outside sync task';
  END IF;
  RETURN NEW;
END $$;

-- Apply to all GTFS tables
CREATE TRIGGER gtfs_routes_ro BEFORE INSERT OR UPDATE OR DELETE ON routes FOR EACH ROW EXECUTE FUNCTION app.assert_gtfs_sync();
CREATE TRIGGER gtfs_stops_ro BEFORE INSERT OR UPDATE OR DELETE ON stops FOR EACH ROW EXECUTE FUNCTION app.assert_gtfs_sync();
-- ... (repeat for all GTFS tables)

-- During daily sync:
-- SET LOCAL app.gtfs_sync = 'on';
```

**Source:** Oracle consultation 03, research-backed (pattern model = OTP/R5, PostGIS KNN, index-only scans, COPY bulk load)
