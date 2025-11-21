# Phase 1.5 - Local Static Departures Service (Offline Engine) Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** Design and implement local static departures engine on iOS for fully offline stop departures using bundled GRDB database
**Complexity:** medium

---

## Problem Statement

iOS app currently fetches departures from backend API (realtime_service.get_realtime_departures) which merges static schedules with GTFS-RT. Phase 1.5 adds offline fallback by replicating backend's static SQL query logic directly on-device using GRDB. DatabaseManager.getDepartures() exists but is incomplete (118 lines, wrong schema assumptions). Need robust static departures service matching backend pattern model query (411 lines in realtime_service.py L143-203).

---

## Affected Systems

**System: iOS GRDB Static Departures Service**
- Current state: DatabaseManager.getDepartures() exists but incomplete - assumes wrong schema (queries departure_offset_secs from pattern_stops directly vs computing start_time+offset), no calendar service_id filtering, no trip→route joins. DeparturesRepository has offline fallback (L56-57) but returns minimal data.
- Gap: Missing: 1) Calendar-aware service filtering (monday-sunday bits, start_date/end_date, calendar_dates exceptions), 2) Pattern model query matching backend SQL (trips→patterns→pattern_stops→routes joins), 3) Start_time_secs + offset calculation, 4) Proper pagination/limit, 5) Route metadata (route_type, color, long_name)
- Files affected:
  - SydneyTransit/Core/Database/DatabaseManager.swift
  - SydneyTransit/Data/Repositories/DeparturesRepository.swift
  - SydneyTransit/Data/Models/Departure.swift

**System: Backend Static Departures SQL (Reference)**
- Current state: Fully implemented in realtime_service.py L143-203. Query joins pattern_stops→patterns→trips→routes→calendar, filters by stop_id+service_date+time_secs, computes actual_departure_secs=(start_time+offset), sorts ASC/DESC by direction, expands LIMIT 3x for delayed trains, returns 12 fields including route metadata.
- Gap: No gaps - this is reference implementation to replicate on iOS
- Files affected:
  - backend/app/services/realtime_service.py

**System: GRDB Schema (iOS SQLite)**
- Current state: Schema complete per ios_db_generator.py (L252-383): dict_stop/dict_route/dict_pattern (WITHOUT ROWID), stops/routes/patterns/pattern_stops/trips (integer FKs sid/rid/pid), calendar (bit-packed days INTEGER), calendar_dates. FTS5 stops_fts. All tables populated, validated, 30K stops + 364K pattern_stops.
- Gap: Schema is correct - just need correct Swift query logic
- Files affected:
  - backend/app/services/ios_db_generator.py
  - schemas/migrations/001_initial_schema.sql

---

## Key Technical Decisions

1. **Replicate backend static query exactly (pattern model)**
   - Rationale: Backend query (realtime_service.py L169-179) is battle-tested, calendar-aware, handles pattern model correctly. iOS must match schema/logic for consistent results offline.
   - Reference: realtime_service.py:L169-L179 (SQL query), DATA_ARCHITECTURE.md Section 6 (pattern model)
   - Critical constraint: Must compute actual_departure_secs = trips.start_time_secs + pattern_stops.departure_offset_secs (NOT use offset directly as absolute time)

2. **Calendar service filtering on-device**
   - Rationale: Static schedules require service_id→calendar mapping to determine which trips run on given date/weekday. Backend uses calendar table joins (L172-176). iOS must decode bit-packed days INTEGER and check start_date/end_date.
   - Reference: realtime_service.py:L172-L176, ios_db_generator.py:L586-L614 (_pack_calendar_days)
   - Critical constraint: Bit-pack decode: monday=bit0, tuesday=bit1...sunday=bit6. Must handle calendar_dates exceptions (not in Phase 1.5 scope, defer).

3. **No GTFS-RT / Redis in offline mode**
   - Rationale: Phase 1.5 is pure static schedules. Offline fallback returns realtime=false, delay_s=0, no platform/occupancy. DeparturesRepository.fetchDepartures() already handles fallback (L48-57).
   - Reference: DeparturesRepository.swift:L48-L57
   - Critical constraint: Departure model supports static data - just omit RT fields (platform=nil, occupancy_status=nil, wheelchairAccessible=0)

4. **Use existing Departure model, no schema changes**
   - Rationale: Departure.swift (L1-153) already has memberwise init (L95-117) for offline use. DatabaseManager can construct Departure objects directly without backend API.
   - Reference: Departure.swift:L95-L117 (memberwise init)
   - Critical constraint: Must set realtime=false, delay_s=0, realtimeTimeSecs=scheduledTimeSecs for static data

---

## Implementation Checkpoints

### Checkpoint 1: Implement calendar service filtering

**Goal:** Swift function to check if service_id active on given date/weekday using calendar table

**Backend Work:**
N/A

**iOS Work:**
- Add CalendarService extension to DatabaseManager
- Implement isServiceActive(db:serviceId:date:) -> Bool
- Decode bit-packed days INTEGER (calendar.days & (1 << weekday_index))
- Check start_date <= date <= end_date
- Write unit test with known service_id (weekday-only vs weekend)

**Design Constraints:**
- Follow ios_db_generator.py:L586-L614 for bit-pack mapping (monday=bit0...sunday=bit6)
- Use Foundation Calendar with explicit Australia/Sydney timezone
- Swift weekday is 1-indexed (Sunday=1), subtract 1 for bit operations
- Must handle edge case: service_id not found in calendar table → return false

**Validation:**
```bash
# Test in Xcode or command line
# Expected: Circular Quay (stop_id 200060) on Monday returns different trip count than Sunday
```

**References:**
- Pattern: Calendar bit-pack decode (ios_db_generator.py:L586-L614)
- iOS Research: `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-swift-calendar-weekday.md`
- iOS Research: `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-swift-bitwise-operations.md`

---

### Checkpoint 2: Rewrite getDepartures() with pattern model query

**Goal:** Match backend SQL query (realtime_service.py L169-179) in Swift/GRDB

**Backend Work:**
N/A

**iOS Work:**
- Replace DatabaseManager.getDepartures() SQL (L80-95)
- Join pattern_stops→patterns→trips→routes using pid/rid integer FKs
- Add calendar join and service filtering (use Checkpoint 1 function)
- Compute actual_departure_secs = start_time_secs + departure_offset_secs
- Filter WHERE ps.sid = ? AND actual_departure_secs >= ? AND actual_departure_secs <= ?
- ORDER BY actual_departure_secs ASC, LIMIT ?
- Return Departure objects with route_short_name, route_long_name, route_type, route_color

**Design Constraints:**
- Follow backend/app/services/realtime_service.py:L169-L179 SQL structure exactly
- Use raw SQL with Database.prepare() for 5-table join (simpler than GRDB associations)
- Implement FetchableRecord for type-safe row parsing
- Must set realtime=false, delay_s=0, realtimeTimeSecs=scheduledTimeSecs for all static departures
- Time window: current_time_secs to current_time_secs + 7200 (2 hours)

**Validation:**
```bash
# Compare offline iOS query with backend API
# Query: Circular Quay (stop_id 200060) at 09:00
# Expected: Same departure count/times as backend /stops/200060/departures?time=9:00 (±0s for static)
curl http://localhost:8000/api/v1/stops/200060/departures?time=09:00
# Run iOS query at 09:00 Sydney time, compare results
```

**References:**
- Pattern: Pattern model query (realtime_service.py:L169-L179)
- Architecture: DATA_ARCHITECTURE.md Section 6 (pattern model)
- iOS Research: `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-grdb-complex-joins.md`

---

### Checkpoint 3: Integrate with DeparturesRepository fallback

**Goal:** Offline fallback in DeparturesRepository returns rich static data

**Backend Work:**
N/A

**iOS Work:**
- Update DeparturesRepository.fetchDepartures() L56-57 to pass limit parameter
- Test offline mode: disable Wi-Fi, navigate to departures
- Verify UI shows route badges, headsigns, formatted times (not 'Scheduled' placeholders)
- Add logging: 'Using offline static departures' with count

**Design Constraints:**
- Follow DEVELOPMENT_STANDARDS.md offline-first repository pattern
- Must gracefully handle errors (e.g., invalid stop_id → return empty array, not crash)
- Log structured events: `logger.info("offline_departures_loaded", stop_id: stopId, count: departures.count)`
- UI must clearly indicate offline mode (DeparturesView shows 'Scheduled' status, no platform/occupancy icons)

**Validation:**
```bash
# Airplane mode test
# 1. Enable Airplane Mode on iOS Simulator
# 2. Navigate to Departures screen for any stop
# Expected: DeparturesView shows 10-20 departures with route colors, no error message or loading spinner stuck
```

**References:**
- Pattern: Offline-first repository fallback (DeparturesRepository.swift:L36-L57)
- Architecture: IOS_APP_SPECIFICATION.md (offline-first architecture)

---

### Checkpoint 4: Performance & edge cases

**Goal:** Optimize query, handle service_date edge cases (overnight trips, no service)

**Backend Work:**
N/A

**iOS Work:**
- Add index on pattern_stops(sid, departure_offset_secs) if missing (check ios_db_generator.py)
- Handle overnight trips: departure_offset_secs >= 86400 (next day)
- Return empty [] if no calendar match (e.g., public holiday with no service)
- Measure query time: log duration_ms, target <100ms for 20 departures

**Design Constraints:**
- Follow backend pattern for overnight trips: if departure_offset_secs >= 86400, treat as next-day service
- Must verify index exists: `CREATE INDEX IF NOT EXISTS idx_pattern_stops_sid_offset ON pattern_stops(sid, departure_offset_secs)`
- Performance target: <100ms on iPhone 12 simulator for 20 departures (simulate with XCTest performance test)
- Edge cases: late-night (23:30), early morning (01:00 next-day trips), Sunday (weekend service_id)

**Validation:**
```bash
# Test edge cases in Xcode
# 1. Late-night stop (23:30) - should show overnight trips with offset >= 86400
# 2. Early morning (01:00) - should show trips from previous day's late service
# 3. Sunday - should return weekend service_id trips (different count than weekday)
# Expected: All cases return correct results or empty [], no crashes, <100ms query time
```

**References:**
- Pattern: Performance optimization (DEVELOPMENT_STANDARDS.md - GRDB indexing)
- Architecture: DATA_ARCHITECTURE.md Section 6 (overnight trips handling)

---

## Acceptance Criteria

- [x] Offline departures work: Disable Wi-Fi → navigate to any stop → see 10-20 upcoming departures with route names, times, colors
- [x] Calendar filtering correct: Monday vs Sunday returns different trips (weekday vs weekend service)
- [x] Performance acceptable: <100ms query time for 20 departures on iPhone 12 simulator
- [x] Data accuracy: Offline departure times match backend /stops/{id}/departures within ±0s (pure static, no RT)
- [x] Edge cases handled: Overnight trips (01:00), late-night (23:30), stops with sparse service (ferries) return correct results or empty []
- [x] No crashes: Invalid stop_id, missing calendar entries, empty pattern_stops gracefully return []
- [x] Integration test: DeparturesView offline shows 'Scheduled' status (not 'On time' or delays), no platform/occupancy icons

---

## User Blockers (Complete Before Implementation)

None

---

## Research Notes

**iOS Research Completed:**
- GRDB complex JOIN syntax (5-table join with integer FKs) → `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-grdb-complex-joins.md`
- Swift Date/Calendar manipulation (weekday index 1-7 vs 0-6, Sydney timezone DST) → `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-swift-calendar-weekday.md`
- Bit manipulation in Swift (calendar.days & (1 << weekday) for service filtering) → `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/ios-research-swift-bitwise-operations.md`

**On-Demand Research (During Implementation):**
None required

---

## Related Phases

**Phase 1:** Builds on Phase 1 GRDB static data - pattern_stops, trips, calendar tables already populated via ios_db_generator.py

**Phase 2:** Reuses backend static SQL logic from Phase 2 realtime_service.py (L143-203) - offline engine mirrors this without Redis/GTFS-RT

---

## Exploration Report

Attached: `.workflow-logs/custom/phase-1-5-local-static-departures-service-offline-engine/exploration-report.json`

---

**Plan Created:** 2025-11-21
**Estimated Duration:** 6-8 hours (2h calendar filtering, 3h pattern query rewrite, 1h integration, 2h testing edge cases)
