# Departures Infinite Scroll & Bug Fixes Implementation Plan

**Type:** Custom Plan (Bug Fixes)
**Context:** Fix 4 reported issues from last session - occupancy not showing, trip map not rendering, departures no infinite scroll, trip stops missing times
**Complexity:** Medium (3 already implemented, 1 new feature needed)

---

## Problem Statement

Last session implemented occupancy indicators, MapKit route visualization, and trip details enhancements (commits fc5c725, 42b9d84, 3ebf331, 0f14136, e00fbd3). However, user reports 4 issues:

1. **Occupancy icons not displaying** in departures list
2. **Trip details missing stops/times** from start to end
3. **Map not showing route/stops/timings** when selecting departure
4. **Departures no bidirectional scroll** (can't load past or future beyond initial view)

**Exploration findings:** Issues 1-3 are **fully implemented** in code. Likely data availability problems (Redis VehiclePosition, PostGIS coordinates). Issue 4 is **not implemented** - requires backend API + iOS LazyVStack pagination.

---

## Affected Systems

### System 1: Occupancy Display ✅ CODE COMPLETE

**Current state:**
- Backend extracts `occupancy_status` (0-8) from Redis `vp:{mode}:v1` blobs (realtime_service.py:208-224)
- iOS Departure model has `occupancy_status: Int?` field + `occupancyIcon` computed property (Departure.swift:14,45-61)
- DeparturesView shows occupancy icon conditionally (DeparturesView.swift:115-120)

**Gap:**
- Code complete. If not showing → Redis VehiclePosition data missing (GTFS-RT poller not deployed)

**Files affected:**
- backend/app/services/realtime_service.py:208-224
- SydneyTransit/Data/Models/Departure.swift:14,45-61
- SydneyTransit/Features/Departures/DeparturesView.swift:115-120

---

### System 2: Trip Details Stops/Times ✅ CODE COMPLETE

**Current state:**
- Backend queries ALL `pattern_stops` (no LIMIT), returns complete stop sequence with arrival_time_secs (trip_service.py:68-164)
- iOS TripDetailsView shows all stops via `ForEach(trip.stops)` (TripDetailsView.swift:26-28)

**Gap:**
- Code complete. All stops returned with times. If missing → backend data issue (pattern model incomplete)

**Files affected:**
- backend/app/services/trip_service.py:68-164
- SydneyTransit/Features/Trips/TripDetailsView.swift:26-28
- SydneyTransit/Data/Models/Trip.swift:29-57

---

### System 3: Map Route Visualization ✅ CODE COMPLETE

**Current state:**
- Backend returns `lat`/`lon` for each stop in trip_details (trip_service.py:149-164)
- iOS TripMapView creates MKPolyline + MKPointAnnotations (TripMapView.swift:1-65)
- Map conditionally rendered if ALL stops have coordinates (TripDetailsView.swift:11-15)

**Gap:**
- Code complete. If not showing → stop coordinates NULL in DB OR strict `allSatisfy` check hiding partial maps

**Files affected:**
- backend/app/services/trip_service.py:149-164
- SydneyTransit/Features/Trips/TripMapView.swift:1-65
- SydneyTransit/Features/Trips/TripDetailsView.swift:11-15

---

### System 4: Departures Bidirectional Scroll ❌ NOT IMPLEMENTED

**Current state:**
- Backend: Single `time_secs` param filters departures `>= time` (future only)
- iOS: DeparturesView loads once on appear, 30s auto-refresh. No pagination.

**Gap:**
- Cannot scroll up for past departures
- Cannot scroll down for future beyond initial limit
- Requires backend `direction` param (`past`/`future`) + iOS LazyVStack sentinel-based loading

**Files affected:**
- backend/app/api/v1/stops.py:176-300 (departures endpoint)
- SydneyTransit/Features/Departures/DeparturesView.swift:1-144
- SydneyTransit/Features/Departures/DeparturesViewModel.swift:1-63

---

## Key Technical Decisions

### Decision 1: Time-Based Pagination (Not Offset/Limit)

**Rationale:** Backend uses `time_secs` parameter for filtering departures. Matches GTFS-RT best practices: time-based queries for transit schedules.

**Reference:** backend/app/api/v1/stops.py:179-243

**Critical constraint:** Must support bidirectional queries:
- `direction=future`: `WHERE (start_time + offset) >= time_secs ORDER BY ASC`
- `direction=past`: `WHERE (start_time + offset) <= time_secs ORDER BY DESC`

---

### Decision 2: Occupancy From VehiclePosition Blob

**Rationale:** GTFS-RT spec places `occupancy_status` in VehiclePosition message (not TripUpdate). Matches NSW API structure.

**Reference:** DATA_ARCHITECTURE.md:217-224, realtime_service.py:208-224

**Critical constraint:** Requires Redis `vp:{mode}:v1` blob populated by GTFS-RT poller. If poller not deployed, occupancy null.

---

### Decision 3: Stop Coordinates From Static GTFS

**Rationale:** Stop locations static (not real-time). Pattern model stores stop_id, JOIN to stops table for coordinates.

**Reference:** trip_service.py:68-76,149-154

**Critical constraint:** If `stops.stop_lat`/`stop_lon` NULL, map hidden. User confirmed coords populated from GTFS stops.txt.

---

### Decision 4: Map Visibility All-Or-Nothing

**Rationale:** Prevents broken polylines if some stops missing coords. Conservative approach.

**Reference:** TripDetailsView.swift:11 (`allSatisfy` check)

**Critical constraint:** Single missing coord hides entire map. Alternative: graceful degradation (show partial route, skip nil coords). Trade-off: correctness vs UX.

---

### Decision 5: Past Departures Use Scheduled Times Only

**Rationale:** User confirmed "Scheduled only" - no historical real-time data retention needed. Simpler implementation.

**Reference:** User response to clarifying question

**Critical constraint:** No historical RT delays for past departures. Show static GTFS schedule for times before `now()`.

---

## Implementation Checkpoints

### Checkpoint 1: Verify Data Availability

**Goal:** Confirm Redis VehiclePosition blobs exist + PostGIS coordinates populated before debugging rendering issues

**Backend Work:**
- Check Redis keys: `redis-cli KEYS 'vp:*'` (expect `vp:sydneytrains:v1`, `vp:buses:v1`, etc.)
- Query sample VehiclePosition: `redis-cli --raw GET vp:sydneytrains:v1 | gunzip | jq '.entity[0].vehicle.occupancy_status'`
- Query stop coordinates: `SELECT COUNT(*) FROM stops WHERE stop_lat IS NULL OR stop_lon IS NULL` (expect 0)
- Check GTFS-RT poller status: `celery -A app.tasks.celery_app inspect active` (look for `poll_gtfs_rt` task)

**iOS Work:**
- N/A

**Design Constraints:**
- User confirmed coords populated from GTFS stops.txt
- GTFS-RT poller status unknown - must verify Redis data

**Validation:**
```bash
# Expected Redis keys
redis-cli KEYS 'vp:*'
# Output: vp:sydneytrains:v1, vp:buses:v1, vp:ferries:v1, vp:lightrail:v1

# Expected coordinates
psql -h localhost -U postgres -d sydney_transit_dev -c "SELECT COUNT(*) FROM stops WHERE stop_lat IS NULL"
# Output: 0

# If Redis keys missing
celery -A app.tasks.celery_app inspect registered | grep poll_gtfs_rt
# If not registered: deploy GTFS-RT poller from Phase 2
```

**References:**
- GTFS-RT poller: backend/app/tasks/gtfs_rt_poller.py
- Redis data structure: DATA_ARCHITECTURE.md:217-266
- PostGIS coordinates: trip_service.py:149-154

---

### Checkpoint 2: Implement Departures Bidirectional Scroll

**Goal:** Load past departures (scroll up) and future departures (scroll down) with SwiftUI LazyVStack onAppear triggers

**Backend Work:**
- Modify `/stops/{stop_id}/departures` endpoint: add `direction` query param (`past` | `future`, default `future`)
- For `direction=past`:
  - Query: `WHERE (pattern.start_time + pattern_stop.arrival_offset_secs) <= time_secs ORDER BY DESC LIMIT {limit}`
  - Returns departures earlier than `time_secs` in reverse chronological order
- For `direction=future`:
  - Existing behavior: `WHERE ... >= time_secs ORDER BY ASC LIMIT {limit}`
- Return pagination metadata in response envelope:
  ```json
  {
    "data": [...],
    "meta": {
      "pagination": {
        "has_more_past": true,
        "has_more_future": true,
        "earliest_time_secs": 1234567890,
        "latest_time_secs": 1234567900
      }
    }
  }
  ```

**iOS Work:**
- DeparturesViewModel changes:
  - Replace single `departures: [Departure]` with separate `pastDepartures: [Departure]` + `futureDepartures: [Departure]`
  - Track `earliestTimeSecs: Int?` + `latestTimeSecs: Int?` for pagination boundaries
  - Add `loadPastDepartures()` + `loadFutureDepartures()` methods
  - Deduplicate by `trip_id` when appending/prepending
- DeparturesView changes:
  - Replace `List` with `ScrollView { LazyVStack }` for sentinel-based pagination
  - Add top sentinel: `Color.clear.frame(height: 1).onAppear { viewModel.loadPastDepartures() }`
  - Add bottom sentinel: `Color.clear.frame(height: 1).onAppear { viewModel.loadFutureDepartures() }`
  - Combine arrays: `ForEach(viewModel.pastDepartures.reversed() + viewModel.futureDepartures)`
  - Use `ScrollViewReader` to preserve scroll position when prepending past departures

**Design Constraints:**
- Follow time-based pagination pattern (not offset/limit) - backend/app/api/v1/stops.py:179-243
- Use MVVM @Published state - DEVELOPMENT_STANDARDS.md:750-906
- Deduplicate departures by `trip_id` to prevent duplicates during pagination
- Must handle "now()" boundary gracefully (overlap between past/future queries)

**Validation:**
```bash
# Test backend direction param
curl "http://localhost:8000/api/v1/stops/200060/departures?time_secs=1700000000&direction=past&limit=5"
# Expected: 5 departures with times <= 1700000000 in DESC order

curl "http://localhost:8000/api/v1/stops/200060/departures?time_secs=1700000000&direction=future&limit=5"
# Expected: 5 departures with times >= 1700000000 in ASC order

# Test iOS infinite scroll
# 1. Run app, navigate to departures for stop
# 2. Scroll to top - past departures load (earlier times)
# 3. Scroll to bottom - future departures load (later times)
# 4. Verify no duplicates, smooth scrolling
```

**References:**
- Backend pagination: backend/app/api/v1/stops.py:176-300
- iOS LazyVStack pattern: DEVELOPMENT_STANDARDS.md (iOS data flow section)
- Sentinel-based loading: Standard SwiftUI infinite scroll pattern (onAppear on invisible view)

---

### Checkpoint 3: Debug Occupancy Icon Rendering

**Goal:** Add debug logging to identify why occupancy icons not showing (data issue vs rendering bug)

**Backend Work:**
- Add debug logging in `realtime_service.py` before occupancy extraction:
  ```python
  logger.debug("vp_blob_check", mode=mode, blob_exists=vp_blob is not None, blob_size=len(vp_blob) if vp_blob else 0)
  ```
- Log sample VehiclePosition data:
  ```python
  if vp_data:
      logger.debug("vp_sample", trip_id=vp_data[0].get('trip_id'), occupancy=vp_data[0].get('occupancy_status'))
  ```
- Add logging in departures endpoint response build:
  ```python
  logger.debug("departure_occupancy", trip_id=dep['trip_id'], occupancy_status=dep.get('occupancy_status'))
  ```

**iOS Work:**
- Add debug logging in `DepartureRow` before occupancy icon rendering:
  ```swift
  Logger.app.debug("Occupancy check", metadata: [
      "trip_id": "\(departure.tripId)",
      "occupancy_status": "\(departure.occupancy_status?.description ?? "nil")"
  ])
  ```
- Add unit test for `occupancyIcon` computed property:
  ```swift
  func testOccupancyIconMapping() {
      let lowDeparture = Departure(occupancy_status: 0, ...)
      XCTAssertEqual(lowDeparture.occupancyIcon?.symbol, "figure.stand")
      XCTAssertEqual(lowDeparture.occupancyIcon?.color, .green)
      // Test all 0-8 values
  }
  ```
- Verify JSON decoding: Add breakpoint in `DeparturesViewModel.loadDepartures()` after API call

**Design Constraints:**
- Follow structlog JSON logging pattern - DEVELOPMENT_STANDARDS.md:1126-1172
- Never log PII (user tokens, email)
- Use Logger.app for iOS logging (unified logging system)

**Validation:**
```bash
# Backend logs
cd backend && source venv/bin/activate && uvicorn app.main:app --reload
# Check logs for: "vp_blob_check", "vp_sample", "departure_occupancy"

# iOS logs (Xcode console)
# Expected: "Occupancy check" logs with occupancy_status values
# If nil: Redis data missing (Checkpoint 1)
# If non-nil but icon not showing: computed property bug (unit test will catch)

# Unit test
# Expected: All occupancy values 0-8 map to correct colors/symbols
```

**References:**
- Backend logging: realtime_service.py:208-224
- iOS logging: DeparturesView.swift:115-120
- Structlog patterns: DEVELOPMENT_STANDARDS.md:1126-1172

---

### Checkpoint 4: Fix Map Rendering (Graceful Degradation)

**Goal:** Debug why map not showing route + add graceful degradation for partial coordinate availability

**Backend Work:**
- Add debug logging in `trip_service.py` when returning stop coordinates:
  ```python
  logger.debug("trip_stop_coords", stop_id=stop_id, lat=stop_lat, lon=stop_lon, has_coords=stop_lat is not None)
  ```
- Add aggregation log after query:
  ```python
  stops_with_coords = sum(1 for s in stops if s['lat'] is not None)
  logger.info("trip_coords_summary", trip_id=trip_id, total_stops=len(stops), stops_with_coords=stops_with_coords)
  ```

**iOS Work:**
- Add debug logging in `TripDetailsView` before map visibility check:
  ```swift
  Logger.app.debug("Map visibility", metadata: [
      "stops_count": "\(trip.stops.count)",
      "stops_with_coords": "\(trip.stops.filter { $0.lat != nil && $0.lon != nil }.count)"
  ])
  ```
- **Graceful degradation option:** Change `allSatisfy` to threshold-based check:
  ```swift
  let stopsWithCoords = trip.stops.filter { $0.lat != nil && $0.lon != nil }
  if stopsWithCoords.count >= 2 {
      TripMapView(stops: stopsWithCoords)  // Show partial route
  }
  ```
- Update `TripMapView` to handle partial routes:
  - Filter nil coords before creating MKPolyline
  - Add warning text overlay: "Showing partial route (X of Y stops)"

**Design Constraints:**
- User confirmed coords populated - if missing, PostGIS load issue
- Graceful degradation preferred over strict all-or-nothing (UX improvement)
- Must show warning if partial route displayed

**Validation:**
```bash
# Backend logs
# Expected: "trip_coords_summary" showing total_stops and stops_with_coords

# iOS logs
# Expected: "Map visibility" with counts
# If stops_with_coords < total_stops: Show partial map with warning
# If stops_with_coords >= 2: Show map
# If stops_with_coords < 2: Hide map (not enough for polyline)

# Manual test
# 1. Run app, navigate to trip details
# 2. Verify map displays with route + annotations
# 3. If partial coords: verify warning overlay shows
```

**References:**
- Backend coords: trip_service.py:149-164
- iOS map rendering: TripMapView.swift:1-65
- Conditional rendering: TripDetailsView.swift:11-15

---

## Acceptance Criteria

- [x] **Checkpoint 1 complete:** Redis VehiclePosition data availability verified, PostGIS coordinates confirmed
- [ ] **Occupancy icons display** in departures list (green=low, yellow=moderate, orange=high, red=crowded)
- [ ] **Trip details show all stops** from start to end with arrival times (no missing stops)
- [ ] **Map displays blue polyline** route connecting all stops
- [ ] **Map shows MKPointAnnotation** for each stop with stop name + arrival time subtitle
- [ ] **Map auto-zooms** to fit all annotations
- [ ] **Departures infinite scroll up:** Load past departures when scrolling to top (earlier times)
- [ ] **Departures infinite scroll down:** Load future departures when scrolling to bottom (later times)
- [ ] **No duplicate departures** during pagination (trip_id deduplication)
- [ ] **Smooth scroll performance** (no lag when loading new pages)
- [ ] **Past departures reverse chronological** (most recent first when scrolling up)
- [ ] **Future departures chronological** (earliest first)
- [ ] **Graceful degradation:** Map shows partial route if some stops missing coords (with warning overlay)

---

## User Blockers (Complete Before Implementation)

**None** - User confirmed:
- Stop coordinates populated from GTFS stops.txt
- Past departures should use scheduled times only (no historical RT retention needed)

**To verify:**
- [ ] Check Redis VehiclePosition data availability (Checkpoint 1)
- [ ] If Redis empty: Deploy GTFS-RT poller from Phase 2 before testing occupancy

---

## Research Notes

**iOS Research Topics:**
- SwiftUI LazyVStack with onAppear triggers for bidirectional infinite scroll
- ScrollViewReader for scroll position preservation when prepending items
- Set-based deduplication for preventing duplicate list items

**Research completed:** No upfront research needed. Standard SwiftUI patterns documented in:
- [Apple Docs: LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack)
- [Apple Docs: ScrollViewReader](https://developer.apple.com/documentation/swiftui/scrollviewreader)
- Pattern: Use invisible sentinel views with `.onAppear` to trigger pagination

**On-Demand Research:**
- None required. Implementation uses standard SwiftUI + backend patterns from DEVELOPMENT_STANDARDS.md

---

## Related Phases

**Phase 2:** This plan fixes bugs in GTFS-RT occupancy + trip details from Phase 2 implementation (commits fc5c725, 42b9d84, 3ebf331, 0f14136, e00fbd3)

**Independent from roadmap:** Ad-hoc bug fixes + new feature (infinite scroll) not covered in phase specs

---

## Exploration Report

**Attached:** `.workflow-logs/custom/departures-infinite-scroll-fixes/exploration-report.json`

**Critical Findings:**
- 3 of 4 issues **fully implemented** in code (occupancy, trip stops/times, map visualization)
- Likely data availability issues (Redis VehiclePosition, PostGIS coordinates)
- 1 issue **not implemented** (departures infinite scroll) - requires backend + iOS work
- Trip stops query has no LIMIT clause (returns complete sequence)
- Map visibility conditional on ALL stops having coords (strict check may hide partial maps)

**Recommended Order:**
1. Checkpoint 1 (verify data) - BLOCKER for Checkpoints 3-4
2. Checkpoint 2 (infinite scroll) - highest complexity, user-facing priority
3. Checkpoint 3 (occupancy debug) - quick fix if data exists
4. Checkpoint 4 (map debug) - add graceful degradation for UX improvement

---

**Plan Created:** 2025-11-17
**Estimated Duration:** 4-6 hours (1h verification + 2-3h infinite scroll + 1-2h debugging)
