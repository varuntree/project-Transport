# ORACLE PROMPT: Database Schema Design & Optimization

**Consultation ID:** 03_database_schema
**Context Document:** Attach `SYSTEM_OVERVIEW.md` when submitting this prompt
**Priority:** CRITICAL - Foundation for all data operations
**Expected Consultation Time:** 3-4 hours (with research + optimization analysis)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Database:** Supabase (PostgreSQL 14+ with PostGIS extension)
**Critical Constraint:** 500MB free tier limit (must stay under for as long as possible)
**Data:** Full Sydney GTFS (~2000 stops, ~500 routes, millions of stop_times rows)
**Workload:** Read-heavy (80% reads, 20% writes), geospatial queries (nearby stops)

---

## Fixed Tech Stack (DO NOT CHANGE)

- **Database:** Supabase (managed PostgreSQL + PostGIS)
- **ORM:** None (use raw SQL for performance, Pydantic for validation)
- **Query Interface:** Supabase Python client + psycopg2 for complex queries
- **Authentication:** Supabase Auth (built-in, handles JWT, Apple Sign-In)
- **Row Level Security:** Supabase RLS policies (for user data isolation)

**NO new databases or services allowed.**

---

## Problem Statement

Design an optimized PostgreSQL schema for Supabase that:

1. **Stores complete Sydney GTFS data** - Normalized structure, efficient queries
2. **Stays under 500MB** - Free tier limit (target <400MB for headroom)
3. **Optimizes for read-heavy workload** - 80% reads (departures, nearby stops, trip planning)
4. **Supports geospatial queries** - PostGIS for "nearby stops" (fast <100ms)
5. **Isolates user data** - RLS policies (users only see their own favorites/trips)
6. **Scales to 10K users** - Without hitting database limits

---

## Data Requirements

### GTFS Static Data (Public, Read-Only)

**Entities to Store:**
- **Agencies:** ~5-10 transit operators (Sydney Trains, Metro, Buses, Ferries, Light Rail)
- **Stops:** ~2,000 stops in Sydney (stations, bus stops, wharves)
- **Routes:** ~500 routes (T1, T2, T3 trains, bus routes 100-999, ferries, metro, light rail)
- **Trips:** ~50,000 trip instances (each service departure throughout the day)
- **Stop Times:** ~1-2 million rows (every trip × every stop × arrival/departure time)
- **Calendar:** ~20 service patterns (weekday, weekend, holiday schedules)
- **Calendar Dates:** ~500 exceptions (public holidays, special events)
- **Shapes:** ~500 route paths (~50,000 coordinate points for map visualization)

**Relationships:**
```
Agency (1) ──< Route (many)
Route (1) ──< Trip (many)
Trip (1) ──< StopTime (many)
StopTime (many) ──> Stop (1)
Trip (many) ──> Calendar (1)
Trip (many) ──> Shape (1)
```

### User Data (Private, RLS Protected)

**Entities:**
- **Users:** Managed by Supabase Auth (no custom table needed, extend with profiles)
- **Favorites:** ~3-5 per user (saved stops/routes for quick access)
- **Saved Trips:** ~2-3 per user (common journeys: "Home to Work")
- **Notification Preferences:** 1 per user (alert settings, APNs token)

**Expected Scale:**
- MVP: 1,000 users → ~5,000 favorites, ~3,000 saved trips
- Growth: 10,000 users → ~50,000 favorites, ~30,000 saved trips

---

## Constraints (CRITICAL - Must Respect)

### 1. Database Size Limit (500MB Supabase Free Tier)

**Challenge:**
- Full Sydney GTFS uncompressed: ~500-700 MB (raw CSV text)
- Must fit in PostgreSQL with indexes: Target <400 MB (80% of limit)

**Strategies Oracle Must Evaluate:**
- **Normalize vs Denormalize:** Normalized saves space, denormalized faster queries
- **Index Selection:** Only essential indexes (each index adds ~10-30% table size)
- **Data Type Optimization:** Use smallest safe types (INT vs BIGINT, VARCHAR(50) vs TEXT)
- **Partitioning:** Split large tables (stop_times) to manage size/performance
- **Compression:** PostgreSQL table compression (TOAST settings)

### 2. Query Performance Requirements

**Critical Queries (Must Be Fast):**

**Q1: Nearby Stops (Geospatial)**
```sql
-- Find stops within 500m radius of user location
-- Target: <100ms response time
SELECT stop_id, stop_name, stop_lat, stop_lon
FROM stops
WHERE ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(151.2093, -33.8688), 4326)::geography,
    500  -- meters
)
ORDER BY location <-> ST_SetSRID(ST_MakePoint(151.2093, -33.8688), 4326)::geography
LIMIT 20;

-- Oracle: Optimize this query (indexes, PostGIS settings)
```

**Q2: Next Departures for Stop**
```sql
-- Get next 5 departures for stop_id "12345" after current time
-- Target: <200ms response time
-- Must merge: scheduled times (stop_times) + real-time delays (from Redis via app logic)

SELECT
    st.trip_id,
    r.route_short_name,
    r.route_long_name,
    t.trip_headsign,
    st.departure_time,
    st.stop_sequence
FROM stop_times st
JOIN trips t ON st.trip_id = t.trip_id
JOIN routes r ON t.route_id = r.route_id
JOIN calendar c ON t.service_id = c.service_id
WHERE st.stop_id = '12345'
  AND st.departure_time > CURRENT_TIME
  AND c.start_date <= CURRENT_DATE
  AND c.end_date >= CURRENT_DATE
  -- AND (c.monday = TRUE) -- if today is Monday
ORDER BY st.departure_time
LIMIT 5;

-- Oracle: Optimize this query (most frequent, 80% of load)
```

**Q3: Route Details**
```sql
-- Get all stops for a route (for map visualization)
-- Target: <300ms response time

SELECT DISTINCT
    s.stop_id,
    s.stop_name,
    s.stop_lat,
    s.stop_lon,
    st.stop_sequence
FROM stop_times st
JOIN trips t ON st.trip_id = t.trip_id
JOIN stops s ON st.stop_id = s.stop_id
WHERE t.route_id = 'T1'
ORDER BY st.stop_sequence;

-- Oracle: Is there a better way to structure this data?
```

**Q4: User Favorites**
```sql
-- Get user's favorited stops with next departure info
-- Target: <200ms response time

SELECT
    f.entity_id AS stop_id,
    s.stop_name,
    -- ... (need next departure, complex join)
FROM favorites f
JOIN stops s ON f.entity_id = s.stop_id
WHERE f.user_id = 'uuid-here'
  AND f.entity_type = 'stop'
ORDER BY f.display_order;

-- Oracle: Optimize for fast favorites retrieval
```

### 3. Geospatial Requirements (PostGIS)

**Use Case:** "Nearby stops within 500m radius"
- **Query Frequency:** High (~30% of all queries)
- **Performance Target:** <100ms at p95
- **Data:** 2,000 stops with lat/lon coordinates

**PostGIS Configuration:**
```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Spatial index needed (GIST)
CREATE INDEX idx_stops_location ON stops USING GIST(location);

-- Oracle Questions:
-- 1. Best GIST index configuration for ~2000 points?
-- 2. Use GEOGRAPHY (accurate, slower) or GEOMETRY (fast, less accurate)?
-- 3. SRID 4326 (WGS84, standard) or project to local SRID (faster, complex)?
```

### 4. Row Level Security (User Data Isolation)

**Supabase RLS Requirement:**
```sql
-- Users must only access their own favorites, saved trips, preferences
-- Supabase RLS policies enforce this at database level

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own favorites"
ON favorites
FOR ALL
USING (auth.uid() = user_id);

-- Oracle: Design complete RLS policies for all user tables
-- Oracle: Ensure RLS doesn't degrade performance (RLS adds WHERE clauses)
```

---

## Questions for Oracle

### 1. Schema Design & Normalization

**Question:** Provide complete optimized schema (DDL) for Supabase PostgreSQL.

**Requirements:**
- Fully normalized (3NF) to minimize storage
- Essential indexes only (balance performance vs size)
- Correct data types (smallest safe sizes)
- Foreign key constraints (data integrity)
- NOT NULL constraints where applicable

**Oracle Provide:**
```sql
-- Complete CREATE TABLE statements for:
-- 1. GTFS tables: agencies, stops, routes, trips, stop_times, calendar, calendar_dates, shapes
-- 2. User tables: user_profiles, favorites, saved_trips, notification_preferences

-- For each table:
-- - Optimal data types (VARCHAR(X) vs TEXT, INT vs BIGINT, etc.)
-- - Primary keys
-- - Foreign keys with ON DELETE CASCADE/RESTRICT
-- - NOT NULL constraints
-- - Default values
-- - Comments explaining design decisions
```

**Example (Oracle expands):**
```sql
CREATE TABLE stops (
    stop_id VARCHAR(50) PRIMARY KEY,  -- NSW uses alphanumeric IDs, max ~30 chars observed
    stop_code VARCHAR(20),  -- Optional short code
    stop_name VARCHAR(255) NOT NULL,  -- Required, longest observed ~150 chars
    stop_desc TEXT,  -- Optional long description (rare, can be TEXT)
    stop_lat DECIMAL(10, 8) NOT NULL,  -- 8 decimal places = ~1mm precision
    stop_lon DECIMAL(11, 8) NOT NULL,
    location GEOGRAPHY(POINT, 4326),  -- PostGIS, WGS84 standard
    zone_id VARCHAR(10),  -- Fare zones (Sydney: "1", "2", etc.)
    stop_url VARCHAR(500),  -- Optional URL
    location_type SMALLINT DEFAULT 0,  -- 0=stop, 1=station, 2=entrance
    parent_station VARCHAR(50) REFERENCES stops(stop_id),  -- Hierarchical (entrance → station)
    wheelchair_boarding SMALLINT DEFAULT 0,  -- 0=unknown, 1=accessible, 2=not accessible
    created_at TIMESTAMP DEFAULT NOW(),  -- Track when loaded
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes (Oracle determines which are essential)
CREATE INDEX idx_stops_location ON stops USING GIST(location);  -- Geospatial
CREATE INDEX idx_stops_name_gin ON stops USING GIN(to_tsvector('english', stop_name));  -- Full-text search
CREATE INDEX idx_stops_parent ON stops(parent_station) WHERE parent_station IS NOT NULL;  -- Hierarchical queries

-- Oracle: Is GIN index worth the size? Alternatives for name search?
-- Oracle: Are all these indexes necessary? Drop any that don't justify their size?
```

### 2. Indexing Strategy (Critical for Performance & Size)

**Question:** Which indexes are essential vs optional? Justify each.

**Oracle Analyze:**

**Trade-Off Matrix:**
```
Index Name              | Table       | Size Overhead | Query Speedup | Verdict
------------------------|-------------|---------------|---------------|------------
idx_stops_location      | stops       | +20%         | 100x (spatial)| ✅ ESSENTIAL
idx_stops_name_gin      | stops       | +40%         | 50x (search)  | ❓ Oracle decides
idx_trips_route         | trips       | +15%         | 10x           | ✅ Likely needed
idx_stop_times_trip     | stop_times  | +25%         | 20x           | ✅ ESSENTIAL
idx_stop_times_stop     | stop_times  | +25%         | 50x           | ✅ ESSENTIAL
idx_stop_times_combined | stop_times  | +30%         | 100x (?)      | ❓ Better than 2 separate?
...
```

**Oracle Provide:**
- Complete index recommendations with size estimates
- Composite indexes vs single-column (when to use which)
- Partial indexes (index only subset of rows, save space)
- Index types (B-tree, GIST, GIN, BRIN) - when to use each

**Example Partial Index:**
```sql
-- Only index future departures (past times irrelevant)
CREATE INDEX idx_stop_times_future ON stop_times(stop_id, departure_time)
WHERE departure_time > CURRENT_TIME - INTERVAL '1 hour';

-- Oracle: Is this safe? Will it work with daily GTFS updates?
```

### 3. Stop_Times Optimization (Largest Table)

**Question:** How to optimize stop_times table (millions of rows, 60-70% of DB size)?

**Challenge:**
- **Rows:** ~1-2 million (every trip × every stop)
- **Size:** ~300-400 MB (largest table by far)
- **Query Pattern:** Filter by stop_id + time range, order by time

**Strategies to Evaluate:**

**A) Partitioning (by date or route)**
```sql
-- Partition by service date
CREATE TABLE stop_times (
    trip_id VARCHAR(50),
    stop_id VARCHAR(50),
    arrival_time TIME,
    departure_time TIME,
    stop_sequence INT,
    service_date DATE  -- Derived from calendar
) PARTITION BY RANGE (service_date);

CREATE TABLE stop_times_week1 PARTITION OF stop_times
FOR VALUES FROM ('2025-11-12') TO ('2025-11-19');

-- Pros: Faster queries (smaller partitions), easier archival (drop old partitions)
-- Cons: Complexity, requires date in WHERE clause

-- Oracle: Is partitioning worth it for ~1-2M rows? When to start partitioning?
```

**B) Materialized Views (Pre-computed Departures)**
```sql
-- Create materialized view for "next departures by stop"
CREATE MATERIALIZED VIEW next_departures AS
SELECT
    stop_id,
    trip_id,
    route_id,
    departure_time,
    trip_headsign
FROM stop_times st
JOIN trips t ON st.trip_id = t.trip_id
WHERE departure_time BETWEEN CURRENT_TIME AND CURRENT_TIME + INTERVAL '2 hours';

-- Refresh every 10 minutes
CREATE INDEX idx_next_departures_stop ON next_departures(stop_id, departure_time);

-- Pros: Blazing fast queries (<10ms)
-- Cons: Refresh overhead, stale data between refreshes

-- Oracle: Is this a good strategy? How to refresh efficiently?
```

**C) Denormalization (Embed Route Info)**
```sql
-- Add route_id directly to stop_times (avoids JOIN with trips)
ALTER TABLE stop_times ADD COLUMN route_id VARCHAR(50);

-- Pros: Faster queries (no JOIN)
-- Cons: Data redundancy, larger table size

-- Oracle: Worth the trade-off? Measure impact.
```

**Oracle Decide:**
- Best optimization strategy for stop_times
- Provide benchmark estimates (query time, table size)
- Recommend approach for MVP vs growth phase

### 4. Database Size Estimation

**Question:** Estimate total database size with Oracle's optimized schema.

**Calculate:**
```
Table Sizes (estimate):
- agencies: ~5 rows × ~200 bytes = <1 KB
- stops: ~2,000 rows × ~300 bytes = ~600 KB
- routes: ~500 rows × ~250 bytes = ~125 KB
- trips: ~50,000 rows × ~200 bytes = ~10 MB
- stop_times: ~1.5M rows × ~150 bytes = ~225 MB
- calendar: ~20 rows × ~100 bytes = <1 KB
- calendar_dates: ~500 rows × ~50 bytes = ~25 KB
- shapes: ~50,000 points × ~50 bytes = ~2.5 MB

Subtotal (GTFS data): ~240 MB

Indexes (+30% average): ~72 MB
User data (10K users): ~10 MB

Total: ~320 MB

Oracle: Validate/correct these estimates with real-world data
```

**Oracle Provide:**
- Table-by-table size breakdown
- Index size overhead (each index)
- Total at 1K, 5K, 10K users
- Headroom before hitting 500MB limit

### 5. Query Optimization Examples

**Question:** Optimize the 4 critical queries (Q1-Q4 above).

**Oracle Provide:**
- Rewritten queries (optimal SQL)
- EXPLAIN ANALYZE output (estimated cost, rows, time)
- Index recommendations for each query
- Alternative approaches if standard query slow

**Example:**
```sql
-- BEFORE (naive query)
SELECT * FROM stops WHERE stop_name LIKE '%Central%';  -- Slow, full table scan

-- AFTER (Oracle's optimized version)
SELECT stop_id, stop_name, stop_lat, stop_lon
FROM stops
WHERE to_tsvector('english', stop_name) @@ to_tsquery('central')
ORDER BY ts_rank(to_tsvector('english', stop_name), to_tsquery('central')) DESC
LIMIT 10;
-- Uses GIN index, returns ranked results
```

### 6. Row Level Security Policies

**Question:** Design complete RLS policies for all user tables.

**Oracle Provide:**
```sql
-- Enable RLS on user tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read/write only their own data
CREATE POLICY "user_profiles_policy" ON user_profiles
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can insert favorites
CREATE POLICY "favorites_insert" ON favorites
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view own favorites
CREATE POLICY "favorites_select" ON favorites
FOR SELECT
USING (auth.uid() = user_id);

-- Oracle: Complete policies for all tables
-- Oracle: Ensure policies don't degrade performance (test with EXPLAIN)
```

**Oracle Also Provide:**
- Policies for service accounts (backend can read GTFS data without auth)
- Admin policies (if needed for support)

### 7. Migration & Versioning Strategy

**Question:** How to handle schema changes and GTFS updates?

**Scenarios:**
- **Daily GTFS updates:** New stops, routes, trips added/removed
- **Schema evolution:** Add new field (e.g., real_time_data_available BOOLEAN)
- **Supabase migrations:** How to version and apply schema changes

**Oracle Provide:**

**Migration Tool:**
```sql
-- Use Supabase migrations (SQL files)
-- migrations/001_initial_schema.sql
-- migrations/002_add_realtime_flag.sql

-- Oracle: Recommend migration strategy (Supabase CLI, manual, automated)
```

**Idempotent DDL:**
```sql
-- Safe to re-run migrations
CREATE TABLE IF NOT EXISTS stops (...);
CREATE INDEX IF NOT EXISTS idx_stops_location ON stops USING GIST(location);

-- Oracle: Best practices for idempotent schema changes
```

**GTFS Update Strategy:**
```sql
-- How to update existing data without breaking app?
-- Option A: Truncate + bulk insert (brief downtime)
-- Option B: Upsert (slower, no downtime)
-- Option C: Blue-green tables (complex, zero downtime)

-- Oracle: Recommend approach for daily GTFS updates
```

### 8. Monitoring & Performance

**Question:** How to monitor database health and performance?

**Metrics to Track:**
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage (detect unused indexes)
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Slow queries (Supabase provides pg_stat_statements)
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Oracle Provide:**
- Complete monitoring SQL queries
- Alert thresholds (e.g., database >450MB, query >1s, index never used)
- Dashboard design (Supabase SQL view or Grafana)

---

## Research Mandate (Oracle's Superpower)

**CRITICAL:** Research production PostgreSQL schemas for GTFS data.

### Required Research Activities

1. **GTFS PostgreSQL Schemas:**
   - Search: "GTFS PostgreSQL schema best practices"
   - Search: "PostGIS GTFS transit database schema"
   - Search: "Open source GTFS database schema GitHub"
   - **Goal:** Find proven schemas from production transit apps

2. **PostGIS Optimization:**
   - Search: "PostGIS nearby query optimization"
   - Search: "PostGIS GIST index tuning"
   - Search: "PostGIS GEOGRAPHY vs GEOMETRY performance"
   - **Goal:** Best practices for geospatial queries

3. **PostgreSQL Performance:**
   - Search: "PostgreSQL read-heavy workload optimization"
   - Search: "PostgreSQL index strategy large tables"
   - Search: "PostgreSQL partitioning vs materialized views"
   - **Goal:** Optimize for 80% read workload

4. **Supabase-Specific:**
   - Search: "Supabase Row Level Security performance"
   - Search: "Supabase free tier optimization"
   - **Goal:** Supabase-specific best practices

### Citation Format

```
Recommendation: Use GEOGRAPHY type with GIST index for spatial queries

Rationale: Based on PostGIS documentation [1] and production GTFS apps [2],
GEOGRAPHY type provides accurate distance calculations (meters) without
projection complexity. GIST index on ~2000 points performs well (<50ms for
nearby queries) as demonstrated by [transit app example]. Trade-off: GEOGRAPHY
is ~10% slower than GEOMETRY but eliminates projection errors for Sydney
(spanning multiple UTM zones).

Sources:
[1] https://postgis.net/docs/geography.html
[2] https://github.com/OneBusAway/onebusaway (reference implementation)
```

---

## Expected Output Format

### 1. Complete Schema DDL (SQL)

**Full production-ready schema:**
```sql
-- ===================================
-- GTFS STATIC TABLES
-- ===================================

CREATE TABLE agencies (...);  -- Oracle provides complete DDL
CREATE TABLE stops (...);
CREATE TABLE routes (...);
CREATE TABLE trips (...);
CREATE TABLE stop_times (...);
CREATE TABLE calendar (...);
CREATE TABLE calendar_dates (...);
CREATE TABLE shapes (...);

-- ===================================
-- USER DATA TABLES
-- ===================================

CREATE TABLE user_profiles (...);
CREATE TABLE favorites (...);
CREATE TABLE saved_trips (...);
CREATE TABLE notification_preferences (...);

-- ===================================
-- INDEXES
-- ===================================

CREATE INDEX idx_stops_location ON stops USING GIST(location);
-- ... (Oracle provides complete index list with justifications)

-- ===================================
-- ROW LEVEL SECURITY
-- ===================================

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY ...;
-- ... (Oracle provides complete RLS policies)

-- ===================================
-- HELPER FUNCTIONS (if needed)
-- ===================================

-- Oracle may provide PL/pgSQL functions for complex queries
```

### 2. Query Optimization Guide

**For each critical query:**
```sql
-- Query: Next departures for stop
-- Optimized version:
SELECT ... ;

-- Index needed:
CREATE INDEX idx_stop_times_stop_time ON stop_times(stop_id, departure_time);

-- Expected performance:
-- Rows scanned: ~20 (vs 1.5M without index)
-- Execution time: ~10ms (vs 2000ms without index)
```

### 3. Database Size Estimation Table

| Component | Rows | Bytes/Row | Total Size | With Indexes | Notes |
|-----------|------|-----------|------------|--------------|-------|
| stops | 2,000 | 300 | 600 KB | 900 KB | +50% for GIST index |
| routes | 500 | 250 | 125 KB | 150 KB | Small table |
| trips | 50,000 | 200 | 10 MB | 13 MB | +30% indexes |
| stop_times | 1.5M | 150 | 225 MB | 315 MB | Largest table |
| ... | ... | ... | ... | ... | ... |
| **GTFS Total** | - | - | **250 MB** | **350 MB** | Under limit ✅ |
| **User Data (10K)** | - | - | **10 MB** | **15 MB** | Scales linearly |
| **Grand Total** | - | - | **260 MB** | **365 MB** | 73% of 500MB limit |

### 4. Performance Benchmarks

| Query | Without Optimization | With Optimization | Improvement |
|-------|---------------------|-------------------|-------------|
| Nearby stops (500m) | 800ms | 45ms | 18x faster |
| Next departures | 2000ms | 15ms | 133x faster |
| Route details | 1500ms | 120ms | 12x faster |
| User favorites | 300ms | 25ms | 12x faster |

### 5. Migration Scripts

**Oracle provides:**
```bash
# supabase/migrations/20251112000000_initial_schema.sql
# supabase/migrations/20251112000001_add_indexes.sql
# supabase/migrations/20251112000002_enable_rls.sql

# With instructions:
# 1. Install Supabase CLI
# 2. Run: supabase db push
# 3. Verify with: supabase db diff
```

---

## Success Criteria

Oracle's solution is successful if:

✅ **Size:** Total database <400MB at 10K users (80% of free tier)
✅ **Performance:** All critical queries <200ms at p95
✅ **Geospatial:** Nearby stops query <100ms with 2000 stops
✅ **Scalability:** Schema supports 50K users without major refactor
✅ **Security:** RLS policies tested and validated
✅ **Research-Backed:** Cites 3+ production GTFS PostgreSQL schemas
✅ **Complete:** Ready-to-run DDL, migration scripts, monitoring queries

---

## Submission Instructions

1. **Attach:** `SYSTEM_OVERVIEW.md`
2. **Paste:** This prompt
3. **Request:** "Research GTFS PostgreSQL schemas and design optimized Supabase schema"
4. **Expect:** 3-4 hour turnaround

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
