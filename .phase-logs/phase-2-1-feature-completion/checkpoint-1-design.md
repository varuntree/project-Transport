# Checkpoint 1: Stop Search Icon Enhancement

## Goal
Search results display transport mode icon (SF Symbol) next to each stop name with VoiceOver accessibility.

## Approach

### Backend Implementation
None - iOS-only feature.

### iOS Implementation

**Step 1: Extend Stop model to determine primary route type**
- Add `primaryRouteType: Int?` computed property to Stop model
- Query GRDB to find most frequent route_type serving the stop via route_stops join
- Since GRDB query is expensive, cache result or accept query cost per stop display
- Alternative: Add `primary_route_type` column to stops table during GTFS processing (deferred to future optimization)

**Step 2: Add transportIcon computed property**
- Map GTFS route_type (0=Tram, 1=Metro, 2=Rail, 3=Bus, 4=Ferry) to SF Symbol names:
  - 0 → "tram.fill"
  - 1 → "lightrail.fill"
  - 2 → "train.side.front.car"
  - 3 → "bus.fill"
  - 4 → "ferry.fill"
  - 5 → "cablecar.fill"
  - default → "mappin.circle.fill"
- Follow pattern from ios-research-sf-symbols-transport.md

**Step 3: Update SearchView.swift lines 32-48**
- Replace current VStack label with HStack containing icon + VStack
- Icon: `Image(systemName: stop.transportIcon)` with `.foregroundColor(.blue)` and `.imageScale(.medium)`
- Add `.accessibilityLabel("\(stop.routeTypeDisplayName) stop")` where routeTypeDisplayName maps int → "Train"/"Bus"/etc
- Maintain existing NavigationLink structure

**Files to create:**
None

**Files to modify:**
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Data/Models/Stop.swift`
  - Add `primaryRouteType: Int?` computed property with GRDB query
  - Add `var transportIcon: String` computed property mapping route_type → SF Symbol
  - Add `var routeTypeDisplayName: String` computed property for accessibility (0→"Tram", 1→"Metro", 2→"Train", 3→"Bus", 4→"Ferry")
- `/Users/varunprasad/code/prjs/prj_transport/SydneyTransit/SydneyTransit/Features/Search/SearchView.swift`
  - Update lines 36-46: Wrap VStack in HStack with leading Image(systemName: stop.transportIcon)
  - Add icon styling: `.foregroundColor(.blue)`, `.imageScale(.medium)`, `.accessibilityLabel()`

## Design Constraints
- Follow GRDB FetchableRecord pattern (DEVELOPMENT_STANDARDS.md Section 2)
- SF Symbols must have accessibility labels per ios-research-accessibility-labels.md
- Icon size: `.imageScale(.medium)` or `.font(.title2)` for consistency with text
- Handle nil primaryRouteType gracefully (show generic mappin icon)

## Risks
- **GRDB query performance:** Querying route_stops for each stop in search results (50 max) may be slow
  - Mitigation: Accept initial cost, optimize later if p95 latency >200ms by adding primary_route_type column to stops table during GTFS pipeline
- **Route type mapping incomplete:** Sydney may use extended GTFS route_types (e.g., 700-799 for buses)
  - Mitigation: Log unknown route_types, default to mappin icon, update mapping if needed

## Validation
```bash
# Run app in simulator (Cmd+R in Xcode)
# Search "Central" → expect train.side.front.car icon
# Search "Circular Quay" → expect ferry.fill icon
# Search "Bondi Junction" → expect train.side.front.car or bus.fill icon
# Enable VoiceOver (Cmd+Fn+F5) → tap icon → hear "Train stop"
```

## References for Subagent
- Exploration report: `critical_patterns` → GRDB FetchableRecord (Stop.swift:4-62)
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-sf-symbols-transport.md`
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-accessibility-labels.md`
- Standards: DEVELOPMENT_STANDARDS.md Section 2 (Database Access)
- Example: Stop.swift lines 24-45 (FTS5 search pattern)

## Estimated Complexity
Simple - Add computed properties to existing model, update SearchView label layout. GRDB query straightforward (route_stops join exists).
