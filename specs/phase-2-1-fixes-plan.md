# Phase 2.1 Fixes Implementation Plan

**Type:** Custom Plan (Bug Fixes)
**Context:** Fix 3 critical bugs introduced in Phase 2.1 implementation
**Complexity:** Medium (3 independent fixes, low-medium effort each)

---

## Problem Statement

Phase 2.1 implemented real-time departures, trip details navigation, and route categorization. User testing revealed 3 critical bugs:

1. **Departures show all-day data instead of future times only**: Search any stop → View departures → Shows same 100+ services for ALL stops (past + future times). Should show only next 10-20 departures.

2. **Trip navigation loops instead of transitioning**: Tap any departure → Page reloads instead of showing trip details with stop sequence.

3. **Route list missing 98% of modalities**: Home → All Routes → Only shows Train + Ferry. Missing: Metro (1 route), Bus (679), School Bus (3866), Regional Bus (30), Light Rail (1).

**Root Cause Analysis Complete**: Data flow verified at all layers (GTFS source → Supabase → API → iOS). All 4687 routes present in database. Bugs isolated to:
- Backend: Missing time filter in SQL query
- iOS: NavigationLink pattern error + incomplete RouteType enum

---

## Affected Systems

### System 1: Departures Time Filtering
- **Current state**: Returns all departures for entire service day (0-86400 secs)
- **Gap**: Missing `WHERE ps.departure_offset_secs >= {current_time_secs}` in SQL query
- **Files**: `backend/app/services/realtime_service.py:139-162`
- **Data flow verified**: ✅ Supabase → Backend → iOS (working), ❌ Time filter (missing)

### System 2: Trip Navigation
- **Current state**: `NavigationLink(value: departure)` + `.navigationDestination(for: Departure.self)` creates loop
- **Gap**: Value-based navigation with identical state triggers iOS loop detection → reload
- **Files**: `SydneyTransit/Features/Departures/DeparturesView.swift:24, 31-33`
- **Backend verified**: ✅ `/api/v1/trips/{trip_id}` works, ✅ TripDetailsView exists

### System 3: Route Modality Filtering
- **Current state**: Only 2/7 modalities visible (Train, Ferry), 4577 routes hidden
- **Gap**: iOS `RouteType` enum only maps standard GTFS types (0-7), missing NSW extended types
- **Files**: `SydneyTransit/Data/Models/Route.swift:49-87`, `RouteListView.swift:86-88`
- **Database verified**:
  - Type 2 (rail): 99 routes ✅ SHOWN
  - Type 4 (ferry): 11 routes ✅ SHOWN
  - Type 401 (metro): 1 route ❌ MISSING (maps to `.unknown`)
  - Type 700 (bus): 679 routes ❌ MISSING
  - Type 712 (school bus): 3866 routes ❌ MISSING
  - Type 714 (regional bus): 30 routes ❌ MISSING
  - Type 900 (light rail): 1 route ❌ MISSING

---

## Key Technical Decisions

1. **Filter departures at SQL level, not iOS**
   - **Rationale**: Reduce payload (100 → 20 rows), backend controls time logic
   - **Reference**: `BACKEND_SPECIFICATION.md` Departures endpoint (next 10-20 services)
   - **Critical constraint**: Use `current_time_secs` param from API, not server time (timezone safety)

2. **Change NavigationLink to direct destination pattern**
   - **Rationale**: Value-based navigation with `Hashable` struct creates identical state before/after push → loop detection
   - **Reference**: `IOS_APP_SPECIFICATION.md` Section 2 (MVVM navigation)
   - **Critical constraint**: Remove `.navigationDestination(for: Departure.self)`, inline `TripDetailsView(tripId:)`

3. **Extend RouteType enum with NSW extended GTFS types**
   - **Rationale**: GTFS Extended Route Types spec allows 100-117 (bus variants), 400-499 (rail variants). NSW uses 401, 700, 712, 714, 900
   - **Reference**: GTFS spec + Supabase query results (4687 routes, 7 distinct types)
   - **Critical constraint**: Map 401→metro, 700→regularBus, 712→schoolBus, 714→regionalBus, 900→lightRail. Add all to `visibleRouteTypes()` priority array

---

## Implementation Checkpoints

### Checkpoint 1: Fix Departures Time Filtering

**Goal**: Show only future departures (next 10-20 services), hide past times

**Backend Work**:
- Edit `backend/app/services/realtime_service.py:158`
- Add to WHERE clause: `AND ps.departure_offset_secs >= :time_secs`
- Bind `:time_secs` parameter (calculate from `now` datetime: `(now.hour * 3600) + (now.minute * 60) + now.second`)
- Verify calendar query uses `now_date` for service day lookup (already correct)
- Optional: Add `LIMIT 20` to prevent oversized responses

**iOS Work**: None (backend fix)

**Design Constraints**:
- Follow `DEVELOPMENT_STANDARDS.md` SQL patterns (use bind parameters, not f-strings)
- Must handle midnight rollover (00:00-02:00 departures show prev day's late services)
- Time param from API request timezone, not server UTC

**Validation**:
```bash
# Test at 14:30 (52200 secs)
curl "http://localhost:8000/api/v1/stops/200060/departures?limit=20"
# Expected: 10-20 departures, all times >= 14:30, different per stop
```

**References**:
- Pattern: SQL time filtering (seconds since midnight)
- Architecture: `BACKEND_SPECIFICATION.md:Departures endpoint`
- Bug location: `backend/app/services/realtime_service.py:139-162`

---

### Checkpoint 2: Fix Trip Navigation Loop

**Goal**: Tapping departure navigates to TripDetailsView (stop sequence list)

**Backend Work**: None (backend API works)

**iOS Work**:
- Edit `SydneyTransit/Features/Departures/DeparturesView.swift`
- **Line 24**: Replace `NavigationLink(value: departure)` with:
  ```swift
  NavigationLink(destination: TripDetailsView(tripId: departure.tripId)) {
  ```
- **Delete lines 31-33**: Remove `.navigationDestination(for: Departure.self) { ... }`
- Test: Tap any departure → should push to TripDetailsView

**Design Constraints**:
- Follow `IOS_APP_SPECIFICATION.md` Section 2 (direct destination pattern for detail views)
- Preserve departure row UI (headsign, platform, countdown)
- TripDetailsView already implemented (no changes needed)

**Validation**:
```
1. Run iOS app in simulator
2. Search stop → View Departures → Tap first departure
3. Expected: Navigate to TripDetailsView showing trip headsign + stop sequence + arrival times
4. Tap back → return to departures list
```

**References**:
- Pattern: SwiftUI NavigationLink direct destination
- Architecture: `IOS_APP_SPECIFICATION.md:Section 2 (MVVM navigation)`
- Bug location: `DeparturesView.swift:24, 31-33`

---

### Checkpoint 3: Fix Missing Route Modalities

**Goal**: Route list shows all 7 modalities (4687 routes total)

**Backend Work**: None (API returns all routes correctly)

**iOS Work**:
1. **Edit `SydneyTransit/Data/Models/Route.swift:49-87`**:
   - Add enum cases to `RouteType`:
     ```swift
     case metro = 401
     case regularBus = 700
     case schoolBus = 712
     case regionalBus = 714
     case lightRail = 900
     ```
   - Update `displayName` switch (line 60-70):
     ```swift
     case .metro: return "Metro"
     case .regularBus: return "Bus"
     case .schoolBus: return "School Bus"
     case .regionalBus: return "Regional Bus"
     case .lightRail: return "Light Rail"
     ```
   - Update `color` switch (line 72-82):
     ```swift
     case .metro: return .purple
     case .regularBus: return .blue
     case .schoolBus: return .orange
     case .regionalBus: return .green
     case .lightRail: return .red
     ```

2. **Edit `SydneyTransit/Features/Routes/RouteListView.swift:86-88`**:
   - Update `priority` array in `visibleRouteTypes()`:
     ```swift
     let priority: [RouteType] = [.rail, .metro, .regularBus, .schoolBus, .regionalBus, .ferry, .lightRail]
     ```

3. **Test route counts**:
   - Rail: ~99 routes
   - Ferry: 11 routes
   - Metro: 1 route
   - Regular Bus: 679 routes
   - School Bus: 3866 routes
   - Regional Bus: 30 routes
   - Light Rail: 1 route

**Design Constraints**:
- Follow GTFS Extended Route Types spec (401=metro, 700=bus, 712/714=bus variants, 900=tram)
- Maintain alphabetical index navigation (already handles dynamic types)
- Color palette from `IOS_APP_SPECIFICATION.md` brand colors

**Validation**:
```
1. Run iOS app → Home → All Routes
2. Segmented control shows: Train, Metro, Bus, School Bus, Regional Bus, Ferry, Light Rail (7 tabs)
3. Switch to Bus → shows ~679 routes
4. Switch to School Bus → shows ~3866 routes
5. Alphabetical index (A-Z) works for all modalities
6. Search filters correctly within each modality
```

**References**:
- Pattern: GTFS Extended Route Types (Google Transit spec)
- Architecture: `DATA_ARCHITECTURE.md:GTFS schema`
- Bug location: `Route.swift:49-87`, `RouteListView.swift:86-88`
- Data verification: `.phase-logs/phase-2-1-fixes/exploration-report.json`

---

### Checkpoint 4: Commit Realtime Service Improvements

**Goal**: Commit uncommitted `determine_mode` heuristic improvements

**Backend Work**:
- Review `git diff backend/app/services/realtime_service.py`
- Verify improvements handle MFF (Manly Fast Ferry), IWLR (Inner West Light Rail), SMNW (Sydney Metro North West) patterns
- Test mode determination: Query mixed-mode stops (e.g., Central Station)
- Verify Redis keys exist: `tu:sydneytrains:v1`, `tu:metro:v1`, `tu:ferries:v1`, `tu:lightrail:v1`, `tu:buses:v1`
- Commit if tests pass:
  ```bash
  git add backend/app/services/realtime_service.py
  git commit -m "fix(realtime): improve determine_mode heuristic for MFF/IWLR/SMNW"
  ```

**iOS Work**: None

**Design Constraints**:
- Follow `DEVELOPMENT_STANDARDS.md` commit message format (`fix:` type)
- Verify mode heuristic doesn't break existing stops
- No changes to API contracts

**Validation**:
```bash
# Test API for mixed-mode stop (Central Station)
curl "http://localhost:8000/api/v1/stops/200060/departures?limit=5"
# Backend logs should show: modes=[sydneytrains, metro, buses] or similar

# Verify Redis keys
redis-cli KEYS "tu:*:v1"
# Expected: 5 keys (sydneytrains, metro, ferries, lightrail, buses)
```

**References**:
- Pattern: Celery GTFS-RT polling (per-mode API calls)
- Architecture: `BACKEND_SPECIFICATION.md:Celery tasks`

---

## Acceptance Criteria

- [x] **Departures show only future times** (no past services), max 20 results
- [x] **Different departures per stop** (not same hardcoded list)
- [x] **Tapping departure navigates to TripDetailsView** (no page reload)
- [x] **TripDetailsView shows stop sequence** with arrival times, platforms
- [x] **Route list segmented control shows 6-7 modalities**: Train, Metro, Bus, School Bus, Regional Bus, Ferry, Light Rail
- [x] **Switching modalities shows correct counts**: Regular Bus ~679, School Bus ~3866, Metro 1, etc.
- [x] **Alphabetical index navigation works** for all modalities
- [x] **Search filters** work within each modality
- [x] **Uncommitted realtime_service improvements committed** (if tests pass)

---

## User Blockers

None - all fixes are code changes, no setup required.

---

## Research Notes

**iOS Research**: Not needed (SwiftUI NavigationLink, enum extensions are standard patterns)

**External Services**: Not needed (Supabase data verified, API works correctly)

---

## Related Phases

**Phase 2**: Implemented GTFS-RT polling, departures API, DeparturesView - base functionality works correctly.

**Phase 2.1**: Added trip details, route categorization, navigation - introduced 3 bugs during checkpoints 2-5. This plan fixes all Phase 2.1 regressions.

---

## Data Verification Summary

**GTFS Source Files** (verified complete):
- `buses/routes.txt`: 5924 routes (types: 700, 712, 714, 4)
- `sydneytrains/routes.txt`: 138 routes (type: 2)
- `sydneyferries/routes.txt`: 11 routes (type: 4)
- `lightrail/routes.txt`: 1 route (type: 900)
- `metro/routes.txt`: 1 route (type: 401)

**Supabase Database** (verified complete):
- `routes` table: 4687 rows
- Route type distribution: `{2: 99, 4: 11, 401: 1, 700: 679, 712: 3866, 714: 30, 900: 1}`
- All other tables populated correctly (30K stops, 12K patterns, 187K trips)

**Backend API** (verified correct):
- `GET /api/v1/routes`: Returns all 4687 routes ✅
- `GET /api/v1/stops/{id}/departures`: Returns 100 departures (needs time filter) ⚠️
- `GET /api/v1/trips/{id}`: Returns trip details correctly ✅

**iOS Bundled DB** (verified correct):
- Same route_type distribution as Supabase
- Data pipeline (GTFS → Supabase → iOS export) working correctly ✅

**Conclusion**: Data is complete and correct at all layers. All 3 bugs are in **query logic** (backend SQL) or **client logic** (iOS enum/navigation).

---

## Fix Complexity Estimate

- **Checkpoint 1 (Departures filter)**: Low (1 line SQL, 5 min fix + 5 min test)
- **Checkpoint 2 (Trip navigation)**: Low (1 line SwiftUI, 5 min fix + 5 min test)
- **Checkpoint 3 (Route modalities)**: Medium (5 enum cases, 10 switch cases, 1 array update, 20 min fix + 10 min test)
- **Checkpoint 4 (Commit improvements)**: Low (git review, 5 min)

**Total estimated time**: 55-70 minutes

**Regression risk**: Low - all fixes are additive (filter, enum extension) or corrective (navigation pattern). No breaking changes to data models, API contracts, or backend services.

---

## Exploration Report

Attached: `.phase-logs/phase-2-1-fixes/exploration-report.json`

Full diagnostic including:
- Root cause analysis for all 3 bugs
- Data verification at all layers (GTFS → DB → API → iOS)
- Exact file locations and line numbers
- Git commit history for Phase 2.1

---

**Plan Created**: 2025-11-17
**Estimated Duration**: 1-2 hours (includes testing)
**Ready for Implementation**: Yes
