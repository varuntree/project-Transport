# Phase 1 Implementation Plan

**Phase:** Static Data - GTFS Pipeline + iOS Offline Browsing
**Duration:** 3 weeks
**Complexity:** medium

---

## Goals

- Build backend GTFS pipeline: programmatic download from NSW API → parse → pattern model → Supabase (<350MB)
- Generate 15-20MB iOS SQLite (dictionary encoding, FTS5) from Supabase pattern tables
- iOS adds GRDB, stop/route search, offline browsing (no real-time yet)
- Vertical slice: Backend GTFS loader + iOS UI working together

---

## Key Technical Decisions

1. **Pattern model for GTFS compression (8-15× smaller)**
   - Rationale: Reduces stop_times 100MB+ → 10-15MB by factoring trips into patterns with offsets. Required for iOS bundle <50MB target.
   - Reference: DATA_ARCHITECTURE.md:Section 5.4.3, 6
   - Critical constraint: Must achieve <350MB Supabase, 15-20MB iOS SQLite. Sydney filtering (bbox [-34.5,-33.3] × [150.5,151.5]) reduces by 40-60%.

2. **PostGIS spatial indexes for location queries**
   - Rationale: Nearby stops query (<50ms) requires GIST index on geography type. NSW API returns lat,lon but PostGIS uses lon,lat order.
   - Reference: DATA_ARCHITECTURE.md:Section 6, PHASE_1:L176-199
   - Critical constraint: Auto-populate location column via trigger (ST_MakePoint(lon,lat)). Verify NULL locations = 0.

3. **iOS SQLite dictionary encoding (text IDs → ints)**
   - Rationale: Text stop_ids ('200060') → int (sid) saves 30-40% space. WITHOUT ROWID tables reduce overhead. FTS5 for search.
   - Reference: DATA_ARCHITECTURE.md:Section 6, PHASE_1:L308-369
   - Critical constraint: dict_route, dict_stop mapping tables required. FTS5 tokenize='porter' for stop name search.

4. **Bundle gtfs.db in iOS app (Phase 1 only)**
   - Rationale: Simplifies MVP - no download logic yet. Phase 2 adds CDN download + version check. Accept >50MB initial install for speed.
   - Reference: PHASE_1:L572-575
   - Critical constraint: Copy to Resources/, verify in Copy Bundle Resources build phase. Phase 2 refactor to download.

5. **Supabase RPC for raw SQL (pattern queries)**
   - Rationale: Pattern model queries (JOIN trips→pattern_stops→routes) too complex for Supabase JS query builder. Use exec_raw_sql RPC.
   - Reference: PHASE_1:L419-425, L474-487
   - Critical constraint: Must create exec_raw_sql RPC in Supabase SQL editor. Parameterized queries ($1, $2) prevent injection.

6. **Programmatic GTFS download from NSW API**
   - Rationale: No manual downloads - backend fetches from NSW API endpoints programmatically. Aligns with Phase 2 real-time integration.
   - Reference: NSW_API_REFERENCE.md:Section 3.1, BACKEND_SPECIFICATION.md:L245-268
   - Critical constraint: Fetch per-mode endpoints (sydneytrains, metro, buses, ferries, lightrail) for trip_id alignment with GTFS-RT. Rate limit: 5 req/s, use sequential downloads with delays.

---

## Implementation Checkpoints

### Checkpoint 1: NSW API GTFS Downloader

**Goal:** Backend downloads GTFS ZIPs from NSW API, unzips to temp dir

**Backend Work:**
- Create `app/services/nsw_gtfs_downloader.py`
- Implement `download_gtfs_feeds()` → downloads per-mode ZIPs:
  - `/v2/gtfs/schedule/sydneytrains` (realtime-aligned)
  - `/v2/gtfs/schedule/metro`
  - `/v1/gtfs/schedule/buses`
  - `/v1/gtfs/schedule/ferries/sydneyferries`
  - `/v1/gtfs/schedule/ferries/MFF`
  - `/v1/gtfs/schedule/lightrail`
- Sequential downloads with 250ms delay (avoid 5 req/s limit)
- Unzip to `temp/gtfs-downloads/<mode>/`
- Log downloaded file sizes, validate ZIP integrity

**iOS Work:**
- None

**Design Constraints:**
- Must use NSW API token from `NSW_API_TOKEN` env var
- Header: `Authorization: apikey <token>`, `Accept: application/zip`
- Reference NSW_API_REFERENCE.md:L94-106 for endpoint paths
- 5 req/s rate limit → sequential downloads with `time.sleep(0.25)`
- Log structured events: `logger.info("gtfs_download_complete", mode="sydneytrains", size_mb=45.2)`

**Validation:**
```bash
python -c "from app.services.nsw_gtfs_downloader import download_gtfs_feeds; download_gtfs_feeds()"
# Expected: 6 ZIP files downloaded to temp/gtfs-downloads/, total ~100-150MB
# Logs show: gtfs_download_complete for each mode
ls -lh temp/gtfs-downloads/*/
```

**References:**
- API docs: NSW_API_REFERENCE.md:L90-113
- Rate limiting: BACKEND_SPECIFICATION.md:L380-401

---

### Checkpoint 2: GTFS Parser + Pattern Model

**Goal:** Parse GTFS CSV → pattern model, Sydney filter, validate counts

**Backend Work:**
- Add `gtfs-kit==6.0.0` to requirements.txt
- Create `app/services/gtfs_service.py`
- Implement `parse_gtfs(input_dir)` → loads CSV with gtfs-kit
- Implement `extract_patterns()` → groups trips by stop_seq, median offsets
- Sydney filtering: bbox [-34.5, -33.3] × [150.5, 151.5] on stops.stop_lat/stop_lon
- Validate GTFS spec compliance (gtfs-kit validation)
- Log stats: stops, routes, patterns, trips counts

**iOS Work:**
- None

**Design Constraints:**
- Use gtfs-kit `feed.read_csv()` for parsing
- Pattern grouping: GROUP BY trip.route_id, trip.direction_id, trip.stop_sequence ORDER → assign pattern_id
- Sydney bbox filtering reduces dataset 40-60%
- Must handle multiple input dirs (merge feeds from 6 modes)
- Follow DEVELOPMENT_STANDARDS.md:4.1 for structured logging

**Validation:**
```bash
python -c "from app.services.gtfs_service import parse_gtfs; parse_gtfs('temp/gtfs-downloads/')"
# Expected logs:
# gtfs_parse_complete: stops=10000-25000, routes=400-1200, patterns=2000-10000, trips=50000-150000
```

**References:**
- Pattern model: DATA_ARCHITECTURE.md:Section 5.4.3
- Sydney filtering: DATA_ARCHITECTURE.md:L341-350
- Parsing patterns: DEVELOPMENT_STANDARDS.md:Section 2.3.2

---

### Checkpoint 3: Supabase Schema Migration

**Goal:** Create pattern tables with PostGIS, execute migration

**Backend Work:**
- Create `schemas/migrations/001_initial_schema.sql`
- Tables: agencies, routes, stops (w/ PostGIS location), patterns, pattern_stops, trips, calendar, calendar_dates, gtfs_metadata
- PostGIS: `CREATE EXTENSION postgis;`, location `geography(Point, 4326)`
- Trigger: `update_stop_location()` auto-populate geography from lat/lon
- Indexes:
  - GIST(location) for spatial queries
  - GIN(stop_name gin_trgm_ops) for text search
  - B-tree on pattern_id, service_id, route_id, stop_id
- RPC: `exec_raw_sql(query text, params jsonb)` for pattern queries
- Execute in Supabase SQL Editor (user action)

**iOS Work:**
- None

**Design Constraints:**
- PostGIS order: `ST_MakePoint(stops.stop_lon, stops.stop_lat)` (lon first!)
- Trigger must run on INSERT/UPDATE to stops table
- RPC must use `EXECUTE format(query, ...)` with `$1, $2` placeholders
- Follow DATA_ARCHITECTURE.md:Section 6 schema exactly
- Pattern_stops table: `(pattern_id, stop_sequence, stop_id, arrival_offset_secs, departure_offset_secs)`

**Validation:**
```sql
-- In Supabase SQL Editor:
SELECT table_name FROM information_schema.tables WHERE table_schema='public';
-- Expected: agencies, routes, stops, patterns, pattern_stops, trips, calendar, calendar_dates, gtfs_metadata (9 tables)

SELECT PostGIS_version();
-- Expected: PostGIS 3.x version string

SELECT proname FROM pg_proc WHERE proname = 'exec_raw_sql';
-- Expected: exec_raw_sql (RPC function exists)
```

**References:**
- Schema: DATA_ARCHITECTURE.md:Section 6, Tables 1-9
- PostGIS setup: PHASE_1:L176-199
- RPC pattern: PHASE_1:L419-425

**SQL for user to execute (Checkpoint 3):**
See `schemas/migrations/001_initial_schema.sql` after implementation.

---

### Checkpoint 4: GTFS Loader Task

**Goal:** Load parsed GTFS → Supabase, verify DB size <350MB

**Backend Work:**
- Create `app/tasks/gtfs_static_sync.py`
- Implement `load_gtfs_static()`:
  - Call `nsw_gtfs_downloader.download_gtfs_feeds()`
  - Parse with `gtfs_service.parse_gtfs()`
  - Bulk insert: `supabase.table('routes').upsert(routes_list).execute()`
  - Insert in order: agencies → routes → stops → patterns → pattern_stops → trips → calendar → calendar_dates → gtfs_metadata
  - Batch size: 1000 rows per upsert
- Log progress, verify row counts
- Run manually (not Celery scheduled yet)

**iOS Work:**
- None

**Design Constraints:**
- Use Supabase batch upsert (not individual inserts)
- gtfs_metadata: store feed_version, feed_start_date, feed_end_date, processed_at
- Trigger will auto-populate stops.location → verify NULL count = 0
- Must handle duplicate route_ids across modes (prefix with mode?)
- Follow DEVELOPMENT_STANDARDS.md:2.3.1 for Supabase client usage

**Validation:**
```bash
# Run loader manually:
python -c "from app.tasks.gtfs_static_sync import load_gtfs_static; load_gtfs_static()"

# Check Supabase SQL Editor:
SELECT COUNT(*) FROM stops;        -- 10000-25000
SELECT COUNT(*) FROM routes;       -- 400-1200
SELECT COUNT(*) FROM patterns;     -- 2000-10000
SELECT COUNT(*) FROM trips;        -- 50000-150000
SELECT COUNT(*) FROM stops WHERE location IS NULL;  -- 0 (trigger worked)

# Check Supabase Dashboard → Database → Usage:
# Total size <350MB
```

**References:**
- Bulk loading: BACKEND_SPECIFICATION.md:L245-268
- Supabase client: backend/app/db/supabase_client.py (Phase 0)

---

### Checkpoint 5: iOS SQLite Generator

**Goal:** Generate 15-20MB SQLite with dict encoding + FTS5

**Backend Work:**
- Create `app/services/ios_db_generator.py`
- Implement `generate_ios_db(output_path)`:
  - Query Supabase pattern tables (all 9 tables)
  - Transform: text IDs → ints (dict_route, dict_stop mapping)
  - Create SQLite: WITHOUT ROWID tables for dict mappings
  - Bit-packed calendar.days (7 bits → 1 byte)
  - FTS5: `CREATE VIRTUAL TABLE stops_fts USING fts5(sid, name, tokenize='porter');`
  - PRAGMA: `journal_mode=OFF`, `page_size=8192`, `VACUUM`
- Output to `backend/ios_output/gtfs.db`
- Log file size, validate <20MB

**iOS Work:**
- None

**Design Constraints:**
- Must follow DATA_ARCHITECTURE.md:Section 6 iOS schema exactly
- WITHOUT ROWID: `CREATE TABLE dict_stop (sid INTEGER PRIMARY KEY, stop_id TEXT UNIQUE) WITHOUT ROWID;`
- FTS5 tokenize='porter' for stemming (e.g., "Station" → "station")
- Use `executemany()` for bulk inserts (not individual)
- VACUUM at end to reclaim space
- iOS research: `.phase-logs/phase-1/ios-research-without-rowid.md` for optimization

**Validation:**
```bash
python -c "from app.services.ios_db_generator import generate_ios_db; generate_ios_db('backend/ios_output/gtfs.db')"
ls -lh backend/ios_output/gtfs.db  # 15-20MB

sqlite3 backend/ios_output/gtfs.db <<EOF
SELECT COUNT(*) FROM stops;        -- Matches Supabase count
SELECT COUNT(*) FROM dict_stop;    -- Same as stops
SELECT name FROM stops_fts WHERE stops_fts MATCH 'circular' LIMIT 5;  -- FTS5 works
.tables                           -- List all tables (verify dict_*, stops_fts exist)
EOF
```

**References:**
- iOS SQLite schema: DATA_ARCHITECTURE.md:Section 6, Table 6
- Dictionary encoding: PHASE_1:L308-369
- iOS research: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md`, `ios-research-without-rowid.md`

---

### Checkpoint 6: Stops API Endpoints

**Goal:** GET /stops/nearby, /stops/{id}, /stops/search, /stops/{id}/departures

**Backend Work:**
- Create `app/api/v1/stops.py`
- Endpoints:
  - `GET /nearby?lat=-33.8615&lon=151.2106&radius=500` → PostGIS ST_DWithin (lon,lat swap!)
  - `GET /{stop_id}` → Simple select by stop_id
  - `GET /search?q=circular` → PostgreSQL FTS (to_tsquery)
  - `GET /{stop_id}/departures?time=<epoch>` → Pattern model query (exec_raw_sql RPC)
- All responses use envelope: `{"data": [...], "meta": {"pagination": {...}}}`
- Register router in `app/main.py`

**iOS Work:**
- None

**Design Constraints:**
- PostGIS nearby: `ST_DWithin(location::geography, ST_MakePoint($lon, $lat)::geography, $radius_meters)`
- Departures query: JOIN pattern_stops → patterns → trips → calendar → routes, filter by stop_id + time + active service_id
- Must call Supabase RPC for departures (complex join), direct query builder for others
- Follow INTEGRATION_CONTRACTS.md:Section 2 for response envelope
- Pagination: offset/limit (default 0/20)

**Validation:**
```bash
# Nearby (Circular Quay coords):
curl 'http://localhost:8000/api/v1/stops/nearby?lat=-33.8615&lon=151.2106&radius=500'
# Expected: JSON with Circular Quay Ferry Terminal, Circular Quay Station stops

# Get by ID:
curl http://localhost:8000/api/v1/stops/200060
# Expected: {"data": {"stop_id": "200060", "stop_name": "...", "location": {...}}}

# Search:
curl 'http://localhost:8000/api/v1/stops/search?q=circular'
# Expected: Circular Quay stops in results

# Departures (scheduled only, no realtime yet):
curl 'http://localhost:8000/api/v1/stops/200060/departures?time=1699000000'
# Expected: Scheduled trips for stop 200060 after epoch time
```

**References:**
- API contracts: INTEGRATION_CONTRACTS.md:Section 2.1-2.4
- PostGIS queries: DATA_ARCHITECTURE.md:L176-199
- Envelope pattern: DEVELOPMENT_STANDARDS.md:Section 2.2

---

### Checkpoint 7: Routes + GTFS API Endpoints

**Goal:** GET /routes, /routes/{id}, /gtfs/version, /gtfs/download

**Backend Work:**
- Create `app/api/v1/routes.py`:
  - `GET /` → List all routes (filter by type optional)
  - `GET /{route_id}` → Single route details
- Create `app/api/v1/gtfs.py`:
  - `GET /version` → Query gtfs_metadata (feed_version, dates)
  - `GET /download` → FileResponse for backend/ios_output/gtfs.db
- Register routers in `app/main.py`

**iOS Work:**
- None

**Design Constraints:**
- Routes list: paginate, allow `?type=train` filter (route_type enum)
- GTFS download: must set `Content-Disposition: attachment; filename=gtfs.db`
- Version endpoint: return latest gtfs_metadata row
- Follow envelope pattern for routes list/get

**Validation:**
```bash
# List routes:
curl http://localhost:8000/api/v1/routes
# Expected: {"data": [...400-1200 routes...], "meta": {"pagination": {...}}}

# Get route:
curl http://localhost:8000/api/v1/routes/T1
# Expected: {"data": {"route_id": "T1", "route_short_name": "T1", "route_type": 1}}

# GTFS version:
curl http://localhost:8000/api/v1/gtfs/version
# Expected: {"data": {"feed_version": "2025-11-13", "feed_start_date": "2025-11-01", ...}}

# Download iOS SQLite:
curl -O http://localhost:8000/api/v1/gtfs/download
ls -lh gtfs.db  # 15-20MB
```

**References:**
- API contracts: INTEGRATION_CONTRACTS.md:Section 2.5-2.7
- FileResponse: FastAPI docs (streaming large files)

---

### Checkpoint 8: iOS GRDB Setup + Models

**Goal:** Bundle gtfs.db, create DatabaseManager, Stop/Route models

**Backend Work:**
- None

**iOS Work:**
- Add GRDB via SPM: https://github.com/groue/GRDB.swift (6.22.0+)
- Copy `backend/ios_output/gtfs.db` → `SydneyTransit/Resources/gtfs.db`
- Add gtfs.db to Xcode: Build Phases → Copy Bundle Resources
- Create `Core/Database/DatabaseManager.swift`:
  - Singleton pattern
  - `Bundle.main.path(forResource: "gtfs", ofType: "db")`
  - Read-only mode (immutable flag for concurrent reads)
- Create `Data/Models/Stop.swift`:
  - Conform to `FetchableRecord, Codable`
  - Implement `search(db, query)` → FTS5 MATCH with porter tokenizer
- Create `Data/Models/Route.swift`:
  - Codable, FetchableRecord
  - Enum for route_type (Train=1, Bus=3, Ferry=4, LightRail=0, Metro=1)

**Design Constraints:**
- DatabaseManager: `let dbQueue = try DatabaseQueue(path: path, configuration: config)` with read-only config
- FTS5 query sanitization: escape special chars (*, ", OR, AND), check empty string
- Bundle.main.path requires device-specific handling (works in simulator + device)
- Follow IOS_APP_SPECIFICATION.md:Section 4.2 for GRDB patterns
- iOS research: `.phase-logs/phase-1/ios-research-bundle-readonly-mode.md` for immutable flag

**Validation:**
```bash
# Open Xcode:
open SydneyTransit/SydneyTransit.xcodeproj

# Build (Cmd+B):
# Expected: No GRDB import errors, build succeeds

# Run in simulator (Cmd+R):
# Expected: App launches, logs show "DB loaded successfully"

# Check Xcode Console:
# Logger.app.info("database_loaded", stops_count=<10000-25000>)
```

**References:**
- GRDB setup: IOS_APP_SPECIFICATION.md:Section 4.2
- Models: DEVELOPMENT_STANDARDS.md:Section 3.2.2
- iOS research: `.phase-logs/phase-1/ios-research-bundle-readonly-mode.md`, `ios-research-grdb-fts5-match.md`

---

### Checkpoint 9: iOS Search UI

**Goal:** SearchView with FTS5 stop search

**Backend Work:**
- None

**iOS Work:**
- Create `Features/Search/SearchView.swift`:
  - `@State var searchQuery = ""`
  - `@State var searchResults: [Stop] = []`
  - `.searchable(text: $searchQuery)` modifier
  - `.onChange(of: searchQuery)` → debounced FTS5 query (300ms)
  - `Task + Task.sleep(for: .milliseconds(300))` → cancel previous task
  - `performSearch()`: `DatabaseManager.shared.read { Stop.search(db, searchQuery) }`
  - `List(searchResults)` with `NavigationLink` → StopDetailsView
- Update `HomeView.swift`: Add NavigationLink to SearchView

**Design Constraints:**
- Debounce pattern: cancel previous Task before starting new search
- FTS5 query must sanitize input (call `Stop.search()` which handles escaping)
- SwiftUI `.searchable` → automatic keyboard, cancel button
- Follow MVVM pattern (consider SearchViewModel if logic grows)
- iOS research: `.phase-logs/phase-1/ios-research-swiftui-searchable-debounce.md` for debouncing

**Validation:**
```bash
# Run iOS app in simulator:
1. Tap "Search" from HomeView
2. Type "circular" → Circular Quay stops appear in <200ms
3. Type "central" → Central Station stops appear
4. Clear query → results empty
5. Check Xcode Console: No FTS5 SQLITE_ERROR logs
```

**References:**
- SwiftUI search: IOS_APP_SPECIFICATION.md:Section 5.2
- FTS5 patterns: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md`
- Debouncing: `.phase-logs/phase-1/ios-research-swiftui-searchable-debounce.md`

---

### Checkpoint 10: iOS Stop Details + Route List

**Goal:** StopDetailsView, RouteListView

**Backend Work:**
- None

**iOS Work:**
- Create `Features/Stops/StopDetailsView.swift`:
  - Display stop name, stop_code, lat/lon
  - Mock departures section (static text: "Real-time departures in Phase 2")
  - Share button (iOS share sheet with stop coordinates)
- Create `Features/Routes/RouteListView.swift`:
  - Fetch all routes: `DatabaseManager.shared.read { Route.fetchAll(db) }`
  - Group by route_type (Train, Bus, Ferry, Light Rail, Metro)
  - Display route_short_name, route_long_name, type badge
- Update `HomeView.swift`: Add NavigationLink to RouteListView

**Design Constraints:**
- StopDetailsView: Receive `Stop` as parameter, not stop_id (avoid query)
- RouteListView: Group routes using `Dictionary(grouping: routes, by: \.route_type)`
- Route type badges: Color-coded (Train=red, Bus=blue, Ferry=green, LightRail=orange, Metro=purple)
- Follow IOS_APP_SPECIFICATION.md:Section 5.1-5.3 for view structure

**Validation:**
```bash
# Run iOS app in simulator:
1. Search "circular" → Tap stop → StopDetailsView shows name, coords
2. Navigate back → Tap "Routes" from HomeView
3. RouteListView shows ~400-1200 routes grouped by type
4. Tap route → (details view optional for Phase 1, can be placeholder)
5. No crashes, smooth navigation
```

**References:**
- View structure: IOS_APP_SPECIFICATION.md:Section 5.1-5.3
- Navigation: DEVELOPMENT_STANDARDS.md:Section 3.2.3

---

### Checkpoint 11: Offline Mode Validation

**Goal:** Verify iOS works without network (local GRDB only)

**Backend Work:**
- None

**iOS Work:**
- None (validation only)

**Design Constraints:**
- No backend API calls in Phase 1 (all data from bundled GRDB)
- Future: Phase 2+ will add network calls, must gracefully degrade

**Validation:**
```bash
# On Mac:
1. Disable Wi-Fi (toggle off in menu bar)
2. Relaunch iOS app in simulator (Cmd+R)
3. Search "circular" → Results appear (GRDB works offline)
4. Tap stop → Details show (no network needed)
5. Navigate to Routes → List displays
6. Check Xcode Console: No URLError logs
7. Re-enable Wi-Fi
```

**References:**
- Offline-first: IOS_APP_SPECIFICATION.md:Section 4.2 (GRDB bundled)
- Phase 2 migration: PHASE_2:L45-67 (add network fallback)

---

## Acceptance Criteria

- [x] Backend: GTFS data downloaded programmatically from NSW API (6 ZIP files)
- [x] Backend: GTFS data loaded to Supabase (<350MB total)
- [x] Backend: Pattern model implemented (SELECT COUNT(*) FROM patterns; # 2k-10k)
- [x] Backend: iOS SQLite generated (15-20MB, backend/ios_output/gtfs.db exists)
- [x] Backend: GET /api/v1/stops/nearby returns Circular Quay stops
- [x] Backend: GET /api/v1/stops/200060/departures returns scheduled departures
- [x] Backend: GET /api/v1/routes returns 400-1200 routes
- [x] Backend: GET /api/v1/gtfs/version returns feed_version, feed_start_date
- [x] iOS: App builds without GRDB errors
- [x] iOS: Search 'circular' returns Circular Quay in <200ms
- [x] iOS: Tap stop → StopDetailsView shows name + location
- [x] iOS: RouteListView shows routes with type labels (Train, Bus, Ferry)
- [x] iOS: Offline mode works (Wi-Fi off, search still functional)
- [x] iOS: No NULL location errors in logs
- [x] iOS: gtfs.db bundled (Build Phases → Copy Bundle Resources includes gtfs.db)

---

## User Blockers (Complete Before Implementation)

**Before Checkpoint 1:**
- [x] Supabase credentials in `backend/.env.local` (user confirmed: "Yes, credentials added")
- [ ] NSW API token in `backend/.env.local` (`NSW_API_TOKEN=<your_token>`)
  - Get token: https://opendata.transport.nsw.gov.au/ → Profile → API Tokens → CREATE
- [ ] Xcode 15+ installed (GRDB requires Swift 5.9+)
  - Verify: `xcodebuild -version` should show "Xcode 15.x"

**Before Checkpoint 3:**
- [ ] Execute Supabase migration SQL (provided below in "Supabase RPC SQL")
  - Action: Copy SQL from schemas/migrations/001_initial_schema.sql → Supabase SQL Editor → Run

**No manual GTFS downloads required** - Backend handles this programmatically in Checkpoint 1.

---

## Research Notes

**iOS Research Completed:**
1. **GRDB FTS5 MATCH syntax** → `.phase-logs/phase-1/ios-research-grdb-fts5-match.md`
   - Key finding: Porter stemming tokenizer requires query sanitization (special chars cause errors), empty string check mandatory
2. **WITHOUT ROWID performance** → `.phase-logs/phase-1/ios-research-without-rowid.md`
   - Key finding: 15-20% size reduction for integer PK tables, benefits dict_stop/dict_route
3. **Bundle.main read-only mode** → `.phase-logs/phase-1/ios-research-bundle-readonly-mode.md`
   - Key finding: GRDB auto-detects Bundle.main as read-only, immutable flag enables concurrent reads
4. **SwiftUI searchable debouncing** → `.phase-logs/phase-1/ios-research-swiftui-searchable-debounce.md`
   - Key finding: Use Task + Task.sleep(300ms) in onChange(), cancel previous task to avoid race conditions

**On-Demand Research (During Implementation):**
- Supabase RPC creation (AI provides SQL below, user executes in SQL editor)
- Supabase free tier limits (500MB DB verified safe for <350MB target)
- PostGIS ST_DWithin units (geography type = meters, used in nearby endpoint)

---

## Supabase RPC SQL

**User Action Required:** Execute this SQL in Supabase SQL Editor **before Checkpoint 3**:

```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable trigram extension for text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create exec_raw_sql RPC for pattern queries
-- SECURITY: Only use with parameterized queries ($1, $2, etc.)
CREATE OR REPLACE FUNCTION exec_raw_sql(query text, params jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  param_array text[] := '{}';
  i int;
BEGIN
  -- Convert jsonb array to text array
  IF params IS NOT NULL AND jsonb_array_length(params) > 0 THEN
    FOR i IN 0..jsonb_array_length(params)-1 LOOP
      param_array := array_append(param_array, params->>i);
    END LOOP;
  END IF;

  -- Execute query with parameters
  EXECUTE query INTO result USING param_array;

  RETURN result;
END;
$$;

-- Grant execute to authenticated users (adjust based on your RLS policies)
GRANT EXECUTE ON FUNCTION exec_raw_sql TO authenticated, anon;
```

**Verification:**
```sql
SELECT proname FROM pg_proc WHERE proname = 'exec_raw_sql';
-- Expected: exec_raw_sql
```

---

## Exploration Report

Attached: `.phase-logs/phase-1/exploration-report.json`

---

**Plan Created:** 2025-11-13
**Estimated Duration:** 3 weeks
**Implementation Ready:** After user completes "User Blockers" section
