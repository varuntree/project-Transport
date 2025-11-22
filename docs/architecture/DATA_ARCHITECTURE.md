# Data Architecture Specification
**Project:** Sydney Transit App - Data Layer Design
**Version:** 1.0 (Draft - Requires Oracle Review)
**Date:** 2025-11-12
**Dependencies:** SYSTEM_OVERVIEW.md
**Status:** 50% Complete - Awaiting Oracle Consultation

---

## Document Purpose

This document defines how data flows through the Sydney Transit App system:
- GTFS static data ingestion (227MB daily updates from NSW)
- GTFS-RT real-time data polling & caching
- Database schema (Supabase PostgreSQL)
- Redis caching strategy
- Cost optimization for $25/month budget

**Critical Sections Requiring Oracle Consultation:**
1. ⚠️ GTFS-RT Caching Strategy (Section 4)
2. ⚠️ GTFS Static Ingestion Pipeline (Section 5)
3. ⚠️ Database Schema Design (Section 6)
4. ⚠️ Cost Optimization Architecture (Section 9)

---

## 1. Data Sources Overview

### NSW Transport Open Data Hub

**Static Data (GTFS):**
- **Format:** ZIP file containing CSV files (stops.txt, routes.txt, trips.txt, etc.)
- **Size:** ~227 MB compressed
- **Update Frequency:** Daily (updated nightly)
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/schedule/[mode]`
- **Coverage:** All Sydney modes (Trains, Metro, Buses, Ferries, Light Rail)

**Real-Time Data (GTFS-RT):**
- **Format:** Protocol Buffer (binary)
- **Update Frequency:** Every 10-15 seconds
- **Feeds:**
  - Vehicle Positions: `https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/[mode]`
  - Trip Updates: `https://api.transport.nsw.gov.au/v1/gtfs/realtime/[mode]`
  - Service Alerts: `https://api.transport.nsw.gov.au/v1/gtfs/alerts/[mode]`
- **Modes:** buses, ferries, lightrail, nswtrains, sydneytrains, metro

**Trip Planner API:**
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/tp/trip`
- **Rate Limit:** 60,000 free calls/day
- **Purpose:** Multi-modal journey planning (fallback: build custom routing later)

### Rate Limits & Constraints
- **Throttle:** 5 requests/second
- **Daily Quota:** 60,000 requests/day
- **Authentication:** API key in `Authorization: apikey [key]` header
- **Errors:** HTTP 403 (rate limit), HTTP 401 (invalid key)

---

## 2. Data Flow Architecture (High-Level)

```
┌─────────────────────────────────────────────────────────────────┐
│                     NSW TRANSPORT APIS                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │  GTFS Static     │  │   GTFS-RT        │  │ Trip Planner │  │
│  │  (227MB ZIP)     │  │ (10-15s updates) │  │     API      │  │
│  │  Daily updates   │  │  Protobuf feeds  │  │  60K/day     │  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘  │
└───────────┼─────────────────────┼────────────────────┼──────────┘
            │                     │                    │
            │ Daily 3am           │ Every 30-60s       │ On-demand
            │                     │ (Celery)           │ (User request)
            │                     │                    │
┌───────────▼─────────────────────▼────────────────────▼──────────┐
│                  BACKEND DATA LAYER (FastAPI)                    │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Celery Background Workers                     │  │
│  │  ┌─────────────────────┐  ┌──────────────────────────┐   │  │
│  │  │ gtfs_static_sync.py │  │  gtfs_rt_poller.py       │   │  │
│  │  │ - Download 227MB    │  │  - Poll NSW GTFS-RT      │   │  │
│  │  │ - Parse CSV files   │  │  - Parse protobuf        │   │  │
│  │  │ - Transform data    │  │  - Write to Redis cache  │   │  │
│  │  │ - Load to Supabase  │  │  - Trigger alerts        │   │  │
│  │  │ - Schedule: Daily   │  │  - Schedule: Every ??s   │   │  │
│  │  │   3am Sydney time   │  │    ⚠️ ORACLE DECIDES     │   │  │
│  │  └─────────────────────┘  └──────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │   Supabase      │  │      Redis       │  │  File Cache  │   │
│  │  (PostgreSQL)   │  │  (In-Memory)     │  │  (Volumes)   │   │
│  │                 │  │                  │  │              │   │
│  │ - GTFS static   │  │ - GTFS-RT data   │  │ - Raw GTFS   │   │
│  │   (normalized)  │  │   (TTL: ??s)     │  │   ZIP files  │   │
│  │ - User data     │  │ - API responses  │  │              │   │
│  │ - Favorites     │  │ - Rate limiting  │  │              │   │
│  │                 │  │   ⚠️ ORACLE      │  │              │   │
│  │ ⚠️ ORACLE       │  │   DECIDES TTL    │  │              │   │
│  │ DESIGNS SCHEMA  │  │   & STRUCTURE    │  │              │   │
│  └─────────────────┘  └──────────────────┘  └──────────────┘   │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                  FastAPI REST Endpoints                    │  │
│  │  - GET /stops/:id/departures (reads Redis + Supabase)     │  │
│  │  - GET /stops/nearby (reads Supabase, geospatial query)   │  │
│  │  - POST /trips/plan (calls NSW API, caches in Redis)      │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬────────────────────────────────────┘
                               │ HTTPS REST API
                               │
┌──────────────────────────────▼────────────────────────────────────┐
│                        iOS APPLICATION                             │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │                  GRDB SQLite (Local Cache)                 │   │
│  │  - Cached GTFS subset (~30MB optimized)                   │   │
│  │  - Recent searches                                         │   │
│  │  - User favorites (offline access)                         │   │
│  │  ⚠️ ORACLE DECIDES: What data to cache locally?           │   │
│  └───────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Entities & Relationships

### Core GTFS Entities (Standard Specification)

```
Agency (1) ──────< Route (many)
                      │
                      │ (1)
                      │
                      ▼
                   Trip (many)
                      │
                      │ (1)
                      │
                      ▼
                 StopTime (many)
                      │
                      │ (references)
                      │
                      ▼
                   Stop (1)

Calendar ────────< Trip
Shape ──────────< Trip (optional)
```

### Extended Entities (App-Specific)

```
User (Supabase Auth)
  │
  ├──< Favorite (many) ──> Stop/Route
  ├──< SavedTrip (many)
  └──< NotificationPreference (1)

Alert (GTFS-RT)
  │
  └──< AlertAffectedEntity (many) ──> Route/Stop/Trip
```

### Entity Descriptions

**GTFS Static (NSW Standard):**
- **Agency:** Transit operators (e.g., Sydney Trains, NSW TrainLink)
- **Route:** Transit lines (e.g., T1 North Shore Line, 333 Bus)
- **Trip:** Specific journey instance (e.g., T1 departing Central at 8:15am)
- **StopTime:** Scheduled arrival/departure at a stop for a trip
- **Stop:** Physical location (station, bus stop, wharf)
- **Calendar:** Service patterns (weekday, weekend, holiday schedules)
- **Shape:** Geographic path of routes (for map visualization)

**GTFS-RT (Real-Time Updates):**
- **VehiclePosition:** Current location, speed, bearing of vehicles
- **TripUpdate:** Real-time delays, cancellations, platform changes
- **Alert:** Service disruptions, planned work, important notices

**App-Specific (User Data):**
- **User:** Authenticated user (Apple Sign-In, Supabase Auth)
- **Favorite:** User's saved stops/routes for quick access
- **SavedTrip:** Common journeys (e.g., "Home to Work")
- **NotificationPreference:** Alert settings (delay threshold, quiet hours)

---

## 4. ✅ GTFS-RT Caching Strategy (ORACLE REVIEWED)

### Design Overview

**Adaptive polling** with per-mode blob caching, minimal write-amplification, and edge caching coordination.

### Polling Strategy

**Adaptive cadence (peak vs off-peak):**
- **Peak hours** (7-9am, 5-7pm Sydney local):
  - VehiclePositions: 30s
  - TripUpdates: 60s
  - Alerts: 5 min (always)
- **Off-peak**:
  - VehiclePositions: 60s
  - TripUpdates: 90s
  - Alerts: 5 min

**Daily API calls:** ~16,640 NSW calls/day (well under 60K limit, <20K target met)

**Rationale:** Matches human demand patterns, stays within budget, maintains <60s p95 staleness at peaks per GTFS-RT best practices.

### Redis Data Structure

**Per-mode blob model** (not per-entity keys):

```redis
# Vehicle Positions (per mode, all vehicles)
Key: "vp:{mode}:v1"           # e.g., "vp:buses:v1"
Type: String (gzipped JSON)
TTL: 75s
Value: {
  "generated_at": 1731369600,
  "vehicles": [
    {"vehicle_id":"bus_1234", "route_id":"333", "lat":-33.86, "lon":151.21, "bearing":45, "speed":25, "ts":1731369595},
    ...
  ]
}

# Trip Updates (per mode, all trips)
Key: "tu:{mode}:v1"
Type: String (gzipped JSON)
TTL: 90s
Value: {
  "generated_at": 1731369600,
  "trips": [
    {"trip_id":"t_abc", "route_id":"333", "delay_s":90, "stop_time_updates":[...], "sched_rel":"SCHEDULED"},
    ...
  ]
}

# Service Alerts (per mode)
Key: "alerts:{mode}:v1"
Type: String (JSON)
TTL: 300s
Value: {"alerts":[{"id":"a1", "severity":"major", "routes":["T1"], "header":"...", ...}]}

# Precomputed Departures (per stop, hot path)
Key: "departures:{stop_id}"
Type: String (JSON)
TTL: 25-30s
Value: {
  "as_of":1731369603,
  "stale":false,
  "items": [
    {"route":"T1", "headsign":"City", "realtime":true, "mins":3, "scheduled_time":"2025-11-12T08:12:00+11:00", "delay_s":90, "trip_id":"t_abc"},
    ...
  ]
}

# (Optional) Hotness tracking for prefetch
Key: "hot:stop_counts"
Type: Sorted Set
TTL: 1 day rolling
```

**Why blobs?** Minimizes write-amplification (one write/mode/poll vs 100s of per-vehicle writes); pairs well with MGET batching (Upstash counts MGET as 1 command).

### Prefetching Strategy

- **MVP (0-1K users):** No prefetch; cache on demand (simplicity first)
- **At 1K-10K users:** During peak windows, prewarm Top-100 stops every 30s based on rolling ZSET (`hot:stop_counts`) from recent reads + favorites
- **Adaptive:** If `departures:{stop_id}` miss rate >40%, add to hot set for 10 min

### Memory Estimation

| Users | Concurrent (peak) | Redis Memory  |
|------:|------------------:|--------------:|
| 1K    | ~100              | ~7-10 MB      |
| 5K    | ~500              | ~9-12 MB      |
| 10K   | ~1,000            | ~10-13 MB     |

**Well under 256 MB** (Upstash free tier) or 512 MB (Railway paid).

### Celery Worker Pseudocode

```python
# app/workers/gtfs_rt_poller.py
# Beat: runs every 15s, adaptive scheduler inside

MODES = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']
PEAK_HOURS = {7,8,9,17,18,19}

def cadence(now_local):
    peak = now_local.hour in PEAK_HOURS
    return {
        "vehicle": 30 if peak else 60,
        "trip": 60 if peak else 90,
        "alerts": 300
    }

state = {}  # in-memory last_poll timestamps per (mode, feed)

@app.task
def poll_gtfs_rt_feeds():
    now_local = datetime.now(tz=SYDNEY_TZ)
    cad = cadence(now_local)
    for mode in MODES:
        for feed in ("vehicle","trip","alerts"):
            last = state.get((mode,feed))
            due = (last is None) or ((time.time() - last) >= cad[feed])
            if not due or circuit_open(mode, feed):
                continue
            try:
                url = build_url(mode, feed)
                blob_bytes = fetch_nsw_api(url, timeout=5)  # with auth, rate limiter
                parsed = parse_protobuf(blob_bytes, feed)
                normalized = normalize_entities(parsed, feed)  # drop stale >90s
                out = gzip.compress(json.dumps(normalized, separators=(',',':')).encode())

                key = {"vehicle":f"vp:{mode}:v1", "trip":f"tu:{mode}:v1", "alerts":f"alerts:{mode}:v1"}[feed]
                ttl = {"vehicle":75, "trip":90, "alerts":300}[feed]

                # Skip write if header timestamp unchanged
                prev = redis.get(key)
                if prev and json.loads(gzip.decompress(prev)).get("generated_at") == normalized.get("generated_at"):
                    state[(mode,feed)] = time.time()
                    continue

                redis.setex(key, ttl, out)
                state[(mode,feed)] = time.time()
                clear_failures(mode, feed)
            except TemporaryAPIError as e:
                on_failure_with_backoff(mode, feed, e)  # circuit breaker
            time.sleep(0.05 + random.random()*0.05)  # rate limit jitter

# Fast path endpoint
@app.get("/api/v1/stops/{stop_id}/departures")
def get_departures(stop_id: str):
    cached = redis.get(f"departures:{stop_id}")
    if cached:
        return json.loads(cached)
    # Cache miss → compute from blobs
    vp_bus, tu_bus, alerts_bus = redis.mget("vp:buses:v1", "tu:buses:v1", "alerts:buses:v1")
    # (load only relevant modes for this stop)
    merged = compute_departures(stop_id, [vp_bus, tu_bus, ...], gtfs_static=Supabase)
    body = {"as_of": now(), "stale": False, "items": merged}
    redis.setex(f"departures:{stop_id}", 30, json.dumps(body))
    return body
```

### Failure Handling

- **Circuit breaker:** Open after 5 consecutive failures per (mode, feed); reset after 60s
- **Retries:** Max 3 with exponential backoff + jitter
- **Graceful degradation:** Serve stale cache (mark `"stale":true`) up to 3-5 min; fallback to schedule-only if RT absent >5 min
- **Redis unavailable:** FastAPI bypasses cache, computes from Supabase + in-process blobs

### Cloudflare Coordination

Set `Cache-Control: public, max-age=30, s-maxage=30, stale-while-revalidate=30, stale-if-error=600` on departures/alerts endpoints. Cloudflare Free tier respects origin headers; this keeps edge hit rate >90%.

### Scaling Triggers

- **Redis size >400MB sustained 1h:** Upgrade 512MB→1GB
- **Redis commands >500K/day:** Switch to PAYG or fixed plan
- **NSW calls >50K/day:** Lengthen off-peak cadences
- **Cache hit rate <60%:** Add Top-100 prewarm, ensure MGET batching

**Source:** Oracle consultation 01, research-backed (OneBusAway defaults, GTFS-RT best practices, Upstash billing model)

---

## 5. ✅ GTFS Static Ingestion Pipeline (ORACLE REVIEWED)

### The Solution

**Pattern Model** (OTP/R5-style factoring) + **geographic filtering** + **shape optimization** = ~15-20 MB iOS SQLite, ~250-350 MB Supabase DB.

**Key Innovations:**
1. **Replace `stop_times`** with TripPattern + offsets (8-15× compression)
2. **Filter by Greater Sydney polygon** (PostGIS ST_Contains) - removes ~40-60% of NSW data
3. **Simplify + encode shapes** (Douglas-Peucker + Google polyline) for rail/metro/ferry/LR only
4. **Dictionary-code IDs** to compact ints in iOS SQLite
5. **Full daily refresh** (simple, reliable) - no complex incrementals at MVP

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: Download + Validate (Daily 3am Sydney)                 │
│  - Celery: gtfs_static_sync.py                                  │
│  - Download 227MB NSW ZIP, check hash (skip if unchanged)       │
│  - MobilityData validator (schema check)                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│  STEP 2: Parse + Filter (Sydney Only)                           │
│  - Use Partridge (view-based filtering, memory-efficient)       │
│  - PostGIS: ST_Contains(sydney_polygon, stop_coords)            │
│  - Keep trips with ≥1 in-boundary stop_time                     │
│  - Drop ~40-60% NSW data → Sydney subset                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│  STEP 3: Pattern Model Transform                                │
│  - Group trips by (route, direction, stop sequence) → patterns  │
│  - Per pattern: store stop offsets (median, TOD-bucketed)       │
│  - Per trip: (pattern_id, service_id, start_time_secs)          │
│  - Result: 8-15× compression vs raw stop_times                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│  STEP 4: Load Supabase (COPY bulk, blue/green swap)             │
│  - COPY to staging tables (drop indexes first)                  │
│  - Rebuild indexes, ANALYZE                                     │
│  - Validate: row counts, ref integrity, geo bounds              │
│  - If OK → atomic rename stg_* → live; else keep prev           │
│  - Stores pattern model (~250-350 MB < 500 MB free tier)        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│  STEP 5: Generate iOS SQLite                                    │
│  - Dictionary-code IDs → compact ints (route_id → rid)          │
│  - Simplify shapes (Douglas-Peucker ~10-30m) → encode polyline  │
│  - Keep rail/metro/ferry/LR shapes only (drop bus)              │
│  - WITHOUT ROWID, page_size=8192, VACUUM                        │
│  - journal_mode=OFF (immutable read-only)                       │
│  - Result: ~15-20 MB SQLite file                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│  STEP 6: Upload + CDN (Cloudflare Free)                         │
│  - Upload to Supabase Storage (within 1GB free tier)            │
│  - Front with Cloudflare (unlimited bandwidth)                  │
│  - Expose /api/v1/gtfs/version (feed_version, sha256, URL)      │
│  - iOS: Background Assets download if version changed           │
│  - App opens with immutable=1 (no WAL/SHM companions)           │
└─────────────────────────────────────────────────────────────────┘
```

### Feed Selection Architecture (MODE_DIRS vs COVERAGE_EXTRA_DIRS)

**Critical Distinction for GTFS-RT Alignment:**

**MODE_DIRS** (Pattern model feeds):
- Feeds: `sydneytrains`, `metro`, `buses`, `sydneyferries`, `mff`, `complete` (filtered)
- Provide `trips`/`stop_times` for pattern extraction
- **MUST verify trip_id alignment with GTFS-RT feeds** - real-time departures depend on matching static trip_ids
- Light rail: Use `complete` feed filtered by `route_type IN (0, 900)` (lightrail feed incomplete/contaminated)

**COVERAGE_EXTRA_DIRS** (Coverage-only feeds):
- Feeds: `complete`, `ferries_all`, `nswtrains`, `regionbuses`
- Provide `agencies`/`stops`/`routes` only (NO `trips`/`stop_times` used)
- Improve stop coverage (ferry wharves like Davistown, regional stops)
- No GTFS-RT alignment concerns

**Why exclude lightrail feed from MODE_DIRS (Nov 2024):**
- lightrail feed returns only L1 (1 route, ~1,300 trips) vs complete feed (6 routes, ~6,750 trips, ~126 stops)
- lightrail feed contaminated with train platform stops (`route_type=0` Platform stops without "Light Rail" in name)
- Must filter complete feed by `route_type IN (0, 900)` for light rail patterns
- Prefix trip_ids to avoid collisions: `complete_lr_{original_trip_id}`

See `backend/docs/gtfs-coverage-matrix.md` for detailed feed selection matrix.

### Data Filtering Strategy

**Geographic (Sydney Only):**
- Ship ABS Greater Sydney GCCSA boundary (PostGIS polygon)
- `ST_Contains(boundary.geom, stop_point)` → keep in-boundary stops
- Keep trips referencing those stops → prune routes/shapes/calendars
- **Saves:** ~40-60% of NSW rows

**Temporal (No Day-Slicing):**
- Keep all trips within feed validity window
- Apply `calendar`/`calendar_dates` at query time (not duplication)
- Optional: prune service_ids with no active date in next 30d

**Field Pruning:**
- **Drop:** `stop_desc`, `zone_id`, `block_id`, `wheelchair_boarding` (optional)
- **Keep:** All core GTFS fields needed for schedule queries
- **Shapes:** Rail/metro/ferry/LR only (drop bus shapes)

### Pattern Model (Trip Factoring)

**Why:** Raw `stop_times` = 70-85% of GTFS size (millions of rows); pattern model gives 8-15× compression while preserving fidelity.

**Design:**
```sql
-- TripPattern: unique stop sequence
CREATE TABLE patterns (
  pattern_id BIGSERIAL PRIMARY KEY,
  route_id TEXT NOT NULL,
  direction_id INT,
  shape_id TEXT
);

-- Offsets per stop (median across trips)
CREATE TABLE pattern_stops (
  pattern_id BIGINT NOT NULL REFERENCES patterns,
  seq INT NOT NULL,
  stop_id TEXT NOT NULL REFERENCES stops,
  offset_secs INT NOT NULL,  -- seconds from trip start_time
  PRIMARY KEY (pattern_id, seq)
);

-- Trips reference patterns
CREATE TABLE trips_c (
  trip_id TEXT PRIMARY KEY,
  pattern_id BIGINT NOT NULL REFERENCES patterns,
  service_id TEXT NOT NULL,
  start_time_secs INT NOT NULL,  -- first stop departure
  headsign TEXT
);
```

**Query for departures:**
```sql
-- Departure time = start_time_secs + offset_secs
SELECT t.trip_id, r.route_short_name, t.headsign,
       (t.start_time_secs + ps.offset_secs) AS dep_secs
FROM pattern_stops ps
JOIN trips_c t ON t.pattern_id = ps.pattern_id
JOIN routes r ON r.route_id = (SELECT route_id FROM patterns WHERE pattern_id = ps.pattern_id)
JOIN service_active_dates sad ON sad.service_pk = t.service_id AND sad.service_date = :today
WHERE ps.stop_id = :stop_id
  AND (t.start_time_secs + ps.offset_secs) >= :now_secs
ORDER BY dep_secs LIMIT 5;
```

### iOS SQLite Optimization

**WITHOUT ROWID + Dictionary Coding:**
```sql
-- Map text IDs → compact ints
CREATE TABLE dict_route (rid INTEGER PRIMARY KEY, route_id TEXT UNIQUE) WITHOUT ROWID;
CREATE TABLE dict_stop  (sid INTEGER PRIMARY KEY, stop_id TEXT UNIQUE) WITHOUT ROWID;

-- Stops with int keys
CREATE TABLE stops (
  sid INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  name_norm TEXT NOT NULL,  -- folded ASCII for prefix search
  lat REAL NOT NULL,
  lon REAL NOT NULL
) WITHOUT ROWID;

-- Open immutable
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA page_size=8192;
VACUUM;
```

**Open in iOS:** `file:gtfs.sqlite?mode=ro&immutable=1` (no WAL/SHM companions)

### Distribution Strategy

**MVP:** Download-on-first-launch (not bundled)
- Smaller app binary (<10 MB code + assets)
- 15-20 MB SQLite downloaded via iOS Background Assets (Wi-Fi preferred)
- Only downloads when `feed_version` changes
- Cloudflare CDN (free, no bandwidth meter)

**Update Flow:**
1. App checks `/api/v1/gtfs/version` on launch
2. If version changed → queue Background Assets download
3. iOS fetches in background (Wi-Fi, low priority)
4. GRDB opens new file when complete; atomic swap
5. Old file deleted

### Validation Checks

**Post-load SQL queries:**
```sql
-- Row counts (establish baselines)
SELECT COUNT(*) AS stops FROM stops;          -- Expect 10k-25k Sydney
SELECT COUNT(*) AS routes FROM routes;        -- Expect 400-1200
SELECT COUNT(*) AS patterns FROM patterns;    -- Expect 2k-10k
SELECT COUNT(*) AS trips FROM trips_c;        -- Expect 40k-120k

-- Referential integrity
SELECT COUNT(*) FROM trips_c t LEFT JOIN patterns p ON t.pattern_id=p.pattern_id WHERE p.pattern_id IS NULL;

-- Geo bounds
SELECT COUNT(*) FROM stops s, sydney_boundary b
WHERE NOT ST_Contains(b.geom, ST_Point(s.stop_lon, s.stop_lat));

-- Pattern monotonicity
SELECT COUNT(*) FROM (
  SELECT pattern_id, seq, offset_secs,
         LAG(offset_secs) OVER (PARTITION BY pattern_id ORDER BY seq) AS prev
  FROM pattern_stops
) q WHERE prev IS NOT NULL AND offset_secs < prev;
```

### Data Cleanup Before Load (Prevent Stale Accumulation)

**Problem:** Batch upserts without cleanup accumulate stale rows when feeds shrink (e.g., lightrail feed had L1/L2/L3, now only L1).

**Solution:** Pre-load cleanup for route_types being reloaded

```python
def _cleanup_stale_light_rail_data(supabase) -> None:
    """Delete stale light rail data before loading fresh feed.

    Critical for preventing contamination accumulation when feeds change.
    Must maintain FK integrity order: pattern_stops → trips → patterns → routes
    """
    # Get current light rail route_ids
    routes_response = supabase.table("routes") \\
        .select("route_id") \\
        .in_("route_type", [0, 900]) \\
        .execute()

    lr_route_ids = [r["route_id"] for r in routes_response.data]

    if not lr_route_ids:
        return  # No existing light rail data

    # Delete in reverse FK dependency order
    # 1. pattern_stops (references patterns)
    supabase.rpc("delete_pattern_stops_by_route_type", {"route_types": [0, 900]})

    # 2. trips (references patterns)
    supabase.rpc("delete_trips_by_route_type", {"route_types": [0, 900]})

    # 3. patterns (references routes)
    supabase.rpc("delete_patterns_by_route_type", {"route_types": [0, 900]})

    # 4. routes (no dependencies)
    supabase.table("routes").delete().in_("route_type", [0, 900]).execute()
```

**When to use:**
- Before loading MODE_DIRS feeds (pattern model data)
- Especially for route_types with known feed issues (light rail)
- Not needed for coverage-only feeds (simple upserts)

### Size Estimates

| Component              | Size        | Notes                                    |
|-----------------------|------------:|------------------------------------------|
| **Supabase DB**        | 250-350 MB  | Pattern model + Sydney subset < 500 MB   |
| **iOS SQLite**         | 15-20 MB    | Dict-coded, WITHOUT ROWID, VACUUM        |
| **App Binary**         | <10 MB      | Code + assets (SQLite downloaded)        |
| **Total App (first run)** | <35 MB   | Binary + SQLite = well under 50 MB       |

**Source:** Oracle consultations 02 & 04, research-backed (OTP pattern model, Partridge filtering, Douglas-Peucker simplification, SQLite size tuning)

---

## 6. ⚠️ Database Schema Design (ORACLE DECISION NEEDED)

### Supabase (PostgreSQL) Schema

**Purpose:** Store GTFS static data, user data, and support real-time queries

**Constraints:**
- Free tier: 500MB database size
- Must support geospatial queries (nearby stops)
- Optimize for read-heavy workload (80% reads, 20% writes)
- iOS app queries frequently (minimize latency)

### GTFS Load Validation Thresholds

**Minimum counts per mode (fail build if below):**

| Mode | route_type | min_routes | min_trips | min_distinct_stops |
|------|-----------|-----------|-----------|-------------------|
| Light Rail | 0, 900 | 3 | 6000 | 100 |
| Sydney Trains | 2 | 10 | 15000 | 300 |
| Metro | 1 | 1 | 2000 | 13 |
| Buses | 3 | 200 | 40000 | 3000 |
| Ferries | 4 | 5 | 500 | 30 |

**Contamination checks:**
- Light rail (`route_type` 0/900): Pattern_stops with `stop_name LIKE '%Platform%' AND stop_name NOT LIKE '%Light Rail%'` must be 0
- Train (`route_type` 2): No light rail stops (check stop_name patterns)

**Feed delta logging:**
```python
# Before load
old_counts = get_route_type_counts(db)

# After load
new_counts = get_route_type_counts(db)

for route_type in [0, 1, 2, 3, 4, 900]:
    old = old_counts.get(route_type, 0)
    new = new_counts.get(route_type, 0)
    delta_pct = ((new - old) / old * 100) if old > 0 else 0

    logger.info("route_type_delta",
                route_type=route_type,
                old=old, new=new, delta_pct=delta_pct)

    if delta_pct < -10:
        logger.error("coverage_regression",
                     route_type=route_type, delta_pct=delta_pct)
```

**Rationale:**
- Prevents silent data loss when feeds change
- Catches contamination issues (Nov 2024: light rail had 116 train platforms)
- Alerts on >10% coverage drops for regression detection

### Preliminary Schema (Needs Oracle Review)

#### GTFS Static Tables

```sql
-- ⚠️ ORACLE: Review & optimize this schema

-- Agencies
CREATE TABLE agencies (
    agency_id VARCHAR(50) PRIMARY KEY,
    agency_name VARCHAR(255) NOT NULL,
    agency_url VARCHAR(255),
    agency_timezone VARCHAR(50) NOT NULL
);

-- Routes
CREATE TABLE routes (
    route_id VARCHAR(50) PRIMARY KEY,
    agency_id VARCHAR(50) REFERENCES agencies(agency_id),
    route_short_name VARCHAR(50),
    route_long_name VARCHAR(255),
    route_type INT NOT NULL, -- 0=tram, 1=metro, 2=rail, 3=bus, 4=ferry
    route_color VARCHAR(6),
    route_text_color VARCHAR(6)
);
CREATE INDEX idx_routes_agency ON routes(agency_id);
CREATE INDEX idx_routes_type ON routes(route_type);

-- Stops (with PostGIS for geospatial)
CREATE TABLE stops (
    stop_id VARCHAR(50) PRIMARY KEY,
    stop_code VARCHAR(50),
    stop_name VARCHAR(255) NOT NULL,
    stop_desc TEXT,
    stop_lat DECIMAL(10, 8) NOT NULL,
    stop_lon DECIMAL(11, 8) NOT NULL,
    location GEOGRAPHY(POINT, 4326), -- PostGIS for geospatial queries
    zone_id VARCHAR(50),
    stop_url VARCHAR(255),
    location_type INT DEFAULT 0,
    parent_station VARCHAR(50),
    wheelchair_boarding INT DEFAULT 0
);
CREATE INDEX idx_stops_location ON stops USING GIST(location);
CREATE INDEX idx_stops_name ON stops USING GIN(to_tsvector('english', stop_name));
CREATE INDEX idx_stops_parent ON stops(parent_station);

-- Trips
CREATE TABLE trips (
    trip_id VARCHAR(50) PRIMARY KEY,
    route_id VARCHAR(50) REFERENCES routes(route_id),
    service_id VARCHAR(50) NOT NULL,
    trip_headsign VARCHAR(255),
    trip_short_name VARCHAR(50),
    direction_id INT,
    block_id VARCHAR(50),
    shape_id VARCHAR(50),
    wheelchair_accessible INT DEFAULT 0
);
CREATE INDEX idx_trips_route ON trips(route_id);
CREATE INDEX idx_trips_service ON trips(service_id);

-- Stop Times (largest table - needs optimization)
CREATE TABLE stop_times (
    id BIGSERIAL PRIMARY KEY,
    trip_id VARCHAR(50) REFERENCES trips(trip_id),
    arrival_time TIME NOT NULL,
    departure_time TIME NOT NULL,
    stop_id VARCHAR(50) REFERENCES stops(stop_id),
    stop_sequence INT NOT NULL,
    stop_headsign VARCHAR(255),
    pickup_type INT DEFAULT 0,
    drop_off_type INT DEFAULT 0,
    shape_dist_traveled DECIMAL(10, 2)
);
CREATE INDEX idx_stop_times_trip ON stop_times(trip_id, stop_sequence);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id, departure_time);

-- ⚠️ ORACLE QUESTION: Should we partition stop_times by route or date?
-- This table will be massive (millions of rows)

-- Calendar (service patterns)
CREATE TABLE calendar (
    service_id VARCHAR(50) PRIMARY KEY,
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

-- Calendar Dates (exceptions)
CREATE TABLE calendar_dates (
    service_id VARCHAR(50) NOT NULL,
    date DATE NOT NULL,
    exception_type INT NOT NULL, -- 1=added, 2=removed
    PRIMARY KEY (service_id, date)
);

-- Shapes (route paths for maps)
CREATE TABLE shapes (
    shape_id VARCHAR(50) NOT NULL,
    shape_pt_lat DECIMAL(10, 8) NOT NULL,
    shape_pt_lon DECIMAL(11, 8) NOT NULL,
    shape_pt_sequence INT NOT NULL,
    shape_dist_traveled DECIMAL(10, 2),
    PRIMARY KEY (shape_id, shape_pt_sequence)
);
CREATE INDEX idx_shapes_id ON shapes(shape_id);

-- ⚠️ ORACLE QUESTION: Store shapes as PostGIS LineString instead?
```

#### User Data Tables

```sql
-- Users (managed by Supabase Auth, but we extend with preferences)
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id),
    display_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Favorites
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    entity_type VARCHAR(20) NOT NULL, -- 'stop' or 'route'
    entity_id VARCHAR(50) NOT NULL, -- stop_id or route_id
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, entity_type, entity_id)
);
CREATE INDEX idx_favorites_user ON favorites(user_id, display_order);

-- Saved Trips
CREATE TABLE saved_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    trip_name VARCHAR(100) NOT NULL, -- e.g., "Home to Work"
    origin_stop_id VARCHAR(50),
    destination_stop_id VARCHAR(50),
    origin_address TEXT,
    destination_address TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_saved_trips_user ON saved_trips(user_id, last_used_at DESC);

-- Notification Preferences
CREATE TABLE notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    alerts_enabled BOOLEAN DEFAULT TRUE,
    delay_threshold_minutes INT DEFAULT 5,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    apns_device_token VARCHAR(255), -- APNs push token
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Row Level Security (RLS) Policies

```sql
-- ⚠️ ORACLE: Review security model

-- Enable RLS on user tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own data
CREATE POLICY "Users manage own profile"
    ON user_profiles FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users manage own favorites"
    ON favorites FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users manage own trips"
    ON saved_trips FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users manage own preferences"
    ON notification_preferences FOR ALL
    USING (auth.uid() = user_id);

-- GTFS tables are public read (no RLS needed, read-only for users)
```

### Questions for Oracle:

1. **Indexing Strategy:**
   - Which indexes are critical for performance?
   - Which can we skip to save disk space?
   - Composite indexes vs single-column indexes?

2. **Partitioning:**
   - Should `stop_times` be partitioned? (millions of rows)
   - Partition by route? By service date?
   - Impact on query performance vs complexity?

3. **Denormalization:**
   - Denormalize frequently joined data?
   - E.g., embed route info in trips table?
   - Trade-off: faster queries vs larger DB size?

4. **Geospatial Optimization:**
   - PostGIS best practices for nearby stops queries?
   - Optimal GIST index configuration?
   - Bounding box queries vs radius queries?

5. **Cost Control:**
   - Estimated DB size with full Sydney GTFS?
   - How to stay under 500MB free tier?
   - What data to exclude if space limited?

6. **Materialized Views:**
   - Should we create materialized views for common queries?
   - E.g., "next departures by stop" view?
   - Refresh strategy?

**See:** `oracle/specs/oracle_prompts/03_database_schema.md` for detailed Oracle prompt

---

## 7. iOS Local Persistence (GRDB SQLite)

### Purpose
- Cache GTFS data for offline access (optional P1 feature)
- Recent searches (instant results)
- User favorites (available offline)
- Reduce network requests

### Schema (Mirrors Supabase Subset)

```swift
// GRDB Table Definitions

struct Stop: Codable, FetchableRecord, PersistableRecord {
    var stopId: String
    var stopCode: String?
    var stopName: String
    var stopLat: Double
    var stopLon: Double
    var wheelchairBoarding: Int

    static let databaseTableName = "stops"
}

struct Route: Codable, FetchableRecord, PersistableRecord {
    var routeId: String
    var routeShortName: String
    var routeLongName: String
    var routeType: Int
    var routeColor: String

    static let databaseTableName = "routes"
}

struct CachedDeparture: Codable, FetchableRecord, PersistableRecord {
    var stopId: String
    var routeId: String
    var tripId: String
    var departureTime: Date
    var delaySeconds: Int?
    var cachedAt: Date

    static let databaseTableName = "cached_departures"
}

struct Favorite: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var entityType: String // "stop" or "route"
    var entityId: String
    var displayOrder: Int
    var syncedAt: Date?

    static let databaseTableName = "favorites"
}
```

### Database Setup

```swift
// GRDBManager.swift

class GRDBManager {
    static let shared = GRDBManager()

    private var dbQueue: DatabaseQueue!

    init() {
        let databaseURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("transit.sqlite")

        dbQueue = try! DatabaseQueue(path: databaseURL.path)

        try! migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "stops") { t in
                t.column("stopId", .text).primaryKey()
                t.column("stopCode", .text)
                t.column("stopName", .text).notNull()
                t.column("stopLat", .double).notNull()
                t.column("stopLon", .double).notNull()
                t.column("wheelchairBoarding", .integer).notNull()
            }

            try db.create(index: "idx_stops_name", on: "stops", columns: ["stopName"])

            // ⚠️ More tables created based on Oracle's schema decisions
        }

        return migrator
    }

    // Query methods
    func fetchNearbyStops(lat: Double, lon: Double, radius: Double) throws -> [Stop] {
        // ⚠️ ORACLE: Optimize this query
        // Haversine formula for distance calculation in SQLite?
        try dbQueue.read { db in
            try Stop.fetchAll(db, sql: """
                SELECT * FROM stops
                WHERE (stopLat - ?) * (stopLat - ?) + (stopLon - ?) * (stopLon - ?) < ?
                ORDER BY (stopLat - ?) * (stopLat - ?) + (stopLon - ?) * (stopLon - ?)
                LIMIT 20
                """,
                arguments: [lat, lat, lon, lon, radius * radius, lat, lat, lon, lon]
            )
        }
    }
}
```

### Sync Strategy

```
User adds favorite (offline)
    ↓
Write to local SQLite (immediate)
    ↓
Queue sync request (when network available)
    ↓
POST /api/v1/favorites (to Supabase via FastAPI)
    ↓
Update local record with server UUID
    ↓
Mark as synced
```

**Conflict Resolution:**
- Client wins (user actions on device are authoritative)
- Last-write-wins timestamp (if conflicts detected)

---

## 8. Redis Data Structures

### Cache Categories

**1. GTFS-RT Real-Time Data (Hot Cache)**
```redis
# Key pattern: "gtfs-rt:{feed_type}:{entity_id}"

# Vehicle positions
Key: "gtfs-rt:vehicle:bus_1234"
Type: Hash
TTL: 30 seconds (⚠️ Oracle decides optimal)
Fields:
    vehicle_id: "bus_1234"
    route_id: "333"
    trip_id: "trip_12345"
    lat: "-33.8688"
    lon: "151.2093"
    bearing: "45"
    speed: "25"
    timestamp: "1699876543"

# Trip updates (delays)
Key: "gtfs-rt:trip:trip_12345"
Type: Hash
TTL: 60 seconds (⚠️ Oracle decides)
Fields:
    trip_id: "trip_12345"
    route_id: "T1"
    delay_seconds: "120"
    updated_at: "1699876543"

# Service alerts
Key: "gtfs-rt:alerts:trains"
Type: String (JSON array)
TTL: 300 seconds (5 minutes, ⚠️ Oracle decides)
Value: JSON array of alerts
```

**2. API Response Cache (Warm Cache)**
```redis
# Departures by stop
Key: "api:departures:stop_12345"
Type: String (JSON)
TTL: 30 seconds (⚠️ Oracle decides)
Value: JSON response from /stops/{id}/departures

# Trip planning results
Key: "api:trip:{origin_hash}:{dest_hash}"
Type: String (JSON)
TTL: 600 seconds (10 minutes, frequently requested routes)
Value: JSON response from NSW Trip Planner API
```

**3. Rate Limiting (Leaky Bucket)**
```redis
# Per-user rate limit
Key: "ratelimit:user:{user_id}"
Type: String (counter)
TTL: 60 seconds
Value: Request count
Limit: 60 requests/minute per user

# Per-IP rate limit (anonymous users)
Key: "ratelimit:ip:{ip_address}"
Type: String (counter)
TTL: 60 seconds
Value: Request count
Limit: 20 requests/minute per IP
```

**4. Session & Queue Data**
```redis
# Celery task queue (automatic, managed by Celery)
Key: "celery:task:{task_id}"

# User sessions (if not using Supabase Auth only)
Key: "session:{session_id}"
Type: Hash
TTL: 3600 seconds (1 hour)
```

### Memory Estimation

⚠️ **ORACLE QUESTION:** Estimate Redis memory usage:
- At 1K users (MVP)
- At 10K users (growth phase)
- Worst-case scenario (peak commute hour)

**Back-of-envelope calculation (needs Oracle validation):**
```
Assumptions:
- 2000 stops in Sydney
- 100 active trips at peak
- 50 active vehicles per mode (5 modes = 250 total)
- 10% of users active simultaneously (1K users = 100 concurrent)

GTFS-RT data:
- Vehicles: 250 vehicles × 200 bytes ≈ 50 KB
- Trips: 100 trips × 150 bytes ≈ 15 KB
- Alerts: 20 alerts × 500 bytes ≈ 10 KB

API cache:
- Departures: 100 active stops × 2 KB ≈ 200 KB
- Trip plans: 50 cached plans × 5 KB ≈ 250 KB

Rate limiting:
- Users: 100 active × 50 bytes ≈ 5 KB

Total: ~530 KB at 1K users (trivial for Redis)

At 10K users (1K concurrent):
- 10x multiplier ≈ 5 MB (still trivial)

⚠️ ORACLE: Validate these estimates with real-world GTFS-RT data
```

---

## 9. ⚠️ Cost Optimization Architecture (ORACLE DECISION NEEDED)

### Budget Constraints

**MVP (0-1K users):**
- Target: <$25/month total infrastructure
- Supabase: Free tier (500MB DB, 50K MAU, 1GB storage)
- Railway/Fly.io: $5-20/month (1 instance)
- Redis: Included in Railway or Upstash free tier (10K req/day)
- CloudFlare: Free (unlimited bandwidth)
- Total: $5-25/month ✅

**Growth (1K-10K users):**
- Target: <$150/month
- Supabase: Still free tier (if optimized)
- Railway/Fly.io: $50-100/month (scaled instances)
- Redis: $10-20/month (larger instance)
- CloudFlare: Free
- Total: $60-120/month ✅

### Cost Risks (Where Bills Could Explode)

**⚠️ ORACLE: Design safeguards for these scenarios**

**1. Runaway Celery Tasks**
```python
# Scenario: GTFS-RT poller runs in infinite loop
# Impact: Thousands of NSW API calls/minute → rate limit + quota exhaustion

# Safeguard needed:
# - Task timeout (kill after X seconds)
# - Max retries (fail after 3 attempts)
# - Circuit breaker (stop polling if NSW API down)
# - Alert developer if task fails >5 times/hour
```

**2. Redis Memory Explosion**
```redis
# Scenario: TTLs not set, cache grows unbounded
# Impact: Railway Redis instance scales up → $50/month → $200/month

# Safeguard needed:
# - All keys MUST have TTL (enforce in code)
# - Eviction policy: volatile-lru (evict keys with TTL first)
# - Memory limit: 512 MB (alert at 80% = 410 MB)
# - Monitor: Dashboard showing memory usage trend
```

**3. Supabase Storage Leak**
```
# Scenario: Daily GTFS downloads never cleaned up
# Impact: 227 MB/day × 30 days = 6.8 GB → exceed 1 GB free tier

# Safeguard needed:
# - Retention policy: Keep only last 7 days of GTFS files
# - Automated cleanup: Celery task runs weekly
# - Alert at 800 MB storage used (80% of 1 GB)
```

**4. API Call Spike**
```
# Scenario: App goes viral, 10K users overnight
# Impact: NSW API quota (60K/day) exhausted by noon

# Safeguard needed:
# - Aggressive caching (reduce API calls by 80%)
# - Rate limiting on our side (queue requests, don't forward all)
# - Alert at 80% quota (48K calls/day)
# - Graceful degradation (serve cached data if quota exceeded)
```

### Questions for Oracle:

1. **Monitoring & Alerts:**
   - What metrics to track? (API calls/day, DB size, Redis memory, etc.)
   - What thresholds trigger alerts? (80% of quota/limit?)
   - Simple dashboard design (Supabase table + SQL view?)

2. **Cost Triggers:**
   - At what user count should we upgrade from free tier?
   - Database size trigger: Migrate to paid plan at X MB?
   - Redis memory trigger: Upgrade instance at X MB?

3. **Optimization Strategies:**
   - Which optimizations give best ROI? (caching > compute?)
   - Can we stay on free tier longer with X optimization?
   - When to add complexity (read replicas, sharding)?

4. **Scaling Thresholds:**
   - Clear metric-driven triggers for:
     - Adding Redis replica
     - Upgrading Supabase plan
     - Scaling backend instances
     - Adding database read replicas

**See:** `oracle/specs/oracle_prompts/04_cost_optimization.md` for detailed Oracle prompt

---

## 10. Data Migration Strategy

### Initial Load (First Time Setup)

```
Step 1: Set up Supabase project
    ↓
Step 2: Run schema SQL scripts (from oracle_prompts/03 solution)
    ↓
Step 3: Deploy FastAPI + Celery to Railway/Fly.io
    ↓
Step 4: Manually trigger gtfs_static_sync.py (first run)
    ↓
Step 5: Wait for GTFS data to load (~30 min for 227 MB)
    ↓
Step 6: Verify data integrity (row counts, spot checks)
    ↓
Step 7: Enable Celery Beat schedule (daily updates)
    ↓
Step 8: Enable GTFS-RT poller (real-time updates)
```

### Ongoing Updates

**Daily (GTFS Static):**
```
3:00 AM Sydney time: Celery Beat triggers gtfs_static_sync.py
    ↓
Download latest GTFS ZIP from NSW
    ↓
Compare version/timestamp with previous
    ↓
If changed: Parse, transform, load to Supabase
If unchanged: Skip (save compute)
    ↓
Generate updated iOS SQLite export (if offline mode enabled)
    ↓
Upload to CloudFlare CDN (for app downloads)
    ↓
Log completion, alert if failed
```

**Every 30-60 seconds (GTFS-RT):**
```
Celery Beat triggers gtfs_rt_poller.py
    ↓
Fetch VehiclePositions, TripUpdates, Alerts from NSW
    ↓
Parse Protocol Buffers
    ↓
Write to Redis (with TTL)
    ↓
Check for significant delays (>5 min)
    ↓
If delay affecting user favorites: Trigger alert_engine.py
    ↓
Alert engine matches delay to user subscriptions
    ↓
Queue APNs notification (apns_worker.py)
```

### Data Validation

⚠️ **ORACLE: Design validation rules**

```python
# Validation checks after GTFS static load

def validate_gtfs_data():
    checks = {
        "stops_count": "SELECT COUNT(*) FROM stops",  # Expect ~2000 for Sydney
        "routes_count": "SELECT COUNT(*) FROM routes",  # Expect ~500
        "trips_count": "SELECT COUNT(*) FROM trips",  # Expect ~50K
        "orphan_trips": "SELECT COUNT(*) FROM trips t LEFT JOIN routes r ON t.route_id = r.route_id WHERE r.route_id IS NULL",  # Expect 0
        "invalid_coords": "SELECT COUNT(*) FROM stops WHERE stop_lat < -90 OR stop_lat > 90 OR stop_lon < -180 OR stop_lon > 180",  # Expect 0
    }

    # Run checks, alert if anomalies detected
    # ⚠️ ORACLE: What other validation checks are critical?
```

---

## 11. Disaster Recovery & Backups

### Supabase Automatic Backups
- Point-in-time recovery (PITR) enabled on Pro plan
- Free tier: Daily backups (retained 7 days)
- Recovery: Supabase dashboard → Restore to timestamp

### File Backups (GTFS Static)
```bash
# Railway/Fly.io volumes persist automatically
# Backup strategy:

# Option 1: Keep last 7 daily GTFS downloads (1.6 GB total)
# Option 2: Upload to Supabase Storage (within 1 GB free tier)
# Option 3: Upload to S3/CloudFlare R2 (minimal cost)

# ⚠️ ORACLE: Recommend backup strategy (cost vs recovery time)
```

### Redis (Cache) - No Backups Needed
- Cache can be rebuilt from Supabase + NSW APIs
- No persistent data in Redis (all ephemeral)
- On Redis crash: Cache misses → rebuild from source

### Recovery Scenarios

**Scenario 1: Supabase Outage**
```
iOS app: Gracefully degrade to cached SQLite data
Backend: Return 503 errors with retry-after header
User experience: "Server temporarily unavailable, showing cached data"
Recovery: Wait for Supabase recovery (99.9% uptime SLA)
```

**Scenario 2: Redis Crash**
```
Backend: Detect Redis unavailable (connection error)
Fallback: Query Supabase directly (slower but functional)
User experience: Slower response times (~200ms → ~500ms)
Recovery: Restart Redis instance, cache rebuilds automatically
```

**Scenario 3: NSW API Down**
```
Backend: Circuit breaker detects failures
Fallback: Serve last cached GTFS-RT data (mark as stale)
User experience: "Real-time data unavailable, showing scheduled times"
Recovery: Wait for NSW API recovery, resume polling
```

---

## 12. Open Questions & Next Steps

### Awaiting Oracle Decisions

1. ✅ **Section 4:** GTFS-RT caching strategy (TTLs, prefetching, Redis structure)
2. ✅ **Section 5:** GTFS static ingestion pipeline (227MB → <50MB app)
3. ✅ **Section 6:** Database schema design (Supabase tables, indexes, optimization)
4. ✅ **Section 7:** Cost optimization architecture (safeguards, monitoring, triggers)

### After Oracle Consultation

**Update this document with:**
- Oracle's recommended caching strategy (replace Section 4)
- Oracle's GTFS pipeline design (replace Section 5)
- Oracle's optimized schema (replace Section 6)
- Oracle's cost optimization plan (replace Section 9)

**Then create:**
- BACKEND_SPECIFICATION.md (FastAPI endpoints, Celery tasks)
- IOS_APP_SPECIFICATION.md (MVVM architecture, ViewModels)
- INTEGRATION_CONTRACTS.md (API contracts, auth flows)

---

## 13. Success Criteria

This data architecture succeeds if:

✅ **Performance:**
- Real-time queries: <200ms p95 response time
- Nearby stops query: <100ms (geospatial index optimized)
- GTFS static sync: <30 minutes daily

✅ **Cost:**
- MVP (1K users): <$25/month total infrastructure
- Growth (10K users): <$150/month
- Database: Stay under 500MB free tier for 5K+ users

✅ **Reliability:**
- Data freshness: <60 seconds stale (real-time)
- Uptime: 99.9% (allow 43 min downtime/month)
- Graceful degradation when upstream APIs fail

✅ **Scalability:**
- Architecture supports 10K users without major refactor
- Clear triggers for when to scale (metric-driven)
- Modular design allows component upgrades independently

---

**Document Status:** 🟡 50% Complete - Awaiting Oracle Review
**Critical Blockers:** 4 Oracle consultations required (Sections 4, 5, 6, 9)
**Next Step:** Create Oracle prompt files, submit for consultation
**Last Updated:** 2025-11-12
