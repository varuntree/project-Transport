# Checkpoint 3: Trip Details View Implementation

## Goal
Tapping departure shows TripDetailsView with intermediary stops and real-time arrival times, platform info, and wheelchair accessibility.

## Approach

### Backend Implementation

**Step 1: Create trips.py API endpoint**
- Create `backend/app/api/v1/trips.py` with router
- Route: `GET /trips/{trip_id}`
- Register router in `backend/app/main.py` (add `app.include_router(trips.router)`)

**Step 2: Create trip_service.py**
- Create `backend/app/services/trip_service.py` with `get_trip_details(trip_id: str) -> dict` function
- Query Supabase `trips` table for trip metadata (route_id, trip_headsign, pattern_id, wheelchair_accessible)
- Query `patterns` + `pattern_stops` tables for stop sequence using pattern_id
- Join with `stops` table to get stop_name, stop_lat, stop_lon
- Merge with GTFS-RT trip_update.stop_time_update from Redis for real-time arrival predictions
- Return dict with: trip_id, route (short_name, color), headsign, stops array

**Step 3: Create trips.py Pydantic models**
- Create `backend/app/models/trips.py`:
  - TripStopResponse: stop_id, stop_name, arrival_time_secs, platform?, wheelchair_accessible
  - RouteInfo: short_name, color
  - TripDetailsResponse: trip_id, route: RouteInfo, headsign, stops: List[TripStopResponse]
- Follow API envelope format

**Step 4: Implement GET /trips/{trip_id} handler**
- Call trip_service.get_trip_details(trip_id)
- Wrap in envelope: `{data: {...}, meta: {}}`
- Handle errors: 404 if trip not found, 500 if Redis/Supabase error
- Add structlog logging: `logger.info("trip_fetched", trip_id=trip_id, stops_count=len(stops))`

### iOS Implementation

**Step 1: Create Trip model**
- Create `SydneyTransit/Data/Models/Trip.swift`:
  - Struct Trip: Codable, Identifiable
  - Nested struct TripStop: stop_id, stop_name, arrivalTimeSecs, platform?, wheelchairAccessible
  - Properties: trip_id, route (short_name, color), headsign, stops: [TripStop]

**Step 2: Create TripRepository**
- Create `SydneyTransit/Data/Repositories/TripRepository.swift`:
  - Protocol TripRepositoryProtocol: `func fetchTrip(id: String) async throws -> Trip`
  - Class TripRepositoryImpl: APIClient only (GRDB bundled trip details deferred to Phase 4)
  - Follow DeparturesRepository pattern (async/await, error handling)

**Step 3: Create TripDetailsViewModel**
- Create `SydneyTransit/Features/Trips/TripDetailsViewModel.swift`:
  - @MainActor, ObservableObject
  - @Published var trip: Trip?, isLoading: Bool, errorMessage: String?
  - func loadTrip(id: String) async
  - Follow MVVM pattern from DeparturesViewModel

**Step 4: Create TripDetailsView**
- Create `SydneyTransit/Features/Trips/TripDetailsView.swift`:
  - Accept tripId in initializer, create ViewModel
  - List of TripStopRow components (stop name, arrival time formatted, platform badge, wheelchair icon)
  - Navigation title: trip.headsign or "Trip Details"
  - Handle loading/error states (ProgressView, error Text)
  - .onAppear → viewModel.loadTrip(id: tripId)

**Step 5: Create TripStopRow component**
- In same file or separate `TripStopRow.swift`:
  - Display stop_name (font: .body, weight: .medium)
  - Display arrival time formatted (formatArrivalTime from departure_time_secs, .caption font)
  - Show platform badge if available (trailing)
  - Show wheelchair icon if accessible (trailing)

**Step 6: Update DeparturesView navigation**
- Wrap DepartureRow in NavigationLink:
  ```swift
  NavigationLink(value: departure) {
      DepartureRow(departure: departure)
  }
  ```
- Add `.navigationDestination(for: Departure.self) { departure in TripDetailsView(tripId: departure.tripId) }`
- Follow value-based NavigationLink pattern

**Files to create:**
- `backend/app/api/v1/trips.py`
- `backend/app/services/trip_service.py`
- `backend/app/models/trips.py`
- `SydneyTransit/Data/Models/Trip.swift`
- `SydneyTransit/Data/Repositories/TripRepository.swift`
- `SydneyTransit/Features/Trips/TripDetailsViewModel.swift`
- `SydneyTransit/Features/Trips/TripDetailsView.swift`

**Files to modify:**
- `backend/app/main.py`: Register trips router
- `SydneyTransit/Features/Departures/DeparturesView.swift`: Add NavigationLink + navigationDestination

## Design Constraints
- Follow API envelope format (INTEGRATION_CONTRACTS.md Section 1.2)
- Repository pattern: Protocol-based, async/await (DEVELOPMENT_STANDARDS.md Section 6)
- MVVM: ViewModel handles data loading, View observes @Published state
- Real-time data: Merge static pattern_stops with GTFS-RT trip_update.stop_time_update for arrival predictions
- Error handling: 404 if trip not found, 500 for service errors, structlog JSON logging
- Trip ID validation: Supabase query with trip_id string (not integer), handle SQL injection via parameterized query

## Risks
- **Pattern model complexity:** Need to join trips → patterns → pattern_stops → stops (4-table join)
  - Mitigation: Use Supabase client with proper indexing (pattern_id, stop_sequence), test query performance
- **GTFS-RT trip_update matching:** Trip ID in Redis blob may not match Supabase trip_id
  - Mitigation: Log mismatches, return static schedule if RT data unavailable, investigate ID mapping if >10% mismatch rate
- **Large stop sequences:** Some trips have 30-50 stops (long scrolling list)
  - Mitigation: Accept for MVP, consider virtualized list or "show more" expansion in future

## Validation
```bash
# Backend test
curl http://localhost:8000/api/v1/trips/1234 | jq '.data'
# Expected: {trip_id, route: {short_name, color}, headsign, stops: [{stop_id, stop_name, arrival_time_secs, ...}, ...]}
# Verify stops array has 10-30+ entries with sequential arrival times

# iOS test (Cmd+R in Xcode)
# Search "Central" → StopDetailsView → "View Departures" → tap first departure
# Expect: TripDetailsView with "Emu Plains" title, list of stops: "Central (Platform 1) - 3:45 PM", "Redfern - 3:48 PM", ...
# Verify wheelchair icons show for accessible stops
# Verify loading spinner appears briefly before data loads
```

## References for Subagent
- Pattern: Repository protocol (DeparturesRepository.swift), MVVM ViewModel (DeparturesViewModel.swift)
- Architecture: BACKEND_SPECIFICATION.md Section 3 (API Routes), DATA_ARCHITECTURE.md Section 3 (Pattern Model)
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-navigationlink-state.md`
- Standards: DEVELOPMENT_STANDARDS.md Section 3 (API Response Envelope), Section 6 (iOS ViewModels)
- Example: stops.py:176-261 (departures endpoint structure)

## Estimated Complexity
Complex - Backend requires multi-table join + GTFS-RT merge, iOS requires new feature module (MVVM + Repository + View). Most code of any checkpoint.
