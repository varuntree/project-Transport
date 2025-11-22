# Phase 2.1 Feature Completion Plan

**Type:** Custom Plan (Intermediary Phase)
**Context:** Complete partial features from Phase 2 before Phase 3
**Complexity:** Medium

---

## Problem Statement

Phase 2 implemented GTFS-RT polling and departures API backend successfully, but left iOS UI integration incomplete. Stop search shows results without transport icons or real departures. Route list displays flat structure without modality filtering or alphabetical navigation. Trip details view missing entirely. This blocks moving to Phase 3 user features as basic app functionality is not complete.

---

## Affected Systems

**System: iOS Stop Search (Features/Search/SearchView.swift)**
- Current state: GRDB FTS5 search working, shows stop name/code, navigates to StopDetailsView with hardcoded placeholder departures
- Gap: Missing stop type icons, DeparturesView not wired from StopDetailsView, trip details view missing
- Files: SearchView.swift, StopDetailsView.swift, Stop.swift

**System: iOS Departures View (Features/Departures/DeparturesView.swift)**
- Current state: DeparturesView + ViewModel + Repository implemented with auto-refresh, not accessible from StopDetailsView
- Gap: StopDetailsView lines 83-101 show hardcoded placeholders, missing platform/wheelchair display, no trip details navigation
- Files: DeparturesView.swift, StopDetailsView.swift, Departure.swift, DepartureRow.swift

**System: iOS Route List (Features/Routes/RouteListView.swift)**
- Current state: Flat list with RouteType sections (rail/metro/bus/ferry/tram), sorted by priority
- Gap: No modality filter/picker, no alphabetical A-Z index navigation
- Files: RouteListView.swift, Route.swift

**System: Backend Departures API (backend/app/api/v1/stops.py)**
- Current state: GET /stops/{stop_id}/departures exists (lines 176-261), returns trip_id/route/headsign/timing/delay
- Gap: Missing platform, wheelchair_accessible fields in response
- Files: stops.py, realtime_service.py, stops.py (models)

**System: Backend Trip Details API (backend/app/api/v1/trips.py)**
- Current state: Not implemented
- Gap: Need GET /trips/{trip_id} returning trip metadata + stop sequence with real-time predictions
- Files: trips.py (NEW), trips.py models (NEW)

---

## Key Technical Decisions

1. **Use SF Symbols for transport mode icons in search results**
   - Rationale: Native iOS, free, supports accessibility (VoiceOver), no asset management, GTFS route_type maps to SF Symbol names
   - Reference: IOS_APP_SPECIFICATION.md Section 5.1, DEVELOPMENT_STANDARDS.md iOS UI Components
   - Critical constraint: Map GTFS route_type (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry) to SF Symbols (tram.fill, lightrail.fill, train.side.front.car, bus.fill, ferry.fill), mandatory .accessibilityLabel()

2. **SwiftUI List with sectionIndexTitles for A-Z navigation**
   - Rationale: Native iOS Contacts-style pattern, accessibility built-in, no custom gestures
   - Reference: IOS_APP_SPECIFICATION.md Section 3, iOS research file
   - Critical constraint: iOS 26+ API (.listSectionIndexVisibility() + .sectionIndexLabel()), routes alphabetically sorted within modality, single-letter section labels ("A", "B", ...)

3. **Repository pattern for TripRepository (protocol + async/await)**
   - Rationale: Matches existing DeparturesRepository/StopRepository architecture, offline-first with API fallback
   - Reference: DEVELOPMENT_STANDARDS.md Section 6, IOS_APP_SPECIFICATION.md Section 4.3
   - Critical constraint: Protocol TripRepositoryProtocol, async throws methods, GRDB first (if bundled) → API fallback

4. **NavigationLink drill-down: Stop → DeparturesView → TripDetailsView**
   - Rationale: Standard iOS navigation, maintains back stack, MVVM coordinator architecture
   - Reference: IOS_APP_SPECIFICATION.md Section 2, DEVELOPMENT_STANDARDS.md iOS ViewModels
   - Critical constraint: Value-based NavigationLink (value: + .navigationDestination(for:)), ViewModels fetch data on appear, handle loading/error states

5. **Segmented control for modality filter (not tabs)**
   - Rationale: iOS HIG best practice for 3-7 mutually exclusive options with short labels
   - Reference: iOS research file (picker-vs-segmented.md)
   - Critical constraint: Picker(selection:).pickerStyle(.segmented), 6 options (All/Train/Bus/Metro/Ferry/Tram), state-based filtering

---

## Implementation Checkpoints

### Checkpoint 1: Stop Search Icon Enhancement

**Goal:** Search results show transport mode icon (SF Symbol) next to stop name/code

**Backend Work:**
- N/A

**iOS Work:**
- Add `primaryRouteType: Int?` field to Stop model (query GRDB: most frequent route_type serving stop via route_stops table)
- Add computed property `var transportIcon: String` to Stop model mapping route_type → SF Symbol name:
  - 0 (Tram/LightRail) → "tram.fill"
  - 1 (Metro) → "lightrail.fill"
  - 2 (Rail) → "train.side.front.car"
  - 3 (Bus) → "bus.fill"
  - 4 (Ferry) → "ferry.fill"
  - Default → "mappin.circle.fill"
- Update SearchView.swift (lines 32-48): Add HStack with `Image(systemName: stop.transportIcon)` before VStack
- Add `.accessibilityLabel("\(stop.routeTypeDisplayName) stop")` to icon (e.g., "Train stop", "Bus stop")

**Design Constraints:**
- Follow GRDB FetchableRecord pattern for Stop model (DEVELOPMENT_STANDARDS.md Section 2)
- SF Symbols must have accessibility labels (iOS research: accessibility-labels.md)
- Icon size: `.font(.title2)` or `.imageScale(.medium)`, foreground color based on route type

**Validation:**
```bash
# Run app in simulator
# Search "Central" → expect train.side.front.car icon
# Search "Circular Quay" → expect ferry.fill icon
# Enable VoiceOver → tap icon → hear "Train stop"
```

**References:**
- Pattern: GRDB FetchableRecord (Stop.swift:4-62)
- iOS Research: `.phase-logs/phase-2-1-feature-completion/ios-research-sf-symbols-transport.md`

---

### Checkpoint 2: Real Departures Integration

**Goal:** StopDetailsView navigates to DeparturesView showing real API data (not hardcoded placeholders)

**Backend Work:**
- Add `platform: str | None` and `wheelchair_accessible: int` fields to DepartureResponse model in backend/app/models/stops.py
- Update realtime_service.py `get_realtime_departures()` to query GTFS-RT stop_time_update.platform_code and trip.wheelchair_accessible
- Return enriched data in GET /stops/{stop_id}/departures response

**iOS Work:**
- Replace StopDetailsView lines 83-101 (hardcoded "Next Departures" section) with NavigationLink:
  ```swift
  NavigationLink("View Departures", value: stop)
  .navigationDestination(for: Stop.self) { stop in
      DeparturesView(stop: stop)
  }
  ```
- Add `platform: String?` and `wheelchairAccessible: Bool` fields to Departure model (SydneyTransit/Data/Models/Departure.swift)
- Update DepartureRow (Features/Departures/DepartureRow.swift) to display:
  - Platform badge if `departure.platform != nil` (e.g., "Platform 2")
  - Wheelchair icon `Image(systemName: "figure.roll")` if `departure.wheelchairAccessible == true`
- Update APIClient Departure DTO mapping to decode new fields

**Design Constraints:**
- Follow API envelope format (INTEGRATION_CONTRACTS.md Section 1.2)
- MVVM pattern: DeparturesViewModel handles data loading, @Published state (DEVELOPMENT_STANDARDS.md Section 6)
- Handle missing fields gracefully (platform/wheelchair may be nil in GTFS-RT)

**Validation:**
```bash
# Run backend + app
curl http://localhost:8000/api/v1/stops/200060/departures | jq '.data[0]'
# Expected: {trip_id, route_short_name, headsign, ..., platform: "1", wheelchair_accessible: 1}

# Tap stop in app → StopDetailsView → "View Departures"
# Expect: DeparturesView with countdown timers, delays, platforms, wheelchair icons
```

**References:**
- Pattern: API envelope (stops.py:55-72), MVVM ViewModel (DeparturesViewModel.swift)
- Architecture: INTEGRATION_CONTRACTS.md Section 2 (Departures API)

---

### Checkpoint 3: Trip Details View Implementation

**Goal:** Tapping departure shows TripDetailsView with intermediary stops and real-time arrival times

**Backend Work:**
- Create `backend/app/api/v1/trips.py`:
  - Route: `GET /trips/{trip_id}`
  - Query patterns + pattern_stops tables for stop sequence (pattern_id from trips table)
  - Merge GTFS-RT trip_update.stop_time_update for real-time arrival predictions
  - Return:
    ```json
    {
      "data": {
        "trip_id": "...",
        "route": {"short_name": "T1", "color": "#F99D1C"},
        "headsign": "Emu Plains",
        "stops": [
          {"stop_id": "...", "stop_name": "Central", "arrival_time_secs": 1234567890, "platform": "1", "wheelchair_accessible": true},
          ...
        ]
      }
    }
    ```
- Create `backend/app/models/trips.py` with TripDetailsResponse, TripStopResponse Pydantic models
- Create `backend/app/services/trip_service.py` with `get_trip_details(trip_id)` function

**iOS Work:**
- Create `SydneyTransit/Data/Models/Trip.swift`:
  - Struct Trip with nested TripStop struct (stop_id, stop_name, arrivalTimeSecs, platform?, wheelchairAccessible)
- Create `SydneyTransit/Data/Repositories/TripRepository.swift`:
  - Protocol TripRepositoryProtocol with `func fetchTrip(id: String) async throws -> Trip`
  - Implementation TripRepositoryImpl (GRDB bundled data → API fallback)
- Create `SydneyTransit/Features/Trips/TripDetailsViewModel.swift`:
  - @Published var trip: Trip?, isLoading: Bool, errorMessage: String?
  - func loadTrip(id: String) async
- Create `SydneyTransit/Features/Trips/TripDetailsView.swift`:
  - List of TripStopRow (displays stop name, arrival time, platform, wheelchair icon)
  - Navigation title: trip.headsign
- Update DeparturesView: Wrap DepartureRow in NavigationLink(value: departure) → .navigationDestination(for: Departure.self) { TripDetailsView(tripId: $0.tripId) }

**Design Constraints:**
- Repository pattern: Protocol-based, async/await (DEVELOPMENT_STANDARDS.md Section 6)
- MVVM: ViewModel handles data loading, View observes @Published state
- API envelope format (INTEGRATION_CONTRACTS.md Section 1.2)
- Real-time data: Merge static pattern_stops with GTFS-RT trip_update.stop_time_update

**Validation:**
```bash
# Backend test
curl http://localhost:8000/api/v1/trips/1234 | jq '.data.stops | length'
# Expected: 10-30 stops with arrival times

# iOS test
# Tap departure in DeparturesView → TripDetailsView
# Expect: List of stops with "Central (Platform 1) - 3:45 PM", wheelchair icons
```

**References:**
- Pattern: Repository protocol (DeparturesRepository.swift)
- Architecture: BACKEND_SPECIFICATION.md Section 3 (API Routes), DEVELOPMENT_STANDARDS.md Section 3 (API Response Envelope)
- iOS Research: `.phase-logs/phase-2-1-feature-completion/ios-research-navigationlink-state.md`

---

### Checkpoint 4: Route List Modality Filter

**Goal:** Route list has segmented control (All/Train/Bus/Metro/Ferry/Tram), shows filtered routes

**Backend Work:**
- N/A

**iOS Work:**
- Add `@State private var selectedMode: RouteType? = nil` to RouteListView
- Add Picker above List:
  ```swift
  Picker("Transport Mode", selection: $selectedMode) {
      Text("All").tag(RouteType?.none)
      ForEach(RouteType.allCases) { type in
          Text(type.displayName).tag(type as RouteType?)
      }
  }
  .pickerStyle(.segmented)
  .padding()
  ```
- Filter routes before grouping:
  ```swift
  let filteredRoutes = selectedMode == nil ? routes : routes.filter { $0.type == selectedMode }
  ```
- Update section headers to show only selected mode when filtered

**Design Constraints:**
- Segmented control for 6 options (All + 5 transport modes) per iOS HIG (iOS research: picker-vs-segmented.md)
- RouteType enum must conform to CaseIterable for ForEach
- Maintain scroll position when switching modes (SwiftUI List handles automatically)

**Validation:**
```bash
# Run app
# Routes tab → see segmented control at top (All | Train | Bus | Metro | Ferry | Tram)
# Tap "Train" → see only T1-T9 routes
# Tap "All" → see all routes grouped by type
```

**References:**
- Pattern: @State SwiftUI state management (DEVELOPMENT_STANDARDS.md iOS ViewModels)
- iOS Research: `.phase-logs/phase-2-1-feature-completion/ios-research-picker-vs-segmented.md`

---

### Checkpoint 5: Alphabetical Index Navigation

**Goal:** Route list shows A-Z index on right side, tapping letter scrolls to that section

**Backend Work:**
- N/A

**iOS Work:**
- Group routes alphabetically within each modality:
  ```swift
  let alphabeticalSections = Dictionary(grouping: filteredRoutes.sorted { $0.displayName < $1.displayName }) { route in
      String(route.displayName.prefix(1).uppercased())
  }
  ```
- Update List to use ForEach over alphabeticalSections.keys.sorted():
  ```swift
  List {
      ForEach(alphabeticalSections.keys.sorted(), id: \.self) { letter in
          Section {
              ForEach(alphabeticalSections[letter]!) { route in
                  NavigationLink(value: route) {
                      RouteRow(route: route)
                  }
              }
          } header: {
              Text(letter)
                  .font(.headline)
                  .sectionIndexLabel(letter) // iOS 26+ API
          }
      }
  }
  .listSectionIndexVisibility(.automatic)
  ```

**Design Constraints:**
- iOS 26+ API: `.listSectionIndexVisibility()` + `.sectionIndexLabel()` (iOS research: list-section-index.md)
- Section headers must be single-letter strings ("A", "B", ..., "Z", "#")
- Sort routes alphabetically BEFORE grouping by first letter
- Fallback for iOS <26: Show sections without index (graceful degradation)

**Validation:**
```bash
# Run app on iOS 26+ simulator
# Routes tab → select "Train" → see A-Z index on right edge
# Tap "T" in index → scroll to T1/T2/T3 routes
# Tap "M" → scroll to M routes (if any)
```

**References:**
- iOS Research: `.phase-logs/phase-2-1-feature-completion/ios-research-list-section-index.md`
- Pattern: SwiftUI List sections (IOS_APP_SPECIFICATION.md Section 5)

---

## Acceptance Criteria

- [x] Stop search results show transport mode icon (SF Symbol) next to stop name
- [x] Tapping stop in search shows StopDetailsView with "View Departures" button
- [x] Tapping "View Departures" navigates to DeparturesView showing real API data (not hardcoded)
- [x] Each departure row shows: route badge, headsign, countdown timer, delay badge (if >0), platform, wheelchair icon (if accessible)
- [x] Tapping departure navigates to TripDetailsView showing intermediary stops with arrival times
- [x] Route list has modality segmented control (All/Train/Bus/Metro/Ferry/Tram) at top
- [x] Selecting modality filters routes to show only that type
- [x] Route list shows A-Z alphabetical index on right side (iOS 26+)
- [x] Tapping letter in A-Z index scrolls to routes starting with that letter
- [x] All views follow MVVM pattern with @Published state and repositories

---

## User Blockers (Complete Before Implementation)

None - all work builds on existing Phase 2 implementation.

---

## Research Notes

**iOS Research Completed:**
1. **List Section Index** - `.phase-logs/phase-2-1-feature-completion/ios-research-list-section-index.md`
   - iOS 26+ API, requires single-letter labels, vertical stack on trailing edge
2. **SF Symbols Transport** - `.phase-logs/phase-2-1-feature-completion/ios-research-sf-symbols-transport.md`
   - Map GTFS route_type to symbol names, mandatory accessibility labels
3. **Picker vs Segmented** - `.phase-logs/phase-2-1-feature-completion/ios-research-picker-vs-segmented.md`
   - Segmented control optimal for 6 modes, avoid toolbar placement
4. **NavigationLink State** - `.phase-logs/phase-2-1-feature-completion/ios-research-navigationlink-state.md`
   - Value-based pattern for trip details, ViewModel fetches data on appear
5. **Accessibility Labels** - `.phase-logs/phase-2-1-feature-completion/ios-research-accessibility-labels.md`
   - All SF Symbols need descriptive VoiceOver labels (1-3 words)

**On-Demand Research (During Implementation):**
- GTFS route_type mapping (0=Tram, 1=Metro, 2=Rail, 3=Bus, 4=Ferry per GTFS spec)
- Agent researches when implementing Checkpoint 1 if <80% confident

---

## Related Phases

**Phase 2:** Phase 2.1 completes partial UI features from Phase 2 real-time implementation (GTFS-RT poller + departures API working, UI integration incomplete)

**Phase 3:** Phase 2.1 must complete before Phase 3 user features (Apple Sign-In, favorites, sync) to have functional core app

---

## Exploration Report

Attached: `.phase-logs/phase-2-1-feature-completion/exploration-report.json`

---

**Plan Created:** 2025-11-17
**Estimated Duration:** 1-2 weeks (5 checkpoints, medium complexity)
