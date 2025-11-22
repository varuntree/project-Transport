# Complete System Restoration Implementation Plan

**Type:** Custom Plan (Comprehensive - Architecture Fix + Data Verification/Loading)
**Context:** Fix Phase 1+2 architectural deviations AND ensure data loaded at all 3 layers for complete working end-to-end system
**Complexity:** Complex

---

## Problem Statement

Phase 1+2 code implemented but system broken on two fronts: (1) **Architecture:** stops.py L220-232 hard-checks Supabase returning 404 when empty (blocks RT-only mode), realtime_service.py L203 returns empty array when static fails (prevents RT-only serving). (2) **Data:** Supabase row counts unverified, Redis RT cache status unknown, iOS GRDB bundle exists (74MB vs spec 15-20MB) but table counts unverified. Recent fixes (bc15753 iOS offline fallback, 8b9ac66 SQL injection) applied but backend Layer 2↔3 coupling remains. Need: restore Oracle-spec architecture (Layer 2↔3 decoupling) + verify/load GTFS static at all layers → working end-to-end system with RT departures + offline fallbacks.

---

## Affected Systems

**System: Backend departures endpoint architecture**
- Current state: stops.py L220-232 hard Supabase check returns 404 if stop missing
- Gap: Blocks RT-only mode when Supabase empty but Redis has RT data
- Files affected: `backend/app/api/v1/stops.py`
- Evidence: git show 8b9ac66 removed SQL injection but Supabase check remains

**System: Backend RT merge service architecture**
- Current state: realtime_service.py L184-203 returns [] when static_deps empty
- Gap: Cannot serve RT-only departures, violates layer independence
- Files affected: `backend/app/services/realtime_service.py`
- Evidence: Read L195-203 shows early return pattern

**System: Supabase GTFS static data**
- Current state: UNKNOWN - Cannot verify row counts (no supabase module in test shell)
- Gap: Need to verify data loaded or run Phase 1 import
- Files affected: `backend/app/services/gtfs_service.py` (EXISTS - pattern model implemented), `backend/scripts/load_gtfs.py` (EXISTS), `backend/scripts/update_start_times.py` (EXISTS)
- Evidence: Import pipeline implemented, data state unverified

**System: iOS GRDB bundle**
- Current state: VERIFIED - Resources/gtfs.db exists, 74MB size
- Gap: Verify table counts and data integrity (74MB vs spec 15-20MB size discrepancy)
- Files affected: `SydneyTransit/SydneyTransit/Resources/gtfs.db` (EXISTS - 74MB), `SydneyTransit/SydneyTransit/Core/Database/DatabaseManager.swift`
- Evidence: ls -lah shows gtfs.db 74M Nov 22 13:05

**System: Redis RT cache**
- Current state: UNKNOWN - Need to verify if Celery poller running and caching blobs
- Gap: Need to verify poller running or start it
- Files affected: `backend/app/tasks/gtfs_rt_poller.py` (EXISTS), `backend/app/tasks/celery_app.py` (EXISTS), `backend/scripts/start_all.sh` (EXISTS - 4828 bytes, updated Nov 22 17:04)
- Evidence: Task files exist, poller runtime status unknown

**System: iOS offline fallback (Layer 1)**
- Current state: FIXED - bc15753 added do-catch fallback to fetchDeparturesPage()
- Gap: None - iOS Layer 1 correctly implements offline-first
- Files affected: `SydneyTransit/SydneyTransit/Data/Repositories/DeparturesRepository.swift` (FIXED)
- Evidence: git show bc15753 - try-catch wrapper L118-154, fallback to DatabaseManager.getDepartures()

---

## Key Technical Decisions

1. **Split plan into Architecture Fix + Data Loading phases**
   - Rationale: Architecture fixes enable graceful degradation (RT-only mode), data loading makes system actually work. Can verify architecture before data load.
   - Reference: specs/three-layer-decoupling-refactor-plan.md (exists, previous architecture-only plan)
   - Critical constraint: Both must be complete for end-to-end working system

2. **Verify data first, load only if missing**
   - Rationale: Don't regenerate data if already exists (iOS GRDB 74MB suggests import ran). Verify Supabase row counts before deciding to reload.
   - Reference: PHASE_1_STATIC_DATA.md acceptance criteria
   - Critical constraint: Check Supabase row counts (stops >50k, pattern_stops >100k), Redis keys (gtfs_rt:*), iOS bundle queries before loading

3. **Use existing Phase 1 import pipeline**
   - Rationale: gtfs_service.py fully implemented (pattern model, Sydney filter, MODE_DIRS). load_gtfs.py script exists. Don't rewrite.
   - Reference: PHASE_1_STATIC_DATA.md implementation checklist, gtfs_service.py lines 1-100
   - Critical constraint: Pipeline supports light rail fix (complete feed filtered by route_type 0/900), deduplication, validation thresholds

4. **Backend Option A: Remove Supabase stop check (short-term)**
   - Rationale: Simplest fix, immediately unblocks RT-only mode. Return 200 with empty when all layers fail, not 404.
   - Reference: Oracle guidance, specs/three-layer-decoupling-refactor-plan.md Checkpoint 3
   - Critical constraint: Only 404 when stop truly unknown (not in Supabase AND not in Redis RT)

---

## Implementation Checkpoints

### Checkpoint 1: Verify Current Data State

**Goal:** Determine what data exists vs missing at all 3 layers before any changes

**Backend Work:**
- Activate venv: `cd backend && source venv/bin/activate`
- Query Supabase stops: `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print(sb.table('stops').select('stop_id', count='exact').execute().count)"`
- Query Supabase pattern_stops: `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print(sb.table('pattern_stops').select('pattern_id', count='exact').execute().count)"`
- Query Supabase routes: `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print(sb.table('routes').select('route_id', count='exact').execute().count)"`
- Query Supabase trips: `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print(sb.table('trips').select('trip_id', count='exact').execute().count)"`
- Check Redis keys: `redis-cli KEYS 'gtfs_rt:*'` (or use REDIS_URL from .env if Railway/Upstash)
- Check Redis blob sample: `redis-cli GET gtfs_rt:train:blob | wc -c` (should be >1000 bytes if caching)
- Check GTFS files: `ls -lh backend/data/` (verify GTFS zip files exist)
- Check Celery running: `ps aux | grep celery` (worker + beat processes)

**iOS Work:**
- Verify bundle exists: `ls -lh SydneyTransit/SydneyTransit/Resources/gtfs.db` (DONE - 74MB confirmed)
- Check table counts: `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "SELECT name FROM sqlite_master WHERE type='table';"` (verify pattern model tables exist)
- Check stops count: `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "SELECT COUNT(*) FROM stops;"`
- Check routes count: `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "SELECT COUNT(*) FROM routes;"`
- Test GRDB queries: Run iOS simulator, check Xcode console for DatabaseManager.shared initialization errors

**Design Constraints:**
- Do NOT modify any code - pure verification checkpoint
- Document exact current state in .workflow-logs/custom/complete-system-restoration/data-state-report.md
- Use exact counts (not estimates) for decision-making in later checkpoints

**Validation:**
```bash
# Document findings in data-state-report.md with format:
# Supabase:
#   - stops: X rows
#   - pattern_stops: Y rows
#   - routes: Z rows
#   - trips: W rows
# iOS GRDB:
#   - File size: 74MB
#   - Tables: [list]
#   - stops: X rows
# Redis:
#   - Keys: [gtfs_rt:train:blob, ...]
#   - Blob sizes: train=X bytes, bus=Y bytes, ...
# Celery:
#   - Worker processes: X running
#   - Beat process: running/stopped
```

**References:**
- Pattern: PHASE_1_STATIC_DATA.md acceptance criteria (row count thresholds)
- Architecture: DATA_ARCHITECTURE.md Section 5 (pattern model schema)

---

### Checkpoint 2: Backend Architecture Decoupling

**Goal:** Remove stops.py Supabase check, enable RT-only mode per Oracle guidance

**Backend Work:**
- Create `backend/app/models/departures.py` with DeparturesPage class:
  - Fields: `stop_exists: bool`, `source: str` (static+rt | rt_only | static_only | no_data), `stale: bool`, `departures: list`, `earliest_time_secs: int | None`, `latest_time_secs: int | None`, `has_more_past: bool`, `has_more_future: bool`
  - Method: `to_dict()` returning API envelope: `{data: {departures: [...], ...}, meta: {source: ..., stale: ...}}`
  - Class method: `DeparturesPage.empty(stop_id, stop_exists)` for failure cases
- Refactor `backend/app/services/realtime_service.py`:
  - Add `async def get_departures_page(stop_id, time_secs, direction, limit, supabase) -> DeparturesPage`
  - Wrap static query (L153-182) in try-except: `try: static_deps = ... except: static_deps = []`
  - Replace L184-203 diagnostic block: Remove `return []`, just log and continue with `static_deps = []`
  - Add `_build_rt_only_departures(rt_trip_updates: list) -> list[dict]` helper:
    - Extract stop_time_updates from TripUpdates
    - Compute scheduled_time = estimated_time - delay_seconds
    - Return departure dicts matching DepartureDTO schema
  - Add `_compute_staleness(rt_blobs: dict) -> bool` helper: check blob age >90s
  - Build departures logic: if static_deps → merge with RT (source=static+rt or static_only), elif rt_deps → RT-only mode (source=rt_only), else empty (source=no_data)
  - Return DeparturesPage with stop_exists = (Supabase check OR bool(rt_deps))
- Refactor `backend/app/api/v1/stops.py`:
  - Remove L220-232 Supabase stop check block
  - Replace `realtime_service.fetch_departures_page(...)` with `realtime_service.get_departures_page(...)`
  - Add 404 check: `if page.stop_exists is False: raise HTTPException(404, "Stop not found in any data source")`
  - Return `page.to_dict()` for 200 responses
  - Update logger.info: `logger.info("departures_response", stop_id=stop_id, count=len(page.departures), source=page.source, ...)`

**iOS Work:**
- None (bc15753 already fixed iOS Layer 1 offline fallback)

**Design Constraints:**
- Follow specs/three-layer-decoupling-refactor-plan.md Checkpoints 1-4 exactly
- Preserve API envelope format: `{data: {}, meta: {}}` from BACKEND_SPECIFICATION.md Section 3.2
- RT-only departures must include: trip_id, route_short_name, route_long_name, headsign, scheduled_time (computed), estimated_time, delay_seconds, realtime=true, platform
- Keep existing expanded_limit logic (3x user limit for RT delay window)

**Validation:**
```bash
# Test RT-only mode (Supabase empty scenario)
# If Checkpoint 1 found Supabase empty:
curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '.meta.source'
# Expected: "rt_only" or "no_data" (not 404)

# If Checkpoint 1 found Supabase populated:
# Temporarily comment out Supabase query in realtime_service.py to force RT-only mode
curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '{source: .meta.source, count: (.data.departures | length)}'
# Expected: {"source": "rt_only", "count": >0}
```

**References:**
- Pattern: Oracle Section 4.1-4.2 Backend refactor pseudocode
- Architecture: BACKEND_SPECIFICATION.md Section 3.2 (departures endpoint), Section 8 (error handling)
- Previous plan: specs/three-layer-decoupling-refactor-plan.md Checkpoints 1-4

---

### Checkpoint 3: Load GTFS Static to Supabase (conditional - skip if Checkpoint 1 verified data exists)

**Goal:** Populate Supabase with GTFS static data from NSW Transport (only if missing)

**Conditional Logic:**
- **If Checkpoint 1 found:** stops >50k, pattern_stops >100k → SKIP this checkpoint (data already loaded)
- **If Checkpoint 1 found:** stops <50k or missing tables → EXECUTE this checkpoint

**Backend Work:**
- Check if backend/data/ has GTFS zips: `ls backend/data/*.zip`
- If missing GTFS files:
  - Download NSW Transport GTFS: Follow PHASE_1_STATIC_DATA.md user setup instructions
  - Or use: `curl -o backend/data/full_greater_sydney_gtfs_static.zip https://api.transport.nsw.gov.au/v1/gtfs/schedule/...` (check NSW_API_REFERENCE.md for current URL)
- Run GTFS import: `cd backend && source venv/bin/activate && python scripts/load_gtfs.py`
  - Uses gtfs_service.py parse_gtfs() with pattern model extraction
  - Filters to Sydney bbox per DATA_ARCHITECTURE.md Section 5.2
  - Deduplicates stop_ids across feeds
  - Validates light rail: complete feed filtered by route_type IN (0, 900), NOT lightrail feed
- Verify tables populated:
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print('stops:', sb.table('stops').select('stop_id', count='exact').execute().count)"` (expect >50k)
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print('routes:', sb.table('routes').select('route_id', count='exact').execute().count)"` (expect >500)
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print('trips:', sb.table('trips').select('trip_id', count='exact').execute().count)"` (expect >10k)
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print('pattern_stops:', sb.table('pattern_stops').select('pattern_id', count='exact').execute().count)"` (expect >100k)
- Check light rail validation:
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); print('LR routes:', len(sb.table('routes').select('route_id').in_('route_type', [0, 900]).execute().data))"` (expect ≥3)
  - `python -c "from app.db.supabase_client import get_supabase; sb = get_supabase(); query = 'SELECT COUNT(*) as count FROM trips t JOIN patterns p ON t.pattern_id = p.pattern_id JOIN routes r ON p.route_id = r.route_id WHERE r.route_type IN (0, 900)'; print('LR trips:', sb.rpc('exec_raw_sql', {'query': query}).execute().data[0]['count'])"`  (expect ≥6000)

**iOS Work:**
- None (iOS bundle regenerated in Checkpoint 4 after Supabase loaded)

**Design Constraints:**
- Follow PHASE_1_STATIC_DATA.md implementation checklist exactly
- Use existing gtfs_service.py parse_gtfs() - do NOT rewrite parser
- Light rail: Use complete feed filtered by route_type IN (0, 900), NOT lightrail feed (incomplete/contaminated per docs/oracle/gtfs-coverage-matrix.md)
- Deduplication: stop_id globally unique across feeds (stops table PRIMARY KEY)
- Validation thresholds from PHASE_1_STATIC_DATA.md acceptance criteria

**Validation:**
```bash
# Row count thresholds
cd backend && source venv/bin/activate
python -c "
from app.db.supabase_client import get_supabase
sb = get_supabase()
stops = sb.table('stops').select('stop_id', count='exact').execute().count
routes = sb.table('routes').select('route_id', count='exact').execute().count
trips = sb.table('trips').select('trip_id', count='exact').execute().count
ps = sb.table('pattern_stops').select('pattern_id', count='exact').execute().count
print(f'Stops: {stops} (expect >50000)')
print(f'Routes: {routes} (expect >500)')
print(f'Trips: {trips} (expect >10000)')
print(f'Pattern stops: {ps} (expect >100000)')
assert stops > 50000, 'Stops count too low'
assert routes > 500, 'Routes count too low'
assert trips > 10000, 'Trips count too low'
assert ps > 100000, 'Pattern stops count too low'
print('✓ Phase 1 static data loaded successfully')
"
```

**References:**
- Pattern: backend/app/services/gtfs_service.py parse_gtfs() implementation
- Architecture: DATA_ARCHITECTURE.md Section 5 (pattern model), docs/oracle/gtfs-coverage-matrix.md (light rail fix)
- Acceptance criteria: PHASE_1_STATIC_DATA.md Section 5

---

### Checkpoint 4: Generate iOS GRDB Bundle (conditional - verify or regenerate based on Checkpoint 1)

**Goal:** Verify or regenerate bundled gtfs.db with Sydney-filtered GTFS data

**Conditional Logic:**
- **If Checkpoint 1 found:** gtfs.db exists, size reasonable (<50MB), table queries work → VERIFY ONLY (skip regeneration)
- **If Checkpoint 1 found:** gtfs.db missing or size >50MB or queries fail → REGENERATE from Supabase

**Backend Work:**
- Check if generate_ios_db.py exists: `ls -lh backend/scripts/generate_ios_db.py` (EXISTS - 1951 bytes confirmed)
- If regenerating (74MB size suggests unfiltered or wrong schema):
  - Ensure Supabase data loaded (Checkpoint 3 complete)
  - Run export: `cd backend && source venv/bin/activate && python scripts/generate_ios_db.py`
  - Script should:
    - Export Supabase pattern model tables (stops, routes, trips, patterns, pattern_stops, calendar, calendar_dates)
    - Filter to Sydney stops only (bbox or stop_id list)
    - Apply SQLite optimizations: `journal_mode=OFF` (immutable), `page_size=4096`, `VACUUM`
    - Output to: `SydneyTransit/SydneyTransit/Resources/gtfs.db`
  - Verify output size: `ls -lh SydneyTransit/SydneyTransit/Resources/gtfs.db` (expect 15-20MB for Sydney only)
  - Check compression: `file SydneyTransit/SydneyTransit/Resources/gtfs.db` (should show SQLite 3.x database)

**iOS Work:**
- If regenerated: Xcode will auto-detect resource change, no manual copy needed (already in Resources/)
- Rebuild Xcode project: `cd SydneyTransit && xcodebuild -project SydneyTransit.xcodeproj -scheme SydneyTransit -sdk iphonesimulator clean build`
- Verify DatabaseManager.swift loads bundle:
  - Run iOS simulator
  - Check Xcode console for errors in DatabaseManager.shared initialization
  - Should see log: "GRDB database loaded successfully" or similar
- Test GRDB queries:
  - Open app in simulator
  - Navigate to stops list (should load from GRDB)
  - Check Xcode console: DatabaseManager.shared.getStops() should show >0 stops
- Verify offline mode:
  - Stop backend server: `cd backend && ./scripts/stop_all.sh`
  - iOS app should still show stops/routes from GRDB bundle
  - Check for "Offline mode" banner or no error dialogs

**Design Constraints:**
- Follow IOS_APP_SPECIFICATION.md Section 6 (bundled GTFS database) exactly
- Target size: 15-20MB for Sydney subset (current 74MB suggests full NSW or wrong schema)
- Schema: Pattern model tables ONLY (no stop_times table, shapes optional)
- Optimization: `WITHOUT ROWID` on junction tables, indexes on stop_id/route_id foreign keys
- Bundle path: `SydneyTransit/SydneyTransit/Resources/gtfs.db` (not Resources/Data/ or other location)

**Validation:**
```bash
# Verify bundle size and schema
ls -lh SydneyTransit/SydneyTransit/Resources/gtfs.db
# Expected: 15-20MB (or document if 74MB acceptable with justification)

sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "
SELECT 'Tables:', COUNT(*) FROM sqlite_master WHERE type='table';
SELECT 'Stops:', COUNT(*) FROM stops;
SELECT 'Routes:', COUNT(*) FROM routes;
SELECT 'Trips:', COUNT(*) FROM trips;
SELECT 'Pattern stops:', COUNT(*) FROM pattern_stops;
"
# Expected: Stops >1000, Routes >50, Trips >1000, Pattern stops >10000 (Sydney subset)

# Test offline mode in iOS simulator
# Backend stopped, app loads → ✓
```

**References:**
- Pattern: backend/scripts/generate_ios_db.py (1951 bytes, export logic)
- Architecture: IOS_APP_SPECIFICATION.md Section 6, DATA_ARCHITECTURE.md Section 5.5 (iOS SQLite optimization)
- Size discrepancy note: Current 74MB vs spec 15-20MB - investigate if unfiltered (full NSW) or different schema

---

### Checkpoint 5: Verify/Start Celery RT Poller

**Goal:** Ensure Redis caching live GTFS-RT blobs from NSW Transport API

**Backend Work:**
- Check if Celery worker running: `ps aux | grep celery | grep -v grep` (should see worker + beat processes)
- Check worker logs: `tail -f backend/logs/celery_worker.log` (if logs/ dir exists)
- If NOT running:
  - Start all services: `cd backend && ./scripts/start_all.sh`
  - Script starts (per BACKEND_SPECIFICATION.md Section 4):
    - FastAPI (uvicorn on port 8000)
    - Celery Worker A: `-Q critical -c 1` (RT poller on critical queue)
    - Celery Worker B: `-Q normal,batch -c 2 --autoscale=3,1` (GTFS sync, alert matcher on normal/batch queues)
    - Celery Beat: scheduler for periodic tasks
  - Script includes Redis startup check (per commit ece23d6)
- Monitor startup:
  - `tail -f backend/logs/celery_worker.log` (check for "poll_gtfs_rt_started" events)
  - `tail -f backend/logs/celery_beat.log` (check for schedule entries: poll_gtfs_rt every 30s)
- Verify Redis keys appear (wait ~30s for first poll):
  - `redis-cli KEYS 'gtfs_rt:*'` (should see vp:buses:v1, tu:sydneytrains:v1, alerts:metro:v1, etc.)
  - Or if Railway/Upstash: `redis-cli -u $REDIS_URL KEYS 'gtfs_rt:*'`
- Check blob structure:
  - `redis-cli GET gtfs_rt:train:blob | gunzip -c | jq '.' | head -20` (should decompress to JSON array of TripUpdates)
  - Verify blob age: Check `redis-cli GET gtfs_rt:train:blob:updated_at` (timestamp should be <90s old)
- Verify polling cadence:
  - Watch logs for 2 minutes: `tail -f backend/logs/celery_worker.log | grep poll_gtfs_rt`
  - Should see "poll_gtfs_rt_started" events every 30s (per BACKEND_SPECIFICATION.md Section 4 Celery task schedule)

**iOS Work:**
- None (iOS consumes RT data via backend API /stops/{stop_id}/departures)

**Design Constraints:**
- Follow BACKEND_SPECIFICATION.md Section 4 Celery Worker Task Design exactly
- Polling interval: 30s (adaptive polling NOT implemented in Phase 2, fixed 30s)
- Blob format: Gzip-compressed JSON arrays (not protobuf, per DATA_ARCHITECTURE.md Section 4.2)
- Queue config: Critical queue (RT poller), Normal/Batch queues (GTFS sync, alert matcher)
- Startup check: start_all.sh must verify Redis connectable before starting workers (commit ece23d6)

**Validation:**
```bash
# Check processes running
ps aux | grep celery | grep -v grep
# Expected: 3 processes (worker A, worker B, beat)

# Check Redis keys (after 30s)
redis-cli KEYS 'gtfs_rt:*'
# Expected: gtfs_rt:train:blob, gtfs_rt:bus:blob, gtfs_rt:ferry:blob, gtfs_rt:metro:blob, gtfs_rt:lightrail:blob
# Plus: vp:buses:v1, tu:sydneytrains:v1, alerts:*:v1, etc.

# Check blob size (compressed)
redis-cli GET gtfs_rt:train:blob | wc -c
# Expected: >1000 bytes (gzipped JSON)

# Check blob age
redis-cli GET gtfs_rt:train:blob:updated_at
# Expected: timestamp within last 90 seconds

# Test decompression
redis-cli GET gtfs_rt:train:blob | gunzip -c | jq '. | length'
# Expected: >0 (array of TripUpdates)
```

**References:**
- Pattern: backend/app/tasks/gtfs_rt_poller.py (30s poll task)
- Architecture: BACKEND_SPECIFICATION.md Section 4 (Celery config), DATA_ARCHITECTURE.md Section 4 (GTFS-RT caching)
- Script: backend/scripts/start_all.sh (4828 bytes, updated Nov 22 17:04 with Redis check)

---

### Checkpoint 6: End-to-End Integration Test

**Goal:** Verify complete system - RT data showing in iOS app, all fallbacks working, no regressions

**Backend Work - 6 Test Scenarios:**

1. **Test static+RT merge (ideal mode):**
   ```bash
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '{source: .meta.source, count: (.data.departures | length), has_delays: [.data.departures[] | select(.delay_seconds != 0)] | length > 0}'
   # Expected: {"source": "static+rt", "count": >0, "has_delays": true}
   ```

2. **Test RT-only mode (Supabase unavailable):**
   ```bash
   # Temporarily stop Supabase connection or use stop with no static data
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '{source: .meta.source, status_code: 200}'
   # Expected: {"source": "rt_only", "status_code": 200} (not 404)
   ```

3. **Test static-only mode (Redis unavailable):**
   ```bash
   # Stop Celery poller or flush Redis: redis-cli FLUSHDB
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '{source: .meta.source, count: (.data.departures | length), realtime_flags: [.data.departures[] | .realtime]}'
   # Expected: {"source": "static_only", "count": >0, "realtime_flags": [false, false, ...]}
   ```

4. **Test stale cache detection:**
   ```bash
   # Stop Celery poller, wait >90s
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '.meta.stale'
   # Expected: true
   ```

5. **Test 404 logic (unknown stop):**
   ```bash
   curl -i "http://localhost:8000/api/v1/stops/INVALID999/departures" | grep "HTTP/1.1 404"
   # Expected: 404 Not Found (stop not in Supabase AND not in Redis RT)
   ```

6. **Test graceful degradation (all layers fail):**
   ```bash
   # Stop Supabase + Celery poller
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '{status: 200, source: .meta.source, count: (.data.departures | length)}'
   # Expected: {"status": 200, "source": "no_data", "count": 0}
   ```

**iOS Work - 6 Test Scenarios:**

1. **Test online mode (RT departures with delay badges):**
   - Backend running, all layers healthy
   - Open iOS app in simulator → navigate to stop 200060 departures
   - Expected: Departures list shows delay badges (green <2min, yellow 2-5min, red >5min per Phase 2 commits)
   - Verify: Delay time matches backend API response `delay_seconds`

2. **Test delay accuracy:**
   ```bash
   # Compare backend API vs iOS UI
   curl "http://localhost:8000/api/v1/stops/200060/departures" | jq '.data.departures[0] | {route: .route_short_name, delay_seconds: .delay_seconds}'
   # Then check iOS UI: Same route should show same delay badge color
   ```

3. **Test offline mode (GRDB fallback):**
   - Stop backend: `cd backend && ./scripts/stop_all.sh`
   - iOS app should still show stops/routes from GRDB bundle
   - Navigate to departures screen → should show static schedule (no delay badges)
   - Expected: "Offline mode" banner or "Showing scheduled times" message
   - Verify: No crash, graceful degradation per DeparturesRepository.swift bc15753 fallback

4. **Test all layers fail (graceful empty state):**
   - Stop backend
   - Simulate GRDB failure (or use stop not in bundle)
   - Expected: Empty state message "No departures available" (not crash)
   - Verify: DeparturesRepository returns .empty per L147-153

5. **Test auto-refresh (30s updates):**
   - Open departures screen, leave app open
   - Watch for departures list updates every 30s
   - Expected: DeparturesViewModel timer fires, API called, UI refreshes
   - Verify: Check Xcode console for "departures_request" logs every 30s

6. **Test service alerts:**
   - Backend running with alerts in Redis (check redis-cli KEYS 'alerts:*')
   - Navigate to route with active alert
   - Expected: AlertBanner component shows at top of departures list (per commit 3ddd510)
   - Verify: Alert text matches backend API /alerts response

**Design Constraints:**
- All 12 scenarios (6 backend + 6 iOS) must pass before merging
- Use curl for backend tests (no pytest required for MVP)
- Use iOS simulator for iOS tests (no device required)
- Document test results in .workflow-logs/custom/complete-system-restoration/integration-test-results.md

**Validation:**
```bash
# Backend test suite
cd backend && source venv/bin/activate
./scripts/start_all.sh  # Ensure all services running
bash .workflow-logs/custom/complete-system-restoration/run-backend-tests.sh
# Expected: 6/6 tests pass

# iOS test suite (manual)
# Open iOS simulator, run through 6 scenarios
# Document results in integration-test-results.md
```

**References:**
- Pattern: Oracle Section 3 Phase 3 (validation & tests)
- Acceptance criteria: PHASE_1_STATIC_DATA.md + PHASE_2_REALTIME.md combined
- Architecture: INTEGRATION_CONTRACTS.md Section 1 (departures API contract)

---

## Acceptance Criteria

**Architecture Fixes:**
- [ ] Backend RT-only mode works (Supabase empty → 200 with RT departures, source=rt_only)
- [ ] Backend static-only mode works (Redis empty → 200 with static departures, source=static_only)
- [ ] Backend 404 only when stop not in Supabase AND not in Redis RT (truly unknown stop)
- [ ] Backend graceful degradation (all layers fail → 200 with empty departures, source=no_data)

**Data Verification/Loading:**
- [ ] Supabase has >50k stops, >100k pattern_stops, >500 routes, >10k trips (Phase 1 complete)
- [ ] Light rail validation passes (≥3 routes route_type 0/900, ≥6000 trips, 0 contamination)
- [ ] iOS GRDB bundle exists, queries work, offline mode functional
- [ ] iOS GRDB bundle size reasonable (<50MB or documented justification for 74MB)
- [ ] Redis has gtfs_rt:train/bus/ferry/metro/lightrail blobs (vp:*:v1 and tu:*:v1 keys)
- [ ] Celery poller running (worker + beat processes), 30s polling cadence verified

**End-to-End System:**
- [ ] iOS app shows RT departures with color-coded delay badges (green <2min, yellow 2-5min, red >5min)
- [ ] iOS app shows service alerts in AlertBanner component (when alerts exist)
- [ ] Backend stopped → iOS shows GRDB offline data (no crash, graceful degradation)
- [ ] Redis empty → Backend shows static-only departures (source=static_only)
- [ ] Supabase empty → Backend shows RT-only departures (source=rt_only)
- [ ] All Phase 1+2 features still work (browse stops, search, nearby, trip details, RT delays, alerts)

---

## User Blockers (Complete Before Implementation)

- [ ] NSW Transport API key configured in backend/.env (for GTFS download + RT polling)
- [ ] Supabase project credentials in backend/.env (sydney-transit-dev project)
- [ ] Redis running locally or Railway/Upstash URL in backend/.env
- [ ] Python venv activated (backend/venv) for Supabase queries in Checkpoint 1
- [ ] Xcode installed (for iOS GRDB verification and testing)

---

## Research Notes

**iOS Research Completed:**
- None (bc15753 already fixed iOS Layer 1 offline fallback, no new iOS work needed)

**On-Demand Research (During Implementation):**
- None (backend refactor uses existing patterns, no new external services/APIs)

---

## Related Phases

**Phase 1 (Static Data):** Fixes incomplete Phase 1 verification (data exists but state unverified) + iOS bundling (74MB size discrepancy investigation)

**Phase 2 (Real-Time):** Fixes Phase 2 RT blocked by architecture (Layer 2↔3 coupling) + verifies poller running (runtime status unknown)

---

## Exploration Report

Attached: `.workflow-logs/custom/complete-system-restoration/exploration-report.json`

**Key Discoveries:**
- iOS Layer 1 (GRDB) already FIXED by commit bc15753 (no iOS work needed)
- Backend Layer 2↔3 coupling confirmed: stops.py L220-232, realtime_service.py L203
- iOS GRDB bundle exists (74MB vs spec 15-20MB) - verify or regenerate
- GTFS import pipeline implemented (gtfs_service.py, load_gtfs.py exists)
- Celery poller implemented (gtfs_rt_poller.py exists), runtime status unknown
- Supabase data state unknown (cannot query without venv activation)
- Redis RT cache status unknown (need process check)

---

**Plan Created:** 2025-11-22
**Estimated Duration:** 6-10 hours total
- 2h: Architecture fix (Checkpoints 2 - DeparturesPage DTO + refactor)
- 1h: Data verification (Checkpoint 1 - Supabase/Redis/iOS queries)
- 2-3h: Data loading if needed (Checkpoints 3-4 - GTFS import + iOS bundle)
- 1h: Celery verification/startup (Checkpoint 5 - poller + Redis caching)
- 2-3h: End-to-end testing (Checkpoint 6 - 12 scenarios)
- 1h: Bug fixes and iteration
