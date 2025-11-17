# Checkpoint 2: Fix Trip Navigation Loop

## Goal
Tapping departure navigates to TripDetailsView (stop sequence list), no page reload.

## Approach

### Backend Implementation
None (backend API `/api/v1/trips/{trip_id}` works correctly)

### iOS Implementation
- Edit `SydneyTransit/Features/Departures/DeparturesView.swift`
- **Line 24**: Replace `NavigationLink(value: departure)` with:
  ```swift
  NavigationLink(destination: TripDetailsView(tripId: departure.tripId)) {
  ```
- **Delete lines 31-33**: Remove `.navigationDestination(for: Departure.self) { departure in TripDetailsView(tripId: departure.tripId) }`
- Preserve departure row UI (headsign, platform, countdown timer)
- TripDetailsView already exists (no changes needed)

## Design Constraints
- Follow IOS_APP_SPECIFICATION.md Section 2 (direct destination pattern for detail views)
- Value-based navigation creates loop: identical Departure struct before/after push triggers iOS loop detection
- Direct destination pattern: NavigationLink explicitly specifies child view
- Maintain existing UI (headsign, platform, countdown)

## Risks
- Breaking other navigation paths
  - Mitigation: This is isolated to Departures → TripDetails navigation, no other NavigationLinks use Departure type
- TripDetailsView not working
  - Mitigation: Backend API verified working, TripDetailsView already implemented in Phase 2.1

## Validation
```
1. Run iOS app in Xcode simulator (Cmd+R)
2. Search any stop → View Departures
3. Tap first departure row
4. Expected: Navigate to TripDetailsView showing:
   - Trip headsign (top)
   - Stop sequence list with arrival times
   - Platform numbers
5. Tap back button → return to departures list (no crash)
```

## References for Subagent
- Exploration report: `affected_systems[1]` → Trip details navigation
- Standards: IOS_APP_SPECIFICATION.md → Section 2 (MVVM navigation)
- File location: SydneyTransit/Features/Departures/DeparturesView.swift:24, 31-33
- Pattern: SwiftUI NavigationLink direct destination (not value-based)

## Estimated Complexity
Simple - 2-line change (replace NavigationLink, delete .navigationDestination), 5 min implementation + 5 min validation
