# Phase 2 Implementation Plan

**Phase:** Real-Time GTFS-RT Integration
**Duration:** 3 weeks (Weeks 6-8)
**Complexity:** medium

---

## Goals

- Add real-time GTFS-RT integration: Celery workers poll NSW API every 30s, cache per-mode blobs in Redis
- Merge live delays with static schedules: iOS gets realtime departures with auto-refresh, countdown timers, delay badges
- Graceful degradation: Stale cache → static schedules (no 503 errors), offline-first architecture maintained
- 3-queue Celery: critical (RT poller, singleton, 1 worker), normal (alerts/APNs future), batch (GTFS sync)
- No auth yet—all anonymous endpoints (auth = Phase 3)

---

## Key Technical Decisions

1. **Adaptive 30s GTFS-RT polling (peak-aware)**
   - Rationale: NSW API updates every 30s. Polling VehiclePositions + TripUpdates per mode (buses, trains, metro, ferries, lightrail) = 10 calls/cycle. 2,880 cycles/day = 28.8K calls (within 60K daily limit). Peak-aware logic stub for future optimization.
   - Reference: DATA_ARCHITECTURE.md:Section 4.2-4.4, PHASE_2_REALTIME.md:L124-138
   - Critical constraint: Must use Redis SETNX lock for singleton task. TTL 75s (VP), 90s (TU) for graceful degradation. Hard timeout 15s, soft 10s to prevent hung workers.

2. **Per-mode blob caching (not per-entity keys)**
   - Rationale: Avoid key explosion (100K+ vehicles → 100K Redis keys). Instead: vp:{mode}:v1, tu:{mode}:v1 = 10 total keys. Gzip compress JSON blobs (~70% reduction). Client-side filtering by route/trip.
   - Reference: DATA_ARCHITECTURE.md:Section 4.5, PHASE_2_REALTIME.md:L283-287
   - Critical constraint: Gzip before cache (gzip.compress), decompress on read. TTL > poll interval to avoid cache misses between cycles.

3. **3-queue Celery architecture (critical/normal/batch)**
   - Rationale: Isolate time-sensitive RT poller (critical, 1 worker, singleton) from parallel tasks (normal: alerts, APNs) and long-running (batch: GTFS sync). Prevents head-of-line blocking.
   - Reference: BACKEND_SPECIFICATION.md:Section 4.2, PHASE_2_REALTIME.md:L100-138
   - Critical constraint: Worker A: -Q critical -c 1 (singleton). Worker B: -Q normal,batch -c 2 --autoscale=3,1. Beat scheduler required for periodic tasks.

4. **Merge static schedules + RT delays in API layer**
   - Rationale: iOS offline-first: GRDB has static schedules, API enriches with live delays from Redis. Pattern model query joins trips→pattern_stops→routes, then lookup trip_id in Redis tu:{mode}:v1 blob for delay_s.
   - Reference: PHASE_2_REALTIME.md:L375-451, INTEGRATION_CONTRACTS.md:L163-228
   - Critical constraint: Route ID heuristics determine mode (T*/BMT→trains, M→metro, F→ferries, L→lightrail, else→buses). Fallback to delay_s=0 if Redis miss.

5. **iOS Timer-based auto-refresh (30s)**
   - Rationale: SwiftUI Timer triggers API refetch every 30s while DeparturesView visible. Pull-to-refresh manual trigger. minutesUntil computed property recalculates on each render (no timer needed for countdown).
   - Reference: IOS_APP_SPECIFICATION.md:Section 5.2, PHASE_2_REALTIME.md:L633-646
   - Critical constraint: Timer.invalidate() in onDisappear to prevent memory leaks. Timer scheduled on main thread (@MainActor).

6. **Graceful degradation (stale cache fallback)**
   - Rationale: If Redis TTL expires or NSW API fails, serve static schedules (realtime: false, delay_s: 0). No 503 errors—app remains functional offline/degraded. Log stale state, don't crash.
   - Reference: BACKEND_SPECIFICATION.md:Section 5.3, PHASE_2_REALTIME.md:L800-811
   - Critical constraint: Handle gzip.decompress errors, Redis misses, NSW 429 rate limits. All exceptions caught, logged, return empty/static data.

---

## Implementation Checkpoints

### Checkpoint 1: Celery App Config + 3 Queues

**Goal:** Configure Celery with 3 queues (critical/normal/batch), Beat scheduler, timezone-aware

**Backend Work:**
- Add `celery[redis]==5.3.4`, `redis==5.0.1`, `gtfs-realtime-bindings==1.0.0` to requirements.txt
- Create `app/tasks/celery_app.py` (broker=REDIS_URL, include=['app.tasks.gtfs_rt_poller'])
- Define 3 queues: critical (RT poller), normal (alerts, APNs), batch (GTFS sync)
- Beat schedule: poll_gtfs_rt (30s), sync_gtfs_static (03:10 Sydney cron)
- Config: task_serializer=json, timezone='Australia/Sydney', worker_prefetch_multiplier=1

**iOS Work:**
- None (backend-only checkpoint)

**Design Constraints:**
- Follow BACKEND_SPECIFICATION.md:Section 4.2 for Celery config pattern
- Use DEVELOPMENT_STANDARDS.md:Section 3 for structlog logging (JSON events)
- Must set `enable_utc=False` for DST-safe scheduling

**Validation:**
```bash
celery -A app.tasks.celery_app inspect registered
# Expected: Empty tasks list (none implemented yet), no import errors
celery -A app.tasks.celery_app inspect scheduled
# Expected: Beat schedule shows poll_gtfs_rt (30s interval)
```

**References:**
- Pattern: Celery task decorator (PHASE_2_REALTIME.md:L161-168)
- Architecture: BACKEND_SPECIFICATION.md:Section 4.4

---

### Checkpoint 2: GTFS-RT Poller Task (VehiclePositions + TripUpdates)

**Goal:** Poll 5 modes × 2 feeds every 30s, parse protobuf, cache gzipped JSON blobs

**Backend Work:**
- Create `app/tasks/gtfs_rt_poller.py`
- `@celery_app.task(queue='critical', time_limit=15, soft_time_limit=10, max_retries=0)`
- Redis SETNX lock: `lock:poll_gtfs_rt` (TTL 30s, skip if already running)
- Loop `MODES = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']`
- `fetch_gtfs_rt(mode, 'vehiclepos')`: requests.get(NSW API, headers={'Authorization': 'apikey KEY'}, timeout=8)
- `parse_vehicle_positions(pb_data)`: gtfs_realtime_pb2.FeedMessage().ParseFromString()
- Extract `{vehicle_id, trip_id, route_id, lat, lon, bearing, speed, timestamp}`
- Repeat for 'realtime' feed → parse_trip_updates (extract `{trip_id, route_id, delay_s, stop_time_updates}`)
- `cache_blob(redis, f'vp:{mode}:v1', parsed_vp, ttl=75)`: gzip.compress(json.dumps(data))
- `cache_blob(redis, f'tu:{mode}:v1', parsed_tu, ttl=90)`
- Log: `logger.info('poll_gtfs_rt_complete', modes=MODES, duration_ms=elapsed)`

**iOS Work:**
- None (backend-only checkpoint)

**Design Constraints:**
- Follow PHASE_2_REALTIME.md:L173-178 for Redis SETNX lock pattern
- Follow PHASE_2_REALTIME.md:L283-287 for gzip blob caching
- NSW API endpoints: `/gtfs/vehiclepos/{mode}` and `/gtfs/realtime/{mode}` (see NSW_API_REFERENCE.md)
- Must handle protobuf ParseError gracefully (log + skip cycle, don't crash worker)

**Validation:**
```bash
# Start worker + beat in separate terminals:
# Terminal 1: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && uvicorn app.main:app --reload
# Terminal 2: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info
# Terminal 3: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && celery -A app.tasks.celery_app beat --loglevel=info

# Wait 30s, then check Redis:
redis-cli KEYS vp:*
# Expected: 5 keys (vp:buses:v1, vp:sydneytrains:v1, vp:metro:v1, vp:ferries:v1, vp:lightrail:v1)

redis-cli KEYS tu:*
# Expected: 5 keys (tu:buses:v1, tu:sydneytrains:v1, tu:metro:v1, tu:ferries:v1, tu:lightrail:v1)

redis-cli GET vp:buses:v1
# Expected: Binary gzipped blob (not human-readable)

redis-cli TTL vp:buses:v1
# Expected: 60-75 seconds remaining
```

**References:**
- Pattern: Redis SETNX lock (DATA_ARCHITECTURE.md:Section 4.7)
- Pattern: Gzip blob caching (DATA_ARCHITECTURE.md:Section 4.5)
- Architecture: BACKEND_SPECIFICATION.md:Section 4.4 (Celery tasks)
- NSW API: NSW_API_REFERENCE.md (GTFS-RT endpoints)

---

### Checkpoint 3: Worker Startup Scripts

**Goal:** Create bash scripts to start Worker A (critical), Worker B (normal+batch), Beat

**Backend Work:**
- Create `scripts/start_worker_critical.sh`: `celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info`
- Create `scripts/start_worker_service.sh`: `celery -A app.tasks.celery_app worker -Q normal,batch -c 2 --autoscale=3,1 --loglevel=info`
- Create `scripts/start_beat.sh`: `celery -A app.tasks.celery_app beat --loglevel=info`
- `chmod +x scripts/*.sh`

**iOS Work:**
- None (backend-only checkpoint)

**Design Constraints:**
- Follow PHASE_2_REALTIME.md:L100-138 for worker configuration
- Worker A: 1 concurrency (singleton RT poller, no parallelism)
- Worker B: 2-3 concurrency (autoscale for normal/batch queue, future alerts + APNs)

**Validation:**
```bash
bash scripts/start_worker_critical.sh
# Expected: Starts without errors, logs show "worker_critical@hostname ready" or similar

bash scripts/start_worker_service.sh
# Expected: Starts without errors, logs show autoscale config

bash scripts/start_beat.sh
# Expected: Starts without errors, logs show beat scheduler running
```

**References:**
- Architecture: BACKEND_SPECIFICATION.md:Section 4.2 (Celery queues)

---

### Checkpoint 4: Real-Time Departures Service (Merge Static + RT)

**Goal:** Fetch static schedules from Supabase, enrich with Redis RT delays

**Backend Work:**
- Create `app/services/realtime_service.py`
- `async def get_realtime_departures(stop_id, now_secs, limit=10)`
- Step 1: Query Supabase pattern model (same as Phase 1 `/stops/{id}/departures`)
- Step 2: Determine modes from route_ids (heuristic: T*/BMT→trains, M→metro, F→ferries, L→lightrail, else→buses)
- Step 3: Fetch `tu:{mode}:v1` from Redis, decompress gzip, parse JSON, build `trip_delays = {trip_id: delay_s}`
- Step 4: Merge `static_deps + trip_delays` → `realtime_dep_secs = dep_secs + delay_s`
- Return `[{trip_id, route_short_name, headsign, scheduled_time_secs, realtime_time_secs, delay_s, realtime: bool}]`
- Sort by `realtime_time_secs`, limit to 10

**iOS Work:**
- None (backend-only checkpoint)

**Design Constraints:**
- Follow PHASE_2_REALTIME.md:L375-451 for merge algorithm
- Route ID heuristics per PHASE_2_REALTIME.md:L410-425
- Must handle Redis misses gracefully: `delay_s=0, realtime=false` (static fallback)
- Gzip decompress pattern: `gzip.decompress(blob_bytes)` then `json.loads()`

**Validation:**
```bash
# Python REPL test:
python3
>>> from app.services.realtime_service import get_realtime_departures
>>> import asyncio
>>> asyncio.run(get_realtime_departures('200060', 32400, 10))
# Expected: List of departures, some with delay_s != 0 if NSW has delays
# Check: realtime: true for trips with delay_s > 0
```

**References:**
- Pattern: Merge static + RT (INTEGRATION_CONTRACTS.md:L163-228)
- Architecture: PHASE_2_REALTIME.md:L375-451

---

### Checkpoint 5: Update Stops API for Real-Time

**Goal:** Replace static departures endpoint with realtime_service

**Backend Work:**
- Update `app/api/v1/stops.py`
- Replace `@router.get('/stops/{stop_id}/departures')` handler
- `from app.services.realtime_service import get_realtime_departures`
- Default time to now (`pytz.timezone('Australia/Sydney')`), convert to seconds since midnight
- Call `get_realtime_departures(stop_id, now_secs, limit)`
- Return `SuccessResponse(data=departures)`

**iOS Work:**
- None (backend-only checkpoint)

**Design Constraints:**
- Follow INTEGRATION_CONTRACTS.md:L163-228 for API response format
- Must handle `stop_id` not found (404), invalid `time` param (400)
- Log structured event: `logger.info('departures_fetched', stop_id=stop_id, realtime_count=N, static_count=M)`

**Validation:**
```bash
curl 'http://localhost:8000/api/v1/stops/200060/departures'
# Expected: JSON response with data array
# Check: Some items have realtime: true, delay_s != 0 (if NSW has delays)
# Check: scheduled_time_secs < realtime_time_secs when delayed
# Check: Response includes meta: {pagination: null} (not paginated)
```

**References:**
- API contract: INTEGRATION_CONTRACTS.md:L163-228
- Architecture: BACKEND_SPECIFICATION.md:Section 3 (API routes)

---

### Checkpoint 6: iOS Departure Model + Repository

**Goal:** Create Departure model with countdown logic, repository protocol

**Backend Work:**
- None (iOS-only checkpoint)

**iOS Work:**
- Create `Data/Models/Departure.swift`
- `struct Departure: Codable, Identifiable { trip_id, route_short_name, headsign, scheduled_time_secs, realtime_time_secs, delay_s, realtime, departure_time }`
- `var minutesUntil: Int` (computed: `(realtime_time_secs - Date().timeIntervalSince(startOfDay)) / 60`)
- `var delayText: String?` ('+X min' if `delay_s > 0`, else nil)
- Create `Data/Repositories/DeparturesRepository.swift` (protocol + impl)
- `func fetchDepartures(stopId: String) async throws -> [Departure]`
- `APIClient.request(APIEndpoint.getDepartures(stopId: stopId))`

**Design Constraints:**
- Follow IOS_APP_SPECIFICATION.md:Section 5.1 for repository pattern
- Follow DEVELOPMENT_STANDARDS.md:iOS patterns for protocol-based repositories
- URLSession timeout: 8s request, 15s resource (align with Celery soft_time_limit 10s)
- API endpoint: `GET /api/v1/stops/{stopId}/departures`

**Validation:**
```bash
# Xcode build
open SydneyTransit.xcodeproj
# Cmd+B to build
# Expected: No compilation errors on Departure model, DeparturesRepositoryImpl compiles
```

**References:**
- iOS Research: `.phase-logs/phase-2/ios-research-urlsession-timeouts.md` (timeout configuration)
- Pattern: Repository protocol (IOS_APP_SPECIFICATION.md:Section 3.2)
- Architecture: INTEGRATION_CONTRACTS.md:L163-228 (API response format)

---

### Checkpoint 7: iOS Departures ViewModel (Auto-Refresh)

**Goal:** ViewModel with Timer-based 30s refresh, loading/error states

**Backend Work:**
- None (iOS-only checkpoint)

**iOS Work:**
- Create `Features/Departures/DeparturesViewModel.swift`
- `@MainActor class DeparturesViewModel: ObservableObject`
- `@Published var departures: [Departure] = [], isLoading = false, errorMessage: String?`
- `func loadDepartures(stopId: String) async { isLoading=true, fetch from repo, handle errors }`
- `func startAutoRefresh(stopId: String)`: `Timer.scheduledTimer(withTimeInterval: 30, repeats: true)`
- `func stopAutoRefresh()`: `refreshTimer?.invalidate()`

**Design Constraints:**
- Follow IOS_APP_SPECIFICATION.md:Section 5.2 for ViewModel pattern
- @MainActor ensures Timer.scheduledTimer fires on main RunLoop (no manual RunLoop.main.add needed)
- Must invalidate timer on disappear to prevent memory leak
- Handle errors gracefully: URLError.notConnectedToInternet → "No internet connection"

**Validation:**
```bash
# Xcode build
# Cmd+B to build
# Expected: ViewModel compiles, Timer import Foundation, no Combine needed
# Manual test (Checkpoint 8): Timer fires every 30s, isLoading toggles
```

**References:**
- iOS Research: `.phase-logs/phase-2/ios-research-timer-scheduling.md` (Timer pattern)
- Pattern: ViewModel (@MainActor, @Published) (IOS_APP_SPECIFICATION.md:Section 5.2)
- Architecture: PHASE_2_REALTIME.md:L633-645

---

### Checkpoint 8: iOS Departures View (Countdown UI)

**Goal:** SwiftUI view with List, DepartureRow, auto-refresh on appear

**Backend Work:**
- None (iOS-only checkpoint)

**iOS Work:**
- Create `Features/Departures/DeparturesView.swift`
- `List { ForEach(viewModel.departures) { DepartureRow(departure: $0) } }`
- `.refreshable { await viewModel.loadDepartures(stopId: stop.sid) }`
- `.onAppear { Task { await viewModel.loadDepartures(stopId: stop.sid) }; viewModel.startAutoRefresh(stopId: stop.sid) }`
- `.onDisappear { viewModel.stopAutoRefresh() }`
- Create `DepartureRow`: `HStack { route badge, headsign + delayText, Spacer, minutesUntil + departure_time }`

**Design Constraints:**
- Follow IOS_APP_SPECIFICATION.md:Section 5.1 for SwiftUI views
- SwiftUI List auto-diffs by Identifiable.id—no manual optimization needed
- Delay badge orange if `delay_s > 0`, gray otherwise
- Countdown updates on refresh (minutesUntil is computed property, recalculates automatically)

**Validation:**
```bash
# Xcode simulator (Cmd+R)
# Manual test:
# 1. Tap stop → 'View Departures' → list shows
# 2. Countdown shows '5 min' (or similar)
# 3. Wait 30s → list auto-refreshes, countdown updates to '4 min'
# 4. Delay badges show orange '+2 min' when delay_s > 0
# 5. Pull down → loading indicator → refresh completes
# 6. Back navigation → Timer stops (no memory leak)
```

**References:**
- iOS Research: `.phase-logs/phase-2/ios-research-list-refresh-optimization.md` (List performance)
- iOS Research: `.phase-logs/phase-2/ios-research-timer-scheduling.md` (Timer lifecycle)
- Pattern: SwiftUI .refreshable (PHASE_2_REALTIME.md:L681-684)
- Architecture: IOS_APP_SPECIFICATION.md:Section 5.1

---

### Checkpoint 9: Integration Test (Backend + iOS Real-Time)

**Goal:** End-to-end test: Worker polls → Redis caches → API serves → iOS displays

**Backend Work:**
- None (testing checkpoint)

**iOS Work:**
- None (testing checkpoint)

**Design Constraints:**
- Must test full stack: Celery Beat → Worker → Redis → FastAPI → iOS
- Verify 30s auto-refresh synchronizes with backend polling

**Validation:**
```bash
# Start all services:
# Terminal 1: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && uvicorn app.main:app --reload
# Terminal 2: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && bash scripts/start_worker_critical.sh
# Terminal 3: cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && bash scripts/start_beat.sh

# iOS simulator:
# 1. Launch app
# 2. Navigate to departures
# 3. Verify: list populates (<2s initial load)
# 4. Verify: delays show '+X min' if NSW has delays
# 5. Verify: auto-refresh every 30s (countdown changes)
# 6. Verify: pull-to-refresh works (loading indicator)
# 7. Check Redis: redis-cli TTL vp:buses:v1 # Should be 60-75s throughout test

# Expected logs (structured JSON):
# Worker: poll_gtfs_rt_started, vp_cached, tu_cached, poll_gtfs_rt_complete
# Backend: departures_fetched, stop_id=200060, realtime_count=X
```

**References:**
- Acceptance criteria: exploration-report.json (lines 250-264)

---

### Checkpoint 10: Graceful Degradation Test

**Goal:** Verify offline/stale cache behavior

**Backend Work:**
- None (testing checkpoint)

**iOS Work:**
- None (testing checkpoint)

**Design Constraints:**
- Must verify stale cache → static fallback (no 503 errors)
- Must verify iOS offline mode → error message (no crash)

**Validation:**
```bash
# Test 1: Stale cache fallback
# Stop Celery workers (Ctrl+C in terminals 2-3)
# Wait 2 minutes (TTL expires)
curl 'http://localhost:8000/api/v1/stops/200060/departures'
# Expected: Returns static schedules (realtime: false, delay_s: 0)
# Expected: No 503 errors, HTTP 200 OK

# iOS simulator: departures still load (static data)

# Test 2: Offline mode
# iOS simulator → Settings → Wi-Fi off (or Xcode → Network Link Conditioner → 100% Loss)
# Tap departures
# Expected: Error message "No internet connection" (or similar)
# Expected: No crash, app remains functional (can browse offline GRDB data)

# Test 3: Network monitor
# iOS simulator → Settings → Wi-Fi on
# Verify: Offline banner disappears, departures refresh
```

**References:**
- iOS Research: `.phase-logs/phase-2/ios-research-network-monitor.md` (NWPathMonitor)
- Architecture: BACKEND_SPECIFICATION.md:Section 5.3 (graceful degradation)
- Pattern: PHASE_2_REALTIME.md:L800-811

---

## Acceptance Criteria

- [ ] Backend: Celery worker starts without import errors
- [ ] Backend: Beat schedules poll_gtfs_rt every 30s
- [ ] Backend: Redis has 10 keys after 30s (vp:* and tu:* for 5 modes)
- [ ] Backend: Redis keys have TTL 60-90s (`TTL vp:buses:v1` returns 60-75)
- [ ] Backend: `GET /stops/200060/departures` returns `realtime: true` for ≥1 trip (if NSW has delays)
- [ ] Backend: Stale cache test: Stop workers, wait 2min, API returns `realtime: false` (graceful degradation)
- [ ] iOS: DeparturesView shows list of departures
- [ ] iOS: Countdown '5 min' updates after 30s auto-refresh (becomes '4 min')
- [ ] iOS: Delay badges show orange '+2 min' when `delay_s > 0`
- [ ] iOS: Pull-to-refresh triggers network call, loading indicator appears
- [ ] iOS: Timer invalidates on back navigation (no memory leak)
- [ ] iOS: Offline mode test: Wi-Fi off, departures fail gracefully (error message, no crash)
- [ ] Logs: Structured JSON events (`poll_gtfs_rt_started`, `vp_cached`, `tu_cached`) in worker output
- [ ] Logs: No PII (no user IDs yet—Phase 3), no full protobuf dumps (log counts only)

---

## User Blockers (Complete Before Implementation)

**All blockers cleared (user confirmed):**

- [x] Verified NSW API key has GTFS-RT access (tested vehiclepos/realtime endpoints)
- [x] Verified Redis Railway connection (redis-cli PING test)
- [x] Ready to run 3 terminal windows for backend+worker+beat
- [x] Understand 30s wait after worker start for first Redis cache

---

## Research Notes

**iOS Research Completed:**

1. **Timer.scheduledTimer main thread scheduling** → `.phase-logs/phase-2/ios-research-timer-scheduling.md`
   - @MainActor sufficient for main RunLoop (no manual configuration)
   - Must invalidate() in onDisappear to prevent memory leak

2. **SwiftUI List item refresh optimization** → `.phase-logs/phase-2/ios-research-list-refresh-optimization.md`
   - SwiftUI auto-diffs by Identifiable.id (no manual optimization needed)
   - Computed properties (minutesUntil) recalculate cheaply on each render

3. **NetworkMonitor for offline detection** → `.phase-logs/phase-2/ios-research-network-monitor.md`
   - NWPathMonitor.pathUpdateHandler on background queue (wrap UI updates in Task { @MainActor })
   - Detect offline: path.status == .unsatisfied, show banner

4. **APIClient timeout handling** → `.phase-logs/phase-2/ios-research-urlsession-timeouts.md`
   - Set timeoutIntervalForRequest=8s (NSW API), timeoutIntervalForResource=15s (Celery hard limit)
   - Prevents 60s hang when backend kills task at 15s

**On-Demand Research (During Implementation):**

If confidence <80%, agent will research:
- NSW API GTFS-RT feed reliability (uptime stats, 429 rate limit window)
- Redis Railway auto-scaling triggers (memory >70%, connection pool limits)
- Celery Beat DST handling (Australia/Sydney timezone transitions, cron schedule drift)
- GTFS-RT protobuf schema stability (gtfs-realtime-bindings version pinning)

---

## Exploration Report

Attached: `.phase-logs/phase-2/exploration-report.json`

**Phase 1 State:**
- Completed: Static GTFS pipeline, iOS offline browsing, pattern model, FTS5 search
- Current state: Backend :8000 serving static GTFS data, iOS builds successfully
- No blockers

**10 Checkpoints:** 3 backend-only (1-3, 5), 1 backend service (4), 3 iOS-only (6-8), 2 integration tests (9-10)

---

**Plan Created:** 2025-11-14
**Estimated Duration:** 3 weeks (Weeks 6-8)
