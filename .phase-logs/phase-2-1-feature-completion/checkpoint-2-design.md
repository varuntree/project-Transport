# Checkpoint 2: Real Departures Integration

## Goal
StopDetailsView shows real upcoming departures from API (replacing hardcoded placeholders), including platform and wheelchair accessibility.

## Approach

### Backend Implementation

**Step 1: Extend Departure response model**
- Add `platform: str | None` and `wheelchair_accessible: int` fields to DepartureResponse in `backend/app/models/stops.py`
- Follow API envelope format from INTEGRATION_CONTRACTS.md Section 1.2

**Step 2: Update realtime_service.py get_realtime_departures()**
- Query GTFS-RT stop_time_update.platform_code (if available in Redis blob)
- Query GTFS static trips.wheelchair_accessible (fallback if RT data missing)
- Enrich departure dicts with platform/wheelchair fields before returning
- Handle None values gracefully (not all trips have platform/wheelchair data)

**Step 3: Update GET /stops/{stop_id}/departures in stops.py**
- Return enriched DepartureResponse with new fields
- Validate with curl test

### iOS Implementation

**Step 1: Extend Departure model**
- Add `platform: String?` and `wheelchairAccessible: Bool` fields to `SydneyTransit/Data/Models/Departure.swift`
- Update Codable CodingKeys if needed

**Step 2: Update DeparturesRepository**
- Update DTO mapping in `parseDeparture()` or API response handler to decode new fields
- Handle nil platform gracefully

**Step 3: Replace StopDetailsView hardcoded departures**
- Remove lines 83-101 (mock "Next Departures" section)
- Add NavigationLink to DeparturesView:
  ```swift
  NavigationLink("View Departures", value: stop)
  ```
- Add `.navigationDestination(for: Stop.self) { stop in DeparturesView(stop: stop) }`
- Follow value-based NavigationLink pattern from ios-research-navigationlink-state.md

**Step 4: Update DepartureRow to show platform + wheelchair**
- Display platform badge if `departure.platform != nil` (e.g., "Platform 2" in secondary text or trailing badge)
- Show wheelchair icon `Image(systemName: "figure.roll")` if `departure.wheelchairAccessible == true`
- Add accessibility labels for both

**Files to create:**
None

**Files to modify:**
- `backend/app/models/stops.py`: Add fields to DepartureResponse
- `backend/app/services/realtime_service.py`: Enrich get_realtime_departures() return data
- `backend/app/api/v1/stops.py`: Verify response includes new fields (likely no change if using model)
- `SydneyTransit/Data/Models/Departure.swift`: Add platform/wheelchairAccessible properties
- `SydneyTransit/Data/Repositories/DeparturesRepository.swift`: Update DTO parsing
- `SydneyTransit/Features/Stops/StopDetailsView.swift`: Replace hardcoded departures with NavigationLink
- `SydneyTransit/Features/Departures/DepartureRow.swift`: Add platform badge + wheelchair icon display

## Design Constraints
- Follow API envelope format (INTEGRATION_CONTRACTS.md Section 1.2): `{data: [...], meta: {...}}`
- MVVM pattern: DeparturesViewModel handles loading, @Published state (DEVELOPMENT_STANDARDS.md Section 6)
- Handle missing fields gracefully (platform/wheelchair may be nil/undefined in GTFS-RT)
- NavigationLink value-based pattern (iOS 16+ API): `value:` + `.navigationDestination(for:)`
- Platform display: Show as secondary info (not primary), e.g., "Platform 1" in .caption font below headsign
- Wheelchair icon: Small trailing icon, not text, with VoiceOver label "Wheelchair accessible"

## Risks
- **GTFS-RT platform data missing:** Many Sydney trips may not have platform_code in real-time feed
  - Mitigation: Show platform only if available, don't error if nil, consider static GTFS stop_times.stop_headsign as fallback
- **Wheelchair field interpretation:** GTFS wheelchair_accessible values (0=unknown, 1=accessible, 2=not accessible)
  - Mitigation: Only show icon if value == 1, hide for 0/2/null

## Validation
```bash
# Backend test
cd backend && source venv/bin/activate
uvicorn app.main:app --reload  # Start backend
curl http://localhost:8000/api/v1/stops/200060/departures | jq '.data[0]'
# Expected: {trip_id, route_short_name, headsign, ..., platform: "1", wheelchair_accessible: 1}

# iOS test (Cmd+R in Xcode)
# Tap stop in search → StopDetailsView → tap "View Departures"
# Expect: DeparturesView with countdown timers, delays, "Platform 1" badges, wheelchair icons
# Verify auto-refresh works (30s timer)
```

## References for Subagent
- Pattern: API envelope (stops.py:55-72), MVVM ViewModel (DeparturesViewModel.swift)
- Architecture: INTEGRATION_CONTRACTS.md Section 2 (Departures API contract)
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-navigationlink-state.md`
- Standards: DEVELOPMENT_STANDARDS.md Section 3 (API Response Envelope), Section 6 (iOS ViewModels)
- Example: DeparturesRepository.swift (existing repository pattern)

## Estimated Complexity
Moderate - Backend changes require understanding GTFS-RT structure + Redis blob parsing. iOS changes straightforward (extend model, update UI).
