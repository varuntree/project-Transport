# Phase 1.5 Multi-Modal Search UI and Route Type Filters Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** Upgrade SearchView to complete multi-modal search UI with segmented control for modality filtering
**Complexity:** Medium

---

## Problem Statement

Upgrade SearchView with modal segmented control (All/Train/Bus/Ferry/LightRail/Metro) and correct NSW GTFS route_type filtering. Current FTS5 search returns all stops but no modality filters exist; RouteType enum already supports NSW extensions (401,700,712,714,900) but search lacks UI and query integration. Needed for complete Phase 1.5 multi-modal UX after Phase 2.2 modal coverage fixes.

---

## Affected Systems

**System: iOS SearchView UI (SearchView.swift)**
- Current state: FTS5 text search over stops_fts, displays results with icons, no route_type filtering
- Gap: Missing SearchMode enum, segmented control UI, and query integration to filter by modality
- Files affected: `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Search/SearchView.swift`

**System: GRDB Stop.search() query (Stop.swift)**
- Current state: Uses FTS5 MATCH on stops_fts with sanitized query, LIMIT 50, no JOIN filters
- Gap: Need optional route_type filter via JOIN to pattern_stops→patterns→trips→routes, maintaining FTS5 performance
- Files affected: `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Stop.swift`

**System: RouteType enum and transport icons (Stop.swift, Route.swift)**
- Current state: RouteType enum supports standard GTFS (0-7) + NSW extensions (401,700,712,714,900); Stop.transportIcon maps to SF Symbols
- Gap: Enum complete, but need mode-friendly grouping (All, Train, Bus, Ferry, LightRail, Metro) and ensure icons work across all modalities
- Files affected:
  - `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Stop.swift`
  - `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Route.swift`

---

## Key Technical Decisions

1. **SearchMode enum: All/Train/Bus/Ferry/LightRail/Metro (not 7 individual NSW types)**
   - Rationale: User-friendly segmented control groups NSW extensions (700/712/714→Bus, 401→Metro, 900→LightRail)
   - Reference: SYSTEM_OVERVIEW.md Section 4 (multi-modal UX), Route.swift:49-101 (RouteType enum)
   - Critical constraint: Map SearchMode to route_type array for SQL IN clause (e.g., .bus → [3,700,712,714])

2. **Filter at GRDB query level via JOIN pattern_stops→patterns→routes, not iOS post-filter**
   - Rationale: Maintain FTS5 performance, reduce memory (filter 50 → 10-30 per mode), leverage existing idx_pattern_stops_sid_offset index
   - Reference: Stop.swift:24-50 (FTS5 search), DatabaseManager.swift:206 (JOIN pattern with idx usage)
   - Critical constraint: Keep FTS5 MATCH first (indexed), add route_type WHERE after JOIN; avoid N+1 queries

3. **Use SwiftUI Picker with segmentedPickerStyle for mode selector**
   - Rationale: Standard iOS pattern, auto-handles state, accessible, compact (fits above search bar)
   - Reference: IOS_APP_SPECIFICATION.md Section 2 (MVVM), DEVELOPMENT_STANDARDS.md:194 (SwiftUI patterns)
   - Critical constraint: State in @State var selectedMode: SearchMode; debounce onChange same as search query

---

## Implementation Checkpoints

### Checkpoint 1: SearchMode enum and UI segmented control

**Goal:** User can select All/Train/Bus/Ferry/LightRail/Metro above search bar

**Backend Work:**
- N/A

**iOS Work:**
- Add SearchMode enum in `SearchView.swift`: All, Train(→2), Bus(→3,700,712,714), Ferry(→4), LightRail(→900), Metro(→1,401)
- Add `@State var selectedMode: SearchMode = .all` above searchQuery state
- Add Picker above List in SearchView body:
  ```swift
  Picker("Mode", selection: $selectedMode) {
      ForEach(SearchMode.allCases, id: \.self) { mode in
          Text(mode.displayName).tag(mode)
      }
  }
  .pickerStyle(.segmented)
  .padding(.horizontal)
  ```
- Wire `onChange(of: selectedMode)` to trigger performSearch (cancel existing task, debounce 300ms same as query)
- Update `performSearch()` signature to accept selectedMode, prepare to pass routeTypes: [Int]? to Stop.search()

**Design Constraints:**
- Follow iOS Research: SwiftUI Picker segmentedPickerStyle (`.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-swiftui-picker-segmented.md`)
- Limit to 5 segments on iPhone (All, Train, Bus, Ferry, LightRail, Metro = 6 segments - within Apple's guideline for wide screens)
- Place Picker in VStack above List to avoid conflict with .searchable modifier
- Use DEVELOPMENT_STANDARDS.md:194 (SwiftUI patterns) for @State binding

**Validation:**
```bash
# Run app in Xcode Simulator
# Steps:
# 1. Launch SearchView
# 2. Verify segmented control appears above search bar
# 3. Tap "Bus" → UI updates (selectedMode = .bus)
# 4. Tap "Ferry" → UI updates (selectedMode = .ferry)
# Expected: Segmented control renders, tap changes selectedMode (no results yet OK)
```

**References:**
- Pattern: SwiftUI Picker with segmented style (SearchView.swift:72, needs Picker above List)
- Architecture: IOS_APP_SPECIFICATION.md Section 2 (MVVM state management)
- iOS Research: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-swiftui-picker-segmented.md`

---

### Checkpoint 2: Extend Stop.search() with route_type filtering

**Goal:** FTS5 search optionally filters by route_type via JOIN patterns/routes

**Backend Work:**
- N/A

**iOS Work:**
- Update `Stop.search()` signature in `Stop.swift`: add `routeTypes: [Int]? = nil` parameter
- Modify SQL query:
  - If routeTypes != nil: add JOINs:
    ```sql
    JOIN pattern_stops ps ON s.sid = ps.sid
    JOIN patterns p ON ps.pid = p.pid
    JOIN routes r ON p.rid = r.rid
    WHERE stops_fts MATCH ? AND r.route_type IN (?, ?, ...)
    ```
  - Maintain FTS5 MATCH in WHERE clause first (indexed lookup per iOS Research GRDB FTS5 doc)
  - Use DISTINCT s.* to avoid duplicate stops (one stop may serve multiple route types)
  - Bind routeTypes array with SQL IN clause using GRDB arguments (bind each int individually)
  - Keep LIMIT 50, add ORDER BY after FTS5 rank if needed
- If routeTypes == nil: keep existing query (no JOIN, return all stops)

**Design Constraints:**
- Follow iOS Research: GRDB JOIN performance with FTS5 (`.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-grdb-fts5-explain-query-plan.md`)
- Critical: FTS5 MATCH must be in WHERE clause (not JOIN ON) for index usage
- Use DISTINCT to avoid duplicates when JOINing pattern_stops
- Leverage existing idx_pattern_stops_sid_offset index (DatabaseManager.swift:206)
- Use DEVELOPMENT_STANDARDS.md:350-354 (GRDB query patterns)

**Validation:**
```bash
# Test Stop.search() in Xcode Playground or unit test
# Query 1: Stop.search(db, query: "station", routeTypes: [2])
# Expected: Returns only train stops (route_type = 2)
# Query 2: Stop.search(db, query: "circular quay", routeTypes: [4])
# Expected: Returns only ferry stops (route_type = 4)
# Query 3: Stop.search(db, query: "central", routeTypes: nil)
# Expected: Returns all stops matching "central" (trains + buses + etc)
```

**References:**
- Pattern: FTS5 search with JOIN filters (Stop.swift:24-50, DatabaseManager.swift:193-213)
- Architecture: DEVELOPMENT_STANDARDS.md:350-354 (GRDB query patterns)
- iOS Research: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-grdb-fts5-explain-query-plan.md`

---

### Checkpoint 3: Integrate mode filter with search UI

**Goal:** Search 'central' in Bus mode returns bus-heavy results; Ferry mode returns ferry stops

**Backend Work:**
- N/A

**iOS Work:**
- Update `SearchView.performSearch()`:
  - Map selectedMode to routeTypes array:
    ```swift
    let routeTypes: [Int]? = switch selectedMode {
    case .all: nil
    case .train: [2]
    case .bus: [3, 700, 712, 714]
    case .ferry: [4]
    case .lightRail: [900]
    case .metro: [1, 401]
    }
    ```
  - Call `Stop.search(db, query: query, routeTypes: routeTypes)`
  - Log route type distribution in search results (pattern: phase-2-2 route_type distribution logging)
  - Test edge cases: All mode (nil routeTypes) → returns all; empty query → no search
- Add logging for validation:
  ```swift
  logger.info("search_results", mode: selectedMode.rawValue, count: results.count, routeTypes: routeTypes ?? [])
  ```

**Design Constraints:**
- Follow DEVELOPMENT_STANDARDS.md:817-845 (ViewModel async patterns)
- Use debounced search pattern (SearchView.swift:73-106, 300ms debounce)
- Cancel existing Task when mode changes (same pattern as query change)
- Log route type distribution per search (validate multi-modal coverage per phase-2-2 pattern)

**Validation:**
```bash
# Run app in Xcode Simulator
# Test 1: Search "circular quay" in All mode
# Expected: Returns trains + ferries + maybe buses (mixed icons)
# Test 2: Search "circular quay" in Bus mode
# Expected: Returns buses only (bus.fill icons)
# Test 3: Search "circular quay" in Ferry mode
# Expected: Returns ferry stops only (ferry.fill icons)
# Test 4: Search "central" in Train mode
# Expected: Returns Central Station + other train stops (train icons)
# Verify logs show correct routeTypes arrays and result counts
```

**References:**
- Pattern: Debounced search with Task cancellation (SearchView.swift:73-106)
- Architecture: DEVELOPMENT_STANDARDS.md:817-845 (ViewModel async patterns)
- iOS Research: Both picker and GRDB docs apply here

---

### Checkpoint 4: Performance validation and polish

**Goal:** FTS5 + JOIN query <100ms for typical search; icons display correctly

**Backend Work:**
- N/A

**iOS Work:**
- Add query duration logging in `Stop.search()`:
  ```swift
  let start = CFAbsoluteTimeGetCurrent()
  let results = try db.read { ... }
  let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
  logger.info("search_query_duration", query: query, routeTypes: routeTypes ?? [], duration_ms: Int(duration))
  ```
- Verify idx_pattern_stops_sid_offset index used:
  - Export gtfs.db from app bundle
  - Run: `sqlite3 gtfs.db "EXPLAIN QUERY PLAN <Stop.search query>"`
  - Expected output: "SEARCH TABLE stops_fts USING fts5 index"
- Test with 100 searches across modes (manual or automated), confirm p95 <100ms
- Validate icons in SearchView:
  - Train: tram.fill or train.side.front.car
  - Metro: lightrail.fill
  - Bus: bus.fill
  - Ferry: ferry.fill
  - LightRail: tram.fill
- Ensure no UI jank on mode switch (debounce working, Task cancellation prevents race conditions)

**Design Constraints:**
- Follow DEVELOPMENT_STANDARDS.md:1140-1159 (structured logging patterns)
- Use CFAbsoluteTimeGetCurrent for high-precision timing (pattern: SearchView.swift:118-127 if exists)
- Performance target: p95 <100ms (acceptable for interactive search)
- Use Xcode Instruments for frame rate validation (60fps, no dropped frames on mode switch)

**Validation:**
```bash
# Performance test in Xcode
# 1. Run app with Xcode Instruments (Time Profiler + Core Animation)
# 2. Search "station" in Bus mode → check logs for query duration
# Expected: duration_ms <100ms for most queries
# 3. Switch modes rapidly (All → Train → Bus → Ferry → Metro)
# Expected: No UI jank, smooth 60fps, debounce prevents query spam
# 4. Export gtfs.db, run EXPLAIN QUERY PLAN for Stop.search with routeTypes
# Expected: "SEARCH TABLE stops_fts USING fts5 index" + "USING INDEX idx_pattern_stops_sid_offset"
# 5. Verify icons match route types in search results (screenshot validation)
```

**References:**
- Pattern: Query duration logging (SearchView.swift:118-127 if exists, or add new)
- Architecture: DEVELOPMENT_STANDARDS.md:1140-1159 (structured logging)
- iOS Research: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-grdb-fts5-explain-query-plan.md`

---

## Acceptance Criteria

- [x] Segmented control (All/Train/Bus/Ferry/LightRail/Metro) renders above search bar
- [x] Search 'circular quay' in All mode returns trains+ferries with correct icons
- [x] Search 'circular quay' in Bus mode returns buses only (not trains/ferries)
- [x] Search 'circular quay' in Ferry mode returns ferry stops only
- [x] Ferry/Metro/Light Rail filters work correctly offline (GRDB-only mode)
- [x] FTS5 + JOIN query p95 <100ms (log duration per search)
- [x] Route type distribution logged per search (validate multi-modal coverage)
- [x] No UI jank on mode switch (debounce + task cancellation working)

---

## User Blockers (Complete Before Implementation)

None - all dependencies complete (Phase 1 static data, Phase 2.2 modal coverage fixes, iOS 16+ target)

---

## Research Notes

**iOS Research Completed:**
1. SwiftUI Picker segmentedPickerStyle layout
   - File: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-swiftui-picker-segmented.md`
   - Key finding: Segmented picker auto-sizes to equal width, best for 2-5 options; place in VStack above List to avoid layout conflicts with .searchable modifier
2. GRDB JOIN performance with FTS5 EXPLAIN QUERY PLAN
   - File: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/ios-research-grdb-fts5-explain-query-plan.md`
   - Key finding: FTS5 MATCH must be in WHERE clause (not JOIN ON) for index usage; verify with EXPLAIN QUERY PLAN showing 'SEARCH TABLE using fts5 index'

**On-Demand Research (During Implementation):**
None - all iOS patterns researched upfront

---

## Related Phases

**Phase 1:** Builds on Phase 1 static search (FTS5 over stops_fts, GRDB bundled DB)
**Phase 2.2:** Integrates modal coverage fixes (dict_stop completeness, all 7 NSW route types reachable)
**Phase 1.5:** Completes multi-modal search UX (this is the search filter component of Phase 1.5)

---

## Exploration Report

Attached: `.workflow-logs/custom/phase-1-5-multi-modal-search-ui-and-route-type-filters/exploration-report.json`

---

**Plan Created:** 2025-11-21
**Estimated Duration:** 2-3 days
