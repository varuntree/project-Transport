# Departure UI & Trip Map Enhancements Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** Enhance departure list UI with occupancy indicators, fix TripDetailsView crash, add MapKit route visualization
**Complexity:** Medium

---

## Problem Statement

Current departure list shows basic info but missing real-time crowding levels, TripDetailsView crashes due to SwiftUI @StateObject initialization in NavigationLink, and trip details lack map visualization. This enhances UX with occupancy awareness and spatial context for routes.

---

## Affected Systems

**System: iOS Departures UI**
- Current state: Shows route badge, headsign, platform, delay, wheelchair, time countdown. No occupancy indicator.
- Gap: Missing occupancy_status field in Departure model and UI crowding indicator
- Files affected:
  - `SydneyTransit/SydneyTransit/Data/Models/Departure.swift`
  - `SydneyTransit/SydneyTransit/Features/Departures/DeparturesView.swift`

**System: iOS Trip Details View**
- Current state: Shows list of stops with arrival times, wheelchair accessibility. Crashes when tapped from DeparturesView.
- Gap: SwiftUI @StateObject initialized in NavigationLink (violates rules), no map visualization, TripStop missing lat/lon
- Files affected:
  - `SydneyTransit/SydneyTransit/Features/Trips/TripDetailsView.swift`
  - `SydneyTransit/SydneyTransit/Data/Models/Trip.swift`
  - `SydneyTransit/SydneyTransit/Features/Departures/DeparturesView.swift`

**System: Backend Departures API**
- Current state: Returns departures with route, headsign, delay, platform. Fetches from GTFS-RT VehiclePosition feed.
- Gap: Does not extract occupancy_status from GTFS-RT (field exists in protobuf but not queried)
- Files affected:
  - `backend/app/services/realtime_service.py`
  - `backend/app/api/v1/stops.py`

**System: Backend Trip API**
- Current state: Returns trip with stops (name, arrival_time_secs, platform, wheelchair). Queries dict_stops + stop_times.
- Gap: Does not return stop coordinates (lat/lon) needed for map pins and polyline
- Files affected:
  - `backend/app/api/v1/trips.py`
  - `backend/app/services/gtfs_service.py`

---

## Key Technical Decisions

1. **Use SF Symbols for occupancy indicators (figure.stand, figure.stand.line.dotted.figure.stand)**
   - Rationale: Follows iOS HIG for transit crowding, accessible via VoiceOver, color-coded (green/yellow/orange/red) for quick scanning
   - Reference: IOS_APP_SPECIFICATION.md:Section 5 (Accessibility)
   - Critical constraint: Must provide VoiceOver labels for occupancy levels

2. **Fix crash using NavigationLink(value:) + .navigationDestination modifier (iOS 16+ value-based navigation)**
   - Rationale: Avoids @StateObject initialization in NavigationLink body (violates SwiftUI object lifecycle), cleaner separation of concerns
   - Reference: DEVELOPMENT_STANDARDS.md:iOS Patterns (MVVM)
   - Critical constraint: ViewModels must be @StateObject in destination view, not in NavigationLink closure

3. **Use straight-line MKPolyline segments between stops (no shapes table)**
   - Rationale: Simplified data model omitted shapes.txt, straight lines acceptable for MVP (TripView shows approximate path)
   - Reference: DATA_ARCHITECTURE.md:Pattern Model (shapes not ingested)
   - Critical constraint: Polyline is approximate, not actual vehicle path

4. **Backend extracts occupancy_status from GTFS-RT VehiclePosition.occupancy_status field**
   - Rationale: NSW GTFS-RT includes occupancy (0=EMPTY, 1=MANY_SEATS, 2=FEW_SEATS, 3=STANDING_ONLY, 4=CRUSHED, 5=FULL, 6=NOT_ACCEPTING)
   - Reference: INTEGRATION_CONTRACTS.md:GTFS-RT Schema
   - Critical constraint: Default to null if occupancy unavailable (graceful degradation)

---

## Implementation Checkpoints

### Checkpoint 1: Backend - Add occupancy to departures API

**Goal:** Departures endpoint returns occupancy_status field (0-6 or null)

**Backend Work:**
- Update `realtime_service.py` `parse_gtfs_rt_blob` to extract VehiclePosition.occupancy_status
- Add `occupancy_status` to departure dict returned by `get_stop_departures`
- Update API response model in `stops.py` (add optional occupancy_status field)

**iOS Work:** N/A

**Design Constraints:**
- Follow GTFS-RT protobuf spec for occupancy enum values (0-6)
- Default to `None` if occupancy field missing (graceful degradation)
- Use structlog JSON logging for extraction errors

**Validation:**
```bash
# Backend running locally
curl http://localhost:8000/api/v1/stops/200060/departures | jq '.data.departures[0].occupancy_status'
# Expected: 0-6 or null
```

**References:**
- Pattern: API envelope format (APIClient.swift:L22-24)
- Architecture: INTEGRATION_CONTRACTS.md:GTFS-RT Schema

---

### Checkpoint 2: Backend - Add coordinates to trip API

**Goal:** Trip endpoint returns lat/lon for each stop

**Backend Work:**
- Update `gtfs_service.py` `get_trip_details` to SELECT `stop_lat`, `stop_lon` from `dict_stops`
- Add `lat`, `lon` to stop dict in trip response
- Update `trips.py` API response model (add lat/lon to stops)

**iOS Work:** N/A

**Design Constraints:**
- Follow PostGIS conventions (lat = Y, lon = X in coordinates)
- Return coordinates as floats (6 decimal precision sufficient for transit)
- Use structlog JSON logging for missing coordinates

**Validation:**
```bash
# Backend running locally
curl http://localhost:8000/api/v1/trips/1234.T1.2-ABC-mjp-1.1.R | jq '.data.stops[0] | {lat, lon}'
# Expected: {"lat": -33.8688, "lon": 151.2093}
```

**References:**
- Pattern: Repository pattern (DeparturesRepository.swift:L4-6)
- Architecture: DATA_ARCHITECTURE.md:PostGIS Spatial Indexes

---

### Checkpoint 3: iOS - Add occupancy indicator to DepartureRow

**Goal:** Departure list shows crowding icon next to wheelchair icon

**Backend Work:** N/A

**iOS Work:**
- Update `Departure` model with optional `occupancy_status: Int?` field
- Add computed var `occupancyIcon: (symbolName: String, color: Color, label: String)?` to `Departure` model
  - Map 0-6 values to SF Symbol + color:
    - 0-1: "figure.stand" + green
    - 2: "figure.stand.line.dotted.figure.stand" + yellow
    - 3-4: "figure.stand.line.dotted.figure.stand" + orange
    - 5-6: "figure.stand.line.dotted.figure.stand" + red
- Update `DepartureRow` to show SF Symbol if occupancy available (before wheelchair icon)

**Design Constraints:**
- Follow MVVM pattern (computed properties in model, not view)
- Use SF Symbols only (no custom images)
- Provide VoiceOver accessibility labels ("Low occupancy", "Moderate occupancy", "High occupancy", "Very crowded")
- Support Dynamic Type (system font sizes)

**Validation:**
```bash
# Run iOS app in simulator
# Tap search → select stop with departures
# Expected: Departure rows show colored crowding icons (if occupancy data available)
```

**References:**
- Pattern: MVVM with @MainActor ViewModels (DeparturesViewModel.swift:L3-14)
- Architecture: IOS_APP_SPECIFICATION.md:Accessibility
- iOS Research: N/A (SF Symbols usage is standard)

---

### Checkpoint 4: iOS - Fix TripDetailsView crash

**Goal:** Selecting departure navigates to trip details without crash

**Backend Work:** N/A

**iOS Work:**
- Make `Departure` conform to `Hashable` (already does via `Identifiable`)
- Update `DeparturesView` to use `NavigationLink(value: departure)` instead of `NavigationLink(destination:)`
- Add `.navigationDestination(for: Departure.self) { departure in TripDetailsView(tripId: departure.tripId) }` modifier to `DeparturesView.body`
- Ensure `TripDetailsViewModel` uses `@StateObject` in `TripDetailsView` (already correct)

**Design Constraints:**
- Follow iOS 16+ value-based navigation pattern (no destination closure)
- ViewModels must be @StateObject in destination view, never in NavigationLink
- Use NavigationStack (already in use per iOS 16+ target)

**Validation:**
```bash
# Run iOS app in simulator
# Tap search → select stop → tap any departure
# Expected: Navigation to trip details succeeds without crash
```

**References:**
- Pattern: MVVM with @MainActor ViewModels (DEVELOPMENT_STANDARDS.md:iOS Patterns)
- iOS Research: `.workflow-logs/custom/departure-ui-trip-map-enhancements/ios-research-navigationlink-value-based.md`

---

### Checkpoint 5: iOS - Add MapKit route visualization to TripDetailsView

**Goal:** Trip details shows map at top with route polyline + stop pins

**Backend Work:** N/A

**iOS Work:**
- Update `Trip`/`TripStop` models with optional `lat: Double?`, `lon: Double?` fields
- Create `TripMapView.swift` (UIViewRepresentable wrapping MKMapView):
  - Coordinator implements MKMapViewDelegate
  - `makeUIView`: Create MKMapView, set delegate to coordinator
  - `updateUIView`: Add polyline overlay (MKPolyline from stop coordinates) + stop annotations (MKPointAnnotation)
  - Coordinator `mapView(_:rendererFor:)`: Return MKPolylineRenderer with blue stroke
  - Auto-zoom: Call `mapView.showAnnotations(annotations, animated: true)` after adding annotations
- Embed `TripMapView` in `TripDetailsView` above stop list (200pt height, full width)
- Handle missing coordinates gracefully (hide map if no lat/lon data)

**Design Constraints:**
- Follow UIViewRepresentable pattern (never modify SwiftUI-controlled layout properties)
- Use Coordinator for MKMapViewDelegate methods
- MKPolyline draws straight lines (acceptable per plan - shapes.txt not ingested)
- Auto-zoom must happen AFTER addAnnotations (use `updateUIView` not `makeUIView`)
- Add "Route Map" accessibility label for VoiceOver

**Validation:**
```bash
# Run iOS app in simulator
# Tap search → select stop → tap departure → trip details opens
# Expected: Map shows at top with blue polyline connecting stops + pins for each stop
```

**References:**
- Pattern: UIViewRepresentable (SwiftUI-UIKit interop)
- iOS Research:
  - `.workflow-logs/custom/departure-ui-trip-map-enhancements/ios-research-uiviewrepresentable-mapkit.md`
  - `.workflow-logs/custom/departure-ui-trip-map-enhancements/ios-research-mkpolyline-overlay.md`
  - `.workflow-logs/custom/departure-ui-trip-map-enhancements/ios-research-mkpointannotation.md`
  - `.workflow-logs/custom/departure-ui-trip-map-enhancements/ios-research-mapkit-autozoom.md`

---

## Acceptance Criteria

- [ ] Departure list shows occupancy indicators (colored icons) when crowding data available
- [ ] Selecting a departure navigates to trip details without crash
- [ ] Trip details screen shows map at top with route polyline connecting all stops
- [ ] Trip details map shows pin annotations for each stop
- [ ] Map auto-zooms to fit entire route
- [ ] All features work offline (graceful degradation if backend unavailable)
- [ ] VoiceOver announces occupancy levels for accessibility

---

## User Blockers (Complete Before Implementation)

None - ready to implement

---

## Research Notes

**iOS Research Completed:**
- MapKit MKMapView integration with UIViewRepresentable
- MapKit MKPolyline overlay rendering
- MapKit MKPointAnnotation for stop pins
- MapKit auto-zoom region to fit coordinates
- SwiftUI NavigationLink value-based navigation (iOS 16+)

**On-Demand Research (During Implementation):**
None required

---

## Related Phases

**Phase 2:** This enhances Phase 2 real-time departure display with occupancy data and trip detail improvements

---

## Exploration Report

Attached: `.workflow-logs/custom/departure-ui-trip-map-enhancements/exploration-report.json`

---

**Plan Created:** 2025-11-17
**Estimated Duration:** 6-8 hours
