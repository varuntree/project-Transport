# Phase 1.5 Map Drawer and Stop Map Integration (Offline) Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** Implement MapKit-based view with stop pins and bottom drawer showing static departures for selected stops, fully offline
**Complexity:** Medium

---

## Problem Statement

Implement core map experience for Phase 1.5: MapKit view with stop pins and bottom drawer showing static departures. Existing drawer pattern from TripDetailsView (e90ddcc) uses SwiftUI sheets with presentationDetents. Current DatabaseManager.getDepartures provides offline static schedules via GRDB. Need to build map experience connecting stops→pins→drawer→departures, fully offline, with efficient stop loading to handle ~30K stops.

---

## Affected Systems

**System: Map View Infrastructure**
- Current state: No dedicated Map feature module exists. TripDetailsView has TripMapView showing route stops on map, but no general-purpose stop map viewer
- Gap: Need new Features/Map module with MapKit integration, stop annotations, region-based loading, and coordinator for navigation
- Files affected:
  - SydneyTransit/SydneyTransit/Features/Map/MapView.swift
  - SydneyTransit/SydneyTransit/Features/Map/MapViewModel.swift
  - SydneyTransit/SydneyTransit/Features/Map/MapCoordinator.swift
  - SydneyTransit/SydneyTransit/Features/Map/Components/StopAnnotationView.swift

**System: Drawer UI Pattern**
- Current state: TripDetailsView (commit e90ddcc) implements drawer using SwiftUI .sheet with presentationDetents([.fraction(0.15), .medium, .large]), presentationDragIndicator, and custom sheet content. Pattern works with trip stops list
- Gap: Need to adapt drawer pattern for stop details + departures. Requires drawer states: collapsed (stop name+mode icon), half (stop info+next 3 departures), full (all departures scrollable)
- Files affected:
  - SydneyTransit/SydneyTransit/Features/Map/Components/StopDetailsDrawer.swift
  - SydneyTransit/SydneyTransit/Features/Map/MapView.swift

**System: GRDB Stop Loading (Region-Based)**
- Current state: Stop model has lat/lon fields (stopLat, stopLon as Double), search() via FTS5, and fetchByStopID(). DatabaseManager supports read-only queries. ~30K stops in bundled gtfs.db
- Gap: Need efficient region-based query to load stops within visible map bounds (not all 30K at once). Consider clustering or limit to N nearest. Must use spatial query or bounding box filter
- Files affected:
  - SydneyTransit/SydneyTransit/Data/Models/Stop.swift
  - SydneyTransit/SydneyTransit/Core/Database/DatabaseManager.swift

**System: Stop Annotations & Modality Icons**
- Current state: Stop model has primaryRouteType computed property querying pattern_stops→routes for most frequent route_type. transportIcon returns SF Symbol based on route_type (train, bus, ferry, tram, metro)
- Gap: Need to create MKAnnotation subclass for stops with primaryRouteType-based pin icons. Consider pin clustering for dense areas (e.g., CBD with 100s of stops)
- Files affected:
  - SydneyTransit/SydneyTransit/Features/Map/Components/StopAnnotation.swift
  - SydneyTransit/SydneyTransit/Features/Map/Components/StopAnnotationView.swift
  - SydneyTransit/SydneyTransit/Data/Models/Stop.swift

**System: LocalDeparturesService Integration**
- Current state: DatabaseManager.getDepartures(stopId:limit:currentDate:) exists (L157-L281) with pattern model query, calendar service filtering, returns Departure objects with static schedules. DeparturesRepository uses offline fallback
- Gap: Drawer needs to call DatabaseManager.getDepartures for selected stop, display next 3-5 departures in collapsed/half states. Must handle empty results gracefully (no service at current time)
- Files affected:
  - SydneyTransit/SydneyTransit/Features/Map/MapViewModel.swift
  - SydneyTransit/SydneyTransit/Core/Database/DatabaseManager.swift
  - SydneyTransit/SydneyTransit/Features/Map/Components/StopDetailsDrawer.swift

**System: Navigation Flow (Search/Departures → Map)**
- Current state: SearchView exists with stop search, DeparturesView shows departures for a stop. No 'View on Map' button or navigation to map currently
- Gap: Need to add 'View on Map' action in SearchView, DeparturesView, and potentially StopDetailsView (if exists). Must pass selected stop + center map on that stop with drawer showing
- Files affected:
  - SydneyTransit/SydneyTransit/Features/Search/SearchView.swift
  - SydneyTransit/SydneyTransit/Features/Departures/DeparturesView.swift
  - SydneyTransit/SydneyTransit/Features/Map/MapCoordinator.swift

---

## Key Technical Decisions

1. **Reuse TripDetailsView drawer pattern (presentationDetents-based sheet)**
   - Rationale: Existing pattern from e90ddcc commit is battle-tested, uses native SwiftUI .sheet with .fraction(0.15), .medium, .large detents. Matches iOS Maps app drawer UX. Drawer is interactiveDismissDisabled to stay visible, presentationBackgroundInteraction allows map taps while drawer open
   - Reference: TripDetailsView.swift:L19-L27
   - Critical constraint: Must use iOS 16+ presentationDetents API. For iOS 16.4+ features (presentationBackground, presentationCornerRadius), wrap in @available checks (see TripDetailsView.swift:L212-L239)

2. **Region-based stop loading with limit (not all 30K at once)**
   - Rationale: Loading all 30K stops at once would freeze UI and consume excessive memory. Use MKMapView.region (center lat/lon + span) to compute bounding box, query GRDB with WHERE stopLat BETWEEN ? AND ? AND stopLon BETWEEN ? AND ?, LIMIT 200. Update annotations when region changes significantly (>50% overlap threshold)
   - Reference: IOS_APP_SPECIFICATION.md:Section 6.1 (MapKit Live Vehicle Positions), DATA_ARCHITECTURE.md:Section 7 (iOS Local Persistence)
   - Critical constraint: Must debounce region change events (300ms delay) to avoid excessive DB queries during pan/zoom. Consider clustering with MKClusterAnnotation if >100 stops visible

3. **Drawer states: collapsed (0.15 fraction), half (medium), full (large) with distinct content**
   - Rationale: Collapsed: stop name + transport icon only. Half: stop name + primaryRouteType badge + next 3 departures (non-scrollable). Full: all content scrollable (stop info + 20 departures + 'View All Departures' button). Matches iOS Maps behavior and provides progressive disclosure
   - Reference: TripDetailsView.swift:L21 (detents array), DeparturesView.swift:L56-L128 (departure list pattern)
   - Critical constraint: Half detent must not scroll - use fixed height VStack. Full detent has ScrollView for long content. Sheet content must adapt to detent changes (GeometryReader for height detection)

4. **Offline-only for Phase 1.5 (no realtime departures in drawer)**
   - Rationale: Phase 1.5 focuses on static offline experience. DatabaseManager.getDepartures returns static schedules (realtime=false, delayS=0). Drawer shows 'Scheduled' times, no platform/occupancy indicators. Realtime integration deferred to Phase 2
   - Reference: DatabaseManager.swift:L157-L281 (getDepartures), oracle/specs/phase-1-5-local-static-departures-service-offline-engine-plan.md:L52-L55
   - Critical constraint: UI must clearly indicate offline mode - use 'Scheduled' label on departure rows, gray color scheme for static times vs green/orange for realtime

5. **Pin icons based on Stop.primaryRouteType with SF Symbols**
   - Rationale: Stop model already computes primaryRouteType (most frequent route_type at stop) and transportIcon (SF Symbol). Use this for pin customization: train.side.front.car (trains), bus.fill (buses), ferry.fill (ferries), tram.fill (light rail), lightrail.fill (metro). Color by mode or use standard blue
   - Reference: Stop.swift:L78-L128 (primaryRouteType + transportIcon), IOS_APP_SPECIFICATION.md:Section 6.1 (MapKit integration)
   - Critical constraint: primaryRouteType is nonisolated computed property - queries DB on each access. Cache in annotation for performance (avoid DB hits per pin render)

---

## Implementation Checkpoints

### Checkpoint 1: Map View Setup & Region-Based Stop Loading

**Goal:** Create MapView with MapKit, basic stop annotations (no drawer yet), center on Sydney with efficient region-based loading

**Backend Work:**
- N/A

**iOS Work:**
- Create Features/Map module with MapView.swift, MapViewModel.swift, MapCoordinator.swift
- Add MapKit import, create Map view with @State region centered on Sydney (-33.8688, 151.2093)
- Create StopAnnotation class conforming to NSObject, MKAnnotation with coordinate, title from Stop model
- Implement region-based stop loading: MapViewModel.loadStops(for region: MKCoordinateRegion) queries GRDB with bounding box
- Add debouncing for region changes (use @State timer, 300ms delay)
- Display stop pins using .annotationItems in Map view
- Add basic pin customization: color based on Stop.primaryRouteType (cache in annotation init)
- Implement clustering if >100 stops visible (MKClusterAnnotation, opt-in with .clusteringIdentifier)

**Design Constraints:**
- Follow region-based loading pattern from IOS_APP_SPECIFICATION.md:Section 6.1
- Use bounding box calculation: center ± span/2 for min/max lat/lon (see ios-research-bounding-box-calculation.md)
- Debounce with Task.sleep(300ms) pattern from ios-research-map-region-debouncing.md
- Cache primaryRouteType in StopAnnotation init - avoid DB query per pin render
- Clustering: set clusteringIdentifier on MKAnnotationView (see ios-research-mkannotation-clustering.md)

**Validation:**
```bash
# Open MapView in Xcode simulator
# Pan/zoom around Sydney - verify pins appear for stops, update on region change
# Check Instruments Time Profiler - no UI freeze with 200+ stops
# Test pin tap - annotation selected (placeholder for drawer in Checkpoint 2)
```

**References:**
- Pattern: MapKit Region-Based Loading (IOS_APP_SPECIFICATION.md:Section 6.1)
- Pattern: GRDB Read-Only Query (DatabaseManager.swift:L157-L281)
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-bounding-box-calculation.md`
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-map-region-debouncing.md`
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-mkannotation-clustering.md`

---

### Checkpoint 2: Drawer Integration with Static Departures

**Goal:** Add bottom drawer using sheet pattern from TripDetailsView, show stop details + static departures

**Backend Work:**
- N/A

**iOS Work:**
- Create StopDetailsDrawer component (separate file in Features/Map/Components/)
- Add @State isDrawerPresented = false to MapView, bind to .sheet modifier
- Implement drawer with presentationDetents([.fraction(0.15), .medium, .large]), presentationDragIndicator, interactiveDismissDisabled
- Add iOS 16.4+ compatibility wrappers (safePresentationBackground, safePresentationCornerRadius) from TripDetailsView.swift:L212-L239
- Drawer content: header (collapsed), stop info + 3 departures (half), scrollable 20 departures (full)
- On pin tap: set selectedStop in MapViewModel, set isDrawerPresented = true, center map on stop
- Call DatabaseManager.getDepartures(stopId:limit:3) for half detent, limit:20 for full detent
- Display departures using DepartureRow component from DeparturesView.swift (reuse existing UI)
- Handle empty departures gracefully - show 'No upcoming departures at this time' message

**Design Constraints:**
- Follow TripDetailsView drawer pattern: presentationDetents, interactiveDismissDisabled, presentationBackgroundInteraction
- Fixed VStack for half detent (3 departures, no scroll), ScrollView for full detent (20 departures scrollable)
- Use 'Scheduled' label on departure rows (gray color) to indicate offline mode
- Handle empty departures: late-night, no service at current time

**Validation:**
```bash
# Tap stop pin → drawer opens at collapsed state showing stop name
# Drag up to half → shows 3 departures with route badges
# Drag to full → shows 20 departures scrollable
# Test offline mode (Airplane Mode in Xcode) - verify static schedules load, no crash
# Test late-night (23:30) - drawer shows overnight trips or 'No departures' message
```

**References:**
- Pattern: SwiftUI Sheet Drawer with presentationDetents (TripDetailsView.swift:L19-L27)
- Pattern: Repository Offline Fallback (DeparturesRepository.swift:L27-L85)
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-drawer-height-adaptation.md`

---

### Checkpoint 3: Navigation Integration (Search/Departures → Map)

**Goal:** Add 'View on Map' buttons in SearchView, DeparturesView to navigate to MapView with selected stop

**Backend Work:**
- N/A

**iOS Work:**
- Add MapCoordinator.navigateToStop(stop: Stop) method - centers map, opens drawer for stop
- In SearchView: add 'View on Map' button to search result rows (trailing swipe action or context menu)
- In DeparturesView: add 'View on Map' toolbar button (navigationBar trailing item)
- Use NavigationLink or coordinator pattern to push MapView with selected stop parameter
- MapView.onAppear: if selectedStop parameter provided, center map region, set isDrawerPresented=true, call loadDepartures
- Test deep link flow: Search 'Circular Quay' → tap result → 'View on Map' → map centers on stop with drawer open

**Design Constraints:**
- Follow MVVM + Coordinator pattern from DEVELOPMENT_STANDARDS.md:Section 6
- Use NavigationStack for back navigation (iOS 16+)
- MapView must accept optional selectedStop parameter - centers map + opens drawer if provided

**Validation:**
```bash
# From SearchView, search 'Central Station' → tap 'View on Map' → map opens centered on Central with drawer showing departures
# From DeparturesView for any stop → tap toolbar 'View on Map' button → same behavior
# Verify back navigation works (NavigationStack pop)
# Test edge case: search stop, view on map, close drawer, search different stop, view on map again
```

**References:**
- Pattern: MVVM + Coordinator (DEVELOPMENT_STANDARDS.md:Section 6)
- Architecture: IOS_APP_SPECIFICATION.md:Section 5 (Feature Structure)

---

### Checkpoint 4: Performance, Clustering & Polish

**Goal:** Optimize stop loading performance, add clustering, refine drawer UX, validate edge cases

**Backend Work:**
- N/A

**iOS Work:**
- Profile stop loading query time - target <100ms for 200 stops (use Instruments Time Profiler)
- Verify idx_pattern_stops_sid_offset index exists for primaryRouteType query (check PRAGMA index_list)
- Implement MKClusterAnnotation for dense areas (CBD, transport hubs) - group stops if >5 within 100m radius
- Add drawer scroll-to-top on detent collapse (reset ScrollView offset when returning to half/collapsed state)
- Add haptic feedback on pin tap (UIImpactFeedbackGenerator.light)
- Test edge cases: no departures at current time (late night), Sunday service (different schedules), stops with no routes (return empty primaryRouteType)
- Add accessibility: VoiceOver labels for pins ('Central Station, Train stop'), drawer detent hints
- Log structured events: 'map_stop_selected', 'drawer_opened', 'offline_departures_shown' with stop_id, count

**Design Constraints:**
- Performance target: <100ms for loadStops(for:) with 200 stops
- Clustering: use clusteringIdentifier pattern from ios-research-mkannotation-clustering.md
- Accessibility: concise labels, test with VoiceOver + Screen Curtain (Settings → Accessibility)
- Structured logging: follow DEVELOPMENT_STANDARDS.md:Section 9 (JSON logging with stop_id, event_type)

**Validation:**
```bash
# Run XCTest performance test - loadStops(for:) completes <100ms
# Stress test: zoom to CBD (100+ stops) - verify clustering works, no UI lag
# Test late-night (23:30) - drawer shows overnight trips or 'No departures' message
# VoiceOver: all pins + drawer content have accessibility labels
# Test edge case: stop with no routes (fallback to generic pin icon)
# Check Xcode console for structured log events: map_stop_selected, drawer_opened
```

**References:**
- Pattern: Structured Logging (DEVELOPMENT_STANDARDS.md:Section 9)
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-accessibility-map-pins.md`
- iOS Research: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/ios-research-mkannotation-clustering.md`

---

## Acceptance Criteria

- [ ] MapView displays stops as pins within visible region, updates on pan/zoom, no UI freeze with 200+ stops
- [ ] Pin icons reflect stop primaryRouteType (train/bus/ferry/tram/metro) using SF Symbols
- [ ] Tapping pin opens drawer at collapsed state (.fraction(0.15)) showing stop name + icon
- [ ] Dragging drawer to half (.medium) shows stop name + next 3 static departures (non-scrollable)
- [ ] Dragging drawer to full (.large) shows scrollable list of 20 static departures
- [ ] SearchView 'View on Map' button navigates to MapView centered on selected stop with drawer open
- [ ] DeparturesView 'View on Map' toolbar button navigates to MapView for current stop
- [ ] Offline mode (Airplane Mode): map + drawer work fully, show static schedules from GRDB, no errors
- [ ] Performance: stop loading query <100ms, map responsive with 100+ pins, clustering active in dense areas
- [ ] Edge cases handled: no departures (show message), late-night (overnight trips), stops with no routes (fallback icon)
- [ ] Accessibility: VoiceOver labels for pins + drawer, detent drag hints, semantic UI elements

---

## User Blockers (Complete Before Implementation)

None - ready to implement

---

## Research Notes

**iOS Research Completed:**
1. MKAnnotation clustering API (MKClusterAnnotation, .clusteringIdentifier) for dense stop areas
2. Map region change debouncing with Combine or async/await Task.sleep
3. Bounding box calculation from MKCoordinateRegion (region.center ± region.span)
4. Drawer content height adaptation to presentationDetents (GeometryReader vs fixed heights)
5. Accessibility best practices for map pins + drawer (VoiceOver labels, custom actions)

**On-Demand Research (During Implementation):**
None - all iOS patterns researched upfront

---

## Related Phases

**Phase 1.5:** Part of Phase 1.5 offline experience - complements local static departures engine with map UI

**Phase 2:** Phase 2 will add realtime departures to drawer (replace static with GTFS-RT merged data)

---

## Exploration Report

Attached: `.workflow-logs/custom/phase-1-5-map-drawer-and-stop-map-integration-offline/exploration-report.json`

---

**Plan Created:** 2025-11-21
**Estimated Duration:** 2-3 days (MapKit setup + drawer integration + offline departures + navigation + polish)
